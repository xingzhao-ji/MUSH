extends Node
## Diagnostic only (no pass/fail thresholds): controlled in-process attribution of the
## prototype art layer's frame cost, and LOD-switch frames along the walkable route.
## Attribution: at fixed poses from the benchmark route (night + rain, like its "worst"
## scenario), each component's visibility is toggled in ABBA order within one process,
## so machine state is shared across configurations. VSync is disabled only while
## sampling: the interval is application throughput, not GPU time (GPU timestamps report
## zero on this Metal path). Captures prove depicted states only, not motion quality.
const SIZE := Vector2i(1920,1080)
const WARM := 20
const SAMPLES := 90
var game: Node
var player: CharacterBody3D
var scenery: Node
var output := "user://verification/perf"
var _sampling: bool = false
var _deltas: Array[float] = []
var _last_usec: int = 0

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _process(_delta: float) -> void:
	if not _sampling: return
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0: _deltas.append((now - _last_usec) / 1000.0)
	_last_usec = now

func _v(value: Vector3) -> Array:
	return [snappedf(value.x,0.01),snappedf(value.y,0.01),snappedf(value.z,0.01)]

func _groups() -> Dictionary:
	var sets: Dictionary = {"carpet":[],"trees":[],"near_crowns":[],"terrain":[],"giants_rocks":[],"water":[]}
	for node: Node in scenery.get_children():
		var label: String = String(node.name)
		if label.begins_with("ForestCarpet"): sets.carpet.append(node)
		elif node.has_meta("lod_range"):
			sets.trees.append(node)
			if node.get_meta("lod_range") == "near": sets.near_crowns.append(node)
		elif label in ["WorldTerrain","CliffDetailPatch"]: sets.terrain.append(node)
		elif label in ["HeroCanopy","LuminousCanopies","CanopyStems","RockPillars","RimBoulders"]: sets.giants_rocks.append(node)
		elif label == "WorldLake": sets.water.append(node)
	return sets

func _apply(config: String, sets: Dictionary) -> void:
	scenery.visible = config != "prototype_hidden"
	for key: String in sets:
		for node: Node3D in sets[key]: node.visible = true
	if sets.has(config):
		for node: Node3D in sets[config]: node.visible = false

func _measure() -> Dictionary:
	for _i: int in WARM: await get_tree().process_frame
	_deltas.clear()
	_last_usec = 0
	_sampling = true
	var prims: Array[float] = []
	var draws: Array[float] = []
	for _i: int in SAMPLES:
		await get_tree().process_frame
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_sampling = false
	var sorted: Array[float] = _deltas.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in sorted: total += d
	prims.sort(); draws.sort()
	return {"mean_ms":total / maxf(sorted.size(),1), "median_ms":sorted[sorted.size()/2], "p95_ms":sorted[mini(sorted.size()-1,int(ceil(0.95*sorted.size()))-1)], "primitives":prims[prims.size()/2], "draw_calls":draws[draws.size()/2], "samples":sorted.size()}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	player = game.player
	scenery = game.get("prototype_scenery")
	if not is_instance_valid(scenery):
		_finish({"error":"prototype scenery absent; full-art attribution impossible"}, false)
		return
	game.ui.hide()
	game.set_appearance("night","rain")
	player.set_glow(true)
	await get_tree().create_timer(4.5).timeout
	if "--lod-cost" in arguments:
		await _lod_cost()
		return
	var sets: Dictionary = _groups()
	# Poses on the actual benchmark route (player camera), plus the two scenic overlooks.
	var poses: Array = [
		{"name":"route-spawn","player":Vector3(-1,0.08,11),"look":Vector3(4,1,9)},
		{"name":"route-bridge","player":Vector3(11.3,0.08,7.5),"look":Vector3(14,1,2)},
		{"name":"route-north","player":Vector3(12,0.08,-6),"look":Vector3(-5,1,-7)},
		{"name":"route-west","player":Vector3(-7,0.08,5),"look":Vector3(-1,1,11)},
		{"name":"rim-overlook","camera":scenery.overlook_pose()},
	]
	var configs: Array[String] = ["full","carpet","trees","near_crowns","terrain","giants_rocks","water","prototype_hidden"]
	var vsync_before: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var attribution: Array = []
	for pose: Dictionary in poses:
		var camera: Camera3D
		if pose.has("camera"):
			camera = game.review_camera
			camera.global_position = pose.camera.position
			camera.fov = pose.camera.fov
			camera.look_at(pose.camera.target)
		else:
			var aim: Vector3 = pose.look - pose.player
			player._camera_pitch = deg_to_rad(-6.0)
			player.teleport_safe(pose.player, atan2(-aim.x,-aim.z))
			camera = player._camera
		camera.make_current()
		await get_tree().create_timer(1.0).timeout
		var rows: Dictionary = {}
		# ABBA: forward then reverse, averaged, so slow drift cancels.
		for pass_index: int in 2:
			var order: Array[String] = configs.duplicate()
			if pass_index == 1: order.reverse()
			for config: String in order:
				_apply(config, sets)
				var m: Dictionary = await _measure()
				if not rows.has(config): rows[config] = []
				rows[config].append(m)
		_apply("full", sets)
		var summary: Dictionary = {}
		var full_mean: float = (rows.full[0].mean_ms + rows.full[1].mean_ms) / 2.0
		for config: String in rows:
			var mean: float = (rows[config][0].mean_ms + rows[config][1].mean_ms) / 2.0
			summary[config] = {"mean_ms":snappedf(mean,0.001), "saved_vs_full_ms":snappedf(full_mean - mean,0.001), "median_ms":[snappedf(rows[config][0].median_ms,0.001),snappedf(rows[config][1].median_ms,0.001)], "p95_ms":[snappedf(rows[config][0].p95_ms,0.001),snappedf(rows[config][1].p95_ms,0.001)], "primitives":rows[config][0].primitives, "draw_calls":rows[config][0].draw_calls}
		attribution.append({"pose":pose.name, "camera_position":_v(camera.global_position), "configs":summary})
	DisplayServer.window_set_vsync_mode(vsync_before)
	# LOD switches along the actual route walk: consecutive frames near each 100 m switch.
	var lod: Dictionary = await _route_lod_walk(sets)
	_finish({"attribution":attribution, "lod_walk":lod, "refresh_hz":DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen()), "resolution":[SIZE.x,SIZE.y]}, true)

## Controlled LOD-only comparison (--lod-cost): at the benchmark-route poses (night + rain, the
## benchmark's "worst" scenario), the rim overlook and a transition view 106 m from the near batch
## nearest the route, only scenery.set_lod_crossfade() is toggled (swap = original instant swap,
## crossfade = current), in two ABBA rounds with the existing WARM/SAMPLES. VSync is disabled only
## while sampling (application frame interval, not GPU time). Visible LOD node/instance counts use
## each node's range against the camera-to-AABB-centre distance (the swap state's 12 m hysteresis
## makes its counts nominal).
func _lod_cost() -> void:
	var near_route: Node3D = null
	var best: float = INF
	for node: Node in scenery.get_children():
		if node.get_meta("lod_range", "") != "near": continue
		for point: Vector3 in scenery.route._p:
			if (node as Node3D).global_position.distance_to(point) < best:
				best = (node as Node3D).global_position.distance_to(point)
				near_route = node
	var centre: Vector3 = near_route.global_position
	var route_point: Vector3 = scenery.route._p[0]
	for point: Vector3 in scenery.route._p:
		if point.distance_to(centre) < route_point.distance_to(centre): route_point = point
	var heading: Vector3 = Vector3(route_point.x - centre.x, 0.0, route_point.z - centre.z).normalized()
	var poses: Array = [
		{"name":"route-spawn","player":Vector3(-1,0.08,11),"look":Vector3(4,1,9)},
		{"name":"route-bridge","player":Vector3(11.3,0.08,7.5),"look":Vector3(14,1,2)},
		{"name":"route-north","player":Vector3(12,0.08,-6),"look":Vector3(-5,1,-7)},
		{"name":"route-west","player":Vector3(-7,0.08,5),"look":Vector3(-1,1,11)},
		{"name":"rim-overlook","camera":scenery.overlook_pose()},
		{"name":"transition-106m","camera":{"position":centre + heading * 106.0 + Vector3.UP * 10.0, "target":centre + Vector3.UP * 6.0, "fov":50.0}},
	]
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var vsync_before: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Array = []
	for pose: Dictionary in poses:
		var camera: Camera3D
		if pose.has("camera"):
			camera = game.review_camera
			camera.global_position = pose.camera.position
			camera.fov = pose.camera.fov
			camera.look_at(pose.camera.target)
		else:
			var aim: Vector3 = pose.look - pose.player
			player._camera_pitch = deg_to_rad(-6.0)
			player.teleport_safe(pose.player, atan2(-aim.x,-aim.z))
			camera = player._camera
		camera.make_current()
		await get_tree().create_timer(1.0).timeout
		var rows: Dictionary = {"swap": [], "crossfade": []}
		for round_index: int in 2:
			for state: String in ["swap", "crossfade", "crossfade", "swap"]:
				scenery.set_lod_crossfade(state == "crossfade")
				var m: Dictionary = await _measure()
				m["render_cpu_ms"] = snappedf(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu(), 0.001)
				m["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
				m["objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
				m["lod"] = _visible_lod(camera.global_position)
				rows[state].append(m)
		scenery.set_lod_crossfade(true)
		var summary: Dictionary = {}
		for state: String in rows:
			var list: Array = rows[state]
			var mean: float = 0.0
			for m: Dictionary in list: mean += float(m.mean_ms) / list.size()
			summary[state] = {"mean_ms": snappedf(mean, 0.001), "median_ms": list.map(func(m: Dictionary) -> float: return snappedf(m.median_ms, 0.001)), "p95_ms": list.map(func(m: Dictionary) -> float: return snappedf(m.p95_ms, 0.001)),
				"render_cpu_ms": list.map(func(m: Dictionary) -> float: return m.render_cpu_ms), "gpu_timing_available": list.any(func(m: Dictionary) -> bool: return float(m.render_gpu_ms) > 0.0),
				"primitives": list[0].primitives, "draw_calls": list[0].draw_calls, "objects": list[0].objects, "lod": list[0].lod}
		summary["crossfade_minus_swap"] = {"mean_ms": snappedf(summary.crossfade.mean_ms - summary.swap.mean_ms, 0.001), "primitives": summary.crossfade.primitives - summary.swap.primitives, "draw_calls": summary.crossfade.draw_calls - summary.swap.draw_calls}
		results.append({"pose": pose.name, "camera_position": _v(camera.global_position), "states": summary})
	DisplayServer.window_set_vsync_mode(vsync_before)
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	_finish({"schema_mode": "lod-cost", "lod_cost": results, "warmup_frames": WARM, "samples": SAMPLES, "rounds": "2 x ABBA (swap, crossfade, crossfade, swap)", "resolution": [SIZE.x, SIZE.y], "appearance": "night + rain (benchmark worst)", "lod_config": scenery.get_report().trees.get("lod", {}).get("crossfade")}, true)

func _visible_lod(eye: Vector3) -> Dictionary:
	var out := {"near_nodes": 0, "near_instances": 0, "near_triangles": 0, "far_nodes": 0, "far_instances": 0, "far_triangles": 0}
	for node: Node in scenery.get_children():
		var role: String = node.get_meta("lod_range", "")
		if not role in ["near", "far"]: continue
		var g: MultiMeshInstance3D = node as MultiMeshInstance3D
		var d: float = eye.distance_to(g.global_transform * g.get_aabb().get_center())
		if d < g.visibility_range_begin or (g.visibility_range_end > 0.0 and d > g.visibility_range_end): continue
		var tris: int = scenery._triangle_count(g.multimesh.mesh) * g.multimesh.instance_count
		out[role + "_nodes"] += 1
		out[role + "_instances"] += g.multimesh.instance_count
		out[role + "_triangles"] += tris
	return out

func _route_lod_walk(sets: Dictionary) -> Dictionary:
	var route: Node3D = scenery.route
	var near: Array = sets.near_crowns
	var result: Dictionary = {"frames":[], "near_batches":near.size(), "tree_batches":(sets.trees as Array).size(), "switch_events":[]}
	if not is_instance_valid(route) or not route.valid or near.is_empty(): return result
	game.set_appearance("day","sunny")
	await get_tree().create_timer(4.5).timeout
	player.teleport_safe(Vector3(-2.0,0.08,22.0), PI)
	await get_tree().create_timer(1.0).timeout
	player._camera.make_current()
	var targets: Array = [Vector3(-2,0,27.5)]
	for i: int in range(0, route._p.size(), maxi(1, int(route._p.size()/40))): targets.append(route._p[i])
	var previous_inside: Dictionary = {}
	var captured: int = 0
	var ticks: int = 0
	for target: Vector3 in targets:
		while ticks < 9000:
			var offset: Vector3 = target - player.global_position
			offset.y = 0.0
			if offset.length() < 1.0: break
			player.camera_yaw = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward",1.0)
			await get_tree().physics_frame
			ticks += 1
			var eye: Vector3 = player._camera.global_position
			for node: Node3D in near:
				var distance: float = eye.distance_to(node.global_position)
				var inside: bool = distance < 100.0
				var key: int = node.get_instance_id()
				if previous_inside.has(key) and previous_inside[key] != inside:
					result.switch_events.append({"tick":ticks, "batch":String(node.name), "distance_m":snappedf(distance,0.01), "entering":inside})
					# Two consecutive rendered frames right at the nominal switch distance.
					if captured < 12:
						for k: int in 2:
							await RenderingServer.frame_post_draw
							var frame: Image = get_viewport().get_texture().get_image()
							frame.convert(Image.FORMAT_RGBA8)
							var label: String = "lod-%02d-%s.png" % [captured, "a" if k == 0 else "b"]
							frame.save_png(output.path_join(label))
							result.frames.append({"file":label, "tick":ticks, "batch":String(node.name), "distance_m":snappedf(distance,0.01)})
						captured += 1
				previous_inside[key] = inside
			if player.state == "Recovering": break
	Input.action_release("move_forward")
	result["walk_ticks"] = ticks
	result["end"] = _v(player.global_position)
	result["scope"] = "Switch distances are measured from camera to batch centre; Godot applies a 12 m hysteresis margin, so the visible switch can occur up to 12 m either side of the logged crossing. Frames are stills around the nominal crossing, not continuous motion review."
	return result

func _finish(data: Dictionary, ok: bool) -> void:
	data.merge({"schema":"mush-perf-probe/1", "diagnostic_only":true, "passed":ok, "timing_scope":"Uncapped application frame interval per configuration; not GPU time, not display presentation, not a benchmark verdict.", "art_enabled":true, "manual_motion_verified":false})
	var file := FileAccess.open(output.path_join("perf.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	print("PERF_PROBE_COMPLETE ",ok)
	game._quit_clean(0 if ok else 1)
