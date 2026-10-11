extends RefCounted
## Native support lookup fixtures only; no player movement or controller mutation.
## Caller awaits run(player, game) in the actual world, with a settled player.
const ORIGIN := Vector3(4.0, 2.0, 16.0)
const DEPTH := 0.4
const MASK := 1 | 4 | 16
const FLOOR_COS := 0.819152

func _check(report: Dictionary, label: String, passed: bool) -> void:
	report.checks.append({"label": label, "passed": passed})
	if not passed: report.failed += 1

func _sync(tree: SceneTree) -> void:
	await tree.physics_frame
	await tree.physics_frame
	await tree.process_frame

func _state(player: CharacterBody3D) -> Dictionary:
	var stats: Dictionary = player.get("_step48_stats").duplicate(true)
	stats.erase("paired_supports")
	return {"transform": player.global_transform, "velocity": player.velocity,
		"state": player.get("state"), "safe_position": player.get("safe_position"),
		"enabled": player.get("enabled"), "require_release": player.get("_require_release"),
		"phase": player.get("_step48_phase"), "floor": player.is_on_floor(),
		"layer": player.collision_layer, "mask": player.collision_mask,
		"snap": player.floor_snap_length, "angle": player.floor_max_angle,
		"margin": player.safe_margin, "slides": player.max_slides,
		"stop_on_slope": player.floor_stop_on_slope,
		"constant_speed": player.floor_constant_speed,
		"camera_yaw": player.get("camera_yaw"), "camera_pitch": player.get("camera_pitch"),
		"process": player.is_processing(), "physics": player.is_physics_processing(),
		"paused": player.get_tree().paused, "stats_except_paired_supports": stats}

func _patch(x: float, y: float) -> PackedVector3Array:
	# Godot clockwise upward faces, identical orientation to retained paving tops.
	var a := Vector3(x - 0.04, y, -0.10)
	var b := Vector3(x - 0.04, y, 0.10)
	var c := Vector3(x + 0.04, y, 0.10)
	var d := Vector3(x + 0.04, y, -0.10)
	return PackedVector3Array([a, c, b, a, d, c])

func _build(container: Node3D, patches: Dictionary) -> Dictionary:
	var bodies: Dictionary = {}
	for body_index: int in [0, 1]:
		var groups: Dictionary = {}
		for key: String in patches:
			var spec: Array = patches[key] # [local X, local Y, body index, shape index]
			if int(spec[2]) != body_index: continue
			var index := int(spec[3])
			var faces: PackedVector3Array = groups.get(index, PackedVector3Array())
			faces.append_array(_patch(float(spec[0]), float(spec[1])))
			groups[index] = faces
		if groups.is_empty(): continue
		var body := StaticBody3D.new()
		body.name = "SupportFixtureBody%d" % body_index
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = ORIGIN
		body.set_meta("entrance48_step_surface", true)
		body.set_meta("entrance48_step_bounds", Rect2(Vector2(3.6, 15.7), Vector2(0.8, 0.6)))
		for shape_index: int in [0, 1]:
			if not groups.has(shape_index): continue
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(groups[shape_index])
			var shape_node := CollisionShape3D.new()
			shape_node.shape = shape
			body.add_child(shape_node)
		container.add_child(body)
		bodies[body_index] = body
	return bodies

func _ray(player: CharacterBody3D, feet: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.08,
		feet - Vector3.UP * DEPTH, MASK, [player.get_rid()])
	query.collide_with_areas = false
	return player.get_world_3d().direct_space_state.intersect_ray(query)

func _wire(hit: Dictionary) -> Dictionary:
	if hit.is_empty(): return {"hit": false}
	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	return {"hit": true, "body_id": collider.get_instance_id(),
		"path": str((collider as Node).get_path()), "rid": str(hit.get("rid")),
		"shape": int(hit.get("shape", -1)), "position": [point.x, point.y, point.z],
		"normal": [normal.x, normal.y, normal.z],
		"position_f32_hex": PackedVector3Array([point]).to_byte_array().hex_encode(),
		"normal_f32_hex": PackedVector3Array([normal]).to_byte_array().hex_encode()}

func _same_hit(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and a.get("collider") == b.get("collider") \
		and int(a.get("shape", -1)) == int(b.get("shape", -1)) \
		and a.get("position") == b.get("position") and a.get("normal") == b.get("normal")

func run(player: CharacterBody3D, game: Node3D) -> Dictionary:
	var report := {"schema": "mush-native-paired-support-fixtures/1", "passed": false,
		"failed": 0, "checks": [], "cases": [], "source_only": true,
		"scope": "Native support proposals only; no full-step or movement acceptance.",
		"query_mask": MASK, "ray_start_y": 2.28, "ray_end_y": 1.8}
	var valid: bool = is_instance_valid(player) and is_instance_valid(game) \
		and player.is_inside_tree() and game.is_inside_tree() \
		and player.has_method("_step48_support_at") and not player.get_tree().paused
	_check(report, "Actual player helper and unpaused native world available", valid)
	if not valid: return report
	var capsule := player.get("_capsule") as CapsuleShape3D
	valid = capsule != null and is_equal_approx(capsule.radius, 0.28) \
		and not bool(player.call("_outside_playable", ORIGIN)) \
		and not bool(player.call("_over_water", ORIGIN)) \
		and player.global_position.distance_to(ORIGIN) > 1.0
	_check(report, "Admitted radius, dry playable test location and remote player", valid)
	if not valid: return report
	var patch_faces := _patch(0.0, 0.0)
	var minimum_up_dot := INF
	for corner: int in range(0, patch_faces.size(), 3):
		var cross := (patch_faces[corner + 2] - patch_faces[corner]).cross(patch_faces[corner + 1] - patch_faces[corner])
		minimum_up_dot = minf(minimum_up_dot, cross.dot(Vector3.UP))
	report["patch_clockwise_cross_dot_up_min"] = minimum_up_dot
	_check(report, "Both patch triangles have positive project-convention upward winding", is_finite(minimum_up_dot) and minimum_up_dot > 0.0)
	if not is_finite(minimum_up_dot) or minimum_up_dot <= 0.0: return report
	var feet := ORIGIN + Vector3.UP * 0.2
	var offset := capsule.radius * 0.5
	var rays := {"center": feet, "left": feet - Vector3.RIGHT * offset,
		"right": feet + Vector3.RIGHT * offset}
	var clear := true
	for key: String in rays: clear = clear and _ray(player, rays[key]).is_empty()
	_check(report, "All three bounded ray segments initially empty", clear)
	if not clear: return report
	var cases: Array[Dictionary] = [
		{"label": "center_equal_wins", "patches": {"center": [0.0, 0.0, 0, 0], "left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "center"},
		{"label": "center_higher_wins", "patches": {"center": [0.0, 0.04, 0, 0], "left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "center"},
		{"label": "qualified_higher_pair", "patches": {"center": [0.0, -0.04, 0, 0], "left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "pair"},
		{"label": "empty_center_pair", "patches": {"left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "pair"},
		{"label": "one_side_missing", "patches": {"left": [-offset, 0.0, 0, 0]}, "expected": "empty"},
		{"label": "unequal_heights", "patches": {"left": [-offset, 0.0, 0, 0], "right": [offset, 0.03, 0, 0]}, "expected": "empty"},
		{"label": "different_shapes", "patches": {"left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 1]}, "expected": "empty"},
		{"label": "different_bodies", "patches": {"left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 1, 0]}, "expected": "empty"},
		{"label": "wrong_center_body_preserved", "patches": {"center": [0.0, -0.04, 1, 0], "left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "center"},
		{"label": "wrong_center_shape_preserved", "patches": {"center": [0.0, -0.04, 0, 1], "left": [-offset, 0.0, 0, 0], "right": [offset, 0.0, 0, 0]}, "expected": "center"}]
	var before := _state(player)
	var children_before: Array = game.get_children()
	for entry: Dictionary in cases:
		var container := Node3D.new()
		container.name = "NativeSupportFixtures"
		game.add_child(container)
		container.global_transform = Transform3D.IDENTITY
		var bodies := _build(container, entry.patches)
		await _sync(player.get_tree())
		var raw: Dictionary = {}
		var raw_wires: Dictionary = {}
		var evidence_valid := true
		for key: String in rays:
			var hit := _ray(player, rays[key])
			raw[key] = hit
			raw_wires[key] = _wire(hit)
			if entry.patches.has(key):
				var spec: Array = entry.patches[key]
				var normal: Vector3 = hit.get("normal", Vector3.ZERO)
				evidence_valid = evidence_valid and not hit.is_empty() \
					and hit.get("collider") == bodies[int(spec[2])] \
					and int(hit.get("shape", -1)) == int(spec[3]) and normal.y >= FLOOR_COS
			else: evidence_valid = evidence_valid and hit.is_empty()
		var result: Dictionary = player.call("_step48_support_at", feet, DEPTH,
			bodies[0], Vector3.FORWARD)
		var matches := false
		match entry.expected:
			"center": matches = _same_hit(result, raw.center)
			"empty": matches = result.is_empty()
			"pair": matches = _same_hit(result, raw.left) or _same_hit(result, raw.right)
		var row := {"label": entry.label, "expected": entry.expected,
			"raw_native_rays": raw_wires, "actual_support": _wire(result),
			"native_fixture_hits_admitted": evidence_valid, "passed": evidence_valid and matches}
		container.free()
		container = null
		await _sync(player.get_tree())
		row["fixture_removed"] = game.get_children() == children_before
		row.passed = bool(row.passed) and bool(row.fixture_removed)
		report.cases.append(row)
		_check(report, str(entry.label), bool(row.passed))
	report["player_state_unchanged_except_paired_counter"] = _state(player) == before
	report["actual_fixture_nodes_removed"] = game.get_children() == children_before
	_check(report, "Player pose settings state and other counters unchanged", bool(report.player_state_unchanged_except_paired_counter))
	_check(report, "All native fixture nodes actually removed", bool(report.actual_fixture_nodes_removed))
	report["assertions"] = report.checks.size()
	report.passed = int(report.failed) == 0 and report.cases.size() == cases.size()
	return report
