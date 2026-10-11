extends "res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"
## Offline mesh only. Retains the stock 94-triangle budget and root plane.
func make_flower() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var stalk := PackedVector3Array([Vector3.ZERO, Vector3(-.014,.085,.006), Vector3(-.009,.18,-.008), Vector3(.024,.265,-.012)])
	for segment: int in range(3):
		var a: Vector3 = stalk[segment]
		var b: Vector3 = stalk[segment+1]
		var wa: float = .0045 - float(segment)*.0006
		var wb: float = wa-.0006
		for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
			_quad(vertices,normals,uvs,colors,a-axis*wa,b-axis*wb,b+axis*wb,a+axis*wa,Color(.25,.49,.22))
	var starts := PackedVector3Array([stalk[1].lerp(stalk[2],.37),stalk[1].lerp(stalk[2],.52),stalk[1].lerp(stalk[2],.68)])
	var ends := PackedVector3Array([Vector3(.105,.14,.023),Vector3(-.060,.18,.07),Vector3(.022,.19,-.10)])
	for leaf: int in range(3):
		_flower_leaf(vertices,normals,uvs,colors,starts[leaf],ends[leaf],.035,Color(.35,.64,.26))
	var center: Vector3 = stalk[3]
	for petal: int in range(6):
		var angle: float = TAU*float(petal)/6.0
		var radial := Vector3(sin(angle),0,cos(angle))
		var radius: float = .074*(1.0+.06*sin(float(petal)*2.31))
		_flower_leaf(vertices,normals,uvs,colors,center+radial*.012,center+radial*radius+Vector3(0,.009+.007*sin(angle+.8),0),.028,Color.WHITE)
	for index: int in range(10):
		var a: float = TAU*float(index)/10.0
		var b: float = TAU*float(index+1)/10.0
		_triangle(vertices,normals,uvs,colors,center+Vector3(0,.016,0),center+Vector3(sin(a)*.022,.008,cos(a)*.022),center+Vector3(sin(b)*.022,.008,cos(b)*.022),Color(.95,.71,.17))
	return _array_mesh(vertices,normals,uvs,colors)

func _flower_leaf(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, start: Vector3, finish: Vector3, width: float, color_value: Color) -> void:
	var direction: Vector3 = finish - start
	var side: Vector3 = Vector3(-direction.z, 0, direction.x).normalized() * width
	if side.length_squared() < 1e-12:
		side = Vector3.RIGHT * width
	var middle: Vector3 = start.lerp(finish, 0.47) + Vector3(0, width * 0.16, 0)
	var quarter: Vector3 = start.lerp(finish, 0.24)
	var three_quarter: Vector3 = start.lerp(finish, 0.78)
	_triangle(vertices, normals, uvs, colors, start, quarter + side * 0.65, middle, color_value)
	_triangle(vertices, normals, uvs, colors, quarter + side * 0.65, middle + side, middle, color_value)
	_triangle(vertices, normals, uvs, colors, middle + side, three_quarter + side * 0.60, middle, color_value)
	_triangle(vertices, normals, uvs, colors, three_quarter + side * 0.60, finish, middle, color_value)
	_triangle(vertices, normals, uvs, colors, start, middle, quarter - side * 0.65, color_value * Color(0.93, 0.98, 0.90))
	_triangle(vertices, normals, uvs, colors, quarter - side * 0.65, middle, middle - side, color_value * Color(0.93, 0.98, 0.90))
	_triangle(vertices, normals, uvs, colors, middle - side, middle, three_quarter - side * 0.60, color_value)
	_triangle(vertices, normals, uvs, colors, three_quarter - side * 0.60, middle, finish, color_value)
