extends Node
## Diagnostic: near-crown LOD transitions in motion, before (instant swap with hysteresis) and
## after (dithered crossfade, scripts/prototype_scenery.gd set_lod_crossfade) in one process.
## A. Harness-driven review camera: fixed aim at one dense-crown batch, 130 m -> 76 m -> 130 m in
##    0.5 m steps (world and environment motion frozen).
## B. Physical walk: the character walks the route with real analog move input (CharacterBody
##    physics) toward one near tree and back away from it; the follow camera's yaw/pitch is set by
##    the harness each tick so the tree stays in view (camera translation is the real follow rig).
## At every step the same paused pose is rendered twice more: once with the dense near-crown LOD
## nodes hidden (changed fraction in the tree/batch box = dense contribution D) and once with the
## ring far-crown nodes hidden (= ring contribution R). The dense share s = D / (D + R) is 1 inside
## and 0 outside the LOD distance; occlusion and camera events scale D and R together. A pop is a
## single step with |ds| > 0.35 (a swap flips s by ~1), searched over the whole sequence, since the
## original swap happens by batch-centre distance, not by the individual tree's distance. A gap is a
## run of steps whose crown coverage D + R falls below 35 % of the visible coverage on both sides
## of the run (crowns vanishing between the two LODs). Walk steps where rendered terrain hides the
## tree from the follow camera (camera below ground, or terrain across the line of sight) are
## excluded from the gap search and counted; that test is geometric and independent of the LOD.
## Cropped frames every 2 m through 88-124 m, and full frames around each sequence's largest step,
## are kept. Stills under fixed-step motion: not manual motion review.
const SIZE := Vector2i(1280,720)
const BAND := Vector2(86.0, 126.0)
var game: Node
var scenery: Node
var player: Node
var output := "user://verification/lod"
var beat: Node

func _ready() -> void:
	game = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	beat = preload("res://tests/harness_heartbeat.gd").new()
	add_child(beat)
	_run.call_deferred()

func _v(value: Vector3) -> Array:
	return [snappedf(value.x,0.01),snappedf(value.y,0.01),snappedf(value.z,0.01)]

func _settle(frames: int) -> void:
	for _i: int in frames: await get_tree().process_frame
	await _drawn()

## Next drawn frame, or an explicit exit with the window state if none is drawn within the
## heartbeat's limit (instead of waiting until the runner's timeout).
func _drawn() -> void:
	if not await beat.await_draw():
		print("HARNESS_DRAW_LOST ", JSON.stringify(beat.state()))
		game._quit_clean(1)
		await get_tree().create_timer(3600.0).timeout

func _grab(label: String) -> Image:
	await _drawn()
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	if label != "": frame.save_png(output.path_join(label + ".png"))
	return frame

func _box_roi(camera: Camera3D, box: AABB) -> Rect2i:
	var rect := Rect2()
	var first := true
	for i: int in 8:
		var corner: Vector3 = box.get_endpoint(i)
		if camera.is_position_behind(corner): continue
		var point: Vector2 = camera.unproject_position(corner)
		rect = Rect2(point, Vector2.ZERO) if first else rect.expand(point)
		first = false
	var clipped: Rect2 = rect.grow(8.0).intersection(Rect2(Vector2.ZERO, Vector2(SIZE)))
	return Rect2i(clipped.position.floor(), clipped.size.ceil())

func _diff(a: Image, b: Image, roi: Rect2i) -> Dictionary:
	var changed: int = 0
	var total: float = 0.0
	var count: int = 0
	for y: int in range(roi.position.y, roi.end.y, 2):
		for x: int in range(roi.position.x, roi.end.x, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			var d: float = maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			total += d
			count += 1
			if d > 24.0 / 255.0: changed += 1
	return {"changed_fraction": snappedf(float(changed) / maxf(count, 1), 0.0001), "mean_abs": snappedf(total / maxf(count, 1) * 255.0, 0.01), "sampled_pixels": count}

## Dense and ring crown contributions at the current (already rendered) frame: the same pose
## re-rendered while paused with the near LOD nodes hidden, then with the far LOD nodes hidden.
func _coverage(frame: Image, roi: Rect2i) -> Dictionary:
	get_tree().paused = true
	var out := {}
	for role: String in ["near", "far"]:
		beat.step = beat.step.get_slice(" | ", 0) + " | coverage " + role
		var hidden: Array = []
		for node: Node in scenery.get_children():
			if node.get_meta("lod_range", "") == role and (node as Node3D).visible:
				(node as Node3D).visible = false
				hidden.append(node)
		await _drawn()
		var bare: Image = await _grab("")
		for node: Node in hidden: (node as Node3D).visible = true
		out["dense" if role == "near" else "ring"] = float(_diff(frame, bare, roi).changed_fraction)
	await _drawn()
	get_tree().paused = false
	var total: float = out.dense + out.ring
	out["share"] = out.dense / total if total >= 0.001 else -1.0
	return out

## Crown disappearance: runs of steps whose D + R drops below 35 % of the coverage on both sides.
func _gaps(all_steps: Array) -> Array:
	var steps: Array = all_steps.filter(func(s: Dictionary) -> bool: return not s.get("occluded", false))
	var found: Array = []
	var i: int = 1
	while i < steps.size() - 1:
		var before: float = float(steps[i - 1].dense) + float(steps[i - 1].ring)
		var j: int = i
		while j < steps.size() and float(steps[j].dense) + float(steps[j].ring) < before * 0.35: j += 1
		if j > i and j < steps.size() and before >= 0.002:
			var after: float = float(steps[j].dense) + float(steps[j].ring)
			if after >= 0.002:
				var low: float = INF
				for k: int in range(i, j): low = minf(low, float(steps[k].dense) + float(steps[k].ring))
				if low < 0.35 * minf(before, after):
					found.append({"from_m": steps[i].distance_m, "to_m": steps[j - 1].distance_m, "steps": j - i, "min_coverage": snappedf(low, 0.0001), "bracket_coverage": [snappedf(before, 0.0001), snappedf(after, 0.0001)]})
			i = j
		i += 1
	return found

## Pop analysis of one sequence of steps ({distance_m, dense, ring, share}).
func _pops(steps: Array) -> Dictionary:
	var worst: Dictionary = {}
	var last: Dictionary = {}
	var valid: int = 0
	for step: Dictionary in steps:
		if float(step.share) < 0.0: continue
		valid += 1
		if not last.is_empty():
			var jump: float = absf(float(step.share) - float(last.share))
			step["share_jump"] = snappedf(jump, 0.001)
			if worst.is_empty() or jump > float(worst.jump): worst = {"jump": jump, "from_m": last.distance_m, "to_m": step.distance_m, "share": [last.share, step.share]}
		last = step
	var gaps: Array = _gaps(steps)
	var occluded: int = steps.filter(func(s: Dictionary) -> bool: return s.get("occluded", false)).size()
	return {"occluded_steps_excluded_from_gap_search": occluded, "max_share_jump": snappedf(float(worst.get("jump", 0.0)), 0.001), "between_m": [worst.get("from_m"), worst.get("to_m")], "share_at_jump": worst.get("share"), "threshold": 0.35, "pop": float(worst.get("jump", 0.0)) > 0.35, "gaps": gaps, "gap": not gaps.is_empty(), "valid_steps": valid, "steps": steps.size()}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	scenery = game.get("prototype_scenery")
	var report: Dictionary = {"schema":"mush-lod-check/2", "diagnostic_only":true, "manual_motion_verified":false}
	if not is_instance_valid(scenery) or not is_instance_valid(scenery.route):
		report["error"] = "prototype scenery or route absent"
		_finish(report, false)
		return
	game.ui.hide()
	game.player.visible = false
	game.world.set_appearance(false, false, false)
	await get_tree().create_timer(4.5).timeout
	# Freeze world living motion and the shared environment (wind, clouds) for stills.
	game.world.set_living_motion_enabled(false)
	game.environment_controller.set_foreground(false)
	game.world.set_environment_foreground(false)
	scenery.set_frozen(true)
	var near: MultiMeshInstance3D = null
	var far: MultiMeshInstance3D = null
	var best: float = INF
	for node: Node in scenery.get_children():
		if node.get_meta("lod_range", "") != "near": continue
		for point: Vector3 in scenery.route._p:
			var gap: float = (node as Node3D).global_position.distance_to(point)
			if gap < best:
				best = gap
				near = node
	if near == null:
		report["error"] = "no near-LOD batch"
		_finish(report, false)
		return
	# The far LOD partner shares the batch cell, so it is the nearest far batch.
	var far_gap: float = INF
	for node: Node in scenery.get_children():
		if node.get_meta("lod_range", "") == "far" and (node as Node3D).global_position.distance_to(near.global_position) < far_gap:
			far_gap = (node as Node3D).global_position.distance_to(near.global_position)
			far = node
	var centre: Vector3 = near.global_position
	var route_point: Vector3 = scenery.route._p[0]
	for point: Vector3 in scenery.route._p:
		if point.distance_to(centre) < route_point.distance_to(centre): route_point = point
	var heading: Vector3 = Vector3(route_point.x - centre.x, 0.0, route_point.z - centre.z).normalized()
	var camera: Camera3D = game.review_camera
	camera.fov = 50.0
	camera.make_current()
	report["batch"] = {"name":String(near.name), "instances":near.multimesh.instance_count, "centre":_v(centre), "far_partner":String(far.name) if far != null else null, "route_point":_v(route_point), "range_end":near.visibility_range_end, "end_margin":near.visibility_range_end_margin}
	player = game.player
	var sequences: Dictionary = {}
	for state: String in ["before", "after"]:
		scenery.set_lod_crossfade(state == "after")
		await _settle(10)
		sequences["sweep-" + state] = await _sweep(camera, near, centre, heading, state)
	report["walk_target"] = _walk_plan(near)
	if report.walk_target.has("error"):
		report["error"] = report.walk_target.error
	else:
		for state: String in ["before", "after"]:
			scenery.set_lod_crossfade(state == "after")
			for direction: String in ["approach", "retreat"]:
				sequences["walk-%s-%s" % [direction, state]] = await _walk(report.walk_target, direction, state)
	scenery.set_lod_crossfade(true)
	camera.make_current()
	report["sequences"] = sequences
	report["lod_config"] = scenery.get_report().trees.get("lod", {})
	var checks: Array = []
	var old_pops: int = 0
	var new_pops: Array = []
	var old_gaps: int = 0
	var new_gaps: Array = []
	var recovered: Array = []
	for key: String in sequences:
		var sequence: Dictionary = sequences[key]
		if sequence.get("recovered", false): recovered.append(key)
		if key.ends_with("-before") and sequence.analysis.pop: old_pops += 1
		if key.ends_with("-after") and sequence.analysis.pop: new_pops.append(key)
		if key.ends_with("-before") and sequence.analysis.gap: old_gaps += 1
		if key.ends_with("-after") and sequence.analysis.gap: new_gaps.append(key)
	checks.append({"label": "Detector sanity: the original instant swap registers as a pop in at least one sequence", "passed": old_pops > 0, "detail": old_pops})
	checks.append({"label": "Crossfade: no pop spike in any approach/retreat sequence (harness camera and physical walk)", "passed": new_pops.is_empty(), "detail": new_pops})
	checks.append({"label": "Detector sanity: the original version shows a crown disappearance gap in at least one sequence", "passed": old_gaps > 0, "detail": old_gaps})
	checks.append({"label": "Crossfade: crowns never disappear (no coverage gap) in any sequence", "passed": new_gaps.is_empty(), "detail": new_gaps})
	var walk_ok: bool = not report.has("error") and recovered.is_empty()
	var spans: Dictionary = {}
	for direction: String in ["approach", "retreat"]:
		var key: String = "walk-%s-after" % direction
		var span: Array = sequences.get(key, {}).get("distance_span", [INF, -INF])
		spans[direction] = span
		walk_ok = walk_ok and sequences.has(key) and float(span[0]) <= 88.0 and float(span[1]) >= 124.0
	checks.append({"label": "Physical walks: approach and retreat both crossed 88-124 m with no recovery", "passed": walk_ok, "detail": {"recovered": recovered, "spans": spans}})
	report["checks"] = checks
	var ok := true
	for check: Dictionary in checks: ok = ok and check.passed
	_finish(report, ok)

## A. Harness-driven review camera sweep (fixed aim at the batch).
func _sweep(camera: Camera3D, near: MultiMeshInstance3D, centre: Vector3, heading: Vector3, state: String) -> Dictionary:
	beat.phase = "sweep-%s" % state
	camera.make_current()
	var steps: Array = []
	var crops: Array = []
	var distances: Array[float] = []
	var d: float = 130.0
	while d >= 76.0:
		distances.append(d)
		d -= 0.5
	d = 76.5
	while d <= 130.0:
		distances.append(d)
		d += 0.5
	var previous: Image = null
	var frames_kept: Array = []
	var worst: Dictionary = {}
	for i: int in distances.size():
		var direction: String = "approach" if i < 109 else "retreat"
		camera.global_position = centre + heading * distances[i] + Vector3.UP * 10.0
		camera.look_at(centre + Vector3.UP * 6.0)
		await _settle(2)
		var frame: Image = await _grab("")
		var roi: Rect2i = _box_roi(camera, near.global_transform * near.get_aabb())
		var prims: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var parts: Dictionary = await _coverage(frame, roi)
		var step := {"distance_m": distances[i], "direction": direction, "dense": parts.dense, "ring": parts.ring, "share": snappedf(parts.share, 0.001), "primitives": prims}
		steps.append(step)
		frames_kept.append(frame)
		if frames_kept.size() > 2: frames_kept.pop_front()
		var prior: Array = steps.filter(func(s: Dictionary) -> bool: return float(s.share) >= 0.0)
		if float(step.share) >= 0.0 and prior.size() > 1:
			var jump: float = absf(float(step.share) - float(prior[prior.size() - 2].share))
			if worst.is_empty() or jump > float(worst.jump): worst = {"jump": jump, "frames": frames_kept.duplicate()}
		if is_equal_approx(fmod(distances[i], 2.0), 0.0) and distances[i] >= 88.0 and distances[i] <= 124.0:
			var name: String = "sweep-%s-%s-%03d" % [state, direction, int(distances[i])]
			frame.get_region(roi).save_png(output.path_join(name + ".png"))
			crops.append(name + ".png")
		previous = frame
	var spike_files: Array = []
	if not worst.is_empty():
		for k: int in 2:
			if k >= worst.frames.size(): continue
			var name: String = "sweep-%s-maxstep-%s.png" % [state, ["a", "b"][k]]
			(worst.frames[k] as Image).save_png(output.path_join(name))
			spike_files.append(name)
		worst.erase("frames")
	var approach: Array = steps.filter(func(s: Dictionary) -> bool: return s.direction == "approach")
	var retreat: Array = steps.filter(func(s: Dictionary) -> bool: return s.direction == "retreat")
	var by_direction := {"approach": _pops(approach), "retreat": _pops(retreat)}
	var analysis: Dictionary = by_direction.approach.duplicate()
	analysis["pop"] = by_direction.approach.pop or by_direction.retreat.pop
	analysis["max_share_jump"] = maxf(by_direction.approach.max_share_jump, by_direction.retreat.max_share_jump)
	analysis["gaps"] = by_direction.approach.gaps + by_direction.retreat.gaps
	analysis["gap"] = by_direction.approach.gap or by_direction.retreat.gap
	return {"motion": "harness-driven review camera (fixed aim, 0.5 m steps)", "state": state, "steps": steps, "crops": crops, "max_step": worst, "max_step_files": spike_files,
		"analysis": analysis, "analysis_by_direction": by_direction}

## Chooses one near-crown tree and a route span whose distance falls monotonically through the band.
func _walk_plan(near: MultiMeshInstance3D) -> Dictionary:
	var best: Dictionary = {}
	var route: PackedVector3Array = scenery.route._p
	for k: int in near.multimesh.instance_count:
		var origin: Vector3 = (near.global_transform * near.multimesh.get_instance_transform(k)).origin
		var i: int = 0
		while i < route.size() - 1:
			if route[i].distance_to(origin) < 132.0:
				i += 1
				continue
			var j: int = i
			while j < route.size() - 1 and route[j + 1].distance_to(origin) < route[j].distance_to(origin) + 0.05: j += 1
			var far_d: float = route[i].distance_to(origin)
			var near_d: float = route[j].distance_to(origin)
			if near_d <= 80.0 and (best.is_empty() or j - i < int(best.span[1]) - int(best.span[0])):
				best = {"instance": k, "origin": origin, "span": [i, j], "route_distance_m": [snappedf(far_d, 0.1), snappedf(near_d, 0.1)]}
			i = j + 1
	if best.is_empty(): return {"error": "no route span falls monotonically from >= 132 m to <= 80 m of a near-crown tree"}
	best["origin_xyz"] = _v(best.origin)
	best["batch_centre"] = near.global_transform * near.get_aabb().get_center()
	best["batch_centre_xyz"] = _v(best.batch_centre)
	return best

## B. Physical walk with real analog move input along the route span; camera aimed at the tree.
func _walk(plan: Dictionary, direction: String, state: String) -> Dictionary:
	var route: PackedVector3Array = scenery.route._p
	var path: Array = []
	for i: int in range(int(plan.span[0]), int(plan.span[1]) + 1): path.append(route[i])
	if direction == "retreat": path.reverse()
	var tree: Vector3 = plan.origin
	beat.phase = "walk-%s-%s" % [state, direction]
	player._camera.make_current()
	_release()
	player.global_position = path[0] + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	_aim(tree)
	player._camera_pivot.global_position = player.global_position + Vector3.UP * 0.70
	await _settle(40)
	var steps: Array = []
	var crops: Array = []
	var previous: Image = null
	var frames_kept: Array = []
	var batch_centre: Vector3 = plan.batch_centre
	var last_d: float = INF
	var next_crop: float = 124.0 if direction == "approach" else 88.0
	var worst: Dictionary = {}
	var span := Vector2(INF, -INF)
	var index: int = 1
	var ticks: int = 0
	var recovered := false
	var stall: int = 0
	var best_left: float = INF
	while index < path.size() and ticks < 6000:
		var p: Vector3 = player.global_position
		var target: Vector3 = path[index]
		var left: float = Vector2(target.x - p.x, target.z - p.z).length()
		if left < 1.0:
			index += 1
			best_left = INF
			continue
		stall = 0 if left < best_left - 0.05 else stall + 1
		best_left = minf(best_left, left)
		if stall > 300: break
		var move: Vector3 = Vector3(target.x - p.x, 0.0, target.z - p.z).normalized()
		var yaw: float = _aim(tree)
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		_press(move.dot(forward), move.dot(right))
		await get_tree().physics_frame
		ticks += 1
		if player.state == "Recovering":
			recovered = true
			break
		var d: float = player._camera.global_position.distance_to(tree)
		beat.step = "ticks %d, path %d/%d, d %.1f m, left %.2f m, stall %d" % [ticks, index, path.size(), d, left, stall]
		span = Vector2(minf(span.x, d), maxf(span.y, d))
		var crossed: bool = absf(d - last_d) >= 1.0 or last_d == INF
		if not crossed: continue
		last_d = d
		var frame: Image = await _grab("")
		var roi: Rect2i = _box_roi(player._camera, AABB(tree + Vector3(-9.0, -2.0, -9.0), Vector3(18.0, 22.0, 18.0)))
		if roi.size.x > 4 and roi.size.y > 4:
			var parts: Dictionary = await _coverage(frame, roi)
			var step := {"distance_m": snappedf(d, 0.01), "batch_distance_m": snappedf(player._camera.global_position.distance_to(batch_centre), 0.01), "dense": parts.dense, "ring": parts.ring, "share": snappedf(parts.share, 0.001), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "player": _v(p), "occluded": _terrain_hides(player._camera.global_position, tree + Vector3.UP * 6.0)}
			steps.append(step)
			frames_kept.append(frame)
			if frames_kept.size() > 2: frames_kept.pop_front()
			var prior: Array = steps.filter(func(s: Dictionary) -> bool: return float(s.share) >= 0.0)
			if float(step.share) >= 0.0 and prior.size() > 1:
				var jump: float = absf(float(step.share) - float(prior[prior.size() - 2].share))
				if worst.is_empty() or jump > float(worst.jump): worst = {"jump": jump, "frames": frames_kept.duplicate()}
		if roi.size.x > 4 and roi.size.y > 4 and ((direction == "approach" and d <= next_crop) or (direction == "retreat" and d >= next_crop)) and d >= 87.0 and d <= 125.0:
			var name: String = "walk-%s-%s-%03d" % [state, direction, roundi(d)]
			frame.get_region(roi).save_png(output.path_join(name + ".png"))
			crops.append(name + ".png")
			next_crop += -2.0 if direction == "approach" else 2.0
		previous = frame
	_release()
	var spike_files: Array = []
	if not worst.is_empty():
		for k: int in 2:
			if k >= worst.frames.size(): continue
			var name: String = "walk-%s-%s-maxstep-%s.png" % [state, direction, ["a", "b"][k]]
			(worst.frames[k] as Image).save_png(output.path_join(name))
			spike_files.append(name)
		worst.erase("frames")
	return {"motion": "physical: CharacterBody walk with real analog move input along the route; follow-camera aim set by harness", "state": state, "direction": direction, "ticks": ticks, "recovered": recovered,
		"reached_end": index >= path.size(), "distance_span": [snappedf(span.x, 0.1), snappedf(span.y, 0.1)], "steps": steps, "crops": crops, "max_step": worst, "max_step_files": spike_files, "analysis": _pops(steps)}

## True when rendered terrain hides the target: the camera is below the ground, or the ground
## rises above the camera-to-crown line anywhere along it.
func _terrain_hides(eye: Vector3, target: Vector3) -> bool:
	for k: int in range(0, 41):
		var at: Vector3 = eye.lerp(target, k / 40.0)
		var ground: float = scenery.rendered_terrain_height(at.x, at.z)
		if not is_nan(ground) and ground > at.y + 0.05: return true
	return false

func _aim(tree: Vector3) -> float:
	var eye: Vector3 = player.global_position + Vector3.UP * 0.7
	var yaw: float = atan2(-(tree.x - eye.x), -(tree.z - eye.z))
	player.camera_yaw = yaw
	# Slightly downward: positive pitch swings the spring arm below the walker and, on the
	# uphill route, pressed the camera into the bank (lod-check-20261026-112007-35393). Crowns at
	# ~100 m sit about 8 degrees above the horizon, well inside the 65 degree view.
	player._camera_pitch = deg_to_rad(-3.0)
	return yaw

func _press(forward: float, right: float) -> void:
	for pair: Array in [["move_forward", forward], ["move_back", -forward], ["move_right", right], ["move_left", -right]]:
		if float(pair[1]) > 0.001: Input.action_press(pair[0], float(pair[1]))
		else: Input.action_release(pair[0])

func _release() -> void:
	for action: String in ["move_forward", "move_back", "move_right", "move_left"]: Input.action_release(action)

func _finish(report: Dictionary, ok: bool) -> void:
	report["passed"] = ok
	var file := FileAccess.open(output.path_join("lod.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("LOD_CHECK_COMPLETE ", ok)
	game._quit_clean(0 if ok else 1)
