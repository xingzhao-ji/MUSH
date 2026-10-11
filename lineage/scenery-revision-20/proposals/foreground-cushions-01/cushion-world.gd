extends "res://lineage/scenery-revision-19/proposals/rooted-substitution-01/substitution-world.gd"

const _REVIEW20_HERB = preload("res://lineage/scenery-revision-19/proposals/clump-mesh-02/clump-mesh-library.gd")
const _REVIEW20_MAX_ROOTS: int = 144
const _REVIEW20_MAX_TRIANGLES: int = 9216
const _REVIEW20_MIN_PER_SITE: int = 6
const _REVIEW20_MIN_TOTAL: int = 84
const _REVIEW20_COMPARISON_CENTER: Vector2 = Vector2(4.0, 14.0)
const _REVIEW20_COMPARISON_RADIUS: float = 0.70
var _review20_records: Array[Dictionary] = []
var _review20_sites: Array[Dictionary] = []
var _review20_groups: Array[Dictionary] = []
var _review20_stones: Array[Dictionary] = []
var _review20_errors: Array[String] = []
var _review20_status: String = "not_started"
var _review20_rng_before: int = 0
var _review20_rng_after: int = 0
var _review20_attempted: int = 0
var _review20_accepted: int = 0

func _ready() -> void:
	super._ready()
	_review20_rng_before = _rng.state
	_review20_build_patches()
	_review20_rng_after = _rng.state

func _review20_layout() -> Array[Dictionary]:
	# Proposed visible pockets, grounded in root-run exact960px projection/support sample03.
	return [
		{"site": "left_middle", "center": Vector2(2.0, 13.0), "axis": Vector2(0.55, 0.45), "turn": -0.40},
		{"site": "left_front", "center": Vector2(3.0, 15.0), "axis": Vector2(0.62, 0.45), "turn": -0.50},
		{"site": "center_front", "center": Vector2(5.0, 15.0), "axis": Vector2(0.58, 0.45), "turn": 0.30},
		{"site": "bank_middle", "center": Vector2(6.5, 14.0), "axis": Vector2(0.46, 0.62), "turn": 0.25},
		{"site": "shore_stone_skirt", "center": Vector2(6.5, 12.8), "axis": Vector2(0.47, 0.58), "turn": 0.50},
		{"site": "hero_stone_landward", "center": Vector2(4.4, 11.9), "axis": Vector2(0.60, 0.44), "turn": -0.25},
		{"site": "path_middle", "center": Vector2(3.0, 11.5), "axis": Vector2(0.58, 0.44), "turn": 0.20},
		{"site": "stone_skirt_near", "center": Vector2(5.5, 13.5), "axis": Vector2(0.58, 0.42), "turn": 0.30},
		{"site": "left_corner", "center": Vector2(1.7, 14.3), "axis": Vector2(0.60, 0.46), "turn": 0.40},
		{"site": "left_path_edge", "center": Vector2(1.2, 13.2), "axis": Vector2(0.48, 0.43), "turn": -0.20},
		{"site": "center_pocket", "center": Vector2(2.8, 13.6), "axis": Vector2(0.58, 0.43), "turn": 0.60},
		{"site": "front_bank_skirt", "center": Vector2(5.8, 14.8), "axis": Vector2(0.55, 0.44), "turn": -0.35}
	]

func _review20_root_pattern() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.64, -0.25), Vector2(-0.32, -0.40), Vector2(0.07, -0.43), Vector2(0.42, -0.21), Vector2(0.61, 0.13), Vector2(0.34, 0.43), Vector2(-0.02, 0.35), Vector2(-0.38, 0.30), Vector2(-0.13, -0.10), Vector2(0.16, 0.04), Vector2(-0.08, 0.11), Vector2(0.31, 0.21)])

func _review20_herb_mesh(site_index: int, root_index: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var builder: RefCounted = _REVIEW20_HERB.new()
	var phase: float = float(site_index) * 0.73 + float(root_index) * 1.17
	var interior: float = 1.0 if root_index >= 8 else 0.0
	var height: float = 0.18 + interior * 0.15 + 0.045 * (0.5 + 0.5 * sin(phase))
	var bend: Vector3 = Vector3(sin(phase) * 0.027, 0.0, cos(phase * 0.91) * 0.025)
	var path: PackedVector3Array = PackedVector3Array([Vector3.ZERO, bend * 0.42 + Vector3.UP * height * 0.52, bend + Vector3.UP * height])
	builder.call("_append_stem", vertices, normals, uvs, colors, path, 0.0052, 0.0029)
	for leaf_index: int in range(4):
		var t: float = 0.17 + float(leaf_index) * 0.22
		var start: Vector3 = Vector3.UP * height * t + bend * t * t
		var angle: float = phase * 0.38 + float(leaf_index) * 2.31 + sin(phase + float(leaf_index)) * 0.22
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var length: float = 0.160 + 0.032 * sin(phase * 0.71 + float(leaf_index) * 0.87) + interior * 0.019
		var width: float = 0.054 + 0.010 * cos(phase * 1.13 + float(leaf_index) * 0.91)
		var end_rise: float = 0.021 + 0.022 * sin(phase + float(leaf_index) * 1.2)
		var finish: Vector3 = start + direction * length + Vector3.UP * end_rise
		var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var control: Vector3 = start.lerp(finish, 0.48) + Vector3.UP * (0.045 + interior * 0.012) + side * width * sin(phase + float(leaf_index)) * 0.24
		var tint: Color = Color(0.73 + 0.09 * sin(phase * 0.37), 0.83 + 0.07 * cos(phase * 0.44), 0.68 + 0.07 * sin(phase * 0.51), 1.0)
		builder.call("_append_leaf", vertices, normals, uvs, colors, start, control, finish, width, 0.13 * sin(phase + float(leaf_index)), tint)
	builder.call("_smooth_normals", vertices, normals)
	return _array_mesh(vertices, normals, uvs, colors)

func _review20_surface_basis(normal_value: Vector3, turn: float) -> Basis:
	var up: Vector3 = normal_value.normalized()
	var right: Vector3 = Vector3(cos(turn), 0.0, -sin(turn))
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up).normalized())

func _review20_actual_reach(mesh: ArrayMesh, basis_value: Basis) -> float:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var reach: float = 0.0
	for point: Vector3 in vertices:
		var offset: Vector3 = basis_value * point
		reach = maxf(reach, Vector2(offset.x, offset.z).length())
	return reach + 0.006

func _review20_mesh_issue(mesh: ArrayMesh) -> String:
	if mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return "mesh_surface"
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	if vertices.size() != 192 or normals.size() != 192 or uvs.size() != 192 or colors.size() != 192:
		return "mesh_channel_count"
	for index: int in range(vertices.size()):
		if not vertices[index].is_finite() or not normals[index].is_finite() or not uvs[index].is_finite() or not is_finite(colors[index].r) or not is_finite(colors[index].g) or not is_finite(colors[index].b) or not is_finite(colors[index].a):
			return "mesh_nonfinite"
		if absf(normals[index].length_squared() - 1.0) > 0.002:
			return "mesh_normal_length"
	for index: int in range(0, vertices.size(), 3):
		var face: Vector3 = (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
		if face.length_squared() <= 0.000000000000000001:
			return "mesh_degenerate"
		for corner: int in range(3):
			if face.normalized().dot(normals[index + corner]) <= 0.0:
				return "mesh_opposed_normal"
	return ""

func _review20_comparison_clear(origin: Vector3, reach: float, samples: PackedVector3Array, basis_value: Basis) -> bool:
	if Vector2(origin.x, origin.z).distance_to(_REVIEW20_COMPARISON_CENTER) < _REVIEW20_COMPARISON_RADIUS + reach:
		return false
	for sample: Vector3 in samples:
		var point: Vector3 = origin + basis_value * sample
		if Vector2(point.x, point.z).distance_to(_REVIEW20_COMPARISON_CENTER) < _REVIEW20_COMPARISON_RADIUS:
			return false
	return true

func _review20_add_to_bucket(bucket: Dictionary, record: Dictionary) -> void:
	var mesh: ArrayMesh = record["mesh"] as ArrayMesh
	var xf: Transform3D = record["transform"] as Transform3D
	var arrays: Array = mesh.surface_get_arrays(0)
	var local_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var local_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var local_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var local_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var vertices: PackedVector3Array = bucket["vertices"] as PackedVector3Array
	var normals: PackedVector3Array = bucket["normals"] as PackedVector3Array
	var uvs: PackedVector2Array = bucket["uvs"] as PackedVector2Array
	var colors: PackedColorArray = bucket["colors"] as PackedColorArray
	record["corner_start"] = vertices.size()
	record["corner_count"] = local_vertices.size()
	for index: int in range(local_vertices.size()):
		vertices.append(xf * local_vertices[index])
		normals.append((xf.basis * local_normals[index]).normalized())
		uvs.append(local_uvs[index])
		colors.append(local_colors[index])
	bucket["vertices"] = vertices
	bucket["normals"] = normals
	bucket["uvs"] = uvs
	bucket["colors"] = colors
	(bucket["records"] as Array).append(record["sequence"])

func _review20_build_patches() -> void:
	_review20_status = "preparing"
	var inherited: Dictionary = get_review19_substitution_evidence()
	var inherited_report: Dictionary = get_review19_substitution_report()
	if inherited_report.get("status", "") != "complete":
		_review20_errors.append("R19 unchanged substitution must complete first")
		_review20_status = "integrity_failed"
		return
	for stone: Dictionary in inherited["stones"] as Array:
		_review20_stones.append(stone)
	var layout: Array[Dictionary] = _review20_layout()
	var pattern: PackedVector2Array = _review20_root_pattern()
	var buckets: Dictionary = {}
	for id: String in ["leaf", "leaf_dark"]:
		buckets[id] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "records": []}
	for site_index: int in range(layout.size()):
		var site: Dictionary = layout[site_index]
		var center: Vector2 = site["center"] as Vector2
		var axis: Vector2 = site["axis"] as Vector2
		var turn: float = float(site["turn"])
		var accepted: int = 0
		var reasons: Dictionary = {}
		for root_index: int in range(pattern.size()):
			_review20_attempted += 1
			var offset: Vector2 = (pattern[root_index] * axis).rotated(turn)
			var origin: Vector3 = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
			var support: Dictionary = _rooted_ground_support(origin)
			var mesh: ArrayMesh = _review20_herb_mesh(site_index, root_index)
			var basis_value: Basis = Basis.from_euler(Vector3(0.0, turn + float(root_index) * 0.71, 0.0))
			if not support.is_empty():
				origin.y = float(support["height"])
				basis_value = _review20_surface_basis(support["normal"] as Vector3, turn + float(root_index) * 0.71)
			var samples: PackedVector3Array = _rooted_group_samples(mesh)
			var reach: float = _review20_actual_reach(mesh, basis_value)
			var reason: String = _review20_mesh_issue(mesh)
			if reason.is_empty() and support.is_empty():
				reason = "missing_root_support"
			if reason.is_empty() and reach > 0.30:
				reason = "declared_reach_exceeds_0_30"
			if reason.is_empty() and not _review20_comparison_clear(origin, reach, samples, basis_value):
				reason = "comparison_pose_exclusion"
			if reason.is_empty():
				reason = _rooted_group_guard(origin, basis_value, reach, samples, _review19_relevant_stones(origin, reach))
			var id: String = "leaf_dark" if root_index >= 8 else "leaf"
			var record: Dictionary = {"sequence": _review20_records.size(), "site": site["site"], "site_index": site_index, "root_index": root_index, "origin": origin, "transform": Transform3D(basis_value, origin), "mesh": mesh, "samples": samples, "reach": reach, "id": id, "support": support, "accepted": reason.is_empty(), "reason": "accepted" if reason.is_empty() else reason, "node": null, "surface": 0, "corner_start": -1, "corner_count": 0}
			_review20_records.append(record)
			if reason.is_empty():
				accepted += 1
				_review20_accepted += 1
				_review20_add_to_bucket(buckets[id] as Dictionary, record)
			else:
				reasons[reason] = int(reasons.get(reason, 0)) + 1
		_review20_sites.append({"site": site["site"], "center": center, "axis": axis, "turn": turn, "attempted": pattern.size(), "accepted": accepted, "rejected": pattern.size() - accepted, "reasons": reasons})
		if accepted < _REVIEW20_MIN_PER_SITE:
			_review20_errors.append("Insufficient proposed flowing mass at %s: %d < %d roots" % [site["site"], accepted, _REVIEW20_MIN_PER_SITE])
	if _review20_attempted != _REVIEW20_MAX_ROOTS or _review20_accepted < _REVIEW20_MIN_TOTAL:
		_review20_errors.append("Insufficient aggregate roots or wrong attempt cardinality")
	if not _review20_errors.is_empty():
		_review20_status = "insufficient_mass"
		return
	var parent: Node3D = Node3D.new()
	parent.name = "RootedForegroundCushions20"
	add_child(parent)
	var triangles: int = 0
	for id: String in ["leaf", "leaf_dark"]:
		var bucket: Dictionary = buckets[id] as Dictionary
		var vertices: PackedVector3Array = bucket["vertices"] as PackedVector3Array
		if vertices.is_empty():
			continue
		triangles += int(vertices.size() / 3)
		var merged: ArrayMesh = _array_mesh(vertices, bucket["normals"] as PackedVector3Array, bucket["uvs"] as PackedVector2Array, bucket["colors"] as PackedColorArray)
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = "FlowingHerbs_" + id
		node.mesh = merged
		node.material_override = _materials[id] as Material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		for sequence: int in bucket["records"] as Array:
			_review20_records[sequence]["node"] = node
		_review20_groups.append({"node": node, "mesh": merged, "id": id, "surface": 0, "records": (bucket["records"] as Array).duplicate(), "corners": vertices.size(), "triangles": vertices.size() / 3, "shadow": "OFF"})
	if triangles > _REVIEW20_MAX_TRIANGLES or _review20_groups.size() > 4:
		_review20_errors.append("Declared triangle/draw budget exceeded")
	_review20_status = "complete" if _review20_errors.is_empty() else "integrity_failed"

func get_review20_cushion_evidence() -> Dictionary:
	return {"records": _review20_records, "sites": _review20_sites, "groups": _review20_groups, "stones": _review20_stones, "comparison_center": _REVIEW20_COMPARISON_CENTER, "comparison_radius": _REVIEW20_COMPARISON_RADIUS, "rng_before": _review20_rng_before, "rng_after": _review20_rng_after}

func get_review20_cushion_report() -> Dictionary:
	var records: Array[Dictionary] = []
	for record: Dictionary in _review20_records:
		var item: Dictionary = record.duplicate()
		var xf: Transform3D = record["transform"] as Transform3D
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		for key: String in ["mesh", "samples", "transform", "node", "support", "origin"]:
			item.erase(key)
		item["origin"] = [xf.origin.x, xf.origin.y, xf.origin.z]
		item["exact_transform_hex"] = var_to_bytes(xf).hex_encode()
		item["render_path"] = String(node.get_path()) if node != null else ""
		records.append(item)
	var sites: Array[Dictionary] = []
	for site: Dictionary in _review20_sites:
		var item: Dictionary = site.duplicate()
		var center: Vector2 = item["center"] as Vector2
		var axis: Vector2 = item["axis"] as Vector2
		item["center"] = [center.x, center.y]
		item["axis"] = [axis.x, axis.y]
		sites.append(item)
	return {"schema": "mush-r20-rooted-flowing-cushions/1", "status": _review20_status, "errors": _review20_errors.duplicate(), "attempted": _review20_attempted, "accepted": _review20_accepted, "rejected": _review20_attempted - _review20_accepted, "sites": sites, "records": records, "merged_nodes": _review20_groups.size(), "triangles": _review20_accepted * 64 if _review20_status == "complete" else 0, "max_triangles": _REVIEW20_MAX_TRIANGLES, "min_per_site": _REVIEW20_MIN_PER_SITE, "min_total": _REVIEW20_MIN_TOTAL, "rng_before": _review20_rng_before, "rng_after": _review20_rng_after, "comparison_disk": {"center": [4.0, 14.0], "proposed_visual_radius": 0.70, "source_capsule_radius": 0.28, "source_capsule_height": 0.95}, "scope": "Existing R19 scene runs unchanged first; appended rooted plants only. Seven-point guard evidence is discrete, not continuous clipping; actual QA must compare triangle envelopes and old render scope."}
