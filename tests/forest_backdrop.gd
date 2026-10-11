extends "res://tests/paving_surface.gd"
var backdrop: RefCounted
var native_report: Dictionary={}
var camera_rows: Array[Dictionary]=[]
var bodies_before: String

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not output.begins_with(ProjectSettings.globalize_path("res://reports/")): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	controller=game.get("environment_controller")
	if not _check("Actual rendered Main and fresh test profile",controller!=null and game.world.snapshot_loaded and str(game.store.directory).begins_with("user://verification/") and DisplayServer.get_name()!="headless"):
		_finish(); return
	owner=game.world.paving_preview_prebuilt; backdrop=game.world.forest_backdrop
	game.get_window().unfocusable=true; game.get_window().mouse_passthrough=true
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled=false
	await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false); game.player._visual.process_mode=Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false); game.ui.hide(); game.player.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; paused=false
	game.get_window().size=Vector2i(1280,720); game.get_window().content_scale_size=Vector2i(1280,720)
	bodies_before=_bodies()
	_check("Startup install and one actual water-audio alias",game.world.forest_backdrop_report.passed and backdrop.stream.mesh==backdrop.water and controller._water_audio_node==backdrop.stream and controller._water_audio_bounds==backdrop.stream.global_transform*backdrop.water.get_aabb())
	_check("Actual rollback/reinstall keeps the retained water node",backdrop.restore_original() and backdrop.stream.mesh==backdrop.original_water and backdrop.reinstall() and backdrop.stream.mesh==backdrop.water)
	native_report=_native_check()
	print("FOREST_NATIVE ",JSON.stringify(native_report))
	_check("202 exact render seams and bounded inherited collision rounding",native_report.seams==202 and native_report.missing==0 and native_report.collision_pairs==202 and native_report.maximum_collision_delta<.0001)
	_check("All soil faces outside original terrain; no collider additions",native_report.faces==2688 and native_report.inside_faces==0 and backdrop.root.find_children("*","CollisionObject3D",true,false).is_empty() and _bodies()==bodies_before)
	var a: Array=backdrop.original_water.surface_get_arrays(0); var b: Array=backdrop.water.surface_get_arrays(0); var exact:=true
	for channel: int in range(Mesh.ARRAY_MAX): exact=exact and (b[channel]==null if a[channel]==null else var_to_bytes(a[channel])==var_to_bytes(b[channel].slice(0,a[channel].size())))
	_check("All13 original water channels/index prefixes exact;20mm wave culling covered",exact and b[Mesh.ARRAY_VERTEX].size()-a[Mesh.ARRAY_VERTEX].size()==308 and b[Mesh.ARRAY_INDEX].size()-a[Mesh.ARRAY_INDEX].size()==1584 and backdrop.stream.extra_cull_margin>=.02)
	for label: String in ["home-day","side-day","reverse-day","home-night","home-rain"]: await _backdrop_pair(label)
	await _camera_check()
	_finish()

func _native_check() -> Dictionary:
	var result: Dictionary={"seams":0,"missing":0,"collision_pairs":0,"maximum_collision_delta":0.0,"faces":0,"inside_faces":0,"missing_points":[],"unpaired_points":[]}
	var soil: MeshInstance3D=game.world.get_node(backdrop.SOIL_PATH)
	var seams: Dictionary={}; var colliders: Dictionary={}; var candidate_vertices: Dictionary={}
	for p: Vector3 in soil.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if (p.x<=7.80001 or p.x>=10.19999) and (absf(p.x+24.0)<.00001 or absf(p.x-25.0)<.00001 or absf(p.z+24.0)<.00001 or absf(p.z-29.0)<.00001): seams[var_to_bytes(p)]=p
	for node: Node in game.world.get_node("GroundAndPaths").find_children("*","CollisionShape3D",true,false):
		if not node.shape is ConcavePolygonShape3D: continue
		for p: Vector3 in node.shape.get_faces():
			p=node.global_transform*p
			if absf(p.x+24.0)<.00001 or absf(p.x-25.0)<.00001 or absf(p.z+24.0)<.00001 or absf(p.z-29.0)<.00001: colliders[Vector2i(roundi(p.x*1000),roundi(p.z*1000))]=p
	for node: MeshInstance3D in backdrop.root.get_children():
		for p: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: candidate_vertices[var_to_bytes(p)]=true
		var faces: PackedVector3Array=node.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			var outside_left:=true; var outside_right:=true; var outside_rear:=true; var outside_front:=true
			for corner: int in range(3):
				var p: Vector3=faces[index+corner]
				outside_left=outside_left and p.x<=-24.0; outside_right=outside_right and p.x>=25.0
				outside_rear=outside_rear and p.z<=-24.0; outside_front=outside_front and p.z>=29.0
			result.faces+=1
			if not (outside_left or outside_right or outside_rear or outside_front): result.inside_faces+=1
	for key: PackedByteArray in seams:
		result.seams+=1
		if not candidate_vertices.has(key): result.missing+=1; result.missing_points.append(str(seams[key]))
		var p: Vector3=seams[key]; var nearest: float=INF
		# Native collision serialization rounds decimal coordinates. Nearest-point
		# distance avoids a hash-cell boundary inventing a failed correspondence.
		for candidate_point: Vector3 in colliders.values(): nearest=minf(nearest,p.distance_to(candidate_point))
		if nearest<.0001:
			result.collision_pairs+=1; result.maximum_collision_delta=maxf(result.maximum_collision_delta,nearest)
		else: result.unpaired_points.append(str(p))
	return result

func _backdrop_pair(label: String) -> void:
	var night:=label.ends_with("night"); var rain:=label.ends_with("rain")
	var camera:=Vector3(0,2.8,18); var target:=Vector3(0,1.6,0)
	if label=="side-day": camera=Vector3(-12,2.2,7); target=Vector3(-17,1.8,-8)
	if label=="reverse-day": camera=Vector3(0,2.8,6); target=Vector3(0,1.3,25)
	game.review_camera.position=camera; game.review_camera.fov=65; game.review_camera.look_at(target); game.review_camera.make_current()
	controller.set_foreground(true); game.world.set_environment_foreground(true)
	controller.set_inspection_state("rain" if rain else ("night" if night else "calm"))
	game.set_appearance("night" if night else "day","rain" if rain else "sunny")
	await create_timer(4.0).timeout
	controller.set_foreground(false); game.world.set_environment_foreground(false); await _frames(3)
	var held:=_held(); var rest:=_rest()
	for after: bool in [false,true]:
		var ok: bool=backdrop.reinstall() if after else backdrop.restore_original()
		await _frames(10); await RenderingServer.frame_post_draw
		var frame: Image=root.get_texture().get_image(); frame.convert(Image.FORMAT_RGBA8)
		var name:=label+("-after.png" if after else "-before.png")
		ok=ok and frame.get_size()==Vector2i(1280,720) and frame.save_png(output.path_join(name))==OK and _held()==held and _rest()==rest and _bodies()==bodies_before
		_check(name+": frozen context and unrelated geometry/collision exact",ok)
		views.append({"file":name,"passed":ok,"sha256":FileAccess.get_sha256(output.path_join(name)),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	backdrop.reinstall()

func _camera_check() -> void:
	# Query-only test geometry uses a layer absent from player/camera masks. It
	# observes the real camera response against unchanged production colliders.
	var probe:=StaticBody3D.new(); probe.collision_layer=1<<30; probe.collision_mask=0; game.world.add_child(probe)
	for node: MeshInstance3D in backdrop.root.get_children():
		var shape:=ConcavePolygonShape3D.new(); shape.set_faces(node.mesh.get_faces())
		var child:=CollisionShape3D.new(); child.shape=shape; probe.add_child(child)
	await physics_frame; await physics_frame
	var camera_shape: SphereShape3D=game.player._spring_arm.shape
	game.player.set_physics_process(true); game.player.set_process(true)
	for site: Vector3 in [Vector3(-18,0,25.8),Vector3(-8,0,25.8),Vector3(0,0,25.8),Vector3(14,0,25.8),Vector3(19,0,25.8),Vector3(-19.8,0,5),Vector3(19.8,0,5),Vector3(-8,0,-19.8)]:
		var floor_query:=PhysicsRayQueryParameters3D.create(site+Vector3.UP*1.5,site-Vector3.UP,1)
		var support: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(floor_query)
		if support.is_empty(): _check("Camera site has native support",false); continue
		var point: Vector3=support.position+Vector3.UP*.008
		var yaw: float=0.0 if site.z>25 else (PI if site.z< -19 else (-PI*.5 if site.x<0 else PI*.5))
		for pitch: float in [-65.0,-10.0,15.0]:
			game.player._camera_pitch=deg_to_rad(pitch); game.player.teleport_safe(point,yaw)
			for i: int in range(45): await physics_frame
			var camera: Vector3=game.player.get_camera().global_position
			var query:=PhysicsRayQueryParameters3D.create(Vector3(camera.x,10,camera.z),Vector3(camera.x,-2,camera.z),1<<30)
			var hit: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(query)
			var clearance: float=camera.y-float(hit.position.y) if not hit.is_empty() else INF
			var sphere_query:=PhysicsShapeQueryParameters3D.new()
			sphere_query.shape=camera_shape; sphere_query.transform=game.player.get_camera().global_transform
			sphere_query.collision_mask=1<<30; sphere_query.margin=.001
			var sphere_hits: int=game.world.get_world_3d().direct_space_state.intersect_shape(sphere_query,1).size()
			var valid: bool=game.player.global_position.distance_to(point)<.3 and camera.is_finite() and clearance>=.14 and sphere_hits==0
			camera_rows.append({"sphere_radius":camera_shape.radius,"sphere_hits":sphere_hits,"site":str(site),"pitch":pitch,"camera":str(camera),"player":str(game.player.global_position),"over_new_ground":not hit.is_empty(),"clearance_m":clearance if is_finite(clearance) else null,"passed":valid})
	game.player.set_physics_process(false); game.player.set_process(false)
	probe.free(); await physics_frame
	var valid:=camera_rows.size()==24
	for row: Dictionary in camera_rows: valid=valid and row.passed
	_check("24 actual perimeter camera poses clear new visual terrain",valid)
	_check("Query-only test collider removed; original bodies exact",_bodies()==bodies_before)

func _rest() -> String:
	var rows: Array=[]
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false):
		if backdrop.root.is_ancestor_of(node) or node==backdrop.stream: continue
		var mesh: Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null)
		rows.append([node.get_instance_id(),node.transform,mesh.get_instance_id() if mesh!=null else 0,node.material_override.get_instance_id() if node.material_override!=null else 0,node.cast_shadow,node.extra_cull_margin])
	return _sha(var_to_bytes(rows))

func _bodies() -> String:
	var rows: Array=[]; var omit: Array[String]=[]
	for node: Node in game.world.find_children("*","CollisionShape3D",true,false): rows.append([node.get_instance_id(),node.transform,node.disabled,node.shape.get_instance_id(),owner.call("_stored",node.shape,omit),node.get_parent().get_instance_id()])
	return _sha(var_to_bytes(rows))

func _held() -> String:
	return _sha(var_to_bytes([game._review_lighting_state(),game.review_camera.global_transform,game.review_camera.fov,controller.clock_seconds,controller.detail_clock_seconds,controller.cloud_offset,controller.wetness,game.world.night_amount,game.world.rain_amount,_parameters(backdrop.stream.material_override),_parameters(backdrop.root.get_child(0).material_override)]))

func _finish() -> void:
	if backdrop!=null: backdrop.reinstall()
	_check("Ten paired frames complete",views.size()==10)
	var failed:=0
	for row: Dictionary in checks:
		if not row.passed: failed+=1
	FileAccess.open(output.path_join("forest.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":failed==0,"checks":checks,"views":views,"native":native_report,"camera":camera_rows,"motion_verified":false,"art_approved":false,"performance_measured":false},"  "))
	print("FOREST_COMPLETE ",failed," failures")
	if is_instance_valid(game): game._quit_clean(0 if failed==0 else 2)
	else: quit(2)
