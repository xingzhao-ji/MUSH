extends "res://lineage/scenery-revision-17/proposals/gill-material-02/material-world.gd"

const WATER_ROCK_STREAM_SHADER: Shader = preload("res://lineage/scenery-revision-17/proposals/water-rock-01/stream-water-01.gdshader")
const WATER_ROCK_FALL_SHADER: Shader = preload("res://lineage/scenery-revision-17/proposals/water-rock-01/falling-water-01.gdshader")

func _create_stream() -> void:
	super._create_stream()
	# The same two stream-owned resources remain the appearance targets.
	_water_material.shader = WATER_ROCK_STREAM_SHADER
	_fall_material.shader = WATER_ROCK_FALL_SHADER

func _waterfall_shelf_mesh(full_size: Vector3, phase: float) -> ArrayMesh:
	if full_size.y < 0.10:
		return super._waterfall_shelf_mesh(full_size, phase)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var corners: PackedVector2Array = PackedVector2Array([Vector2(-0.75,-1.0),Vector2(0.52,-1.0),Vector2(1.0,-0.65),Vector2(1.0,0.50),Vector2(0.68,1.0),Vector2(-0.60,1.0),Vector2(-1.0,0.60),Vector2(-1.0,-0.55)])
	var outline: PackedVector2Array = PackedVector2Array()
	for i: int in range(corners.size()):
		outline.append(corners[i])
		outline.append(corners[i].lerp(corners[(i + 1) % corners.size()], 0.5) * (0.955 + 0.018 * sin(phase + float(i) * 1.43)))
	var levels: PackedFloat64Array = PackedFloat64Array([-1.0,-0.87,-0.57,-0.36,-0.14,0.17,0.39,0.64,0.84,1.0])
	var widths: PackedFloat64Array = PackedFloat64Array([0.59,0.77,0.94,0.98,0.87,1.0,0.97,0.90,0.81,0.67])
	var rings: Array[PackedVector3Array] = []
	var half_size: Vector3 = full_size * 0.5
	for band: int in range(levels.size()):
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in range(outline.size()):
			var side_phase: float = phase + float(i) * 1.37
			var width: float = minf(1.0, widths[band] * (1.0 + 0.028 * sin(side_phase + float(band) * 0.81)))
			var y: float = levels[band] + 0.016 * sin(side_phase * 0.83 + float(band)) * (1.0 - absf(levels[band]))
			if band == levels.size() - 1:
				y = 0.965 + 0.035 * sin(side_phase)
			ring.append(Vector3(outline[i].x * width * half_size.x, y * half_size.y, outline[i].y * width * half_size.z))
		rings.append(ring)
	for band: int in range(rings.size() - 1):
		var shade: float = 0.73 if band == 3 else (0.83 if band == 5 else 0.94)
		for i: int in range(outline.size()):
			var next: int = (i + 1) % outline.size()
			var tint: float = shade * (0.97 + 0.03 * sin(phase + float(i) * 1.09))
			_quad(vertices,normals,uvs,colors,rings[band][i],rings[band + 1][i],rings[band + 1][next],rings[band][next],Color(tint,tint,tint),Vector2(float(i) / 16.0,levels[band]),Vector2(float(i) / 16.0,levels[band + 1]),Vector2(float(i + 1) / 16.0,levels[band + 1]),Vector2(float(i + 1) / 16.0,levels[band]))
	var top: PackedVector3Array = rings[rings.size() - 1]
	var bottom: PackedVector3Array = rings[0]
	for i: int in range(outline.size()):
		var next: int = (i + 1) % outline.size()
		_triangle(vertices,normals,uvs,colors,Vector3(0,half_size.y * 0.90,0),top[next],top[i],Color(0.96,0.97,0.93),Vector2.ZERO,Vector2(top[next].x,top[next].z),Vector2(top[i].x,top[i].z))
		_triangle(vertices,normals,uvs,colors,Vector3(0,-half_size.y,0),bottom[i],bottom[next],Color(0.76,0.77,0.74),Vector2.ZERO,Vector2(bottom[i].x,bottom[i].z),Vector2(bottom[next].x,bottom[next].z))
	return _array_mesh(vertices,normals,uvs,colors)

func _create_waterfall_shelves_and_cascade(parent: Node3D) -> void:
	# Super retains all eleven original shelf transforms and exactly88 legacy RNG calls.
	super._create_waterfall_shelves_and_cascade(parent)
	var shelf_names: PackedStringArray = PackedStringArray(["LeftMiddleShelf","RightHeadShelf","RightMiddleShelf"])
	var sizes: PackedVector2Array = PackedVector2Array([Vector2(2.2,1.4),Vector2(2.0,1.4),Vector2(2.4,1.5)])
	for i: int in range(3):
		var shelf: MeshInstance3D = parent.get_node(shelf_names[i]) as MeshInstance3D
		var moss: MeshInstance3D = parent.get_node("BrokenShelfMoss%d" % i) as MeshInstance3D
		moss.mesh = _water_rock_rooted_moss(shelf,moss,sizes[i],float(i) * 1.91)

func _water_rock_clip_polygon(polygon: Array[Vector3], a: Vector2, b: Vector2) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if polygon.is_empty():
		return result
	var edge: Vector2 = b - a
	var previous: Vector3 = polygon[polygon.size() - 1]
	var previous_distance: float = edge.cross(Vector2(previous.x,previous.z) - a)
	for point: Vector3 in polygon:
		var distance: float = edge.cross(Vector2(point.x,point.z) - a)
		var inside: bool = distance >= 0.0
		var previous_inside: bool = previous_distance >= 0.0
		if inside != previous_inside:
			var ratio: float = previous_distance / (previous_distance - distance)
			var hit: Vector3 = previous.lerp(point,ratio)
			if result.is_empty() or result[result.size() - 1].distance_squared_to(hit) > 0.000000000001:
				result.append(hit)
		if inside and (result.is_empty() or result[result.size() - 1].distance_squared_to(point) > 0.000000000001):
			result.append(point)
		previous = point
		previous_distance = distance
	if result.size() > 1 and result[0].distance_squared_to(result[result.size() - 1]) <= 0.000000000001:
		result.remove_at(result.size() - 1)
	return result

func _water_rock_rooted_moss(shelf: MeshInstance3D, moss: MeshInstance3D, full_size: Vector2, phase: float) -> Mesh:
	var arrays: Array = shelf.mesh.surface_get_arrays(0)
	var triangles: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var shelf_inverse: Transform3D = shelf.transform.affine_inverse()
	var moss_inverse: Transform3D = moss.transform.affine_inverse()
	var outline: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var theta: float = TAU * float(i) / 24.0
		# A small unequal oval remains convex; triangle clipping keeps its true shelf plane.
		var lobe: float = 0.91 + 0.023 * sin(theta * 3.0 + phase)
		var point: Vector3 = shelf_inverse * (moss.transform * Vector3(cos(theta) * full_size.x * 0.36 * lobe,0.0,sin(theta) * full_size.y * 0.36 * lobe))
		outline.append(Vector2(point.x,point.z))
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	# The320-face shelf has288 side faces, then16 interleaved top/bottom fan pairs.
	for i: int in range(16):
		var index: int = (288 + i * 2) * 3
		var polygon: Array[Vector3] = [triangles[index],triangles[index + 1],triangles[index + 2]]
		for edge_index: int in range(outline.size()):
			polygon = _water_rock_clip_polygon(polygon,outline[edge_index],outline[(edge_index + 1) % outline.size()])
			if polygon.size() < 3:
				break
		for j: int in range(1,polygon.size() - 1):
			var a: Vector3 = moss_inverse * (shelf.transform * (polygon[0] + Vector3.UP * 0.003))
			var b: Vector3 = moss_inverse * (shelf.transform * (polygon[j] + Vector3.UP * 0.003))
			var c: Vector3 = moss_inverse * (shelf.transform * (polygon[j + 1] + Vector3.UP * 0.003))
			if (c - a).cross(b - a).length_squared() <= 0.000000000001:
				continue
			_triangle(vertices,normals,uvs,colors,a,c,b,Color(0.91,0.98,0.86),Vector2(a.x,a.z),Vector2(c.x,c.z),Vector2(b.x,b.z))
	if vertices.is_empty():
		push_error("Review17 rooted waterfall moss has no clipped shelf faces")
		return moss.mesh
	return _array_mesh(vertices,normals,uvs,colors)

func _water_rock_sheet_point(points: PackedVector3Array, widths: PackedFloat64Array, row: int, across: int, phase: float) -> Vector3:
	var along: float = float(row) / 24.0
	var segment: int = mini(2,int(floor(along * 3.0)))
	var t: float = along * 3.0 - float(segment)
	var center: Vector3 = points[segment].lerp(points[segment + 1],t)
	var s: float = float(across) / 8.0
	var width: float = lerpf(widths[segment],widths[segment + 1],t)
	center.x += (s - 0.5) * width * (1.0 + sin(along * 8.3 + phase) * 0.028)
	center.z += sin(t * PI) * 0.045 + sin(s * PI) * sin(along * 18.0 + phase) * 0.035
	return center

func _water_rock_append_sheet(points: PackedVector3Array, widths: PackedFloat64Array, phase: float, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray) -> void:
	for row: int in range(24):
		for across: int in range(8):
			var a: Vector3 = _water_rock_sheet_point(points,widths,row,across,phase)
			var b: Vector3 = _water_rock_sheet_point(points,widths,row + 1,across,phase)
			var c: Vector3 = _water_rock_sheet_point(points,widths,row + 1,across + 1,phase)
			var d: Vector3 = _water_rock_sheet_point(points,widths,row,across + 1,phase)
			var foam: float = smoothstep(0.78,1.0,float(row) / 24.0) * 0.70
			_quad(vertices,normals,uvs,colors,a,b,c,d,Color(foam,1.0,1.0,1.0),Vector2(float(across) / 8.0,(5.35 - a.y) / 5.45),Vector2(float(across) / 8.0,(5.35 - b.y) / 5.45),Vector2(float(across + 1) / 8.0,(5.35 - c.y) / 5.45),Vector2(float(across + 1) / 8.0,(5.35 - d.y) / 5.45))

func _water_rock_foam_mesh(center: Vector3, radii: Vector2, phase: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for arc: int in range(3):
		var radius: float = 0.38 + float(arc) * 0.23
		for i: int in range(24):
			var a: float = -0.16 + float(i) * 1.23 * PI / 24.0 + phase
			var b: float = -0.16 + float(i + 1) * 1.23 * PI / 24.0 + phase
			var inner: float = radius - 0.055
			var outer: float = radius + 0.055
			var pa: Vector3 = center + Vector3(cos(a) * radii.x,sin(a * 3.0 + phase) * 0.008,sin(a) * radii.y)
			var pb: Vector3 = center + Vector3(cos(b) * radii.x,sin(b * 3.0 + phase) * 0.008,sin(b) * radii.y)
			var va: Vector3 = pa - center
			var vb: Vector3 = pb - center
			_quad(vertices,normals,uvs,colors,center + va * inner,center + vb * inner,center + vb * outer,center + va * outer,Color(1.0,1.0,1.0,1.0),Vector2(0.0,float(i) / 24.0),Vector2(0.0,float(i + 1) / 24.0),Vector2(1.0,float(i + 1) / 24.0),Vector2(1.0,float(i) / 24.0))
	return _array_mesh(vertices,normals,uvs,colors)

func _create_staged_waterfall_mesh(parent: Node3D) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	_water_rock_append_sheet(PackedVector3Array([Vector3(8.05,5.35,-22.16),Vector3(8.10,4.90,-21.98),Vector3(8.17,3.90,-21.57),Vector3(8.20,3.24,-21.19)]),PackedFloat64Array([1.10,1.20,1.18,1.30]),0.0,vertices,normals,uvs,colors)
	_water_rock_append_sheet(PackedVector3Array([Vector3(9.65,5.20,-22.19),Vector3(9.62,4.75,-21.96),Vector3(9.69,3.90,-21.56),Vector3(9.70,3.24,-21.19)]),PackedFloat64Array([1.45,1.35,1.42,1.40]),1.7,vertices,normals,uvs,colors)
	_water_rock_append_sheet(PackedVector3Array([Vector3(8.02,3.10,-20.79),Vector3(8.11,2.40,-20.54),Vector3(8.21,1.0,-19.94),Vector3(8.25,-0.10,-19.2)]),PackedFloat64Array([0.82,0.79,0.66,0.66]),2.9,vertices,normals,uvs,colors)
	_water_rock_append_sheet(PackedVector3Array([Vector3(9.0,3.10,-20.80),Vector3(8.95,2.30,-20.53),Vector3(9.05,1.05,-19.95),Vector3(9.0,-0.10,-19.2)]),PackedFloat64Array([1.08,0.97,1.04,0.92]),4.1,vertices,normals,uvs,colors)
	_water_rock_append_sheet(PackedVector3Array([Vector3(9.96,3.10,-20.79),Vector3(9.91,2.50,-20.56),Vector3(9.75,1.0,-19.94),Vector3(9.77,-0.10,-19.2)]),PackedFloat64Array([0.74,0.76,0.72,0.66]),5.3,vertices,normals,uvs,colors)
	for row: int in range(4):
		for across: int in range(8):
			var a: Vector3 = Vector3(lerpf(7.55,10.40,float(across) / 8.0),lerpf(3.235,3.15,float(row) / 4.0),lerpf(-21.19,-20.78,float(row) / 4.0))
			var b: Vector3 = Vector3(lerpf(7.55,10.40,float(across) / 8.0),lerpf(3.235,3.15,float(row + 1) / 4.0),lerpf(-21.19,-20.78,float(row + 1) / 4.0))
			var c: Vector3 = b + Vector3(2.85 / 8.0,0,0)
			var d: Vector3 = a + Vector3(2.85 / 8.0,0,0)
			_quad(vertices,normals,uvs,colors,a,b,c,d,Color(0.55,1.0,1.0,1.0),Vector2(float(across) / 8.0,0.388 + float(row) * 0.004),Vector2(float(across) / 8.0,0.388 + float(row + 1) * 0.004),Vector2(float(across + 1) / 8.0,0.388 + float(row + 1) * 0.004),Vector2(float(across + 1) / 8.0,0.388 + float(row) * 0.004))
	var waterfall: MeshInstance3D = _instance(_array_mesh(vertices,normals,uvs,colors),_fall_material,parent)
	waterfall.name = "SteppedShelfCascade"
	waterfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var centers: PackedVector3Array = PackedVector3Array([Vector3(8.17,3.249,-21.08),Vector3(9.67,3.249,-21.08),Vector3(8.52,-0.119,-19.03),Vector3(9.55,-0.119,-19.03)])
	for i: int in range(4):
		var foam: MeshInstance3D = _instance(_water_rock_foam_mesh(centers[i],Vector2(0.57,0.22),float(i) * 0.91),_fall_material,parent)
		foam.name = "BrokenCascadeFoam"
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
