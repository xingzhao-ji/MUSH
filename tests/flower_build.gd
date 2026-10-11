extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var factory: Node3D = load("res://tools/author_flower.gd").new()
	var mesh: ArrayMesh = factory.make_flower()
	var old: ArrayMesh = factory._make_flower_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var valid: bool = vertices.size()==282 and normals.size()==282 and uvs.size()==282 and colors.size()==282 and mesh.surface_get_material(0)==null
	var root_corners := 0
	var minimum_area := INF
	var minimum_winding := INF
	var footprint := old.get_aabb().grow(.000001)
	for i: int in range(vertices.size()):
		var v: Vector3 = vertices[i]
		valid = valid and v.is_finite() and v.y>=0.0 and footprint.has_point(v) and normals[i].is_finite() and absf(normals[i].length()-1.0)<.0001 and uvs[i].is_finite()
		if v.y==0.0: root_corners+=1
	for i: int in range(0,vertices.size(),3):
		var cross: Vector3 = (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
		minimum_area = minf(minimum_area,cross.length()*.5)
		minimum_winding = minf(minimum_winding,cross.normalized().dot(normals[i]))
	valid = valid and root_corners==6 and minimum_area>1e-8 and minimum_winding>.99
	for i: int in range(36,252): valid = valid and normals[i].y>0.0
	var file: String = output.path_join("flower.res")
	valid = valid and ResourceSaver.save(mesh,file)==OK
	var restored: ArrayMesh = ResourceLoader.load(file,"",ResourceLoader.CACHE_MODE_IGNORE)
	valid = valid and restored!=null and var_to_bytes(restored.surface_get_arrays(0))==var_to_bytes(arrays) and restored.get_aabb()==mesh.get_aabb()
	var report := {"passed":valid,"triangles":vertices.size()/3,"root_corners":root_corners,"minimum_triangle_area":minimum_area,"minimum_winding_dot":minimum_winding,"original_aabb":str(old.get_aabb()),"candidate_aabb":str(mesh.get_aabb()),"bytes":FileAccess.get_file_as_bytes(file).size(),"sha256":FileAccess.get_sha256(file),"channels":[]}
	for channel: Variant in restored.surface_get_arrays(0):
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(channel)); report.channels.append(hash.finish().hex_encode())
	var pinned: ArrayMesh=load("res://baked/ground-flower.res")
	report["pinned_native_exact"]=pinned.get_surface_count()==1 and pinned.surface_get_material(0)==null and pinned.get_script()==null and pinned.get_aabb()==restored.get_aabb() and pinned.surface_get_format(0)==restored.surface_get_format(0) and pinned.surface_get_primitive_type(0)==restored.surface_get_primitive_type(0) and var_to_bytes(pinned.surface_get_arrays(0))==var_to_bytes(restored.surface_get_arrays(0))
	valid=valid and report.pinned_native_exact
	report["passed"]=valid
	FileAccess.open(output.path_join("flower.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	factory.free()
	print("FLOWER_BUILD ",JSON.stringify(report))
	quit(0 if valid else 2)
