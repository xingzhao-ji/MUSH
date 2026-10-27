extends Node
## Connected-slice traversal with ordinary input (camera yaw + move_forward) and real
## CharacterBody physics at fixed 60 Hz steps: original box -> existing route -> knoll
## junction -> connected slice -> stopped by the hero root; captures on the shore and at
## the root during that same walk; return walk to the junction; boundary/recovery, junction
## and rendered-terrain checks; unchanged save/teleport limits. Automated input only.
const SIZE := Vector2i(1280,720)
var game: Node
var player: CharacterBody3D
var scenery: Node
var route: Node3D
var slice: Node3D
var output := "user://verification/slice"
var checks: Array = []
var legs: Array = []
var images: Array = []
var shore_captured: bool = false
var approach_captured: bool = false
var approach_info: Dictionary = {}
var _tree_boxes: Array = []
var timings: Array = []
var motion_steps: Array = []

var beat: Node
## Set when a capture found no frame drawn within the heartbeat's limit; later captures are
## skipped so the run reports the failure promptly instead of reaching the runner timeout.
var draw_lost: Dictionary = {}

func _ready() -> void:
	game = get_parent()
	beat = preload("res://tests/harness_heartbeat.gd").new()
	add_child(beat)
	_run.call_deferred()

func _check(label: String, ok: bool, detail: Variant = null) -> bool:
	checks.append({"label":label,"passed":ok,"detail":detail})
	return ok

func _frames(count: int) -> void:
	for _i: int in count: await get_tree().physics_frame

func _v(value: Vector3) -> Array:
	return [snappedf(value.x,0.01),snappedf(value.y,0.01),snappedf(value.z,0.01)]

func _release() -> void:
	for action: String in ["move_forward","move_back","move_left","move_right","float","glow"]:
		if InputMap.has_action(action): Input.action_release(action)

func _ground_under(at: Vector3) -> float:
	var rendered: float = scenery.rendered_terrain_height(at.x, at.z)
	var ground: float = rendered if not is_nan(rendered) else scenery.terrain_height(at.x, at.z)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.01, at + Vector3.DOWN * 80.0, 1))
	if not hit.is_empty(): ground = maxf(ground, (hit.position as Vector3).y)
	return ground

func _camera_clearance() -> float:
	var at: Vector3 = player._camera.global_position
	var inside := PhysicsPointQueryParameters3D.new()
	inside.position = at
	inside.collision_mask = 1
	if not game.get_world_3d().direct_space_state.intersect_point(inside, 1).is_empty(): return -1.0
	return at.y - _ground_under(at)

func _capture(label: String) -> void:
	beat.phase = "capture " + label
	if not draw_lost.is_empty(): return
	for _i: int in 2:
		if not await beat.await_draw():
			draw_lost = beat.state().merged({"capture": label})
			_check("Window kept drawing (no frame drawn for 20 s during capture %s; window state recorded)" % label, false, draw_lost)
			return
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(label + ".png")
	frame.save_png(path)
	images.append({"file":label + ".png","png_sha256":FileAccess.get_sha256(path),"size":[frame.get_width(),frame.get_height()],"player":_v(player.global_position)})

func _look(target: Vector3, pitch_deg: float) -> void:
	var aim: Vector3 = target - player.global_position
	player.camera_yaw = atan2(-aim.x, -aim.z)
	player._camera_pitch = deg_to_rad(pitch_deg)

## Drives through targets. With stop_on_stall, an unreachable last target (the root) ends
## the leg when forward progress stops for 90 ticks while still pressing forward.
func _drive(targets: Array, label: String, max_ticks: int, stop_on_stall: bool = false) -> Dictionary:
	var leg := {"label":label,"from":_v(player.global_position),"ticks":0,"floor_ticks":0,"recovered":false,"min_camera_clearance":INF,"max_drop_per_tick":0.0,"reached":false,"stalled":false,"stuck":false,"travel_m":0.0}
	var previous: Vector3 = player.global_position
	var best: float = INF
	var since_progress: int = 0
	for index: int in targets.size():
		var target: Vector3 = targets[index]
		var last: bool = index == targets.size() - 1
		best = INF
		since_progress = 0
		while leg.ticks < max_ticks:
			var offset: Vector3 = target - player.global_position
			offset.y = 0.0
			if offset.length() < 1.0: break
			player.camera_yaw = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward", 1.0)
			await get_tree().physics_frame
			leg.ticks += 1
			var p: Vector3 = player.global_position
			if player.is_on_floor(): leg.floor_ticks += 1
			leg.max_drop_per_tick = maxf(leg.max_drop_per_tick, previous.y - p.y)
			leg.travel_m += Vector2(p.x - previous.x, p.z - previous.z).length()
			previous = p
			if leg.ticks % 6 == 0: leg.min_camera_clearance = minf(leg.min_camera_clearance, _camera_clearance())
			if player.state == "Recovering":
				leg.recovered = true
				leg.recovered_at = _v(p)
				break
			if not shore_captured and label == "clearing-to-root" and p.z < -300.0 and p.x > 300.0:
				shore_captured = true
				_release()
				await _frames(20)
				_look(Vector3(190.0, -80.0, -330.0), -4.0)
				await _frames(4)
				await _capture("slice-shore-day")
				previous = player.global_position
			var hero_d: float = Vector2(p.x - scenery.hero.base.x, p.z - scenery.hero.base.z).length()
			if not approach_captured and label in ["clearing-to-root", "endpoint-approach"] and p.z < -190.0 and hero_d < 420.0 and leg.ticks % 30 == 0 and (hero_d < 250.0 or _root_view_blockers(_expected_camera(p)).is_empty()):
				approach_captured = true
				_release()
				await _frames(20)
				await _approach_capture("endpoint-" if label == "endpoint-approach" else "slice-")
				previous = player.global_position
			var remaining: float = Vector2(target.x - p.x, target.z - p.z).length()
			if remaining < best - 0.2:
				best = remaining
				since_progress = 0
			else:
				since_progress += 1
			if stop_on_stall and last and since_progress >= 90:
				leg.stalled = true
				break
			# Any other target with no progress for 10 s is a failure (bounded runtime).
			if since_progress >= 600 and not (stop_on_stall and last):
				leg.stuck = true
				leg.stuck_at = _v(p)
				break
		if leg.recovered or leg.stalled or leg.get("stuck", false): break
	_release()
	await _frames(30)
	var final: Vector3 = targets[targets.size() - 1]
	leg.reached = not leg.recovered and not leg.stuck and Vector2(player.global_position.x - final.x, player.global_position.z - final.z).length() < 2.0
	leg.end = _v(player.global_position)
	leg.end_floor = player.is_on_floor()
	leg.end_state = player.state
	leg.floor_ratio = float(leg.floor_ticks) / maxf(1.0, float(leg.ticks))
	legs.append(leg)
	return leg

## Root landmark from the actual path, a reasonable distance back: the walker's own camera,
## required to be outside every collider and above the rendered ground.
func _approach_capture(prefix: String) -> void:
	var hero: Vector3 = scenery.hero.base
	var to_root: float = Vector2(player.global_position.x - hero.x, player.global_position.z - hero.z).length()
	# Taken about 420 m out, beyond the 220 m cap, so the base, the whole stem and the cap
	# underside read against the sky. Positive pitch swings the 3.8 m spring arm below the
	# walker, so stay within 0-8 degrees and keep the underside centre below the top edge.
	var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - player._camera.global_position.y, to_root))
	var pitch: float = clampf(underside - 28.0, 0.0, 8.0)
	_look(hero, pitch)
	# Turn 10 degrees so the walker avatar (screen centre) does not cover the root base.
	player.camera_yaw += deg_to_rad(10.0)
	await _frames(12)
	var clearance: float = _camera_clearance()
	# Depiction: the root base (8 m up) and lower stem (60 m up) project inside the frame, and
	# neither rendered terrain nor any copied-tree/forest instance bounds block the view.
	var cam: Camera3D = player._camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var screens: Array = []
	var on_screen: bool = true
	var avatar_x: float = cam.unproject_position(player.global_position + Vector3.UP * 0.5).x
	var beside_avatar: bool = true
	for target: Vector3 in _root_targets():
		var screen: Vector2 = cam.unproject_position(target)
		screens.append([screen.x, screen.y])
		on_screen = on_screen and not cam.is_position_behind(target) and screen.x > 0.0 and screen.y > 0.0 and screen.x < size.x and screen.y < size.y
		beside_avatar = beside_avatar and absf(screen.x - avatar_x) >= 70.0
	var blockers: Array = _root_view_blockers(cam.global_position)
	var ok: bool = clearance > 0.05 and on_screen and beside_avatar and blockers.is_empty()
	approach_info = {"avatar_screen_x":avatar_x,"root_beside_avatar":beside_avatar,"player":_v(player.global_position),"camera":_v(cam.global_position),"camera_clearance_m":clearance,"distance_to_hero_centre_m":to_root,"pitch_deg":pitch,"root_targets_on_screen":on_screen,"root_targets_screen":screens,"blockers":blockers.slice(0, 5),"blocker_count":blockers.size(),"tree_boxes_tested":_tree_boxes.size(),"depicts_root":ok}
	await _capture(prefix + ("root-approach-day" if ok else "FAILED-root-approach-day"))

func _root_targets() -> Array:
	var hero: Vector3 = scenery.hero.base
	return [hero + Vector3.UP * 8.0, hero + Vector3.UP * 60.0]

## Approximate follow-camera position once it is aimed at the hero (3.8 m arm behind).
func _expected_camera(p: Vector3) -> Vector3:
	var away: Vector3 = Vector3(p.x - scenery.hero.base.x, 0.0, p.z - scenery.hero.base.z).normalized()
	return p + Vector3.UP * 0.7 + away * 3.8

## What blocks the view from eye to the root targets: rendered terrain (outside the hero's
## own 60 m mound) and the world bounds of every visible prototype MultiMesh instance (copied
## trees, forest carpet, other giants' stems), excluding the hero's own stem.
func _root_view_blockers(eye: Vector3) -> Array:
	if _tree_boxes.is_empty():
		var stack: Array = [scenery]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			var instance: MultiMeshInstance3D = node as MultiMeshInstance3D
			if instance == null or instance.multimesh == null or instance.multimesh.mesh == null: continue
			var local: AABB = instance.multimesh.mesh.get_aabb()
			var centre: Vector3 = instance.global_transform * instance.get_aabb().get_center()
			for i: int in instance.multimesh.instance_count:
				_tree_boxes.append({"box":(instance.global_transform * instance.multimesh.get_instance_transform(i)) * local, "node":String(instance.name), "centre":centre, "begin":instance.visibility_range_begin, "end":instance.visibility_range_end})
	var hero: Vector3 = scenery.hero.base
	var blockers: Array = []
	for target: Vector3 in _root_targets():
		for k: int in range(1, 100):
			var at: Vector3 = eye.lerp(target, k / 100.0)
			if Vector2(at.x - hero.x, at.z - hero.z).length() < 60.0: break
			var ground: float = scenery.rendered_terrain_height(at.x, at.z)
			if not is_nan(ground) and ground > at.y:
				blockers.append({"terrain":_v(at)})
				break
		for entry: Dictionary in _tree_boxes:
			# The hero's own stem instance is the target, not an obstruction.
			var box_centre: Vector3 = (entry.box as AABB).get_center()
			if Vector2(box_centre.x - hero.x, box_centre.z - hero.z).length() < 60.0: continue
			var d: float = eye.distance_to(entry.centre)
			if (entry.begin > 0.0 and d < entry.begin) or (entry.end > 0.0 and d > entry.end): continue
			if (entry.box as AABB).intersects_segment(eye, target):
				blockers.append({"instance":entry.node, "box_centre":_v((entry.box as AABB).get_center())})
	return blockers

## Documented reachable endpoint: the last slice sample at least 2.5 m before the point where
## the centreline (0.6 m above the tread) first meets the hero-root collider surface.
func _reachable_endpoint() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for i: int in range(1, slice._p.size()):
		# Only the root body counts; any other collider on the segment is skipped past.
		var exclude: Array[RID] = [player.get_rid()]
		var hit: Dictionary = {}
		for attempt: int in 4:
			hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(slice._p[i - 1] + Vector3.UP * 0.6, slice._p[i] + Vector3.UP * 0.6, 1, exclude))
			if hit.is_empty() or hit.collider == scenery.root_body: break
			exclude.append(hit.rid)
		if hit.is_empty() or hit.collider != scenery.root_body: continue
		var surface: Vector3 = hit.position
		var j: int = i - 1
		while j > 0 and Vector2(slice._p[j].x - surface.x, slice._p[j].z - surface.z).length() < 2.5: j -= 1
		return {"index":j, "point":_v(slice._p[j]), "root_surface":_v(surface), "surface_segment":i, "clearance_to_root_m":Vector2(slice._p[j].x - surface.x, slice._p[j].z - surface.z).length(), "samples":slice._p.size()}
	return {}

## Input-driven contact probe from the reachable endpoint: forward input toward the stem
## must be stopped by the hero-root body itself (contact within 1.5 m), grounded, on the
## corridor, with no recovery.
func _contact_probe(label: String) -> Dictionary:
	var hero: Vector3 = scenery.hero.base
	var probe: Dictionary = await _drive([Vector3(hero.x, player.global_position.y, hero.z)], label, 900, true)
	var eye: Vector3 = player.global_position + Vector3.UP * 0.6
	var contact: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, Vector3(hero.x, eye.y, hero.z), 1, [player.get_rid()]))
	var distance: float = (contact.position as Vector3).distance_to(eye) if not contact.is_empty() else INF
	var root_hit: bool = not contact.is_empty() and contact.collider == scenery.root_body and distance <= 1.5
	var ok: bool = probe.stalled and not probe.recovered and root_hit and probe.end_floor and probe.end_state == "Grounded" and scenery.allows_movement(player.global_position)
	return {"passed":ok, "stalled":probe.stalled, "recovered":probe.recovered, "root_body_hit":root_hit, "contact_m":distance, "end":probe.end, "grounded":probe.end_floor, "on_corridor":scenery.allows_movement(player.global_position), "ticks":probe.ticks}

func _place(point: Vector3, yaw: float) -> void:
	# Harness placement on the tread (teleport_safe intentionally refuses route points).
	_release()
	player.global_position = point + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.camera_yaw = yaw
	player._camera_pivot.global_position = player.global_position + Vector3.UP * 0.70
	await _frames(40)

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in range(arguments.size()-1):
		if arguments[index] == "--report-dir": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	player = game.player
	scenery = game.get("prototype_scenery")
	route = scenery.route if is_instance_valid(scenery) else null
	slice = scenery.slice_route if is_instance_valid(scenery) else null
	var built: bool = is_instance_valid(route) and route.valid and is_instance_valid(slice) and slice.valid and is_instance_valid(scenery.root_body)
	if _check("Existing route, connected slice and hero-root collider are built", built, scenery.slice_report if is_instance_valid(scenery) else null):
		game.ui.hide()
		if "--junction" in arguments: await _junction_scenario()
		elif "--endpoint" in arguments: await _endpoint_scenario()
		elif "--path-pairs" in arguments: await _path_pairs_scenario()
		elif "--understory-pairs" in arguments: await _understory_pairs_scenario()
		elif "--rock-pairs" in arguments: await _rock_pairs_scenario()
		elif "--stem-pairs" in arguments: await _stem_pairs_scenario()
		elif "--look-pairs" in arguments: await _look_pairs_scenario()
		elif "--shore-pairs" in arguments: await _shore_pairs_scenario()
		elif "--water-pairs" in arguments: await _water_pairs_scenario()
		elif "--water-motion" in arguments: await _water_motion_scenario()
		elif "--geology-diag" in arguments: await _geology_diag_scenario()
		elif "--geology" in arguments: await _geology_scenario()
		elif "--camera-sweep" in arguments: await _camera_sweep_scenario()
		elif "--cap-pairs" in arguments: await _cap_pairs_scenario("shape" if "--cap-shape" in arguments else ("leaf" if "--leaf-craft" in arguments else "craft"))
		else: await _scenario()
	_release()
	var passed := not checks.is_empty()
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"schema":"mush-slice-traversal/1","mode":"geology-diag" if "--geology-diag" in arguments else "geology" if "--geology" in arguments else "junction-local" if "--junction" in arguments else ("endpoint-local" if "--endpoint" in arguments else ("path-pairs" if "--path-pairs" in arguments else ("understory-pairs" if "--understory-pairs" in arguments else ("rock-pairs" if "--rock-pairs" in arguments else ("stem-pairs" if "--stem-pairs" in arguments else ("look-pairs" if "--look-pairs" in arguments else ("shore-pairs" if "--shore-pairs" in arguments else ("water-pairs" if "--water-pairs" in arguments else ("water-motion" if "--water-motion" in arguments else (("cap-shape-pairs" if "--cap-shape" in arguments else ("leaf-pairs" if "--leaf-craft" in arguments else "cap-pairs")) if "--cap-pairs" in arguments else "full")))))))))),"passed":passed,"checks":checks,"legs":legs,"images":images,"motion_steps":motion_steps,"slice_report":scenery.slice_report if is_instance_valid(scenery) else null,"physics":"fixed 60 Hz steps (--fixed-fps 60), presentation uncapped","input":"Input.action_press move_forward with camera_yaw steering","harness_placements":"boundary probes start from harness-placed tread points; the main and return legs are continuous","manual_feel_verified":false,"motion_quality_verified":false,"performance_measured":false,"saves_reloaded_in_new_process":false}
	var file := FileAccess.open(output.path_join("slice.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SLICE_TRAVERSAL_COMPLETE ", JSON.stringify({"passed":passed,"checks":checks.size()}))
	game._quit_clean(0 if passed else 1)

## Local, reproducible junction test (harness-placed start; NOT continuous clearing-to-root
## proof): real input across the seam onto the slice and back, on three lateral lines; then a
## supported walk below y -1.5 on the slice, and a step-off there that must still recover.
func _junction_scenario() -> void:
	# Let the game's own start-up spawn teleport settle before any harness placement.
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	var junction: Vector3 = route.get_end_point()
	var a: float = route.surface_height_at(junction.x, junction.z)
	var b: float = slice.surface_height_at(junction.x, junction.z)
	_check("Junction surfaces within 3 cm and slice starts at the junction", not is_nan(a) and not is_nan(b) and absf(a - b) <= 0.03 and slice.get_start_point().distance_to(junction) <= 0.05, {"existing":a,"slice":b,"start":_v(slice.get_start_point())})
	# Cross-section consistency: across the whole width, the existing route's last ring and the
	# slice's first ring leave no collision gap and no overlap (the render uses the same
	# triangles), and no height step along any line (5 mm steps, +-25 cm about the junction).
	var seam_heading: Vector3 = route.get_end_direction()
	var seam_side := Vector3(-seam_heading.z, 0.0, seam_heading.x)
	var seam_half: float = route._tread_half + route._shoulder
	var seam_space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var seam_worst := {"gap_m":0.0, "gap_lateral":null, "overlap_m":0.0, "overlap_lateral":null, "step_m":0.0, "step_lateral":null}
	var seam_across: float = -seam_half + 0.05
	while seam_across <= seam_half - 0.05 + 0.0001:
		var run: int = 0
		var overlap: int = 0
		var last_y: float = NAN
		for k: int in range(-50, 51):
			var at: Vector3 = junction + seam_heading * (k * 0.005) + seam_side * seam_across
			var hit: Dictionary = seam_space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1))
			var on: bool = not hit.is_empty() and (hit.collider == route._body or hit.collider == slice._body)
			run = 0 if on else run + 1
			if run * 0.005 > seam_worst.gap_m:
				seam_worst.gap_m = run * 0.005
				seam_worst.gap_lateral = seam_across
			if not on: continue
			var under: Dictionary = seam_space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1, [hit.rid]))
			if not under.is_empty() and under.collider != hit.collider and (under.collider == route._body or under.collider == slice._body) and absf((under.position as Vector3).y - (hit.position as Vector3).y) < 0.05:
				overlap += 1
			var y: float = (hit.position as Vector3).y
			if not is_nan(last_y) and absf(y - last_y) > seam_worst.step_m:
				seam_worst.step_m = absf(y - last_y)
				seam_worst.step_lateral = seam_across
			last_y = y
		if overlap * 0.005 > seam_worst.overlap_m:
			seam_worst.overlap_m = overlap * 0.005
			seam_worst.overlap_lateral = seam_across
		seam_across += 0.1
	_check("Junction cross-section: no collision/render gap > 5 mm, overlap <= 1 cm, step <= 1 cm across the full width", seam_worst.gap_m <= 0.005 and seam_worst.overlap_m <= 0.01 and seam_worst.step_m <= 0.01, seam_worst)
	var back_from: int = route._p.size() - 1
	while back_from > 0 and route._p[back_from].distance_to(junction) < 15.0: back_from -= 1
	var ahead_to: int = 0
	while ahead_to < slice._p.size() - 1 and slice._p[ahead_to].distance_to(junction) < 30.0: ahead_to += 1
	for lateral: float in [0.0, -1.2, 1.2]:
		var line_out: Array = []
		var line_back: Array = []
		for i: int in range(back_from, route._p.size()): line_out.append(_offset(route._p, i, lateral))
		for i: int in range(1, ahead_to + 1): line_out.append(_offset(slice._p, i, lateral))
		for i: int in range(ahead_to, 0, -1): line_back.append(_offset(slice._p, i, lateral))
		for i: int in range(route._p.size() - 1, back_from - 1, -1): line_back.append(_offset(route._p, i, lateral))
		var start: Vector3 = line_out[0]
		var next: Vector3 = line_out[1]
		await _place(start, atan2(-(next.x - start.x), -(next.z - start.z)))
		var out: Dictionary = await _drive(line_out, "junction-out-%+.1f" % lateral, 6000)
		_check("Junction %+.1f m: route -> slice crossing, no stall/recovery, grounded, no fall" % lateral, out.reached and not out.recovered and not out.stuck and out.floor_ratio >= 0.97 and out.max_drop_per_tick < 0.25, {"end":out.end,"ticks":out.ticks,"stuck_at":out.get("stuck_at"),"floor":out.floor_ratio})
		var ret: Dictionary = await _drive(line_back, "junction-back-%+.1f" % lateral, 6000)
		_check("Junction %+.1f m: slice -> route crossing, no stall/recovery, grounded, no fall" % lateral, ret.reached and not ret.recovered and not ret.stuck and ret.floor_ratio >= 0.97 and ret.max_drop_per_tick < 0.25, {"end":ret.end,"ticks":ret.ticks,"stuck_at":ret.get("stuck_at"),"floor":ret.floor_ratio})
	# Below the old y -1.5 guard: supported walking continues; leaving the corridor recovers.
	var low: int = -1
	for i: int in slice._p.size():
		if slice._p[i].y < -6.0:
			low = i
			break
	if _check("Slice has a section below y -6 m", low >= 0):
		var stop: int = low
		while stop < slice._p.size() - 1 and slice._p[stop].distance_to(slice._p[low]) < 30.0: stop += 1
		var line: Array = []
		for i: int in range(low + 1, stop + 1): line.append(slice._p[i])
		await _place(slice._p[low], atan2(-(slice._p[low + 1].x - slice._p[low].x), -(slice._p[low + 1].z - slice._p[low].z)))
		var deep: Dictionary = await _drive(line, "below-guard-walk", 3000)
		_check("Supported walk below y -1.5 on the slice: no recovery, grounded", deep.reached and not deep.recovered and not deep.stuck and deep.floor_ratio >= 0.97, {"from_y":slice._p[low].y,"end":deep.end,"ticks":deep.ticks})
		var lp: Vector3 = slice._p[low]
		var side: Vector3 = Vector3(slice._p[low + 1].x - lp.x, 0, slice._p[low + 1].z - lp.z).normalized().cross(Vector3.UP)
		await _place(lp, atan2(-side.x, -side.z))
		var off: Dictionary = await _drive([lp + side * 10.0], "below-guard-step-off", 900)
		_check("Stepping off the slice below y -1.5 still recovers into the original box", off.recovered and not player._outside_original_box(player.global_position) and player.is_on_floor(), {"recovered_at":off.get("recovered_at"),"end":off.end})
	_check("Save position still inside the original box", not player._outside_original_box(player.safe_position), _v(player.safe_position))

## Focused endpoint verification (HARNESS-PLACED start 440 m from the hero centre; NOT
## continuous clearing-to-root proof): walk to the documented endpoint with real input,
## landmark frame on the way, input-driven root contact probe, then a 60 m return walk.
func _endpoint_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	var endpoint: Dictionary = _reachable_endpoint()
	if not _check("Documented reachable endpoint found before the root surface", not endpoint.is_empty(), endpoint): return
	var e: int = int(endpoint.index)
	var s: int = e
	var hero_base: Vector3 = scenery.hero.base
	while s > 0 and Vector2(slice._p[s].x - hero_base.x, slice._p[s].z - hero_base.z).length() < 440.0: s -= 1
	await _place(slice._p[s], atan2(-(slice._p[s + 1].x - slice._p[s].x), -(slice._p[s + 1].z - slice._p[s].z)))
	var line: Array = []
	for i: int in range(s + 3, e, 3): line.append(slice._p[i])
	line.append(slice._p[e])
	var leg: Dictionary = await _drive(line, "endpoint-approach", 24000)
	_check("(harness-placed) Walk reaches the documented endpoint, no recovery/stall, grounded, no fall", leg.reached and not leg.recovered and not leg.stuck and leg.floor_ratio >= 0.97 and leg.max_drop_per_tick < 0.25, {"start_index":s,"end":leg.end,"ticks":leg.ticks})
	_check("(harness-placed) Root landmark frame from the path, camera outside geometry, root stem in frame and unoccluded", approach_captured and approach_info.get("depicts_root", false), approach_info)
	if not leg.reached:
		_check("(harness-placed) Contact probe skipped: documented endpoint not reached", false, leg.end)
		return
	var contact: Dictionary = await _contact_probe("endpoint-contact-probe")
	_check("(harness-placed) Contact probe: stopped by the hero-root body within 1.5 m, grounded, on corridor, no recovery", contact.passed, contact)
	var hero: Vector3 = scenery.hero.base
	_look(hero + Vector3.UP * 60.0, 35.0)
	await _frames(6)
	await _capture("endpoint-root-contact-day" if contact.passed else "endpoint-FAILED-root-contact-at-%d_%d-day" % [roundi(player.global_position.x), roundi(player.global_position.z)])
	var back: Array = [slice._p[e]]
	var r: int = e
	while r > 0 and slice._p[r].distance_to(slice._p[e]) < 60.0: r -= 1
	for i: int in range(e - 3, r - 1, -3): back.append(slice._p[i])
	var ret: Dictionary = await _drive(back, "endpoint-return", 6000)
	_check("(harness-placed) Return 60 m from the root, no recovery/stall, grounded", ret.reached and not ret.recovered and not ret.stuck and ret.floor_ratio >= 0.97, {"end":ret.end,"ticks":ret.ticks})

## Path-look evidence (diagnostic; HARNESS-PLACED at poses recorded by real walks): the same
## pose and frame captured with the previous earth material ("before", rebuilt exactly as it
## was in 3058e28) and with the current path material ("after"). Only the ribbon material
## differs between the two frames of a pair.
const PAIR_POSES := [
	# slice-20261026-070902-96139 slice-root-approach-day / slice-shore-day; route-20261026-072355-96790 route-overlook-day
	["root-approach", Vector3(386.89, -78.71, -284.54)],
	["shore", Vector3(387.12, -78.01, -300.14)],
	["knoll-overlook", Vector3(72.7724, 26.6973, 214.5524)],
]

func _path_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	var current: Material = route._mesh_instance.material_override
	var legacy := StandardMaterial3D.new()
	legacy.albedo_texture = preload("res://assets/world/textures/rock_01_diff_1k.jpg")
	legacy.albedo_color = Color(0.86, 0.66, 0.48)
	legacy.uv1_triplanar = true
	legacy.uv1_world_triplanar = true
	legacy.uv1_scale = Vector3.ONE * 0.22
	legacy.roughness = 0.95
	legacy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_check("Both ribbons share the path material", current is ShaderMaterial and slice._mesh_instance.material_override == current)
	var hero: Vector3 = scenery.hero.base
	for pose: Array in PAIR_POSES:
		var at: Vector3 = pose[1]
		await _place(at, 0.0)
		match pose[0]:
			"root-approach":
				var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
				var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
				_look(hero, clampf(underside - 28.0, 0.0, 8.0))
				player.camera_yaw += deg_to_rad(10.0)
			"shore":
				_look(Vector3(190.0, -80.0, -330.0), -4.0)
			"knoll-overlook":
				_look(Vector3(110.0, 0.0, -500.0), -9.0)
		# Walking pose: the walker faces along the camera, as in the walk frames.
		player._visual.rotation.y = player.camera_yaw
		await _frames(45)
		for state: Array in [["before", legacy], ["after", current]]:
			route._mesh_instance.material_override = state[1]
			slice._mesh_instance.material_override = state[1]
			await _frames(4)
			await _capture("path-%s-%s-day" % [pose[0], state[0]])
		_check("Pair %s captured at the recorded pose (within 0.3 m), camera clear" % pose[0], player.global_position.distance_to(at) < 0.3 and _camera_clearance() > 0.05, {"player":_v(player.global_position), "recorded":_v(at), "camera_clearance_m":_camera_clearance()})
	route._mesh_instance.material_override = current
	slice._mesh_instance.material_override = current

## Corridor understory evidence (diagnostic; HARNESS-PLACED): before = the replaced forest
## clumps shown and the understory hidden (the previous look), after = the shipped state; same
## pose and frame. Two recorded walk poses plus two offset views for 3D composition. Each
## capture records the engine's own frame counters (primitives, draw calls, objects).
func _understory_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	var report: Dictionary = scenery.understory_report
	_check("Corridor understory built: clearing assets, budget <= 4,000 instances / 300,000 triangles, no colliders or shadows", report.get("built", false) and int(report.instances) <= 4000 and int(report.triangles) <= 300000 and scenery.replaced_carpet != null and not scenery.replaced_carpet.visible, report)
	var clear := true
	for asset: String in report.get("min_lateral_m", {}):
		clear = clear and float(report.min_lateral_m[asset]) >= float(report.min_lateral_required_m[asset]) - 0.001
	_check("No plant inside its clearance from the path centre (tread edge 1.8 m)", clear, report.get("min_lateral_m"))
	var attach: Dictionary = report.get("attachment", {})
	_check("Attachment: every plant's mesh floor at or below the rendered surface under it (reported corner lift is the independent measure)", float(attach.get("max_base_above_surface_m", 1.0)) <= 0.0, attach)
	var hero: Vector3 = scenery.hero.base
	var shore_i: int = _nearest_sample(Vector3(387.12, -78.01, -300.14))
	var root_i: int = _nearest_sample(Vector3(386.89, -78.71, -284.54))
	var poses: Array = [
		["root-approach", Vector3(386.89, -78.71, -284.54), hero, 0.0, -1.0],
		["shore", Vector3(387.12, -78.01, -300.14), Vector3(190.0, -80.0, -330.0), 0.0, -4.0],
		["shore-offset", slice._p[shore_i - 4], slice._p[shore_i] + Vector3(-8.0, 0.0, 0.0), 0.0, -6.0],
		["root-offset", slice._p[root_i + 5], hero, -30.0, 2.0],
		["bank-closeup", slice._p[_nearest_sample(Vector3(392.0, -78.0, -325.0))], null, 0.0, -12.0]]
	for pose: Array in poses:
		var at: Vector3 = pose[1]
		await _place(at, 0.0)
		if pose[0] == "bank-closeup":
			# Attachment view: from the path, square to the inland (east) verge bank.
			var i: int = _nearest_sample(at)
			var along: Vector3 = (slice._p[i + 1] - slice._p[i - 1]).normalized()
			var east: Vector3 = Vector3(-along.z, 0.0, along.x) * (1.0 if -along.z > 0.0 else -1.0)
			_look(at + east * 10.0, pose[4])
		elif pose[0] == "root-approach":
			var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
			var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
			_look(hero, clampf(underside - 28.0, 0.0, 8.0))
			player.camera_yaw += deg_to_rad(10.0)
		else:
			_look(pose[2], pose[4])
			player.camera_yaw += deg_to_rad(pose[3])
		player._visual.rotation.y = player.camera_yaw
		await _frames(45)
		for state: String in ["before", "after"]:
			_set_corridor_state(state == "after")
			await _frames(6)
			await _capture("understory-%s-%s-day" % [pose[0], state])
			images[images.size() - 1]["plants"] = _plant_visibility() if state == "after" else null
			images[images.size() - 1]["blobs"] = _visible_blobs() if state == "after" else null
			images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}
		_check("Pair %s: placed on the path, camera clear" % pose[0], player.global_position.distance_to(at) < 0.3 and _camera_clearance() > 0.05, {"player":_v(player.global_position), "camera_clearance_m":_camera_clearance()})
		if pose[0] in ["root-approach", "shore", "root-offset"]:
			for state: String in ["before", "after"]:
				_set_corridor_state(state == "after")
				timings.append((await _time_view(30, 180)).merged({"pose": pose[0], "state": state}))
	_set_corridor_state(true)
	var drawn_ok := true
	for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
	_check("Viewpoint timing (uncapped, fixed-step, harness-placed; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Rock readability evidence (diagnostic; HARNESS-PLACED): picks the owner of the dark pixels
## by casting the camera ray through them against every prototype mesh's real triangles, then
## captures before (the new rock uniforms at their neutral defaults) and after in the same frame.
func _rock_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	var material: ShaderMaterial = scenery.rock_material
	var patch: GeometryInstance3D = scenery.get_node_or_null("CliffDetailPatch") as GeometryInstance3D
	_check("Cliff detail patch (the picked owner) carries the region-masked readability uniforms", material != null and patch != null and patch.material_override == material and (material.get_shader_parameter("rock_focus_rect") as Vector4).z > (material.get_shader_parameter("rock_focus_rect") as Vector4).x, scenery.get_report().rock_readability)
	var hero: Vector3 = scenery.hero.base
	var root_i: int = _nearest_sample(Vector3(386.89, -78.71, -284.54))
	var poses: Array = [
		["root-approach", Vector3(386.89, -78.71, -284.54), [Vector2(1060, 150), Vector2(1010, 300)]],
		["root-offset", slice._p[root_i + 5], [Vector2(610, 130), Vector2(620, 260)]],
		["rock-offset", slice._p[root_i - 30], [Vector2(640, 250), Vector2(760, 200)]]]
	for pose: Array in poses:
		var at: Vector3 = pose[1]
		await _place(at, 0.0)
		if pose[0] == "root-approach":
			var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
			var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
			_look(hero, clampf(underside - 28.0, 0.0, 8.0))
			player.camera_yaw += deg_to_rad(10.0)
		elif pose[0] == "root-offset":
			_look(hero, 2.0)
			player.camera_yaw += deg_to_rad(-30.0)
		else:
			_look(Vector3(555.0, 0.0, -640.0), 6.0)
		player._visual.rotation.y = player.camera_yaw
		await _frames(45)
		var picks: Array = []
		for pixel: Vector2 in pose[2]: picks.append(_pick(pixel))
		for state: String in ["before", "after"]:
			for key: String in scenery.ROCK_READABILITY: material.set_shader_parameter(key, (1.0 if key == "rock_albedo_lift" else 0.0) if state == "before" else scenery.ROCK_READABILITY[key])
			await _frames(6)
			await _capture("rock-%s-%s-day" % [pose[0], state])
			images[images.size() - 1]["picks"] = picks
			images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
		_check("Rock pose %s: placed on the path, camera clear; dark-pixel owners picked" % pose[0], player.global_position.distance_to(at) < 0.3 and _camera_clearance() > 0.05, picks)
	# Night and rain at the same poses: the shared appearance transition settles, then the same
	# before/after toggle (the fill must not light the cliff at night).
	for mood: Array in [["night", true, false], ["rain", false, true]]:
		game.world.set_appearance(mood[1], mood[2], false)
		await get_tree().create_timer(4.5).timeout
		for pose: Array in poses:
			await _place(pose[1], 0.0)
			if pose[0] == "root-approach":
				var to_root: float = Vector2(pose[1].x - hero.x, pose[1].z - hero.z).length()
				var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (pose[1].y + 0.7), to_root))
				_look(hero, clampf(underside - 28.0, 0.0, 8.0))
				player.camera_yaw += deg_to_rad(10.0)
			elif pose[0] == "root-offset":
				_look(hero, 2.0)
				player.camera_yaw += deg_to_rad(-30.0)
			else:
				_look(Vector3(555.0, 0.0, -640.0), 6.0)
			player._visual.rotation.y = player.camera_yaw
			await _frames(45)
			for state: String in ["before", "after"]:
				for key: String in scenery.ROCK_READABILITY: material.set_shader_parameter(key, (1.0 if key == "rock_albedo_lift" else 0.0) if state == "before" else scenery.ROCK_READABILITY[key])
				await _frames(6)
				await _capture("rock-%s-%s-%s" % [pose[0], state, mood[0]])
	game.world.set_appearance(false, false, false)
	for key: String in scenery.ROCK_READABILITY: material.set_shader_parameter(key, scenery.ROCK_READABILITY[key])

## Hero stem finish evidence (diagnostic): before (stem_organic 0) and after in the same frame at
## the harness-placed root approach and the established rim-overlook review camera, day and
## night, plus per-view frame timing before/after (same method as the understory pairs).
func _stem_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	var material: ShaderMaterial = scenery.stem_material
	var stems: GeometryInstance3D = scenery.get_node_or_null("CanopyStems") as GeometryInstance3D
	_check("Hero stem finish is on the CanopyStems material, masked to the hero base", material != null and stems != null and stems.material_override == material and (material.get_shader_parameter("stem_focus") as Vector4).z > 0.0, scenery.get_report().stem_finish)
	var hero: Vector3 = scenery.hero.base
	var pose: Dictionary = scenery.overlook_pose()
	var review := Camera3D.new()
	review.fov = pose.fov
	game.add_child(review)
	for mood: Array in [["day", false], ["night", true]]:
		game.world.set_appearance(mood[1], false, false)
		await get_tree().create_timer(4.5).timeout
		for view: String in ["root-approach", "overlook"]:
			if view == "root-approach":
				var at := Vector3(386.89, -78.71, -284.54)
				await _place(at, 0.0)
				var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
				var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
				_look(hero, clampf(underside - 28.0, 0.0, 8.0))
				player.camera_yaw += deg_to_rad(10.0)
				player._visual.rotation.y = player.camera_yaw
				player._camera.make_current()
			else:
				review.position = pose.position
				review.look_at(pose.target)
				review.make_current()
			await _frames(45)
			for state: String in ["before", "after"]:
				material.set_shader_parameter("stem_organic", 0.0 if state == "before" else scenery.STEM_ORGANIC)
				await _frames(6)
				await _capture("stem-%s-%s-%s" % [view, state, mood[0]])
				images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
				if mood[0] == "day":
					timings.append((await _time_view(30, 180)).merged({"pose": view, "state": state}))
	player._camera.make_current()
	review.queue_free()
	game.world.set_appearance(false, false, false)
	material.set_shader_parameter("stem_organic", scenery.STEM_ORGANIC)
	var drawn_ok := true
	for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
	_check("Viewpoint timing (uncapped, fixed-step; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Palette/depth evidence (diagnostic): previous look (look_depth false) and the new one in the
## same frame at the root approach, the shore, the rim-overlook review camera (day) and the root
## approach and overlook at night; per-view frame timing before/after at the three day views.
func _look_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	_check("Depth look present on the prototype (day endpoints only)", scenery.get("look_depth") != null and scenery.DEPTH_LOOK.size() == 6, scenery.get_report().depth_look)
	var hero: Vector3 = scenery.hero.base
	var pose: Dictionary = scenery.overlook_pose()
	var review := Camera3D.new()
	review.fov = pose.fov
	game.add_child(review)
	for mood: Array in [["day", false, ["root-approach", "shore", "overlook"]], ["night", true, ["root-approach", "overlook"]]]:
		game.world.set_appearance(mood[1], false, false)
		await get_tree().create_timer(4.5).timeout
		for view: String in mood[2]:
			if view == "overlook":
				review.position = pose.position
				review.look_at(pose.target)
				review.make_current()
			else:
				var at := Vector3(386.89, -78.71, -284.54) if view == "root-approach" else Vector3(387.12, -78.01, -300.14)
				await _place(at, 0.0)
				if view == "root-approach":
					var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
					var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
					_look(hero, clampf(underside - 28.0, 0.0, 8.0))
					player.camera_yaw += deg_to_rad(10.0)
				else:
					_look(Vector3(190.0, -80.0, -330.0), -4.0)
				player._visual.rotation.y = player.camera_yaw
				player._camera.make_current()
			await _frames(45)
			for state: String in ["before", "after"]:
				scenery.look_depth = state == "after"
				await _frames(12)
				await _capture("look-%s-%s-%s" % [view, state, mood[0]])
				images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
				if mood[0] == "day":
					timings.append((await _time_view(30, 180)).merged({"pose": view, "state": state}))
	player._camera.make_current()
	review.queue_free()
	scenery.look_depth = true
	game.world.set_appearance(false, false, false)
	var drawn_ok := true
	for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
	_check("Viewpoint timing (uncapped, fixed-step; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Opposite-shore vegetation evidence (diagnostic): at the shore walk pose, the rim overlook and an
## offset ground view along the east shore, every visible ForestCarpet clump is listed (owner,
## index, position, size, distance, screen box); when scenery.shore_groves exists, before (clumps
## shown, groves hidden) and after are captured in the same frame with per-view timing.
func _shore_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	var pose: Dictionary = scenery.overlook_pose()
	var review := Camera3D.new()
	review.fov = pose.fov
	game.add_child(review)
	var has_groves: bool = scenery.get("shore_groves") != null and is_instance_valid(scenery.shore_groves)
	var grove: Dictionary = scenery.get_report().get("shore_groves", {})
	_check("Opposite-shore groves built within budget (<= 150,000 triangles, <= 12 nodes), no colliders or shadows", grove.get("built", false) and int(grove.triangles) <= 150000 and int(grove.nodes) <= 12, grove)
	var offset_at: Vector3 = slice._p[_nearest_sample(Vector3(402.0, -78.0, -418.0))]
	var views: Array = [["shore", Vector3(387.12, -78.01, -300.14), Vector3(190.0, -80.0, -330.0), "day"], ["overlook", null, null, "day"], ["shore-offset", offset_at, Vector3(200.0, -80.0, -420.0), "day"]]
	if has_groves:
		for mood: String in ["night", "rain"]:
			views.append(["shore", Vector3(387.12, -78.01, -300.14), Vector3(190.0, -80.0, -330.0), mood])
			views.append(["overlook", null, null, mood])
	var current_mood: String = "day"
	for view: Array in views:
		if view[3] != current_mood:
			current_mood = view[3]
			game.world.set_appearance(current_mood == "night", current_mood == "rain", false)
			await get_tree().create_timer(4.5).timeout
		if view[1] == null:
			review.position = pose.position
			review.look_at(pose.target)
			review.make_current()
		else:
			await _place(view[1], 0.0)
			_look(view[2], -4.0)
			player._visual.rotation.y = player.camera_yaw
			player._camera.make_current()
		await _frames(45)
		for state: String in (["before", "after"] if has_groves else ["current"]):
			if has_groves: scenery.set_shore_groves(state == "after")
			await _frames(8)
			await _capture("shore-%s-%s-%s" % [view[0], state, view[3]])
			images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
			images[images.size() - 1]["clumps"] = _visible_clumps(view[0] == "overlook")
			if has_groves and view[3] == "day": timings.append((await _time_view(30, 180)).merged({"pose": view[0], "state": state}))
	player._camera.make_current()
	review.queue_free()
	game.world.set_appearance(false, false, false)
	if has_groves:
		scenery.set_shore_groves(true)
		var drawn_ok := true
		for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
		_check("Viewpoint timing (uncapped, fixed-step; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Lake material evidence (diagnostic): previous far_water look and the current lake shader in
## the same frame at the shore walk pose, an offset east-shore view and the rim overlook (day),
## then the shore and overlook at night; per-view frame timing in ABBA order at the day views.
func _water_pairs_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	_check("Lake surface uses the current lake shader", scenery.get_report().get("lake_water", {}).get("enabled", false), scenery.get_report().get("lake_water"))
	var pose: Dictionary = scenery.overlook_pose()
	var review := Camera3D.new()
	review.fov = pose.fov
	game.add_child(review)
	var offset_at: Vector3 = slice._p[_nearest_sample(Vector3(402.0, -78.0, -418.0))]
	var views: Array = [["shore", Vector3(387.12, -78.01, -300.14), Vector3(190.0, -80.0, -330.0), "day"], ["shore-offset", offset_at, Vector3(200.0, -80.0, -420.0), "day"], ["overlook", null, null, "day"],
		["shore", Vector3(387.12, -78.01, -300.14), Vector3(190.0, -80.0, -330.0), "night"], ["overlook", null, null, "night"]]
	var current_mood: String = "day"
	for view: Array in views:
		if view[3] != current_mood:
			current_mood = view[3]
			game.world.set_appearance(current_mood == "night", current_mood == "rain", false)
			await get_tree().create_timer(4.5).timeout
		if view[1] == null:
			review.position = pose.position
			review.look_at(pose.target)
			review.make_current()
		else:
			await _place(view[1], 0.0)
			_look(view[2], -4.0)
			player._visual.rotation.y = player.camera_yaw
			player._camera.make_current()
		await _frames(45)
		for state: String in ["before", "after"]:
			scenery.set_lake_water(state == "after")
			await _frames(8)
			await _capture("water-%s-%s-%s" % [view[0], state, view[3]])
			images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
		# Day cost: ABBA order (before, after, after, before) so drift cancels.
		if view[3] == "day":
			for state: String in ["before", "after", "after", "before"]:
				scenery.set_lake_water(state == "after")
				timings.append((await _time_view(30, 180)).merged({"pose": view[0], "state": state}))
	player._camera.make_current()
	review.queue_free()
	scenery.set_lake_water(true)
	game.world.set_appearance(false, false, false)
	var drawn_ok := true
	for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
	_check("Viewpoint timing (uncapped, fixed-step; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Lake reflection in motion (diagnostic): at the shore walk pose with ripple, wind and cloud
## motion frozen (camera motion is the only change), (A) the harness turns the follow camera's yaw
## 0 -> +20 -> -20 -> 0 degrees in 2-degree steps, and (B) the character strafes with real analog
## move input along the path, right 5 m, left 10 m, right 5 m, a frame every 0.5 m. Each step
## saves the bank-and-water band (rows 280-480, full width); key steps also save full frames.
func _water_motion_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	game.world.set_appearance(false, false, false)
	await get_tree().create_timer(4.5).timeout
	game.world.set_living_motion_enabled(false)
	game.environment_controller.set_foreground(false)
	game.world.set_environment_foreground(false)
	scenery.set_frozen(true)
	_check("Lake surface uses the current lake shader", scenery.get_report().get("lake_water", {}).get("enabled", false), scenery.get_report().get("lake_water"))
	var at := Vector3(387.12, -78.01, -300.14)
	await _place(at, 0.0)
	_look(Vector3(190.0, -80.0, -330.0), -4.0)
	var base_yaw: float = player.camera_yaw
	player._visual.rotation.y = base_yaw
	player._camera.make_current()
	await _frames(45)
	var steps: Array = []
	var yaws: Array = []
	for k: int in range(0, 11): yaws.append(k * 2.0)
	for k: int in range(9, -11, -1): yaws.append(k * 2.0)
	for k: int in range(-9, 1): yaws.append(k * 2.0)
	for i: int in yaws.size():
		player.camera_yaw = base_yaw + deg_to_rad(yaws[i])
		await _frames(4)
		steps.append(await _motion_frame("yaw", i, {"yaw_deg": yaws[i]}, yaws[i] in [20.0, -20.0] and not _saved_full("yaw", yaws[i])))
	player.camera_yaw = base_yaw
	await _frames(20)
	var right := Vector3(cos(base_yaw), 0.0, -sin(base_yaw))
	var start: Vector3 = player.global_position
	var legs: Array = [[1.0, 5.0], [-1.0, -5.0], [1.0, 0.0]]
	var index: int = 0
	var last_offset: float = 0.0
	var recovered := false
	var ticks: int = 0
	for leg: Array in legs:
		var sign: float = leg[0]
		var goal: float = leg[1]
		while ticks < 3000:
			var offset: float = (player.global_position - start).dot(right)
			if (sign > 0.0 and offset >= goal) or (sign < 0.0 and offset <= goal): break
			player.camera_yaw = base_yaw
			Input.action_press("move_right" if sign > 0.0 else "move_left", 0.6)
			Input.action_release("move_left" if sign > 0.0 else "move_right")
			await get_tree().physics_frame
			ticks += 1
			if player.state == "Recovering":
				recovered = true
				break
			offset = (player.global_position - start).dot(right)
			if absf(offset - last_offset) >= 0.5:
				last_offset = offset
				index += 1
				steps.append(await _motion_frame("strafe", index, {"offset_m": snappedf(offset, 0.01), "player": _v(player.global_position)}, absf(absf(offset) - 5.0) < 0.3 and not _saved_full("strafe", signf(offset))))
		_release()
		if recovered: break
	_release()
	_check("Strafe: physical left/right walk along the path with no recovery", not recovered and index >= 30, {"frames": index, "ticks": ticks})
	# Side-clamp extent (diagnostic tint): accepted reflection samples that needed the clamp.
	await _place(at, 0.0)
	var mat: ShaderMaterial = scenery._lake_material
	for yaw_deg: float in [0.0, 20.0, -20.0]:
		player.camera_yaw = base_yaw + deg_to_rad(yaw_deg)
		await _frames(30)
		mat.set_shader_parameter("debug_side_clamp", true)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		var name: String = "motion-clampmask-yaw%+03d.png" % roundi(yaw_deg)
		frame.save_png(output.path_join(name))
		var tinted: int = 0
		var columns: Dictionary = {}
		for y: int in range(300, 480, 2):
			for x: int in range(0, frame.get_width(), 2):
				var p: Color = frame.get_pixel(x, y)
				if p.r > 0.9 and p.b > 0.9 and p.g < 0.2:
					tinted += 1
					columns[x] = true
		var xs: Array = columns.keys()
		xs.sort()
		motion_steps.append({"kind": "clampmask", "yaw_deg": yaw_deg, "band": name, "tinted_samples": tinted, "sampled": 90 * frame.get_width() / 2, "columns_min_max": [xs.front() if not xs.is_empty() else null, xs.back() if not xs.is_empty() else null]})
		mat.set_shader_parameter("debug_side_clamp", false)
	_check("Motion frames captured (yaw sweep and strafe)", steps.size() >= 60, steps.size())
	motion_steps = steps + motion_steps
	scenery.set_frozen(false)

var _full_saved: Dictionary = {}
func _saved_full(kind: String, key: float) -> bool:
	return _full_saved.has("%s%+.0f" % [kind, key])

## Saves the bank-and-water band of the current frame (and optionally the full frame).
func _motion_frame(kind: String, index: int, meta: Dictionary, full: bool) -> Dictionary:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var name: String = "motion-%s-%03d.png" % [kind, index]
	frame.get_region(Rect2i(0, 280, frame.get_width(), 200)).save_png(output.path_join(name))
	var entry: Dictionary = meta.merged({"kind": kind, "index": index, "band": name, "band_rows": [280, 480], "camera": _v(player._camera.global_position)})
	if full:
		var key: String = "%s%+.0f" % [kind, float(meta.get("yaw_deg", signf(float(meta.get("offset_m", 0.0)))))]
		_full_saved[key] = true
		var full_name: String = "motion-full-%s-%03d.png" % [kind, index]
		frame.save_png(output.path_join(full_name))
		entry["full"] = full_name
	return entry

## Hero cap craft evidence (diagnostic): previous cap look and the current one in the same frame at
## the rim-overlook review camera, the recorded root-approach walk pose, and an offset under-cap
## view (review camera 1.7 m above a slice sample ~160 m from the hero, looking up at the gills),
## day and night; per-view frame timing in ABBA order by day.
func _cap_pairs_scenario(mode: String = "craft") -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	_check("Cap craft is on the hero cap material", scenery.get_report().get("cap_craft", {}).get("enabled", false), scenery.get_report().get("cap_craft"))
	var shape: bool = mode == "shape"
	var toggle: Callable = scenery.set_cap_shape if shape else (scenery.set_leaf_craft if mode == "leaf" else scenery.set_cap_craft)
	var prefix: String = "capshape" if shape else ("leaf" if mode == "leaf" else "cap")
	if mode == "leaf": _check("Foreground leaf craft mesh check: same leaves, vertices and triangles, finite, leaf bases fixed, no face flipped, no new degenerate faces", scenery.leaf_craft_report.get("passed", false) and scenery.leaf_craft, scenery.leaf_craft_report)
	if shape: _check("Hero cap shape mesh check: same topology, finite, closed seam, centre normals up/down, no face flipped against the previous cap, centre unchanged, degenerate triangles only in the unchanged centre fan", scenery.hero_cap_mesh_check.get("passed", false), scenery.hero_cap_mesh_check)
	var hero: Vector3 = scenery.hero.base
	var pose: Dictionary = scenery.overlook_pose()
	var review := Camera3D.new()
	game.add_child(review)
	var under_i: int = 0
	for i: int in slice._p.size():
		if absf(Vector2(slice._p[i].x - hero.x, slice._p[i].z - hero.z).length() - 160.0) < absf(Vector2(slice._p[under_i].x - hero.x, slice._p[under_i].z - hero.z).length() - 160.0): under_i = i
	var under_at: Vector3 = slice._p[under_i] + Vector3.UP * 1.7
	var toward: Vector3 = Vector3(hero.x - under_at.x, 0.0, hero.z - under_at.z).normalized()
	# Leaf offset: 8 m from the actual near crown closest to the right framing tree's spot
	# (forward 7 m, right 14 m of the overlook eye, as placed by _add_trees), from the eye's side.
	var offset_target := Vector3.ZERO
	var offset_at := Vector3.ZERO
	if mode == "leaf":
		var eye: Vector3 = pose.position
		var forward := Vector2(pose.target.x - eye.x, pose.target.z - eye.z).normalized()
		var right := Vector2(-forward.y, forward.x)
		var spot: Vector2 = Vector2(eye.x, eye.z) + forward * 7.0 + right * 14.0
		var best: float = INF
		for node: Node in scenery.get_children():
			if not node is MultiMeshInstance3D or node.get_meta("lod_range", "") != "near": continue
			var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
			for i: int in multi.instance_count:
				var at: Vector3 = ((node as MultiMeshInstance3D).global_transform * multi.get_instance_transform(i)).origin
				var gap: float = Vector2(at.x - spot.x, at.z - spot.y).length()
				if gap < best:
					best = gap
					offset_target = at
		offset_at = offset_target + Vector3(eye.x - offset_target.x, 0.0, eye.z - offset_target.z).normalized() * 8.0 + Vector3.UP * 0.5
		_check("Leaf offset view aims at an actual near crown of the right framing tree (within 6 m of its spot)", best < 6.0, {"crown": _v(offset_target), "spot": [spot.x, spot.y], "gap_m": best, "camera": _v(offset_at)})
	for mood: Array in [["day", false], ["night", true]]:
		game.world.set_appearance(mood[1], false, false)
		await get_tree().create_timer(4.5).timeout
		for view: String in (["overlook", "offset"] if mode == "leaf" else ["overlook", "root-approach", "under-cap"]):
			if view == "offset":
				review.fov = 60.0
				review.position = offset_at
				review.look_at(offset_target)
				review.make_current()
			elif view == "overlook":
				review.fov = pose.fov
				review.position = pose.position
				review.look_at(pose.target)
				review.make_current()
			elif view == "under-cap":
				review.fov = 60.0
				review.position = under_at
				review.look_at(under_at + toward * 60.0 + Vector3.UP * 75.0)
				review.make_current()
			else:
				var at := Vector3(386.89, -78.71, -284.54)
				await _place(at, 0.0)
				var to_root: float = Vector2(at.x - hero.x, at.z - hero.z).length()
				var underside: float = rad_to_deg(atan2(float(scenery.hero.position.y) - (at.y + 0.7), to_root))
				_look(hero, clampf(underside - 28.0, 0.0, 8.0))
				player.camera_yaw += deg_to_rad(10.0)
				player._visual.rotation.y = player.camera_yaw
				player._camera.make_current()
			await _frames(45)
			for state: String in ["before", "after"]:
				toggle.call(state == "after")
				await _frames(6)
				await _capture("%s-%s-%s-%s" % [prefix, view, state, mood[0]])
				images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
			if mood[0] == "day":
				for state: String in ["before", "after", "after", "before"]:
					toggle.call(state == "after")
					timings.append((await _time_view(30, 180)).merged({"pose": view, "state": state}))
	if mode == "leaf":
		# Facing diagnostic (day): magenta where a prototype leaf's shading normal faces away from
		# the viewer, green elsewhere; previous and current state at the same two views.
		game.world.set_appearance(false, false, false)
		await get_tree().create_timer(4.5).timeout
		scenery.set_leaf_facing_debug(true)
		for view: String in ["overlook", "offset"]:
			review.fov = pose.fov if view == "overlook" else 60.0
			review.position = pose.position if view == "overlook" else offset_at
			review.look_at(pose.target if view == "overlook" else offset_target)
			review.make_current()
			await _frames(30)
			for state: String in ["before", "after"]:
				toggle.call(state == "after")
				await _frames(6)
				await _capture("leaf-facing-%s-%s-day" % [view, state])
		scenery.set_leaf_facing_debug(false)
	player._camera.make_current()
	review.queue_free()
	toggle.call(true)
	game.world.set_appearance(false, false, false)
	var drawn_ok := true
	for timing: Dictionary in timings: drawn_ok = drawn_ok and int(timing.frames_drawn) == int(timing.samples)
	_check("Viewpoint timing (uncapped, fixed-step; NOT the route benchmark): engine drew every sampled frame", not timings.is_empty() and drawn_ok, timings)

## Geology landmark views (West Wall and Falls): the same fixed poses whether or not the landmark
## is built (MUSH_SCENERY_DIAG=no_geology builds the previous landform for the "before" run).
## Aims are fixed coordinates, not read from the wall, so both runs frame identical shots.
func _geology_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	var wall: Dictionary = scenery.get_report().get("escarpment", {})
	var skipped: bool = "no_geology" in scenery.diagnostic_skips
	if skipped: _check("Landmark skipped for the before run (MUSH_SCENERY_DIAG=no_geology)", not wall.get("built", false), wall)
	else:
		_check("West Wall: built, finite, face looks into the valley, falls clear of the face, route and giant caps clear of the toe", wall.get("passed", false), wall)
		var stream: Dictionary = scenery.get_report().get("stream", {})
		_check("Outlet stream: reaches the lake, water on the rendered channel floor, route and slice clear of the valley, crag base not carved", stream.get("passed", false), stream)
	_check("All seven giant footings unchanged (prototype footing check)", scenery.get_report().get("footing_ok", false), scenery.get_report().get("footing_ok"))
	var falls_aim := Vector3(-600.0, 140.0, -560.0)
	var knoll: Vector3 = route.get_end_point() + Vector3.UP * 1.7
	var shore := Vector3(387.12, -78.01 + 1.7, -300.14)
	var side := Vector3(-300.0, scenery.terrain_height(-300.0, -200.0) + 30.0, -200.0)
	var pose: Dictionary = scenery.overlook_pose()
	# Basin view (a new, labelled camera, not a matched pair): fixed in plan 260 m from the lake
	# centre toward the falls' basin, 2.5 m above the ground or water there, aimed at the basin.
	# Basin view (new, labelled camera): mid-ravine on the outlet stream looking upstream at the
	# basin; without the landmark (before run) a fixed fallback from the lake's west shore.
	var basin_pose: Dictionary = scenery.stream_view_pose()
	# Hero view (new, labelled camera): walkable knoll, looking north-west across the light.
	var hero_pose: Dictionary = scenery.hero_view_pose()
	var basin_xz := Vector2(-577.8, -448.5)
	var basin_eye: Vector3 = basin_pose.get("position", Vector3(-150.0, scenery.terrain_height(-150.0, -400.0) + 8.0, -400.0))
	var basin_aim: Vector3 = basin_pose.get("target", Vector3(basin_xz.x, 100.0, basin_xz.y))
	var views: Array = [["overlook", pose.position, pose.target, pose.fov], ["knoll", knoll, Vector3(-60.0, 60.0, -700.0), 60.0], ["shore", shore, falls_aim, 60.0],
		["side", side, Vector3(-600.0, 200.0, -800.0), 60.0], ["overview", Vector3(-320.0, 620.0, 520.0), Vector3(150.0, -40.0, -480.0), 62.0], ["basin", basin_eye, basin_aim, 60.0], ["hero", hero_pose.get("position", knoll), hero_pose.get("target", Vector3(-560.0, 170.0, -560.0)), 55.0],
		# Vista (new, labelled camera; composition chosen by a camera sweep, 172824/173142): creature
		# eye on the walkable slice east of the lake, looking WNW across the lake to the falls with
		# the hero giant's cap framing the upper right (the concept's refuge/vista relationship).
		["vista", Vector3(350.0, scenery.rendered_terrain_height(350.0, 100.0) + 1.7, 100.0), Vector3(-300.0, 90.0, -760.0), 60.0]]
	var review := Camera3D.new()
	review.far = 2600.0
	game.add_child(review)
	for mood: Array in [["day", false, false], ["night", true, false], ["rain", false, true]]:
		game.world.set_appearance(mood[1], mood[2], false)
		await get_tree().create_timer(4.5).timeout
		for view: Array in views:
			if mood[0] == "night" and not view[0] in ["overlook", "knoll", "shore", "hero", "vista"]: continue
			if mood[0] == "rain" and not view[0] in ["overlook", "shore", "hero", "vista"]: continue
			scenery.set_overview(view[0] == "overview")
			review.fov = view[3]
			review.position = view[1]
			review.look_at(view[2])
			review.make_current()
			await _frames(30)
			await _capture("geo-%s-%s" % [view[0], mood[0]])
			images[images.size() - 1]["frame"] = {"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "camera": _v(review.position), "aim": _v(view[2])}
	scenery.set_overview(false)
	player._camera.make_current()
	review.queue_free()
	game.world.set_appearance(false, false, false)
	_check("Geology views captured (day 8 incl. the basin, hero and vista views, night 5, rain 4)", images.size() == 17, images.size())

## Composition exploration only (not an acceptance check): renders candidate review cameras
## listed in MUSH_SWEEP as JSON [[label, [x, z], eye_height_m, [tx, ty, tz], fov, mood], ...],
## eye placed eye_height_m above the rendered terrain (or the lake surface, if higher);
## mood is "day", "night" or "rain". Captures are named sweep-<label>-<mood>.png.
func _camera_sweep_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	var specs: Variant = JSON.parse_string(OS.get_environment("MUSH_SWEEP"))
	if not _check("Sweep poses supplied (MUSH_SWEEP JSON list)", specs is Array and not (specs as Array).is_empty(), OS.get_environment("MUSH_SWEEP")): return
	var review := Camera3D.new()
	review.far = 2600.0
	game.add_child(review)
	var mood_now: String = ""
	for spec: Array in specs:
		var mood: String = str(spec[5]) if spec.size() > 5 else "day"
		if mood != mood_now:
			game.world.set_appearance(mood == "night", mood == "rain", false)
			await get_tree().create_timer(4.5).timeout
			mood_now = mood
		var ground: float = maxf(scenery.rendered_terrain_height(float(spec[1][0]), float(spec[1][1])), -82.0)
		review.fov = float(spec[4])
		review.position = Vector3(float(spec[1][0]), ground + float(spec[2]), float(spec[1][1]))
		review.look_at(Vector3(float(spec[3][0]), float(spec[3][1]), float(spec[3][2])))
		review.make_current()
		await _frames(30)
		await _capture("sweep-%s-%s" % [str(spec[0]), mood])
		images[images.size() - 1]["frame"] = {"camera": _v(review.position), "aim": spec[3], "fov": spec[4]}
	player._camera.make_current()
	review.queue_free()
	game.world.set_appearance(false, false, false)
	_check("Sweep views captured", images.size() == (specs as Array).size(), images.size())

## Controlled geology diagnosis at the shore and side poses (day): the same frame in the final
## rendering, without depth fog, as unlit albedo, as world normals, as uniform grey lit by the
## scene (with and without fog) and as a flat rock/ice mask; then the final rendering is restored.
func _geology_diag_scenario() -> void:
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	var wall: Dictionary = scenery.get_report().get("escarpment", {})
	_check("West Wall built for diagnosis", wall.get("passed", false), wall.get("passed"))
	var views: Array = [["shore", Vector3(387.12, -78.01 + 1.7, -300.14), Vector3(-600.0, 140.0, -560.0)], ["side", Vector3(-300.0, scenery.terrain_height(-300.0, -200.0) + 30.0, -200.0), Vector3(-600.0, 200.0, -800.0)]]
	# fog-previous: the same final rendering with the previous fog profile (matched atmosphere pair).
	var states: Array = [["final", 0, false], ["fog-previous", 0, false], ["nofog", 0, true], ["albedo", 1, true], ["normal", 2, true], ["greylit", 3, false], ["greylit-nofog", 3, true], ["mask", 4, true]]
	var review := Camera3D.new()
	review.far = 2600.0
	review.fov = 60.0
	game.add_child(review)
	game.world.set_appearance(false, false, false)
	await get_tree().create_timer(4.5).timeout
	for view: Array in views:
		review.position = view[1]
		review.look_at(view[2])
		review.make_current()
		await _frames(30)
		for state: Array in states:
			scenery.atmosphere_previous = state[0] == "fog-previous"
			scenery.set_geology_debug(state[1], state[2])
			await _frames(8)
			await _capture("geodiag-%s-%s" % [view[0], state[0]])
	scenery.atmosphere_previous = false
	scenery.set_geology_debug(0, false)
	await _frames(4)
	player._camera.make_current()
	review.queue_free()
	_check("Final rendering restored after diagnosis (debug view 0, fog on, current atmosphere)", scenery.geology_debug == 0 and not scenery._debug_fog_off and not scenery.atmosphere_previous, {"debug": scenery.geology_debug, "fog_off": scenery._debug_fog_off, "atmosphere_previous": scenery.atmosphere_previous})
	_check("Diagnosis frames captured (2 views x 8 states)", images.size() == 16, images.size())

## Visible forest-carpet clumps for the current camera: in range, in front, projected box share
## >= 0.0003 of the frame, centre not hidden by rendered terrain; sorted by screen share.
func _visible_clumps(review_camera: bool) -> Array:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var found: Array = []
	for node: Node in scenery.get_children():
		var instance: MultiMeshInstance3D = node as MultiMeshInstance3D
		if instance == null or not instance.is_visible_in_tree() or not String(instance.name).begins_with("ForestCarpet_"): continue
		var local: AABB = instance.multimesh.mesh.get_aabb()
		for i: int in instance.multimesh.instance_count:
			var pose: Transform3D = instance.global_transform * instance.multimesh.get_instance_transform(i)
			var box: AABB = pose * local
			var centre: Vector3 = box.get_center()
			var distance: float = cam.global_position.distance_to(centre)
			if distance > 900.0 or cam.is_position_behind(centre): continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for k: int in 8:
				var corner: Vector3 = box.get_endpoint(k)
				if cam.is_position_behind(corner): continue
				var p: Vector2 = cam.unproject_position(corner)
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			lo = lo.clamp(Vector2.ZERO, size)
			hi = hi.clamp(Vector2.ZERO, size)
			var share: float = (hi.x - lo.x) * (hi.y - lo.y) / (size.x * size.y)
			if share < 0.0003: continue
			var hidden := false
			for k: int in range(1, 24):
				var on: Vector3 = cam.global_position.lerp(centre, k / 24.0)
				var ground: float = scenery.terrain_height(on.x, on.z)
				if ground > on.y + 1.0:
					hidden = true
					break
			if hidden: continue
			found.append({"owner": String(instance.name), "index": i, "position": _v(pose.origin), "size": _v(box.size), "distance_m": snappedf(distance, 0.1), "screen_box": [roundi(lo.x), roundi(lo.y), roundi(hi.x), roundi(hi.y)], "screen_share": snappedf(share, 0.0001)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.screen_share > b.screen_share)
	return found

## Owner of the surface under a screen pixel: nearest hit of the camera ray against the real
## triangles of every visible prototype mesh and multimesh instance (bounding boxes first).
func _pick(pixel: Vector2) -> Dictionary:
	var cam: Camera3D = player._camera
	var from: Vector3 = cam.project_ray_origin(pixel)
	var dir: Vector3 = cam.project_ray_normal(pixel)
	var best := {"pixel": [pixel.x, pixel.y], "owner": null, "distance_m": INF}
	for node: Node in scenery.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if not geometry.is_visible_in_tree(): continue
		var poses: Array = []
		var mesh: Mesh = null
		if geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
			var multi: MultiMesh = (geometry as MultiMeshInstance3D).multimesh
			mesh = multi.mesh
			for i: int in multi.instance_count: poses.append([i, geometry.global_transform * multi.get_instance_transform(i)])
		elif geometry is MeshInstance3D:
			mesh = (geometry as MeshInstance3D).mesh
			poses.append([0, geometry.global_transform])
		if mesh == null: continue
		var faces: PackedVector3Array = PackedVector3Array()
		for entry: Array in poses:
			var pose: Transform3D = entry[1]
			if (pose * mesh.get_aabb()).intersects_ray(from, dir) == null: continue
			if faces.is_empty(): faces = mesh.get_faces()
			var local_from: Vector3 = pose.affine_inverse() * from
			var local_dir: Vector3 = (pose.affine_inverse().basis * dir).normalized()
			for k: int in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(local_from, local_dir, faces[k], faces[k + 1], faces[k + 2])
				if hit == null: continue
				var world: Vector3 = pose * (hit as Vector3)
				var distance: float = from.distance_to(world)
				if distance < float(best.distance_m):
					best = {"pixel": [pixel.x, pixel.y], "owner": String(geometry.name), "instance": entry[0], "hit": _v(world), "distance_m": snappedf(distance, 0.1)}
	return best

func _set_corridor_state(after: bool) -> void:
	scenery.replaced_carpet.visible = not after
	scenery.understory.visible = after
	for node: MultiMeshInstance3D in scenery.corridor_trees: node.visible = after

## Frame timing at the current view: warmup frames, then per-frame wall time between process
## frames, Godot's measured viewport render time (CPU, and GPU where the driver reports it),
## and the engine's drawn-frame counter, which must advance once per sample.
func _time_view(warmup: int, samples: int) -> Dictionary:
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	await _frames(warmup)
	var walls: Array = []
	var cpus: Array = []
	var gpus: Array = []
	await RenderingServer.frame_post_draw
	var drawn_before: int = Engine.get_frames_drawn()
	var last: int = Time.get_ticks_usec()
	for i: int in samples:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		walls.append((now - last) / 1000.0)
		last = now
		cpus.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu())
		gpus.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	var drawn: int = Engine.get_frames_drawn() - drawn_before
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	var pct := func(values: Array, q: float) -> float:
		var sorted: Array = values.duplicate()
		sorted.sort()
		return snappedf(float(sorted[mini(int(ceil(q * sorted.size())) - 1, sorted.size() - 1)]), 0.001)
	var gpu_available: bool = float(pct.call(gpus, 0.95)) > 0.0
	return {"samples": samples, "warmup": warmup, "frames_drawn": drawn, "wall_p50_ms": pct.call(walls, 0.5), "wall_p95_ms": pct.call(walls, 0.95),
		"render_cpu_p50_ms": pct.call(cpus, 0.5), "render_cpu_p95_ms": pct.call(cpus, 0.95), "render_gpu_p95_ms": pct.call(gpus, 0.95) if gpu_available else null, "gpu_timing_available": gpu_available,
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}

## Plants actually depicted: in the camera frustum, projected taller than 20 px, and with an
## unblocked line of sight over the rendered terrain (sampled along the ray).
func _plant_visibility() -> Dictionary:
	var cam: Camera3D = player._camera
	var focal: float = get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var result := {"in_frustum": 0, "over_20px": 0, "depicted": 0, "depicted_by_asset": {}, "nearest_depicted_m": INF}
	for node: Node in scenery.understory.get_children():
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var height: float = multi.mesh.get_aabb().size.y
		var asset: String = node.get_meta("asset", "")
		for i: int in multi.instance_count:
			var pose: Transform3D = (node as Node3D).global_transform * multi.get_instance_transform(i)
			var tall: float = height * pose.basis.get_scale().y
			var top: Vector3 = pose.origin + Vector3.UP * tall * 0.6
			if not cam.is_position_in_frustum(top): continue
			result.in_frustum += 1
			var distance: float = cam.global_position.distance_to(top)
			if tall / distance * focal < 20.0: continue
			result.over_20px += 1
			var blocked := false
			for k: int in range(1, 12):
				var on: Vector3 = cam.global_position.lerp(top, k / 12.0)
				var ground: float = scenery.rendered_terrain_height(on.x, on.z)
				if not is_nan(ground) and ground > on.y + 0.02:
					blocked = true
					break
			if blocked: continue
			result.depicted += 1
			result.depicted_by_asset[asset] = int(result.depicted_by_asset.get(asset, 0)) + 1
			result.nearest_depicted_m = minf(result.nearest_depicted_m, distance)
	return result

## Large prototype vegetation instances actually in view (forest-carpet clumps and copied-tree
## parts): owner node, world position and size, camera distance, projected screen box and its
## share of the frame, and whether the rendered terrain hides its centre. Sorted by screen share.
func _visible_blobs() -> Array:
	var cam: Camera3D = player._camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var found: Array = []
	for node: Node in scenery.get_children():
		var instance: MultiMeshInstance3D = node as MultiMeshInstance3D
		if instance == null or not instance.visible or instance.multimesh == null: continue
		var owner_name := String(instance.name)
		if not (owner_name.begins_with("ForestCarpet_") or owner_name.begins_with("CopiedTrees_") or owner_name.begins_with("CorridorTrees_")): continue
		var local: AABB = instance.multimesh.mesh.get_aabb()
		for i: int in instance.multimesh.instance_count:
			var pose: Transform3D = instance.global_transform * instance.multimesh.get_instance_transform(i)
			var box: AABB = pose * local
			var centre: Vector3 = box.get_center()
			var distance: float = cam.global_position.distance_to(centre)
			if distance > 400.0: continue
			var d_end: float = instance.visibility_range_end
			if (d_end > 0.0 and cam.global_position.distance_to(instance.global_position) > d_end) or cam.global_position.distance_to(instance.global_position) < instance.visibility_range_begin: continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			var any_front := false
			for k: int in 8:
				var corner: Vector3 = box.get_endpoint(k)
				if cam.is_position_behind(corner): continue
				any_front = true
				var p: Vector2 = cam.unproject_position(corner)
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			if not any_front: continue
			lo = lo.clamp(Vector2.ZERO, size)
			hi = hi.clamp(Vector2.ZERO, size)
			var share: float = (hi.x - lo.x) * (hi.y - lo.y) / (size.x * size.y)
			if share < 0.004: continue
			var hidden := false
			for k: int in range(1, 16):
				var on: Vector3 = cam.global_position.lerp(centre, k / 16.0)
				var ground: float = scenery.rendered_terrain_height(on.x, on.z)
				if not is_nan(ground) and ground > on.y + 0.5:
					hidden = true
					break
			found.append({"owner": owner_name, "index": i, "position": _v(pose.origin), "size": _v(box.size), "distance_m": snappedf(distance, 0.1), "screen_box": [roundi(lo.x), roundi(lo.y), roundi(hi.x), roundi(hi.y)], "screen_share": snappedf(share, 0.0001), "centre_hidden_by_terrain": hidden})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.screen_share > b.screen_share)
	return found.slice(0, 25)

func _nearest_sample(at: Vector3) -> int:
	var best: int = 0
	for i: int in slice._p.size():
		if slice._p[i].distance_to(at) < slice._p[best].distance_to(at): best = i
	return best

func _offset(points: PackedVector3Array, i: int, lateral: float) -> Vector3:
	var a: Vector3 = points[maxi(i - 1, 0)]
	var b: Vector3 = points[mini(i + 1, points.size() - 1)]
	var side: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized().cross(Vector3.UP)
	return points[i] + side * lateral

func _scenario() -> void:
	# --- static checks on the installed geometry
	var junction: Vector3 = route.get_end_point()
	var a: float = route.surface_height_at(junction.x, junction.z)
	var b: float = slice.surface_height_at(junction.x, junction.z)
	# The module starts each ribbon join_overlap (0.2 m) behind its first point, at the same height.
	var overlap: float = float(scenery.slice_report.get("join_overlap_m", 0.2))
	_check("Junction: slice starts on the existing route's end (within its join overlap), surfaces within 3 cm", not is_nan(a) and not is_nan(b) and absf(a - b) <= 0.03 and slice.get_start_point().distance_to(junction) <= overlap + 0.05 and absf(slice.get_start_point().y - junction.y) <= 0.03, {"existing":a,"slice":b,"start":_v(slice.get_start_point()),"junction":_v(junction),"join_overlap_m":overlap})
	var intrusion: float = -INF
	var gap: float = -INF
	var worst: Array = []
	for k: int in range(0, slice._p.size() - 1):
		var p0: Vector3 = slice._p[k]
		var p1: Vector3 = slice._p[k + 1]
		var along: Vector3 = Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		for lateral: float in [-1.7, 0.0, 1.7]:
			var at: Vector3 = p0 + side * lateral
			var surface: float = slice.surface_height_at(at.x, at.z)
			var rendered: float = scenery.rendered_terrain_height(at.x, at.z)
			if is_nan(surface) or is_nan(rendered): continue
			if Vector2(at.x - 378.0, at.z + 648.0).length() < 75.0: continue  # inside the hero root (hidden)
			if rendered - surface > intrusion:
				intrusion = rendered - surface
				worst = _v(at)
			if lateral == 0.0: gap = maxf(gap, surface - rendered)
	_check("Rendered terrain never rises over the slice tread (<= 2 cm)", intrusion <= 0.02, {"max_intrusion_m":intrusion,"at":worst,"max_tread_above_rendered_ground_m":gap})
	var existing_intrusion: float = -INF
	var existing_at: Array = []
	var existing_over: Array = []
	for p: Vector3 in route._p:
		var r: float = scenery.rendered_terrain_height(p.x, p.z)
		var s: float = route.surface_height_at(p.x, p.z)
		if is_nan(r) or is_nan(s): continue
		if r - s > 0.02: existing_over.append([snappedf(p.x, 0.1), snappedf(p.z, 0.1), snappedf(r - s, 0.01)])
		if r - s > existing_intrusion:
			existing_intrusion = r - s
			existing_at = _v(p)
	# Pre-slice baseline e78e73f measured 0.04 m (3 samples over 2 cm) with this method.
	_check("Existing route centreline: rendered terrain no higher than its pre-slice 0.04 m", existing_intrusion <= 0.045, {"max_intrusion_m":existing_intrusion,"at":existing_at,"samples_over_2cm":existing_over,"pre_slice_baseline_m":0.04})
	var m: int = slice._p.size() / 3
	var lateral_dir: Vector3 = Vector3(slice._p[m + 1].x - slice._p[m].x, 0, slice._p[m + 1].z - slice._p[m].z).normalized().cross(Vector3.UP)
	_check("Slice corridor is exact: on it yes, 8 m beside it (perpendicular) no", scenery.allows_movement(slice._p[m] + Vector3.UP * 0.1) and not scenery.allows_movement(slice._p[m] + lateral_dir * 8.0 + Vector3.UP * 0.1) and not scenery.allows_movement(slice._p[m] - lateral_dir * 8.0 + Vector3.UP * 0.1))
	_check("Original movement box itself unchanged", player._outside_original_box(Vector3(0,0.1,27.0)) and not player._outside_original_box(Vector3(0,0.1,25.9)) and player._outside_original_box(Vector3(21,0.1,0)))
	var footing: Dictionary = scenery.get_report().landform_checks
	_check("All seven giant footings unchanged (drift <= 0.01 m)", float(footing.giant_footing_drift_m) <= 0.01, footing.giant_footing_drift_m)
	# --- continuous walk: original box -> existing route -> junction -> slice -> root
	game.world.set_appearance(false, false, false)
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _frames(60)
	_check("Start grounded inside the original box", player.is_on_floor() and not player._outside_original_box(player.global_position), _v(player.global_position))
	var endpoint: Dictionary = _reachable_endpoint()
	if not _check("Documented reachable endpoint found before the root surface", not endpoint.is_empty(), endpoint): return
	var seam: Vector3 = route.get_start_point()
	var targets: Array = [Vector3(seam.x, seam.y, 27.5)]
	for i: int in range(0, route._p.size(), 4): targets.append(route._p[i])
	targets.append(junction)
	for i: int in range(2, int(endpoint.index), 3): targets.append(slice._p[i])
	targets.append(slice._p[int(endpoint.index)])
	var walk: Dictionary = await _drive(targets, "clearing-to-root", 90000)
	var hero: Vector3 = scenery.hero.base
	_check("Continuous walk: clearing -> route -> junction -> whole slice -> documented endpoint, no recovery", walk.reached and not walk.recovered and not walk.stuck, {"end":walk.end,"ticks":walk.ticks,"travel_m":walk.travel_m,"endpoint":endpoint,"stuck_at":walk.get("stuck_at")})
	_check("Grounded for at least 97% of walk ticks", walk.floor_ratio >= 0.97, walk.floor_ratio)
	_check("No fall: largest per-tick drop under 0.25 m", walk.max_drop_per_tick < 0.25, walk.max_drop_per_tick)
	_check("Camera never inside a collider or below the rendered ground", walk.min_camera_clearance > 0.05, walk.min_camera_clearance)
	_check("Shore frame captured during the walk", shore_captured)
	_check("Root landmark frame captured from the path, camera outside geometry, root stem in frame and unoccluded", approach_captured and approach_info.get("depicts_root", false), approach_info)
	if not walk.reached:
		_check("Contact probe skipped: documented endpoint not reached", false, walk.end)
		return
	var contact: Dictionary = await _contact_probe("root-contact-probe")
	_check("Contact probe: forward input stopped by the hero-root body within 1.5 m, grounded, on corridor, no recovery", contact.passed, contact)
	_check("Save position stays inside the original box after the walk", not player._outside_original_box(player.safe_position), _v(player.safe_position))
	var saved: Array = game._snapshot().player.position
	_check("Saved player position is the in-box safe position, not the slice", not player._outside_original_box(Vector3(saved[0], saved[1], saved[2])), saved)
	_look(hero + Vector3.UP * 60.0, 35.0)
	await _frames(6)
	# The file name states what was achieved: root contact, or the failed stop location.
	await _capture("slice-root-contact-day" if contact.passed else "slice-FAILED-root-contact-at-%d_%d-day" % [roundi(player.global_position.x), roundi(player.global_position.z)])
	# --- return walk: from the documented endpoint back to the knoll junction
	var back: Array = [slice._p[int(endpoint.index)]]
	for i: int in range(int(endpoint.index) - 3, -1, -3): back.append(slice._p[i])
	back.append(junction)
	var ret: Dictionary = await _drive(back, "root-to-junction", 70000)
	_check("Return walk reaches the knoll junction without recovery", ret.reached and not ret.recovered and not ret.stuck, {"end":ret.end,"ticks":ret.ticks,"stuck_at":ret.get("stuck_at")})
	_check("Return walk grounded >= 97% with no fall", ret.floor_ratio >= 0.97 and ret.max_drop_per_tick < 0.25, {"floor_ratio":ret.floor_ratio,"max_drop":ret.max_drop_per_tick})
	_check("Return walk camera clearance", ret.min_camera_clearance > 0.05, ret.min_camera_clearance)
	# --- Float on the shoreline
	var shore_index: int = 0
	for i: int in slice._p.size():
		if slice._p[i].z < -300.0 and slice._p[i].x > 300.0:
			shore_index = i
			break
	var sp: Vector3 = slice._p[shore_index]
	var sn: Vector3 = slice._p[shore_index + 1]
	var along: Vector3 = Vector3(sn.x - sp.x, 0, sn.z - sp.z).normalized()
	await _place(sp, atan2(-along.x, -along.z))
	var float_states: Array = []
	Input.action_press("float")
	for _i: int in 60:
		await get_tree().physics_frame
		if not player.state in float_states: float_states.append(player.state)
	Input.action_release("float")
	await _frames(120)
	_check("Float on the shoreline ends grounded without recovery", player.is_on_floor() and player.state == "Grounded" and not "Recovering" in float_states, float_states)
	# --- boundaries: lake side of the shore, and the descent's downhill shoulder
	var lake_dir: Vector3 = (Vector3(190.0, sp.y, -330.0) - sp)
	lake_dir.y = 0.0
	lake_dir = lake_dir.normalized()
	await _place(sp, atan2(-lake_dir.x, -lake_dir.z))
	var wade: Dictionary = await _drive([sp + lake_dir * 16.0], "shore-into-lake", 900)
	_check("Lake side: stepping off the shore corridor recovers into the original box", wade.recovered and not player._outside_original_box(player.global_position) and player.is_on_floor(), {"recovered_at":wade.get("recovered_at"),"end":wade.end})
	var bench: int = slice._p.size() / 4
	var bp: Vector3 = slice._p[bench]
	var bn: Vector3 = slice._p[bench + 1]
	var bside: Vector3 = Vector3(bn.x - bp.x, 0, bn.z - bp.z).normalized().cross(Vector3.UP)
	for probe: Array in [["descent-left", bside], ["descent-right", -bside]]:
		await _place(bp, atan2(-(probe[1] as Vector3).x, -(probe[1] as Vector3).z))
		var off: Dictionary = await _drive([bp + (probe[1] as Vector3) * 10.0], probe[0], 900)
		_check(probe[0] + ": stepping off the slice recovers into the original box", off.recovered and not player._outside_original_box(player.global_position) and player.is_on_floor(), {"recovered_at":off.get("recovered_at"),"end":off.end})
	# --- teleport/reload resolution never lands on the slice
	player.teleport_safe(sp, 0.0)
	await _frames(60)
	_check("teleport_safe to a slice point resolves into the original box", not player._outside_original_box(player.global_position) and player.is_on_floor(), _v(player.global_position))
