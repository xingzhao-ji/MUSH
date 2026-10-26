extends "res://lineage/scenery-revision-18/proposals/planting-mana-01/candidate_main-final.gd"
const BakedWorld = preload("res://scripts/baked_world.gd")
const CurrentPlayer = preload("res://scripts/air_capsule_guard.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const EnvironmentController = preload("res://scripts/environment_controller.gd")
const PrototypeScenery = preload("res://scripts/prototype_scenery.gd")
var prototype_scenery: Node3D
var touch_controls: Control
var environment_controller: Node
var living_motion_startup: Dictionary = {"passed":false,"status":"pending"}
var camera_fade_prewarm: Dictionary = {"status":"pending"}
var _prewarm_draw_frames: int = 0
var _prewarm_last_draw_us: int = 0

func _ready() -> void:
	# Desktop input isolation applies only to explicit automated sessions.
	if "--verify" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		get_window().unfocusable = true
	if "--verify" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		get_window().mouse_passthrough = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	world = BakedWorld.new()
	world.name = "WorldGeometry"
	add_child(world)
	player = CurrentPlayer.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var paw_grounding = preload("res://scripts/paw_grounding.gd").new()
	paw_grounding.name = "PawGrounding"
	player._skeleton.add_child(paw_grounding)
	paw_grounding.configure(player)
	player.position = Vector3(-2,0,18)
	player.feedback.connect(_toast)
	store = SaveScript.new()
	_preview_slot = "user://profile"
	store.directory = _preview_slot
	_build_gameplay()
	_build_ui()
	_build_audio()
	_apply_settings()
	review_camera = Camera3D.new()
	review_camera.name = "FixedReviewCamera"
	review_camera.position = Vector3(6,3.3,20)
	review_camera.fov = 60
	add_child(review_camera)
	review_camera.look_at(review_target)
	if PrototypeScenery.is_enabled():
		prototype_scenery = PrototypeScenery.new()
		add_child(prototype_scenery)
		prototype_scenery.configure(world)
		player.movement_extension = prototype_scenery
		review_camera.far = PrototypeScenery.FAR_PLANE
	var arguments := OS.get_cmdline_user_args()
	verification = "--mobile-save-review" in arguments or "--verify" in arguments or "--capture" in arguments or "--benchmark" in arguments or "--traversal" in arguments or "--crash-probe" in arguments or "--smoke" in arguments or "--ui-review" in arguments or "--growth-timing" in arguments or "--wake-review" in arguments
	await _prewarm_camera_fade()
	if verification:
		_preview_slot = "user://verification/current"
		store.directory = _preview_slot
		_start_new()
	else:
		_title()
	environment_controller = EnvironmentController.new()
	environment_controller.configure(world,player,self)
	add_child(environment_controller)
	environment_controller.set_quality("low" if bool(settings.get("reduced_effects",false)) else "balanced")
	environment_controller.set_reduced_motion(bool(settings.get("reduced_motion",false)))
	if is_instance_valid(prototype_scenery): prototype_scenery.set_reduced_motion(bool(settings.get("reduced_motion",false)))
	mobile_release_requested.connect(_release_mobile_controls)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	Input.joy_connection_changed.connect(_controller_change)
	living_motion_startup = {"passed":world.snapshot_loaded,"status":"loaded_native_snapshot","time_running":world._m37_initialized}
	if "--mobile-save-review" in arguments:
		add_child.call_deferred(load("res://tests/mobile_save.gd").new())
	if "--crash-probe" in arguments:
		_start_crash_probe.call_deferred()
	if "--verify" in arguments:
		_start_acceptance.call_deferred()
	if "--benchmark" in arguments or "--traversal" in arguments:
		_start_benchmark.call_deferred()
	for review_flag: String in ["--ui-review", "--growth-timing"]:
		if review_flag in arguments:
			var review_script: String = "res://tests/ui_review.gd" if review_flag == "--ui-review" else "res://tests/growth_timing.gd"
			add_child.call_deferred(load(review_script).new())
	if "--wake-review" in arguments:
		add_child.call_deferred(load("res://tests/wake_review.gd").new())
	if "--smoke" in arguments:
		var runner: Node = load("res://tests/smoke.gd").new()
		add_child.call_deferred(runner)

func _prewarm_camera_fade() -> void:
	# Instance transparency switches pipelines only in Forward+. Exercise the
	# existing character materials under a loading cover, before accepting play.
	if DisplayServer.get_name()=="headless":
		camera_fade_prewarm = {"status":"headless_no_render"}
		return
	if RenderingServer.get_current_rendering_method()!="forward_plus":
		camera_fade_prewarm = {"status":"not_needed_for_renderer"}
		return
	var started: int = Time.get_ticks_usec()
	var paused_before: bool = get_tree().paused
	var process_before: bool = is_processing()
	var input_before: bool = is_processing_input()
	var unhandled_before: bool = is_processing_unhandled_input()
	var world_process_before: bool = world.is_processing()
	var player_process_before: bool = player.is_processing()
	var camera_before: Camera3D = get_viewport().get_camera_3d()
	var pivot_before: Transform3D = player._camera_pivot.global_transform
	var saved: Array[float] = []
	var emission_before: bool = player._cream.emission_enabled
	var warmed_modes: int = 0
	var total_draw_frames: int = 0
	var cover: ColorRect = ColorRect.new()
	cover.color = Color("17251f")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(cover)
	var entering: Label = Label.new()
	entering.text = "Entering the clearing…"
	entering.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entering.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover.add_child(entering)
	entering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = true
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	world.set_process(false)
	player.set_process(false)
	player._camera_pivot.global_position = player.global_position+Vector3.UP*0.70
	player._camera_pivot.rotation = Vector3(player._camera_pitch,player.camera_yaw,0.0)
	player.get_camera().make_current()
	for mesh: MeshInstance3D in player._meshes:
		saved.append(mesh.transparency)
		mesh.transparency = 0.25
	RenderingServer.frame_post_draw.connect(_count_prewarm_draw)
	# Glow changes the cream shader's emission feature. Warm both fade variants
	# without invoking the ability, its light, or its animation during loading.
	for emission: bool in [false,true]:
		player._cream.emission_enabled = emission
		_prewarm_draw_frames = 0
		_prewarm_last_draw_us = Time.get_ticks_usec()
		# Bound inactivity; a slow cold first draw still counts as progress.
		while _prewarm_draw_frames<4 and Time.get_ticks_usec()-_prewarm_last_draw_us<3000000:
			await get_tree().process_frame
		total_draw_frames += _prewarm_draw_frames
		if _prewarm_draw_frames<4: break
		warmed_modes += 1
	RenderingServer.frame_post_draw.disconnect(_count_prewarm_draw)
	player._cream.emission_enabled = emission_before
	var restored: bool = true
	for index: int in range(saved.size()):
		player._meshes[index].transparency = saved[index]
		restored = restored and player._meshes[index].transparency==saved[index]
	player._camera_pivot.global_transform = pivot_before
	if is_instance_valid(camera_before): camera_before.make_current()
	player.set_process(player_process_before)
	world.set_process(world_process_before)
	set_process(process_before)
	set_process_input(input_before)
	set_process_unhandled_input(unhandled_before)
	get_tree().paused = paused_before
	cover.free()
	camera_fade_prewarm = {"status":"drawn" if warmed_modes==2 else "draw_inactivity_deadline","draw_frames":total_draw_frames,"glow_shader_modes_warmed":warmed_modes,"emission_flag_restored":player._cream.emission_enabled==emission_before,"mesh_count":saved.size(),"all_mesh_transparencies_restored":restored,"camera_restored":get_viewport().get_camera_3d()==camera_before and player._camera_pivot.global_transform.is_equal_approx(pivot_before),"processing_restored":is_processing()==process_before and is_processing_input()==input_before and is_processing_unhandled_input()==unhandled_before and world.is_processing()==world_process_before and player.is_processing()==player_process_before and get_tree().paused==paused_before,"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,"draw_compilations":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"surface_compilations":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)}
	print("CAMERA_FADE_PREWARM ",JSON.stringify(camera_fade_prewarm))

func _count_prewarm_draw() -> void:
	_prewarm_draw_frames += 1
	_prewarm_last_draw_us = Time.get_ticks_usec()

func _title() -> void:
	super._title()
	# The player rig has not settled when the paused title first appears.
	# Reuse the established comparison view instead of looking into the shell.
	if mode=="title" and is_instance_valid(review_camera):
		review_camera.look_at(review_target)
		review_camera.make_current()

func _apply_settings() -> void:
	super._apply_settings()
	if is_instance_valid(world) and world.has_method("set_living_motion_reduced"):
		world.set_living_motion_reduced(bool(settings.get("reduced_motion",false)))
	if is_instance_valid(environment_controller):
		environment_controller.set_quality("low" if bool(settings.get("reduced_effects",false)) else "balanced")
		environment_controller.set_reduced_motion(bool(settings.get("reduced_motion",false)))
		if is_instance_valid(prototype_scenery): prototype_scenery.set_reduced_motion(bool(settings.get("reduced_motion",false)))

func _release_mobile_controls(reason: String) -> void:
	if reason in ["suspend","load"] and is_instance_valid(touch_controls):
		touch_controls.reset_all(reason)
		touch_controls.set_active(false)

func _quit_clean(exit_code: int=0) -> void:
	if _quitting: return
	if is_instance_valid(environment_controller): environment_controller.shutdown_visuals()
	super._quit_clean(exit_code)

func _snapshot() -> Dictionary:
	var snapshot: Dictionary = super._snapshot()
	snapshot["build_version"] = "0.3.0"
	return snapshot

func _capture_review() -> void:
	var runner: Node = load("res://tests/lod_check.gd" if "--lod" in OS.get_cmdline_user_args() else "res://tests/perf_probe.gd" if "--perf" in OS.get_cmdline_user_args() else "res://tests/route_traversal.gd" if "--route" in OS.get_cmdline_user_args() else "res://tests/scenic_capture.gd" if "--scenic" in OS.get_cmdline_user_args() else "res://tests/capture_current.gd").new()
	add_child.call_deferred(runner)

func _build_ui() -> void:
	super._build_ui()
	touch_controls = TouchControls.new()
	touch_controls.configure(self)
	ui.add_child(touch_controls)

func _enter_menu(new_mode: String) -> void:
	if is_instance_valid(touch_controls):
		touch_controls.reset_all("menu")
		touch_controls.set_active(false)
	super._enter_menu(new_mode)

func _explore() -> void:
	super._explore()
	if mode!="explore" or get_tree().paused or _mobile_suspended: return
	player.get_camera().make_current()
	if is_instance_valid(touch_controls) and touch_controls.requested:
		touch_controls.set_active(true)
		helper.text = "Left thumb to move · drag the forest to look"
		intro_time = 6.0

func _touch_action(action: String) -> void:
	if mode not in ["explore","garden_place"]: return
	match action:
		"hover": player.set_touch_hover(not player.touch_hover_latched)
		"glow":
			player.set_glow(not player.glow_on)
			_schedule_save()
		"pause": _cancel()
		"decorate":
			if _inside_home() and player.state=="Grounded" and player.is_on_floor(): _decorate_menu()
		"context":
			if mode=="garden_place":
				if garden_valid:
					plant_garden(garden_target,garden_type)
					_end_garden_preview()
				else: _toast("Choose open soil inside the garden, away from other plants.")
			else: _interact()

func _layout_mobile_hud(rect: Rect2) -> void:
	if not is_instance_valid(touch_controls) or not touch_controls.requested: return
	var center := rect.get_center()
	var height := minf(660.0,rect.size.y-40.0)
	var width := minf(580.0,rect.size.x-40.0)
	modal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	modal.position = center-Vector2(width,height)*0.5
	modal.size = Vector2(width,height)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	prompt.position = Vector2(center.x-300.0,rect.end.y-250.0)
	prompt.size = Vector2(600,48)
	mana_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mana_label.position = rect.position+Vector2(20,20)
	mana_label.size = Vector2(180,45)
	helper.hide()
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	notice.position = Vector2(center.x-360,rect.position.y+28)
	notice.size = Vector2(720,60)

func _notification(what: int) -> void:
	# Godot automatically invokes inherited _notification methods.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if is_instance_valid(touch_controls): touch_controls.reset_all("lifecycle")
