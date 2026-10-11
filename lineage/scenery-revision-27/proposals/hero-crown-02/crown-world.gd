extends "res://lineage/scenery-revision-25/proposals/left-bank-join-01/rising-world.gd"

# Detached main-cap geometry proposal. No original source or live asset is changed.
const _R27_PATH: String = "res://lineage/scenery-revision-27/proposals/hero-crown-02/crown-world.gd"
const _R27_BAKE_DIR: String = "res://lineage/scenery-revision-27/owned-bake01/"
const _R27_REVISION: String = "hero-crown-27-v2"
const _R27_SCHEMA: String = "rooted-foreground-groups-r27-v1"
const _R27_MAIN_RADIUS: float = 5.25
const _R27_MAIN_CROWN: float = 2.30
const _R27_MAIN_ORIGIN: Vector3 = Vector3(0.0, 6.50, 0.0)
const _R27_CROWN_RISE: float = 0.80
const _R27_EFFECTIVE_CROWN: float = 3.10
const _R27_BROAD_VALLEY: float = 0.012
const _R27_PARENT_WORLD = preload("res://lineage/scenery-revision-25/proposals/left-bank-join-01/rising-world.gd")
var _r27_errors: Array[String] = []
var _r27_status: String = "not_started"
var _r27_main_calls: int = 0
var _r27_cap_calls: Array[Dictionary] = []
var _r27_main_parts: Array[Dictionary] = []
var _r27_baseline_profile: Array[Vector2] = []
var _r27_selected_profile: Array[Vector2] = []
var _r27_bake: Dictionary = {"mode": "not_started"}
var _r27_parent_ground_fingerprint: String = ""
var _r27_chimney: Dictionary = {}

func _ready() -> void:
	super._ready()
	if _r25_status != "complete":
		_r27_errors.append("Inherited R25 assembly incomplete")
	if _r27_main_calls != 1 or _r27_main_parts.size() != 2:
		_r27_errors.append("Exactly one verified main cap and its two existing mesh nodes required")
	if not bool(_r27_chimney.get("attachment_measured", false)):
		_r27_errors.append("Main chimney native triangle attachment shift missing")
	if not ["authored", "baked"].has(String(_r27_bake.get("mode", ""))):
		_r27_errors.append("Fresh R27 all474 author/replay required")
	_r27_status = "complete" if _r27_errors.is_empty() else "integrity_failed"

func _r27_main_style(radius: float, crown: float) -> bool:
	return radius == _R27_MAIN_RADIUS and crown == _R27_MAIN_CROWN

func _cap(origin: Vector3, radius: float, crown: float, parent: Node3D) -> void:
	var main: bool = _r27_main_style(radius, crown) and origin == _R27_MAIN_ORIGIN and parent.name == "MushroomHome"
	var first: int = parent.get_child_count()
	var rng_before: int = _rng.state
	if radius == _R27_MAIN_RADIUS and not main:
		_r27_errors.append("Main-radius caller does not match verified hero origin/crown/parent")
	super._cap(origin, radius, crown, parent)
	_r27_cap_calls.append({"origin": origin, "radius": radius, "crown": crown, "parent_name": String(parent.name), "main": main, "rng_before": rng_before, "rng_after": _rng.state})
	if not main:
		return
	_r27_main_calls += 1
	for ordinal: int in range(first, parent.get_child_count()):
		var node: MeshInstance3D = parent.get_child(ordinal) as MeshInstance3D
		if node != null and ["FoldedPeachUmbrella", "ContinuousPleatedCreamUnderbody"].has(String(node.name)):
			_r27_main_parts.append({"name": String(node.name), "node": node, "mesh": node.mesh, "transform": node.transform, "material_override": node.material_override, "cast_shadow": node.cast_shadow, "constructor_ordinal": ordinal})

func _cap_rolled_profile(radius: float, crown: float) -> Array[Vector2]:
	var original: Array[Vector2] = super._cap_rolled_profile(radius, crown)
	if not _r27_main_style(radius, crown):
		return original
	_r27_baseline_profile = original.duplicate()
	if original.size() != 41:
		_r27_errors.append("Verified main profile41 cardinality changed")
		return original
	var selected: Array[Vector2] = original.duplicate()
	var exponent_value: float = 0.49
	var start_fraction: float = 0.955
	for i: int in range(33):
		var fraction: float = original[i].x / radius
		var point: Vector2 = selected[i]
		point.y += _R27_CROWN_RISE * pow(maxf(0.0, 1.0-fraction*fraction), exponent_value)
		selected[i] = point
	# Carry the new dome's start value AND radial derivative through the same
	# cubic's control X values. The exact original cream endpoint/tangent stay.
	var start_delta: float = _R27_CROWN_RISE * pow(1.0-start_fraction*start_fraction, exponent_value)
	var slope_delta: float = -2.0*_R27_CROWN_RISE*exponent_value*start_fraction*pow(1.0-start_fraction*start_fraction, exponent_value-1.0)
	var control_a_delta: float = start_delta + slope_delta*(1.006-start_fraction)
	for i: int in range(1, 8):
		var t: float = float(i)/8.0
		var u: float = 1.0-t
		var point: Vector2 = selected[32+i]
		point.y += start_delta*u*u*u + control_a_delta*3.0*u*u*t
		selected[32+i] = point
	_r27_selected_profile = selected.duplicate()
	return selected

func _cap_surface_point(profile_point: Vector2, theta: float, radius: float, skin: bool) -> Vector3:
	var point: Vector3 = super._cap_surface_point(profile_point, theta, radius, skin)
	if not skin or radius != _R27_MAIN_RADIUS:
		return point
	var fraction: float = profile_point.x/radius
	var lip_height: float = _cap_main_lip_height(fraction, radius)
	var gate: float = smoothstep(0.24, 0.52, fraction)*smoothstep(lip_height+0.01, lip_height+radius*0.22, profile_point.y)
	# Subordinate unequal valleys follow the higher continuous dome. No positive
	# angular flesh lobes or annular shoulder lift; inherited fine detail remains.
	var phase: float = theta*14.0 + sin(theta*3.0+0.29)*0.52 + sin(theta*7.0-0.41)*0.22 + sin(fraction*2.7+theta*2.0)*0.70
	var valley: float = pow(0.5+0.5*sin(phase), 3.0)
	var unequal: float = 0.65+0.35*(0.5+0.5*sin(theta*3.0+0.67))
	point.y -= radius*_R27_BROAD_VALLEY*unequal*valley*gate
	return point

func _create_chimney(parent: Node3D) -> void:
	super._create_chimney(parent)
	if parent.name != "MushroomHome":
		return
	var chimney: Node3D = parent.get_node_or_null("MushroomLanternChimney") as Node3D
	var selected_skin: ArrayMesh
	for part: Dictionary in _r27_main_parts:
		if part["name"] == "FoldedPeachUmbrella":
			selected_skin = part["mesh"] as ArrayMesh
	if chimney == null or selected_skin == null:
		_r27_errors.append("Native main skin/chimney relation absent")
		return
	var old_world: Node3D = _R27_PARENT_WORLD.new() as Node3D
	var original_profile: Array[Vector2] = old_world.call("_cap_rolled_profile", _R27_MAIN_RADIUS, _R27_MAIN_CROWN) as Array[Vector2]
	var original_skin: ArrayMesh = old_world.call("_cap_surface_mesh", original_profile, _R27_MAIN_RADIUS, true) as ArrayMesh
	var never_inside_tree: bool = not old_world.is_inside_tree()
	old_world.free()
	var attachment: Vector2 = Vector2(chimney.position.x, chimney.position.z)
	if attachment != Vector2(-0.50, -0.55) or not never_inside_tree:
		_r27_errors.append("Original chimney attachment/pure baseline identity changed")
		return
	var original_hit: Dictionary = _r27_skin_hit(original_skin, attachment)
	var selected_hit: Dictionary = _r27_skin_hit(selected_skin, attachment)
	if original_hit.is_empty() or selected_hit.is_empty():
		_r27_errors.append("Native chimney attachment triangle containment unavailable")
		return
	var before: Transform3D = chimney.transform
	var children: Array[Dictionary] = _r27_chimney_children(chimney)
	var delta: float = float(selected_hit["height"])-float(original_hit["height"])
	chimney.position.y += delta
	_r27_chimney = {"attachment_measured": true, "node": chimney, "baseline_root_transform": before, "selected_root_transform": chimney.transform, "attachment_xz": attachment, "baseline_surface_height": original_hit["height"], "selected_surface_height": selected_hit["height"], "requested_delta_y": delta, "actual_delta_y": float(chimney.position.y)-float(before.origin.y), "baseline_skin": original_skin, "baseline_hit": original_hit, "selected_hit": selected_hit, "baseline_never_inside_tree": never_inside_tree, "children_before_root_shift": children}

func _r27_skin_hit(mesh: ArrayMesh, xz: Vector2) -> Dictionary:
	# Read the renderer's packed vertices/index stream directly. Mesh.get_faces()
	# constructs TriangleMesh and snaps coordinates to 0.0001 m in Godot 4.7.2.
	if mesh == null or mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		_r27_errors.append("Chimney attachment requires one native triangle surface")
		return {}
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		_r27_errors.append("Chimney attachment native vertex channel unavailable")
		return {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var faces: PackedVector3Array = PackedVector3Array()
	if arrays[Mesh.ARRAY_INDEX] == null:
		faces = vertices
	elif arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			faces = vertices
		else:
			for index: int in indices:
				if index < 0 or index >= vertices.size():
					_r27_errors.append("Chimney attachment native index out of range")
					return {}
				faces.append(vertices[index])
	else:
		_r27_errors.append("Chimney attachment native index channel invalid")
		return {}
	if faces.size() != 15360*3:
		_r27_errors.append("Chimney attachment main native triangle cardinality changed")
		return {}
	var answer: Dictionary = {}
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i+1]
		var c: Vector3 = faces[i+2]
		var bx: float = float(b.x)-float(a.x)
		var bz: float = float(b.z)-float(a.z)
		var cx: float = float(c.x)-float(a.x)
		var cz: float = float(c.z)-float(a.z)
		var determinant: float = bx*cz-bz*cx
		if determinant == 0.0:
			continue
		var px: float = float(xz.x)-float(a.x)
		var pz: float = float(xz.y)-float(a.z)
		var u: float = (px*cz-pz*cx)/determinant
		var v: float = (bx*pz-bz*px)/determinant
		if u < 0.0 or v < 0.0 or u+v > 1.0:
			continue
		var height_value: float = float(a.y)+u*(float(b.y)-float(a.y))+v*(float(c.y)-float(a.y))
		if answer.is_empty() or height_value > float(answer["height"]):
			answer = {"height": height_value, "triangle_ordinal": i/3, "a": a, "b": b, "c": c, "barycentric": [1.0-u-v, u, v], "frame": "main cap local; origin(0,6.50,0) cancels in old/new difference"}
	return answer

func _r27_chimney_children(parent: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for child: Node in parent.get_children():
		if child is Node3D:
			var node: Node3D = child as Node3D
			var record: Dictionary = {"name": String(node.name), "node": node, "transform": node.transform, "class": node.get_class()}
			if node is MeshInstance3D:
				var instance: MeshInstance3D = node as MeshInstance3D
				record["mesh"] = instance.mesh
				record["material_override"] = instance.material_override
			if node is Light3D:
				var light: Light3D = node as Light3D
				record["light_energy"] = light.light_energy
				record["light_color"] = light.light_color
			records.append(record)
			records.append_array(_r27_chimney_children(node))
	return records

func _rooted_groups_fingerprint() -> String:
	_r27_parent_ground_fingerprint = super._rooted_groups_fingerprint()
	if _r27_parent_ground_fingerprint.is_empty():
		return ""
	return _r22_sha(var_to_bytes([_R27_REVISION, FileAccess.get_sha256(_R27_PATH), _r27_parent_ground_fingerprint]))

func get_review27_bake_document() -> Dictionary:
	var doc: Dictionary = _rooted_groups_bake_document()
	doc["schema"] = _R27_SCHEMA
	doc["authoring_revision"] = _R27_REVISION
	return doc

func _r27_decode(doc: Dictionary) -> Dictionary:
	if doc.get("schema", "") != _R27_SCHEMA or doc.get("authoring_revision", "") != _R27_REVISION or doc.get("codec_revision", "") != _ROOTED_GROUPS_CODEC_REVISION:
		return {"ok": false, "error": "FreshR27 schema/revision/codec required"}
	var adapter: Dictionary = doc.duplicate()
	adapter["schema"] = "rooted-foreground-groups-v2"
	adapter["authoring_revision"] = _ROOTED_GROUPS_AUTHORING_REVISION
	return _rooted_groups_decode_bake(adapter)

func _create_rooted_ground_groups() -> void:
	if not _r25_errors.is_empty() or not _r27_errors.is_empty() or _r25_stair_collision == null:
		_r27_refuse("Inherited construction/main-cap selector failed before author/replay")
		return
	if bool(get_meta("review27_author_mode", false)):
		_generate_rooted_ground_groups()
		_r27_set_bake({"mode": "authored", "reason": "Explicit standaloneR27 author mode", "fingerprint": _rooted_groups_fingerprint(), "parent_ground_fingerprint": _r27_parent_ground_fingerprint})
		return
	var path: String = String(get_meta("review27_bake_lock_path", ""))
	var pin: String = String(get_meta("review27_bake_lock_sha256", ""))
	var error: String = "Immutable fresh R27 bake lock/pin missing"
	var decoded: Dictionary = {}
	if path.is_absolute_path() and path == path.simplify_path() and path.begins_with(_R27_BAKE_DIR) and pin.length() == 64:
		var bytes: PackedByteArray = _r22_read(path, 16384)
		if not bytes.is_empty() and _r22_sha(bytes) == pin:
			var json: JSON = JSON.new()
			if json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
				var lock: Dictionary = json.data as Dictionary
				var payload_path: String = String(lock.get("payload_path", ""))
				var payload_sha: String = String(lock.get("payload_sha256", ""))
				if lock.get("schema", "") == "mush-r27-owned-bake-lock/1" and lock.get("authoring_revision", "") == _R27_REVISION and lock.get("candidate_sha256", "") == FileAccess.get_sha256(_R27_PATH) and lock.get("fingerprint", "") == _rooted_groups_fingerprint() and lock.get("attempt_count", 0) == 474 and lock.get("codec_revision", "") == _ROOTED_GROUPS_CODEC_REVISION and payload_path.is_absolute_path() and payload_path == payload_path.simplify_path() and payload_path.begins_with(_R27_BAKE_DIR) and payload_sha.length() == 64:
					var payload: PackedByteArray = _r22_read(payload_path, _ROOTED_GROUPS_BAKE_LIMIT)
					if not payload.is_empty() and payload.size() == int(lock.get("payload_bytes", -1)) and _r22_sha(payload) == payload_sha:
						var payload_json: JSON = JSON.new()
						if payload_json.parse(payload.get_string_from_utf8()) == OK and payload_json.data is Dictionary:
							decoded = _r27_decode(payload_json.data as Dictionary)
							error = String(decoded.get("error", "Decode rejected"))
						else:
							error = "FreshR27 payload JSON invalid"
					else:
						error = "FreshR27 payload size/SHA invalid"
				else:
						error = "FreshR27 lock candidate/revision/fingerprint/path invalid"
			else:
				error = "FreshR27 lock JSON invalid"
		else:
			error = "FreshR27 lock size/SHA invalid"
	if not bool(decoded.get("ok", false)):
		_r27_refuse(error)
		return
	var records: Array[Dictionary] = decoded["records"] as Array[Dictionary]
	for record: Dictionary in records:
		if bool(record["accepted"]):
			_add_foliage(record["id"] as String, _foreground_understory_meshes[record["label"]] as ArrayMesh, record["origin"] as Vector3, record["turn"] as Vector3, record["scale"] as Vector3)
	_rooted_foreground_group_records = records
	_rooted_foreground_group_stats = decoded["stats"] as Dictionary
	_r27_set_bake({"mode": "baked", "reason": "Fresh all474 R27 SHA/fingerprint rows validated before replay", "fingerprint": decoded["fingerprint"], "parent_ground_fingerprint": _r27_parent_ground_fingerprint, "lock_path": path, "lock_sha256": pin})

func _r27_set_bake(state: Dictionary) -> void:
	_r27_bake = state.duplicate()
	_r25_bake = state.duplicate()
	_r22_bake = state.duplicate()
	_rooted_foreground_group_load_status = state.duplicate()

func _r27_refuse(reason: String) -> void:
	_r27_set_bake({"mode": "refused", "reason": reason, "fingerprint": _rooted_groups_fingerprint(), "parent_ground_fingerprint": _r27_parent_ground_fingerprint})
	_r27_errors.append("Normal R27 bake REFUSED before append: " + reason)

func get_review27_cap_report() -> Dictionary:
	var rng_equal: bool = true
	for call_record: Dictionary in _r27_cap_calls:
		rng_equal = rng_equal and call_record["rng_before"] == call_record["rng_after"]
	var parts: Array[Dictionary] = []
	for part: Dictionary in _r27_main_parts:
		var mesh: ArrayMesh = part["mesh"] as ArrayMesh
		var triangle_count: int = 0
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			triangle_count += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		parts.append({"name": part["name"], "surfaces": mesh.get_surface_count(), "triangles": triangle_count, "transform": str(part["transform"])})
	return {"schema": "mush-r27-hero-cap/1", "status": _r27_status, "errors": _r27_errors.duplicate(), "stats": {"main_cap_calls": _r27_main_calls, "cap_call_rng_states_equal": rng_equal, "parts": parts, "profile_rows": _r27_selected_profile.size(), "sides": 192, "effective_crown_m_formula": _R27_EFFECTIVE_CROWN, "crown_rise_m_formula": _R27_CROWN_RISE, "chimney_attachment": _r27_chimney_summary(), "maximum_broad_valley_depth_m_formula": _R27_MAIN_RADIUS*_R27_BROAD_VALLEY, "bake": _r27_bake.duplicate(), "rooted_attempts": _rooted_foreground_group_records.size(), "rooted_stats": _rooted_foreground_group_stats.duplicate(true)}, "inherited": get_review25_approach_report(), "scope": "Only main peach skin Y/normal/tangent plus rigid chimney rootY changes: a higher continuous central dome, C1 rolled return and subordinate unequal valleys. Profile X, angular sampling, exact lip/cream underside/neck/windows, all colliders/materials/light parameters/nonmain caps and RNG remain. Chimney child meshes and local transforms remain; any child light follows its rigid root. All dimensions/proportions provisional; native quality/boundary/placement equality and fixed-camera appearance remain actual root tests."}

func get_review27_cap_evidence() -> Dictionary:
	return {"status": _r27_status, "errors": _r27_errors, "main_parts": _r27_main_parts, "cap_calls": _r27_cap_calls, "baseline_profile": _r27_baseline_profile, "selected_profile": _r27_selected_profile, "bake": _r27_bake, "parent_ground_fingerprint": _r27_parent_ground_fingerprint, "chimney": _r27_chimney, "rooted_records": _rooted_foreground_group_records, "rooted_stats": _rooted_foreground_group_stats}

func _r27_chimney_summary() -> Dictionary:
	return {"attachment_measured": _r27_chimney.get("attachment_measured", false), "attachment_xz": [-0.50, -0.55], "baseline_surface_height": _r27_chimney.get("baseline_surface_height", null), "selected_surface_height": _r27_chimney.get("selected_surface_height", null), "requested_delta_y": _r27_chimney.get("requested_delta_y", null), "actual_delta_y": _r27_chimney.get("actual_delta_y", null), "baseline_never_inside_tree": _r27_chimney.get("baseline_never_inside_tree", false), "rule": "Difference of top hits on actual native old/new cap triangles at original chimney rootXZ; rigid rootY only, original embedding preserved."}
