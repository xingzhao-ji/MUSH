extends "res://lineage/scenery-revision-21/proposals/connected-cushions-01/cushion-world.gd"

# All numerical dimensions are proposed. Root owns actual author/replay/mesh/render tests.
const _R22_PATH: String = "res://lineage/scenery-revision-22/proposals/soil-shoulder-03/terrain-world.gd"
const _R22_BAKE_DIR: String = "res://lineage/scenery-revision-22/owned-bake03/"
const _R22_RECT: Rect2 = Rect2(1.0, 11.2, 6.8, 5.0)
const _R22_REVISION: String = "soil-shoulder-22-v3"
const _R22_SCHEMA: String = "rooted-foreground-groups-r22-v3"
const _R22_RELIEF_SCALE: float = 0.65
# Exact native02 original west boundary; not an epsilon or arbitrary point snap.
const _R22_INHERITED_WEST_EDGE_X: float = 7.799999713897705
const _R22_CELL_MARGIN: float = 0.00002
var _r22_ground: MeshInstance3D
var _r22_collision: CollisionShape3D
var _r22_soil: MeshInstance3D
var _r22_moss: MeshInstance3D
var _r22_old_collision: PackedVector3Array = PackedVector3Array()
var _r22_faces: PackedVector3Array = PackedVector3Array()
var _r22_base_faces: PackedVector3Array = PackedVector3Array()
var _r22_corner_relief: PackedFloat64Array = PackedFloat64Array()
var _r22_base_bank_flags: PackedByteArray = PackedByteArray()
var _r22_cells: Dictionary = {}
var _r22_rows: Array[PackedVector3Array] = []
var _r22_face_rows: Array[PackedInt32Array] = []
var _r22_changed_faces: PackedByteArray = PackedByteArray()
var _r22_stones: Array[Dictionary] = []
var _r22_meshes: Array[Dictionary] = []
var _r22_placements: Array[Dictionary] = []
var _r22_shrubs: Array[Dictionary] = []
var _r22_errors: Array[String] = []
var _r22_metrics: Dictionary = {}
var _r22_bake: Dictionary = {"mode": "not_started"}
var _r22_status: String = "not_started"
var _r22_old_query: int = 0
var _r22_cluster: bool = false
var _r22_shrub: bool = false
var _r22_reach: float = 0.0
var _r22_group_delta: float = 0.0
var _r22_old_group_lift: float = 0.0
var _r22_sequence: int = 0
var _r22_choice: Dictionary = {}
var _r22_field_cache: Dictionary = {}

func _ready() -> void:
	super._ready()
	if _review19_status != "complete" or _review20_status != "complete" or _review21_status != "complete":
		_r22_errors.append("Inherited foliage assembly incomplete")
	if not ["authored", "baked"].has(String(_r22_bake.get("mode", ""))):
		_r22_errors.append("Fresh R22 author/replay mandatory")
	_r22_status = "complete" if _r22_errors.is_empty() else "integrity_failed"

func _ground_piece(x0: float, x1: float, z0: float, z1: float, parent: Node3D) -> CollisionShape3D:
	var collision: CollisionShape3D = super._ground_piece(x0, x1, z0, z1, parent)
	if x0 == -24.0 and x1 == 7.8:
		_r22_collision = collision
		for child: Node in parent.get_children():
			if child is MeshInstance3D and String(child.name) == "ContinuousGround":
				_r22_ground = child as MeshInstance3D
	return collision

func _create_foreground_bank_transitions(parent: Node3D, west: CollisionShape3D, east: CollisionShape3D) -> void:
	super._create_foreground_bank_transitions(parent, west, east)
	_r22_status = "building"
	_r22_soil = parent.get_node_or_null("CoherentForegroundSoilBanksProposal") as MeshInstance3D
	_r22_moss = parent.get_node_or_null("BrokenBankMossProposal") as MeshInstance3D
	if _r22_ground == null or _r22_soil == null or _r22_moss == null or west != _r22_collision or not west.shape is ConcavePolygonShape3D:
		_r22_errors.append("Original west floor/bank/collider relation missing")
		return
	_r22_old_collision = (west.shape as ConcavePolygonShape3D).get_faces().duplicate()
	_r22_stones = _rooted_ground_stone_cache()
	var top: Dictionary = _r22_bucket()
	# The old physical grid and actual old bank top are retained as two base partitions.
	_r22_build_top(_foreground_bank_original_faces[0], _r22_rect(1.0, 6.2, 11.2, 16.2), 4, top)
	_r22_build_top(_foreground_bank_original_faces[0], _r22_rect(6.2, 7.8, 11.2, 16.2), 4, top)
	_r22_faces = (top["v"] as PackedVector3Array).duplicate()
	_r22_index()
	_r22_measure()
	var floor_mesh: ArrayMesh = _r22_replace(_r22_ground.mesh as ArrayMesh, "west_ground", false, false, top)
	var soil_mesh: ArrayMesh = _r22_replace(_r22_soil.mesh as ArrayMesh, "soil_bank", true, false, _r22_bucket())
	var moss_mesh: ArrayMesh = _r22_replace(_r22_moss.mesh as ArrayMesh, "bank_moss", false, true, _r22_bucket())
	if floor_mesh == null or soil_mesh == null or moss_mesh == null:
		_r22_errors.append("Encoded surface replacement failed")
		return
	_r22_ground.mesh = floor_mesh
	_r22_soil.mesh = soil_mesh
	_r22_moss.mesh = moss_mesh
	var faces: PackedVector3Array = _r22_outside(_r22_old_collision)
	faces.append_array(_r22_faces)
	(west.shape as ConcavePolygonShape3D).set_faces(faces)
	_r22_metrics["old_collision_triangles"] = _r22_old_collision.size() / 3
	_r22_metrics["new_collision_triangles"] = faces.size() / 3
	_r22_metrics["collision_triangle_delta"] = (faces.size() - _r22_old_collision.size()) / 3
	if int(_r22_metrics["collision_triangle_delta"]) > 4000:
		_r22_errors.append("Additional collision triangles exceed4000")

func _r22_bucket() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray()}

func _r22_rect(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	var rect: Rect2 = Rect2(Vector2(x0, z0), Vector2.ZERO)
	rect.end = Vector2(x1, z1)
	return rect

func _r22_inside(p: Vector3) -> bool:
	return p.x >= 0.999999 and p.x <= 7.800001 and p.z >= 11.199999 and p.z <= 16.200001

func _r22_clip(poly: Array[Vector3], axis: int, bound: float, greater: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if poly.is_empty():
		return out
	var last: Vector3 = poly[poly.size() - 1]
	var last_in: bool = last[axis] >= bound if greater else last[axis] <= bound
	for p: Vector3 in poly:
		var inside: bool = p[axis] >= bound if greater else p[axis] <= bound
		if inside != last_in and absf(p[axis] - last[axis]) > 0.0000000001:
			var cut: Vector3 = last.lerp(p, (bound - last[axis]) / (p[axis] - last[axis]))
			cut[axis] = bound
			out.append(cut)
		if inside:
			out.append(p)
		last = p
		last_in = inside
	return out

func _r22_partition(a: Vector3, b: Vector3, c: Vector3, rect: Rect2 = _R22_RECT) -> Dictionary:
	var inner: Array[Vector3] = [a, b, c]
	var outside: Array[Array] = []
	var axes: PackedInt32Array = PackedInt32Array([0, 0, 2, 2])
	var limits: PackedFloat64Array = PackedFloat64Array([rect.position.x, rect.end.x, rect.position.y, rect.end.y])
	for i: int in range(4):
		var greater: bool = i % 2 == 0
		var outer: Array[Vector3] = _r22_clip(inner, axes[i], limits[i], not greater)
		if outer.size() >= 3:
			outside.append(outer)
		inner = _r22_clip(inner, axes[i], limits[i], greater)
	return {"inside": inner, "outside": outside}

func _r22_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	return (c - a).cross(b - a).length() * 0.5

func _r22_polygon_area(poly: Array) -> float:
	var area: float = 0.0
	for i: int in range(1, poly.size() - 1):
		area += _r22_area(poly[0], poly[i], poly[i + 1])
	return area

func _r22_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000000000001), 0.0, 1.0))

func _r22_stone_distance(p: Vector3) -> float:
	var nearest: float = 1000.0
	var q: Vector2 = Vector2(p.x, p.z)
	for stone: Dictionary in _r22_stones:
		var bounds: AABB = stone["bounds"] as AABB
		if p.x < bounds.position.x - 0.90 or p.x > bounds.end.x + 0.90 or p.z < bounds.position.z - 0.90 or p.z > bounds.end.z + 0.90:
			continue
		var faces: PackedVector3Array = stone["faces"] as PackedVector3Array
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i + 1]
			var c: Vector3 = faces[i + 2]
			if not _foreground_bank_triangle_support(p, a, b, c, 0, false).is_empty():
				return 0.0
			nearest = minf(nearest, _r22_segment_distance(q, Vector2(a.x, a.z), Vector2(b.x, b.z)))
			nearest = minf(nearest, _r22_segment_distance(q, Vector2(b.x, b.z), Vector2(c.x, c.z)))
			nearest = minf(nearest, _r22_segment_distance(q, Vector2(c.x, c.z), Vector2(a.x, a.z)))
	return nearest

func _r22_relief(p: Vector3) -> float:
	var key: Vector2 = Vector2(p.x, p.z)
	if _r22_field_cache.has(key):
		return float(_r22_field_cache[key])
	var edge: float = minf(minf(p.x - 1.0, 7.8 - p.x), minf(p.z - 11.2, 16.2 - p.z))
	var height: float = 0.0
	if edge > 0.0 and not _near_route(p, 1.46) and not _house_reserved(p):
		var q1: float = maxf(0.0, 1.0 - pow((p.x - 2.15) / 2.55, 2.0) - pow((p.z - 13.50) / 2.25, 2.0))
		var q2: float = maxf(0.0, 1.0 - pow((p.x - 5.65) / 2.60, 2.0) - pow((p.z - 14.05) / 2.35, 2.0))
		var saddle: float = maxf(0.0, 1.0 - pow((p.x - 4.05) / 3.05, 2.0) - pow((p.z - 13.65) / 2.45, 2.0))
		var route_mask: float = 1.0
		if _near_route(p, 1.86):
			var low: float = 1.46
			var high: float = 1.86
			for _step: int in range(12):
				var mid: float = (low + high) * 0.5
				if _near_route(p, mid):
					high = mid
				else:
					low = mid
			route_mask = smoothstep(1.46, 1.86, (low + high) * 0.5)
		height = _R22_RELIEF_SCALE * (0.28 * q1 * q1 + 0.30 * q2 * q2 + 0.12 * saddle * saddle) * smoothstep(0.0, 1.0, edge) * route_mask * smoothstep(0.36, 0.90, _r22_stone_distance(p))
	_r22_field_cache[key] = height
	return height

func _r22_point_less(a: Vector3, b: Vector3) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z

func _r22_subdivision_point(a: Vector3, b: Vector3, c: Vector3, i: int, j: int, subdivisions: int) -> Vector3:
	var points: PackedVector3Array = PackedVector3Array([a, b, c])
	var weights: PackedInt32Array = PackedInt32Array([subdivisions - i - j, i, j])
	# Keep each integer weight attached to its source point while ordering additions.
	for first: int in range(2):
		for second: int in range(first + 1, 3):
			if _r22_point_less(points[second], points[first]):
				var point_swap: Vector3 = points[first]
				var weight_swap: int = weights[first]
				points[first] = points[second]
				weights[first] = weights[second]
				points[second] = point_swap
				weights[second] = weight_swap
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	for ordinal: int in range(3):
		if weights[ordinal] == 0:
			continue
		var weight: float = float(weights[ordinal])
		x += float(points[ordinal].x) * weight
		y += float(points[ordinal].y) * weight
		z += float(points[ordinal].z) * weight
	# Scalar GDScript float arithmetic is double; only this constructor stores float32.
	var point: Vector3 = Vector3(x / float(subdivisions), y / float(subdivisions), z / float(subdivisions))
	# Only generated points exactly on the pinned inherited west-grid edge reconcile
	# to the declared rectangle end; all other quarter points keep their value.
	if point.x == _R22_INHERITED_WEST_EDGE_X:
		point.x = _R22_RECT.end.x
	return point

func _r22_top_cut(a: Vector3, b: Vector3, axis: int, bound: float) -> Vector3:
	var first: Vector3 = b if _r22_point_less(b, a) else a
	var last: Vector3 = a if _r22_point_less(b, a) else b
	var ratio: float = (bound - float(first[axis])) / (float(last[axis]) - float(first[axis]))
	# Reversing a shared edge cannot change the evaluation order or its rounded cut.
	var x: float = float(first.x) + (float(last.x) - float(first.x)) * ratio
	var y: float = float(first.y) + (float(last.y) - float(first.y)) * ratio
	var z: float = float(first.z) + (float(last.z) - float(first.z)) * ratio
	var cut: Vector3 = Vector3(x, y, z)
	cut[axis] = bound
	return cut

func _r22_top_clip(poly: Array[Vector3], axis: int, bound: float, greater: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if poly.is_empty():
		return out
	var last: Vector3 = poly[poly.size() - 1]
	var last_in: bool = last[axis] >= bound if greater else last[axis] <= bound
	for p: Vector3 in poly:
		var inside: bool = p[axis] >= bound if greater else p[axis] <= bound
		if inside != last_in and absf(float(p[axis]) - float(last[axis])) > 0.0000000001:
			out.append(_r22_top_cut(last, p, axis, bound))
		if inside:
			out.append(p)
		last = p
		last_in = inside
	return out

func _r22_build_top(source: PackedVector3Array, rect: Rect2, subdivisions: int, bucket: Dictionary) -> void:
	# Top-only rational subdivision: sort source terms, evaluate scalar doubles, round once.
	# The old _r22_clip/_r22_partition outside-stream path remains byte-identical.
	var source_end_x: float = -INF
	for point: Vector3 in source:
		source_end_x = maxf(source_end_x, float(point.x))
	if source_end_x != _R22_INHERITED_WEST_EDGE_X:
		_r22_errors.append("Pinned inherited west-grid edge identity differs; no boundary fallback")
		return
	_r22_metrics["boundary_reconciliation"] = {"mode": "exact known generated-edge identity only", "native_source_max_x": source_end_x, "declared_end_x": _R22_RECT.end.x, "width_m": float(_R22_RECT.end.x) - source_end_x, "strip_area_m2": (float(_R22_RECT.end.x) - source_end_x) * (float(_R22_RECT.end.y) - float(_R22_RECT.position.y)), "zero_relief_boundary": true, "outside_original_buffers_changed": false}
	for index: int in range(0, source.size(), 3):
		var a: Vector3 = source[index]
		var b: Vector3 = source[index + 1]
		var c: Vector3 = source[index + 2]
		if maxf(a.x, maxf(b.x, c.x)) < rect.position.x or minf(a.x, minf(b.x, c.x)) > rect.end.x or maxf(a.z, maxf(b.z, c.z)) < rect.position.y or minf(a.z, minf(b.z, c.z)) > rect.end.y:
			continue
		for i: int in range(subdivisions):
			for j: int in range(subdivisions - i):
				var p0: Vector3 = _r22_subdivision_point(a, b, c, i, j, subdivisions)
				var p1: Vector3 = _r22_subdivision_point(a, b, c, i + 1, j, subdivisions)
				var p2: Vector3 = _r22_subdivision_point(a, b, c, i, j + 1, subdivisions)
				_r22_clip_emit(p0, p1, p2, rect, bucket)
				if i + j < subdivisions - 1:
					var p3: Vector3 = _r22_subdivision_point(a, b, c, i + 1, j + 1, subdivisions)
					_r22_clip_emit(p1, p3, p2, rect, bucket)

func _r22_clip_emit(a: Vector3, b: Vector3, c: Vector3, rect: Rect2, bucket: Dictionary) -> void:
	var poly: Array[Vector3] = [a, b, c]
	var axes: PackedInt32Array = PackedInt32Array([0, 0, 2, 2])
	var limits: PackedFloat64Array = PackedFloat64Array([rect.position.x, rect.end.x, rect.position.y, rect.end.y])
	for index: int in range(4):
		poly = _r22_top_clip(poly, axes[index], limits[index], index % 2 == 0)
	for fan: int in range(1, poly.size() - 1):
		if _r22_area(poly[0], poly[fan], poly[fan + 1]) > 0.000000001:
			_r22_emit_top(poly[0], poly[fan], poly[fan + 1], bucket)

func _r22_emit_top(a: Vector3, b: Vector3, c: Vector3, bucket: Dictionary) -> void:
	var points: PackedVector3Array = PackedVector3Array([a, b, c])
	var base_points: PackedVector3Array = PackedVector3Array()
	var relief_values: PackedFloat64Array = PackedFloat64Array()
	var base_flags: PackedByteArray = PackedByteArray()
	for i: int in range(3):
		var p: Vector3 = points[i]
		var old_top: Dictionary = super._foreground_bank_support(p)
		if not old_top.is_empty():
			p.y = float(old_top["height"])
		base_points.append(p)
		base_flags.append(0 if old_top.is_empty() else 1)
		var relief_value: float = _r22_relief(p)
		relief_values.append(relief_value)
		p.y += relief_value
		points[i] = p
	var normal_value: Vector3 = (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	if normal_value.y <= 0.0 or _r22_area(points[0], points[1], points[2]) <= 0.000000001:
		_r22_errors.append("Canonical degenerate/downward triangle")
		return
	# Store native base before float32 Y addition, in exactly canonical corner order.
	_r22_base_faces.append_array(base_points)
	_r22_corner_relief.append_array(relief_values)
	_r22_base_bank_flags.append_array(base_flags)
	var v: PackedVector3Array = bucket["v"] as PackedVector3Array
	var n: PackedVector3Array = bucket["n"] as PackedVector3Array
	var u: PackedVector2Array = bucket["u"] as PackedVector2Array
	var c0: PackedColorArray = bucket["c"] as PackedColorArray
	for p: Vector3 in points:
		v.append(p)
		n.append(normal_value)
		u.append(Vector2(p.x, p.z))
		c0.append(Color(0.92, 1.0, 0.82))
	bucket["v"] = v
	bucket["n"] = n
	bucket["u"] = u
	bucket["c"] = c0

func _r22_index() -> void:
	for _row: int in range(20):
		_r22_rows.append(PackedVector3Array())
		_r22_face_rows.append(PackedInt32Array())
	for i: int in range(0, _r22_faces.size(), 3):
		var a: Vector3 = _r22_faces[i]
		var b: Vector3 = _r22_faces[i + 1]
		var c: Vector3 = _r22_faces[i + 2]
		_r22_changed_faces.append(1 if maxf(_r22_relief(a), maxf(_r22_relief(b), _r22_relief(c))) > 0.000001 else 0)
		var first: int = clampi(int(floor((minf(a.z, minf(b.z, c.z)) - 11.2) / 0.25)), 0, 19)
		var last: int = clampi(int(floor((maxf(a.z, maxf(b.z, c.z)) - 11.2) / 0.25)), 0, 19)
		for row: int in range(first, last + 1):
			var faces: PackedVector3Array = _r22_rows[row]
			faces.append_array(PackedVector3Array([a, b, c]))
			_r22_rows[row] = faces
			var ids: PackedInt32Array = _r22_face_rows[row]
			ids.append(i / 3)
			_r22_face_rows[row] = ids
		# AABB expansion covers the source barycentric edge tolerance; old row bins stay intact.
		var x_first: int = clampi(int(floor((minf(a.x, minf(b.x, c.x)) - 1.0 - _R22_CELL_MARGIN) / 0.30)), 0, 22)
		var x_last: int = clampi(int(floor((maxf(a.x, maxf(b.x, c.x)) - 1.0 + _R22_CELL_MARGIN) / 0.30)), 0, 22)
		var z_first: int = clampi(int(floor((minf(a.z, minf(b.z, c.z)) - 11.2 - _R22_CELL_MARGIN) / 0.25)), 0, 19)
		var z_last: int = clampi(int(floor((maxf(a.z, maxf(b.z, c.z)) - 11.2 + _R22_CELL_MARGIN) / 0.25)), 0, 19)
		for x_cell: int in range(x_first, x_last + 1):
			for z_cell: int in range(z_first, z_last + 1):
				var key: Vector2i = Vector2i(x_cell, z_cell)
				var ids: PackedInt32Array = _r22_cells.get(key, PackedInt32Array()) as PackedInt32Array
				ids.append(i / 3)
				_r22_cells[key] = ids

func _r22_surface(p: Vector3) -> Dictionary:
	if not _r22_inside(p) or _r22_rows.size() != 20:
		return {}
	var best: Dictionary = {}
	var key: Vector2i = Vector2i(clampi(int(floor((p.x - 1.0) / 0.30)), 0, 22), clampi(int(floor((p.z - 11.2) / 0.25)), 0, 19))
	for ordinal: int in _r22_cells.get(key, PackedInt32Array()) as PackedInt32Array:
		var i: int = ordinal * 3
		var hit: Dictionary = _foreground_bank_triangle_support(p, _r22_faces[i], _r22_faces[i + 1], _r22_faces[i + 2], -1, true)
		if not hit.is_empty() and (best.is_empty() or float(hit["height"]) > float(best["height"])):
			best = hit
	return best

func _foreground_bank_support(p: Vector3) -> Dictionary:
	if _r22_old_query == 0:
		var hit: Dictionary = _r22_surface(p)
		if not hit.is_empty():
			return hit
	return super._foreground_bank_support(p)

func _rooted_ground_support(p: Vector3) -> Dictionary:
	if _r22_old_query == 0:
		var hit: Dictionary = _r22_surface(p)
		if not hit.is_empty():
			return hit
	return super._rooted_ground_support(p)

func _r22_outside(source: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in range(0, source.size(), 3):
		var part: Dictionary = _r22_partition(source[i], source[i + 1], source[i + 2])
		if _r22_polygon_area(part["inside"] as Array) <= 0.000000001:
			out.append_array(PackedVector3Array([source[i], source[i + 1], source[i + 2]]))
		else:
			for poly: Array in part["outside"] as Array:
				for fan: int in range(1, poly.size() - 1):
					if _r22_area(poly[0], poly[fan], poly[fan + 1]) > 0.000000001:
						out.append_array(PackedVector3Array([poly[0], poly[fan], poly[fan + 1]]))
	return out

func _r22_weights(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var ac: Vector2 = Vector2(c.x - a.x, c.z - a.z)
	var ap: Vector2 = Vector2(p.x - a.x, p.z - a.z)
	var det: float = ab.cross(ac)
	if absf(det) < 0.0000000001:
		return Vector3(1.0, 0.0, 0.0)
	var u: float = ap.cross(ac) / det
	var v: float = ab.cross(ap) / det
	return Vector3(1.0 - u - v, u, v)

func _r22_fragment(poly: Array, corners: PackedInt32Array, arrays: Array, bucket: Dictionary, moss: bool) -> void:
	var ov: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var on: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var ou: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var oc: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var v: PackedVector3Array = bucket["v"] as PackedVector3Array
	var n: PackedVector3Array = bucket["n"] as PackedVector3Array
	var u: PackedVector2Array = bucket["u"] as PackedVector2Array
	var c: PackedColorArray = bucket["c"] as PackedColorArray
	for fan: int in range(1, poly.size() - 1):
		var points: PackedVector3Array = PackedVector3Array([poly[0], poly[fan], poly[fan + 1]])
		if _r22_area(points[0], points[1], points[2]) <= 0.000000001:
			continue
		for p: Vector3 in points:
			var w: Vector3 = _r22_weights(p, ov[corners[0]], ov[corners[1]], ov[corners[2]])
			var normal_value: Vector3 = on[corners[0]] * w.x + on[corners[1]] * w.y + on[corners[2]] * w.z
			if moss:
				var hit: Dictionary = _r22_surface(p)
				if hit.is_empty():
					_r22_errors.append("Moss support missing")
				else:
					p.y = float(hit["height"]) + 0.003
					normal_value = hit["normal"] as Vector3
			v.append(p)
			n.append(normal_value.normalized())
			u.append(ou[corners[0]] * w.x + ou[corners[1]] * w.y + ou[corners[2]] * w.z)
			c.append(oc[corners[0]] * w.x + oc[corners[1]] * w.y + oc[corners[2]] * w.z)
	bucket["v"] = v
	bucket["n"] = n
	bucket["u"] = u
	bucket["c"] = c

func _r22_clip_triangle(poly: Array[Vector3], a: Vector3, b: Vector3, c: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = poly.duplicate()
	var points: PackedVector3Array = PackedVector3Array([a, b, c])
	var orientation: float = Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z))
	if absf(orientation) < 0.000000001:
		return []
	for edge: int in range(3):
		if out.is_empty():
			break
		var a0: Vector3 = points[edge]
		var b0: Vector3 = points[(edge + 1) % 3]
		var line: Vector2 = Vector2(b0.x - a0.x, b0.z - a0.z)
		var clipped: Array[Vector3] = []
		var last: Vector3 = out[out.size() - 1]
		var ld: float = line.cross(Vector2(last.x - a0.x, last.z - a0.z)) * signf(orientation)
		for p: Vector3 in out:
			var pd: float = line.cross(Vector2(p.x - a0.x, p.z - a0.z)) * signf(orientation)
			if (pd >= 0.0) != (ld >= 0.0):
				clipped.append(last.lerp(p, ld / (ld - pd)))
			if pd >= 0.0:
				clipped.append(p)
			last = p
			ld = pd
		out = clipped
	return out

func _r22_replace(source: ArrayMesh, kind: String, keep_vertical: bool, moss: bool, added: Dictionary) -> ArrayMesh:
	if source == null or source.get_surface_count() != 1:
		_r22_errors.append("One original surface required: " + kind)
		return null
	var arrays: Array = source.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if indices.is_empty():
		for i: int in range(v.size()):
			indices.append(i)
	var retained: PackedInt32Array = PackedInt32Array()
	var whole: PackedInt32Array = PackedInt32Array()
	var cut: PackedInt32Array = PackedInt32Array()
	for i: int in range(0, indices.size(), 3):
		var corners: PackedInt32Array = PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]])
		var a: Vector3 = v[corners[0]]
		var b: Vector3 = v[corners[1]]
		var c: Vector3 = v[corners[2]]
		var part: Dictionary = _r22_partition(a, b, c)
		var inner: Array[Vector3] = part["inside"] as Array[Vector3]
		var vertical: bool = absf(Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z))) < 0.000000001
		if _r22_polygon_area(inner) <= 0.000000001 or (keep_vertical and vertical):
			retained.append_array(corners)
			whole.append(i / 3)
			continue
		cut.append(i / 3)
		for poly: Array in part["outside"] as Array:
			_r22_fragment(poly, corners, arrays, added, false)
		if moss:
			for ordinal: int in _r22_relevant_faces(inner, false):
				var j: int = ordinal * 3
				var clipped: Array[Vector3] = _r22_clip_triangle(inner, _r22_faces[j], _r22_faces[j + 1], _r22_faces[j + 2])
				if clipped.size() >= 3:
					_r22_fragment(clipped, corners, arrays, added, true)
	var stored: Array = source.get("_surfaces") as Array
	if stored.size() != 1 or not stored[0] is Dictionary or retained.is_empty():
		_r22_errors.append("Pinned raw surface unavailable: " + kind)
		return null
	var encoded: Dictionary = (stored[0] as Dictionary).duplicate()
	if encoded.has("lods") or encoded.has("blend_shapes"):
		_r22_errors.append("Unsupported original LOD/blend tables: " + kind)
		return null
	var format_value: int = int(encoded["format"]) | Mesh.ARRAY_FORMAT_INDEX
	var stride: int = RenderingServer.mesh_surface_get_format_index_stride(format_value, int(encoded["vertex_count"]))
	if stride != 2 and stride != 4:
		_r22_errors.append("Invalid actual index stride")
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
	var result: ArrayMesh = ArrayMesh.new()
	result.set("_surfaces", [encoded])
	if result.get_surface_count() != 1:
		_r22_errors.append("Pinned raw setter failed")
		return null
	if not (added["v"] as PackedVector3Array).is_empty():
		var extra: Array = []
		extra.resize(Mesh.ARRAY_MAX)
		extra[Mesh.ARRAY_VERTEX] = added["v"]
		extra[Mesh.ARRAY_NORMAL] = added["n"]
		extra[Mesh.ARRAY_TEX_UV] = added["u"]
		extra[Mesh.ARRAY_COLOR] = added["c"]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, extra)
	_r22_meshes.append({"kind": kind, "original_mesh": source, "selected_mesh": result, "retained_original_ordinals": whole, "retained_indices": retained, "clipped_original_ordinals": cut, "original_encoded": stored[0], "retained_encoded": encoded, "extra_arrays_before_encoding": added, "extra_surface": 1 if result.get_surface_count() == 2 else -1})
	return result

func _r22_gradient(points: PackedVector3Array) -> Vector2:
	var ab: Vector3 = points[1] - points[0]
	var ac: Vector3 = points[2] - points[0]
	var det: float = float(ab.x) * float(ac.z) - float(ab.z) * float(ac.x)
	if absf(det) < 0.0000000001:
		return Vector2.ZERO
	return Vector2((float(ab.y) * float(ac.z) - float(ac.y) * float(ab.z)) / det, (float(ab.x) * float(ac.y) - float(ac.x) * float(ab.y)) / det)

func _r22_slope(points: PackedVector3Array) -> float:
	return rad_to_deg(acos(clampf((points[2] - points[0]).cross(points[1] - points[0]).normalized().y, -1.0, 1.0)))

func _r22_slope_witness(ordinal: int, evaluated: PackedVector3Array) -> Dictionary:
	var base: PackedVector3Array = PackedVector3Array()
	var actual: PackedVector3Array = PackedVector3Array()
	var corners: Array = []
	for corner: int in range(3):
		var j: int = ordinal * 3 + corner
		var b: Vector3 = _r22_base_faces[j]
		var a: Vector3 = _r22_faces[j]
		base.append(b)
		actual.append(a)
		corners.append({"base_xyz": [b.x, b.y, b.z], "actual_xyz": [a.x, a.y, a.z], "evaluated_xyz": [evaluated[corner].x, evaluated[corner].y, evaluated[corner].z], "native_actual_minus_base_y_m": float(a.y) - float(b.y), "field_scalar_m": _r22_corner_relief[j], "unscaled_field_scalar_m": _r22_corner_relief[j] / _R22_RELIEF_SCALE, "base_source": "old_actual_bank_top" if _r22_base_bank_flags[j] == 1 else "original_physical_grid"})
	var base_gradient: Vector2 = _r22_gradient(base)
	var actual_gradient: Vector2 = _r22_gradient(actual)
	var evaluated_gradient: Vector2 = _r22_gradient(evaluated)
	return {"face_ordinal": ordinal, "corners": corners, "base_slope_deg": _r22_slope(base), "actual_slope_deg": _r22_slope(actual), "evaluated_slope_deg": _r22_slope(evaluated), "base_gradient_dy_dx_dz": [base_gradient.x, base_gradient.y], "actual_gradient_dy_dx_dz": [actual_gradient.x, actual_gradient.y], "actual_minus_base_gradient": [actual_gradient.x - base_gradient.x, actual_gradient.y - base_gradient.y], "evaluated_gradient_dy_dx_dz": [evaluated_gradient.x, evaluated_gradient.y]}

func _r22_scale_models() -> Array:
	# Counterfactual float32 vertex models; factor1 is not byte-exact historical01 evidence.
	var models: Array = []
	for factor: float in PackedFloat64Array([0.60, 0.65, 0.70, 1.0]):
		var maximum: float = -1.0
		var witness: Dictionary = {}
		for ordinal: int in range(_r22_faces.size() / 3):
			var points: PackedVector3Array = PackedVector3Array()
			for corner: int in range(3):
				var j: int = ordinal * 3 + corner
				var p: Vector3 = _r22_base_faces[j]
				p.y += (_r22_corner_relief[j] / _R22_RELIEF_SCALE) * factor
				points.append(_r22_faces[j] if factor == _R22_RELIEF_SCALE else p)
			var slope: float = _r22_slope(points)
			if slope > maximum:
				maximum = slope
				witness = _r22_slope_witness(ordinal, points)
		models.append({"factor": factor, "max_triangle_slope_deg": maximum, "witness": witness, "scope": "Actual02 canonical faces" if factor == _R22_RELIEF_SCALE else "Reconstructed counterfactual from native02 base and unscaled scalar; not historical01 raw-array proof"})
	return models

func _r22_measure() -> void:
	var area: float = 0.0
	var raised_area: float = 0.0
	var maximum: float = 0.0
	var slope: float = 0.0
	var base_slope: float = 0.0
	var slope_witness: Dictionary = {}
	var base_witness: Dictionary = {}
	var edge_max: float = 0.0
	var graph: Dictionary = {}
	var areas: Array[float] = []
	var active: Array[int] = []
	for i: int in range(0, _r22_faces.size(), 3):
		var a: Vector3 = _r22_faces[i]
		var b: Vector3 = _r22_faces[i + 1]
		var c: Vector3 = _r22_faces[i + 2]
		var projected: float = absf(Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z))) * 0.5
		area += projected
		areas.append(projected)
		edge_max = maxf(edge_max, maxf(Vector2(a.x - b.x, a.z - b.z).length(), maxf(Vector2(b.x - c.x, b.z - c.z).length(), Vector2(c.x - a.x, c.z - a.z).length())))
		var actual_points: PackedVector3Array = PackedVector3Array([a, b, c])
		var face_slope: float = _r22_slope(actual_points)
		if slope_witness.is_empty() or face_slope > slope:
			slope = face_slope
			slope_witness = _r22_slope_witness(i / 3, actual_points)
		var base_points: PackedVector3Array = PackedVector3Array([_r22_base_faces[i], _r22_base_faces[i + 1], _r22_base_faces[i + 2]])
		var face_base_slope: float = _r22_slope(base_points)
		if base_witness.is_empty() or face_base_slope > base_slope:
			base_slope = face_base_slope
			base_witness = _r22_slope_witness(i / 3, base_points)
		for p: Vector3 in PackedVector3Array([a, b, c]):
			maximum = maxf(maximum, _r22_relief(p))
		if _r22_relief((a + b + c) / 3.0) > 0.01:
			raised_area += projected
			var ordinal: int = i / 3
			active.append(ordinal)
			for p: Vector3 in PackedVector3Array([a, b, c]):
				var key: Vector2i = Vector2i(roundi(p.x * 100000.0), roundi(p.z * 100000.0))
				if not graph.has(key):
					graph[key] = []
				(graph[key] as Array).append(ordinal)
	var seen: Dictionary = {}
	var components: Array[float] = []
	for ordinal: int in active:
		if seen.has(ordinal):
			continue
		var queue: Array[int] = [ordinal]
		var cursor: int = 0
		var component_area: float = 0.0
		seen[ordinal] = true
		while cursor < queue.size():
			var face: int = queue[cursor]
			cursor += 1
			component_area += areas[face]
			for corner: int in range(3):
				var p: Vector3 = _r22_faces[face * 3 + corner]
				var key: Vector2i = Vector2i(roundi(p.x * 100000.0), roundi(p.z * 100000.0))
				for neighbor: int in graph.get(key, []) as Array:
					if not seen.has(neighbor):
						seen[neighbor] = true
						queue.append(neighbor)
		components.append(component_area)
	components.sort()
	var largest: float = components[components.size() - 1] if not components.is_empty() else 0.0
	var sections: Array = []
	for z: float in PackedFloat64Array([12.5, 13.5, 14.5, 15.5]):
		var row: Array = []
		for i: int in range(29):
			var p: Vector3 = Vector3(1.0 + float(i) * 6.8 / 28.0, 0.0, z)
			row.append([p.x, _r22_surface(p).get("height", null), _r22_relief(p)])
		sections.append({"z": z, "x_y_proposed_field": row})
	var max_cell_candidates: int = 0
	for ids: PackedInt32Array in _r22_cells.values():
		max_cell_candidates = maxi(max_cell_candidates, ids.size())
	_r22_metrics = {"field_scale": _R22_RELIEF_SCALE, "max_slope_face_witness": slope_witness, "max_base_triangle_slope_deg": base_slope, "max_base_slope_face_witness": base_witness, "slope_scale_models": _r22_scale_models(), "point_index": {"cell_x_m": 0.30, "cell_z_m": 0.25, "aabb_margin_m": _R22_CELL_MARGIN, "cell_count": _r22_cells.size(), "max_face_candidates": max_cell_candidates, "same_canonical_faces": true, "original_20_rows_retained": true}, "canonical_triangles": _r22_faces.size() / 3, "projected_area_m2": area, "raised_centroid_area_above_10mm_m2": raised_area, "max_field_at_vertices_m": maximum, "max_actual_triangle_slope_deg": slope, "max_projected_triangle_edge_m": edge_max, "zero_relief_protection_buffer_m": 0.36, "vertex_connected_component_areas_m2": components, "largest_component_fraction": largest / maxf(raised_area, 0.000001), "sections": sections, "proposed_bounds": [1.0, 7.8, 11.2, 16.2]}
	if absf(area - 34.0) > 0.001:
		_r22_errors.append("Actual canonical base partition does not cover34m2")
	if raised_area < 9.0 or maximum < 0.22 or largest < raised_area * 0.70:
		_r22_errors.append("Exclusions erased substantial connected mass")
	if slope > 25.0:
		_r22_errors.append("Actual slope exceeds proposed25deg, unchanged player limit35deg")
	if edge_max > 0.36:
		_r22_errors.append("Canonical edge exceeds zero-relief protected footprint buffer")

func _foreground_understory_choice(id: String, mesh: ArrayMesh, source: Vector3, p: Vector3, turn: Vector3, size_value: Vector3, reach: float) -> Dictionary:
	var result: Dictionary = super._foreground_understory_choice(id, mesh, source, p, turn, size_value, reach)
	if _r22_cluster:
		_r22_choice = {"source_origin": source, "choice_point": p, "choice_turn": turn, "choice_scale": size_value, "choice_original_mesh": mesh, "choice_selected_mesh": result["mesh"], "choice_selected_id": result["id"], "choice_family": result["family"]}
	return result

func _add_clustered_ground_foliage(id: String, mesh: ArrayMesh, origin: Vector3, turn: Vector3, scale_value: Vector3, reach: float) -> void:
	_r22_cluster = true
	_r22_reach = reach
	_r22_choice = {}
	_r22_old_query += 1
	super._add_clustered_ground_foliage(id, mesh, origin, turn, scale_value, reach)
	_r22_old_query -= 1
	_r22_cluster = false

func _r22_relevant_faces(poly: Array, raised_only: bool) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if poly.is_empty():
		return result
	var x0: float = 1000.0
	var x1: float = -1000.0
	var z0: float = 1000.0
	var z1: float = -1000.0
	for p: Vector3 in poly:
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		z0 = minf(z0, p.z)
		z1 = maxf(z1, p.z)
	if x1 < 1.0 or x0 > 7.8 or z1 < 11.2 or z0 > 16.2:
		return result
	var seen: Dictionary = {}
	var first: int = clampi(int(floor((z0 - 11.2) / 0.25)), 0, 19)
	var last: int = clampi(int(floor((z1 - 11.2) / 0.25)), 0, 19)
	for row: int in range(first, last + 1):
		for ordinal: int in _r22_face_rows[row]:
			if seen.has(ordinal) or (raised_only and _r22_changed_faces[ordinal] == 0):
				continue
			seen[ordinal] = true
			var a: Vector3 = _r22_faces[ordinal * 3]
			var b: Vector3 = _r22_faces[ordinal * 3 + 1]
			var c: Vector3 = _r22_faces[ordinal * 3 + 2]
			if maxf(a.x, maxf(b.x, c.x)) < x0 or minf(a.x, minf(b.x, c.x)) > x1 or maxf(a.z, maxf(b.z, c.z)) < z0 or minf(a.z, minf(b.z, c.z)) > z1:
				continue
			result.append(ordinal)
	return result

func _r22_affects(mesh: ArrayMesh, xf: Transform3D) -> bool:
	# Actual full resolved XZ triangle footprint, including roots outside the slice.
	var local: PackedVector3Array = mesh.get_faces()
	for i: int in range(0, local.size(), 3):
		var poly: Array[Vector3] = [xf * local[i], xf * local[i + 1], xf * local[i + 2]]
		for ordinal: int in _r22_relevant_faces(poly, true):
			var j: int = ordinal * 3
			var clipped: Array[Vector3] = _r22_clip_triangle(poly, _r22_faces[j], _r22_faces[j + 1], _r22_faces[j + 2])
			for p: Vector3 in clipped:
				var changed: Dictionary = _r22_surface(p)
				_r22_old_query += 1
				var old: Dictionary = _rooted_ground_support(p)
				_r22_old_query -= 1
				if not old.is_empty() and not changed.is_empty() and absf(float(changed["height"]) - float(old["height"])) > 0.000001:
					return true
	# Projected vertical/degenerate triangles need explicit vertex/edge witnesses.
	for sample: Vector3 in _rooted_group_samples(mesh):
		var p: Vector3 = xf * sample
		var changed: Dictionary = _r22_surface(p)
		if changed.is_empty():
			continue
		_r22_old_query += 1
		var old: Dictionary = _rooted_ground_support(p)
		_r22_old_query -= 1
		if not old.is_empty() and absf(float(changed["height"]) - float(old["height"])) > 0.000001:
			return true
	return false

func _r22_cluster_issue(mesh: ArrayMesh, xf: Transform3D, reach: float) -> String:
	# Legacy clustered callers retain their original reach, without imposing +.06.
	if not _ground_foliage_allowed(xf.origin, reach):
		return "original_caller_root_footprint"
	for sample: Vector3 in _rooted_group_samples(mesh):
		var p: Vector3 = xf * sample
		if not p.is_finite() or Vector2(p.x - xf.origin.x, p.z - xf.origin.z).length() > reach + 0.000001:
			return "finite_or_caller_reach"
		if not _ground_foliage_allowed(p, 0.0):
			return "protected_sample"
		var support: Dictionary = _rooted_ground_support(p)
		if support.is_empty() or p.y < float(support["height"]) - 0.002:
			return "soil_penetration"
		var stone: Dictionary = _rooted_ground_stone_top(p, _r22_stones)
		if not stone.is_empty() and p.y < float(stone["height"]) - 0.002:
			return "stone_penetration"
	return ""

func _add_foliage(id: String, mesh: ArrayMesh, origin: Vector3, turn: Vector3, scale_value: Vector3) -> void:
	var old_xf: Transform3D = Transform3D(Basis.from_euler(turn).scaled(scale_value), origin)
	var p: Vector3 = origin
	var selected_turn: Vector3 = turn
	var affected: bool = false
	var old_issue: String = ""
	var issue: String = ""
	var depth: int = _r22_old_query
	if _r22_cluster or _r22_shrub:
		_r22_old_query = 0
		affected = _r22_affects(mesh, old_xf)
		if _r22_cluster and affected:
			_r22_old_query = 1
			old_issue = _r22_cluster_issue(mesh, old_xf, _r22_reach)
			_r22_old_query = 0
			var support: Dictionary = _rooted_ground_support(p)
			if support.is_empty():
				issue = "missing_root_support"
			else:
				p.y = float(support["height"])
				# Direct YXZ keeps original yaw exactly, without Euler branch wrapping.
				var local_n: Vector3 = Basis(Vector3.UP, -turn.y) * (support["normal"] as Vector3)
				selected_turn = Vector3(atan2(local_n.z, local_n.y), turn.y, asin(clampf(-local_n.x, -1.0, 1.0)))
				issue = _r22_cluster_issue(mesh, Transform3D(Basis.from_euler(selected_turn).scaled(scale_value), p), _r22_reach)
				if not issue.is_empty():
					selected_turn = turn
					issue = _r22_cluster_issue(mesh, Transform3D(Basis.from_euler(turn).scaled(scale_value), p), _r22_reach)
		elif _r22_shrub:
			p.y += _r22_group_delta
			affected = affected or _r22_group_delta != 0.0
			if affected:
				for sample: Vector3 in _rooted_group_samples(mesh):
					var q: Vector3 = p + old_xf.basis * sample
					var support: Dictionary = _rooted_ground_support(q)
					if not support.is_empty() and q.y < float(support["height"]) - 0.002:
						issue = "coherent_shrub_leaf_soil_penetration"
		_r22_old_query = depth
	var xf: Transform3D = Transform3D(Basis.from_euler(selected_turn).scaled(scale_value), p)
	if not issue.is_empty():
		_r22_errors.append("Affected original selected foliage unsafe: " + issue)
	if _r22_cluster:
		var label: String = _review19_old_label(mesh)
		if not label.is_empty() and old_xf != xf:
			var key: String = _review19_context_key(label, id, old_xf)
			var queue: Array = _review19_contexts.get(key, []) as Array
			if queue.is_empty():
				_r22_errors.append("Original selected-mesh caller context missing")
			else:
				var context: Dictionary = queue.pop_back() as Dictionary
				if queue.is_empty():
					_review19_contexts.erase(key)
				context["origin"] = p
				context["turn"] = selected_turn
				_review19_queue_context(label, id, xf, context)
	if _r22_cluster or _r22_shrub:
		var record: Dictionary = _r22_choice.duplicate() if _r22_cluster else {}
		record.merge({"sequence": _r22_sequence, "category": "clustered" if _r22_cluster else "shrub_leaf", "mesh": mesh, "id": id, "original_transform": old_xf, "selected_transform": xf, "caller_reach": _r22_reach if _r22_cluster else -1.0, "affected": affected, "changed": old_xf != xf, "old_issue": old_issue, "selected_issue": issue}, true)
		_r22_placements.append(record)
	_r22_sequence += 1
	super._add_foliage(id, mesh, p, selected_turn, scale_value)

func _foreground_bank_shrub_lift(p: Vector3) -> float:
	_r22_old_query += 1
	var old_lift: float = super._foreground_bank_shrub_lift(p)
	_r22_old_query -= 1
	var support: Dictionary = _r22_surface(p)
	var lift: float = float(support["height"]) - p.y if not support.is_empty() else old_lift
	_r22_old_group_lift = old_lift
	_r22_group_delta = lift - old_lift
	var body: MeshInstance3D
	for i: int in range(get_child_count() - 1, -1, -1):
		if get_child(i) is MeshInstance3D:
			body = get_child(i) as MeshInstance3D
			break
	_r22_shrubs.append({"origin": p, "body": body, "original_body_position": body.position + Vector3.UP * old_lift if body != null else Vector3.ZERO, "selected_body_position": body.position + Vector3.UP * lift if body != null else Vector3.ZERO, "group_delta_y": _r22_group_delta, "leaf_count": 24})
	return lift

func _add_bank_shrub_leaf(id: String, mesh: ArrayMesh, origin: Vector3, turn: Vector3, scale_value: Vector3, _group_lift: float) -> void:
	_r22_shrub = true
	_r22_old_query += 1
	super._add_bank_shrub_leaf(id, mesh, origin, turn, scale_value, _r22_old_group_lift)
	_r22_old_query -= 1
	_r22_shrub = false

func _r22_sha(data: PackedByteArray) -> String:
	var hash: HashingContext = HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if not data.is_empty() and hash.update(data) != OK:
		return ""
	return hash.finish().hex_encode()

func _rooted_groups_fingerprint() -> String:
	return _r22_sha(var_to_bytes([_R22_REVISION, super._rooted_groups_fingerprint(), _r22_faces])) if not _r22_faces.is_empty() else ""

func get_review22_bake_document() -> Dictionary:
	var doc: Dictionary = _rooted_groups_bake_document()
	doc["schema"] = _R22_SCHEMA
	doc["authoring_revision"] = _R22_REVISION
	return doc

func _r22_read(path: String, limit: int) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length: int = file.get_length()
	if length <= 0 or length >= limit:
		file.close()
		return PackedByteArray()
	var data: PackedByteArray = file.get_buffer(length)
	file.close()
	return data if data.size() == length else PackedByteArray()

func _r22_decode(doc: Dictionary) -> Dictionary:
	if doc.get("schema", "") != _R22_SCHEMA or doc.get("authoring_revision", "") != _R22_REVISION or doc.get("codec_revision", "") != _ROOTED_GROUPS_CODEC_REVISION:
		return {"ok": false, "error": "FreshR22 schema/revision/codec required"}
	var adapter: Dictionary = doc.duplicate()
	adapter["schema"] = "rooted-foreground-groups-v2"
	adapter["authoring_revision"] = _ROOTED_GROUPS_AUTHORING_REVISION
	return _rooted_groups_decode_bake(adapter)

func _create_rooted_ground_groups() -> void:
	if bool(get_meta("review22_author_mode", false)):
		_generate_rooted_ground_groups()
		_r22_bake = {"mode": "authored", "reason": "Explicit standaloneR22 author mode", "fingerprint": _rooted_groups_fingerprint()}
		_rooted_foreground_group_load_status = _r22_bake.duplicate()
		return
	var path: String = String(get_meta("review22_bake_lock_path", ""))
	var pin: String = String(get_meta("review22_bake_lock_sha256", ""))
	var error: String = "Immutable fresh bake lock/pin missing"
	var decoded: Dictionary = {}
	if path.is_absolute_path() and path == path.simplify_path() and path.begins_with(_R22_BAKE_DIR) and pin.length() == 64:
		var bytes: PackedByteArray = _r22_read(path, 16384)
		if not bytes.is_empty() and _r22_sha(bytes) == pin:
			var json: JSON = JSON.new()
			if json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
				var lock: Dictionary = json.data as Dictionary
				var payload_path: String = String(lock.get("payload_path", ""))
				var payload_sha: String = String(lock.get("payload_sha256", ""))
				if lock.get("schema", "") == "mush-r22-owned-bake-lock/3" and lock.get("authoring_revision", "") == _R22_REVISION and lock.get("candidate_sha256", "") == FileAccess.get_sha256(_R22_PATH) and lock.get("fingerprint", "") == _rooted_groups_fingerprint() and lock.get("attempt_count", 0) == 474 and lock.get("codec_revision", "") == _ROOTED_GROUPS_CODEC_REVISION and payload_path.is_absolute_path() and payload_path == payload_path.simplify_path() and payload_path.begins_with(_R22_BAKE_DIR) and payload_sha.length() == 64:
					var payload: PackedByteArray = _r22_read(payload_path, _ROOTED_GROUPS_BAKE_LIMIT)
					if not payload.is_empty() and payload.size() == int(lock.get("payload_bytes", -1)) and _r22_sha(payload) == payload_sha:
						var payload_json: JSON = JSON.new()
						if payload_json.parse(payload.get_string_from_utf8()) == OK and payload_json.data is Dictionary:
							decoded = _r22_decode(payload_json.data as Dictionary)
							error = String(decoded.get("error", "Decode rejected"))
						else:
							error = "Fresh payload JSON invalid"
					else:
						error = "Fresh payload size/SHA invalid"
				else:
						error = "Fresh lock candidate/revision/fingerprint/path invalid"
			else:
					error = "Fresh lock JSON invalid"
		else:
			error = "Fresh lock size/SHA invalid"
	if not bool(decoded.get("ok", false)):
		_r22_bake = {"mode": "refused", "reason": error, "fingerprint": _rooted_groups_fingerprint()}
		_rooted_foreground_group_load_status = _r22_bake.duplicate()
		_r22_errors.append("Normal bake REFUSED before append: " + error)
		return
	var records: Array[Dictionary] = decoded["records"] as Array[Dictionary]
	for record: Dictionary in records:
		if bool(record["accepted"]):
			_add_foliage(record["id"] as String, _foreground_understory_meshes[record["label"]] as ArrayMesh, record["origin"] as Vector3, record["turn"] as Vector3, record["scale"] as Vector3)
	_rooted_foreground_group_records = records
	_rooted_foreground_group_stats = decoded["stats"] as Dictionary
	_r22_bake = {"mode": "baked", "reason": "Fresh all474 SHA/fingerprint rows validated before replay", "fingerprint": decoded["fingerprint"], "lock_path": path, "lock_sha256": pin}
	_rooted_foreground_group_load_status = _r22_bake.duplicate()

func get_review22_terrain_evidence() -> Dictionary:
	return {"ground_node": _r22_ground, "soil_node": _r22_soil, "moss_node": _r22_moss, "west_collision": _r22_collision, "old_collision_faces": _r22_old_collision, "canonical_faces": _r22_faces, "base_faces": _r22_base_faces, "corner_relief_scalars": _r22_corner_relief, "corner_base_bank_flags": _r22_base_bank_flags, "point_cells": _r22_cells, "support_rows": _r22_rows, "support_face_rows": _r22_face_rows, "original_grid_faces": _foreground_bank_original_faces, "original_bank_top_faces": _foreground_bank_top_faces, "stones": _r22_stones, "mesh_records": _r22_meshes, "placements": _r22_placements, "shrub_groups": _r22_shrubs, "rooted_records": _rooted_foreground_group_records, "metrics": _r22_metrics, "bake": _r22_bake, "status": _r22_status, "errors": _r22_errors}

func get_review22_terrain_report() -> Dictionary:
	var affected: Dictionary = {"clustered": 0, "shrub_leaf": 0}
	var changed: Dictionary = {"clustered": 0, "shrub_leaf": 0}
	var inherited_bad: int = 0
	for record: Dictionary in _r22_placements:
		var category: String = String(record["category"])
		if bool(record["affected"]):
			affected[category] = int(affected[category]) + 1
		if bool(record["changed"]):
			changed[category] = int(changed[category]) + 1
		if not String(record["old_issue"]).is_empty():
			inherited_bad += 1
	return {"schema": "mush-r22-soil-shoulder/3", "status": _r22_status, "errors": _r22_errors.duplicate(), "metrics": _r22_metrics.duplicate(true), "affected_original_foliage": affected, "changed_original_foliage": changed, "inherited_affected_discrete_guard_failures": inherited_bad, "rooted_stats": _rooted_foreground_group_stats.duplicate(true), "bake": _r22_bake.duplicate(true), "comparison_actor": {"xz": [4.0, 14.0], "proposed_feet_y": _rooted_ground_support(Vector3(4.0, 0.0, 14.0)).get("height", null), "camera_preserved": true, "terrain_disk_not_carved": true}, "scope": "One bounded west shared soil top/one old collider; original grid caches unchanged; original cluster choices preserved before reroot, coherent shrubs, strict fresh474 bake, dynamic144 roots. Values proposed; actual graph/continuous safety/contact/render gates required."}
