extends RefCounted

# Standalone original mesh proposal, not a World override or bake loader.
# Four resources only. All dimensions are tunable, unapproved local metres.
func build_meshes() -> Dictionary:
	var result: Dictionary = {}
	for variant: int in range(2):
		var suffix: String = "a" if variant == 0 else "b"
		for broad: bool in [false, true]:
			var label: String = ("broadleaf_" if broad else "cushion_") + suffix
			var mesh: ArrayMesh = _make_clump(variant, broad)
			mesh.resource_name = "Review18Clump_" + label
			mesh.set_meta("review18_proposal_label", label)
			result[label] = mesh
	return result

func _make_clump(variant: int, broad: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var axes: int = 3 if broad else 2
	var count: int = (12 + variant) if broad else (9 + variant)
	var stem_paths: Array[PackedVector3Array] = []
	for axis: int in range(axes):
		var angle: float = -0.68 + float(axis) * 1.81 + float(variant) * 0.47
		var radial: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		var reach: float = (0.049 + 0.008 * float(axis)) if broad else (0.023 + 0.009 * float(axis))
		var height_value: float = (0.122 + 0.018 * sin(float(axis) * 1.73 + float(variant) * 0.9)) if broad else (0.082 + 0.015 * sin(float(axis) * 1.73 + float(variant) * 0.9))
		var path: PackedVector3Array = PackedVector3Array([Vector3.ZERO, radial * reach * 0.31 + Vector3.UP * height_value * 0.54, radial * reach + Vector3.UP * height_value])
		stem_paths.append(path)
		_append_stem(vertices, normals, uvs, colors, path, 0.0032 if broad else 0.0024, 0.0014 if broad else 0.0011)
	for index: int in range(count):
		var axis: int = index % axes
		var level: int = int(index / axes)
		var axis_count: int = int(ceil(float(count - axis) / float(axes)))
		var fraction: float = lerpf(0.24, 0.82, float(level) / float(maxi(1, axis_count - 1)))
		var path: PackedVector3Array = stem_paths[axis]
		var start: Vector3 = _bezier(path[0], path[1], path[2], fraction)
		var phase: float = float(index) * 1.57 + float(variant) * 0.91
		var side_value: float = -1.0 if level % 2 == 0 else 1.0
		var angle: float = -0.68 + float(axis) * 1.81 + float(variant) * 0.47 + side_value * (1.08 + 0.22 * sin(phase))
		var radial: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		var lateral: Vector3 = Vector3(cos(angle), 0.0, -sin(angle))
		var length_value: float = (0.101 + 0.020 * sin(phase + 0.4)) if broad else (0.059 + 0.012 * sin(phase + 0.4))
		var width: float = (0.045 + 0.008 * cos(phase)) if broad else (0.027 + 0.004 * cos(phase))
		var control: Vector3 = start + radial * length_value * 0.42 + lateral * length_value * 0.10 * sin(phase) + Vector3.UP * (0.066 if broad else 0.042)
		var finish: Vector3 = start + radial * length_value + lateral * length_value * 0.08 * sin(phase * 1.3) + Vector3.UP * (0.023 + 0.008 * cos(phase) if broad else 0.014 + 0.005 * cos(phase))
		var tint: Color = Color(0.72, 0.86, 0.68).lerp(Color(0.98, 1.0, 0.90), 0.5 + 0.5 * sin(phase + 0.8))
		_append_leaf(vertices, normals, uvs, colors, start, control, finish, width, 0.13 * sin(phase * 0.8), tint)
	_smooth_normals(vertices, normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _bezier(start: Vector3, control: Vector3, finish: Vector3, t: float) -> Vector3:
	return start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t

func _append_stem(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, path: PackedVector3Array, start_radius: float, end_radius: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for index: int in range(3):
		var direction: Vector3 = (path[mini(2, index + 1)] - path[maxi(0, index - 1)]).normalized()
		var side: Vector3 = direction.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		var other: Vector3 = side.cross(direction).normalized()
		var radius: float = lerpf(start_radius, end_radius, float(index) * 0.5)
		var ring: PackedVector3Array = PackedVector3Array()
		for corner: int in range(4):
			var angle: float = TAU * float(corner) / 4.0
			var offset: Vector3 = (side * cos(angle) + other * sin(angle)) * radius
			if index == 0:
				offset.y = 0.0
			ring.append(path[index] + offset)
		rings.append(ring)
	for row: int in range(2):
		for corner: int in range(4):
			var next: int = (corner + 1) % 4
			_quad(vertices, normals, uvs, colors, rings[row][corner], rings[row + 1][corner], rings[row + 1][next], rings[row][next], Color(0.61, 0.74, 0.53), Vector2(float(corner) / 4.0, float(row) * 0.5), Vector2(float(corner) / 4.0, float(row + 1) * 0.5), Vector2(float(corner + 1) / 4.0, float(row + 1) * 0.5), Vector2(float(corner + 1) / 4.0, float(row) * 0.5))

func _append_leaf(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, control: Vector3, finish: Vector3, width: float, twist: float, tint: Color) -> void:
	var times: PackedFloat64Array = PackedFloat64Array([0.0, 0.23, 0.55, 0.85, 1.0])
	var centers: PackedVector3Array = PackedVector3Array()
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	for t: float in times:
		var center: Vector3 = _bezier(start, control, finish, t)
		var tangent: Vector3 = ((control - start) * (2.0 * (1.0 - t)) + (finish - control) * (2.0 * t)).normalized()
		var side: Vector3 = Vector3(tangent.z, 0.0, -tangent.x).normalized().rotated(tangent, twist * sin(t * PI))
		var up: Vector3 = tangent.cross(side).normalized()
		var shape: float = pow(maxf(0.0, sin(t * PI)), 0.60) if t < 1.0 else 0.0
		var curl: float = width * 0.16 * pow(clampf((t - 0.64) / 0.36, 0.0, 1.0), 2.0)
		center += up * curl
		var wl: float = width * shape * (0.94 + 0.08 * sin(t * PI * 1.4))
		var wr: float = width * shape * (0.80 + 0.11 * sin(t * PI * 1.6 + 0.6))
		centers.append(center + up * width * shape * 0.02)
		left.append(center + side * wl + up * wl * 0.20)
		right.append(center - side * wr + up * wr * 0.25)
	for row: int in range(4):
		var a: Vector3 = centers[row]
		var b: Vector3 = centers[row + 1]
		var ua: Vector2 = Vector2(0.5, float(times[row]))
		var ub: Vector2 = Vector2(0.5, float(times[row + 1]))
		var lb: Vector3 = left[row + 1]
		var ra: Vector3 = right[row]
		var rb: Vector3 = right[row + 1]
		var shade: float = 0.77 + 0.23 * float(times[row])
		var color_value: Color = tint * Color(shade, shade, shade, 1.0)
		if row == 0:
			_triangle(vertices, normals, uvs, colors, a, b, lb, color_value, ua, ub, Vector2(0.0, float(times[row + 1])))
			_triangle(vertices, normals, uvs, colors, rb, b, a, color_value, Vector2(1.0, float(times[row + 1])), ub, ua)
		elif row == 3:
			_triangle(vertices, normals, uvs, colors, a, b, left[row], color_value, ua, ub, Vector2(0.0, float(times[row])))
			_triangle(vertices, normals, uvs, colors, ra, b, a, color_value, Vector2(1.0, float(times[row])), ub, ua)
		else:
			_quad(vertices, normals, uvs, colors, a, b, lb, left[row], color_value, ua, ub, Vector2(0.0, float(times[row + 1])), Vector2(0.0, float(times[row])))
			_quad(vertices, normals, uvs, colors, ra, rb, b, a, color_value * Color(0.97, 0.99, 0.94), Vector2(1.0, float(times[row])), Vector2(1.0, float(times[row + 1])), ub, ua)

func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, tint: Color, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	vertices.append_array(PackedVector3Array([a, c, b]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uvs.append_array(PackedVector2Array([ua, uc, ub]))
	colors.append_array(PackedColorArray([tint, tint, tint]))

func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_triangle(vertices, normals, uvs, colors, a, b, c, tint, ua, ub, uc)
	_triangle(vertices, normals, uvs, colors, a, c, d, tint, ua, uc, ud)

func _smooth_normals(vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	var sums: Dictionary = {}
	for index: int in range(0, vertices.size(), 3):
		var face: Vector3 = (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
		for corner: int in range(3):
			var point: Vector3 = vertices[index + corner]
			sums[point] = (sums.get(point, Vector3.ZERO) as Vector3) + face
	for index: int in range(vertices.size()):
		var sum: Vector3 = sums[vertices[index]] as Vector3
		if sum.length_squared() > 0.000000000000000001:
			normals[index] = sum.normalized()
