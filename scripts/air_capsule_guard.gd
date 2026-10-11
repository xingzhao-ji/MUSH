extends "res://lineage/entrance48-player-step-proposal02/player.gd"
## Candidate AIR planar clearance guard; native resolution and settings are inherited.
## Zero planar displacement keeps ordinary vertical Float and landing support.

func _safe_hover_support(feet: Vector3) -> bool:
	if not super._safe_hover_support(feet):
		return false
	var motion: Vector3 = feet - global_position
	if motion == Vector3.ZERO:
		return true
	var capsule_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not state in AIR_STATES or not motion.is_finite() or motion.y != 0.0 or capsule_node == null or capsule_node.disabled or capsule_node.shape != _capsule or not capsule_node.shape is CapsuleShape3D:
		return _air_room_refused()
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule_node.shape
	query.transform = capsule_node.global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# A cast ignores initial overlaps: a nonempty start refuses lateral commitment.
	if not space.intersect_shape(query, 1).is_empty():
		return _air_room_refused()
	query.motion = motion
	query.margin = safe_margin
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] != 1.0 or fractions[1] != 1.0:
		return _air_room_refused()
	# Endpoint overlap is a stationary query of the actual capsule, with no lift.
	query.transform.origin += motion
	query.motion = Vector3.ZERO
	query.margin = 0.0
	if not space.intersect_shape(query, 1).is_empty():
		return _air_room_refused()
	return true

func _air_room_refused() -> bool:
	# Use the existing feedback throttle; preserve the inherited landing-support text.
	if _movement_input().length() > 0.1 and _blocked_notice <= 0.0:
		feedback.emit("Float needs a little more room here.")
		_blocked_notice = 2.5
	return false


func _build_camera() -> void:
	super._build_camera()
	# The pinned engine's explicit-shape SpringArm path ignores its margin.
	# A native child offset supplies the intended 5cm inset without another cast
	# or per-frame solver. The same Camera3D and its fade/controls remain in use.
	var carrier:=Node3D.new()
	carrier.name="ShapeCastCameraMargin"
	_spring_arm.add_child(carrier)
	_camera.reparent(carrier,false)
	_camera.position=Vector3(0,0,-.05)
