extends "res://lineage/scenery-revision-20/proposals/foreground-cushions-01/cushion-world.gd"

# Proposed R21 replacement: inherited R20 assembly runs once; no second plant layer.
var _review21_choices: Array[Dictionary] = []
var _review21_errors: Array[String] = []
var _review21_status: String = "not_started"
var _review21_new_count: int = 0
var _review21_fallback_count: int = 0
var _review21_sites: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_review21_status = "checking"
	if _review20_status != "complete" or _review20_accepted != 144 or _review21_choices.size() != 144:
		_review21_errors.append("All original144 R20 roots and assembly must remain complete")
	var layout: Array[Dictionary] = _review20_layout()
	for site_index: int in range(layout.size()):
		var changed: int = 0
		var fallback: int = 0
		var reasons: Dictionary = {}
		for root_index: int in range(12):
			var sequence: int = site_index * 12 + root_index
			if sequence >= _review21_choices.size() or sequence >= _review20_records.size():
				continue
			var choice: Dictionary = _review21_choices[sequence]
			var record: Dictionary = _review20_records[sequence]
			choice["final_record"] = record
			if record["transform"] != choice["original_transform"] or record["mesh"] != choice["selected_mesh"] or not bool(record["accepted"]):
				_review21_errors.append("Original root/selected mesh binding differs at %d" % sequence)
			if not String(choice["mesh_issue"]).is_empty():
				_review21_errors.append("Proposed intrinsic mesh failure at %d: %s" % [sequence, choice["mesh_issue"]])
			if bool(choice["substituted"]):
				changed += 1
				_review21_new_count += 1
			else:
				fallback += 1
				_review21_fallback_count += 1
			var reason: String = String(choice["reason"])
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		_review21_sites.append({"site": layout[site_index]["site"], "site_index": site_index, "new": changed, "fallback": fallback, "reasons": reasons})
		if changed < 6:
			_review21_errors.append("Insufficient NEW connected growth at %s: %d < 6" % [layout[site_index]["site"], changed])
	if _review21_new_count < 84 or _review21_new_count + _review21_fallback_count != 144:
		_review21_errors.append("Insufficient NEW aggregate mass or changed original cardinality")
	_review21_status = "complete" if _review21_errors.is_empty() else "integrity_failed"

func _review20_herb_mesh(site_index: int, root_index: int) -> ArrayMesh:
	# Parent constructs its original component as an exact provenance/fallback resource.
	var old_mesh: ArrayMesh = super._review20_herb_mesh(site_index, root_index)
	var proposed_mesh: ArrayMesh = _review21_low_fan_mesh(site_index, root_index)
	var site: Dictionary = _review20_layout()[site_index]
	var pattern: PackedVector2Array = _review20_root_pattern()
	var center: Vector2 = site["center"] as Vector2
	var axis: Vector2 = site["axis"] as Vector2
	var turn: float = float(site["turn"])
	var offset: Vector2 = (pattern[root_index] * axis).rotated(turn)
	var origin: Vector3 = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
	var support: Dictionary = _rooted_ground_support(origin)
	var basis_value: Basis = Basis.from_euler(Vector3(0.0, turn + float(root_index) * 0.71, 0.0))
	if not support.is_empty():
		origin.y = float(support["height"])
		basis_value = _review20_surface_basis(support["normal"] as Vector3, turn + float(root_index) * 0.71)
	var samples: PackedVector3Array = _rooted_group_samples(proposed_mesh)
	var reach: float = _review20_actual_reach(proposed_mesh, basis_value)
	var mesh_issue: String = _review20_mesh_issue(proposed_mesh)
	var reason: String = mesh_issue
	if reason.is_empty() and support.is_empty():
		reason = "missing_root_support"
	if reason.is_empty() and reach > 0.30:
		reason = "declared_reach_exceeds_0_30"
	if reason.is_empty() and not _review20_comparison_clear(origin, reach, samples, basis_value):
		reason = "comparison_pose_exclusion"
	if reason.is_empty():
		reason = _rooted_group_guard(origin, basis_value, reach, samples, _review19_relevant_stones(origin, reach))
	var substituted: bool = reason.is_empty()
	var selected_mesh: ArrayMesh = proposed_mesh if substituted else old_mesh
	_review21_choices.append({"sequence": _review21_choices.size(), "site": site["site"], "site_index": site_index, "root_index": root_index, "original_transform": Transform3D(basis_value, origin), "old_mesh": old_mesh, "proposed_mesh": proposed_mesh, "selected_mesh": selected_mesh, "proposed_reach": reach, "selected_reach": _review20_actual_reach(selected_mesh, basis_value), "substituted": substituted, "reason": "accepted_new" if substituted else reason, "mesh_issue": mesh_issue, "final_record": {}})
	return selected_mesh

func _review21_low_fan_mesh(site_index: int, root_index: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var builder: RefCounted = _REVIEW20_HERB.new()
	var phase: float = float(site_index) * 0.73 + float(root_index) * 1.17
	var inner_index: int = (root_index - 8 + site_index) % 4 if root_index >= 8 else -1
	var tall: bool = inner_index == 0 or inner_index == 2
	var wave: float = 0.5 + 0.5 * sin(phase)
	# Eight low perimeter stems, two medium inner stems, only two unequal tall shoots.
	var height: float = 0.078 + 0.034 * wave
	if root_index >= 8:
		height = 0.127 + 0.033 * wave
	if tall:
		height = 0.205 + 0.060 * wave + (0.018 if inner_index == 2 else 0.0)
	var bend: Vector3 = Vector3(sin(phase * 0.83) * 0.043, 0.0, cos(phase * 1.07) * 0.035)
	var path: PackedVector3Array = PackedVector3Array([Vector3.ZERO, bend * 0.35 + Vector3.UP * height * 0.46, bend + Vector3.UP * height])
	builder.call("_append_stem", vertices, normals, uvs, colors, path, 0.0052, 0.0029)
	var attachments: PackedFloat64Array = PackedFloat64Array([0.23, 0.36, 0.54, 0.73])
	var fan_angles: PackedFloat64Array = PackedFloat64Array([-1.31, -0.37, 0.58, 1.49])
	var lengths: PackedFloat64Array = PackedFloat64Array([0.185, 0.205, 0.174, 0.153])
	for leaf_index: int in range(4):
		var t: float = attachments[leaf_index]
		var start: Vector3 = Vector3.UP * height * t + bend * t * t
		var angle: float = phase * 0.38 + fan_angles[leaf_index] + 0.19 * sin(phase + float(leaf_index) * 1.3)
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var length: float = lengths[leaf_index] + 0.016 * sin(phase * 0.71 + float(leaf_index) * 0.87)
		var width: float = 0.077 + 0.011 * cos(phase * 1.13 + float(leaf_index) * 0.91)
		var end_rise: float = 0.003 + 0.011 * (0.5 + 0.5 * sin(phase + float(leaf_index) * 1.2))
		var finish: Vector3 = start + direction * length + Vector3.UP * end_rise
		var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var arch: float = 0.025 + 0.014 * (0.5 + 0.5 * cos(phase * 0.9 + float(leaf_index)))
		var control: Vector3 = start.lerp(finish, 0.46) + Vector3.UP * arch + side * width * sin(phase + float(leaf_index)) * 0.19
		# Existing R20 palette; no registry material or light changes.
		var tint: Color = Color(0.73 + 0.09 * sin(phase * 0.37), 0.83 + 0.07 * cos(phase * 0.44), 0.68 + 0.07 * sin(phase * 0.51), 1.0)
		builder.call("_append_leaf", vertices, normals, uvs, colors, start, control, finish, width, 0.10 * sin(phase + float(leaf_index)), tint)
	builder.call("_smooth_normals", vertices, normals)
	return _array_mesh(vertices, normals, uvs, colors)

func get_review21_connected_evidence() -> Dictionary:
	return {"choices": _review21_choices, "inherited20": get_review20_cushion_evidence(), "sites": _review21_sites, "status": _review21_status, "errors": _review21_errors}

func get_review21_connected_report() -> Dictionary:
	var choices: Array[Dictionary] = []
	for choice: Dictionary in _review21_choices:
		var item: Dictionary = choice.duplicate()
		var xf: Transform3D = choice["original_transform"] as Transform3D
		var record: Dictionary = choice["final_record"] as Dictionary
		var node: MeshInstance3D = record.get("node", null) as MeshInstance3D
		for key: String in ["old_mesh", "proposed_mesh", "selected_mesh", "original_transform", "final_record"]:
			item.erase(key)
		item["exact_original_transform_hex"] = var_to_bytes(xf).hex_encode()
		item["render_path"] = String(node.get_path()) if node != null else ""
		item["surface"] = record.get("surface", -1)
		item["corner_start"] = record.get("corner_start", -1)
		item["corner_count"] = record.get("corner_count", 0)
		choices.append(item)
	return {"schema": "mush-r21-connected-cushion-replacement/1", "status": _review21_status, "errors": _review21_errors.duplicate(), "attempted": _review21_choices.size(), "new": _review21_new_count, "fallback": _review21_fallback_count, "min_new_per_site": 6, "min_new_total": 84, "sites": _review21_sites, "choices": choices, "inherited20": get_review20_cushion_report(), "scope": "Exactly one replacement pass inside inherited R20 assembly. Original roots/poses/materials/layout and64triangles each; unsafe new shapes use original20 components at the same roots. Seven-point guards are discrete; independent actual merged continuous-triangle checks/render/performance remain required."}
