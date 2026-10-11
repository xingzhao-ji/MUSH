class_name ClearingPlayer
extends CharacterBody3D
## A deliberately provisional articulated cream creature; final species and appearance are undecided.
## Feet are the controller origin. Animation never moves the collision body or camera target.

signal feedback(message: String)

const WALK_SPEED: float = 2.2
const FLOAT_SPEED: float = 1.6
const GRAVITY: float = 12.0
const FLOOR_COS: float = 0.819152
const WORLD_MASK: int = 1 | 4 | 16
const CAMERA_MASK: int = 1 | 4 | 16 | 32
const FIXED_RECOVERY: Vector3 = Vector3(-2.0, 0.0, 12.0)
const AIR_STATES: Array[String] = ["Rising", "Hovering", "Descending"]

var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if not enabled:
			release_controls()
var glow_on: bool = false
var float_toggle: bool = false
var sensitivity: float = 1.0
var invert_y: bool = false
var reduced_motion: bool = false
var reduced_effects: bool = false
var touch_hover_latched := false
var _touch_hover_pressed := false
var state: String = "Grounded"
var safe_position: Vector3 = FIXED_RECOVERY
var camera_yaw: float = 0.0

var _visual: Node3D
var _skeleton: Skeleton3D
var _animator: AnimationPlayer
var _glow_animator: AnimationPlayer
var _light: OmniLight3D
var _glow_halo: MeshInstance3D
var _float_ring: MeshInstance3D
var _cream: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _capsule: CapsuleShape3D
var _camera_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _camera_pitch: float = deg_to_rad(-10.0)
var _camera_nominal: float = 3.8
var _camera_arm: float = 3.8
var _last_sweep_length: float = 3.8
var _indoor: bool = false
var _indoor_override: int = -1
var _float_latched: bool = false
var _float_buffered: bool = false
var _float_ceiling: float = 0.6
var _rise_start: float = 0.0
var _state_time: float = 0.0
var _stable_time: float = 0.0
var _idle_time: float = 0.0
var _require_release: bool = false
var _blocked_notice: float = 0.0
var _recovery_teleported: bool = false
var _camera_fade: float = 0.0
var _recovery_fade: float = 0.0
var _last_animation: String = ""
var _last_position: Vector3 = Vector3.ZERO
var _pending_teleport: bool = false
var _pending_position: Vector3 = Vector3.ZERO
var _pending_yaw: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = WORLD_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(35.0)
	floor_snap_length = 0.18
	floor_stop_on_slope = true
	floor_constant_speed = true
	max_slides = 6
	# 5 mm native recovery margin closes the reproduced millimetre trunk overlap.
	safe_margin = 0.005
	_capsule = CapsuleShape3D.new()
	_capsule.height = 0.95
	_capsule.radius = 0.28
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = _capsule
	shape.position.y = 0.475
	add_child(shape)
	_build_creature()
	_build_effects()
	_build_camera()
	_last_position = global_position
	set_glow(glow_on)
	_animation("idle", 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _require_release or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		camera_yaw -= mouse.relative.x * 0.0025 * sensitivity
		var sign_y: float = -1.0 if invert_y else 1.0
		_camera_pitch -= mouse.relative.y * 0.0025 * sensitivity * sign_y
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-65.0), deg_to_rad(15.0))

func _physics_process(delta: float) -> void:
	if _pending_teleport:
		_pending_teleport = false
		_complete_teleport(_pending_position, _pending_yaw)
	_update_camera_collision(delta)
	_state_time += delta
	_blocked_notice = maxf(0.0, _blocked_notice - delta)
	if state == "Recovering":
		_update_recovery(delta)
		return
	if _outside_playable(global_position) or _over_water(global_position) or global_position.y < -1.5:
		recover()
		return
	if _require_release and not _any_control_held():
		_require_release = false
	var accept_input: bool = enabled and not _require_release
	var move_input: Vector2 = Vector2.ZERO
	var float_pressed: bool = false
	var float_wanted: bool = false
	if accept_input:
		move_input = _movement_input()
		if Input.is_action_just_pressed("glow"):
			set_glow(not glow_on)
		float_pressed = _float_press()
		if float_toggle:
			if Input.is_action_just_pressed("float"):
				_float_latched = not _float_latched
			float_wanted = _float_latched
		else:
			float_wanted = Input.is_action_pressed("float")
		float_wanted = float_wanted or touch_hover_latched
		_update_gamepad_look(delta)
	if float_pressed and (state == "Descending" or state == "Landing"):
		_float_buffered = float_wanted
	if not float_wanted:
		_float_buffered = false
	if state == "Grounded" and (float_pressed or _float_buffered) and float_wanted:
		_begin_float()
	if (state == "Rising" or state == "Hovering") and not float_wanted:
		_set_state("Descending")
	var yaw_basis: Basis = Basis(Vector3.UP, camera_yaw)
	var direction: Vector3 = yaw_basis * Vector3(move_input.x, 0.0, move_input.y)
	var speed: float = FLOAT_SPEED if state in AIR_STATES else WALK_SPEED
	var desired: Vector3 = direction * speed
	var acceleration: float = 12.0 if move_input.length() > 0.05 else 16.0
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if state in AIR_STATES:
		var proposed: Vector3 = global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
		var lead: Vector3 = Vector3(velocity.x, 0.0, velocity.z).normalized() * 0.22
		if not _safe_hover_support(proposed) or not _safe_hover_support(proposed + lead):
			velocity.x = 0.0
			velocity.z = 0.0
			if move_input.length() > 0.1 and _blocked_notice <= 0.0:
				feedback.emit("Float needs a safe landing surface nearby.")
				_blocked_notice = 2.5
	_update_vertical(delta)
	var before: Vector3 = global_position
	move_and_slide()
	var actual_planar: Vector3 = global_position - before
	actual_planar.y = 0.0
	var actual_speed: float = actual_planar.length() / maxf(delta, 0.0001)
	if actual_speed > 0.05:
		var facing: float = atan2(-actual_planar.x, -actual_planar.z)
		_visual.rotation.y = rotate_toward(_visual.rotation.y, facing, deg_to_rad(540.0) * delta)
	if state == "Rising" and is_on_ceiling():
		_float_ceiling = minf(_float_ceiling, global_position.y)
		velocity.y = 0.0
		_set_state("Hovering")
	elif state == "Descending" and is_on_floor():
		velocity.y = 0.0
		_set_state("Landing")
	elif state == "Grounded" and is_on_floor():
		velocity.y = 0.0
	if state == "Landing" and _state_time >= 0.12:
		_set_state("Grounded")
	_update_safe_marker(delta)
	_update_animation(actual_speed, delta)
	_float_ring.visible = state in AIR_STATES and not reduced_motion and not reduced_effects
	_last_position = global_position

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
	var fade_target: float = 0.92 if hit > 0.001 and hit < 0.35 else 0.0
	_camera_fade = lerpf(_camera_fade, fade_target, 1.0 - exp(-delta / 0.10))
	for mesh: MeshInstance3D in _meshes:
		mesh.transparency = maxf(_camera_fade, _recovery_fade)

func _update_camera_collision(delta: float) -> void:
	if not is_instance_valid(_spring_arm):
		return
	if not is_instance_valid(_camera_pivot):
		return
	var target: Vector3 = global_position + Vector3.UP * 0.70
	var follow_time: float = 0.045 if reduced_motion else 0.12
	_camera_pivot.global_position = _camera_pivot.global_position.lerp(target, 1.0 - exp(-delta / follow_time))
	_camera_pivot.rotation = Vector3(_camera_pitch, camera_yaw, 0.0)
	# Sample exactly once per physics tick. Render frames may outnumber sweeps;
	# comparing a stale sweep against a newly extended arm causes endless compression.
	var hit: float = _spring_arm.get_hit_length()
	if hit > 0.001 and hit < _last_sweep_length - 0.01:
		_camera_arm = hit
	else:
		_camera_arm = lerpf(_camera_arm, _camera_nominal, 1.0 - exp(-delta / 0.20))
	_camera_arm = minf(_camera_arm, _camera_nominal)
	_spring_arm.spring_length = maxf(0.05, _camera_arm)
	_last_sweep_length = _spring_arm.spring_length

func get_camera() -> Camera3D:
	return _camera

func set_indoor_camera(value: bool) -> void:
	_indoor_override = 1 if value else 0

func clear_indoor_camera_override() -> void:
	_indoor_override = -1

func set_glow(value: bool) -> void:
	var changed: bool = glow_on != value
	glow_on = value
	if is_instance_valid(_light):
		_light.visible = value
		_glow_halo.visible = value and not reduced_motion and not reduced_effects
		_cream.emission_enabled = value
		_cream.emission = Color(0.23, 0.18, 0.085) if value else Color.BLACK
		_cream.emission_energy_multiplier = 0.30
		if changed and value and not reduced_motion and is_instance_valid(_glow_animator):
			_glow_animator.play("glow", 0.06)

func release_controls() -> void:
	touch_hover_latched = false
	_touch_hover_pressed = false
	_require_release = true
	_float_latched = false
	_float_buffered = false
	velocity.x = 0.0
	velocity.z = 0.0
	if state == "Rising" or state == "Hovering":
		_set_state("Descending")

func teleport_safe(point: Vector3, yaw: float = 0.0) -> void:
	# Every teleport validates at a physics boundary, after deferred room activation
	# and newly rebuilt furniture have entered the physics space.
	_pending_position = point if point.is_finite() else FIXED_RECOVERY
	_pending_yaw = yaw
	_pending_teleport = true
	var display_point: Vector3 = _pending_position
	if _outside_playable(display_point) or _over_water(display_point):
		display_point = safe_position
	_apply_teleport_pose(display_point, yaw)

func _complete_teleport(point: Vector3, yaw: float) -> void:
	var resolved: Vector3 = _resolve_safe_position(point)
	_apply_teleport_pose(resolved, yaw)
	safe_position = resolved

func _apply_teleport_pose(point: Vector3, yaw: float) -> void:
	global_position = point
	velocity = Vector3.ZERO
	camera_yaw = yaw
	if is_instance_valid(_visual):
		_visual.rotation.y = yaw
	if is_instance_valid(_camera_pivot):
		_camera_pivot.global_position = global_position + Vector3.UP * 0.70
		_camera_pivot.rotation = Vector3(_camera_pitch, camera_yaw, 0.0)
	_set_state("Grounded")
	_stable_time = 0.0
	_recovery_fade = 0.0
	_float_latched = false
	_float_buffered = false
	_require_release = true

func recover() -> void:
	if state == "Recovering":
		return
	release_controls()
	_set_state("Recovering")
	_recovery_teleported = false
	velocity = Vector3.ZERO
	if is_instance_valid(_float_ring):
		_float_ring.visible = false
	feedback.emit("Returning to safe ground.")

func _set_state(next: String) -> void:
	if state == next:
		return
	state = next
	_state_time = 0.0

func _begin_float() -> void:
	if not is_on_floor():
		return
	var support: Dictionary = _support_at(global_position, 0.22)
	if support.is_empty() or test_move(global_transform, Vector3.UP * 0.06):
		_float_latched = false
		feedback.emit("There is not enough clear space to Float here.")
		return
	var support_point: Vector3 = support["position"] as Vector3
	_float_ceiling = support_point.y + 0.60
	_rise_start = global_position.y
	_float_buffered = false
	floor_snap_length = 0.0
	_set_state("Rising")
	_float_ring.visible = not reduced_motion and not reduced_effects

func _update_vertical(delta: float) -> void:
	if state == "Rising":
		var t: float = clampf(_state_time / 0.35, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		var target_y: float = lerpf(_rise_start, _float_ceiling, eased)
		velocity.y = clampf((target_y - global_position.y) / maxf(delta, 0.0001), 0.0, 2.75)
		if t >= 1.0 or global_position.y >= _float_ceiling - 0.015:
			_set_state("Hovering")
	elif state == "Hovering":
		var support: Dictionary = _support_at(global_position, 1.2)
		if support.is_empty():
			velocity.y = 0.0
			_set_state("Descending")
		else:
			var point: Vector3 = support["position"] as Vector3
			var target_y: float = minf(_float_ceiling, point.y + 0.60)
			velocity.y = clampf((target_y - global_position.y) * 10.0, -1.6, 1.6)
	elif state == "Descending":
		floor_snap_length = 0.18
		var support: Dictionary = _support_at(global_position, 1.2)
		if support.is_empty():
			velocity.y = 0.0
			if _state_time > 0.35:
				recover()
		else:
			var point: Vector3 = support["position"] as Vector3
			var remaining: float = maxf(0.0, global_position.y - point.y)
			velocity.y = -minf(2.5, maxf(0.35, remaining / maxf(0.08, 0.30 - _state_time)))
	else:
		floor_snap_length = 0.18
		if not is_on_floor():
			velocity.y = maxf(-8.0, velocity.y - GRAVITY * delta)
		else:
			velocity.y = -0.20

func _support_at(feet: Vector3, depth: float) -> Dictionary:
	if _outside_playable(feet) or _over_water(feet):
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.08, feet - Vector3.UP * depth, WORLD_MASK, [get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit["normal"] as Vector3
	if normal.y < FLOOR_COS:
		return {}
	var solid: Object = hit.get("collider") as Object
	if is_instance_valid(solid) and solid.has_meta("unsafe_support") and bool(solid.get_meta("unsafe_support")):
		return {}
	return hit

func _safe_hover_support(feet: Vector3) -> bool:
	var hit: Dictionary = _support_at(feet, 1.2)
	if hit.is_empty():
		return false
	var point: Vector3 = hit["position"] as Vector3
	return feet.y - point.y <= 1.2 and point.y <= _float_ceiling + 0.025

func _update_safe_marker(delta: float) -> void:
	var stable: bool = state == "Grounded" and is_on_floor() and absf(velocity.y) < 0.25
	if not stable or _reserved_marker_area(global_position):
		_stable_time = 0.0
		return
	_stable_time += delta
	if _stable_time >= 0.30 and _valid_safe_position(global_position):
		safe_position = global_position

func _valid_safe_position(point: Vector3) -> bool:
	if _outside_playable(point) or _over_water(point):
		return false
	var support: Dictionary = _support_at(point, 0.22)
	if support.is_empty():
		return false
	var support_point: Vector3 = support["position"] as Vector3
	if absf(point.y - support_point.y) > 0.15:
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.505)
	query.collision_mask = WORLD_MASK
	query.exclude = [get_rid()]
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()

func _resolve_safe_position(requested: Vector3) -> Vector3:
	for candidate: Vector3 in [requested, safe_position, FIXED_RECOVERY]:
		if not candidate.is_finite() or _outside_playable(candidate) or _over_water(candidate):
			continue
		# Preserve capsule clearance already validated at this supported pose.
		# Projecting only the center ray can lower a capsule into sloped terrain.
		if _valid_safe_position(candidate):
			return candidate
		var hit: Dictionary = _support_at(candidate + Vector3.UP * 0.70, 1.7)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"] as Vector3
		# A new chair/table is not permission to relocate a saved player onto its top.
		var supporting_body: CollisionObject3D = hit.get("collider") as CollisionObject3D
		if absf(point.y - candidate.y) > 0.15 and is_instance_valid(supporting_body) and (supporting_body.collision_layer & 16) != 0:
			continue
		var supported: Vector3 = Vector3(candidate.x, point.y + 0.008, candidate.z)
		if _valid_safe_position(supported):
			return supported
	feedback.emit("Safe ground needs checking; using the clearing entrance.")
	return FIXED_RECOVERY + Vector3.UP * 0.02

func _update_recovery(_delta: float) -> void:
	_recovery_fade = clampf(_state_time / 0.15, 0.0, 1.0) if _state_time < 0.15 else clampf(1.0 - (_state_time - 0.15) / 0.15, 0.0, 1.0)
	if _state_time >= 0.15 and not _recovery_teleported:
		global_position = _resolve_safe_position(safe_position)
		safe_position = global_position
		velocity = Vector3.ZERO
		_camera_pivot.global_position = global_position + Vector3.UP * 0.70
		_recovery_teleported = true
	if _state_time >= 0.30:
		_set_state("Grounded")
		_recovery_fade = 0.0
		_stable_time = 0.0

func _outside_playable(point: Vector3) -> bool:
	return point.x < -20.0 or point.x > 20.0 or point.z < -20.0 or point.z > 26.0

func _over_water(point: Vector3) -> bool:
	var in_stream: bool = point.x > 7.81 and point.x < 10.19 and point.z > -20.0 and point.z < 26.0
	var on_bridge: bool = point.z > 6.57 and point.z < 8.43 and point.y >= -0.03
	var on_loop_ford: bool = point.z > -8.60 and point.z < -6.70 and point.y >= -0.03
	return in_stream and not on_bridge and not on_loop_ford

func _reserved_marker_area(point: Vector3) -> bool:
	var door: bool = absf(point.x) < 1.30 and point.z > 1.10 and point.z < 4.0
	var growth: bool = point.x > 2.30 and point.x < 7.30 and point.z > -1.70 and point.z < 2.90
	var reservation: StaticBody3D = get_parent().get_node_or_null("GrowthReservation") as StaticBody3D
	var growth_active: bool = is_instance_valid(reservation) and reservation.collision_layer != 0
	return door or (growth and growth_active)

func _inside_camera_volume(point: Vector3, margin: float) -> bool:
	if point.y < 0.25 or point.y > 2.60:
		return false
	var main: bool = Vector2(point.x, point.z).length() < 2.65 + margin
	var entry: bool = absf(point.x) < 0.95 + margin and point.z > 1.8 and point.z < 3.0 + margin
	var annex: bool = Vector2(point.x + 4.1, point.z + 0.4).length() < 1.65 + margin
	var room: bool = Vector2(point.x - 4.95, point.z - 0.6).length() < 1.50 + margin
	var neck: bool = point.x > 2.25 and point.x < 4.0 and absf(point.z - 0.6) < 0.70 + margin
	return main or entry or annex or room or neck

func _touch_movement() -> Vector2:
	if not InputMap.has_action("touch_move_left"): return Vector2.ZERO
	return Input.get_vector("touch_move_left","touch_move_right","touch_move_forward","touch_move_back",0.0)

func _movement_input() -> Vector2:
	return (Input.get_vector("move_left","move_right","move_forward","move_back") + _touch_movement()).limit_length(1.0)

func _float_press() -> bool:
	var pressed := Input.is_action_just_pressed("float") or _touch_hover_pressed
	_touch_hover_pressed = false
	return pressed

func set_touch_hover(value: bool) -> void:
	if value and not enabled: return
	_touch_hover_pressed = value and not touch_hover_latched
	touch_hover_latched = value

func touch_look(relative: Vector2, viewport_height: float) -> void:
	if not enabled or _require_release or get_tree().paused or not relative.is_finite(): return
	var scale := 720.0 / maxf(200.0,viewport_height)
	camera_yaw -= relative.x * 0.0035 * sensitivity * scale
	_camera_pitch -= relative.y * 0.0035 * sensitivity * scale * (-1.0 if invert_y else 1.0)
	_camera_pitch = clampf(_camera_pitch,deg_to_rad(-65.0),deg_to_rad(65.0))

func _any_control_held() -> bool:
	if touch_hover_latched or _touch_movement().length() > 0.01: return true
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "float", "glow", "interact", "decorate"]:
		if Input.is_action_pressed(action):
			return true
	for device: int in Input.get_connected_joypads():
		if Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)).length() > 0.20:
			return true
	return false

func _update_gamepad_look(delta: float) -> void:
	for device: int in Input.get_connected_joypads():
		var look: Vector2 = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if look.length() < 0.18:
			continue
		look = look.limit_length(1.0)
		camera_yaw -= look.x * 2.2 * sensitivity * delta
		var sign_y: float = -1.0 if invert_y else 1.0
		_camera_pitch -= look.y * 1.7 * sensitivity * sign_y * delta
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-65.0), deg_to_rad(15.0))

func _update_animation(actual_speed: float, delta: float) -> void:
	match state:
		"Rising":
			_animation("rise", 0.10)
		"Hovering":
			_animation("hover", 0.12)
		"Descending":
			_animation("descent", 0.10)
		"Landing":
			_animation("land", 0.04)
		_:
			if actual_speed > 0.15:
				_idle_time = 0.0
				_animation("walk", 0.12)
				# The short provisional feet author a 0.252 m stance; cadence follows actual travel.
				_animator.speed_scale = clampf(actual_speed / 0.70, 0.15, 3.5)
			else:
				_idle_time += delta
				if _idle_time >= 0.10:
					_animation("idle", 0.12)
	if state in AIR_STATES or _last_animation == "idle" or state == "Landing":
		_animator.speed_scale = 0.0 if state == "Hovering" and reduced_motion else 1.0
	_glow_halo.visible = glow_on and not reduced_motion and not reduced_effects

func _animation(clip: String, blend: float) -> void:
	if _last_animation == clip:
		return
	_last_animation = clip
	_animator.speed_scale = 1.0
	_animator.play(clip, blend)

func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _ellipsoid(parent: Node3D, label: String, center: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = label
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.position = center
	mesh.scale = dimensions
	parent.add_child(mesh)
	_meshes.append(mesh)
	return mesh

func _bone(label: String, parent: int, offset: Vector3) -> int:
	_skeleton.add_bone(label)
	var index: int = _skeleton.get_bone_count() - 1
	_skeleton.set_bone_parent(index, parent)
	_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
	_skeleton.set_bone_pose_position(index, offset)
	return index

func _attachment(label: String, bone_name: String) -> BoneAttachment3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	return attachment

func _build_creature() -> void:
	_visual = Node3D.new()
	_visual.name = "VisualRoot"
	add_child(_visual)
	_visual.set_meta("provisional", true)
	_visual.set_meta("design_status", "Provisional cream creature; final species, fur and expression are not approved.")
	_cream = _material(Color(0.93, 0.85, 0.70), 0.88)
	var feet_material: StandardMaterial3D = _material(Color(0.84, 0.72, 0.54))
	var inner_ear: StandardMaterial3D = _material(Color(0.76, 0.55, 0.41))
	var dark: StandardMaterial3D = _material(Color(0.085, 0.055, 0.032), 0.35)
	var highlight: StandardMaterial3D = _material(Color(1.0, 0.98, 0.89), 0.30)
	var cheek: StandardMaterial3D = _material(Color(0.87, 0.64, 0.48))
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	_visual.add_child(_skeleton)
	var root_bone: int = _bone("root", -1, Vector3.ZERO)
	var body_bone: int = _bone("body", root_bone, Vector3(0.0, 0.395, 0.015))
	var head_bone: int = _bone("head", body_bone, Vector3(0.0, 0.335, -0.055))
	var left_leg: int = _bone("left_leg", root_bone, Vector3(-0.12, 0.175, -0.015))
	var right_leg: int = _bone("right_leg", root_bone, Vector3(0.12, 0.175, -0.015))
	_bone("left_foot", left_leg, Vector3(0.0, -0.105, -0.020))
	_bone("right_foot", right_leg, Vector3(0.0, -0.105, -0.020))
	_bone("left_arm", body_bone, Vector3(-0.205, 0.09, -0.04))
	_bone("right_arm", body_bone, Vector3(0.205, 0.09, -0.04))
	_bone("tail", body_bone, Vector3(0.0, -0.02, 0.18))
	var body_attachment: BoneAttachment3D = _attachment("Body", "body")
	_ellipsoid(body_attachment, "BodyMesh", Vector3.ZERO, Vector3(0.43, 0.46, 0.35), _cream)
	_ellipsoid(body_attachment, "Belly", Vector3(0.0, -0.015, -0.153), Vector3(0.25, 0.29, 0.045), highlight)
	var head_attachment: BoneAttachment3D = _attachment("Head", "head")
	_ellipsoid(head_attachment, "HeadMesh", Vector3.ZERO, Vector3(0.47, 0.43, 0.42), _cream)
	for sign_x: float in [-1.0, 1.0]:
		_ellipsoid(head_attachment, "Ear", Vector3(sign_x * 0.133, 0.191, 0.01), Vector3(0.115, 0.122, 0.085), _cream)
		_ellipsoid(head_attachment, "EarInset", Vector3(sign_x * 0.133, 0.193, -0.034), Vector3(0.057, 0.074, 0.011), inner_ear)
		_ellipsoid(head_attachment, "Eye", Vector3(sign_x * 0.075, 0.018, -0.200), Vector3(0.037, 0.047, 0.026), dark)
		_ellipsoid(head_attachment, "EyeCatchlight", Vector3(sign_x * 0.080, 0.028, -0.211), Vector3(0.009, 0.011, 0.006), highlight)
		_ellipsoid(head_attachment, "Cheek", Vector3(sign_x * 0.125, -0.040, -0.178), Vector3(0.060, 0.030, 0.013), cheek)
	_ellipsoid(head_attachment, "Nose", Vector3(0.0, -0.029, -0.216), Vector3(0.031, 0.023, 0.023), dark)
	_ellipsoid(head_attachment, "Mouth", Vector3(0.0, -0.065, -0.201), Vector3(0.035, 0.008, 0.009), dark)
	for side: String in ["left", "right"]:
		var leg: BoneAttachment3D = _attachment(side.capitalize() + "Leg", side + "_leg")
		_ellipsoid(leg, "LegMesh", Vector3(0.0, -0.025, 0.0), Vector3(0.125, 0.145, 0.125), _cream)
		var foot: BoneAttachment3D = _attachment(side.capitalize() + "Foot", side + "_foot")
		_ellipsoid(foot, "FootMesh", Vector3(0.0, 0.0, -0.035), Vector3(0.145, 0.14, 0.235), _cream)
		_ellipsoid(foot, "PawSole", Vector3(0.0, -0.051, -0.055), Vector3(0.10, 0.029, 0.12), feet_material)
		var arm: BoneAttachment3D = _attachment(side.capitalize() + "Arm", side + "_arm")
		var gesture: Node3D = Node3D.new()
		gesture.name = "GlowGesture"
		arm.add_child(gesture)
		_ellipsoid(gesture, "Forepaw", Vector3(0.0, -0.034, -0.024), Vector3(0.13, 0.20, 0.14), _cream)
	var tail: BoneAttachment3D = _attachment("Tail", "tail")
	_ellipsoid(tail, "TailMesh", Vector3(0.0, 0.01, 0.10), Vector3(0.34, 0.33, 0.33), _cream)
	# A few soft lobes suggest volume without deciding a production fur system.
	for i: int in range(5):
		var angle: float = float(i) * TAU / 5.0
		_ellipsoid(tail, "TailTuft", Vector3(sin(angle) * 0.087, cos(angle) * 0.087, 0.18), Vector3(0.17, 0.17, 0.18), _cream)
	_build_animations()

func _build_effects() -> void:
	var effects: Node3D = Node3D.new()
	effects.name = "AbilityEffects"
	add_child(effects)
	_light = OmniLight3D.new()
	_light.name = "GlowLight"
	_light.position = Vector3(0.0, 0.62, -0.08)
	_light.light_color = Color(1.0, 0.85, 0.56)
	_light.light_energy = 1.35
	_light.omni_range = 3.0
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.visible = false
	effects.add_child(_light)
	var gold: StandardMaterial3D = _material(Color(1.0, 0.86, 0.48))
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.79, 0.35)
	gold.emission_energy_multiplier = 1.2
	_glow_halo = _ring(effects, "GlowHalo", 0.31, 0.322, gold)
	_glow_halo.position.y = 0.07
	_glow_halo.visible = false
	var lilac: StandardMaterial3D = _material(Color(0.79, 0.83, 1.0))
	lilac.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lilac.emission_enabled = true
	lilac.emission = Color(0.66, 0.74, 1.0)
	lilac.emission_energy_multiplier = 1.0
	_float_ring = _ring(effects, "FloatRing", 0.27, 0.282, lilac)
	_float_ring.position.y = 0.025
	_float_ring.visible = false

func _ring(parent: Node3D, label: String, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = label
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraRig"
	add_child(_camera_pivot)
	_camera_pivot.top_level = true
	_camera_pivot.global_position = global_position + Vector3.UP * 0.70
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_spring_arm.spring_length = 3.8
	_spring_arm.margin = 0.05
	var camera_shape: SphereShape3D = SphereShape3D.new()
	camera_shape.radius = 0.14
	_spring_arm.shape = camera_shape
	_spring_arm.collision_mask = CAMERA_MASK
	_spring_arm.add_excluded_object(get_rid())
	_camera_pivot.add_child(_spring_arm)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 65.0
	_camera.near = 0.04
	_camera.far = 160.0
	_camera.current = true
	_spring_arm.add_child(_camera)

func _clip(length: float, looping: bool = false) -> Animation:
	var clip: Animation = Animation.new()
	clip.length = length
	if looping:
		clip.loop_mode = Animation.LOOP_LINEAR
	return clip

func _position_track(clip: Animation, bone_name: String, times: Array[float], poses: Array[Vector3]) -> void:
	var track: int = clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Skeleton3D:" + bone_name))
	var bind_position: Vector3 = _skeleton.get_bone_rest(_skeleton.find_bone(bone_name)).origin
	for i: int in range(times.size()):
		clip.position_track_insert_key(track, times[i], bind_position + poses[i])

func _rotation_track(clip: Animation, bone_name: String, times: Array[float], angles: Array[Vector3]) -> void:
	var track: int = clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath("Skeleton3D:" + bone_name))
	for i: int in range(times.size()):
		clip.rotation_track_insert_key(track, times[i], Quaternion.from_euler(angles[i]))

func _neutral_tracks(clip: Animation) -> void:
	for bone_name: String in ["body", "head", "left_leg", "right_leg", "left_foot", "right_foot", "left_arm", "right_arm", "tail"]:
		_position_track(clip, bone_name, [0.0], [Vector3.ZERO])
		_rotation_track(clip, bone_name, [0.0], [Vector3.ZERO])

func _replace_position(clip: Animation, bone_name: String, times: Array[float], poses: Array[Vector3]) -> void:
	var track: int = clip.find_track(NodePath("Skeleton3D:" + bone_name), Animation.TYPE_POSITION_3D)
	if track >= 0:
		clip.remove_track(track)
	_position_track(clip, bone_name, times, poses)

func _replace_rotation(clip: Animation, bone_name: String, times: Array[float], poses: Array[Vector3]) -> void:
	var track: int = clip.find_track(NodePath("Skeleton3D:" + bone_name), Animation.TYPE_ROTATION_3D)
	if track >= 0:
		clip.remove_track(track)
	_rotation_track(clip, bone_name, times, poses)

func _build_animations() -> void:
	_animator = AnimationPlayer.new()
	_animator.name = "LocomotionAnimator"
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_visual.add_child(_animator)
	var library: AnimationLibrary = AnimationLibrary.new()
	var idle: Animation = _clip(2.4, true)
	_neutral_tracks(idle)
	_replace_position(idle, "body", [0.0, 1.2, 2.4], [Vector3.ZERO, Vector3(0.0, 0.006, 0.0), Vector3.ZERO])
	_replace_rotation(idle, "head", [0.0, 1.2, 2.4], [Vector3.ZERO, Vector3(-0.012, 0.0, 0.0), Vector3.ZERO])
	library.add_animation("idle", idle)
	var walk: Animation = _clip(0.72, true)
	_neutral_tracks(walk)
	var times: Array[float] = [0.0, 0.12, 0.24, 0.36, 0.48, 0.60, 0.72]
	_replace_position(walk, "left_foot", times, [Vector3(0.0, 0.0, -0.126), Vector3(0.0, 0.0, -0.042), Vector3(0.0, 0.0, 0.042), Vector3(0.0, 0.0, 0.126), Vector3(0.0, 0.066, 0.042), Vector3(0.0, 0.054, -0.042), Vector3(0.0, 0.0, -0.126)])
	_replace_position(walk, "right_foot", times, [Vector3(0.0, 0.0, 0.126), Vector3(0.0, 0.066, 0.042), Vector3(0.0, 0.054, -0.042), Vector3(0.0, 0.0, -0.126), Vector3(0.0, 0.0, -0.042), Vector3(0.0, 0.0, 0.042), Vector3(0.0, 0.0, 0.126)])
	_replace_position(walk, "body", times, [Vector3.ZERO, Vector3(0.0, -0.009, 0.0), Vector3(0.0, 0.01, 0.0), Vector3.ZERO, Vector3(0.0, -0.009, 0.0), Vector3(0.0, 0.01, 0.0), Vector3.ZERO])
	_replace_rotation(walk, "body", [0.0, 0.18, 0.36, 0.54, 0.72], [Vector3(0.0, -0.035, 0.018), Vector3.ZERO, Vector3(0.0, 0.035, -0.018), Vector3.ZERO, Vector3(0.0, -0.035, 0.018)])
	_replace_rotation(walk, "left_arm", [0.0, 0.36, 0.72], [Vector3(0.15, 0.0, -0.08), Vector3(-0.15, 0.0, -0.08), Vector3(0.15, 0.0, -0.08)])
	_replace_rotation(walk, "right_arm", [0.0, 0.36, 0.72], [Vector3(-0.15, 0.0, 0.08), Vector3(0.15, 0.0, 0.08), Vector3(-0.15, 0.0, 0.08)])
	walk.set_meta("left_contact", 0.0)
	walk.set_meta("right_contact", 0.36)
	walk.set_meta("authored_stance_metres", 0.252)
	walk.set_meta("cadence_rule", "Playback scales with actual travel / 0.70m/s to keep short provisional feet planted.")
	library.add_animation("walk", walk)
	var rise: Animation = _clip(0.35)
	_neutral_tracks(rise)
	_replace_rotation(rise, "left_arm", [0.0, 0.15, 0.35], [Vector3.ZERO, Vector3(-0.14, 0.0, -0.25), Vector3(-0.10, 0.0, -0.36)])
	_replace_rotation(rise, "right_arm", [0.0, 0.15, 0.35], [Vector3.ZERO, Vector3(-0.14, 0.0, 0.25), Vector3(-0.10, 0.0, 0.36)])
	_replace_rotation(rise, "left_foot", [0.0, 0.35], [Vector3.ZERO, Vector3(0.12, 0.0, 0.0)])
	_replace_rotation(rise, "right_foot", [0.0, 0.35], [Vector3.ZERO, Vector3(0.12, 0.0, 0.0)])
	library.add_animation("rise", rise)
	var hover: Animation = _clip(1.8, true)
	_neutral_tracks(hover)
	_replace_position(hover, "body", [0.0, 0.45, 0.90, 1.35, 1.8], [Vector3.ZERO, Vector3(0.0, 0.012, 0.0), Vector3.ZERO, Vector3(0.0, -0.012, 0.0), Vector3.ZERO])
	_replace_rotation(hover, "left_arm", [0.0, 0.9, 1.8], [Vector3(-0.10, 0.0, -0.36), Vector3(-0.10, 0.0, -0.40), Vector3(-0.10, 0.0, -0.36)])
	_replace_rotation(hover, "right_arm", [0.0, 0.9, 1.8], [Vector3(-0.10, 0.0, 0.36), Vector3(-0.10, 0.0, 0.40), Vector3(-0.10, 0.0, 0.36)])
	_replace_rotation(hover, "left_foot", [0.0], [Vector3(0.12, 0.0, 0.0)])
	_replace_rotation(hover, "right_foot", [0.0], [Vector3(0.12, 0.0, 0.0)])
	library.add_animation("hover", hover)
	var descent: Animation = _clip(0.30)
	_neutral_tracks(descent)
	_replace_rotation(descent, "left_arm", [0.0, 0.30], [Vector3(-0.10, 0.0, -0.36), Vector3.ZERO])
	_replace_rotation(descent, "right_arm", [0.0, 0.30], [Vector3(-0.10, 0.0, 0.36), Vector3.ZERO])
	library.add_animation("descent", descent)
	var land: Animation = _clip(0.12)
	_neutral_tracks(land)
	_replace_position(land, "body", [0.0, 0.04, 0.12], [Vector3.ZERO, Vector3(0.0, -0.018, 0.0), Vector3.ZERO])
	library.add_animation("land", land)
	_animator.add_animation_library("", library)
	_glow_animator = AnimationPlayer.new()
	_glow_animator.name = "GlowAnimator"
	_glow_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_visual.add_child(_glow_animator)
	var glow_library: AnimationLibrary = AnimationLibrary.new()
	var glow: Animation = _clip(0.50)
	for side: String in ["Left", "Right"]:
		var sign_x: float = -1.0 if side == "Left" else 1.0
		var track: int = glow.add_track(Animation.TYPE_VALUE)
		glow.track_set_path(track, NodePath("Skeleton3D/" + side + "Arm/GlowGesture:rotation"))
		glow.track_insert_key(track, 0.0, Vector3.ZERO)
		glow.track_insert_key(track, 0.06, Vector3(-0.12, 0.0, sign_x * 0.13))
		glow.track_insert_key(track, 0.16, Vector3(-0.24, 0.0, sign_x * 0.28))
		glow.track_insert_key(track, 0.30, Vector3(-0.10, 0.0, sign_x * 0.10))
		glow.track_insert_key(track, 0.50, Vector3.ZERO)
	glow_library.add_animation("glow", glow)
	_glow_animator.add_animation_library("", glow_library)
