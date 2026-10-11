extends "res://lineage/sky36-camera-proposal03/player.gd"
## Isolated54 bounded early landing and swept normal-speed lift advance trial.
## The original controller and expanded sky camera remain inherited.
## A full-capsule route is queried first; actual movement still calls native
## move_and_slide exactly once each physics tick, with no position assignment.
const STEP48_MAX_RISE: float = 0.20
const STEP48_LOOKAHEAD: float = 0.34
const STEP48_DOWN_EXTRA: float = 0.08
const STEP48_TOP_CLEARANCE: float = 0.012
const STEP48_VERTICAL_SPEED: float = 1.8
const STEP48_MAX_TIME: float = 1.2
const STEP48_MIN_RISE: float = 0.02
const STEP48_POSE_TOLERANCE: float = 0.006
const STEP48_TARGET_TOLERANCE: float = 0.003
const STEP48_MIN_INPUT: float = 0.15
const STEP48_DIRECTION_DOT: float = 0.995
const STEP48_MAX_QUERY_CONTACTS: int = 16
const STEP48_MAX_EVENTS: int = 128
const STEP48_SURFACE_META: String = "entrance48_step_surface"
const STEP48_BOUNDS_META: String = "entrance48_step_bounds"
var entrance48_step_enabled: bool = true
var _step48_phase: String = "idle"
var _step48_start: Vector3 = Vector3.ZERO
var _step48_raised: Vector3 = Vector3.ZERO
var _step48_goal: Vector3 = Vector3.ZERO
var _step48_direction: Vector3 = Vector3.ZERO
var _step48_body: CollisionObject3D
var _step48_shape: int = -1
var _step48_elapsed: float = 0.0
var _step48_blocked_time: float = 0.0
var _step48_inset: CapsuleShape3D
var _step48_stats: Dictionary = {"attempts":0,"started":0,"completed":0,"aborted":0,"declined":0,"query_count":0,"events_dropped":0,"max_applied_rise_m":0.0}
var _step48_rejections: Dictionary = {}
var _step48_events: Array[Dictionary] = []
var _step48_last_attempt: Dictionary = {}

func _physics_process(delta: float) -> void:
	var entrance48_teleport_tick: bool = _pending_teleport
	if entrance48_teleport_tick:
		_step48_cancel("pending_teleport")
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
	# A real held/toggled request that interrupts a private lift must survive
	# cancellation, then retry only through _begin_float on native floor.
	if _step48_phase != "idle" and state == "Grounded" and float_pressed and float_wanted:
		_float_buffered = true
	if not float_wanted:
		_float_buffered = false
	if _step48_phase == "idle" and state == "Grounded" and (float_pressed or _float_buffered) and float_wanted:
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
	var entrance48_owned_motion: bool = _step48_prepare(delta, move_input, accept_input, float_wanted or float_pressed, entrance48_teleport_tick)
	var before: Vector3 = global_position
	move_and_slide()
	if entrance48_owned_motion:
		_step48_observe(delta, before)
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
	if _step48_phase == "idle":
		_update_safe_marker(delta)
	else:
		_stable_time = 0.0
	_update_animation(actual_speed, delta)
	_float_ring.visible = state in AIR_STATES and not reduced_motion and not reduced_effects
	_last_position = global_position


func teleport_safe(point: Vector3, yaw: float = 0.0) -> void:
	_step48_cancel("teleport_requested")
	super.teleport_safe(point,yaw)

func release_controls() -> void:
	_step48_cancel("controls_released")
	super.release_controls()

func _step48_v(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

func _step48_event(kind: String, reason: String = "") -> void:
	if _step48_events.size() >= STEP48_MAX_EVENTS:
		_step48_stats["events_dropped"] = int(_step48_stats["events_dropped"]) + 1
		return
	_step48_events.append({"kind":kind,"reason":reason,"physics_frame":Engine.get_physics_frames(),"phase":_step48_phase,"position":_step48_v(global_position),"state":state,"floor":is_on_floor(),"elapsed_s":_step48_elapsed})

func _step48_decline(reason: String) -> bool:
	_step48_stats["declined"] = int(_step48_stats["declined"]) + 1
	_step48_rejections[reason] = int(_step48_rejections.get(reason,0)) + 1
	_step48_last_attempt["declined_reason"] = reason
	return false

func _step48_cancel(reason: String) -> void:
	if _step48_phase == "idle": return
	_step48_stats["aborted"] = int(_step48_stats["aborted"]) + 1
	_step48_event("aborted",reason)
	_step48_phase = "idle"
	_step48_body = null
	_step48_shape = -1
	if state == "Grounded" or state == "Landing":
		# Cancel only the private lift impulse, never Float's own velocity/snap.
		velocity.y = minf(velocity.y,0.0)
		floor_snap_length = 0.18

func _step48_tagged(body: CollisionObject3D) -> bool:
	return is_instance_valid(body) and body is StaticBody3D and body.collision_layer == 1 and bool(body.get_meta(STEP48_SURFACE_META,false)) and not bool(body.get_meta("unsafe_support",false)) and body.get_meta(STEP48_BOUNDS_META,null) is Rect2

func _step48_inside(body: CollisionObject3D, point: Vector3) -> bool:
	if not _step48_tagged(body) or not point.is_finite() or _outside_playable(point) or _over_water(point): return false
	var bounds: Rect2 = body.get_meta(STEP48_BOUNDS_META)
	return bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.has_point(Vector2(point.x,point.z))

func _step48_inset_clear(feet: Vector3) -> bool:
	if not is_instance_valid(_capsule): return false
	if _step48_inset == null:
		_step48_inset = CapsuleShape3D.new()
		_step48_inset.radius = _capsule.radius - 0.006
		_step48_inset.height = _capsule.height - 0.012
	var shape_node: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _step48_inset
	query.transform = shape_node.global_transform
	query.transform.origin += feet - global_position
	query.collision_mask = WORLD_MASK
	query.exclude = [get_rid()]
	query.margin = 0.0
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query,STEP48_MAX_QUERY_CONTACTS).is_empty()

func _step48_motion(from: Transform3D, motion: Vector3, recovery_as_collision: bool = false) -> Dictionary:
	_step48_stats["query_count"] = int(_step48_stats["query_count"]) + 1
	var parameters: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	parameters.margin = safe_margin
	parameters.max_collisions = STEP48_MAX_QUERY_CONTACTS
	parameters.recovery_as_collision = recovery_as_collision
	parameters.collide_separation_ray = false
	var result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var hit: bool = PhysicsServer3D.body_test_motion(get_rid(),parameters,result)
	var travel: Vector3 = result.get_travel()
	var safe: float = result.get_collision_safe_fraction()
	var unsafe: float = result.get_collision_unsafe_fraction()
	var valid: bool = from.origin.is_finite() and motion.is_finite() and travel.is_finite() and result.get_remainder().is_finite() and result.get_collision_count() < STEP48_MAX_QUERY_CONTACTS
	if hit: valid = valid and is_finite(safe) and is_finite(unsafe) and safe >= 0.0 and unsafe >= safe and unsafe <= 1.0 and result.get_collision_count() > 0
	var contacts: Array[Dictionary] = []
	for index: int in range(result.get_collision_count()):
		var body: CollisionObject3D = result.get_collider(index) as CollisionObject3D
		var point: Vector3 = result.get_collision_point(index)
		var normal: Vector3 = result.get_collision_normal(index)
		var depth: float = result.get_collision_depth(index)
		valid = valid and is_instance_valid(body) and point.is_finite() and normal.is_finite() and is_finite(depth)
		contacts.append({"body":body,"shape":result.get_collider_shape(index),"point":point,"normal":normal,"depth":depth})
	return {"hit":hit,"valid":valid,"motion":motion,"travel":travel,"safe_fraction":safe,"unsafe_fraction":unsafe,"contacts":contacts,"recovery_residual_m":(travel-motion).length()}

func _step48_receipt(query: Dictionary) -> Dictionary:
	var contacts: Array[Dictionary] = []
	for contact: Dictionary in query["contacts"]:
		var body: CollisionObject3D = contact["body"] as CollisionObject3D
		contacts.append({"body_id":body.get_instance_id() if is_instance_valid(body) else 0,"body_name":str(body.name) if is_instance_valid(body) else "missing","shape":contact["shape"],"point":_step48_v(contact["point"] as Vector3),"normal":_step48_v(contact["normal"] as Vector3),"depth":contact["depth"]})
	return {"hit":query["hit"],"valid":query["valid"],"motion":_step48_v(query["motion"] as Vector3),"travel":_step48_v(query["travel"] as Vector3),"safe_fraction":query["safe_fraction"],"unsafe_fraction":query["unsafe_fraction"],"recovery_residual_m":query["recovery_residual_m"],"contacts":contacts}

func _step48_clear_motion(query: Dictionary) -> bool:
	return bool(query["valid"]) and not bool(query["hit"]) and float(query["recovery_residual_m"]) <= STEP48_POSE_TOLERANCE

func _step48_landing_contact(query: Dictionary, body: CollisionObject3D, shape: int) -> bool:
	if not bool(query["valid"]) or not bool(query["hit"]): return false
	var floor_contact: bool = false
	for contact: Dictionary in query["contacts"]:
		var other: CollisionObject3D = contact["body"] as CollisionObject3D
		var normal: Vector3 = contact["normal"] as Vector3
		# Reject all other bodies and steep/corner contacts, not only the first result.
		if other != body or int(contact["shape"]) != shape or normal.y < FLOOR_COS: return false
		floor_contact = true
	return floor_contact

func _step48_support_at(feet: Vector3, depth: float, body: CollisionObject3D, direction: Vector3) -> Dictionary:
	var center := _support_at(feet, depth)
	if not center.is_empty() and center.get("collider") != body: return center
	# A capsule can straddle a joint with recessed soil or a steep inner return.
	# Require walkable native support on BOTH sides, on the same tagged shape.
	# This only proposes support; the complete capsule sweeps still decide motion.
	if not _step48_inside(body, feet) or _outside_playable(feet) or _over_water(feet): return center
	var side := Vector3(-direction.z, 0.0, direction.x) * (_capsule.radius * 0.5)
	if side.length_squared() < 0.0001: return center
	var left := _support_at(feet - side, depth)
	var right := _support_at(feet + side, depth)
	if left.is_empty() or right.is_empty(): return center
	if left.get("collider") != body or right.get("collider") != body or int(left.get("shape", -1)) != int(right.get("shape", -1)): return center
	if not center.is_empty() and int(center.get("shape", -1)) != int(left.get("shape", -1)): return center
	var left_point: Vector3 = left["position"]
	var right_point: Vector3 = right["position"]
	if not _step48_inside(body, left_point) or not _step48_inside(body, right_point) or absf(left_point.y - right_point.y) > 0.02: return center
	var selected: Dictionary = left if left_point.y >= right_point.y else right
	if not center.is_empty() and (center["position"] as Vector3).y >= (selected["position"] as Vector3).y: return center
	_step48_stats["paired_supports"] = int(_step48_stats.get("paired_supports", 0)) + 1
	return selected

func _step48_begin(delta: float, direction: Vector3) -> bool:
	var planar: Vector3 = Vector3(velocity.x,0.0,velocity.z)
	var obstruction: Dictionary = _step48_motion(global_transform,planar*delta,true)
	if not bool(obstruction["hit"]): return false
	_step48_stats["attempts"] = int(_step48_stats["attempts"]) + 1
	_step48_last_attempt = {"origin":_step48_v(global_position),"direction":_step48_v(direction),"obstruction":_step48_receipt(obstruction)}
	if not bool(obstruction["valid"]): return _step48_decline("invalid_obstruction_query")
	var blocker: CollisionObject3D
	for contact: Dictionary in obstruction["contacts"]:
		var normal: Vector3 = contact["normal"] as Vector3
		if normal.y >= FLOOR_COS: continue
		var body: CollisionObject3D = contact["body"] as CollisionObject3D
		if normal.dot(direction) >= -0.1 or not _step48_tagged(body): return _step48_decline("untagged_or_nonfrontal_blocker")
		if blocker != null and blocker != body: return _step48_decline("mixed_blockers")
		blocker = body
	if blocker == null: return _step48_decline("no_steep_tagged_front")
	if not _step48_inside(blocker,global_position) or not _step48_inset_clear(global_position): return _step48_decline("unsafe_start_or_bounds")
	var current_support: Dictionary = _step48_support_at(global_position,0.22,blocker,direction)
	var current_body: CollisionObject3D = current_support.get("collider") as CollisionObject3D
	if current_support.is_empty() or not is_instance_valid(current_body) or current_body.collision_layer != 1: return _step48_decline("starting_support_not_world_floor")
	var start_support: Vector3 = current_support["position"] as Vector3
	# An actual ray proposes the top/shape; all three full-capsule sweeps still
	# have to approve the complete route. No authored scalar-height shortcut.
	var top_probe: Vector3 = global_position+direction*STEP48_LOOKAHEAD+Vector3.UP*STEP48_MAX_RISE
	var proposed_support: Dictionary = _step48_support_at(top_probe,STEP48_MAX_RISE+STEP48_DOWN_EXTRA,blocker,direction)
	var proposed_body: CollisionObject3D = proposed_support.get("collider") as CollisionObject3D
	if proposed_support.is_empty() or proposed_body != blocker: return _step48_decline("tagged_top_ray_missing")
	var proposed_point: Vector3 = proposed_support["position"] as Vector3
	var proposed_rise: float = proposed_point.y-start_support.y
	if proposed_rise < STEP48_MIN_RISE or proposed_rise > STEP48_MAX_RISE: return _step48_decline("top_ray_rise_outside_budget")
	var lift_height: float = minf(STEP48_MAX_RISE,maxf(STEP48_MIN_RISE,proposed_point.y-global_position.y+STEP48_TOP_CLEARANCE))
	_step48_last_attempt["proposed_top"] = _step48_v(proposed_point)
	_step48_last_attempt["lift_height_m"] = lift_height
	var up_motion: Vector3 = Vector3.UP*lift_height
	var up_query: Dictionary = _step48_motion(global_transform,up_motion)
	_step48_last_attempt["up"] = _step48_receipt(up_query)
	if not _step48_clear_motion(up_query): return _step48_decline("up_blocked_or_recovered_too_far")
	var raised: Transform3D = global_transform
	raised.origin += up_motion
	var ahead_motion: Vector3 = direction*STEP48_LOOKAHEAD
	var ahead_query: Dictionary = _step48_motion(raised,ahead_motion)
	_step48_last_attempt["ahead"] = _step48_receipt(ahead_query)
	if not _step48_clear_motion(ahead_query): return _step48_decline("raised_horizontal_blocked")
	var future: Transform3D = raised
	future.origin += ahead_motion
	if not _step48_inside(blocker,future.origin): return _step48_decline("unsafe_goal_or_bounds")
	var down_query: Dictionary = _step48_motion(future,Vector3.DOWN*(lift_height+STEP48_DOWN_EXTRA))
	_step48_last_attempt["down"] = _step48_receipt(down_query)
	if not bool(down_query["valid"]) or not bool(down_query["hit"]): return _step48_decline("landing_missing")
	var landing_shape: int = -1
	for contact: Dictionary in down_query["contacts"]:
		var body: CollisionObject3D = contact["body"] as CollisionObject3D
		var normal: Vector3 = contact["normal"] as Vector3
		if body != blocker or normal.y < FLOOR_COS: return _step48_decline("landing_not_tagged_walkable_top")
		if landing_shape >= 0 and int(contact["shape"]) != landing_shape: return _step48_decline("mixed_landing_shapes")
		landing_shape = int(contact["shape"])
	var goal: Vector3 = future.origin + (down_query["travel"] as Vector3)
	var support: Dictionary = _step48_support_at(goal,0.22,blocker,direction)
	var landed_body: CollisionObject3D = support.get("collider") as CollisionObject3D
	if support.is_empty() or landed_body != blocker or int(support.get("shape",-1)) != landing_shape or int(proposed_support.get("shape",-1)) != landing_shape: return _step48_decline("goal_ray_not_same_body_shape")
	var support_point: Vector3 = support["position"] as Vector3
	var rise: float = support_point.y-start_support.y
	if rise < STEP48_MIN_RISE or rise > STEP48_MAX_RISE or goal.y-global_position.y > STEP48_MAX_RISE+STEP48_POSE_TOLERANCE or not _step48_inset_clear(goal): return _step48_decline("rise_or_goal_envelope_invalid")
	for fraction: float in [0.25,0.5,0.75]:
		if not _step48_inside(blocker,global_position.lerp(future.origin,fraction)): return _step48_decline("unsafe_route")
	_step48_start = global_position
	_step48_raised = raised.origin
	_step48_goal = goal
	_step48_direction = direction
	_step48_body = blocker
	_step48_shape = landing_shape
	_step48_elapsed = 0.0
	_step48_blocked_time = 0.0
	_step48_phase = "lift"
	_step48_stats["started"] = int(_step48_stats["started"]) + 1
	_step48_last_attempt["goal"] = _step48_v(goal)
	_step48_last_attempt["support_rise_m"] = rise
	_step48_event("started")
	return true

func _step54_try_early_landing() -> bool:
	# The complete original route was admitted in _step48_begin. Only shorten
	# its advance after this actual-pose capsule sweep finds a safe native floor.
	var depth: float = maxf(0.0,global_position.y-_step48_start.y)+STEP48_DOWN_EXTRA
	var query: Dictionary = _step48_motion(global_transform,Vector3.DOWN*depth)
	if not _step48_landing_contact(query,_step48_body,_step48_shape): return false
	var travel: Vector3 = query["travel"] as Vector3
	var goal: Vector3 = global_position+travel
	var rise: float = goal.y-_step48_start.y
	if Vector2(travel.x,travel.z).length()>STEP48_POSE_TOLERANCE or goal.y>global_position.y or rise<STEP48_MIN_RISE or rise>STEP48_MAX_RISE+STEP48_POSE_TOLERANCE: return false
	if not _step48_inside(_step48_body,goal) or not _step48_inset_clear(goal): return false
	var support: Dictionary = _step48_support_at(goal,0.22,_step48_body,_step48_direction)
	if support.is_empty() or support.get("collider")!=_step48_body or int(support.get("shape",-1))!=_step48_shape: return false
	_step48_goal = goal
	_step48_phase = "down"
	_step48_stats["early_landings"] = int(_step48_stats.get("early_landings",0))+1
	_step48_last_attempt["early_landing"] = {"goal":_step48_v(goal),"rise_m":rise,"query":_step48_receipt(query)}
	_step48_event("early_landing")
	return true

func _step48_prepare(delta: float, move_input: Vector2, accept_input: bool, float_requested: bool, teleport_tick: bool) -> bool:
	var eligible: bool = entrance48_step_enabled and enabled and accept_input and not _require_release and not get_tree().paused and not teleport_tick and not _pending_teleport and (state=="Grounded" or state=="Landing") and not float_requested and move_input.length()>=STEP48_MIN_INPUT and is_finite(delta) and delta>0.0 and delta<=0.05
	if not eligible:
		_step48_cancel("input_state_or_teleport_gate")
		return false
	var direction: Vector3 = Basis(Vector3.UP,camera_yaw)*Vector3(move_input.x,0.0,move_input.y)
	direction = direction.normalized()
	if _step48_phase == "idle":
		if not is_on_floor() or Vector2(velocity.x,velocity.z).length()<0.10: return false
		if not _step48_begin(delta,direction): return false
	else:
		if direction.dot(_step48_direction)<STEP48_DIRECTION_DOT or not _step48_inside(_step48_body,global_position) or not _step48_inset_clear(global_position):
			_step48_cancel("direction_bounds_or_envelope_changed")
			return false
	_step48_elapsed += delta
	if _step48_elapsed > STEP48_MAX_TIME:
		_step48_cancel("step_time_limit")
		return false
	var motion: Vector3 = Vector3.ZERO
	if _step48_phase == "lift":
		var remaining: float = _step48_raised.y-global_position.y
		if remaining <= STEP48_TARGET_TOLERANCE: _step48_phase = "advance"
		else:
			motion = Vector3.UP*minf(STEP48_VERTICAL_SPEED*delta,remaining)
			# Keep analog speed; add forward travel only when the entire capsule
			# clears this diagonal. A blocked diagonal retains the original lift.
			var inherited_speed: float = minf(Vector2(velocity.x,velocity.z).length(),WALK_SPEED*move_input.length())
			var route_remaining: float = Vector2(_step48_goal.x-global_position.x,_step48_goal.z-global_position.z).length()
			var diagonal: Vector3 = motion+_step48_direction*minf(inherited_speed*delta,route_remaining)
			var diagonal_goal: Vector3 = global_position+diagonal
			if _step48_clear_motion(_step48_motion(global_transform,diagonal)) and _step48_inside(_step48_body,diagonal_goal) and _step48_inset_clear(diagonal_goal):
				motion = diagonal
				_step48_stats["lift_forward_ticks"] = int(_step48_stats.get("lift_forward_ticks",0))+1
	if _step48_phase == "advance":
		_step54_try_early_landing()
	if _step48_phase == "advance":
		var remaining: float = Vector2(_step48_goal.x-global_position.x,_step48_goal.z-global_position.z).length()
		if remaining <= STEP48_TARGET_TOLERANCE: _step48_phase = "down"
		else:
			var inherited_speed: float = minf(Vector2(velocity.x,velocity.z).length(),WALK_SPEED*move_input.length())
			motion = _step48_direction*minf(inherited_speed*delta,remaining)
	if _step48_phase == "down":
		var remaining: float = maxf(0.0,global_position.y-_step48_goal.y)+STEP48_POSE_TOLERANCE
		motion = Vector3.DOWN*minf(STEP48_VERTICAL_SPEED*delta,remaining)
	var sweep: Dictionary = _step48_motion(global_transform,motion)
	if _step48_phase == "down":
		if not bool(sweep["valid"]) or (bool(sweep["hit"]) and not _step48_landing_contact(sweep,_step48_body,_step48_shape)):
			_step48_cancel("down_contact_changed")
			return false
	elif not _step48_clear_motion(sweep):
		_step48_cancel("phase_sweep_blocked")
		return false
	floor_snap_length = 0.0
	velocity = motion/delta
	return true

func _step48_observe(delta: float, before: Vector3) -> void:
	if _step48_phase == "idle": return
	var rise: float = global_position.y-_step48_start.y
	_step48_stats["max_applied_rise_m"] = maxf(float(_step48_stats["max_applied_rise_m"]),rise)
	if not global_position.is_finite() or rise>STEP48_MAX_RISE+STEP48_POSE_TOLERANCE or is_on_ceiling():
		_step48_cancel("actual_pose_or_ceiling_invalid")
		return
	if (global_position-before).length()<0.0001: _step48_blocked_time += delta
	else: _step48_blocked_time = 0.0
	if _step48_blocked_time>0.12:
		_step48_cancel("actual_motion_blocked")
		return
	if _step48_phase == "down" and is_on_floor():
		var support: Dictionary = _step48_support_at(global_position,0.22,_step48_body,_step48_direction)
		var body: CollisionObject3D = support.get("collider") as CollisionObject3D
		var valid: bool = not support.is_empty() and body==_step48_body and int(support.get("shape",-1))==_step48_shape and get_floor_normal().y>=FLOOR_COS and _step48_inset_clear(global_position)
		if not valid:
			_step48_cancel("actual_landing_identity_invalid")
			return
		_step48_stats["completed"] = int(_step48_stats["completed"]) + 1
		_step48_event("completed")
		_step48_phase = "idle"
		_step48_body = null
		_step48_shape = -1
		floor_snap_length = 0.18
		velocity.y = 0.0

func entrance48_step_readback() -> Dictionary:
	var result: Dictionary = _step48_stats.duplicate(true)
	result["proposal"] = "entrance48-player-step-proposal02"
	result["enabled"] = entrance48_step_enabled
	result["active"] = _step48_phase != "idle"
	result["phase"] = _step48_phase
	result["elapsed_s"] = _step48_elapsed
	result["start"] = _step48_v(_step48_start)
	result["goal"] = _step48_v(_step48_goal)
	result["rejection_counts"] = _step48_rejections.duplicate(true)
	result["last_attempt"] = _step48_last_attempt.duplicate(true)
	result["events"] = _step48_events.duplicate(true)
	result["scope"] = "Provisional tagged-stair capsule sweeps and bounded staged velocity; native floor flags/motion remain authoritative; no engine or visual proof from counters alone."
	return result
