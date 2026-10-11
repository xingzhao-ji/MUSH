extends Node
## One natural room-growth transaction in the real exported clearing.
## Post-draw wall intervals are frame cadence, never isolated GPU durations.
const WARMUP_SECONDS: float = 30.0
const BASELINE_SECONDS: float = 3.0
const GROWTH_AND_REVEAL_SECONDS: float = 8.0
const MAX_SECONDS: float = 55.0
var game: Node
var output: String = "user://verification/growth_timing"
var raw: FileAccess
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var failures: Array[String] = []
var phase: String = "setup"
var started_usec: int = 0
var last_draw_usec: int = 0
var last_process_usec: int = 0
var last_process_state: Dictionary = {}
var capture_active: bool = false
var finished: bool = false
var growth_requested: bool = false
var growth_signal_timing: Dictionary = {}
var commit_observation: Dictionary = {}
var first_ready_draw: Dictionary = {}
var first_consistent_physics: Dictionary = {}
var autosave_observation: Dictionary = {}
var durable_save_timing: Dictionary = {}
var fingerprint_start: Dictionary = {}
var room_shapes: Array = []
var plug_shapes: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Observe after the parent without replacing its callbacks or commit method.
	process_priority = 100
	process_physics_priority = 100
	game = get_parent()
	started_usec = Time.get_ticks_usec()
	for index: int in range(OS.get_cmdline_user_args().size()-1):
		if OS.get_cmdline_user_args()[index] == "--report-dir":
			output = OS.get_cmdline_user_args()[index+1]
	call_deferred("_run")


func _run() -> void:
	if not bool(game.verification):
		_fail("Growth timing requires the game's private verification mode.")
		_finish()
		return
	fingerprint_start = _build_fingerprint()
	game.store.directory = "user://verification/growth_timing_%d" % OS.get_process_id()
	game._reset_world()
	game._explore()
	game.player.teleport_safe(Vector3(1.5,0.6,0.6),0.0)
	game.get_window().content_scale_size = Vector2i(1920,1080)
	game.get_window().content_scale_factor = 1.0
	game.get_window().size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.set_appearance("day","sunny")
	game.review_camera.position = Vector3(10.0,4.2,15.0)
	game.review_camera.fov = 60.0
	game.review_camera.look_at(Vector3(2.2,1.7,0.2))
	game.review_camera.make_current()
	room_shapes = game.world.get("_room_colliders")
	plug_shapes = game.world.get("_plug_colliders")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	await get_tree().create_timer(0.6).timeout
	if finished: return
	_check(Vector2i(get_viewport().get_texture().get_size()) == Vector2i(1920,1080), "The actual render target must be 1920x1080.")
	_check(Engine.physics_ticks_per_second == 60, "The existing physics frequency must remain 60 Hz.")
	_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync must be disabled.")
	_check(not game.room_ready and not game.room_growing, "The fixture must begin with no completed or growing room.")
	if not failures.is_empty():
		_finish()
		return
	phase = "warmup"
	_event("warmup_begin")
	await get_tree().create_timer(WARMUP_SECONDS).timeout
	if finished: return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create the diagnostic report directory.")
		_finish()
		return
	raw = FileAccess.open(output.path_join("growth-timing.csv"),FileAccess.WRITE)
	if raw == null:
		_fail("Cannot open the diagnostic CSV.")
		_finish()
		return
	raw.store_line("monotonic_usec,elapsed_s,frame_post_draw_interval_ms,process_frame,physics_frame,phase,growth_clock_s,mana,room_growing,room_ready,world_room_ready,room_visible,room_scale,wall_plug_visible,room_shapes_enabled,room_shapes_total,plug_shapes_enabled,plug_shapes_total,reservation_layer,dirty,save_timer_s,cpu_render_ms,gpu_render_ms")
	capture_active = true
	phase = "baseline"
	_event("baseline_begin")
	await get_tree().create_timer(BASELINE_SECONDS).timeout
	if finished: return
	game._growth_menu()
	var grow_button: Button = _find_button("Grow this room")
	if grow_button == null or grow_button.disabled:
		_fail("The ordinary Grow this room UI action is unavailable.")
		_finish()
		return
	phase = "growth"
	var before_state: Dictionary = _state()
	var signal_before_usec: int = Time.get_ticks_usec()
	grow_button.pressed.emit()
	var signal_after_usec: int = Time.get_ticks_usec()
	growth_signal_timing = {
		"before_usec":signal_before_usec,"after_usec":signal_after_usec,
		"duration_ms":float(signal_after_usec-signal_before_usec)/1000.0,
		"before_state":before_state,"after_state":_state(),
		"scope":"Accepted Grow this room pressed signal, including normal obstruction checks, stable pre-growth save, growth setup and return to exploration. This is not isolated save or commit CPU time."
	}
	growth_requested = bool(game.room_growing)
	_check(growth_requested and not game.room_ready, "The accepted UI action must start one incomplete room transaction.")
	_event("grow_button_signal_returned")
	if not growth_requested:
		_finish()
		return
	# Do not call _finish_growth or skip the animation. The real parent physics
	# timer owns its normal completion, deferred collision changes and autosave.
	await get_tree().create_timer(GROWTH_AND_REVEAL_SECONDS).timeout
	if finished: return
	_check(not commit_observation.is_empty(), "Natural growth completion must be observed between ordinary child callbacks.")
	_check(not first_ready_draw.is_empty(), "A post-draw callback must observe the completed visible room.")
	_check(not first_consistent_physics.is_empty(), "A later physics boundary must observe settled room/plug collision and a supporting room floor.")
	_check(game.room_ready and not game.room_growing, "The natural transaction must finish without a duplicate request.")
	_check(not autosave_observation.is_empty(), "The normal scheduled post-growth save must finish.")
	phase = "explicit_durable_save"
	var save_before_usec: int = Time.get_ticks_usec()
	var save_ok: bool = game._save_now()
	var save_after_usec: int = Time.get_ticks_usec()
	durable_save_timing = {
		"before_usec":save_before_usec,"after_usec":save_after_usec,
		"duration_ms":float(save_after_usec-save_before_usec)/1000.0,"ok":save_ok,
		"scope":"Explicit synchronous normal _save_now after natural completion and its scheduled autosave. Includes snapshot validation, file writing and native replacement; separate from rendering-frame cadence."
	}
	_check(save_ok,"The explicit normal durable save must succeed.")
	_event("explicit_durable_save_returned")
	phase = "post_save"
	await get_tree().create_timer(1.0).timeout
	if finished: return
	var loaded: Dictionary = game.store.load_snapshot()
	_check(bool(loaded.get("ok",false)) and bool(loaded.get("data",{}).get("room_right",false)), "The private validated primary must contain the completed room.")
	_finish()


func _process(_delta: float) -> void:
	if finished: return
	var now_usec: int = Time.get_ticks_usec()
	if float(now_usec-started_usec)/1000000.0 > MAX_SECONDS:
		_fail("The bounded growth diagnostic exceeded 55 seconds.")
		_finish()
		return
	if not capture_active: return
	var current_state: Dictionary = _state()
	if growth_requested and commit_observation.is_empty() and bool(current_state.room_ready) and not bool(current_state.room_growing):
		commit_observation = {
			"previous_child_callback_usec":last_process_usec,"observed_child_callback_usec":now_usec,
			"callback_interval_ms":float(now_usec-last_process_usec)/1000.0,
			"previous_state":last_process_state.duplicate(true),"observed_state":current_state.duplicate(true),
			"scope":"Natural parent-owned completion observed after the parent callback. The actual commit lies within this observation bracket; no isolated method duration is measured."
		}
		phase = "post_commit"
		_event("natural_commit_observed")
	if not commit_observation.is_empty() and autosave_observation.is_empty() and bool(last_process_state.get("dirty",false)) and not bool(current_state.dirty) and float(current_state.save_timer_s) < 0.0:
		autosave_observation = {
			"previous_child_callback_usec":last_process_usec,"observed_child_callback_usec":now_usec,
			"scope":"Normal scheduled autosave observed by dirty true-to-false and an expired save timer. The callback bracket is not isolated save duration."
		}
		_event("normal_autosave_observed")
	last_process_usec = now_usec
	last_process_state = current_state


func _physics_process(_delta: float) -> void:
	if finished or not growth_requested or not first_consistent_physics.is_empty() or not bool(game.room_ready): return
	var state: Dictionary = _state()
	if int(state.room_shapes_total) == 0 or int(state.plug_shapes_total) == 0: return
	if int(state.room_shapes_enabled) != int(state.room_shapes_total) or int(state.plug_shapes_enabled) != 0 or int(state.reservation_layer) != 0: return
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(4.95,1.0,0.6),Vector3(4.95,0.4,0.6),1|4|16,[game.player.get_rid()])
	var floor: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if floor.is_empty() or absf(float(floor.position.y)-0.6) > 0.05: return
	first_consistent_physics = {
		"monotonic_usec":Time.get_ticks_usec(),"state":state,
		"floor_position":[floor.position.x,floor.position.y,floor.position.z],
		"floor_collider":str(floor.collider.name),
		"scope":"First observed physics callback after deferred room/plug collision settings settle, with an actual supporting room-floor ray."
	}
	_event("settled_room_collision_and_floor_observed")


func _on_frame_post_draw() -> void:
	var now_usec: int = Time.get_ticks_usec()
	var previous_draw_usec: int = last_draw_usec
	last_draw_usec = now_usec
	if finished or not capture_active or raw == null or previous_draw_usec == 0: return
	var state: Dictionary = _state()
	var interval_ms: float = float(now_usec-previous_draw_usec)/1000.0
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	var cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)+RenderingServer.get_frame_setup_time_cpu()
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	var sample: Dictionary = {"monotonic_usec":now_usec,"previous_post_draw_usec":previous_draw_usec,"frame_ms":interval_ms,"phase":phase,"state":state,"cpu_render_ms":cpu_ms,"gpu_render_ms":gpu_ms}
	frames.append(sample)
	if growth_requested and first_ready_draw.is_empty() and bool(state.room_ready) and bool(state.room_visible) and is_equal_approx(float(state.room_scale),1.0):
		first_ready_draw = sample.duplicate(true)
	raw.store_line("%d,%.6f,%.6f,%d,%d,%s,%.6f,%.6f,%d,%d,%d,%d,%.6f,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f" % [now_usec,float(now_usec-started_usec)/1000000.0,interval_ms,state.process_frame,state.physics_frame,phase,state.growth_clock_s,state.mana,int(state.room_growing),int(state.room_ready),int(state.world_room_ready),int(state.room_visible),state.room_scale,int(state.wall_plug_visible),state.room_shapes_enabled,state.room_shapes_total,state.plug_shapes_enabled,state.plug_shapes_total,state.reservation_layer,int(state.dirty),state.save_timer_s,cpu_ms,gpu_ms])


func _state() -> Dictionary:
	var room_enabled: int = 0
	var plug_enabled: int = 0
	for shape: CollisionShape3D in room_shapes:
		if is_instance_valid(shape) and not shape.disabled: room_enabled += 1
	for shape: CollisionShape3D in plug_shapes:
		if is_instance_valid(shape) and not shape.disabled: plug_enabled += 1
	return {
		"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
		"growth_clock_s":float(game.growth_time),"mana":float(game.mana),
		"room_growing":bool(game.room_growing),"room_ready":bool(game.room_ready),
		"world_room_ready":bool(game.world.get("_room_ready")),
		"room_visible":game.world.right_room.visible,"room_scale":game.world.right_room.scale.x,
		"wall_plug_visible":game.world.wall_plug.visible,
		"room_shapes_enabled":room_enabled,"room_shapes_total":room_shapes.size(),
		"plug_shapes_enabled":plug_enabled,"plug_shapes_total":plug_shapes.size(),
		"reservation_layer":int(game.reservation.collision_layer),
		"dirty":bool(game.dirty),"save_timer_s":float(game.save_timer)
	}


func _event(name: String) -> void:
	events.append({"name":name,"monotonic_usec":Time.get_ticks_usec(),"phase":phase,"state":_state()})


func _find_button(prefix: String) -> Button:
	for child: Node in game.content.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.is_queued_for_deletion(): return child
	return null


func _check(condition: bool, message: String) -> void:
	if not condition: _fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("GROWTH_TIMING_FAIL ",message)


func _statistics(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return {"count":ordered.size(),"p50_ms":ordered[mini(ordered.size()-1,int(ceil(0.50*ordered.size())-1))],"p95_ms":ordered[mini(ordered.size()-1,int(ceil(0.95*ordered.size())-1))],"p99_ms":ordered[mini(ordered.size()-1,int(ceil(0.99*ordered.size())-1))],"max_ms":ordered[-1]}


func _window(start_usec: int, end_usec: int, phase_filter: String = "") -> Dictionary:
	var values: Array[float] = []
	for sample: Dictionary in frames:
		if int(sample.monotonic_usec) >= start_usec and int(sample.monotonic_usec) <= end_usec and (phase_filter.is_empty() or sample.phase == phase_filter):
			values.append(float(sample.frame_ms))
	return _statistics(values)


func _finish() -> void:
	if finished: return
	finished = true
	capture_active = false
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
	if raw != null:
		raw.flush()
		raw.close()
		raw = null
	var ended_usec: int = Time.get_ticks_usec()
	var fingerprint_end: Dictionary = _build_fingerprint()
	_check(fingerprint_start == fingerprint_end,"The build identity must remain unchanged throughout the diagnostic.")
	var observed_commit_usec: int = int(commit_observation.get("observed_child_callback_usec",0))
	var environment: Environment = game.world.environment
	var report: Dictionary = {
		"schema":"mush-live-growth-timing/1","passed":failures.is_empty(),"failures":failures,
		"build":str(game._snapshot().build_version),"build_fingerprint":fingerprint_start,"final_build_fingerprint":fingerprint_end,
		"build_unchanged":fingerprint_start == fingerprint_end,"exported":not OS.has_feature("editor"),
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"render_resolution":[get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()],
		"physics_hz":Engine.physics_ticks_per_second,"vsync":DisplayServer.window_get_vsync_mode(),
		"measurement_kind":"short_natural_growth_post_draw_wall_intervals","not_T15":true,"manual_visual_review":false,
		"elapsed_seconds":float(ended_usec-started_usec)/1000000.0,
		"warmup_seconds":WARMUP_SECONDS,"baseline_seconds":BASELINE_SECONDS,"growth_and_reveal_seconds":GROWTH_AND_REVEAL_SECONDS,
		"frames":frames.size(),"baseline":_window(0,ended_usec,"baseline"),
		"growing":_window(0,ended_usec,"growth"),"post_commit":_window(0,ended_usec,"post_commit"),
		"commit_nearby_half_second":_window(maxi(0,observed_commit_usec-250000),observed_commit_usec+250000),
		"commit_and_scheduled_save_two_seconds":_window(maxi(0,observed_commit_usec-250000),observed_commit_usec+2000000),
		"grow_ui_signal":growth_signal_timing,"natural_commit_observation":commit_observation,
		"first_post_draw_with_ready_state":first_ready_draw,"first_settled_physics_boundary":first_consistent_physics,
		"normal_autosave_observation":autosave_observation,"explicit_durable_save":durable_save_timing,
		"private_save_directory":game.store.directory,"final_state":_state(),"events":events,
		"camera":{"position":[10.0,4.2,15.0],"target":[2.2,1.7,0.2],"vertical_fov":60.0},
		"graphics_settings":{"taa":get_viewport().use_taa,"msaa_3d":int(get_viewport().msaa_3d),"ssao":environment.ssao_enabled,"ssr":environment.ssr_enabled,"glow":environment.glow_enabled,"sun_shadows":game.world.sun.shadow_enabled,"sky":game.sky,"weather":game.weather},
		"limitations":["One day/sunny transaction at a fixed view with empty furniture/garden; short diagnostic, not repeated release-route performance.","Commit attribution is a callback observation bracket and adjacent frame cadence; no isolated natural commit method CPU duration is available.","frame_post_draw intervals include scheduling, instrumentation and submission/presentation behavior; they are not isolated GPU timings or human playback review.","The normal autosave is retained. Its observation bracket is separate from the explicitly measured later save invocation.","Deferred collision settlement is recorded independently from logical readiness and the first post-draw callback with ready state."]
	}
	var gpu_values: Array[float] = []
	for sample: Dictionary in frames: gpu_values.append(float(sample.gpu_render_ms))
	report["gpu_timing_available"] = not gpu_values.is_empty() and float(_statistics(gpu_values).max_ms) > 0.0
	report["gpu_timing_scope"] = "Engine viewport GPU timestamps only; all-zero samples mean unavailable, not zero GPU cost."
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		print("GROWTH_TIMING_FAIL Cannot create final report directory.")
		game._quit_clean.call_deferred(1)
		return
	var file: FileAccess = FileAccess.open(output.path_join("growth-timing.json"),FileAccess.WRITE)
	if file == null:
		print("GROWTH_TIMING_FAIL Cannot write final report.")
		game._quit_clean.call_deferred(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.flush()
	file.close()
	print("GROWTH_TIMING_COMPLETE passed=",report.passed," frames=",frames.size()," report=",output.path_join("growth-timing.json"))
	game._quit_clean.call_deferred(0 if bool(report.passed) else 1)


func _build_fingerprint() -> Dictionary:
	var files: Dictionary = {}
	if OS.has_feature("editor"):
		for filename: String in ["scripts/playable.gd","scripts/baked_world.gd","scripts/forest_enclosure.gd","assets/world/fireflies.gdshader","baked/clearing.res","tests/growth_timing.gd"]:
			files[filename] = FileAccess.get_sha256("res://"+filename)
		return {"kind":"editor_source","source_sha256":files}
	var resource_dir: String = OS.get_executable_path().get_base_dir().path_join("../Resources")
	var directory: DirAccess = DirAccess.open(resource_dir)
	if directory != null:
		for filename: String in directory.get_files():
			if filename.ends_with(".pck"): files[filename] = FileAccess.get_sha256(resource_dir.path_join(filename))
	return {"kind":"native_export","executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"resource_pack_sha256":files}
