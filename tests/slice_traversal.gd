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

func _ready() -> void:
	game = get_parent()
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
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
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
		else: await _scenario()
	_release()
	var passed := not checks.is_empty()
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"schema":"mush-slice-traversal/1","mode":"junction-local" if "--junction" in arguments else ("endpoint-local" if "--endpoint" in arguments else ("path-pairs" if "--path-pairs" in arguments else ("understory-pairs" if "--understory-pairs" in arguments else ("rock-pairs" if "--rock-pairs" in arguments else "full")))),"passed":passed,"checks":checks,"legs":legs,"images":images,"slice_report":scenery.slice_report if is_instance_valid(scenery) else null,"physics":"fixed 60 Hz steps (--fixed-fps 60), presentation uncapped","input":"Input.action_press move_forward with camera_yaw steering","harness_placements":"boundary probes start from harness-placed tread points; the main and return legs are continuous","manual_feel_verified":false,"motion_quality_verified":false,"performance_measured":false,"saves_reloaded_in_new_process":false}
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
