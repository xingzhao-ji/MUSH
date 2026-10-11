extends SceneTree
## Reproducible desktop renderer comparison. Fixed clocks/cameras are inspection
## inputs, not production time changes or proof of motion/device performance.
var game: Node3D
var output: String=""
var views: Array[Dictionary]=[]
var started_usec: int=0
var quality: String="balanced"
var scene_material_ids: Dictionary={}

func _initialize() -> void:
	started_usec=Time.get_ticks_usec()
	_run.call_deferred()

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i].begins_with("--report-dir="): output=args[i].trim_prefix("--report-dir=")
		if args[i]=="--report-dir" and i+1<args.size(): output=args[i+1]
		if args[i].begins_with("--quality="): quality=args[i].trim_prefix("--quality=")
	if not output.is_absolute_path() or not output.simplify_path().begins_with(ProjectSettings.globalize_path("res://reports/")) or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output) or quality not in ["low","balanced","high"]:
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	game=load("res://tests/mobile_game_fixture.gd").new()
	root.add_child(game)
	for i in range(5): await physics_frame
	await process_frame
	var coordinator: Node=game.get("environment_controller")
	if not is_instance_valid(coordinator):
		print("MOBILE_RENDERER_CAPTURE_REFUSED: game has no environment coordinator")
		game._quit_clean(2)
		return
	game.ui.hide()
	_scene_materials()
	game.player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.world.set_process(false)
	coordinator.set_process(false)
	coordinator.set_quality(quality)
	for particle: Node in game.world.find_children("*","GPUParticles3D",true,false):
		for property: Dictionary in particle.get_property_list():
			if property.name=="use_fixed_seed": particle.set("use_fixed_seed",true)
			elif property.name=="seed": particle.set("seed",5757)
	var specifications: Array[Dictionary]=[
		{"name":"calm-day","state":"calm","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"gust","state":"gust","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"sunrise","state":"sunrise","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"sunset","state":"sunset","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"night","state":"night","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"rain","state":"rain","camera":Vector3(6,3.3,20),"target":Vector3(3.2,1.65,0)},
		{"name":"entrance-day","state":"calm","camera":Vector3(-3,2.1,11.5),"target":Vector3(0,.55,5)},
		{"name":"entrance-night","state":"night","camera":Vector3(-3,2.1,11.5),"target":Vector3(0,.55,5)},
		{"name":"indoor","state":"indoor","camera":Vector3(0,1.6,1.8),"target":Vector3(-2,1.2,-2)},
		{"name":"dense","state":"dense","camera":Vector3(15.8,1.7,1.2),"target":Vector3(14,.5,-2)}
	]
	for spec: Dictionary in specifications:
		coordinator.clock_seconds=0.0
		coordinator.detail_clock_seconds=0.0
		coordinator.cloud_offset=Vector3.ZERO
		coordinator.wind_strength=0.24
		coordinator.wetness=0.0
		coordinator._sunset=0.0
		game.world._time=0.0
		game.world._m37_elapsed=0.0
		coordinator.set_inspection_state(spec.state)
		game.world.night_amount=1.0 if spec.state=="night" else 0.0
		game.world.rain_amount=1.0 if spec.state=="rain" else 0.0
		# Literal inspection endpoints must initialize the normal production appearance.
		game.world._apply_appearance()
		game.player.teleport_safe(Vector3(0,.08,0) if spec.state=="indoor" else Vector3(4,.08,14),0.278)
		for i in range(5): await physics_frame
		for i in range(100):
			game.world._process(0.1)
			coordinator._process(0.1)
		game.review_camera.position=spec.camera
		game.review_camera.fov=60.0
		game.review_camera.look_at(spec.target)
		game.review_camera.make_current()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image=root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		var path: String=output.path_join(str(spec.name)+".png")
		var error: int=frame.save_png(path)
		var digest:=HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(frame.get_data())
		var state: Dictionary=coordinator.get_report()
		var appearance: Dictionary=_appearance_readback()
		var active_state: bool=absf(float(state.clock_seconds)-10.0)<0.000001 and bool(state.foreground) and not paused
		var shared: bool=not state.bound_materials.is_empty()
		for material: Dictionary in state.bound_materials: shared=shared and material.enabled==true
		views.append({"name":spec.name,"state":spec.state,"passed":error==OK and frame.get_size()==Vector2i(1280,720) and active_state and shared and bool(appearance.passed),"appearance_readback":appearance,"active_environment_state":active_state,"all_materials_enabled":shared,"png":path.get_file(),"png_sha256":FileAccess.get_sha256(path),"rgba_sha256":digest.finish().hex_encode(),"camera":str(spec.camera),"target":str(spec.target),"vertical_fov":60.0,"night_amount":game.world.night_amount,"rain_amount":game.world.rain_amount,"environment":state,"lighting":game._review_lighting_state()})
	var passed: bool=views.size()==10
	for view: Dictionary in views: passed=passed and bool(view.passed)
	var report: Dictionary={"schema":"mush-mobile-fixed-renderer-capture/2","passed":passed,"build":"0.3.0","engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"quality":quality,"viewport":[1280,720],"snapshot_sha256":FileAccess.get_sha256("res://baked/clearing.res"),"script_sha256":FileAccess.get_sha256("res://tests/mobile_environment_capture.gd"),"wall_seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0,"views":views,"physical_device_tested":false,"motion_quality_verified":false,"sustained_performance_measured":false,"art_approved":false,"scope":"Mac source renderer inspection; same native bake, fixed clocks/cameras/quality. Actual still readbacks do not establish motion, phone performance, thermal or art approval."}
	var file:=FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MOBILE_RENDERER_CAPTURE ",JSON.stringify({"passed":passed,"renderer":report.renderer,"views":views.size()}))
	game._quit_clean(0 if passed else 1)

func _scene_materials() -> void:
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false):
		if node.material_override!=null: scene_material_ids[node.material_override.get_instance_id()]=true
		if node is MeshInstance3D and node.mesh!=null:
			for surface: int in range(node.mesh.get_surface_count()):
				var material: Material=node.get_active_material(surface)
				if material!=null: scene_material_ids[material.get_instance_id()]=true
		elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null and node.material_override==null:
			for surface: int in range(node.multimesh.mesh.get_surface_count()):
				var material: Material=node.multimesh.mesh.surface_get_material(surface)
				if material!=null: scene_material_ids[material.get_instance_id()]=true

func _appearance_readback() -> Dictionary:
	var night: float=game.world.night_amount
	var rain: float=game.world.rain_amount
	var sky: ShaderMaterial=game.world.environment.sky.sky_material as ShaderMaterial
	var sky_night: float=float(sky.get_shader_parameter("night_amount"))
	var sky_rain: float=float(sky.get_shader_parameter("rain_amount"))
	var passed: bool=absf(sky_night-night)<0.000001 and absf(sky_rain-rain)<0.000001
	var gills: Array[Dictionary]=[]
	var emissive_scene_gills: int=0
	for material: ShaderMaterial in game.world._gill_materials:
		var actual: float=float(material.get_shader_parameter("emission_strength"))
		var expected: float=night*float(material.get_meta("emission_scale",0.72))
		var in_scene: bool=scene_material_ids.has(material.get_instance_id())
		passed=passed and absf(actual-expected)<0.000001
		if in_scene and float(material.get_meta("emission_scale",0.72))>0.0: emissive_scene_gills+=1
		gills.append({"material_id":str(material.get_instance_id()),"actual_strength":actual,"expected_strength":expected,"used_by_scene":in_scene})
	passed=passed and emissive_scene_gills>0
	var lighting: Dictionary=game._review_lighting_state()
	passed=passed and lighting.practical_lights.size()==20 and lighting.night_lights.size()==4
	for light: Dictionary in lighting.night_lights:
		passed=passed and absf(float(light.energy)-night*0.9)<0.000001
	for light: Dictionary in lighting.practical_lights:
		passed=passed and float(light.energy)>=0.9 if night>.99 else passed and float(light.energy)<=0.3
	return {"passed":passed,"sky_night_amount":sky_night,"sky_rain_amount":sky_rain,"gills":gills,"emissive_materials_used_by_scene":emissive_scene_gills,"ordinary_appearance_initialized":true,"practical_light_count":lighting.practical_lights.size(),"cool_light_count":lighting.night_lights.size()}
