extends "res://scripts/player.gd"
# Detached upward-camera proposal; original source remains unchanged.
# Pitch limits -65/+65 degrees are proposed and tunable. Positive pitch looks
# upward in the existing rig; this expands the actual mouse/gamepad upper range.
# Base player SHA256: e77e1580865695eff313e064a55e2c6a62b67358702f5a7b58d35f7b1e8bf7fa

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _require_release or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		camera_yaw -= mouse.relative.x * 0.0025 * sensitivity
		var sign_y: float = -1.0 if invert_y else 1.0
		_camera_pitch -= mouse.relative.y * 0.0025 * sensitivity * sign_y
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-65.0), deg_to_rad(65.0))

func _update_gamepad_look(delta: float) -> void:
	for device: int in Input.get_connected_joypads():
		var look: Vector2 = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if look.length() < 0.18:
			continue
		look = look.limit_length(1.0)
		camera_yaw -= look.x * 2.2 * sensitivity * delta
		var sign_y: float = -1.0 if invert_y else 1.0
		_camera_pitch -= look.y * 1.7 * sensitivity * sign_y * delta
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-65.0), deg_to_rad(65.0))

# Fade only when native avatar bounds approach the camera near plane.
# AABBs conservatively include animated BoneAttachment transforms and scaling.
# Existing near-hit guard, .10s smoothing, recovery and camera physics remain.
func _process(delta: float) -> void:
	if not is_instance_valid(_camera_pivot):
		return
	if _indoor_override >= 0:
		_indoor = _indoor_override == 1
	elif _indoor:
		_indoor = _inside_camera_volume(global_position, 0.15)
	else:
		_indoor = _inside_camera_volume(global_position, -0.15)
	var target_arm: float = 2.2 if _indoor else 3.8
	_camera_nominal = lerpf(_camera_nominal, target_arm, 1.0 - exp(-delta / 0.40))
	var hit: float = _spring_arm.get_hit_length()
	var near_clearance: float = _avatar_near_clearance()
	var fade_target: float = maxf(0.92 if hit > 0.001 and hit < 0.35 else 0.0, 1.0 - smoothstep(0.08, 0.30, near_clearance))
	_camera_fade = lerpf(_camera_fade, fade_target, 1.0 - exp(-delta / 0.10))
	# A fast orbit can skip the soft band; hide intersecting bounds immediately.
	# Fade back in through the existing band/smoothing once the lens is clear.
	if near_clearance <= 0.0:
		_camera_fade = 1.0
	for mesh: MeshInstance3D in _meshes:
		mesh.transparency = maxf(_camera_fade, _recovery_fade)


func _avatar_near_clearance() -> float:
	var inverse: Transform3D = _camera.global_transform.affine_inverse()
	var clearance: float = INF
	for mesh: MeshInstance3D in _meshes:
		if not mesh.is_visible_in_tree():
			continue
		var bounds: AABB = mesh.get_aabb()
		var half_size: Vector3 = bounds.size * 0.5
		var camera_transform: Transform3D = inverse * mesh.global_transform
		var center: Vector3 = camera_transform * bounds.get_center()
		var extent: float = absf(camera_transform.basis.x.z) * half_size.x + absf(camera_transform.basis.y.z) * half_size.y + absf(camera_transform.basis.z.z) * half_size.z
		clearance = minf(clearance, -center.z - extent - _camera.near)
	return clearance
