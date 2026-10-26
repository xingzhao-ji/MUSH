extends Node
## Real CharacterBody traversal of the prototype NaturalRoute with ordinary input
## (camera yaw + move_forward), from inside the original clearing box to the knoll
## overlook. Then: Float/Glow on the route, both shoulders and the open end (each from a
## harness-placed point on the tread), the save snapshot and teleport resolution.
## Captures prove depicted states only; this is automated input, not manual feel.
const SIZE := Vector2i(1280,720)
var game: Node
var player: CharacterBody3D
var scenery: Node
var route: Node3D
var output := "user://verification/route"
var checks: Array = []
var legs: Array = []
var images: Array = []

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _check(label: String, ok: bool, detail: Variant = null) -> bool:
	checks.append({"label":label,"passed":ok,"detail":detail})
	return ok

func _frames(count: int) -> void:
	for _i: int in count: await get_tree().physics_frame

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _release() -> void:
	for action: String in ["move_forward","move_back","move_left","move_right","float","glow"]:
		if InputMap.has_action(action): Input.action_release(action)

func _camera_clearance() -> float:
	var camera: Camera3D = player._camera
	var at: Vector3 = camera.global_position
	var floor_y: float = scenery.terrain_height(at.x, at.z)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.01, at + Vector3.DOWN * 60.0, 1))
	if not hit.is_empty(): floor_y = maxf(floor_y, (hit.position as Vector3).y)
	var inside := PhysicsPointQueryParameters3D.new()
	inside.position = at
	inside.collision_mask = 1
	if not game.get_world_3d().direct_space_state.intersect_point(inside, 1).is_empty(): return -1.0
	return at.y - floor_y

func _place(point: Vector3, yaw: float) -> void:
	# Harness placement on the tread (teleport_safe intentionally refuses route points).
	_release()
	player.global_position = point + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.camera_yaw = yaw
	player._camera_pivot.global_position = player.global_position + Vector3.UP * 0.70
	await _frames(40)

func _corridor_beside(at: Vector3, dir: Vector3) -> bool:
	for metres: float in [4.0, 5.5, 7.0, 8.5]:
		if scenery.allows_movement(at + dir * metres): return true
	return false

func _drive(targets: Array, label: String, max_ticks: int, expect_recovery: bool) -> Dictionary:
	var leg := {"label":label,"from":_v(player.global_position),"ticks":0,"floor_ticks":0,"recovered":false,"recovery_tick":-1,"min_camera_clearance":INF,"max_drop_per_tick":0.0,"max_y":-INF,"min_y":INF,"reached":false}
	var previous: Vector3 = player.global_position
	for target: Vector3 in targets:
		while leg.ticks < max_ticks:
			var offset: Vector3 = target - player.global_position
			offset.y = 0.0
			if offset.length() < 1.0: break
			player.camera_yaw = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward",1.0)
			await get_tree().physics_frame
			leg.ticks += 1
			var p: Vector3 = player.global_position
			if player.is_on_floor(): leg.floor_ticks += 1
			leg.max_drop_per_tick = maxf(leg.max_drop_per_tick, previous.y - p.y)
			leg.max_y = maxf(leg.max_y, p.y); leg.min_y = minf(leg.min_y, p.y)
			previous = p
			if leg.ticks % 6 == 0: leg.min_camera_clearance = minf(leg.min_camera_clearance, _camera_clearance())
			if player.state == "Recovering":
				leg.recovered = true; leg.recovery_tick = leg.ticks; leg.recovered_at = _v(p)
				break
		if leg.recovered: break
	_release()
	await _frames(40)
	var last: Vector3 = targets[targets.size()-1]
	leg.reached = not leg.recovered and Vector2(player.global_position.x-last.x,player.global_position.z-last.z).length() < 2.0
	leg.end = _v(player.global_position)
	leg.end_state = player.state
	leg.end_floor = player.is_on_floor()
	leg.end_inside_original_box = not player._outside_original_box(player.global_position)
	leg.floor_ratio = float(leg.floor_ticks) / maxf(1.0,float(leg.ticks))
	leg.expect_recovery = expect_recovery
	legs.append(leg)
	return leg

func _capture(label: String) -> String:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(label+".png")
	frame.save_png(path)
	images.append({"file":label+".png","png_sha256":FileAccess.get_sha256(path),"size":[frame.get_width(),frame.get_height()]})
	return label+".png"

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
	var ok := _check("Prototype route built and wired as a movement-only extension", is_instance_valid(route) and route.valid and player.movement_extension == scenery, scenery.route_report if is_instance_valid(scenery) else null)
	if ok:
		await _scenario()
	_release()
	var passed := not checks.is_empty()
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"schema":"mush-route-traversal/1","passed":passed,"checks":checks,"legs":legs,"images":images,"route_report":scenery.route_report if is_instance_valid(scenery) else null,"input":"Input.action_press move_forward with camera_yaw steering, real physics ticks","harness_placements":"shoulder and end probes start from points placed on the tread; the main leg is continuous from the original box","manual_feel_verified":false,"motion_quality_verified":false,"performance_measured":false,"saves_reloaded_in_new_process":false}
	var file := FileAccess.open(output.path_join("route.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ROUTE_TRAVERSAL_COMPLETE ",JSON.stringify({"passed":passed,"checks":checks.size()}))
	game._quit_clean(0 if passed else 1)

func _scenario() -> void:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var start: Vector3 = route.get_start_point()
	var baked: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,5,start.z-0.3),Vector3(start.x,-5,start.z-0.3),1))
	var ribbon: float = route.surface_height_at(start.x,start.z+0.3)
	var step: float = absf((baked.position as Vector3).y - ribbon) if not baked.is_empty() and not is_nan(ribbon) else INF
	_check("Seam: ribbon meets the baked collider within 3 cm", step <= 0.03, {"baked_y":(baked.position as Vector3).y if not baked.is_empty() else null,"ribbon_y":ribbon,"step_m":step})
	_check("Original movement box itself unchanged", player._outside_original_box(Vector3(0,0.1,27.0)) and not player._outside_original_box(Vector3(0,0.1,25.9)) and player._outside_original_box(Vector3(21,0.1,0)))
	var m: int = route._p.size()/2
	var lateral: Vector3 = Vector3(route._p[m+1].x-route._p[m].x,0,route._p[m+1].z-route._p[m].z).normalized().cross(Vector3.UP)
	_check("Movement extension is exact: corridor yes, 8 m beside it (perpendicular) no", scenery.allows_movement(route._p[m] + Vector3.UP*0.1) and not scenery.allows_movement(route._p[m] + lateral*8.0 + Vector3.UP*0.1) and not scenery.allows_movement(route._p[m] - lateral*8.0 + Vector3.UP*0.1))
	# 1. Continuous walk from inside the original box onto and up the route.
	player.teleport_safe(Vector3(-2.0,0.08,22.0),PI)
	await _frames(60)
	_check("Start grounded inside the original box", player.is_on_floor() and not player._outside_original_box(player.global_position), _v(player.global_position))
	var targets: Array = [Vector3(start.x,start.y,27.5)]
	var stride: int = maxi(1,int(route._p.size()/40))
	for i: int in range(0,route._p.size(),stride): targets.append(route._p[i])
	targets.append(route.get_end_point())
	var main: Dictionary = await _drive(targets,"clearing-to-knoll",9000,false)
	_check("Continuous walk reaches the knoll end with no recovery", main.reached and not main.recovered, {"end":main.end,"ticks":main.ticks})
	_check("Grounded for at least 97% of walk ticks", main.floor_ratio >= 0.97, main.floor_ratio)
	_check("No fall: largest per-tick drop under 0.25 m", main.max_drop_per_tick < 0.25, main.max_drop_per_tick)
	_check("Camera never inside a collider or below the visible ground", main.min_camera_clearance > 0.05, main.min_camera_clearance)
	_check("Save position stays inside the original box while on the route", not player._outside_original_box(player.safe_position), _v(player.safe_position))
	var snapshot: Dictionary = game._snapshot()
	var saved: Array = snapshot.player.position
	_check("Saved player position is the in-box safe position, not the route", not player._outside_original_box(Vector3(saved[0],saved[1],saved[2])), saved)
	# 2. Overlook still from the real player camera at the reached route end.
	game.ui.hide()
	var look: Vector3 = Vector3(110.0,0.0,-500.0) - player.global_position
	player.camera_yaw = atan2(-look.x,-look.z)
	player._camera_pitch = deg_to_rad(-9.0)
	game.world.set_appearance(false,false,false)
	await get_tree().create_timer(3.0).timeout
	_check("Overlook still taken from the reached end", main.reached, await _capture("route-overlook-day"))
	game.world.set_appearance(true,false,false)
	await get_tree().create_timer(4.5).timeout
	await _capture("route-overlook-night")
	game.world.set_appearance(false,false,false)
	await get_tree().create_timer(4.5).timeout
	game.ui.show()
	# 3. Repeated actions on the route: Glow twice, Float press/release.
	var glow_before: bool = player.glow_on
	Input.action_press("glow"); await _frames(3); Input.action_release("glow"); await _frames(10)
	Input.action_press("glow"); await _frames(3); Input.action_release("glow"); await _frames(10)
	_check("Glow toggles twice on the route and returns", player.glow_on == glow_before)
	var float_states: Array = []
	Input.action_press("float")
	for _i: int in 60:
		await get_tree().physics_frame
		if not player.state in float_states: float_states.append(player.state)
	Input.action_release("float")
	await _frames(120)
	_check("Float on the route ends grounded without recovery", player.is_on_floor() and not "Recovering" in float_states and player.state == "Grounded", float_states)
	# 4. Shoulders and open end: leaving the corridor recovers into the original box.
	var mid: int = route._p.size()/2
	var a: Vector3 = route._p[mid]
	var b: Vector3 = route._p[mid+1]
	var along: Vector3 = Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side := Vector3(-along.z,0,along.x)
	for probe: Array in [["left-shoulder",side],["right-shoulder",-side]]:
		await _place(a, atan2(-along.x,-along.z))
		var leg: Dictionary = await _drive([a + probe[1]*9.0],probe[0],900,true)
		_check(probe[0]+": stepping off the corridor recovers into the original box", leg.recovered and leg.end_inside_original_box and leg.end_floor and leg.min_y > a.y - 1.5, {"recovered_at":leg.get("recovered_at"),"end":leg.end,"min_y":leg.min_y})
	var end: Vector3 = route.get_end_point()
	var heading: Vector3 = route.get_end_direction()
	var slice: Node3D = scenery.get("slice_route")
	var connected: bool = is_instance_valid(slice) and slice.valid and slice.get_start_point().distance_to(end) <= 0.05
	await _place(end - heading*2.0, atan2(-heading.x,-heading.z))
	var over: Dictionary = await _drive([end + heading*8.0],"open-end",900,true)
	if connected:
		# Authorized topology change (PM decision): the old end is the connected slice's
		# junction, not an open fall edge. Walking past it must continue, grounded, onto the slice.
		_check("Junction (authorized topology change): walking past the old end continues grounded onto the connected slice", over.reached and not over.recovered and over.end_floor and slice.is_in_corridor(player.global_position), {"end":over.end,"recovered_at":over.get("recovered_at")})
		# Equivalent off-route recovery at the genuinely exposed edges there: the junction's
		# north-west side, and the outer side of the slice's summit loop.
		var k: int = 0
		while k < slice._p.size() - 2 and slice._p[k].distance_to(end) < 30.0: k += 1
		var d1: Vector3 = slice._p[k] - slice._p[k - 1]
		var d2: Vector3 = slice._p[k + 1] - slice._p[k]
		var outward: Vector3 = Vector3(d2.x, 0.0, d2.z).normalized().cross(Vector3.UP) * signf(d1.cross(d2).y)
		for probe: Array in [["junction-exposed-edge", end, Vector3(-heading.z, 0.0, heading.x)], ["summit-loop-outer-edge", slice._p[k], outward]]:
			# The probe side must be genuinely exposed: no walkable corridor 4-9 m out.
			var dir: Vector3 = probe[2]
			if _corridor_beside(probe[1], dir): dir = -dir
			if not _check(probe[0] + ": an exposed side exists (no corridor 4-9 m out)", not _corridor_beside(probe[1], dir), {"at":_v(probe[1])}): continue
			probe[2] = dir
			await _place(probe[1], atan2(-(probe[2] as Vector3).x, -(probe[2] as Vector3).z))
			var off: Dictionary = await _drive([(probe[1] as Vector3) + (probe[2] as Vector3) * 9.0], probe[0], 900, true)
			_check(probe[0] + ": stepping off recovers into the original box", off.recovered and off.end_inside_original_box and off.end_floor and off.min_y > (probe[1] as Vector3).y - 1.5, {"recovered_at":off.get("recovered_at"),"end":off.end})
	else:
		_check("Open end: walking past it recovers into the original box", over.recovered and over.end_inside_original_box and over.end_floor and over.min_y > end.y - 1.5, {"recovered_at":over.get("recovered_at"),"end":over.end})
	# 5. Teleport/reload resolution never lands on the route.
	player.teleport_safe(a,0.0)
	await _frames(60)
	_check("teleport_safe to a route point resolves into the original box", not player._outside_original_box(player.global_position) and player.is_on_floor(), _v(player.global_position))
