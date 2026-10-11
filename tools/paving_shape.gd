extends RefCounted
## Offline-only candidate. No world assignments, runtime factory or archive paths.
## Isolated trial: retain the adopted lower joint and narrow the upper joint.
## Retriangulate only the exact 52-face soil roof with matching render/contact.
## Original192 remains untouched. The caller owns a fresh output directory and tests.
const Roof = preload("res://tools/paving_upper_roof.gd")
var roof_result: Dictionary = {}
var roof_points := PackedVector3Array()
const ROOF_RENDER_START := 3113 * 3
const ROOF_RENDER_END := 3165 * 3
const Reader = preload("res://scripts/cap57_prebuilt.gd")
const Owner = preload("res://scripts/paving_collar_prebuilt.gd")
const INPUT := "res://baked/paving-preview192.res"
const MANIFEST := "res://baked/paving-preview192.json"
const INPUT_SHA := "6d5d78516898be3099d0496f07f02057b28b8eb944091d4b27b1018592657aa9"
const MANIFEST_SHA := "e79a3726db329ac6de071966504b5271a584042f1a2aafb73c33228e3d460cd6"
const FORMAT: int = 34359738399
const COUNTS := [4638,3078,9501]
# Corner ranges are ordered native record mappings, not proximity/color selectors.
# 35 lower packets survive79's ordered complement;79 appends upper packets.
# 96/143 retain these slots;179 edits soil only;192 changes six upper-right faces.
const TOP := [[3180,3552],[3552,3912],[3912,4278],[4278,4638]]
const FRONT := [[2598,2694],[2694,2790],[2790,2934],[2934,3078]]
const CENTRAL := [63,60,63,60]
const FEET := [
	"336eb4bf0000fc40562b55bf3d0afb4084ed8bbeb81efd4077f7d8be33330b41ee2802bf52b80c41adeaa9bfc3f50c41494fcabf66660c41085fc9bf713d0a41",
	"ce8c32beb81efd40a25f3f3e295cfb40048e0b3ff628fc409620063fae470141119ed03e66660a416b55963e8fc20b41a9d837be9a990b414ccf9ebe7b140a41",
	"a0369ebfb81edd40370234bfec51dc4073fc11be6666de4051cf8abec3f5f44045b2cdbed7a3f840c0a888bf0000f840ee98acbf3333f7404ce9aebf52b8f240",
	"45a558bc48e1de406a00d53ec3f5dc40c8ee383fae47dd4076bf313f0000e440c27b0e3f7b14f640801ad33eec51f840286a29bc295cf740319404be3333f340"
]
const SHOULDER192 := "5f50133fbcdb903ed95ef340"
const ROOF52_SHA := "d0613c5f227ca9ce4b9c2d7c709c6ef77294ec230374b23359f8c8d7ca5df76a"
const CUT_CONTROLS := "f09b48bd3bdf8f3e295cdf40bd8431be3de8103e3333f340"
const OUTER32 := "8b1bacbff628dc3e48e1da40ef0440bf3bdf8f3e48e1da40a38f18bf3bdf8f3e48e1da40234b1fbe3bdf8f3e48e1da409777493e3bdf8f3e48e1da40a678d53e3bdf8f3e48e1da402d795b3ff628dc3e48e1da40efe9533f087dc13e0000e040a16f533f46d2bf3eec51e040373d523f6da7bb3eb81ee1405f1c4f3f93d1b03e3333e340ca624e3f7651ae3e14aee340ea2c4d3f9726aa3ee17ae440bfd9463fe37a943ed7a3e840f9b43b3fe17a943e0000f040590d2d3fe17a943e713dfa405a0d2d3fd9cef73d713dfa40cc9d183ed9cef73d713dfa4037ec46bdd9cef73d713dfa408ef8d7bed9cef73d713dfa4087665cbfd9cef73d713dfa4075df81bfd9cef73d713dfa40f482c2bfd9cef73d713dfa40f482c2bfe17a943e713dfa40c2f1babfe17a943e0000f0408dcfb5bfe37a943ed7a3e8401aecb2bf9726aa3ee17ae440255db2bf7651ae3e14aee3403407b2bf93d1b03e3333e3401c91b0bf6da7bb3eb81ee1406e00b0bf46d2bf3eec51e0406cc6afbf087dc13e0000e040"
const PROVENANCE := {
	"lower35":"40fa4c11566f439627fc90cb72a1ca63136e4df32c0469a795a0efaa60adaba0",
	"upper79":"bb47dd8899792f1439560c48c228d59339a9dd9f7a6f0cc8917e4714f25ee64d",
	"soil181":"8569bd6c2d89b1a4131959b2d0d3278dbbcf17ecd411d88540170166e58d60ae",
	"final194":"55c1b3266d918c899f77e77097c7e883a1d8e629e756984e1cfc5a96b27d6249"
}
var candidate_library: MeshLibrary
var report: Dictionary = {}
var called := false
var owner: RefCounted
var feet: Array[PackedVector2Array] = []
var planes: Array[Plane] = []
var point_map: Dictionary = {}
var foot_map: Dictionary = {}
var source_meshes: Array[ArrayMesh] = []
var arrays: Array[Array] = []
var refit_controls := PackedVector3Array()

func _sha(bytes: PackedByteArray) -> String:
	return Reader._sha(bytes)

func _check(value: bool,label: String,evidence: Dictionary = {}) -> bool:
	report.checks.append({"label":label,"passed":value,"evidence":evidence})
	if not value: report.failures.append(label)
	return value

func _key(p: Vector3) -> String:
	return PackedVector3Array([p]).to_byte_array().hex_encode()

func _xz_key(p: Vector2) -> String:
	return PackedVector2Array([p]).to_byte_array().hex_encode()

func _points(hex: String) -> PackedVector2Array:
	var bytes := hex.hex_decode()
	var result := PackedVector2Array()
	for i: int in range(0,bytes.size(),8): result.append(Vector2(bytes.decode_float(i),bytes.decode_float(i+4)))
	return result if result.to_byte_array()==bytes else PackedVector2Array()

func _xyz(hex: String) -> PackedVector3Array:
	var bytes:=hex.hex_decode(); var result:=PackedVector3Array()
	for i: int in range(0,bytes.size(),12): result.append(Vector3(bytes.decode_float(i),bytes.decode_float(i+4),bytes.decode_float(i+8)))
	return result if result.to_byte_array()==bytes else PackedVector3Array()

func _span(polygon: PackedVector2Array,z: float) -> PackedFloat64Array:
	var xs: Array[float] = []
	for i: int in range(polygon.size()):
		var a: Vector2=polygon[i]; var b: Vector2=polygon[(i+1)%polygon.size()]
		if (a.y<=z and z<b.y) or (b.y<=z and z<a.y):
			xs.append(lerpf(a.x,b.x,(z-a.y)/(b.y-a.y)))
	if xs.size()!=2: return PackedFloat64Array()
	xs.sort()
	return PackedFloat64Array(xs)

func _dx(stone: int,p: Vector2) -> float:
	# Both joints narrow; upper-right front taper retains its original steep toe.
	# Constant inner offsets retain the existing irregular contours. The X-only
	# transition is checked against unchanged orientation and slope gates.
	var left: bool=stone%2==0
	# Hold the rear outer shoulders: moving one by 5.8mm changed the shared
	# soil ridge and stalled the real diagonal-ascent route in the first trial.
	var weight: float=clampf((p.x+.60)/.15,0.0,1.0) if left else clampf((.25-p.x)/.25,0.0,1.0)
	# Preserve both front toes so narrowing the inner joint does not expand
	# the capsule's first contact into the previously safe lower-row approach.
	if stone==2: weight*=clampf((7.77-p.y)/.115,0.0,1.0)
	if stone==3: weight*=clampf((7.73-p.y)/.13,0.0,1.0)
	return (.030 if stone<2 else .045)*weight*(1.0 if left else -1.0)

func _gather(source: Array,indices: PackedInt32Array) -> Array:
	var result: Array=source.duplicate(true)
	for channel: int in range(Mesh.ARRAY_MAX):
		if result[channel]!=null: result[channel]=result[channel].slice(0,0)
	for index: int in indices:
		for channel: int in range(Mesh.ARRAY_MAX):
			if result[channel]==null: continue
			if channel==Mesh.ARRAY_TANGENT:
				for j: int in range(4): result[channel].append(source[channel][index*4+j])
			else: result[channel].append(source[channel][index])
	return result

func _closed(points: PackedVector3Array) -> bool:
	var directions: Dictionary={}
	for i: int in range(0,points.size(),3):
		for j: int in range(3):
			var a:=_key(points[i+j]); var b:=_key(points[i+(j+1)%3]); var k:=a+":"+b
			directions[k]=int(directions.get(k,0))+1
	for key: String in directions:
		var parts:=key.split(":")
		if directions[key]!=1 or directions.get(parts[1]+":"+parts[0],0)!=1: return false
	return true

func _admit_stones() -> bool:
	var soil: PackedVector3Array=arrays[2][Mesh.ARRAY_VERTEX]
	var soil_xz: Dictionary={}
	for p: Vector3 in soil: soil_xz[_xz_key(Vector2(p.x,p.z))]=true
	var top: PackedVector3Array=arrays[0][Mesh.ARRAY_VERTEX]
	var front: PackedVector3Array=arrays[1][Mesh.ARRAY_VERTEX]
	for stone: int in range(4):
		var polygon:=_points(FEET[stone]); feet.append(polygon)
		var first: int=TOP[stone][0]
		# Tiny triangulation ears are a poorly conditioned plane basis. Use the
		# largest native central triangle; retain the same1um coplanarity gate.
		var basis: int=first; var largest_area:=0.0
		for i: int in range(first,first+CENTRAL[stone],3):
			var area: float=(top[i+1]-top[i]).cross(top[i+2]-top[i]).length_squared()
			if area>largest_area: largest_area=area; basis=i
		var plane:=Plane(top[basis],top[basis+1],top[basis+2])
		if plane.normal.y<0.0: plane=Plane(-plane.normal,-plane.d)
		var maximum_error:=0.0
		for i: int in range(first,first+CENTRAL[stone]): maximum_error=maxf(maximum_error,absf(plane.distance_to(top[i])))
		var closed:=top.slice(first,TOP[stone][1]); closed.append_array(front.slice(FRONT[stone][0],FRONT[stone][1]))
		var all_feet:=true
		for p: Vector2 in polygon:
			all_feet=all_feet and soil_xz.has(_xz_key(p))
			var found:=false
			for v: Vector3 in closed:
				if _xz_key(Vector2(v.x,v.z))==_xz_key(p): found=true; break
			all_feet=all_feet and found
		if not _check(polygon.size()==8 and plane.normal.y>.999 and maximum_error<=.000001 and _closed(closed) and all_feet,"Pinned ordered stone packet/plane/closed foot and soil seam",{"stone":stone,"top_range":TOP[stone],"front_range":FRONT[stone],"central_plane_max_error_m":maximum_error,"foot_XZ_hex":FEET[stone]}): return false
		planes.append(plane)
	return true

func _map_stones() -> bool:
	for stone: int in range(4):
		var walking: Dictionary={}; var points:=PackedVector3Array()
		for item: int in range(2):
			var interval: Array=TOP[stone] if item==0 else FRONT[stone]
			var old: PackedVector3Array=arrays[item][Mesh.ARRAY_VERTEX]
			points.append_array(old.slice(interval[0],interval[1]))
			if item==0:
				for i: int in range(interval[0],interval[1],3):
					if (old[i+2]-old[i]).cross(old[i+1]-old[i]).y>0.0:
						for j: int in range(3): walking[_key(old[i+j])]=true
		var plane: Plane=planes[stone]
		for p: Vector3 in points:
			var old_key:=_key(p); var dx:=_dx(stone,Vector2(p.x,p.z)); var fresh:=p
			if dx!=0.0:
				fresh.x+=dx
				if walking.has(old_key): fresh.y+=-plane.normal.x/plane.normal.y*dx
				# Native float32 coordinates are the sole map reused by render/contact.
				fresh=PackedVector3Array([fresh])[0]
			if point_map.has(old_key) and point_map[old_key]!=fresh: return _check(false,"Selected stones have conflicting shared vertex deformation")
			point_map[old_key]=fresh
		for p: Vector2 in feet[stone]:
			var fresh:=Vector2(p.x+_dx(stone,p),p.y); fresh=PackedVector2Array([fresh])[0]
			var key:=_xz_key(p)
			if foot_map.has(key) and foot_map[key]!=fresh: return _check(false,"Foot contours share conflicting points")
			foot_map[key]=fresh
	var unmapped: Array=[]; var exact_shared:=0; var foot_shared:=0
	# Soil uses only exactly shared native stone XYZ or admitted native foot XZ.
	var soil: PackedVector3Array=arrays[2][Mesh.ARRAY_VERTEX]
	for i: int in range(soil.size()):
		var p: Vector3=soil[i]
		var key:=_key(p); var xz:=_xz_key(Vector2(p.x,p.z))
		var touches_foot:=foot_map.has(xz)
		for polygon: PackedVector2Array in feet: touches_foot=touches_foot or Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
		if touches_foot and not point_map.has(key) and not foot_map.has(xz):
			if unmapped.size()<8: unmapped.append({"soil_corner":i,"XYZ_hex":key})
		if touches_foot and point_map.has(key): exact_shared+=1
		elif touches_foot and foot_map.has(xz): foot_shared+=1
		if not point_map.has(key) and foot_map.has(xz):
			var q: Vector2=foot_map[xz]; point_map[key]=Vector3(q.x,p.y,q.y)
	if not _check(unmapped.is_empty() and exact_shared>0 and foot_shared>0,"Complete native soil-hole/collar vertex correspondence",{"exact_stone_XYZ_soil_incidences":exact_shared,"foot_XZ_soil_incidences":foot_shared,"first_unmapped":unmapped}): return false
	if not _check(not point_map.has(SHOULDER192) or _key(point_map[SHOULDER192])==SHOULDER192,"Current192 outside-right shoulder held byte-exact"): return false
	var boundaries:=_xyz(OUTER32); var controls:=_xyz(CUT_CONTROLS); var source_keys: Dictionary={}
	for source: Array in arrays:
		for p: Vector3 in (source[Mesh.ARRAY_VERTEX] as PackedVector3Array): source_keys[_key(p)]=true
	var boundary_held: bool=boundaries.size()==32 and controls.size()==2
	for p: Vector3 in boundaries+controls:
		boundary_held=boundary_held and source_keys.has(_key(p)) and _key(point_map.get(_key(p),p))==_key(p)
	if not _check(boundary_held,"Native outer32 stations and both interior cut controls retained byte-exact"): return false
	refit_controls=controls.duplicate()
	return true

func _layout(mesh: ArrayMesh) -> Dictionary:
	var stored: Variant=mesh.get("_surfaces")
	if mesh.get_surface_count()!=1 or mesh.surface_get_format(0)!=FORMAT or mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_array_index_len(0)!=0 or not stored is Array or stored.size()!=1 or not stored[0] is Dictionary: return {}
	var data: Dictionary=stored[0]; var n: int=mesh.surface_get_array_len(0)
	if data.size()!=7 or not data.has_all(["format","primitive","vertex_data","vertex_count","attribute_data","aabb","uv_scale"]) or data.vertex_count!=n or data.vertex_data.size()!=n*20 or data.attribute_data.size()!=n*12: return {}
	if RenderingServer.mesh_surface_get_format_vertex_stride(FORMAT,n)!=12 or RenderingServer.mesh_surface_get_format_normal_tangent_stride(FORMAT,n)!=8 or RenderingServer.mesh_surface_get_format_attribute_stride(FORMAT,n)!=12 or RenderingServer.mesh_surface_get_format_offset(FORMAT,n,Mesh.ARRAY_NORMAL)!=n*12 or RenderingServer.mesh_surface_get_format_offset(FORMAT,n,Mesh.ARRAY_TEX_UV)!=4: return {}
	return data

func _tri_key(points: PackedVector3Array) -> String:
	var rows: Array[String]=[]
	for p: Vector3 in points: rows.append(_key(p))
	rows.sort()
	return "|".join(rows)

func _triangle_ok(old: PackedVector3Array,fresh: PackedVector3Array) -> bool:
	var a: Vector3=(old[2]-old[0]).cross(old[1]-old[0]); var b: Vector3=(fresh[2]-fresh[0]).cross(fresh[1]-fresh[0])
	if not b.is_finite() or b.length_squared()<=1e-18 or a.dot(b)<=0.0: return false
	if a.normalized().y>=cos(deg_to_rad(25.0)) and b.normalized().y<cos(deg_to_rad(25.0)): return false
	return true

func _packet(source: Array,points: PackedVector3Array,indices: PackedInt32Array) -> ArrayMesh:
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0,indices.size(),3):
		var n: Vector3=(points[indices[i+2]]-points[indices[i]]).cross(points[indices[i+1]]-points[indices[i]]).normalized()
		var tangent: Vector3=Vector3.RIGHT-n*n.x
		if tangent.length_squared()<.000001: tangent=Vector3.BACK-n*n.z
		tangent=tangent.normalized()
		for j: int in range(3):
			var index: int=indices[i+j]; var p: Vector3=points[index]
			tool.set_normal(n); tool.set_tangent(Plane(tangent,1.0)); tool.set_color(source[Mesh.ARRAY_COLOR][index]); tool.set_uv(Vector2(p.x,p.z)); tool.add_vertex(p)
	return tool.commit()

func _patch(item: int) -> ArrayMesh:
	var old_mesh: ArrayMesh=source_meshes[item]; var old: Array=arrays[item]
	var before: PackedVector3Array=old[Mesh.ARRAY_VERTEX]; var points:=before.duplicate()
	var moved: Dictionary={}; var changed:=PackedInt32Array(); var complement:=PackedInt32Array()
	for i: int in range(points.size()):
		var key:=_key(points[i])
		if point_map.has(key): points[i]=point_map[key]
		if _key(points[i])!=key: moved[i]=true
	if item==2:
		for i: int in range(roof_points.size()):
			points[ROOF_RENDER_START+i]=roof_points[i]
			if _key(points[ROOF_RENDER_START+i])!=_key(before[ROOF_RENDER_START+i]): moved[ROOF_RENDER_START+i]=true
	for i: int in range(0,points.size(),3):
		if moved.has(i) or moved.has(i+1) or moved.has(i+2):
			if not (item==2 and i>=ROOF_RENDER_START and i<ROOF_RENDER_END) and not _triangle_ok(before.slice(i,i+3),points.slice(i,i+3)):
				_check(false,"Changed native triangle inversion/area/25degree refusal",{"item":item,"triangle":i/3,"before":str(before.slice(i,i+3)),"after":str(points.slice(i,i+3)),"old_normal":str((before[i+2]-before[i]).cross(before[i+1]-before[i])),"new_normal":str((points[i+2]-points[i]).cross(points[i+1]-points[i]))})
				return null
			for j: int in range(3): changed.append(i+j)
		else:
			for j: int in range(3): complement.append(i+j)
	var original_data:=_layout(old_mesh)
	var data:=original_data.duplicate(true)
	if data.is_empty() or changed.is_empty(): _check(false,"Known raw layout and substantive selected item change",{"item":item}); return null
	var packet:=_packet(old,points,changed); var fresh:=_layout(packet)
	if fresh.is_empty() or var_to_bytes(fresh.uv_scale)!=var_to_bytes(data.uv_scale): _check(false,"Changed native packet layout/UV scale refused"); return null
	var vertex: PackedByteArray=data.vertex_data.duplicate(); var attributes: PackedByteArray=data.attribute_data.duplicate()
	for i: int in range(changed.size()):
		var target: int=changed[i]
		for b: int in range(12): vertex[target*12+b]=fresh.vertex_data[i*12+b]
		for b: int in range(8): vertex[points.size()*12+target*8+b]=fresh.vertex_data[changed.size()*12+i*8+b]
		# Keep native RGBA8 exact; only UV floats are replaced on moved corners.
		if moved.has(target):
			for b: int in range(4,12): attributes[target*12+b]=fresh.attribute_data[i*12+b]
	data.vertex_data=vertex; data.attribute_data=attributes
	var mesh:=ArrayMesh.new(); mesh.blend_shape_mode=old_mesh.blend_shape_mode; mesh.set("_surfaces",[data])
	mesh.resource_name=old_mesh.resource_name; mesh.resource_local_to_scene=old_mesh.resource_local_to_scene; mesh.custom_aabb=old_mesh.custom_aabb
	var actual:=mesh.surface_get_arrays(0); var loaded:=_layout(mesh)
	var untouched:=true; var colors_held:=true
	var old_records:=PackedByteArray(); var new_records:=PackedByteArray()
	for i: int in complement:
		old_records.append_array(original_data.vertex_data.slice(i*12,i*12+12)); old_records.append_array(original_data.vertex_data.slice(points.size()*12+i*8,points.size()*12+i*8+8)); old_records.append_array(original_data.attribute_data.slice(i*12,i*12+12))
		new_records.append_array(loaded.vertex_data.slice(i*12,i*12+12)); new_records.append_array(loaded.vertex_data.slice(points.size()*12+i*8,points.size()*12+i*8+8)); new_records.append_array(loaded.attribute_data.slice(i*12,i*12+12))
	var old_complement:=var_to_bytes(_gather(old,complement)); var new_complement:=var_to_bytes(_gather(actual,complement))
	untouched=old_records==new_records and old_complement==new_complement
	for i: int in range(points.size()): colors_held=colors_held and loaded.attribute_data.slice(i*12,i*12+4)==original_data.attribute_data.slice(i*12,i*12+4)
	var exact: bool=var_to_bytes(mesh.get("_surfaces"))==var_to_bytes([data]) and (actual[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array()==points.to_byte_array() and var_to_bytes(owner.call("_mesh_configuration",mesh))==var_to_bytes(owner.call("_mesh_configuration",old_mesh)) and var_to_bytes(mesh.get_aabb())==var_to_bytes(old_mesh.get_aabb())
	if not _check(exact and untouched and colors_held,"Native replacement/complement/config/AABB and all colors held",{"item":item,"moved_corners":moved.size(),"changed_triangle_corners":changed.size(),"exact_unselected_corners":complement.size(),"complement_all13_before_sha256":_sha(old_complement),"complement_all13_after_sha256":_sha(new_complement),"complement_raw_before_sha256":_sha(old_records),"complement_raw_after_sha256":_sha(new_records)}): return null
	return mesh

func _verify_geometry(meshes: Array[ArrayMesh],old_contact: PackedVector3Array,new_contact: PackedVector3Array) -> bool:
	var old_caps:=_cap_equivalence(source_meshes,old_contact,"source")
	var new_caps:=_cap_equivalence(meshes,new_contact,"candidate")
	if old_caps.is_empty() or new_caps.is_empty(): return false
	var finite:=true; var planes_exact:=true; var closed:=true; var min_area:=INF
	for mesh: ArrayMesh in meshes:
		var a:=mesh.surface_get_arrays(0); var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX]; var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]; var t: PackedFloat32Array=a[Mesh.ARRAY_TANGENT]; var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
		for i: int in range(p.size()):
			finite=finite and p[i].is_finite() and n[i].is_finite() and uv[i].is_finite() and absf(n[i].length()-1.0)<.005 and is_finite(t[i*4]) and is_finite(t[i*4+1]) and is_finite(t[i*4+2]) and is_finite(t[i*4+3])
		for i: int in range(0,p.size(),3): min_area=minf(min_area,(p[i+2]-p[i]).cross(p[i+1]-p[i]).length()*.5)
	for stone: int in range(4):
		var top: PackedVector3Array=meshes[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]; var front: PackedVector3Array=meshes[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(TOP[stone][0],TOP[stone][0]+CENTRAL[stone]): planes_exact=planes_exact and absf(planes[stone].distance_to(top[i]))<=.000001
		var packet:=top.slice(TOP[stone][0],TOP[stone][1]); packet.append_array(front.slice(FRONT[stone][0],FRONT[stone][1])); closed=closed and _closed(packet)
	var changed_render: Dictionary={}; var render_vertices: Dictionary={}; var original_render: Dictionary={}
	for old_arrays: Array in arrays:
		var original_points: PackedVector3Array=old_arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0,original_points.size(),3): original_render[_tri_key(original_points.slice(i,i+3))]=true
	for mesh: ArrayMesh in meshes:
		var p: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(0,p.size(),3): changed_render[_tri_key(p.slice(i,i+3))]=true
		for v: Vector3 in p: render_vertices[_key(v)]=true
	var contact_exact:=true; var changed_faces:=0; var unmatched: Array=[]
	for i: int in range(0,new_contact.size(),3):
		if old_contact.slice(i,i+3).to_byte_array()!=new_contact.slice(i,i+3).to_byte_array():
			changed_faces+=1
			var same_surface: bool=changed_render.has(_tri_key(new_contact.slice(i,i+3))) or (old_caps.has(i/3) and new_caps.has(i/3))
			var is_roof: bool=i>=2387*3 and i<2439*3
			var match_ok: bool=(is_roof or _triangle_ok(old_contact.slice(i,i+3),new_contact.slice(i,i+3))) and same_surface
			contact_exact=contact_exact and match_ok
			if not match_ok and unmatched.size()<4: unmatched.append({"face":i/3,"old":str(old_contact.slice(i,i+3)),"new":str(new_contact.slice(i,i+3)),"orientation_ok":_triangle_ok(old_contact.slice(i,i+3),new_contact.slice(i,i+3)),"render_triangle_match":changed_render.has(_tri_key(new_contact.slice(i,i+3))),"source_triangle_matched":original_render.has(_tri_key(old_contact.slice(i,i+3))),"all_candidate_vertices_on_render":render_vertices.has(_key(new_contact[i])) and render_vertices.has(_key(new_contact[i+1])) and render_vertices.has(_key(new_contact[i+2]))})
	return _check(finite and min_area>0.0 and planes_exact and closed and contact_exact and changed_faces>0,"Finite native channels/nonzero triangles, unchanged central planes, closed seams and changed contact/render agreement",{"finite_channels":finite,"contact_exact":contact_exact,"unmatched_contact_faces":unmatched,"minimum_render_triangle_area_m2":min_area,"four_native_central_planes_retained":planes_exact,"closed_stones":closed,"changed_contact_faces":changed_faces,"unchanged_contact_corners":new_contact.size()-changed_faces*3,"unchanged_UV_channels_outside_changed_triangles":true,"UV_check_scope":"Raw complement held; changed UV uses native worldXZ. Original native UV metadata is retained."})

func _boundary_signature(points: PackedVector3Array) -> Array[String]:
	var directed: Dictionary={}
	for i: int in range(0,points.size(),3):
		if (points[i+2]-points[i]).cross(points[i+1]-points[i]).y<=0.0: return []
		for j: int in range(3):
			var key:=_key(points[i+j])+":"+_key(points[i+(j+1)%3])
			if directed.has(key): return []
			directed[key]=true
	var boundary: Array[String]=[]
	for key: String in directed:
		var ends:=key.split(":")
		if not directed.has(ends[1]+":"+ends[0]): boundary.append(key)
	boundary.sort()
	return boundary

func _cap_equivalence(meshes: Array[ArrayMesh],contact: PackedVector3Array,label: String) -> Dictionary:
	var eligible: Dictionary={}
	var top: PackedVector3Array=meshes[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for stone: int in range(4):
		var render:=top.slice(TOP[stone][0],TOP[stone][0]+CENTRAL[stone])
		var vertices: Dictionary={}; var maximum_plane_residual:=0.0
		for p: Vector3 in render:
			vertices[_key(p)]=true
			maximum_plane_residual=maxf(maximum_plane_residual,absf(planes[stone].distance_to(p)))
		var cap:=PackedVector3Array(); var indices: Array[int]=[]
		for i: int in range(0,contact.size(),3):
			if vertices.has(_key(contact[i])) and vertices.has(_key(contact[i+1])) and vertices.has(_key(contact[i+2])):
				cap.append_array(contact.slice(i,i+3)); indices.append(i/3)
		var boundary:=_boundary_signature(render)
		var exact: bool=not boundary.is_empty() and cap.size()==render.size() and _boundary_signature(cap)==boundary and maximum_plane_residual<=.000001
		# All triangles face up, each interior directed edge cancels exactly, and
		# every boundary edge/vertex is shared. Thus both tessellations cover the
		# same planar domain, without overlap or holes. The plane residual bounds
		# the vertical difference across either triangulation (not a sample claim).
		if not _check(exact,"Complete "+label+" cap contact/render domain and plane equivalence",{"stone":stone,"render_triangles":render.size()/3,"contact_triangles":cap.size()/3,"exact_directed_boundary_edges":boundary.size(),"all_contact_vertices_native_render_members":true,"maximum_plane_residual_m":maximum_plane_residual,"maximum_surface_separation_bound_m":2.0*maximum_plane_residual/planes[stone].normal.y}): return {}
		for face: int in indices: eligible[face]=true
	return eligible

func _area(polygon: PackedVector2Array) -> float:
	var total:=0.0
	for i: int in range(polygon.size()): total+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(total)*.5

func _seams(meshes: Array[ArrayMesh],new_feet: Array[PackedVector2Array]) -> bool:
	var source: PackedVector3Array=arrays[2][Mesh.ARRAY_VERTEX]; var candidate: PackedVector3Array=meshes[2].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var shared_exact:=true; var outside_clear:=true; var tested:=0; var max_overlap:=0.0
	for i: int in range(source.size()):
		if i>=ROOF_RENDER_START and i<ROOF_RENDER_END: continue
		if point_map.has(_key(source[i])): shared_exact=shared_exact and _key(candidate[i])==_key(point_map[_key(source[i])])
	for i: int in range(0,source.size(),3):
		if source.slice(i,i+3).to_byte_array()==candidate.slice(i,i+3).to_byte_array(): continue
		var old_poly:=PackedVector2Array(); var new_poly:=PackedVector2Array()
		for j: int in range(3): old_poly.append(Vector2(source[i+j].x,source[i+j].z)); new_poly.append(Vector2(candidate[i+j].x,candidate[i+j].z))
		for stone: int in range(4):
			var old_overlap:=0.0; var new_overlap:=0.0
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(old_poly,feet[stone]): old_overlap+=_area(polygon)
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(new_poly,new_feet[stone]): new_overlap+=_area(polygon)
			# Existing visual collars intentionally overlap a stone's projected footprint.
			# Every formerly exterior soil triangle must remain outside its new foot.
			if (i>=ROOF_RENDER_START and i<ROOF_RENDER_END) or old_overlap<=.00000001:
				tested+=1; max_overlap=maxf(max_overlap,new_overlap); outside_clear=outside_clear and new_overlap<=.00000001
	return _check(shared_exact and outside_clear and tested>0,"Actual soil shared incidences exact and no new exterior-soil/stone overlap",{"outside_triangle_foot_checks":tested,"maximum_new_exterior_overlap_m2":max_overlap,"shared_point_mapping_exact":shared_exact,"projected_area_limit_m2":.00000001,"existing_collars_projected_inside_foot_are_retained":true})

func _contact_proof(before: PackedVector3Array,after: PackedVector3Array) -> Dictionary:
	var indices: Array[int]=[]; var faces: Array[int]=[]; var kept_before:=PackedVector3Array(); var kept_after:=PackedVector3Array()
	var nonroof_mapping:=true; var roof_moved: Array[int]=[]
	for i: int in range(before.size()):
		var is_roof: bool=i>=2387*3 and i<2439*3
		if not is_roof: nonroof_mapping=nonroof_mapping and _key(after[i])==_key(point_map.get(_key(before[i]),before[i]))
		if _key(before[i])!=_key(after[i]):
			indices.append(i)
			var face: int=i/3
			if not face in faces: faces.append(face)
			if is_roof: roof_moved.append(i)
		else: kept_before.append(before[i]); kept_after.append(after[i])
	var roof_before:=before.slice(2387*3,2439*3); var roof_after:=after.slice(2387*3,2439*3)
	var held: bool=kept_before.to_byte_array()==kept_after.to_byte_array()
	var passed: bool=held and nonroof_mapping and roof_result.passed and roof_after.to_byte_array()==roof_points.to_byte_array() and _sha(roof_before.to_byte_array())==ROOF52_SHA
	_check(passed,"Exact nonroof native mapping and retriangulated roof52 correspondence")
	return {"passed":passed,"moved_corner_indices":indices,"changed_face_indices":faces,"source_XYZ_hex":before.to_byte_array().hex_encode(),"candidate_XYZ_hex":after.to_byte_array().hex_encode(),"unchanged_complement_exact":held,"unchanged_complement_sha256":_sha(kept_before.to_byte_array()),"nonroof_source_to_candidate_mapping_exact":nonroof_mapping,"roof52":{"passed":passed,"face_range":[2387,2439],"render_corner_range":[ROOF_RENDER_START,ROOF_RENDER_END],"source_sha256":ROOF52_SHA,"candidate_sha256":_sha(roof_after.to_byte_array()),"source_XYZ_hex":roof_before.to_byte_array().hex_encode(),"candidate_XYZ_hex":roof_after.to_byte_array().hex_encode(),"moved_corner_indices":roof_moved,"same_face_slots_and_order":false,"actual_source_to_candidate_mapping_exact":false,"topology_replaced":true,"topology_evidence":roof_result.evidence}}

func build(output_dir: String) -> Dictionary:
	if called: return {"passed":false,"failure":"One-call candidate consumed"}
	called=true
	report={"schema":"mush-paving-shape-candidate/2","passed":false,"checks":[],"failures":[],"source_artifact_sha256":INPUT_SHA,"source_manifest_sha256":MANIFEST_SHA,"provenance":PROVENANCE,"geometry_generated_offline":true,"world_assignments":0,"added_triangles":0,"added_draws":0,"art_accepted":false,"traversal_verified":false,"performance_measured":false,"scope":"Four narrowed stone joints; adopted lower geometry retained. Upper soil roof retriangulated with exact native render/contact triangles. Outer32 and diagonal approach ridge retained. No new draw nodes, triangles, lowered stone top planes or runtime generator. Isolated candidate; walking/art/performance unaccepted."}
	var version:=Engine.get_version_info()
	if not _check([version.major,version.minor,version.patch]==[4,7,2] and output_dir.is_absolute_path() and DirAccess.dir_exists_absolute(output_dir) and not FileAccess.file_exists(output_dir.path_join("paving-shape.res")) and not FileAccess.file_exists(output_dir.path_join("paving-shape.json")),"Godot4.7.2/create-only caller output directory"): return report
	if not _check(FileAccess.get_sha256(INPUT)==INPUT_SHA and FileAccess.get_sha256(MANIFEST)==MANIFEST_SHA,"Current192 source/proof pins exact"): return report
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var source:=ResourceLoader.load(INPUT,"MeshLibrary",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	owner=Owner.new()
	if not _check(parsed is Dictionary and source!=null and bool(owner.call("_library_exact",source)),"Material-free three-item source library"): return report
	var proof: Dictionary=parsed; var originals: Array=[]
	for item: int in range(3):
		var mesh:=source.get_item_mesh(item) as ArrayMesh
		if not _check(mesh!=null and mesh.surface_get_array_len(0)==COUNTS[item] and Reader._wire_descriptor_matches(owner.call("_native_prebuilt_record",mesh),proof.expected_native_items[item]),"Current source native arrays/buffers/config",{"item":item}): return report
		source_meshes.append(mesh); arrays.append(mesh.surface_get_arrays(0)); originals.append(owner.call("_native_prebuilt_record",mesh))
	var old_shape:=source.get_item_shapes(0)[0] as ConcavePolygonShape3D
	var before:=old_shape.get_faces(); var shape_config: Dictionary=owner.call("_shape_configuration",old_shape)
	if not _check(before.size()==7323 and _sha(before.to_byte_array())==proof.contact_sha256 and _sha(var_to_bytes(shape_config))==proof.shape_configuration_sha256,"Current native contact/config exact"): return report
	if not _admit_stones() or not _map_stones(): return report
	var source_roof:=before.slice(2387*3,2439*3)
	if not _check(_sha((arrays[2][Mesh.ARRAY_VERTEX] as PackedVector3Array).slice(ROOF_RENDER_START,ROOF_RENDER_END).to_byte_array())==ROOF52_SHA,"Exact source roof render/contact block correspondence"): return report
	var colors: Dictionary={}; var attributes: PackedByteArray=_layout(source_meshes[2]).attribute_data
	for face: int in [44,45,47]:
		for corner: int in range(3):
			var index: int=ROOF_RENDER_START+face*3+corner
			colors[attributes.slice(index*12,index*12+4).hex_encode()]=true
	if not _check(colors.size()==1,"Retriangulated local roof patch has one exact native RGBA8",{"colors":colors.keys()}): return report
	roof_result=Roof.new().build(source_roof,point_map)
	if not _check(roof_result.get("passed",false),"Native replacement roof topology",roof_result.get("evidence",{})): return report
	if not _check(roof_result.evidence.interior_authoring_25_degrees_passed and roof_result.evidence.topology.no_new_steep_coverage_over_source_walkable_within_area_limit,"Native roof walking slope region preservation",{"interior_violations":roof_result.evidence.candidate_quality.interior_25_degree_violations,"new_steep_over_source_walkable_area_m2":roof_result.evidence.topology.new_steep_over_source_walkable_area_m2}): return report
	roof_points=roof_result.triangles
	refit_controls=roof_result.controls
	var source_controls:=_xyz(CUT_CONTROLS)
	for i: int in range(2): point_map[_key(source_controls[i])]=refit_controls[i]
	var meshes: Array[ArrayMesh]=[]
	for item: int in range(3):
		var mesh:=_patch(item)
		if mesh==null: return report
		meshes.append(mesh)
	var contact:=before.duplicate()
	for i: int in range(contact.size()):
		var key:=_key(contact[i])
		if point_map.has(key): contact[i]=point_map[key]
	for i: int in range(roof_points.size()): contact[2387*3+i]=roof_points[i]
	var approach_held:=true
	for face: int in [1986,1988]:
		approach_held=approach_held and before.slice(face*3,face*3+3).to_byte_array()==contact.slice(face*3,face*3+3).to_byte_array()
	if not _check(approach_held,"Diagonal approach soil ridge retained byte-exact"): return report
	if not _verify_geometry(meshes,before,contact): return report
	var contact_proof:=_contact_proof(before,contact)
	if not contact_proof.passed: return report
	var gaps: Array=[]; var foot_rows: Array=[]; var all_new_feet: Array[PackedVector2Array]=[]
	var render_xz: Dictionary={}; var contact_xz: Dictionary={}
	for mesh: ArrayMesh in meshes:
		for p: Vector3 in (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array): render_xz[_xz_key(Vector2(p.x,p.z))]=true
	for p: Vector3 in contact: contact_xz[_xz_key(Vector2(p.x,p.z))]=true
	for pair: int in range(2):
		var new_feet: Array[PackedVector2Array]=[]
		for stone: int in range(pair*2,pair*2+2):
			var polygon:=PackedVector2Array()
			for p: Vector2 in feet[stone]: polygon.append(foot_map[_xz_key(p)])
			new_feet.append(polygon)
			all_new_feet.append(polygon)
			var native_feet:=true
			for p: Vector2 in polygon: native_feet=native_feet and render_xz.has(_xz_key(p)) and contact_xz.has(_xz_key(p))
			if not _check(native_feet,"Actual candidate foot points present in native render and contact",{"stone":stone}): return report
			foot_rows.append({"stone":stone,"pair":pair,"side":"left" if stone%2==0 else "right","source_XZ_hex":FEET[stone],"candidate_XZ_hex":polygon.to_byte_array().hex_encode(),"native_render_contact_verified":native_feet,"source_plane_variant_hex":var_to_bytes(planes[stone]).hex_encode()})
		var overlap:=Geometry2D.intersect_polygons(new_feet[0],new_feet[1])
		if not _check(overlap.is_empty(),"Native narrowed feet do not overlap",{"pair":pair}): return report
		for z: float in ([8.0,8.2,8.5] if pair==0 else [7.0,7.3,7.6]):
			var left:=_span(new_feet[0],z); var right:=_span(new_feet[1],z); var gap: float=right[0]-left[1] if left.size()==2 and right.size()==2 else -1.0
			gaps.append({"pair":pair,"z":z,"before_m":_span(feet[pair*2+1],z)[0]-_span(feet[pair*2],z)[1],"after_m":gap})
			if not _check(gap>=.030 and gap<=.050,"Actual candidate foot joint30–50mm at declared section",gaps[-1]): return report
	if not _seams(meshes,all_new_feet): return report
	var outside:=_xyz(OUTER32); var controls:=_xyz(CUT_CONTROLS)
	# The corrected 32-station boundary includes an extra station before the
	# retained cut endpoint; index 17 belonged to the older 30-station boundary.
	var cut:=PackedVector2Array([Vector2(outside[3].x,outside[3].z),Vector2(controls[0].x,controls[0].z),Vector2(controls[1].x,controls[1].z),Vector2(outside[18].x,outside[18].z)])
	var new_cut:=PackedVector2Array([cut[0],Vector2(refit_controls[0].x,refit_controls[0].z),Vector2(refit_controls[1].x,refit_controls[1].z),cut[3]])
	var shape:=old_shape.duplicate(true) as ConcavePolygonShape3D; shape.set_faces(contact)
	if not _check(var_to_bytes(owner.call("_shape_configuration",shape))==var_to_bytes(shape_config),"Existing shape persistent configuration held"): return report
	candidate_library=source.duplicate(true) as MeshLibrary
	for item: int in range(3): candidate_library.set_item_mesh(item,meshes[item])
	candidate_library.set_item_shapes(0,[shape,Transform3D.IDENTITY])
	if not _check(bool(owner.call("_library_exact",candidate_library)),"Three original items/material-free meshes and one contact shape"): return report
	var path:=output_dir.path_join("paving-shape.res")
	if not _check(ResourceSaver.save(candidate_library,path)==OK,"Native candidate save"): return report
	var loaded:=ResourceLoader.load(path,"MeshLibrary",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	var records: Array=[]; var roundtrip: bool=loaded!=null and bool(owner.call("_library_exact",loaded))
	for item: int in range(3):
		var record: Dictionary=owner.call("_native_prebuilt_record",meshes[item]); records.append(record)
		if loaded!=null: roundtrip=roundtrip and var_to_bytes(owner.call("_native_prebuilt_record",loaded.get_item_mesh(item)))==var_to_bytes(record)
	if loaded!=null: roundtrip=roundtrip and (loaded.get_item_shapes(0)[0] as ConcavePolygonShape3D).get_faces().to_byte_array()==contact.to_byte_array() and var_to_bytes(owner.call("_shape_configuration",loaded.get_item_shapes(0)[0]))==var_to_bytes(shape_config)
	for item: int in range(3): roundtrip=roundtrip and var_to_bytes(owner.call("_native_prebuilt_record",source_meshes[item]))==var_to_bytes(originals[item])
	roundtrip=roundtrip and old_shape.get_faces().to_byte_array()==before.to_byte_array()
	if not _check(roundtrip,"Fresh native arrays/config/AABB/buffers/contact roundtrip and source immutability"): return report
	candidate_library=loaded
	report.merge({"passed":true,"gaps":gaps,"manifest":{"original":originals,"candidate":records,"original_contact_sha256":_sha(before.to_byte_array()),"contact_sha256":_sha(contact.to_byte_array()),"contact_corners":contact.size(),"contact_mapping":contact_proof,"roof52":contact_proof.roof52,"feet":foot_rows,"outside_upper_roof_source_XYZ_hex":OUTER32,"outside_upper_roof_candidate_XYZ_hex":OUTER32,"cut_controls_source_XYZ_hex":CUT_CONTROLS,"cut_controls_candidate_XYZ_hex":refit_controls.to_byte_array().hex_encode(),"cut_controls_mapping_verified":true,"cut_source_XZ_hex":cut.to_byte_array().hex_encode(),"cut_candidate_XZ_hex":new_cut.to_byte_array().hex_encode(),"cut_unchanged":cut.to_byte_array()==new_cut.to_byte_array(),"shape_configuration_sha256":_sha(var_to_bytes(shape_config)),"corners":COUNTS},"artifact":{"file":path,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size(),"passed":true},"native_save_reload_exact":true,"source_resources_unchanged":true},true)
	var file:=FileAccess.open(output_dir.path_join("paving-shape.json"),FileAccess.WRITE)
	if file==null: _check(false,"Candidate report output open"); report.passed=false; return report
	file.store_string(JSON.stringify(report,"\t")+"\n"); file.flush(); file.close()
	return report.duplicate(true)

func get_candidate_library() -> MeshLibrary:
	return candidate_library if report.get("passed",false) else null
