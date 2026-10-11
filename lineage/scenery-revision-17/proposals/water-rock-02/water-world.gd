extends "res://lineage/scenery-revision-17/proposals/water-rock-01/water-world.gd"

const WATER_ROCK02_FALL_SHADER: Shader = preload("res://lineage/scenery-revision-17/proposals/water-rock-02/falling-water-02.gdshader")

func _create_stream() -> void:
	super._create_stream()
	# Keep01 stream shader and the same fall-owned appearance resource.
	_fall_material.shader = WATER_ROCK02_FALL_SHADER

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
	var widths: PackedFloat64Array = PackedFloat64Array([0.55,0.70,0.84,0.91,0.96,0.99,1.0,0.93,0.82,0.63])
	var rings: Array[PackedVector3Array] = []
	var half_size: Vector3 = full_size * 0.5
	for band: int in range(levels.size()):
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in range(outline.size()):
			var side_phase: float = phase + float(i) * 1.37
			var width: float = minf(1.0, widths[band] * (1.0 + 0.028 * sin(side_phase + float(band) * 0.81)))
			var theta: float = TAU * float(i) / float(outline.size())
			var top_height: float = 0.82 + 0.12 * sin(theta + phase * 0.53) + 0.06 * sin(theta * 3.0 + phase)
			var tilt: float = 0.19 * sin(theta + phase * 0.47) + 0.06 * sin(theta * 3.0 - phase * 0.31)
			# A monotone vertical map slants every shoulder; no continuous recessed belt.
			var y: float = -1.0 + (levels[band] + 1.0) * 0.5 * (top_height + 1.0) + tilt * (1.0 - levels[band] * levels[band])
			ring.append(Vector3(outline[i].x * width * half_size.x, y * half_size.y, outline[i].y * width * half_size.z))
		rings.append(ring)
	for band: int in range(rings.size() - 1):
		var shade: float = 0.91 + 0.035 * sin(phase * 0.7 + float(band) * 0.37)
		for i: int in range(outline.size()):
			var next: int = (i + 1) % outline.size()
			var tint: float = shade * (0.97 + 0.03 * sin(phase + float(i) * 1.09))
			_quad(vertices,normals,uvs,colors,rings[band][i],rings[band + 1][i],rings[band + 1][next],rings[band][next],Color(tint,tint,tint),Vector2(float(i) / 16.0,levels[band]),Vector2(float(i) / 16.0,levels[band + 1]),Vector2(float(i + 1) / 16.0,levels[band + 1]),Vector2(float(i + 1) / 16.0,levels[band]))
	var top: PackedVector3Array = rings[rings.size() - 1]
	var bottom: PackedVector3Array = rings[0]
	for i: int in range(outline.size()):
		var next: int = (i + 1) % outline.size()
		_triangle(vertices,normals,uvs,colors,Vector3(0,half_size.y * (0.81 + 0.035 * sin(phase)),0),top[next],top[i],Color(0.96,0.97,0.93),Vector2.ZERO,Vector2(top[next].x,top[next].z),Vector2(top[i].x,top[i].z))
		_triangle(vertices,normals,uvs,colors,Vector3(0,-half_size.y,0),bottom[i],bottom[next],Color(0.76,0.77,0.74),Vector2.ZERO,Vector2(bottom[i].x,bottom[i].z),Vector2(bottom[next].x,bottom[next].z))
	return _array_mesh(vertices,normals,uvs,colors)

