extends Node
## Runtime measurements: wall-clock frames + renderer CPU/GPU, raw per-frame CSV.
const ROUTE: Array[Vector3] = [Vector3(-1,0,11),Vector3(4,0,9),Vector3(6.7,0,7.5),Vector3(11.3,0,7.5),Vector3(14,0,2),Vector3(12,0,-6),Vector3(11.4,0,-7.5),Vector3(6.8,0,-7.5),Vector3(5,0,-9),Vector3(-5,0,-7),Vector3(-7,0,5),Vector3(-1,0,11),Vector3(0,.6,5.7),Vector3(0,.6,3.5),Vector3(0,.6,1.4),Vector3(0,.6,0),Vector3(-1.8,.6,.1),Vector3(0,.6,0),Vector3(0,.6,1.4),Vector3(0,0,5.7),Vector3(-2,0,18)]
var game:Node
var scenario:String="day"
var repetition:int=1
var duration:float=300
var warmup:float=30
var elapsed:float=0
var step:int=0
var route_loops_completed:int=0
var raw:FileAccess
var output:String="user://verification"
var frame_times:Array[float]=[]
var cpu_times:Array[float]=[]
var gpu_times:Array[float]=[]
var max_memory:float=0
var start_memory:float=0
var last_tick:int=0
var stalls:int=0
var stalled_time:float=0
var last_pos:Vector3
var movie:bool=false
var mobile_probe:bool=false
var target_resolution:=Vector2i(1920,1080)
var save_ms:float=0
var rss_samples:Array=[]
var pipeline_draw_at_start:float=0
var pacing_at_start:Dictionary={}
var draw_counts:Array[int]=[]
var last_draw_count:int=0
var draw_count_before_first_sample:int=0

func _ready() -> void:
	game=get_parent()
	var args:PackedStringArray=OS.get_cmdline_user_args()
	movie="--traversal" in args
	mobile_probe="--mobile-renderer-probe" in args
	for i in range(args.size()-1):
		match args[i]:
			"--scenario": scenario=args[i+1]
			"--repetition": repetition=int(args[i+1])
			"--duration": duration=float(args[i+1])
			"--warmup": warmup=float(args[i+1])
			"--report-dir": output=args[i+1]
	if movie: duration=45; warmup=0
	# Set both canvas and window sizes, as in the verified native image capture.
	# CLI window dimensions alone can leave an oversampled root render target.
	# MovieWriter fixes its encoded extent before this scene changes window size.
	# Keep the established720p initial extent for the whole capture.
	target_resolution = Vector2i(1280,720) if movie or mobile_probe else Vector2i(1920,1080)
	game.get_window().content_scale_size=target_resolution
	game.get_window().content_scale_factor=1.0
	game.get_window().size=target_resolution
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().physics_frame
	game._explore()
	game.ui.hide()
	game.save_timer=-1
	game.door_state="open"
	game.world.door_hinge.rotation.y=deg_to_rad(-95)
	game.set_appearance("day" if scenario=="day" else "night","rain" if scenario=="worst" else "sunny")
	if scenario!="day": game.player.set_glow(true)
	if scenario=="worst":
		game.world.set_room_ready(true)
		game.room_ready=true
		for socket:String in game.SOCKETS: game.furniture[socket]=socket.split("_")[1]+"_moss"
		game._rebuild_furniture()
		for i in range(8):
			game.garden.append({"id":"bench_%d"%i,"type":"moonbell","position":[-5.5+float(i%4)*.5,0,2.8+float(i/4)*.9],"state":"bloomed","transaction_id":"benchmark"})
		game._rebuild_garden()
		game.restoration_state="bloomed"
		game.restoration_tx="benchmark"
		game.resident_awake=true
		game.path_restored=true
		game._update_patch(1)
	var begin:int=Time.get_ticks_usec()
	game._save_now()
	save_ms=(Time.get_ticks_usec()-begin)/1000.0
	game.player.teleport_safe(Vector3(-2,0,18),0)
	await get_tree().create_timer(.6).timeout
	if not movie and Vector2i(get_viewport().get_texture().get_size())!=target_resolution:
		push_error("Benchmark render target must be exactly "+str(target_resolution)+"; actual: "+str(get_viewport().get_texture().get_size()))
		game._quit_clean(2)
		return
	game.player.enabled=true
	last_pos=game.player.position
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	raw=FileAccess.open(output.path_join("%s-%d.csv"%[scenario,repetition]),FileAccess.WRITE)
	raw.store_line("time_s,frame_ms,cpu_render_ms,gpu_render_ms,process_ms,physics_ms,static_memory_bytes,render_memory_bytes,draw_calls,objects,primitives,player_x,player_y,player_z,route_step,pipeline_draw_compilations,camera_fade,first_mesh_transparency,cream_emission_enabled")
	last_tick=Time.get_ticks_usec()
	last_draw_count=Engine.get_frames_drawn()
	start_memory=Performance.get_monitor(Performance.MEMORY_STATIC)
	pipeline_draw_at_start=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	pacing_at_start=_pacing_state()
	print("BENCHMARK_STARTED ",scenario," repetition=",repetition," warmup=",warmup," capture=",duration)

func _pacing_state() -> Dictionary:
	var screen: int = DisplayServer.window_get_current_screen()
	return {"screen":screen,"refresh_hz":DisplayServer.screen_get_refresh_rate(screen),"max_fps":Engine.max_fps,"low_processor_usage_mode":OS.low_processor_usage_mode,"vsync":DisplayServer.window_get_vsync_mode(),"unfocusable":game.get_window().unfocusable,"mouse_passthrough":game.get_window().mouse_passthrough}

func _physics_process(delta:float) -> void:
	if not is_instance_valid(game) or raw==null: return
	var p:Vector3=game.player.position
	var target:Vector3=ROUTE[step]
	var offset:Vector3=target-p
	offset.y=0
	if offset.length()<.35:
		step=(step+1)%ROUTE.size()
		if step==0: route_loops_completed+=1
		Input.action_release("move_forward")
		stalled_time=0
	else:
		game.player.camera_yaw=atan2(-offset.x,-offset.z)
		Input.action_press("move_forward")
	if p.distance_to(last_pos)<.003 and offset.length()>.5: stalled_time+=delta
	else: stalled_time=0
	if stalled_time>4:
		stalls+=1
		print("BENCHMARK_ROUTE_STALL step=",step," position=",p)
		# Do not hide a navigation failure by teleporting. Keep metric + stalled route.
		stalled_time=0
	last_pos=p
	if movie:
		if elapsed>12 and elapsed<16: Input.action_press("float")
		else: Input.action_release("float")

func _process(_delta:float) -> void:
	if raw==null: return
	var drawn_now:int=Engine.get_frames_drawn()
	var drawn_before:int=last_draw_count
	last_draw_count=drawn_now
	var now:int=Time.get_ticks_usec()
	var dt:float=(now-last_tick)/1000.0
	last_tick=now
	elapsed+=_delta if movie else dt/1000.0
	if elapsed<warmup: return
	if draw_counts.is_empty(): draw_count_before_first_sample=drawn_before
	draw_counts.append(drawn_now)
	var rid:RID=get_viewport().get_viewport_rid()
	var cpu:float=RenderingServer.viewport_get_measured_render_time_cpu(rid)+RenderingServer.get_frame_setup_time_cpu()
	var gpu:float=RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var memory:float=Performance.get_monitor(Performance.MEMORY_STATIC)
	max_memory=maxf(max_memory,memory)
	frame_times.append(dt)
	cpu_times.append(cpu)
	gpu_times.append(gpu)
	var p:Vector3=game.player.position
	raw.store_line("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.0f,%.0f,%.0f,%.0f,%.0f,%.4f,%.4f,%.4f,%d,%.0f,%s,%s,%d"%[elapsed-warmup,dt,cpu,gpu,Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,memory,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),p.x,p.y,p.z,step,Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),game.player._camera_fade,game.player._meshes[0].transparency,int(game.player._cream.emission_enabled)])
	if elapsed>=warmup+duration: _finish()

func _percentile(values:Array[float],percent:float) -> float:
	var sorted:Array[float]=values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(ceil(percent*sorted.size())-1))] if not sorted.is_empty() else 0.0

func _draw_progress() -> Dictionary:
	var previous:int=draw_count_before_first_sample
	var undrawn:int=0; var backwards:int=0
	for count:int in draw_counts:
		if count==previous: undrawn+=1
		if count<previous: backwards+=1
		previous=count
	return {"schema":"mush-benchmark-render-progress/1","counter":"Engine.get_frames_drawn","before_first_sample":draw_count_before_first_sample,"sample_counts":draw_counts,"undrawn_callbacks":undrawn,"backwards_callbacks":backwards,"valid":not draw_counts.is_empty() and draw_counts.size()==frame_times.size() and undrawn==0 and backwards==0,"scope":"Engine draw advancement before every measured process sample; not viewport pixels or display presentation. No explicit redraws are issued."}

func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("float")
	raw.flush()
	raw.close()
	raw=null
	var result:Dictionary={"build":ProjectSettings.get_setting("application/config/version","unknown"),"engine":Engine.get_version_info().string,"exported":not OS.has_feature("editor"),"scenario":scenario,"repetition":repetition,"warmup_s":warmup,"capture_s":duration,"frames":frame_times.size(),"resolution":[get_window().size.x,get_window().size.y],"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"os":OS.get_name()+" "+OS.get_version(),"cpu":OS.get_processor_name(),"physical_memory_bytes":OS.get_memory_info().get("physical",0),"vsync":DisplayServer.window_get_vsync_mode(),"physics_hz":Engine.physics_ticks_per_second,"frame_p95_ms":_percentile(frame_times,.95),"frame_p99_ms":_percentile(frame_times,.99),"cpu_render_p95_ms":_percentile(cpu_times,.95),"gpu_render_p95_ms":_percentile(gpu_times,.95),"gpu_timing_available":_percentile(gpu_times,.95)>0,"static_memory_initial_bytes":start_memory,"static_memory_peak_bytes":max_memory,"static_memory_final_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"save_ms":save_ms,"route_stalls":stalls,"route_step":step,"limit_p95_ms":16.7,"limit_p99_ms":33.3}
	# Record live objects, rather than assuming the project defaults reached this viewport.
	var viewport: Viewport = get_viewport()
	var environment: Environment = game.world.environment
	var sun: DirectionalLight3D = game.world.sun
	result["graphics_settings"] = {
		"viewport": {"msaa_3d": int(viewport.msaa_3d), "use_taa": viewport.use_taa, "screen_space_aa": int(viewport.screen_space_aa), "scaling_3d_mode": int(viewport.scaling_3d_mode), "scaling_3d_scale": viewport.scaling_3d_scale, "anisotropic_filtering_level": int(viewport.anisotropic_filtering_level)},
		"ssao": {"enabled": environment.ssao_enabled, "radius": environment.ssao_radius, "intensity": environment.ssao_intensity, "sharpness": environment.ssao_sharpness},
		"ssr": {"enabled": environment.ssr_enabled, "max_steps": environment.ssr_max_steps, "depth_tolerance": environment.ssr_depth_tolerance},
		"glow": {"enabled": environment.glow_enabled, "intensity": environment.glow_intensity, "strength": environment.glow_strength},
		"sun_shadow": {"enabled": sun.shadow_enabled, "angular_distance_degrees": sun.light_angular_distance, "directional_shadow_mode": int(sun.directional_shadow_mode), "max_distance": sun.directional_shadow_max_distance},
		"tonemap_exposure": environment.tonemap_exposure,
		"reduced_effects": bool(game.settings.reduced_effects),
		"reduced_motion": bool(game.settings.reduced_motion),
		"night_amount": float(game.world.night_amount),
		"rain_amount": float(game.world.rain_amount)
	}
	result["render_progress"]=_draw_progress()
	result["render_measurement_valid"]=result.render_progress.valid
	result["measurement_kind"]="fixed_step_traversal_movie" if movie else "wall_clock_native_route"
	result["frame_targets_passed"]=null if movie else result.render_measurement_valid and result.frame_p95_ms<=16.7 and result.frame_p99_ms<=33.3
	if mobile_probe:
		result["measurement_kind"]="short_desktop_renderer_comparison"
		result["frame_targets_passed"]=null
		result.erase("limit_p95_ms")
		result.erase("limit_p99_ms")
		result["physical_device_tested"]=false
		result["phone_performance_measured"]=false
		result["sustained_thermal_measured"]=false
		result["environment"]=game.environment_controller.get_report()
		result["scope"]="Mac source comparison using existing route/frame/render/memory observer. A short route is not a completed loop or sustained phone/thermal/30fps acceptance."
	result["route_waypoint_count"]=ROUTE.size()
	result["render_resolution"]=[get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()]
	result["resolution_valid"]=Vector2i(get_viewport().get_texture().get_size())==target_resolution
	result["static_memory_monitor_available"]=max_memory>0
	result["forest_middle_layer"]=game.world.forest_enclosure
	result["world_load_seconds"]=game.world.snapshot_load_seconds
	result["camera_fade_prewarm"]=game.camera_fade_prewarm.duplicate(true)
	result["rain_near_camera_fade"]=game.world.get_renderer_capabilities_report().get("rain_near_camera_fade",{})
	result["pipeline_draw_compilations_after_start"]=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-pipeline_draw_at_start
	result["build_fingerprint"]=_build_fingerprint()
	result["route_loops_completed"]=route_loops_completed
	result["pacing_at_start"]=pacing_at_start
	result["pacing_at_end"]=_pacing_state()
	result["traversal_measurement_valid"]=stalls==0 and route_loops_completed>0
	var report:=FileAccess.open(output.path_join("%s-%d.json"%[scenario,repetition]),FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"\t"))
	report.close()
	print("BENCHMARK_COMPLETE ",JSON.stringify(result))
	game._quit_clean()

func _build_fingerprint() -> Dictionary:
	var files: Dictionary = {}
	if OS.has_feature("editor"):
		for filename: String in ["scripts/playable.gd","scripts/baked_world.gd","scripts/forest_enclosure.gd","assets/world/fireflies.gdshader","baked/clearing.res","tests/benchmark.gd","scripts/environment_controller.gd","assets/environment/shared_environment.gdshaderinc"]:
			files[filename] = FileAccess.get_sha256("res://"+filename)
		return {"kind":"editor_source","source_sha256":files}
	var resource_dir := OS.get_executable_path().get_base_dir().path_join("../Resources")
	var directory := DirAccess.open(resource_dir)
	if directory:
		for filename: String in directory.get_files():
			if filename.ends_with(".pck"): files[filename] = FileAccess.get_sha256(resource_dir.path_join(filename))
	return {"kind":"native_export","executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"resource_pack_sha256":files}
