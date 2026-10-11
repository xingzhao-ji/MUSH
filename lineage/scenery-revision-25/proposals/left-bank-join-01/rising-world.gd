extends "res://lineage/scenery-revision-22/proposals/soil-shoulder-03/terrain-world.gd"

# Detached procedural proposal only. All design values need actual contact and image review.
const _R25_PATH: String = "res://lineage/scenery-revision-25/proposals/left-bank-join-01/rising-world.gd"
const _R25_BAKE_DIR: String = "res://lineage/scenery-revision-25/owned-bake01/"
const _R25_REVISION: String = "left-bank-join-25-v1"
const _R25_SCHEMA: String = "rooted-foreground-groups-r25-v1"
const _R25_BASELINE_PATH: String = "res://lineage/scenery-revision-24/proposals/entrance-approach-06/rising-world.gd"
const _R25_BASELINE_SHA: String = "97e03f7381c6cdc682c429fe959eaaa4d4bb53599090c143a6de43e9571fac4f"
const _R25_BASELINE_WORLD = preload("res://lineage/scenery-revision-24/proposals/entrance-approach-06/rising-world.gd")
var _r25_baseline_path_faces: PackedVector3Array = PackedVector3Array()
var _r25_path_proof: Dictionary = {"passed": false}
var _r25_join_proof: Array[Dictionary] = []
var _r25_rect: Rect2
var _r25_faces: PackedVector3Array = PackedVector3Array()
var _r25_soil_faces: PackedVector3Array = PackedVector3Array()
var _r25_path_faces: PackedVector3Array = PackedVector3Array()
var _r25_base_faces: PackedVector3Array = PackedVector3Array()
var _r25_cells: Dictionary = {}
var _r25_meshes: Array[Dictionary] = []
var _r25_path_nodes: Array[Dictionary] = []
var _r25_placements: Array[Dictionary] = []
var _r25_shrubs: Array[Dictionary] = []
var _r25_seams: Array[Dictionary] = []
var _r25_errors: Array[String] = []
var _r25_stats: Dictionary = {}
var _r25_bake: Dictionary = {"mode": "not_started"}
var _r25_status: String = "not_started"
var _r25_stair_collision: CollisionShape3D
var _r25_old_west_faces: PackedVector3Array = PackedVector3Array()
var _r25_old_stair_faces: PackedVector3Array = PackedVector3Array()
var _r25_stair_nodes: Array[Dictionary] = []
var _r25_extra_stones: Array[Dictionary] = []
var _r25_flank: Dictionary = {}
var _r25_ready_top: bool = false
var _r25_direct_foliage: bool = false
var _r25_context_depth: int = 0
var _r25_rigid_poses: Array[Dictionary] = []
var _r25_pose_samples: Dictionary = {}

func _ready() -> void:
	super._ready()
	if _r22_status != "complete":
		_r25_errors.append("Inherited terrain/foliage assembly incomplete")
	if not ["authored", "baked"].has(String(_r25_bake.get("mode", ""))):
		_r25_errors.append("Fresh all474 R25 author/replay required")
	if _r25_stair_collision == null or _r25_path_faces.is_empty():
		_r25_errors.append("Original stair support relation missing")
	_r25_stats["bake"] = _r25_bake.duplicate(true)
	_r25_stats["rooted_attempts"] = _rooted_foreground_group_records.size()
	_r25_stats["rooted_stats"] = _rooted_foreground_group_stats.duplicate(true)
	_r25_status = "complete" if _r25_errors.is_empty() else "integrity_failed"

func _path_ribbon(points: Array[Vector3], width: float, parent: Node3D, authored: bool = false) -> void:
	var before: int = parent.get_child_count()
	super._path_ribbon(points, width, parent, authored)
	var main: bool = points.size() == 5 and points[0] == Vector3(-2, 0.028, 23) and points[4] == Vector3(0, 0.028, 3)
	var branch: bool = points.size() == 3 and points[0] == Vector3(-1, 0.02, 11) and points[2] == Vector3(6.7, 0.02, 7.5)
	if not main and not branch:
		return
	for ordinal: int in range(before, parent.get_child_count()):
		var node: MeshInstance3D = parent.get_child(ordinal) as MeshInstance3D
		if node != null:
			_r25_path_nodes.append({"node": node, "kind": "ribbon" if ordinal == parent.get_child_count() - 1 else "paving", "route": "main" if main else "branch", "original_mesh": node.mesh, "original_transform": node.transform, "constructor_ordinal": ordinal})

func _create_foreground_bank_transitions(parent: Node3D, west: CollisionShape3D, east: CollisionShape3D) -> void:
	super._create_foreground_bank_transitions(parent, west, east)
	_r25_status = "building"
	if _r22_status == "integrity_failed" or _r22_ground == null or west != _r22_collision or not west.shape is ConcavePolygonShape3D:
		_r25_errors.append("Inherited west terrain relation unavailable")
		return
	_r25_old_west_faces = (west.shape as ConcavePolygonShape3D).get_faces().duplicate()
	var grid: PackedVector3Array = _foreground_bank_original_faces[0]
	var native_xs: Array[float] = []
	for p: Vector3 in grid:
		if not native_xs.has(float(p.x)):
			native_xs.append(float(p.x))
	native_xs.sort()
	if native_xs.size() != 33:
		_r25_errors.append("Expected original33 west grid columns")
		return
	_r25_rect = _r22_rect(native_xs[20], native_xs[28], 3.0, 11.0)
	var xs: Array[float] = []
	for i: int in range(20, 28):
		for quarter: int in range(4):
			xs.append(float(Vector3((native_xs[i] * float(4 - quarter) + native_xs[i + 1] * float(quarter)) / 4.0, 0, 0).x))
	xs.append(native_xs[28])
	var zs: Array[float] = []
	for i: int in range(17):
		zs.append(float(Vector3(0, 0, 3.0 + float(i) * 0.5).z))
	for i: int in range(8):
		var end_z: float = 9.5 - float(i + 1) * 0.8
		zs.append(float(Vector3(0, 0, end_z).z))
		zs.append(float(Vector3(0, 0, end_z + _r25_nose(i)).z))
	zs.append(float(Vector3(0, 0, 3.1).z))
	zs.sort()
	var unique_zs: Array[float] = []
	for z: float in zs:
		if not unique_zs.has(z):
			unique_zs.append(z)
	var soil: Dictionary = _r22_bucket()
	var path: Dictionary = _r22_bucket()
	_r25_flank = _r22_bucket()
	for band: int in range(3):
		var previous: PackedVector3Array = PackedVector3Array()
		for z: float in unique_zs:
			var row: PackedVector3Array = _r25_row(xs, z, band)
			if not previous.is_empty():
				_r25_join_rows(previous, row, band, soil, path)
			previous = row
	_r25_soil_faces = (soil["v"] as PackedVector3Array).duplicate()
	_r25_path_faces = (path["v"] as PackedVector3Array).duplicate()
	_r25_prove_baseline_path(xs, unique_zs)
	_r25_faces = _r25_soil_faces.duplicate()
	_r25_faces.append_array(_r25_path_faces)
	_r25_build_index()
	_r25_ready_top = true
	for z: float in unique_zs:
		for x: float in PackedFloat64Array([_r25_rect.position.x, _r25_rect.end.x]):
			var p: Vector3 = Vector3(x, 0, z)
			_r25_seams.append({"xz": Vector2(p.x, p.z), "inherited_physical": _r25_base(p), "canonical": _r25_surface(p), "threshold_exception": false})
	_r25_measure()
	var selected: ArrayMesh = _r25_remove_patch(_r22_ground.mesh as ArrayMesh, _r22_ground, "west_ground", soil)
	if selected == null:
		return
	_r22_ground.mesh = selected
	var outside: PackedVector3Array = _r25_outside(_r25_old_west_faces)
	outside.append_array(_r25_soil_faces)
	(west.shape as ConcavePolygonShape3D).set_faces(outside)
	for record: Dictionary in _r25_path_nodes:
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		if record["kind"] == "ribbon":
			var ribbon: ArrayMesh = _r25_remove_patch(node.mesh as ArrayMesh, node, String(record["route"]) + "_ribbon", _r22_bucket())
			if ribbon != null:
				node.mesh = ribbon
		else:
			_r25_embed_paving(node, record)
	# Flank curtains make the existing narrow raised threshold explicit, not a broad
	# fictitious elevated floor underneath unchanged entry pots. They never collide.
	for i: int in range(unique_zs.size() - 1):
		var za: float = unique_zs[i]
		var zb: float = unique_zs[i + 1]
		for side: float in PackedFloat64Array([-1.0, 1.0]):
			var pa: Vector3 = Vector3(_r25_center(za) + side * _r25_width(za), 0, za)
			var pb: Vector3 = Vector3(_r25_center(zb) + side * _r25_width(zb), 0, zb)
			var a: Vector3 = Vector3(pa.x, _r25_grade(za), za)
			var b: Vector3 = Vector3(pb.x, _r25_grade(zb), zb)
			var c: Vector3 = Vector3(pb.x, _r25_soil_height(pb), zb)
			var d: Vector3 = Vector3(pa.x, _r25_soil_height(pa), za)
			if side < 0.0:
				_r25_emit(a, b, c, _r25_flank, Color(0.89, 0.94, 0.84), false)
				_r25_emit(a, c, d, _r25_flank, Color(0.89, 0.94, 0.84), false)
			else:
				_r25_emit(a, c, b, _r25_flank, Color(0.89, 0.94, 0.84), false)
				_r25_emit(a, d, c, _r25_flank, Color(0.89, 0.94, 0.84), false)
	_r22_stones = _rooted_ground_stone_cache()
	_r25_stats["original_west_triangles"] = _r25_old_west_faces.size() / 3
	_r25_stats["selected_west_triangles"] = outside.size() / 3
	_r25_stats["west_collision_delta"] = (outside.size() - _r25_old_west_faces.size()) / 3

func _r25_nose(i: int) -> float:
	return PackedFloat64Array([0.21, 0.24, 0.20, 0.23, 0.21, 0.24, 0.20, 0.23])[i]

func _r25_grade(z: float) -> float:
	var rises: PackedFloat64Array = PackedFloat64Array([0.070, 0.085, 0.065, 0.080, 0.070, 0.085, 0.065, 0.080])
	var height: float = 0.0
	for i: int in range(8):
		var end_z: float = 9.5 - float(i + 1) * 0.8
		height += rises[i] * clampf((end_z + _r25_nose(i) - z) / _r25_nose(i), 0.0, 1.0)
	return height

func _r25_center(z: float) -> float:
	return -clampf((z - 5.5) / 5.5, 0.0, 1.0)

func _r25_width(z: float) -> float:
	# Original ramp half-width at the threshold; unequal shallow lower shoulders.
	return 1.08 + 0.055 * smoothstep(5.7, 9.5, z) + 0.015 * sin((z - 5.7) * 2.1) * smoothstep(5.7, 6.5, z) * (1.0 - smoothstep(9.0, 9.5, z))

func _r25_base(p: Vector3) -> Dictionary:
	# Original physical west faces, not analytical sine terrain or a made-up plane.
	var cells: int = 53
	var x0: float = -24.0
	var step_x: float = 31.8 / 32.0
	var xi: int = clampi(int(floor((p.x - x0) / step_x)), 0, 31)
	var zi: int = clampi(int(floor(p.z + 24.0)), 0, 52)
	var faces: PackedVector3Array = _foreground_bank_original_faces[0]
	for x: int in range(maxi(0, xi - 1), mini(31, xi + 1) + 1):
		for z: int in range(maxi(0, zi - 1), mini(52, zi + 1) + 1):
			var start: int = (x * cells + z) * 6
			for tri: int in range(2):
				var i: int = start + tri * 3
				var hit: Dictionary = _foreground_bank_triangle_support(p, faces[i], faces[i + 1], faces[i + 2], -24, false)
				if not hit.is_empty():
					return hit
	return {}

func _r25_soil_original(p: Vector3) -> float:
	var old: Dictionary = _r25_base(p)
	var base: float = float(old.get("height", 0.0))
	var edge: float = minf(minf(p.x - _r25_rect.position.x, _r25_rect.end.x - p.x), minf(p.z - 3.0, 11.0 - p.z))
	if edge <= 0.0:
		return base
	# Upper entry pots, paid garden and branch remain at their original physical level.
	var pot_mask: float = 1.0
	for side: float in PackedFloat64Array([-1.0, 1.0]):
		for index: int in range(3):
			var q: Vector2 = Vector2(side * (1.25 + 0.38 * index), 3.55 + 0.26 * (index % 2))
			pot_mask = minf(pot_mask, smoothstep(0.42, 0.85, Vector2(p.x, p.z).distance_to(q)))
	if p.x < -3.6 and p.z < 4.8:
		return base
	var route: float = 1.0
	# Existing diagonal fork leaves the raised center at its zero-grade lower end.
	var branch_distance: float = _r22_segment_distance(Vector2(p.x, p.z), Vector2(-1, 11), Vector2(4, 9))
	route *= smoothstep(1.05, 2.00, branch_distance)
	var left: float = maxf(0.0, 1.0 - pow((p.x + 1.75) / 2.30, 2.0) - pow((p.z - 7.65) / 2.65, 2.0))
	var right: float = maxf(0.0, 1.0 - pow((p.x - 1.55) / 2.20, 2.0) - pow((p.z - 7.10) / 2.45, 2.0))
	var saddle: float = maxf(0.0, 1.0 - pow((p.x + 0.10) / 3.10, 2.0) - pow((p.z - 7.55) / 2.90, 2.0))
	var mass: float = (0.25 * left * left + 0.28 * right * right + 0.09 * saddle * saddle) * smoothstep(0.0, 0.90, edge) * pot_mask * route
	var distance_from_edge: float = absf(p.x - _r25_center(p.z)) - _r25_width(p.z)
	var tie: float = (1.0 - smoothstep(0.0, 2.00, maxf(0.0, distance_from_edge))) * smoothstep(4.8, 7.4, p.z) * (1.0 - smoothstep(9.5, 11.0, p.z))
	return base + 0.845 * maxf(mass, _r25_grade(p.z) * tie * pot_mask * route)

func _r25_join_weight(z: float) -> float:
	return smoothstep(7.0, 7.4, z) * (1.0 - smoothstep(9.5, 9.9, z))

func _r25_soil_height(p: Vector3) -> float:
	var original: float = _r25_soil_original(p)
	var longitudinal: float = _r25_join_weight(p.z)
	if longitudinal <= 0.0:
		return original
	# Match the actual native row endpoint, not a differently rounded analytic edge.
	var left: float = float(Vector3(_r25_center(p.z) - _r25_width(p.z), 0, 0).x)
	var outward: float = left - p.x
	if outward < 0.0 or outward >= 0.75:
		return original
	if longitudinal == 1.0 and outward <= 0.08:
		return _r25_grade(p.z)
	var transverse: float = 1.0 - smoothstep(0.08, 0.75, outward)
	return lerpf(original, _r25_grade(p.z), longitudinal * transverse)

func _r25_row(xs: Array[float], z: float, band: int) -> PackedVector3Array:
	var left: float = _r25_center(z) - _r25_width(z)
	var right: float = _r25_center(z) + _r25_width(z)
	var lo: float = _r25_rect.position.x if band == 0 else left if band == 1 else right
	var hi: float = left if band == 0 else right if band == 1 else _r25_rect.end.x
	var row_xs: Array[float] = [lo]
	for x: float in xs:
		if x > lo and x < hi:
			row_xs.append(x)
	row_xs.append(hi)
	if band == 0 and _r25_join_weight(z) > 0.0:
		var native_left: float = float(Vector3(left, 0, 0).x)
		for offset: float in PackedFloat64Array([0.08, 0.25, 0.50, 0.75]):
			var x: float = float(Vector3(native_left - offset, 0, 0).x)
			if x > lo and x < hi:
				row_xs.append(x)
		row_xs.sort()
		var native_unique: Array[float] = []
		for x: float in row_xs:
			var native_x: float = float(Vector3(x, 0, 0).x)
			if not native_unique.has(native_x):
				native_unique.append(native_x)
		row_xs = native_unique
	var row: PackedVector3Array = PackedVector3Array()
	for x: float in row_xs:
		var p: Vector3 = Vector3(x, 0, z)
		p.y = _r25_grade(z) if band == 1 else _r25_soil_height(p)
		row.append(p)
	return row

func _r25_prove_baseline_path(xs: Array[float], zs: Array[float]) -> void:
	if FileAccess.get_sha256(_R25_BASELINE_PATH) != _R25_BASELINE_SHA:
		_r25_errors.append("Frozen World06 path-construction source pin mismatch")
		return
	var baseline: Node3D = _R25_BASELINE_WORLD.new() as Node3D
	if baseline == null:
		_r25_errors.append("Frozen World06 noReady instance unavailable")
		return
	baseline.set("_r24_rect", _r25_rect)
	var original_path: Dictionary = _r22_bucket()
	var unused_soil: Dictionary = _r22_bucket()
	var previous: PackedVector3Array = PackedVector3Array()
	var never_inside_tree: bool = not baseline.is_inside_tree()
	for z: float in zs:
		var row: PackedVector3Array = baseline.call("_r24_row", xs, z, 1) as PackedVector3Array
		if not previous.is_empty():
			baseline.call("_r24_join_rows", previous, row, 1, unused_soil, original_path)
		previous = row
		var point: Vector3 = Vector3(_r25_center(z) - _r25_width(z), 0, z)
		var soil_row: PackedVector3Array = _r25_row(xs, z, 0)
		var soil_edge: Vector3 = soil_row[soil_row.size() - 1]
		var path_edge: Vector3 = row[0]
		_r25_join_proof.append({"z": point.z, "left_x": point.x, "longitudinal_weight": _r25_join_weight(z), "old_field_y": _r25_soil_original(point), "soil_edge_y": soil_edge.y, "path_edge_y": path_edge.y, "native_edge_y_gap_m": soil_edge.y - path_edge.y, "exact_edge_y": soil_edge.y == path_edge.y, "full_join": _r25_join_weight(z) == 1.0})
		if _r25_join_weight(z) == 1.0 and soil_edge != path_edge:
			_r25_errors.append("Full left join row does not share the unchanged native path edge")
	_r25_baseline_path_faces = (original_path["v"] as PackedVector3Array).duplicate()
	var expected: PackedByteArray = _r25_baseline_path_faces.to_byte_array()
	var actual: PackedByteArray = _r25_path_faces.to_byte_array()
	never_inside_tree = never_inside_tree and not baseline.is_inside_tree()
	var exact: bool = expected == actual and _r25_path_faces.size() == 1773 and never_inside_tree
	_r25_path_proof = {"passed": exact, "triangle_count": _r25_path_faces.size() / 3, "expected_sha256": _r22_sha(expected), "actual_sha256": _r22_sha(actual), "baseline_source_sha256": _R25_BASELINE_SHA, "object_never_inside_tree": never_inside_tree, "scope": "Full native band1 POSITION byte stream reconstructed from pinned World06 pure helpers on a never-added instance; no Ready/second scene build. Other path channels and actual stair collision remain independent checks."}
	baseline.free()
	if not exact:
		_r25_errors.append("Original591 path triangles differ from actual noReady frozen World06 reconstruction")

func _r25_join_rows(a: PackedVector3Array, b: PackedVector3Array, band: int, soil: Dictionary, path: Dictionary) -> void:
	var i: int = 0
	var j: int = 0
	var bucket: Dictionary = path if band == 1 else soil
	while i < a.size() - 1 or j < b.size() - 1:
		if j == b.size() - 1 or (i < a.size() - 1 and a[i + 1].x <= b[j + 1].x):
			_r25_emit(a[i], a[i + 1], b[j], bucket, Color(0.95, 0.98, 0.89) if band == 1 else Color(0.92, 1.0, 0.82), true)
			i += 1
		else:
			_r25_emit(a[i], b[j + 1], b[j], bucket, Color(0.95, 0.98, 0.89) if band == 1 else Color(0.92, 1.0, 0.82), true)
			j += 1

func _r25_emit(a: Vector3, b: Vector3, c: Vector3, bucket: Dictionary, color: Color, walk: bool) -> void:
	var normal_value: Vector3 = (c - a).cross(b - a)
	if normal_value.length_squared() <= 0.000000000000000001:
		return
	normal_value = normal_value.normalized()
	if walk and normal_value.y <= 0.0:
		_r25_errors.append("Downward canonical top face")
		return
	var v: PackedVector3Array = bucket["v"] as PackedVector3Array
	var n: PackedVector3Array = bucket["n"] as PackedVector3Array
	var u: PackedVector2Array = bucket["u"] as PackedVector2Array
	var colors: PackedColorArray = bucket["c"] as PackedColorArray
	for p: Vector3 in PackedVector3Array([a, b, c]):
		v.append(p)
		n.append(normal_value)
		u.append(Vector2(p.x, p.z))
		colors.append(color)
	bucket["v"] = v
	bucket["n"] = n
	bucket["u"] = u
	bucket["c"] = colors

func _r25_partition(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	var inner: Array[Vector3] = [a, b, c]
	var outside: Array[Array] = []
	var axes: PackedInt32Array = PackedInt32Array([0, 0, 2, 2])
	var limits: PackedFloat64Array = PackedFloat64Array([_r25_rect.position.x, _r25_rect.end.x, 3.0, 11.0])
	for i: int in range(4):
		var greater: bool = i % 2 == 0
		var outer: Array[Vector3] = _r22_top_clip(inner, axes[i], limits[i], not greater)
		if outer.size() >= 3:
			outside.append(outer)
		inner = _r22_top_clip(inner, axes[i], limits[i], greater)
	return {"inside": inner, "outside": outside}

func _r25_outside(source: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for i: int in range(0, source.size(), 3):
		var part: Dictionary = _r25_partition(source[i], source[i + 1], source[i + 2])
		if _r22_polygon_area(part["inside"] as Array) <= 0.000000000001:
			result.append_array(PackedVector3Array([source[i], source[i + 1], source[i + 2]]))
		else:
			for poly: Array in part["outside"] as Array:
				for fan: int in range(1, poly.size() - 1):
					if _r22_area(poly[0], poly[fan], poly[fan + 1]) > 0.000000000001:
						result.append_array(PackedVector3Array([poly[0], poly[fan], poly[fan + 1]]))
	return result

func _r25_remove_patch(source: ArrayMesh, node: MeshInstance3D, kind: String, added: Dictionary) -> ArrayMesh:
	if source == null or source.get_surface_count() < 1 or source.get_blend_shape_count() != 0:
		_r25_errors.append("Unsupported target mesh: " + kind)
		return null
	var arrays: Array = source.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	if indices.is_empty():
		for i: int in range(v.size()):
			indices.append(i)
	var retained: PackedInt32Array = PackedInt32Array()
	var removed: PackedInt32Array = PackedInt32Array()
	var clipped: PackedInt32Array = PackedInt32Array()
	for i: int in range(0, indices.size(), 3):
		var corners: PackedInt32Array = PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]])
		var a: Vector3 = node.transform * v[corners[0]]
		var b: Vector3 = node.transform * v[corners[1]]
		var c: Vector3 = node.transform * v[corners[2]]
		var part: Dictionary = _r25_partition(a, b, c)
		if _r22_polygon_area(part["inside"] as Array) <= 0.000000000001:
			retained.append_array(corners)
			continue
		removed.append(i / 3)
		for poly: Array in part["outside"] as Array:
			var local_poly: Array[Vector3] = []
			for p: Vector3 in poly:
				local_poly.append(node.transform.affine_inverse() * p)
			_r22_fragment(local_poly, corners, arrays, added, false)
			if _r22_polygon_area(poly) > 0.000000000001:
				clipped.append(i / 3)
	var stored: Array = source.get("_surfaces") as Array
	if stored.size() != source.get_surface_count() or stored.is_empty() or not stored[0] is Dictionary:
		_r25_errors.append("Raw retained target surface unavailable: " + kind)
		return null
	var encoded: Dictionary = (stored[0] as Dictionary).duplicate()
	if encoded.has("lods") or encoded.has("blend_shapes"):
		_r25_errors.append("Unsupported encoded target LOD/blend table")
		return null
	var format_value: int = int(encoded["format"]) | Mesh.ARRAY_FORMAT_INDEX
	var stride: int = RenderingServer.mesh_surface_get_format_index_stride(format_value, int(encoded["vertex_count"]))
	if stride != 2 and stride != 4:
		_r25_errors.append("Actual encoded index stride invalid")
		return null
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(retained.size() * stride)
	for i: int in range(retained.size()):
		if stride == 2:
			bytes.encode_u16(i * stride, retained[i])
		else:
			bytes.encode_u32(i * stride, retained[i])
	encoded["format"] = format_value
	encoded["index_data"] = bytes
	encoded["index_count"] = retained.size()
	var selected_stored: Array = stored.duplicate()
	var retained_source_surfaces: PackedInt32Array = PackedInt32Array()
	if retained.is_empty():
		# No whole source0 triangle survives. Outside partial fragments are already
		# in added; omit source0, never install an empty INDEX buffer that could be
		# rejected or treated as unindexed. All original extra surfaces stay raw.
		selected_stored.remove_at(0)
		for surface: int in range(1, stored.size()):
			retained_source_surfaces.append(surface)
	else:
		selected_stored[0] = encoded
		for surface: int in range(stored.size()):
			retained_source_surfaces.append(surface)
	if selected_stored.is_empty() and (added["v"] as PackedVector3Array).is_empty():
		_r25_errors.append("Fully removed target has no valid remaining surface: " + kind)
		return null
	var result: ArrayMesh = ArrayMesh.new()
	if not selected_stored.is_empty():
		result.set("_surfaces", selected_stored)
	if result.get_surface_count() != selected_stored.size():
		_r25_errors.append("Pinned multiple-surface raw setter failed")
		return null
	var extra_surface: int = selected_stored.size() if not (added["v"] as PackedVector3Array).is_empty() else -1
	_r25_append_surface(result, added)
	_r25_meshes.append({"kind": kind, "node": node, "original_mesh": source, "selected_mesh": result, "original_encoded": stored, "selected_encoded_prefix": selected_stored, "retained_source_surface_ordinals": retained_source_surfaces, "source0_omitted_without_whole_survivors": retained.is_empty(), "retained_indices": retained, "removed_original_ordinals": removed, "clipped_original_ordinals": clipped, "new_arrays_before_encoding": added, "extra_surface": extra_surface})
	return result

func _r25_append_surface(mesh: ArrayMesh, bucket: Dictionary) -> void:
	if (bucket["v"] as PackedVector3Array).is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = bucket["v"]
	arrays[Mesh.ARRAY_NORMAL] = bucket["n"]
	arrays[Mesh.ARRAY_TEX_UV] = bucket["u"]
	arrays[Mesh.ARRAY_COLOR] = bucket["c"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _r25_embed_paving(node: MeshInstance3D, record: Dictionary) -> void:
	# Restored original decorative stones, rigidly posed over the same physical
	# grade. Exact original resource/XYZ shape channels are never rebuilt.
	var original: ArrayMesh = record["original_mesh"] as ArrayMesh
	var original_xf: Transform3D = record["original_transform"] as Transform3D
	if original == null or not _r25_affects(original, original_xf):
		return
	var old_turn: Vector3 = node.rotation
	var old_scale: Vector3 = node.scale
	var support: Dictionary = _rooted_ground_support(original_xf.origin)
	if support.is_empty():
		_r25_errors.append("Restored paving missing actual root support")
		return
	var local_n: Vector3 = Basis(Vector3.UP, -old_turn.y) * (support["normal"] as Vector3)
	var selected_turn: Vector3 = Vector3(atan2(local_n.z, local_n.y), old_turn.y, asin(clampf(-local_n.x, -1.0, 1.0)))
	var p: Vector3 = original_xf.origin
	p.y = float(support["height"]) + original_xf.origin.y
	# Read the exact Node3D transform after applying the rigid pose. A synthetic
	# Basis.scaled would scale rows, unlike this node's nonuniform local scale.
	node.mesh = original
	node.rotation = selected_turn
	node.position = p
	var proposed_xf: Transform3D = node.transform
	var faces: PackedVector3Array = original.get_faces()
	var top_samples: PackedVector3Array = PackedVector3Array()
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() > 0.000000000000000001 and n.normalized().y > 0.15:
			top_samples.append_array(PackedVector3Array([a, b, c, (a + b) * 0.5, (a + c) * 0.5, (b + c) * 0.5, (a + b + c) / 3.0]))
	if top_samples.is_empty():
		_r25_errors.append("Original paving has no measured upper-facing samples")
		return
	var shift: float = -INF
	var initial_minimum: float = INF
	var initial_maximum: float = -INF
	for sample: Vector3 in top_samples:
		var q: Vector3 = proposed_xf * sample
		var hit: Dictionary = _rooted_ground_support(q)
		if hit.is_empty():
			_r25_errors.append("Restored paving missing actual footprint support")
			return
		var gap: float = q.y - float(hit["height"])
		initial_minimum = minf(initial_minimum, gap)
		initial_maximum = maxf(initial_maximum, gap)
		# Signed lower endpoint minimizes the maximum exposure while requiring
		# every resolved sample >=4mm; lowering is essential, not a guard waiver.
		shift = maxf(shift, 0.004 - gap)
	var feasible_fit: Vector2 = Vector2(0.004 - initial_minimum, 0.15 - initial_maximum)
	p.y += shift
	node.position = p
	var fit_basis_matches_actual: bool = node.transform.basis == proposed_xf.basis
	var same_original_scale: bool = node.scale == old_scale
	if not fit_basis_matches_actual or not same_original_scale:
		_r25_errors.append("Paving signed fit/actual nonuniform scale basis mismatch")
	var minimum: float = INF
	var maximum: float = -INF
	for sample: Vector3 in top_samples:
		var q: Vector3 = node.transform * sample
		var hit: Dictionary = _rooted_ground_support(q)
		if hit.is_empty():
			_r25_errors.append("Actually posed paving sample missing support")
			return
		var gap: float = q.y - float(hit["height"])
		minimum = minf(minimum, gap)
		maximum = maxf(maximum, gap)
	if minimum < 0.0038 or maximum > 0.15:
		_r25_errors.append("Restored decorative paving exposure outside proposed4mm..150mm envelope")
	record["selected_mesh"] = original
	record["selected_transform"] = node.transform
	record["original_turn"] = old_turn
	record["selected_turn"] = selected_turn
	record["original_scale"] = old_scale
	record["sampled_upper_support_gap_m"] = Vector2(minimum, maximum)
	record["vertical_fit_m"] = shift
	record["initial_upper_support_gap_m"] = Vector2(initial_minimum, initial_maximum)
	record["feasible_signed_vertical_interval_m"] = feasible_fit
	record["sampled_vertical_fit_feasible"] = feasible_fit.x <= feasible_fit.y
	record["upper_sample_count"] = top_samples.size()
	record["fit_transform_before_translation"] = proposed_xf
	record["fit_basis_matches_actual"] = fit_basis_matches_actual
	record["same_original_scale"] = same_original_scale
	record["exposure_guard_passed"] = minimum >= 0.0038 and maximum <= 0.15
	record["same_resource"] = node.mesh == original
	record["same_origin_xz"] = node.position.x == original_xf.origin.x and node.position.z == original_xf.origin.z
	record["same_yaw"] = selected_turn.y == old_turn.y
	record["noncolliding_decoration"] = true
	record["treatment"] = "exact original stone mesh/material, rigid tangent pose over dark canonical physical underpath; discrete exposure evidence, no tile collision parity"

func _create_stairs(parent: Node3D) -> void:
	var before: int = parent.get_child_count()
	super._create_stairs(parent)
	var bars: Array[MeshInstance3D] = []
	for i: int in range(before, parent.get_child_count()):
		var child: Node = parent.get_child(i)
		var body: StaticBody3D = child as StaticBody3D
		if body != null:
			for nested: Node in body.get_children():
				if nested is CollisionShape3D and (nested as CollisionShape3D).shape is ConcavePolygonShape3D:
					_r25_stair_collision = nested as CollisionShape3D
		var node: MeshInstance3D = child as MeshInstance3D
		if node == null:
			continue
		var record: Dictionary = {"node": node, "original_mesh": node.mesh, "original_transform": node.transform, "original_material": node.material_override, "kind": "bar" if node.mesh is BoxMesh else "detail"}
		_r25_stair_nodes.append(record)
		if node.mesh is BoxMesh:
			bars.append(node)
	if bars.size() != 4 or _r25_stair_collision == null or not _r25_ready_top:
		_r25_errors.append("Original4 stair bars/ramp support unavailable")
		return
	_r25_old_stair_faces = (_r25_stair_collision.shape as ConcavePolygonShape3D).get_faces().duplicate()
	(_r25_stair_collision.shape as ConcavePolygonShape3D).set_faces(_r25_path_faces)
	var buckets: Array[Dictionary] = [_r22_bucket(), _r22_bucket(), _r22_bucket(), _r22_bucket()]
	for i: int in range(0, _r25_path_faces.size(), 3):
		var centroid: Vector3 = (_r25_path_faces[i] + _r25_path_faces[i + 1] + _r25_path_faces[i + 2]) / 3.0
		var owner: int = clampi(3 - int(floor((9.5 - centroid.z) / 1.6)), 0, 3)
		_r25_emit(_r25_path_faces[i], _r25_path_faces[i + 1], _r25_path_faces[i + 2], buckets[owner], Color(0.95, 0.98, 0.89), true)
	for i: int in range(0, (_r25_flank["v"] as PackedVector3Array).size(), 3):
		var v: PackedVector3Array = _r25_flank["v"] as PackedVector3Array
		var owner: int = clampi(3 - int(floor((9.5 - ((v[i].z + v[i + 1].z + v[i + 2].z) / 3.0)) / 1.6)), 0, 3)
		_r25_emit(v[i], v[i + 1], v[i + 2], buckets[owner], Color(0.89, 0.94, 0.84), false)
	for i: int in range(4):
		var node: MeshInstance3D = bars[i]
		var inverse: Transform3D = node.transform.affine_inverse()
		var v: PackedVector3Array = buckets[i]["v"] as PackedVector3Array
		var n: PackedVector3Array = buckets[i]["n"] as PackedVector3Array
		for corner: int in range(v.size()):
			v[corner] = inverse * v[corner]
			n[corner] = (node.transform.basis.transposed() * n[corner]).normalized()
		buckets[i]["v"] = v
		buckets[i]["n"] = n
		var selected: ArrayMesh = ArrayMesh.new()
		_r25_append_surface(selected, buckets[i])
		var original: Mesh = node.mesh
		node.mesh = selected
		# Existing dark soil material makes original pale stone pieces distinct.
		var original_material: Material = node.material_override
		node.material_override = _materials["soil"] as Material
		_r25_meshes.append({"original_material": original_material, "selected_material": node.material_override, "kind": "stair_bar_" + str(i), "node": node, "original_mesh": original, "selected_mesh": selected, "original_transform": node.transform, "selected_transform": node.transform, "new_arrays_before_encoding": buckets[i]})
	for record: Dictionary in _r25_stair_nodes:
		if record["kind"] == "bar":
			continue
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		var old_p: Vector3 = node.position
		var hit: Dictionary = _r25_surface(old_p)
		if not hit.is_empty():
			var old_step: int = clampi(roundi((old_p.z - 3.51) / 0.60), 0, 3)
			var old_top: float = 0.60 - old_step * 0.15
			node.position.y += float(hit["height"]) - old_top
			record["selected_transform"] = node.transform
	_r22_stones = _rooted_ground_stone_cache()
	_r25_extra_stones = _r25_actual_entry_stones()
	_r25_stats["stair_support_triangles"] = _r25_path_faces.size() / 3
	_r25_stats["stair_support_delta"] = (_r25_path_faces.size() - _r25_old_stair_faces.size()) / 3
	if int(_r25_stats.get("west_collision_delta", 0)) + int(_r25_stats["stair_support_delta"]) > 4000:
		_r25_errors.append("Additional physical triangles exceed4000")

func _r25_actual_entry_stones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates: Array = _r25_path_nodes.duplicate()
	candidates.append_array(_r25_stair_nodes)
	for record: Dictionary in candidates:
		if record.get("kind", "") == "ribbon" or record.get("kind", "") == "bar":
			continue
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		var faces: PackedVector3Array = PackedVector3Array()
		var xf: Transform3D = global_transform.affine_inverse() * node.global_transform
		for p: Vector3 in node.mesh.get_faces():
			faces.append(xf * p)
		if faces.is_empty():
			continue
		var bounds: AABB = AABB(faces[0], Vector3.ZERO)
		for p: Vector3 in faces:
			bounds = bounds.expand(p)
		result.append({"site": "r24-entry-detail", "selected": false, "node": node, "bounds": bounds, "faces": faces, "origin": xf.origin})
	return result

func _r25_build_index() -> void:
	for i: int in range(0, _r25_faces.size(), 3):
		var a: Vector3 = _r25_faces[i]
		var b: Vector3 = _r25_faces[i + 1]
		var c: Vector3 = _r25_faces[i + 2]
		var x0: int = int(floor((minf(a.x, minf(b.x, c.x)) - _r25_rect.position.x - 0.00002) / 0.30))
		var x1: int = int(floor((maxf(a.x, maxf(b.x, c.x)) - _r25_rect.position.x + 0.00002) / 0.30))
		var z0: int = int(floor((minf(a.z, minf(b.z, c.z)) - 3.0 - 0.00002) / 0.30))
		var z1: int = int(floor((maxf(a.z, maxf(b.z, c.z)) - 3.0 + 0.00002) / 0.30))
		for x: int in range(x0, x1 + 1):
			for z: int in range(z0, z1 + 1):
				var key: Vector2i = Vector2i(x, z)
				var ids: PackedInt32Array = _r25_cells.get(key, PackedInt32Array()) as PackedInt32Array
				ids.append(i / 3)
				_r25_cells[key] = ids

func _r25_surface(p: Vector3) -> Dictionary:
	if not _r25_ready_top or p.x < _r25_rect.position.x or p.x > _r25_rect.end.x or p.z < 3.0 or p.z > 11.0:
		return {}
	var key: Vector2i = Vector2i(int(floor((p.x - _r25_rect.position.x) / 0.30)), int(floor((p.z - 3.0) / 0.30)))
	var best: Dictionary = {}
	for ordinal: int in _r25_cells.get(key, PackedInt32Array()) as PackedInt32Array:
		var i: int = ordinal * 3
		var hit: Dictionary = _foreground_bank_triangle_support(p, _r25_faces[i], _r25_faces[i + 1], _r25_faces[i + 2], -24, true)
		if not hit.is_empty() and (best.is_empty() or float(hit["height"]) > float(best["height"])):
			best = hit
	return best

func _foreground_bank_support(p: Vector3) -> Dictionary:
	if _r22_old_query == 0:
		var hit: Dictionary = _r25_surface(p)
		if not hit.is_empty():
			return hit
	return super._foreground_bank_support(p)

func _rooted_ground_support(p: Vector3) -> Dictionary:
	if _r22_old_query == 0:
		var hit: Dictionary = _r25_surface(p)
		if not hit.is_empty():
			return hit
	var inherited: Dictionary = super._rooted_ground_support(p)
	if not inherited.is_empty() or _r22_old_query != 0 or not _r25_ready_top:
		return inherited
	# An affected mesh may cross the patch while its root/sample remains outside.
	# Only the actual original physical west floor in this bounded .45m halo is
	# added to the rooted query; original bank and old-choice queries stay exact.
	if p.x >= _r25_rect.position.x - 0.45 and p.x <= _r25_rect.end.x + 0.45 and p.z >= 2.55 and p.z <= 11.45 and not _house_reserved(p):
		return _r25_base(p)
	return {}

func _r25_affects(mesh: ArrayMesh, xf: Transform3D) -> bool:
	if not _r25_ready_top:
		return false
	var local: PackedVector3Array = mesh.get_faces()
	for i: int in range(0, local.size(), 3):
		var poly: Array[Vector3] = [xf * local[i], xf * local[i + 1], xf * local[i + 2]]
		var x0: float = minf(poly[0].x, minf(poly[1].x, poly[2].x))
		var x1: float = maxf(poly[0].x, maxf(poly[1].x, poly[2].x))
		var z0: float = minf(poly[0].z, minf(poly[1].z, poly[2].z))
		var z1: float = maxf(poly[0].z, maxf(poly[1].z, poly[2].z))
		if x1 < _r25_rect.position.x or x0 > _r25_rect.end.x or z1 < 3.0 or z0 > 11.0:
			continue
		var seen: Dictionary = {}
		for x: int in range(int(floor((maxf(x0, _r25_rect.position.x) - _r25_rect.position.x) / 0.30)), int(floor((minf(x1, _r25_rect.end.x) - _r25_rect.position.x) / 0.30)) + 1):
			for z: int in range(int(floor((maxf(z0, 3.0) - 3.0) / 0.30)), int(floor((minf(z1, 11.0) - 3.0) / 0.30)) + 1):
				for ordinal: int in _r25_cells.get(Vector2i(x, z), PackedInt32Array()) as PackedInt32Array:
					if seen.has(ordinal):
						continue
					seen[ordinal] = true
					var j: int = ordinal * 3
					var clipped: Array[Vector3] = _r22_clip_triangle(poly, _r25_faces[j], _r25_faces[j + 1], _r25_faces[j + 2])
					for p: Vector3 in clipped:
						var old: Dictionary = _r25_base(p)
						var selected: Dictionary = _r25_surface(p)
						if not old.is_empty() and not selected.is_empty() and absf(float(selected["height"]) - float(old["height"])) > 0.000001:
							return true
	# Explicit vertical/degenerate projection observations accompany the full footprint.
	for sample: Vector3 in _rooted_group_samples(mesh):
		var p: Vector3 = xf * sample
		var hit: Dictionary = _r25_surface(p)
		if not hit.is_empty() and absf(float(hit["height"]) - float(_r25_base(p).get("height", hit["height"]))) > 0.000001:
			return true
	return false

func _r22_affects(mesh: ArrayMesh, xf: Transform3D) -> bool:
	return super._r22_affects(mesh, xf) or _r25_affects(mesh, xf)

func _r22_cluster_issue(mesh: ArrayMesh, xf: Transform3D, reach: float) -> String:
	var issue: String = super._r22_cluster_issue(mesh, xf, reach)
	if not issue.is_empty():
		return issue
	for sample: Vector3 in _rooted_group_samples(mesh):
		var p: Vector3 = xf * sample
		var hit: Dictionary = _rooted_ground_stone_top(p, _r25_extra_stones)
		if not hit.is_empty() and p.y < float(hit["height"]) - 0.002:
			return "r24_entry_stone_penetration"
	return ""

func _foreground_bank_shrub_lift(p: Vector3) -> float:
	var old: float = super._foreground_bank_shrub_lift(p)
	var hit: Dictionary = _r25_surface(p)
	if hit.is_empty():
		return old
	var selected: float = float(hit["height"]) - p.y
	_r22_group_delta = selected - _r22_old_group_lift
	if not _r22_shrubs.is_empty():
		var record: Dictionary = _r22_shrubs[_r22_shrubs.size() - 1]
		record["selected_body_position"] = record["original_body_position"] + Vector3.UP * _r22_group_delta
		record["group_delta_y"] = _r22_group_delta
		_r25_shrubs.append(record)
	return selected

func _create_foliage() -> void:
	_r25_direct_foliage = true
	super._create_foliage()
	_r25_direct_foliage = false

func _add_foliage(id: String, mesh: ArrayMesh, origin: Vector3, turn: Vector3, scale_value: Vector3) -> void:
	var old: Transform3D = Transform3D(Basis.from_euler(turn).scaled(scale_value), origin)
	# Original untargeted leaf/flower callers only. Shared R19 choice/context flows
	# continue through the unchanged parent; no mesh, family or yaw substitutions.
	if _r22_cluster and _review19_old_label(mesh).is_empty() and (mesh == _grass_mesh or mesh == _flower_mesh or mesh == _broadleaf_mesh) and _r25_affects(mesh, old):
		if _r25_emit_safe_rigid_pose(id, mesh, origin, turn, scale_value):
			return
	var p: Vector3 = origin
	var chosen_turn: Vector3 = turn
	var direct: bool = _r25_direct_foliage and not _r22_cluster and not _r22_shrub and mesh == _flower_mesh and origin.z >= 3.3 and origin.z <= 6.4 and absf(origin.x) >= 1.45 and absf(origin.x) <= 3.55
	if direct and _r25_affects(mesh, old):
		var hit: Dictionary = _r25_surface(p)
		if hit.is_empty():
			_r25_errors.append("Direct entry flower missing actual root support")
		else:
			p.y = float(hit["height"])
			var n: Vector3 = Basis(Vector3.UP, -turn.y) * (hit["normal"] as Vector3)
			chosen_turn = Vector3(atan2(n.z, n.y), turn.y, asin(clampf(-n.x, -1.0, 1.0)))
			var issue: String = _r22_cluster_issue(mesh, Transform3D(Basis.from_euler(chosen_turn).scaled(scale_value), p), 0.17)
			if not issue.is_empty():
				chosen_turn = turn
				issue = _r22_cluster_issue(mesh, Transform3D(Basis.from_euler(chosen_turn).scaled(scale_value), p), 0.17)
			if not issue.is_empty():
				_r25_errors.append("Rerooted direct entry flower unsafe: " + issue)
	var prior: int = _r22_placements.size()
	super._add_foliage(id, mesh, p, chosen_turn, scale_value)
	if _r22_placements.size() > prior:
		var record: Dictionary = _r22_placements[_r22_placements.size() - 1]
		if _r25_affects(mesh, record["original_transform"] as Transform3D):
			_r25_placements.append(record)
	elif direct and old != Transform3D(Basis.from_euler(chosen_turn).scaled(scale_value), p):
		_r25_placements.append({"category": "direct_entry_flower", "mesh": mesh, "id": id, "original_transform": old, "selected_transform": Transform3D(Basis.from_euler(chosen_turn).scaled(scale_value), p), "caller_reach": 0.17, "changed": true})

func _r25_measure() -> void:
	var area: float = 0.0
	var raised: float = 0.0
	var max_slope: float = 0.0
	var max_y: float = -INF
	var witness: Dictionary = {}
	for i: int in range(0, _r25_faces.size(), 3):
		var a: Vector3 = _r25_faces[i]
		var b: Vector3 = _r25_faces[i + 1]
		var c: Vector3 = _r25_faces[i + 2]
		var normal_value: Vector3 = (c - a).cross(b - a).normalized()
		var slope: float = rad_to_deg(acos(clampf(normal_value.y, -1.0, 1.0)))
		var projected: float = absf(Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z))) * 0.5
		area += projected
		var middle: Vector3 = (a + b + c) / 3.0
		var base: Dictionary = _r25_base(middle)
		if middle.y > float(base.get("height", middle.y)) + 0.03:
			raised += projected
		max_y = maxf(max_y, maxf(a.y, maxf(b.y, c.y)))
		if slope > max_slope:
			max_slope = slope
			witness = {"ordinal": i / 3, "a": a, "b": b, "c": c, "slope_deg": slope}
	_r25_stats = {"native_rect": [_r25_rect.position.x, _r25_rect.end.x, 3.0, 11.0], "canonical_triangles": _r25_faces.size() / 3, "soil_triangles": _r25_soil_faces.size() / 3, "path_triangles": _r25_path_faces.size() / 3, "projected_area_m2": area, "raised_area_over30mm_m2": raised, "max_top_y_m": max_y, "max_top_triangle_slope_deg": max_slope, "max_slope_face": witness, "threshold_join": {"z_start": 3.0, "y": 0.60, "half_width": 1.08, "original_ramp_z_endpoint": 3.10}, "eight_rises_m": [0.070, 0.085, 0.065, 0.080, 0.070, 0.085, 0.065, 0.080], "flank_faces_collision": false}
	if absf(area - _r25_rect.size.x * 8.0) > 0.001:
		_r25_errors.append("Canonical top coverage area differs from original native-grid rectangle")
	if max_slope > 25.0:
		_r25_errors.append("Actual top slope exceeds proposed25deg")
	if raised < 12.0:
		_r25_errors.append("Protected exclusions erased meaningful connected approach mass")
	if _r25_faces.size() / 3 > 4000:
		_r25_errors.append("Canonical triangle budget exceeds4000")

func _rooted_groups_fingerprint() -> String:
	if not _r25_ready_top or _r25_stair_collision == null:
		return ""
	var paths: Array = []
	for record: Dictionary in _r25_path_nodes:
		var node: MeshInstance3D = record["node"] as MeshInstance3D
		paths.append([record["route"], record["kind"], node.transform, node.mesh.surface_get_arrays(0)])
	var stones: Array = []
	for stone: Dictionary in _r25_extra_stones:
		stones.append([stone["site"], stone["bounds"], stone["faces"], stone["origin"]])
	return _r22_sha(var_to_bytes([_R25_REVISION, super._rooted_groups_fingerprint(), _r25_faces, _r25_soil_faces, _r25_path_faces, paths, stones]))

func get_review25_bake_document() -> Dictionary:
	var doc: Dictionary = _rooted_groups_bake_document()
	doc["schema"] = _R25_SCHEMA
	doc["authoring_revision"] = _R25_REVISION
	return doc

func _r25_decode(doc: Dictionary) -> Dictionary:
	if doc.get("schema", "") != _R25_SCHEMA or doc.get("authoring_revision", "") != _R25_REVISION or doc.get("codec_revision", "") != _ROOTED_GROUPS_CODEC_REVISION:
		return {"ok": false, "error": "FreshR25 schema/revision/codec required"}
	var adapter: Dictionary = doc.duplicate()
	adapter["schema"] = "rooted-foreground-groups-v2"
	adapter["authoring_revision"] = _ROOTED_GROUPS_AUTHORING_REVISION
	return _rooted_groups_decode_bake(adapter)

func _create_rooted_ground_groups() -> void:
	# Original runtime/bake01/02/03 are never accepted as a new approach bake.
	if not _r25_errors.is_empty() or _r25_stair_collision == null:
		_r25_refuse("Approach construction failed before author/replay")
		return
	if bool(get_meta("review25_author_mode", false)):
		_generate_rooted_ground_groups()
		_r25_bake = {"mode": "authored", "reason": "Explicit standaloneR25 author mode", "fingerprint": _rooted_groups_fingerprint()}
		_r22_bake = _r25_bake.duplicate()
		_rooted_foreground_group_load_status = _r25_bake.duplicate()
		return
	var path: String = String(get_meta("review25_bake_lock_path", ""))
	var pin: String = String(get_meta("review25_bake_lock_sha256", ""))
	var error: String = "Immutable fresh R25 bake lock/pin missing"
	var decoded: Dictionary = {}
	if path.is_absolute_path() and path == path.simplify_path() and path.begins_with(_R25_BAKE_DIR) and pin.length() == 64:
		var bytes: PackedByteArray = _r22_read(path, 16384)
		if not bytes.is_empty() and _r22_sha(bytes) == pin:
			var json: JSON = JSON.new()
			if json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
				var lock: Dictionary = json.data as Dictionary
				var payload_path: String = String(lock.get("payload_path", ""))
				var payload_sha: String = String(lock.get("payload_sha256", ""))
				if lock.get("schema", "") == "mush-r25-owned-bake-lock/1" and lock.get("authoring_revision", "") == _R25_REVISION and lock.get("candidate_sha256", "") == FileAccess.get_sha256(_R25_PATH) and lock.get("fingerprint", "") == _rooted_groups_fingerprint() and lock.get("attempt_count", 0) == 474 and lock.get("codec_revision", "") == _ROOTED_GROUPS_CODEC_REVISION and payload_path.is_absolute_path() and payload_path == payload_path.simplify_path() and payload_path.begins_with(_R25_BAKE_DIR) and payload_sha.length() == 64:
					var payload: PackedByteArray = _r22_read(payload_path, _ROOTED_GROUPS_BAKE_LIMIT)
					if not payload.is_empty() and payload.size() == int(lock.get("payload_bytes", -1)) and _r22_sha(payload) == payload_sha:
						var payload_json: JSON = JSON.new()
						if payload_json.parse(payload.get_string_from_utf8()) == OK and payload_json.data is Dictionary:
							decoded = _r25_decode(payload_json.data as Dictionary)
							error = String(decoded.get("error", "Decode rejected"))
						else:
							error = "FreshR25 payload JSON invalid"
					else:
						error = "FreshR25 payload size/SHA invalid"
				else:
						error = "FreshR25 lock candidate/revision/fingerprint/path invalid"
			else:
				error = "FreshR25 lock JSON invalid"
		else:
			error = "FreshR25 lock size/SHA invalid"
	if not bool(decoded.get("ok", false)):
		_r25_refuse(error)
		return
	var records: Array[Dictionary] = decoded["records"] as Array[Dictionary]
	for record: Dictionary in records:
		if bool(record["accepted"]):
			_add_foliage(record["id"] as String, _foreground_understory_meshes[record["label"]] as ArrayMesh, record["origin"] as Vector3, record["turn"] as Vector3, record["scale"] as Vector3)
	_rooted_foreground_group_records = records
	_rooted_foreground_group_stats = decoded["stats"] as Dictionary
	_r25_bake = {"mode": "baked", "reason": "Fresh all474 R25 SHA/fingerprint rows validated before replay", "fingerprint": decoded["fingerprint"], "lock_path": path, "lock_sha256": pin}
	_r22_bake = _r25_bake.duplicate()
	_rooted_foreground_group_load_status = _r25_bake.duplicate()

func _r25_refuse(reason: String) -> void:
	_r25_bake = {"mode": "refused", "reason": reason, "fingerprint": _rooted_groups_fingerprint()}
	_r22_bake = _r25_bake.duplicate()
	_rooted_foreground_group_load_status = _r25_bake.duplicate()
	_r25_errors.append("Normal R25 bake REFUSED before append: " + reason)

func get_review25_approach_report() -> Dictionary:
	var changed: Dictionary = {"clustered": 0, "shrub_leaf": 0, "direct_entry_flower": 0}
	for record: Dictionary in _r25_placements:
		if bool(record.get("changed", false)):
			var category: String = String(record["category"])
			changed[category] = int(changed.get(category, 0)) + 1
	var stats: Dictionary = _r25_stats.duplicate(true)
	stats["baseline_path_proof"] = _r25_path_proof.duplicate(true)
	stats["left_bank_join"] = {"full_z": [7.4, 9.5], "feather_z": [7.0, 9.9], "level_collar_m": 0.08, "outward_blend_m": 0.75, "soil_relief_scalar_elsewhere": 0.845, "native_row_edges": _r25_join_proof.duplicate(true), "limits": "Only full interval has exact shared row Y. Longitudinal feather residual lateral gaps and faceted interpolated seam/contact need actual native/contact inspection."}
	stats["rerooted"] = changed
	stats["shrub_groups"] = _r25_shrubs.size()
	stats["bake"] = _r25_bake.duplicate(true)
	stats["rooted_stats"] = _rooted_foreground_group_stats.duplicate(true)
	stats["rigid_pose_corrections"] = _r25_rigid_poses.size()
	var paving_count: int = 0
	var captured_paving_count: int = 0
	var paving_routes: Dictionary = {"main": 0, "branch": 0}
	var paving_details: Array[Dictionary] = []
	var paving_minimum: float = INF
	var paving_maximum: float = -INF
	for record: Dictionary in _r25_path_nodes:
		if record["kind"] == "paving":
			captured_paving_count += 1
			paving_routes[String(record["route"])] = int(paving_routes[String(record["route"])]) + 1
		if record.has("sampled_upper_support_gap_m"):
			paving_count += 1
			var gap: Vector2 = record["sampled_upper_support_gap_m"] as Vector2
			paving_minimum = minf(paving_minimum, gap.x)
			paving_maximum = maxf(paving_maximum, gap.y)
			var old_xf: Transform3D = record["original_transform"] as Transform3D
			var new_xf: Transform3D = record["selected_transform"] as Transform3D
			var initial: Vector2 = record["initial_upper_support_gap_m"] as Vector2
			var interval: Vector2 = record["feasible_signed_vertical_interval_m"] as Vector2
			var turn: Vector3 = record["selected_turn"] as Vector3
			paving_details.append({"route": record["route"], "constructor_ordinal": record["constructor_ordinal"], "original_origin": [old_xf.origin.x, old_xf.origin.y, old_xf.origin.z], "selected_origin": [new_xf.origin.x, new_xf.origin.y, new_xf.origin.z], "selected_turn_rad": [turn.x, turn.y, turn.z], "initial_upper_gap_m": [initial.x, initial.y], "signed_vertical_interval_m": [interval.x, interval.y], "vertical_fit_m": record["vertical_fit_m"], "fit_interval_nonempty": record["sampled_vertical_fit_feasible"], "actual_upper_gap_m": [gap.x, gap.y], "upper_sample_count": record["upper_sample_count"], "exposure_guard_passed": record["exposure_guard_passed"], "fit_basis_matches_actual": record["fit_basis_matches_actual"], "same_original_scale": record["same_original_scale"], "same_original_resource": record["same_resource"], "same_origin_xz": record["same_origin_xz"], "same_yaw": record["same_yaw"], "noncolliding_decoration": true})
	stats["visible_original_paving"] = {"targeted_details": paving_details, "captured_total": captured_paving_count, "captured_routes": paving_routes, "posed": paving_count, "sampled_upper_support_gap_m": [paving_minimum, paving_maximum] if paving_count > 0 else [], "physical_top_unchanged": true, "paving_meshes_original": true, "paving_collision": false, "underpath_material": "soil"}
	return {"inherited": _r25_inherited_summary(), "schema": "mush-r25-entrance-approach/1", "status": _r25_status, "errors": _r25_errors.duplicate(), "stats": stats, "scope": "Bounded left soil-to-path join on the frozen World06 entrance. Original591 path faces are compared as native bytes against a never-added frozen baseline instance; only left soil rows gain samples/heights. Full Z7.4..9.5 join, Z7.0..9.9 feather, .08m collar and .75m outward blend are proposals. One west physical top changes relative06; stair grade, house/garden anchors, old encoded outside prefix, original paving resources/XZ/yaw and all guards remain. Fresh474 R25 bake required. Residual feather gaps, contact and reference fidelity are unapproved; decorative paving has no collision parity."}

func get_review25_approach_evidence() -> Dictionary:
	return {"status": _r25_status, "errors": _r25_errors, "canonical_faces": _r25_faces, "baseline_path_faces": _r25_baseline_path_faces, "baseline_path_proof": _r25_path_proof, "left_join_rows": _r25_join_proof, "soil_faces": _r25_soil_faces, "path_faces": _r25_path_faces, "native_rect": _r25_rect, "west_collision": _r22_collision, "stair_collision": _r25_stair_collision, "old_west_faces": _r25_old_west_faces, "old_stair_faces": _r25_old_stair_faces, "mesh_records": _r25_meshes, "path_nodes": _r25_path_nodes, "stair_nodes": _r25_stair_nodes, "placements": _r25_placements, "rigid_pose_corrections": _r25_rigid_poses, "shrub_groups": _r25_shrubs, "seam_pairs": _r25_seams, "extra_entry_stones": _r25_extra_stones, "point_cells": _r25_cells, "flank_arrays": _r25_flank, "bake": _r25_bake, "rooted_records": _rooted_foreground_group_records, "stats": _r25_stats}

func _r25_pose_less(a: Vector2, b: Vector2) -> bool:
	if a.length_squared() != b.length_squared():
		return a.length_squared() < b.length_squared()
	return a.x < b.x if a.x != b.x else a.y < b.y

func _r25_pose_test(mesh: ArrayMesh, p: Vector3, turn: Vector3, scale_value: Vector3, reach: float) -> Dictionary:
	var xf: Transform3D = Transform3D(Basis.from_euler(turn).scaled(scale_value), p)
	if not _r25_pose_samples.has(mesh):
		_r25_pose_samples[mesh] = _rooted_group_samples(mesh)
	var samples: PackedVector3Array = _r25_pose_samples[mesh] as PackedVector3Array
	if xf.basis.y.normalized().dot(Vector3.UP) < cos(deg_to_rad(35.0)):
		return {"guard_issue": "bounded_rigid_up_tilt", "issue": "bounded_rigid_up_tilt", "min_soil_gap": -INF, "turn": turn, "transform": xf}
	# Reject impossible extents before the more expensive exact original guard.
	for sample: Vector3 in samples:
		var local_world: Vector3 = xf.basis * sample
		if Vector2(local_world.x, local_world.z).length() > reach + 0.000001:
			return {"guard_issue": "finite_or_caller_reach", "issue": "finite_or_caller_reach", "min_soil_gap": -INF, "turn": turn, "transform": xf}
	var guard_issue: String = _r22_cluster_issue(mesh, xf, reach)
	var minimum: float = INF
	if guard_issue.is_empty():
		for sample: Vector3 in samples:
			var q: Vector3 = xf * sample
			var hit: Dictionary = _rooted_ground_support(q)
			if hit.is_empty():
				guard_issue = "missing_actual_sample_support"
				break
			minimum = minf(minimum, q.y - float(hit["height"]))
	# This is a stricter selection margin, not a relaxation of the existing2mm guard.
	var issue: String = guard_issue
	if issue.is_empty() and minimum < -0.0018:
		issue = "rigid_pose_native_precision_margin"
	return {"guard_issue": guard_issue, "issue": issue, "min_soil_gap": minimum, "turn": turn, "transform": xf}

func _r25_emit_safe_rigid_pose(id: String, mesh: ArrayMesh, origin: Vector3, turn: Vector3, scale_value: Vector3) -> bool:
	var depth: int = _r22_old_query
	_r22_old_query = 0
	var support: Dictionary = _rooted_ground_support(origin)
	if support.is_empty():
		_r22_old_query = depth
		return false
	var p: Vector3 = origin
	p.y = float(support["height"])
	var local_n: Vector3 = Basis(Vector3.UP, -turn.y) * (support["normal"] as Vector3)
	var aligned_turn: Vector3 = Vector3(atan2(local_n.z, local_n.y), turn.y, asin(clampf(-local_n.x, -1.0, 1.0)))
	var aligned: Dictionary = _r25_pose_test(mesh, p, aligned_turn, scale_value, _r22_reach)
	var upright: Dictionary = _r25_pose_test(mesh, p, turn, scale_value, _r22_reach)
	# If the original parent would choose the same safely guarded pose, leave all
	# original append/context bookkeeping to it.
	if String(aligned["issue"]).is_empty() or (not String(aligned["guard_issue"]).is_empty() and String(upright["issue"]).is_empty()):
		_r22_old_query = depth
		return false
	var candidates: Array[Vector2] = []
	for pi: int in range(-28, 29):
		for ri: int in range(-28, 29):
			candidates.append(Vector2(float(pi), float(ri)))
	candidates.sort_custom(_r25_pose_less)
	var selected: Dictionary = {}
	var attempted: int = 0
	for offset: Vector2 in candidates:
		var candidate_turn: Vector3 = Vector3(aligned_turn.x + deg_to_rad(offset.x * 0.5), turn.y, aligned_turn.z + deg_to_rad(offset.y * 0.5))
		var candidate: Dictionary = _r25_pose_test(mesh, p, candidate_turn, scale_value, _r22_reach)
		attempted += 1
		if String(candidate["issue"]).is_empty():
			selected = candidate
			break
	if selected.is_empty():
		_r22_old_query = depth
		return false
	var old_xf: Transform3D = Transform3D(Basis.from_euler(turn).scaled(scale_value), origin)
	_r22_old_query = 1
	var old_issue: String = _r22_cluster_issue(mesh, old_xf, _r22_reach)
	_r22_old_query = 0
	var chosen_turn: Vector3 = selected["turn"] as Vector3
	var chosen_xf: Transform3D = selected["transform"] as Transform3D
	var sequence: int = _r22_sequence
	var key: String = "%s_%s_%d_%d" % [id, mesh.get_instance_id(), int(floor(p.x / 8.0)), int(floor(p.z / 8.0))]
	var before: int = 0
	if _foliage_chunks.has(key):
		before = ((_foliage_chunks[key] as Dictionary)["transforms"] as Array).size()
	# Exactly one original append, with the selected resource and new safe rigid
	# transform. Suppress only the parent's duplicate reroot for this append.
	var cluster: bool = _r22_cluster
	_r22_cluster = false
	super._add_foliage(id, mesh, p, chosen_turn, scale_value)
	_r22_cluster = cluster
	var appended: Array = (_foliage_chunks[key] as Dictionary)["transforms"] as Array
	var actual_xf: Transform3D = appended[appended.size() - 1] as Transform3D
	var final_issue: String = _r22_cluster_issue(mesh, actual_xf, _r22_reach)
	if appended.size() != before + 1 or actual_xf != chosen_xf or not final_issue.is_empty():
		_r22_errors.append("Actually appended R25 rigid pose invalid: " + final_issue)
	var record: Dictionary = _r22_choice.duplicate()
	record.merge({"sequence": sequence, "category": "clustered", "mesh": mesh, "id": id, "original_transform": old_xf, "selected_transform": actual_xf, "caller_reach": _r22_reach, "affected": true, "changed": old_xf != actual_xf, "old_issue": old_issue, "selected_issue": final_issue, "initial_aligned_issue": aligned["guard_issue"], "initial_upright_issue": upright["guard_issue"], "selected_min_soil_gap": selected["min_soil_gap"], "method": "same-root-yaw-resource bounded half-degree rigid search"}, true)
	_r22_placements.append(record)
	_r25_placements.append(record)
	_r25_rigid_poses.append({"sequence": sequence, "mesh": mesh, "id": id, "old_transform": old_xf, "selected_transform": actual_xf, "original_turn": turn, "selected_turn": chosen_turn, "scale": scale_value, "caller_reach": _r22_reach, "root_support": support, "initial_aligned_issue": aligned["guard_issue"], "initial_upright_issue": upright["guard_issue"], "native_selection_margin_issue": [aligned["issue"], upright["issue"]], "selected_min_soil_gap": selected["min_soil_gap"], "final_issue": final_issue, "attempted_angles": attempted, "same_resource": true, "same_root_xz": p.x == origin.x and p.z == origin.z, "same_original_yaw": chosen_turn.y == turn.y, "exact_root_height": p.y == float(Vector3(0, float(support["height"]), 0).y), "actually_appended_transform_exact": actual_xf == chosen_xf})
	_r22_old_query = depth
	return true

func _r25_inherited_summary() -> Dictionary:
	var failed: int = 0
	for record: Dictionary in _r22_placements:
		if not String(record.get("selected_issue", "")).is_empty():
			failed += 1
	return {"r19": {"status": _review19_status, "errors": _review19_errors.duplicate(), "attempted": _review19_counters.get("attempted", 0), "substituted": _review19_counters.get("substituted", 0), "fallback": _review19_counters.get("fallback", 0)}, "r20": {"status": _review20_status, "errors": _review20_errors.duplicate(), "attempted": _review20_attempted, "accepted": _review20_accepted}, "r21": {"status": _review21_status, "errors": _review21_errors.duplicate(), "new": _review21_new_count, "fallback": _review21_fallback_count}, "r22": {"status": _r22_status, "errors": _r22_errors.duplicate(), "failed_selected_placements": failed}}
