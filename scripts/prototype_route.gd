extends Node3D
## Reusable natural-route module: one continuous walking ribbon (flat tread plus gently
## falling shoulders) with matching collision along a SUPPLIED centreline.
## Built once by configure(); no per-frame geometry, no process callbacks, no mutation
## of any input resource. STATIC-REVIEW ONLY: not run in Godot; native CharacterBody
## traversal, camera and join behaviour are UNVERIFIED until the integration owner tests.
##
## Placement: add as a child of a parent whose global transform is the identity (for
## example PrototypeScenery) and pass world-space points. Query results are then in
## world space as well (get_report().identity_transform tells whether that held).
##
## configure(params) keys (all optional except "centerline"; numbers are clamped and the
## clamp is listed in get_report().notes; structurally invalid input is rejected,
## nothing is built and get_report().errors says why):
##   centerline         PackedVector3Array  world points, 2..256, y = desired tread height.
##                      Smoothed through a Catmull-Rom/Bezier curve. Point 0 should lie on
##                      the baked-collider seam at the baked surface height (flush join).
##   tread_width        4.0   m, 2.5..8     flat walkable core
##   shoulder_width     3.0   m, 0.5..6     each side; falls away from the tread
##   shoulder_angle_deg 18.0  5..22         cross-slope of the shoulders
##   max_grade_deg      14.0  0..20         along-route grade limit; y is relaxed to meet it
##   sample_spacing     1.5   m, 0.75..3
##   taper_length       6.0   m, 0..20      shoulders blend flat from the start
##   join_overlap       0.2   m, 0..1       ribbon extends this far behind point 0 at y0
##   join_zone_length   1.5   m, 0..6       beyond this the ribbon may not enter exclusions
##   exclusion_rects    Array[Rect2]        XZ rects (x, z, w, d) of baked colliders
##   ground_height      Callable(x, z)->float  optional; sizes the visual embankment skirt
##   skirt_min_depth    1.5 / skirt_max_depth 10.0   m (visual only, never collides)
##   curb_height        0.0   m, 0..1.5     optional invisible side wall (camera also hits it)
##   safe_inset         0.35  m, 0.1..1.0   safe corridor = tread+shoulder minus this
##   corridor_below     1.5 / corridor_above 6.0  m, vertical band for is_in_corridor()
##   collision_layer    1     int mask, 1..1048575 (player mask 1|4|16; camera adds 32)
##   material           Material            optional injection; assigned, never modified
##   uv_metres          4.0   m of route per V repeat, 0.5..64
##   visible_mesh       true
## Returns true when built. Collision ownership: one StaticBody3D "RouteCollision" owned by
## this node only; it never touches the baked colliders or the no-collider far scenery.

const MAX_POINTS: int = 256
const MAX_SAMPLES: int = 1200
const MIN_LENGTH: float = 8.0
const MAX_LENGTH: float = 1500.0
## Player FLOOR_COS is cos 35 degrees; the surface must stay inside cos 30 degrees.
const MIN_NORMAL_Y: float = 0.866
const CHUNK_SEGMENTS: int = 8
const END_OVERSHOOT: float = 0.25

var errors: PackedStringArray = PackedStringArray()
var notes: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()
var valid: bool = false

var _body: StaticBody3D
var _mesh_instance: MeshInstance3D
var _layer: int = 1
var _material_injected: bool = false
var _tread_half: float = 2.0
var _shoulder: float = 3.0
var _shoulder_tan: float = 0.3249
var _safe_half: float = 4.65
var _below: float = 1.5
var _above: float = 6.0
var _p: PackedVector3Array = PackedVector3Array()
var _s: PackedFloat32Array = PackedFloat32Array()
var _taper: PackedFloat32Array = PackedFloat32Array()
var _chunk_rects: Array[Rect2] = []
var _chunk_first: PackedInt32Array = PackedInt32Array()
var _bounds: AABB = AABB()
var _stats: Dictionary = {}
# Result of the last _locate() call.
var _q_index: int = 0
var _q_t: float = 0.0
var _q_lateral: float = 0.0
var _q_over: float = 0.0

# --- Build ---

func configure(params: Dictionary) -> bool:
	if _body != null:
		return false
	errors = PackedStringArray()
	notes = PackedStringArray()
	warnings = PackedStringArray()
	valid = false
	set_process(false)
	set_physics_process(false)
	if transform != Transform3D.IDENTITY:
		errors.append("node transform must be identity; pass world-space points under an identity parent")
		return false
	var raw: Variant = params.get("centerline", null)
	if not raw is PackedVector3Array:
		errors.append("centerline must be a PackedVector3Array")
		return false
	var tread: float = _num(params, "tread_width", 4.0, 2.5, 8.0)
	_shoulder = _num(params, "shoulder_width", 3.0, 0.5, 6.0)
	var shoulder_deg: float = _num(params, "shoulder_angle_deg", 18.0, 5.0, 22.0)
	var grade_deg: float = _num(params, "max_grade_deg", 14.0, 0.0, 20.0)
	var spacing: float = _num(params, "sample_spacing", 1.5, 0.75, 3.0)
	var taper_len: float = _num(params, "taper_length", 6.0, 0.0, 20.0)
	var overlap: float = _num(params, "join_overlap", 0.2, 0.0, 1.0)
	var join_zone: float = _num(params, "join_zone_length", 1.5, 0.0, 6.0)
	var skirt_min: float = _num(params, "skirt_min_depth", 1.5, 0.3, 10.0)
	var skirt_max: float = maxf(_num(params, "skirt_max_depth", 10.0, 1.0, 30.0), skirt_min)
	var curb: float = _num(params, "curb_height", 0.0, 0.0, 1.5)
	var inset: float = _num(params, "safe_inset", 0.35, 0.1, 1.0)
	_below = _num(params, "corridor_below", 1.5, 0.5, 6.0)
	_above = _num(params, "corridor_above", 6.0, 1.0, 20.0)
	var uv_metres: float = _num(params, "uv_metres", 4.0, 0.5, 64.0)
	_layer = clampi(int(params.get("collision_layer", 1)), 1, 1048575)
	_tread_half = tread * 0.5
	_shoulder_tan = tan(deg_to_rad(shoulder_deg))
	var half_total: float = _tread_half + _shoulder
	_safe_half = maxf(_tread_half, half_total - inset)
	var max_grade: float = tan(deg_to_rad(grade_deg))

	# 1. Control points: finite, deduplicated, y clamped.
	var controls: PackedVector3Array = PackedVector3Array()
	var supplied: PackedVector3Array = raw
	if supplied.size() > MAX_POINTS:
		errors.append("centerline has more than %d points" % MAX_POINTS)
		return false
	for point: Vector3 in supplied:
		if not point.is_finite():
			errors.append("centerline contains a non-finite point")
			return false
		var fixed := Vector3(point.x, clampf(point.y, -200.0, 400.0), point.z)
		if not controls.is_empty() and Vector2(fixed.x - controls[-1].x, fixed.z - controls[-1].z).length() < 0.5:
			notes.append("control point closer than 0.5 m dropped")
			continue
		controls.append(fixed)
	if controls.size() < 2:
		errors.append("centerline needs at least two points 0.5 m apart")
		return false

	# 2. Smooth with a native Curve3D, then bake at the sample spacing.
	var curve := Curve3D.new()
	curve.bake_interval = spacing
	for i: int in controls.size():
		var before: Vector3 = controls[maxi(i - 1, 0)]
		var after: Vector3 = controls[mini(i + 1, controls.size() - 1)]
		var tangent: Vector3 = (after - before) / (6.0 if i > 0 and i < controls.size() - 1 else 3.0)
		curve.add_point(controls[i], -tangent, tangent)
	var baked: PackedVector3Array = curve.get_baked_points()
	var pts: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in baked:
		if not point.is_finite():
			errors.append("curve produced a non-finite sample")
			return false
		if not pts.is_empty() and Vector2(point.x - pts[-1].x, point.z - pts[-1].z).length() < 0.05:
			continue
		pts.append(point)
	if pts.size() < 2:
		errors.append("baked route is degenerate")
		return false
	if overlap >= 0.05:
		var back: Vector2 = Vector2(pts[0].x - pts[1].x, pts[0].z - pts[1].z).normalized()
		pts.insert(0, Vector3(pts[0].x + back.x * overlap, pts[0].y, pts[0].z + back.y * overlap))
	if pts.size() > MAX_SAMPLES:
		errors.append("route needs %d samples (limit %d); raise sample_spacing or shorten" % [pts.size(), MAX_SAMPLES])
		return false
	var count: int = pts.size()
	var arc := PackedFloat32Array()
	arc.resize(count)
	for i: int in range(1, count):
		arc[i] = arc[i - 1] + Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	if arc[count - 1] < MIN_LENGTH or arc[count - 1] > MAX_LENGTH:
		errors.append("route length %.1f m outside %.0f..%.0f" % [arc[count - 1], MIN_LENGTH, MAX_LENGTH])
		return false

	# 3. Along-route grade limit by pairwise relaxation; the start height is pinned (flush join).
	var ys := PackedFloat32Array()
	var y_in := PackedFloat32Array()
	ys.resize(count)
	y_in.resize(count)
	for i: int in count:
		ys[i] = pts[i].y
		y_in[i] = pts[i].y
	for sweep: int in 400:
		var worst: float = 0.0
		for i: int in range(1, count):
			var run: float = arc[i] - arc[i - 1]
			var rise: float = ys[i] - ys[i - 1]
			var excess: float = absf(rise) - max_grade * run
			if excess > 0.0001:
				worst = maxf(worst, excess)
				var shift: float = signf(rise) * excess
				if i == 1:
					ys[i] -= shift
				else:
					ys[i] -= shift * 0.5
					ys[i - 1] += shift * 0.5
		if worst <= 0.0001:
			break
	var max_adjust: float = 0.0
	var measured_grade: float = 0.0
	for i: int in count:
		pts[i] = Vector3(pts[i].x, ys[i], pts[i].z)
		max_adjust = maxf(max_adjust, absf(ys[i] - y_in[i]))
		if i > 0:
			measured_grade = maxf(measured_grade, absf(ys[i] - ys[i - 1]) / (arc[i] - arc[i - 1]))
	if measured_grade > max_grade * 1.02 + 0.001:
		errors.append("grade limit %.1f deg cannot be met by the supplied heights (%.1f deg)" % [grade_deg, rad_to_deg(atan(measured_grade))])
		return false
	if max_adjust > 0.05:
		notes.append("tread heights adjusted up to %.2f m to respect the grade limit" % max_adjust)

	# 4. Frames and turn radius (inner edge must not fold over).
	var forward: Array[Vector3] = []
	for i: int in count:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, count - 1)]
		var f := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if f.length() < 0.001:
			errors.append("degenerate tangent at sample %d" % i)
			return false
		forward.append(f.normalized())
	var min_radius: float = INF
	for i: int in range(1, count - 1):
		var turn: float = forward[i - 1].angle_to(forward[i + 1]) * 0.5
		if turn > 0.0001:
			min_radius = minf(min_radius, (arc[i + 1] - arc[i - 1]) * 0.5 / turn)
	if min_radius < half_total * 1.15:
		errors.append("turn radius %.1f m is too tight for a %.1f m half width" % [min_radius, half_total])
		return false

	# 5. Walking surface: 4 vertices per ring (outer-left, tread-left, tread-right, outer-right).
	var taper := PackedFloat32Array()
	taper.resize(count)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var rights: Array[Vector3] = []
	var u_edge: float = _shoulder / (tread + 2.0 * _shoulder)
	var u_tread: float = tread / (tread + 2.0 * _shoulder)
	for i: int in count:
		var right := Vector3(-forward[i].z, 0.0, forward[i].x)
		rights.append(right)
		taper[i] = smoothstep(0.0, taper_len, arc[i]) if taper_len > 0.001 else 1.0
		var drop := Vector3(0.0, -_shoulder * _shoulder_tan * taper[i], 0.0)
		var c: Vector3 = pts[i]
		verts.append(c - right * half_total + drop)
		verts.append(c - right * _tread_half)
		verts.append(c + right * _tread_half)
		verts.append(c + right * half_total + drop)
		var v: float = arc[i] / uv_metres
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(u_edge, v))
		uvs.append(Vector2(u_edge + u_tread, v))
		uvs.append(Vector2(1.0, v))
		for k: int in 4:
			colors.append(Color(0, 0, 0))
	var indices := PackedInt32Array()
	var flips: int = 0
	var degenerate: int = 0
	var min_normal_y: float = 1.0
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i: int in count - 1:
		for k: int in 3:
			var a: int = i * 4 + k
			var b: int = a + 1
			var c: int = a + 4
			var d: int = c + 1
			for tri: Array in [[a, c, d], [a, d, b]]:
				var n: Vector3 = (verts[tri[2]] - verts[tri[0]]).cross(verts[tri[1]] - verts[tri[0]])
				if n.length() < 0.000001:
					degenerate += 1
					continue
				if n.y < 0.0:
					flips += 1
					tri = [tri[0], tri[2], tri[1]]
					n = -n
				min_normal_y = minf(min_normal_y, n.normalized().y)
				indices.append_array(PackedInt32Array(tri))
				for index: int in tri:
					normals[index] += n
	if degenerate > 0:
		errors.append("%d degenerate surface triangles" % degenerate)
		return false
	if min_normal_y < MIN_NORMAL_Y:
		errors.append("surface slope %.1f deg exceeds 30 deg; lower shoulder angle/grade or widen turns" % rad_to_deg(acos(min_normal_y)))
		return false
	for i: int in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length() > 0.0 else Vector3.UP

	# 6. Exclusion check: past the join zone the walking surface stays off baked colliders.
	var exclusion_hits: int = 0
	var rects: Array[Rect2] = []
	var raw_rects: Variant = params.get("exclusion_rects", [])
	if raw_rects is Array:
		for entry: Variant in raw_rects:
			if entry is Rect2: rects.append(entry)
	for i: int in count:
		if arc[i] <= overlap + join_zone:
			continue
		for k: int in [0, 3]:
			var vertex: Vector3 = verts[i * 4 + k]
			for rect: Rect2 in rects:
				if rect.has_point(Vector2(vertex.x, vertex.z)):
					exclusion_hits += 1
		var centre := Vector2(pts[i].x, pts[i].z)
		for rect: Rect2 in rects:
			if rect.has_point(centre):
				exclusion_hits += 1
	if exclusion_hits > 0:
		errors.append("%d ring vertices enter exclusion rects beyond the join zone" % exclusion_hits)
		return false
	var join_on_seam: bool = true
	if not rects.is_empty():
		var start2 := Vector2(controls[0].x, controls[0].z)
		join_on_seam = false
		for rect: Rect2 in rects:
			var nearest := Vector2(clampf(start2.x, rect.position.x, rect.end.x), clampf(start2.y, rect.position.y, rect.end.y))
			if rect.has_point(start2):
				var edge: float = minf(minf(start2.x - rect.position.x, rect.end.x - start2.x), minf(start2.y - rect.position.y, rect.end.y - start2.y))
				if edge <= 0.75: join_on_seam = true
			elif nearest.distance_to(start2) <= 0.75:
				join_on_seam = true
		if not join_on_seam:
			warnings.append("start point is not within 0.75 m of an exclusion rect edge; the join may not be flush")

	# 7. Visual embankment skirt (never collides) and optional curb (collision only).
	var ground: Callable = params.get("ground_height", Callable()) if params.get("ground_height", null) is Callable else Callable()
	var skirt_verts := PackedVector3Array()
	var skirt_uvs := PackedVector2Array()
	var skirt_colors := PackedColorArray()
	var skirt_depth_max: float = 0.0
	for i: int in count:
		for side: int in [0, 3]:
			var top: Vector3 = verts[i * 4 + side]
			var outward: Vector3 = -rights[i] if side == 0 else rights[i]
			var depth: float = skirt_min
			if ground.is_valid():
				depth = _skirt_depth(ground, top, outward, skirt_min, skirt_min, skirt_max)
				depth = _skirt_depth(ground, top, outward, depth, skirt_min, skirt_max)
			skirt_depth_max = maxf(skirt_depth_max, depth)
			skirt_verts.append(top)
			skirt_verts.append(top + outward * depth * 0.7 + Vector3(0.0, -depth, 0.0))
			var v: float = arc[i] / uv_metres
			skirt_uvs.append(Vector2(0.0 if side == 0 else 1.0, v))
			skirt_uvs.append(Vector2(0.0 if side == 0 else 1.0, v + depth / uv_metres))
			skirt_colors.append(Color(0, 0, 0))
			skirt_colors.append(Color(0, 0, 0))
	var skirt_indices := PackedInt32Array()
	var skirt_normals := PackedVector3Array()
	skirt_normals.resize(skirt_verts.size())
	for i: int in count - 1:
		for side: int in 2:
			var a: int = i * 4 + side * 2
			var b: int = a + 1
			var c: int = a + 4
			var d: int = c + 1
			var out_dir: Vector3 = -rights[i] if side == 0 else rights[i]
			for tri: Array in [[a, b, c], [b, d, c]]:
				var n: Vector3 = (skirt_verts[tri[2]] - skirt_verts[tri[0]]).cross(skirt_verts[tri[1]] - skirt_verts[tri[0]])
				if n.length() < 0.000001:
					continue
				if n.dot(out_dir) < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					n = -n
				skirt_indices.append_array(PackedInt32Array(tri))
				for index: int in tri:
					skirt_normals[index] += n
	for i: int in skirt_normals.size():
		skirt_normals[i] = skirt_normals[i].normalized() if skirt_normals[i].length() > 0.0 else Vector3.UP

	# 8. Collision faces: the exact walking-surface triangles, plus an optional side curb.
	var faces := PackedVector3Array()
	for index: int in indices:
		faces.append(verts[index])
	if curb > 0.01:
		for i: int in count - 1:
			for side: int in [0, 3]:
				var lo0: Vector3 = verts[i * 4 + side]
				var lo1: Vector3 = verts[(i + 1) * 4 + side]
				var hi0: Vector3 = lo0 + Vector3(0.0, curb, 0.0)
				var hi1: Vector3 = lo1 + Vector3(0.0, curb, 0.0)
				var out_dir: Vector3 = -rights[i] if side == 0 else rights[i]
				for tri: Array in [[lo0, hi0, lo1], [hi0, hi1, lo1]]:
					if (tri[2] - tri[0]).cross(tri[1] - tri[0]).dot(out_dir) < 0.0:
						tri = [tri[0], tri[2], tri[1]]
					faces.append_array(PackedVector3Array(tri))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)

	# 9. Commit nodes; nothing above this line has touched the scene tree.
	_p = pts
	_s = arc
	_taper = taper
	_build_chunks(half_total)
	var low: float = INF
	var high: float = -INF
	for i: int in verts.size():
		low = minf(low, verts[i].y)
		high = maxf(high, verts[i].y)
	var min_xz := Vector2(INF, INF)
	var max_xz := Vector2(-INF, -INF)
	for vertex: Vector3 in verts:
		min_xz = Vector2(minf(min_xz.x, vertex.x), minf(min_xz.y, vertex.z))
		max_xz = Vector2(maxf(max_xz.x, vertex.x), maxf(max_xz.y, vertex.z))
	_bounds = AABB(Vector3(min_xz.x, low, min_xz.y), Vector3(max_xz.x - min_xz.x, high - low, max_xz.y - min_xz.y))

	_body = StaticBody3D.new()
	_body.name = "RouteCollision"
	_body.collision_layer = _layer
	_body.collision_mask = 0
	_body.set_meta("prototype_route", true)
	var collision := CollisionShape3D.new()
	collision.name = "RouteShape"
	collision.shape = shape
	_body.add_child(collision)
	add_child(_body)

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if skirt_indices.size() > 0:
		var skirt_arrays: Array = []
		skirt_arrays.resize(Mesh.ARRAY_MAX)
		skirt_arrays[Mesh.ARRAY_VERTEX] = skirt_verts
		skirt_arrays[Mesh.ARRAY_NORMAL] = skirt_normals
		skirt_arrays[Mesh.ARRAY_TEX_UV] = skirt_uvs
		skirt_arrays[Mesh.ARRAY_COLOR] = skirt_colors
		skirt_arrays[Mesh.ARRAY_INDEX] = skirt_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, skirt_arrays)
	var material: Variant = params.get("material", null)
	_material_injected = material is Material
	if not _material_injected:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color("6b5a3c")
		fallback.roughness = 1.0
		material = fallback
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RouteSurface"
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.visible = bool(params.get("visible_mesh", true))
	add_child(_mesh_instance)

	_stats = {
		"length_m": arc[count - 1], "samples": count, "surface_triangles": indices.size() / 3,
		"collision_faces": faces.size() / 3, "tread_width": tread, "shoulder_width": _shoulder,
		"shoulder_angle_deg": shoulder_deg, "safe_half_width": _safe_half, "max_grade_deg_limit": grade_deg,
		"max_grade_deg_measured": rad_to_deg(atan(measured_grade)), "max_height_adjust_m": max_adjust,
		"min_surface_normal_y": min_normal_y, "max_surface_slope_deg": rad_to_deg(acos(min_normal_y)),
		"min_turn_radius_m": min_radius if min_radius < INF else -1.0, "winding_flips": flips,
		"exclusion_rect_count": rects.size(), "exclusion_hits": exclusion_hits, "join_on_seam": join_on_seam,
		"join_overlap_m": overlap, "curb_height": curb, "skirt_max_depth_used": skirt_depth_max,
		"ground_callable_used": ground.is_valid(), "start": pts[0], "end": pts[count - 1],
	}
	valid = true
	return true

func _num(params: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: float = fallback
	if params.has(key):
		var raw: Variant = params[key]
		if (raw is float or raw is int) and is_finite(float(raw)):
			value = float(raw)
		else:
			notes.append("%s invalid; using %s" % [key, fallback])
	var bounded: float = clampf(value, low, high)
	if bounded != value:
		notes.append("%s clamped %s -> %s" % [key, value, bounded])
	return bounded

# Skirt depth that reaches the supplied ground beneath the outward embankment toe.
func _skirt_depth(ground: Callable, top: Vector3, outward: Vector3, guess: float, low: float, high: float) -> float:
	var toe: Vector3 = top + outward * guess * 0.7
	var result: Variant = ground.call(toe.x, toe.z)
	if not (result is float or result is int) or not is_finite(float(result)):
		return low
	return clampf(top.y - float(result) + 0.4, low, high)

func _build_chunks(half_total: float) -> void:
	_chunk_rects = []
	_chunk_first = PackedInt32Array()
	var last: int = _p.size() - 1
	var first: int = 0
	while first < last:
		var stop: int = mini(first + CHUNK_SEGMENTS, last)
		var rect := Rect2(Vector2(_p[first].x, _p[first].z), Vector2.ZERO)
		for i: int in range(first, stop + 1):
			rect = rect.expand(Vector2(_p[i].x, _p[i].z))
		_chunk_rects.append(rect.grow(half_total + 0.5))
		_chunk_first.append(first)
		first = stop

# --- Queries (valid only after configure() returned true) ---

# Finds the nearest centreline segment in XZ and stores it in _q_*. Returns false off-route.
func _locate(x: float, z: float, reach: float) -> bool:
	var found: bool = false
	var best: float = INF
	var here := Vector2(x, z)
	var last: int = _p.size() - 1
	for c: int in _chunk_rects.size():
		if not _chunk_rects[c].grow(reach).has_point(here):
			continue
		var from: int = _chunk_first[c]
		var to: int = mini(from + CHUNK_SEGMENTS, last)
		for i: int in range(from, to):
			var a := Vector2(_p[i].x, _p[i].z)
			var ab := Vector2(_p[i + 1].x, _p[i + 1].z) - a
			var length2: float = ab.length_squared()
			if length2 < 0.000001:
				continue
			var raw_t: float = (here - a).dot(ab) / length2
			var t: float = clampf(raw_t, 0.0, 1.0)
			var d: float = here.distance_to(a + ab * t)
			if d < best:
				best = d
				found = true
				_q_index = i
				_q_t = t
				_q_lateral = d
				var length: float = sqrt(length2)
				_q_over = 0.0
				if i == 0 and raw_t < 0.0: _q_over = -raw_t * length
				elif i == last - 1 and raw_t > 1.0: _q_over = (raw_t - 1.0) * length
	return found and best <= _tread_half + _shoulder + reach

func _surface_y() -> float:
	var y: float = lerpf(_p[_q_index].y, _p[_q_index + 1].y, _q_t)
	var taper: float = lerpf(_taper[_q_index], _taper[_q_index + 1], _q_t)
	return y - maxf(_q_lateral - _tread_half, 0.0) * _shoulder_tan * taper

## Surface height of the ribbon at (x, z), or NAN when the point is off the walking surface.
func surface_height_at(x: float, z: float) -> float:
	if not valid or not _locate(x, z, 0.0) or _q_over > 0.0 or _q_lateral > _tread_half + _shoulder:
		return NAN
	return _surface_y()

## True when `point` is inside the SAFE corridor (tread + shoulders minus safe_inset, widened
## by `margin`) and within [surface - corridor_below, surface + corridor_above]. Does not
## include the original clearing; combine with the existing rule using OR. Pure query.
func is_in_corridor(point: Vector3, margin: float = 0.0) -> bool:
	if not valid or not point.is_finite():
		return false
	var m: float = clampf(margin, -1.0, 2.0)
	if not _locate(point.x, point.z, 0.0) or _q_over > END_OVERSHOOT or _q_lateral > _safe_half + m:
		return false
	var y: float = _surface_y()
	return point.y >= y - _below and point.y <= y + _above

## Nearest point whose XZ lies inside the safe corridor (y untouched). Returns `point`
## unchanged when it is already inside or too far from the route to associate with it
## (reach 6 m beyond the full width). For selective clamping only; never teleports.
func clamp_to_corridor(point: Vector3, margin: float = 0.0) -> Vector3:
	if not valid or not point.is_finite() or not _locate(point.x, point.z, 6.0):
		return point
	var limit: float = _safe_half + clampf(margin, -1.0, 2.0)
	var a := Vector2(_p[_q_index].x, _p[_q_index].z)
	var b := Vector2(_p[_q_index + 1].x, _p[_q_index + 1].z)
	var on_line: Vector2 = a.lerp(b, _q_t)
	var here := Vector2(point.x, point.z)
	if _q_lateral <= limit or _q_lateral < 0.0001:
		return point
	var inside: Vector2 = on_line + (here - on_line).normalized() * limit
	return Vector3(inside.x, point.y, inside.y)

## Coarse AABB cover of the safe corridor (about `max_span` m of route per box), for owners
## that only support AABB zones. Over-approximates diagonal runs; prefer is_in_corridor().
func get_corridor_aabbs(max_span: float = 10.0) -> Array[AABB]:
	var boxes: Array[AABB] = []
	if not valid:
		return boxes
	var span: float = clampf(max_span, 2.0, 40.0)
	var first: int = 0
	var last: int = _p.size() - 1
	while first < last:
		var stop: int = first + 1
		while stop < last and _s[stop] - _s[first] < span:
			stop += 1
		var low: float = INF
		var high: float = -INF
		var rect := Rect2(Vector2(_p[first].x, _p[first].z), Vector2.ZERO)
		for i: int in range(first, stop + 1):
			rect = rect.expand(Vector2(_p[i].x, _p[i].z))
			low = minf(low, _p[i].y)
			high = maxf(high, _p[i].y)
		rect = rect.grow(_safe_half)
		var floor_y: float = low - _shoulder * _shoulder_tan - _below
		boxes.append(AABB(Vector3(rect.position.x, floor_y, rect.position.y), Vector3(rect.size.x, high + _above - floor_y, rect.size.y)))
		first = stop
	return boxes

func get_bounds() -> AABB:
	return _bounds

func get_start_point() -> Vector3:
	return _p[0] if valid else Vector3.ZERO

func get_end_point() -> Vector3:
	return _p[_p.size() - 1] if valid else Vector3.ZERO

## Horizontal unit direction of travel at the end of the route (the scenic rim heading).
func get_end_direction() -> Vector3:
	if not valid:
		return Vector3.ZERO
	var a: Vector3 = _p[_p.size() - 2]
	var b: Vector3 = _p[_p.size() - 1]
	return Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()

## Reversible: hides the mesh and removes the body from every layer; geometry stays built.
func set_active(active: bool) -> void:
	if _body == null:
		return
	_body.collision_layer = _layer if active else 0
	_mesh_instance.visible = active

func get_report() -> Dictionary:
	var report: Dictionary = _stats.duplicate()
	report["passed"] = valid and errors.is_empty() and int(_stats.get("winding_flips", 1)) == 0
	report["valid"] = valid
	report["errors"] = errors
	report["warnings"] = warnings
	report["notes"] = notes
	report["colliders"] = find_children("*", "CollisionObject3D", true, false).size()
	report["collision_layer"] = _layer
	report["collision_mask"] = 0
	report["material_injected"] = _material_injected
	report["bounds"] = _bounds
	report["identity_transform"] = (not is_inside_tree()) or global_transform == Transform3D.IDENTITY
	report["built_at_startup_only"] = true
	report["runtime_tested"] = false
	report["scope"] = "Single natural walking ribbon with its own collider; far scenery stays collider-free."
	return report
