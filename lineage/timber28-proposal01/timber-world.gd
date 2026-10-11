extends "res://lineage/cap-material27-preview01/material-world.gd"
# Detached provisional timber form trial. No World Ready, ground, shader or shared helper override.
var _timber28: Dictionary = {"schema":"mush-timber28-visual-proposal/1","status":"pending","errors":[],"targets":[],"scope":"19 existing balcony timber meshes only. Original deck/caps/flora/door/allcolliders/materialregistry/camera untouched. No native scope or art approval claim."}
var _timber28_added_triangles: int = 0

func get_timber28_report() -> Dictionary:
	return _timber28.duplicate(true)

func _create_balcony(parent: Node3D) -> void:
	var before_rng: int = _rng.state
	var y: float = 3.25
	var begin: float = -0.72
	var finish: float = 1.44
	for i: int in range(36):
		var a: float = lerpf(begin, finish, float(i) / 36.0)
		var b: float = lerpf(begin, finish, float(i + 1) / 36.0)
		var vertices: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		var colors: PackedColorArray = PackedColorArray()
		var pa: Vector3 = Vector3(sin(a) * 2.68, y, cos(a) * 2.68)
		var pb: Vector3 = Vector3(sin(b) * 2.68, y, cos(b) * 2.68)
		var pc: Vector3 = Vector3(sin(b) * 4.25, y, cos(b) * 4.25)
		var pd: Vector3 = Vector3(sin(a) * 4.25, y, cos(a) * 4.25)
		_quad(vertices, normals, uvs, colors, pa, pb, pc, pd, Color.WHITE)
		_quad(vertices, normals, uvs, colors, pd, pc, pc - Vector3(0, 0.16, 0), pd - Vector3(0, 0.16, 0), Color.WHITE)
		_instance(_array_mesh(vertices, normals, uvs, colors), _materials["wood_light"] as Material, parent)
	var rail_top: Array[Vector3] = []
	var rail_low: Array[Vector3] = []
	var fascia: Array[Vector3] = []
	for i: int in range(44):
		var a: float = lerpf(begin, finish, float(i) / 43.0)
		rail_top.append(Vector3(sin(a) * 4.20, y + 0.74 + sin(float(i)*0.31)*0.045, cos(a) * 4.20))
		rail_low.append(Vector3(sin(a) * 4.20, y + 0.33 - sin(float(i) * 0.62) * 0.035, cos(a) * 4.20))
		fascia.append(Vector3(sin(a) * 4.21, y - 0.15, cos(a) * 4.21))
	_timber28_log(rail_top, 0.080, 0.062, _materials["wood"] as Material, parent, 7, "top", -1)
	_timber28_log(rail_low, 0.035, 0.035, _materials["wood_light"] as Material, parent, 6, "low", -1)
	_timber28_log(fascia, 0.15, 0.15, _materials["wood"] as Material, parent, 8, "fascia", -1)
	for i: int in range(9):
		var a: float = lerpf(begin, finish, float(i) / 8.0) + sin(float(i)*1.3)*0.014
		var p: Vector3 = Vector3(sin(a) * 4.21, y, cos(a) * 4.21)
		_timber28_log([p - Vector3(0, 0.17, 0), p + Vector3(-0.035*sin(float(i)),0.40,0.03), p + Vector3(0.03, 0.89, -0.02)], 0.11, 0.070, _materials["wood"] as Material, parent, 8, "post", i)
		_sphere(p + Vector3(0.03, 0.89, -0.02), Vector3(0.12, 0.10, 0.12), _materials["wood_light"] as Material, parent, 12, 6)
		var support: Vector3 = Vector3(sin(a) * 2.9, y - 1.03, cos(a) * 2.9)
		_timber28_log([support, support.lerp(p, 0.52) + Vector3(0.08, 0.07, 0.04), p - Vector3(0, 0.22, 0)], 0.12, 0.09, _materials["wood"] as Material, parent, 8, "brace", i)
		if i % 2 == 0:
			_pot(p * Vector3(0.83, 1, 0.83) + Vector3(0, 0.02, 0), 0.19, parent)
			_flower_bouquet(p * Vector3(0.83, 1, 0.83) + Vector3(0, 0.30, 0), parent, 7, 0.55)
	for index: int in range(7):
		var a: float = 0.1 + float(index) * 0.17
		var r: float = 4.28
		var points: Array[Vector3] = []
		for j: int in range(9):
			var phase: float = float(j)*0.63 + float(index)*1.37
			var angle: float = a + sin(phase)*0.047
			var radius: float = r + sin(phase*0.72)*0.10
			var drop: float = float(j)*(.19 + float(index%3)*.025)
			points.append(Vector3(sin(angle)*radius, 3.36-drop, cos(angle)*radius))
		_vine(points, parent, index % 2 == 0)
	# Three curved flowering swags sit behind the front rail, leaving the door clear.
	var scenery_rng_state: int = _rng.state
	for index: int in range(3):
		var points: Array[Vector3] = []
		for j: int in range(13):
			var t: float = float(j)/12.0
			var angle: float = -.58+float(index)*.56+t*.57
			points.append(Vector3(sin(angle)*4.27,3.80-sin(t*PI)*.32,cos(angle)*4.27))
		_vine(points,parent,true)
	_rng.state = scenery_rng_state

	_timber28["rng_before_balcony"] = before_rng
	_timber28["rng_after_balcony"] = _rng.state
	_timber28["stats"] = {"targeted_nodes": (_timber28["targets"] as Array).size(), "retained_central_braces": 2, "additional_triangles": _timber28_added_triangles}
	if (_timber28["targets"] as Array).size() != 19:
		(_timber28["errors"] as Array).append("Expected19 existing timber targets")
	_timber28["status"] = "complete" if (_timber28["errors"] as Array).is_empty() else "refused"

func _timber28_bounds(box: AABB) -> Dictionary:
	return {"min":[box.position.x,box.position.y,box.position.z],"max":[box.end.x,box.end.y,box.end.z]}

func _timber28_face_count(mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()/3

func _timber28_log(points: Array[Vector3], old_start: float, old_end: float, material: Material, parent: Node3D, old_sides: int, kind: String, index: int) -> MeshInstance3D:
	# Original constructor executes once at the same ordinal with the original arguments.
	var node: MeshInstance3D = _tube(points,old_start,old_end,material,parent,old_sides)
	# These original front braces meet the doorway; preserve them byte-for-byte.
	if kind == "brace" and index in [2,3]: return node
	var original: ArrayMesh = node.mesh as ArrayMesh
	var old_count: int = _timber28_face_count(original)
	var source_bounds: Dictionary = _timber28_bounds(original.get_aabb())
	var selected: ArrayMesh = _timber28_mesh(points,kind,index)
	var new_count: int = _timber28_face_count(selected)
	node.mesh = selected
	node.name = "Timber28_"+kind+("_"+str(index) if index >= 0 else "")
	_timber28_added_triangles += new_count-old_count
	(_timber28["targets"] as Array).append({"name":node.name,"kind":kind,"index":index,"source_radius_start":old_start,"source_radius_end":old_end,"source_native_bounds":source_bounds,"selected_native_bounds":_timber28_bounds(selected.get_aabb()),"source_triangles":old_count,"selected_triangles":new_count,"material_id":"wood_light" if material == _materials["wood_light"] else "wood","node_transform":str(node.transform),"original_centerline_endpoints":[str(points[0]),str(points[-1])],"collider_created":false})
	return node

func _timber28_centers(points: Array[Vector3], kind: String, index: int) -> Array[Vector3]:
	if points.size() != 3: return points.duplicate()
	var count: int = 7 if kind == "post" else 6
	var result: Array[Vector3] = []
	var control: Vector3 = points[1]*2.0-(points[0]+points[2])*0.5
	for row: int in range(count):
		var t: float = float(row)/float(count-1)
		var value: Vector3 = points[0]*(1.0-t)*(1.0-t)+control*2.0*t*(1.0-t)+points[2]*t*t
		# End centers are exact original anchors; no extra deterministic random draws.
		if row == 0: value = points[0]
		if row == count-1: value = points[2]
		result.append(value)
	return result

func _timber28_accumulate(sums: Array[PackedVector3Array], row: int, side: int, value: Vector3) -> void:
	var channel: PackedVector3Array = sums[row]
	channel[side] += value
	sums[row] = channel

func _timber28_emit(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, a: Vector3,b: Vector3,c: Vector3, na: Vector3,nb: Vector3,nc: Vector3, ua: Vector2,ub: Vector2,uc: Vector2, ca: Color,cb: Color,cc: Color) -> void:
	var cross: Vector3 = (c-a).cross(b-a) # Godot clockwise front.
	if not cross.is_finite() or cross.length_squared() <= 0.00000000000001:
		(_timber28["errors"] as Array).append("Nonfinite or collapsed proposed timber triangle")
		return
	var front: Vector3 = cross.normalized()
	var repaired: Array[Vector3] = []
	for proposed: Vector3 in [na,nb,nc]:
		var normal: Vector3 = proposed.normalized()
		if not normal.is_finite() or normal.length_squared()<0.99 or normal.dot(front)<=0.05: normal=front
		repaired.append(normal)
	vertices.append_array(PackedVector3Array([a,b,c]))
	normals.append_array(PackedVector3Array(repaired))
	uvs.append_array(PackedVector2Array([ua,ub,uc]))
	colors.append_array(PackedColorArray([ca,cb,cc]))

func _timber28_mesh(source_points: Array[Vector3], kind: String, index: int) -> ArrayMesh:
	var centers: Array[Vector3] = _timber28_centers(source_points,kind,index)
	var sides: int = 12 if kind in ["top","fascia"] else (8 if kind == "low" else 10)
	var start_radius: float = 0.110
	var end_radius: float = 0.085
	if kind == "low": start_radius=0.049; end_radius=0.043
	elif kind == "fascia": start_radius=0.225; end_radius=0.205
	elif kind == "post": start_radius=0.150; end_radius=0.090
	elif kind == "brace": start_radius=0.170; end_radius=0.120
	var phase: float = float(index+1)*1.73+0.41
	var unequal: float = 1.0 if index < 0 else 0.98+0.05*sin(phase)
	var rings: Array[PackedVector3Array] = []
	var sums: Array[PackedVector3Array] = []
	var shades: Array[PackedColorArray] = []
	var lengths: PackedFloat32Array = PackedFloat32Array()
	var directions: Array[Vector3] = []
	var arc: float = 0.0
	for row: int in range(centers.size()):
		var t: float = float(row)/float(centers.size()-1)
		var center: Vector3 = centers[row]
		var direction: Vector3 = (centers[mini(row+1,centers.size()-1)]-centers[maxi(row-1,0)]).normalized()
		directions.append(direction)
		var reference: Vector3 = Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.97 else Vector3.UP
		var u: Vector3 = direction.cross(reference).normalized()
		var v: Vector3 = direction.cross(u).normalized()
		var radius: float = lerpf(start_radius,end_radius,t)*unequal*(1.0+0.045*sin(PI*t)+0.020*sin(TAU*t+phase)*sin(PI*t))
		var ellipse_u: float = 1.0+0.045*sin(phase)
		var ellipse_v: float = 0.92+0.035*cos(phase)
		if kind == "fascia": ellipse_u=1.0; ellipse_v=0.89
		var offsets: PackedVector3Array = PackedVector3Array()
		var row_colors: PackedColorArray = PackedColorArray()
		var max_offset_y: float = -INF
		for side: int in range(sides):
			var a: float = TAU*float(side)/float(sides)
			var wear: float = 0.977+0.020*cos(3.0*a+phase)+0.011*sin(5.0*a-phase*0.7)
			var offset: Vector3 = (u*cos(a)*ellipse_u+v*sin(a)*ellipse_v)*radius*wear
			offsets.append(offset)
			max_offset_y=maxf(max_offset_y,offset.y)
			var tint: float = 0.90+0.045*sin(phase+a*2.0)+0.025*cos(t*PI*3.0+phase)
			row_colors.append(Color(tint,tint*0.985,tint*0.955,1.0))
		if kind == "fascia": center.y=3.245-max_offset_y # Added depth below the unchanged deck.
		var points: PackedVector3Array = PackedVector3Array()
		for offset: Vector3 in offsets: points.append(center+offset)
		rings.append(points); shades.append(row_colors)
		var row_sums: PackedVector3Array = PackedVector3Array()
		row_sums.resize(sides); sums.append(row_sums)
		if row>0: arc += centers[row].distance_to(centers[row-1])
		lengths.append(arc*0.5)
	# Normals come from final discrete side triangles, then satisfy each actual face hemisphere.
	for row: int in range(rings.size()-1):
		for j: int in range(sides):
			var k: int = (j+1)%sides
			var f1: Vector3 = (rings[row][k]-rings[row][j]).cross(rings[row+1][k]-rings[row][j])
			var f2: Vector3 = (rings[row+1][k]-rings[row][j]).cross(rings[row+1][j]-rings[row][j])
			_timber28_accumulate(sums,row,j,f1+f2)
			_timber28_accumulate(sums,row,k,f1)
			_timber28_accumulate(sums,row+1,k,f1+f2)
			_timber28_accumulate(sums,row+1,j,f2)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for row: int in range(rings.size()-1):
		for j: int in range(sides):
			var k: int = (j+1)%sides
			var uj: float = float(j)/float(sides)
			var uk: float = float(j+1)/float(sides)
			_timber28_emit(vertices,normals,uvs,colors,rings[row][j],rings[row+1][k],rings[row][k],sums[row][j],sums[row+1][k],sums[row][k],Vector2(uj,lengths[row]),Vector2(uk,lengths[row+1]),Vector2(uk,lengths[row]),shades[row][j],shades[row+1][k],shades[row][k])
			_timber28_emit(vertices,normals,uvs,colors,rings[row][j],rings[row+1][j],rings[row+1][k],sums[row][j],sums[row+1][j],sums[row+1][k],Vector2(uj,lengths[row]),Vector2(uj,lengths[row+1]),Vector2(uk,lengths[row+1]),shades[row][j],shades[row+1][j],shades[row+1][k])
	# Local cut ends close formerly open log tubes; caps and posts stay at original anchors.
	for end: int in [0,rings.size()-1]:
		var center: Vector3 = Vector3.ZERO
		for p: Vector3 in rings[end]: center+=p
		center/=float(sides)
		var normal: Vector3 = -directions[end] if end == 0 else directions[end]
		var tint: Color = Color(0.97,0.95,0.90,1.0)
		for j: int in range(sides):
			var k: int = (j+1)%sides
			var a: Vector3 = rings[end][j] if end == 0 else rings[end][k]
			var b: Vector3 = rings[end][k] if end == 0 else rings[end][j]
			_timber28_emit(vertices,normals,uvs,colors,center,a,b,normal,normal,normal,Vector2(0.5,0.5),Vector2(float(j)/float(sides),0),Vector2(float(j+1)/float(sides),1),tint,tint,tint)
	return _array_mesh(vertices,normals,uvs,colors)
