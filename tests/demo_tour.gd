extends Node
## Recorded demo tour (run with --capture --demo-tour, normally under Godot's --write-movie): the clearing and the
## player character (orbit, Glow, Float), a walk out along the route, the slice toward the hero root, the concept-1 vista by day, dusk into night, rain, a flight over the valley, and a closing wide view. Ordinary input drives the
## walks; a separate review camera flies the vista shots. Presentation only: no checks, no saves.
const SIZE := Vector2i(1280, 720)
const TICKS := 60.0
var game: Node
var player: CharacterBody3D
var scenery: Node
var route: Node3D
var slice: Node3D
var cam: Camera3D

func _ready() -> void:
	game = get_parent()
	_run.call_deferred()

func _frames(count: int) -> void:
	for _i: int in count: await get_tree().physics_frame

func _hold(seconds: float) -> void:
	await _frames(int(seconds * TICKS))

func _release() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "float", "glow"]:
		if InputMap.has_action(action): Input.action_release(action)

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)

## Walks through targets with ordinary input, turning the camera smoothly so the footage does not snap.
func _walk(targets: Array, seconds: float) -> void:
	var limit: int = int(seconds * TICKS)
	var ticks: int = 0
	for target: Vector3 in targets:
		var best: float = INF
		var since: int = 0
		while ticks < limit:
			var offset: Vector3 = target - player.global_position
			offset.y = 0.0
			if offset.length() < 1.5: break
			player.camera_yaw = lerp_angle(player.camera_yaw, atan2(-offset.x, -offset.z), 0.06)
			Input.action_press("move_forward", 1.0)
			await get_tree().physics_frame
			ticks += 1
			if offset.length() < best - 0.2:
				best = offset.length()
				since = 0
			else:
				since += 1
			if since > 240: break
		if ticks >= limit: break
	_release()

## Flies the review camera between two shots (position, target, fov), eased.
func _fly(a: Array, b: Array, seconds: float) -> void:
	cam.make_current()
	var n: int = maxi(1, int(seconds * TICKS))
	for i: int in n + 1:
		var t: float = smoothstep(0.0, 1.0, float(i) / float(n))
		var p: Vector3 = (a[0] as Vector3).lerp(b[0], t)
		var q: Vector3 = (a[1] as Vector3).lerp(b[1], t)
		cam.fov = lerpf(float(a[2]), float(b[2]), t)
		cam.position = p
		cam.look_at(q)
		await get_tree().physics_frame

func _shot(pos: Vector3, target: Vector3, fov: float) -> Array:
	return [pos, target, fov]

func _run() -> void:
	game.get_window().content_scale_size = SIZE
	game.get_window().size = SIZE
	player = game.player
	scenery = game.get("prototype_scenery")
	route = scenery.route if is_instance_valid(scenery) else null
	slice = scenery.slice_route if is_instance_valid(scenery) else null
	if is_instance_valid(game.ui): game.ui.hide()
	cam = Camera3D.new()
	cam.far = scenery.get_view_distance() if is_instance_valid(scenery) else 4000.0
	game.add_child(cam)
	game.world.set_appearance(false, false, false)
	print("DEMO_TOUR scene clearing")
	# 1. The clearing and the player character: an orbiting camera while it glows and floats.
	player.teleport_safe(Vector3(-2.0, 0.08, 22.0), PI)
	await _hold(1.5)
	var c: Vector3 = player.global_position
	cam.make_current()
	cam.fov = 55.0
	var orbit_n: int = int(12.0 * TICKS)
	for i: int in orbit_n + 1:
		var t: float = float(i) / float(orbit_n)
		var a: float = PI * 0.5 + TAU * smoothstep(0.0, 1.0, t)
		var r: float = lerpf(4.2, 7.5, t)
		cam.position = c + Vector3(sin(a) * r, lerpf(1.4, 3.2, t), cos(a) * r)
		cam.look_at(player.global_position + Vector3.UP * 0.7)
		if i == int(3.0 * TICKS): await _tap("glow")
		if i == int(6.0 * TICKS): Input.action_press("float")
		if i == int(8.5 * TICKS): Input.action_release("float")
		await get_tree().physics_frame
	await _tap("glow")
	player.camera_yaw = PI
	player._camera.make_current()
	await _hold(1.0)
	# 2. Out of the clearing along the existing route.
	print("DEMO_TOUR scene route")
	if is_instance_valid(route) and route.valid:
		var seam: Vector3 = route.get_start_point()
		var targets: Array = [Vector3(seam.x, seam.y, 27.5)]
		for i: int in range(0, route._p.size(), 4): targets.append(route._p[i])
		player._camera_pitch = deg_to_rad(-10.0)
		await _walk(targets, 24.0)
	# 3. The connected slice toward the hero root, then a look up at the giant.
	print("DEMO_TOUR scene slice")
	if is_instance_valid(slice) and slice.valid:
		var start: int = int(slice._p.size() * 0.55)
		var from: Vector3 = slice._p[start]
		var to: Vector3 = slice._p[mini(start + 1, slice._p.size() - 1)]
		player.teleport_safe(from + Vector3.UP * 0.1, atan2(-(to.x - from.x), -(to.z - from.z)))
		await _hold(1.0)
		var stargets: Array = []
		for i: int in range(start + 2, int(slice._p.size() * 0.85), 3): stargets.append(slice._p[i])
		await _walk(stargets, 16.0)
		await _hold(1.5)
	# (The rim overlook pose was tried here and dropped: in the concept-1 build it looks into the valley set at close
	# range, among the low-detail masses meant to be seen from the terrace.)
	# 4. The concept-1 vista by day: a pan from the home across the valley to the hero.
	print("DEMO_TOUR scene vista-day")
	var eye: Vector3 = scenery._vista_eye()
	var target: Vector3 = scenery._vista_target()
	var forward: Vector3 = (target - eye)
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var reach: float = Vector2(forward.x, forward.z).length()
	var left_shot: Array = _shot(eye, target - right * reach * 0.28 + Vector3.UP * 40.0, 60.0)
	var main_shot: Array = _shot(eye, target, 60.0)
	var right_shot: Array = _shot(eye, target + right * reach * 0.22 + Vector3.UP * 60.0, 60.0)
	var wide_shot: Array = _shot(eye, target, 95.0)
	await _fly(left_shot, left_shot, 2.0)
	await _fly(left_shot, main_shot, 7.0)
	await _hold(2.0)
	await _fly(main_shot, right_shot, 6.0)
	await _hold(1.5)
	await _fly(right_shot, main_shot, 5.0)
	await _hold(2.0)
	# 5. Dusk into night at the vista, then a slow push in.
	print("DEMO_TOUR scene night")
	game.world.set_appearance(true, false, false)
	await _hold(6.0)
	var push_shot: Array = _shot(eye.lerp(target, 0.06), target, 52.0)
	await _fly(main_shot, push_shot, 9.0)
	await _hold(2.0)
	await _fly(push_shot, right_shot, 6.0)
	await _hold(2.0)
	# 6. Rain over the valley (wide).
	print("DEMO_TOUR scene rain")
	game.world.set_appearance(false, true, false)
	await _fly(right_shot, wide_shot, 6.0)
	await _hold(5.0)
	# 7. Day again: a flight out from the terrace over the valley toward the hero.
	print("DEMO_TOUR scene flight")
	game.world.set_appearance(false, false, false)
	await _hold(2.5)
	var fly_a: Array = _shot(eye + Vector3.UP * 20.0, target, 62.0)
	var fly_b: Array = _shot(eye.lerp(target, 0.32) + Vector3.UP * 30.0, target + right * reach * 0.1, 66.0)
	await _fly(wide_shot, fly_a, 3.0)
	await _fly(fly_a, fly_b, 12.0)
	await _hold(2.0)
	# 8. Closing wide view of the valley by day.
	print("DEMO_TOUR scene closing")
	await _fly(wide_shot, main_shot, 7.0)
	await _hold(3.0)
	_release()
	player._camera.make_current()
	print("DEMO_TOUR_COMPLETE")
	game._quit_clean(0)
