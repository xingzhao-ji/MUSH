extends SkeletonModifier3D
## Visual contact for MUSH's two short feet. No body, collider or camera writes.
## The native modifier runs after AnimationPlayer and restores the input pose each tick.
const MAX_OFFSET := 0.075
const CLEARANCE := 0.002
const RESPONSE := 22.0
var player: CharacterBody3D
var feet: Array[Dictionary] = []
var offsets := PackedFloat32Array([0.0, 0.0])
var last_position := Vector3.ZERO
var initialized := false
var diagnostics := false
var samples: Array[Dictionary] = []
var elapsed_usec := 0
var query_count := 0

func configure(body: CharacterBody3D) -> void:
	player = body
	var skeleton := get_skeleton()
	assert(skeleton != null and feet.is_empty())
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	for side: String in ["Left", "Right"]:
		var bone := skeleton.find_bone(side.to_lower() + "_foot")
		var attachment := skeleton.get_node(side + "Foot") as BoneAttachment3D
		var shapes: Array[Dictionary] = []
		for label: String in ["FootMesh", "PawSole"]:
			var mesh := attachment.get_node(label) as MeshInstance3D
			assert(mesh.mesh is SphereMesh)
			shapes.append({"transform": mesh.transform, "radius": (mesh.mesh as SphereMesh).radius})
		feet.append({"bone": bone, "shapes": shapes, "sole": shapes[1].transform.origin})
	reset_contact()

func reset_contact() -> void:
	offsets.fill(0.0)
	initialized = false

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(player) or feet.size() != 2 or delta <= 0.0:
		return
	var started := Time.get_ticks_usec() if diagnostics else 0
	var skeleton := get_skeleton()
	var discontinuity := not initialized or player.global_position.distance_to(last_position) > 0.5
	if discontinuity:
		offsets.fill(0.0)
	last_position = player.global_position
	initialized = true
	var grounded: bool = player.is_on_floor() and player.state in ["Grounded", "Landing"] and not player._pending_teleport
	var alpha := 1.0 - exp(-RESPONSE * minf(delta, 0.05))
	if diagnostics:
		samples.clear()
		query_count = 0
	for index: int in range(feet.size()):
		var foot: Dictionary = feet[index]
		var bone: int = foot.bone
		var authored := skeleton.get_bone_pose_position(bone)
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.global_basis * skeleton.get_bone_global_pose(parent).basis
		var world_pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		# Remove authored swing lift only while finding the baseline contact offset.
		# Applying that offset to the unmodified pose preserves the original lift.
		var lift := maxf(0.0, (parent_basis * (authored - skeleton.get_bone_rest(bone).origin)).y)
		world_pose.origin.y -= lift
		var target := 0.0
		var accepted := false
		var hit: Dictionary = {}
		if grounded:
			var probe: Vector3 = world_pose * foot.sole
			var query := PhysicsRayQueryParameters3D.create(Vector3(probe.x, player.global_position.y + 0.18, probe.z), Vector3(probe.x, player.global_position.y - 0.18, probe.z), player.WORLD_MASK, [player.get_rid()])
			query.collide_with_areas = false
			hit = player.get_world_3d().direct_space_state.intersect_ray(query)
			if diagnostics: query_count += 1
			if not hit.is_empty() and (hit.normal as Vector3).y >= player.FLOOR_COS and not bool(hit.collider.get_meta("unsafe_support", false)):
				var normal: Vector3 = hit.normal
				target = -INF
				for shape: Dictionary in foot.shapes:
					var transform: Transform3D = world_pose * shape.transform
					# Exact support extent of this transformed sphere against the sampled plane.
					var extent: float = shape.radius * (transform.basis.transposed() * normal).length()
					target = maxf(target, (normal.dot(hit.position - transform.origin) + extent) / normal.y + CLEARANCE)
				accepted = is_finite(target) and absf(target) <= MAX_OFFSET
				if not accepted: target = 0.0
		# Never retain a terrain pose while airborne, recovering or teleported.
		# Stance changes use bounded exponential smoothing; no wall/cliff stretching.
		if not grounded:
			offsets[index] = 0.0
		else:
			offsets[index] = lerpf(offsets[index], target, alpha)
		skeleton.set_bone_pose_position(bone, authored + parent_basis.inverse() * (Vector3.UP * offsets[index]))
		if diagnostics:
			samples.append({"bone": skeleton.get_bone_name(bone), "grounded": grounded, "accepted": accepted, "target": target, "offset": offsets[index], "authored_lift": lift, "hit_position": hit.get("position", Vector3.ZERO), "hit_normal": hit.get("normal", Vector3.ZERO), "hit_rid": str(hit.get("rid", RID())), "input_pose": authored, "output_pose": skeleton.get_bone_pose_position(bone), "physics_frame": Engine.get_physics_frames(), "in_physics_frame": Engine.is_in_physics_frame()})
	if diagnostics: elapsed_usec = Time.get_ticks_usec() - started
