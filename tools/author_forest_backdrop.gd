extends RefCounted
## Offline authoring: native render seams, coarse exterior soil and stream extension.
## Runtime only loads the saved resources; this constructor is not called on startup.
static func build(world: Node3D) -> Dictionary:
	var parent:=Node3D.new(); parent.name="ForestGroundTrial"; world.add_child(parent)
	var report: Dictionary={"meshes":[],"draw_nodes":0,"triangles":0,"seam_vertices":0,"new_colliders":0}
	for side: int in range(2):
		var x0: float=-24.0 if side==0 else 10.2
		var x1: float=7.8 if side==0 else 25.0
		var points: Dictionary={}; var xs: Array[float]=[]; var zs: Array[float]=[]
		var soil: MeshInstance3D=world.get_node("BatchedStaticWorld/Static_-9223371995029174788_0_0")
		for local: Vector3 in soil.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3=soil.global_transform*local
			if point.x<x0-.00001 or point.x>x1+.00001 or point.z < -24.00001 or point.z>29.00001: continue
			var on_x:=absf(point.x-(x0 if side==0 else x1))<.00001
			var on_z:=absf(point.z+24.0)<.00001 or absf(point.z-29.0)<.00001
			if not on_x and not on_z: continue
			var key:=Vector2i(roundi(point.x*100000),roundi(point.z*100000))
			assert(not points.has(key) or points[key]==point)
			points[key]=point
			if on_z and not point.x in xs: xs.append(point.x)
			if on_x and not point.z in zs: zs.append(point.z)
		assert(xs.size()==(33 if side==0 else 16) and zs.size()==54)
		for x: float in ([-64.0,-52.0,-42.0,-34.0,-29.0,-26.0] if side==0 else [27.0,30.0,35.0,43.0,53.0,65.0]): xs.append(x)
		zs.append_array([-64.0,-52.0,-42.0,-34.0,-28.0,-26.0,31.0,34.0,39.0,47.0,57.0,69.0])
		xs.sort(); zs.sort()
		var vertices:=PackedVector3Array(); var normals:=PackedVector3Array(); var uv:=PackedVector2Array(); var colors:=PackedColorArray(); var indices:=PackedInt32Array()
		var native: Dictionary={}
		for zi: int in range(zs.size()):
			for xi: int in range(xs.size()):
				var x: float=xs[xi]; var z: float=zs[zi]
				var key:=Vector2i(roundi(x*100000),roundi(z*100000))
				var point:=Vector3(x,_height(world,x,z),z)
				if points.has(key): point=points[key]; report.seam_vertices+=1
				vertices.append(point); normals.append(Vector3.ZERO); uv.append(Vector2(x,z)); colors.append(Color(.92,1.0,.82))
				native[Vector2i(xi,zi)]=vertices.size()-1
		for zi: int in range(zs.size()-1):
			for xi: int in range(xs.size()-1):
				var cx: float=(xs[xi]+xs[xi+1])*.5; var cz: float=(zs[zi]+zs[zi+1])*.5
				if cx>x0 and cx<x1 and cz> -24.0 and cz<29.0: continue
				var a: int=native[Vector2i(xi,zi)]; var b: int=native[Vector2i(xi+1,zi)]
				var c: int=native[Vector2i(xi+1,zi+1)]; var d: int=native[Vector2i(xi,zi+1)]
				indices.append_array([a,b,c,a,c,d])
		for offset: int in range(0,indices.size(),3):
			var a: int=indices[offset]; var b: int=indices[offset+1]; var c: int=indices[offset+2]
			var normal: Vector3=(vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
			assert(normal.y>0.0)
			normals[a]+=normal; normals[b]+=normal; normals[c]+=normal
		for index: int in range(normals.size()): normals[index]=normals[index].normalized() if normals[index].length_squared()>.00001 else Vector3.UP
		var compact_vertices:=PackedVector3Array(); var compact_normals:=PackedVector3Array(); var compact_uv:=PackedVector2Array(); var compact_colors:=PackedColorArray(); var compact_indices:=PackedInt32Array(); var remap: Dictionary={}
		for old: int in indices:
			if not remap.has(old):
				remap[old]=compact_vertices.size(); compact_vertices.append(vertices[old]); compact_normals.append(normals[old]); compact_uv.append(uv[old]); compact_colors.append(colors[old])
			compact_indices.append(remap[old])
		vertices=compact_vertices; normals=compact_normals; uv=compact_uv; colors=compact_colors; indices=compact_indices
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance3D.new(); node.name="DistantSoilWest" if side==0 else "DistantSoilEast"
		node.mesh=mesh; node.material_override=world._materials.soil; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(node)
		report.draw_nodes+=1; report.triangles+=indices.size()/3
		report.meshes.append({"vertices":vertices.size(),"triangles":indices.size()/3,"seam_native_points":points.size(),"render_seam_exact":true,"bounds":str(mesh.get_aabb())})
	_water(world,parent,report)
	return report

static func _height(world: Node3D,x: float,z: float) -> float:
	var distance: float=maxf(maxf(-24.0-x,x-25.0),maxf(-24.0-z,z-29.0))
	var t: float=smoothstep(3.0,24.0,distance)
	var valley: float=smoothstep(1.2,12.0,absf(x-9.0)) if z>29.0 else 1.0
	return world._ground_height(x,z)+valley*t*(2.5+1.0*sin(x*.12+z*.045)+.8*cos(z*.15-x*.035))

static func _water(world: Node3D,parent: Node3D,report: Dictionary) -> void:
	var source: MeshInstance3D
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		if node.material_override==world._water_material: source=node; break
	assert(source!=null)
	var mesh: Mesh=source.mesh
	var arrays: Array=mesh.surface_get_arrays(0).duplicate(true)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var tangent: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	assert(indices.size()>0 and arrays[Mesh.ARRAY_COLOR]==null)
	# Preserve original complete arrays as prefix. Additional local-Z rows continue
	# the same world-space wave, flow, lighting and pause-aware uniforms.
	var old_vertices:=vertices.size(); var old_indices:=indices.size()
	var edge:=PackedInt32Array()
	var end_z: float=-INF
	for v: Vector3 in vertices: end_z=maxf(end_z,v.z)
	for i: int in range(vertices.size()):
		if vertices[i].z==end_z: edge.append(i)
	var ordered: Array[int]=[]; ordered.assign(edge)
	ordered.sort_custom(func(a: int,b: int)->bool: return vertices[a].x<vertices[b].x)
	assert(ordered.size()==7)
	var previous: Array[int]=ordered.duplicate()
	for row: int in range(1,45):
		var current: Array[int]=[]
		for index: int in ordered:
			var v:=vertices[index]; v.z+=float(row)
			current.append(vertices.size()); vertices.append(v); normals.append(normals[index]); uv.append(uv[index]+Vector2(0,float(row)/50.0))
			for component: int in range(4): tangent.append(tangent[index*4+component])
		for column: int in range(6): indices.append_array([previous[column],previous[column+1],current[column+1],previous[column],current[column+1],current[column]])
		previous=current
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_TANGENT]=tangent; arrays[Mesh.ARRAY_INDEX]=indices
	var merged:=ArrayMesh.new(); merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new(); node.name="DistantStreamTrial"; node.mesh=merged; node.transform=source.global_transform; node.material_override=source.material_override; node.cast_shadow=source.cast_shadow; node.extra_cull_margin=source.extra_cull_margin; parent.add_child(node)
	report["water_node"]=str(world.get_path_to(source)); report["water_added_triangles"]=(indices.size()-old_indices)/3; report["water_original_vertices"]=old_vertices; report["water_added_vertices"]=vertices.size()-old_vertices
