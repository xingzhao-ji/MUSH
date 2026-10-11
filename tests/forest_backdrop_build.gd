extends "res://tests/paving_surface.gd"
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not output.begins_with(ProjectSettings.globalize_path("res://reports/")): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	if game.get("environment_controller")==null: game._quit_clean(2); return
	if game.world.forest_backdrop==null or not game.world.forest_backdrop.restore_original(): game._quit_clean(2); return
	var report: Dictionary=load("res://tools/author_forest_backdrop.gd").build(game.world)
	if report.get("passed",true)==false:
		FileAccess.open(output.path_join("seam-failure.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		game._quit_clean(2); return
	var rows: Array=[]; var passed: bool=report.seam_vertices==202
	for node: MeshInstance3D in game.world.get_node("ForestGroundTrial").get_children():
		var names: Dictionary={"DistantSoilWest":"forest-ground-west.res","DistantSoilEast":"forest-ground-east.res","DistantStreamTrial":"forest-stream.res"}
		if not names.has(str(node.name)): game._quit_clean(2); return
		var name: String=names[str(node.name)]
		var path:=output.path_join(name)
		var mesh: ArrayMesh=node.mesh
		passed=passed and ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK
		var loaded: ArrayMesh=ResourceLoader.load(path,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE)
		var native:=mesh.surface_get_arrays(0); var channels: Array=[]
		var geometry:=_valid_mesh(loaded)
		passed=passed and geometry.passed
		for channel: int in range(Mesh.ARRAY_MAX):
			var digest:=_sha(var_to_bytes(native[channel])); channels.append(digest)
			passed=passed and digest==_sha(var_to_bytes(loaded.surface_get_arrays(0)[channel]))
		var pinned: ArrayMesh=load("res://baked/"+name)
		var exact: bool=var_to_bytes(pinned.surface_get_arrays(0))==var_to_bytes(loaded.surface_get_arrays(0)) and pinned.get_aabb()==loaded.get_aabb() and pinned.surface_get_format(0)==loaded.surface_get_format(0)
		passed=passed and exact
		rows.append({"pinned_native_exact":exact,"file":name,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.open(path,FileAccess.READ).get_length(),"channels":channels,"bounds":str(loaded.get_aabb()),"triangles":loaded.get_faces().size()/3,"geometry":geometry,"arrays_sha256":_sha(var_to_bytes(native))})
	var source: MeshInstance3D=game.world.get_node(report.water_node)
	var successor: MeshInstance3D=game.world.get_node("ForestGroundTrial/DistantStreamTrial")
	var original:=source.mesh.surface_get_arrays(0); var changed:=successor.mesh.surface_get_arrays(0)
	var prefix: Array=[]
	for channel: int in range(Mesh.ARRAY_MAX):
		var same: bool=changed[channel]==null if original[channel]==null else var_to_bytes(original[channel])==var_to_bytes(changed[channel].slice(0,original[channel].size()))
		prefix.append(same); passed=passed and same
	report["water_prefix_channels"]=prefix
	report["water_source_arrays_sha256"]=_sha(var_to_bytes(original))
	report["water_source_transform"]=str(source.transform)
	report["water_source_path"]=str(game.world.get_path_to(source))
	report["soil_arrays_sha256"]=_sha(var_to_bytes(game.world.get_node("BatchedStaticWorld/Static_-9223371995029174788_0_0").mesh.surface_get_arrays(0)))
	report["files"]=rows; report["passed"]=passed
	FileAccess.open(output.path_join("backdrop-build.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BACKDROP_BUILD ",passed)
	game._quit_clean(0 if passed else 2)

func _valid_mesh(mesh: ArrayMesh) -> Dictionary:
	var a:=mesh.surface_get_arrays(0); var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]; var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]; var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]; var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	var good: bool=mesh.get_surface_count()==1 and mesh.surface_get_material(0)==null and mesh.get_script()==null and ix.size()%3==0 and n.size()==v.size() and uv.size()==v.size()
	var area:=INF; var winding:=INF; var used: Dictionary={}
	for i: int in range(v.size()): good=good and v[i].is_finite() and n[i].is_finite() and uv[i].is_finite() and absf(n[i].length()-1.0)<.001
	for i: int in ix: good=good and i>=0 and i<v.size(); used[i]=true
	if good:
		for offset: int in range(0,ix.size(),3):
			var cross: Vector3=(v[ix[offset+2]]-v[ix[offset]]).cross(v[ix[offset+1]]-v[ix[offset]])
			area=minf(area,cross.length()*.5)
			for corner: int in range(3): winding=minf(winding,cross.normalized().dot(n[ix[offset+corner]]))
	good=good and area>1e-8 and winding>0.0 and used.size()==v.size()
	return {"passed":good,"vertices":v.size(),"minimum_area":area,"minimum_winding_dot":winding,"unused_vertices":v.size()-used.size()}
