extends Node
## Observe the real paid Plant UI, natural bloom and resident wake at native ticks.
## Timing/continuity expectations use observed brackets, not the easing formula.
signal observed_tick
const EXPECTED_BLOOM_SECONDS := 3.0
const EXPECTED_WAKE_SECONDS := 0.8
const EXPECTED_SLEEP_ANGLE := 1.15
const MAX_ANGLE_STEP := 0.04
const PAUSE_TICKS := 30
const MAX_WALL_SECONDS := 45.0
const FLORA_COUNT := 18
const FLORA_CHILD_COUNT := 11
const FLORA_RADIUS := 3.5
const MUTED_COLOR := Color("828b73")
const RESTORED_COLOR := Color("aabbe5")
const READBACK_EPSILON := 0.000002
const SUN_LOCAL_ORIGIN_MAX_DISTANCE_M := 0.0001
var game: Node
var output: String = ""
var slot: String = ""
var raw: FileAccess
var flora_raw: FileAccess
var flora_rows := 0
var flora_samples: Array[Dictionary] = []
var flora_identity_before: Dictionary = {}
var flora_geometry_before: Dictionary = {}
var world_geometry_before: Dictionary = {}
var sun_native_before: Dictionary = {}
var wave_tick_guards := true
var wave_guard_first_failure: Dictionary = {}
var assertions: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var natural_samples: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var failed := 0
var finished := false
var sampling := false
var planted := false
var phase: String = "setup"
var started_usec: int = 0
var planted_usec: int = 0
var active_elapsed := 0.0
var last_state: Dictionary = {}
var accepted: Dictionary = {}
var paid_snapshot: Dictionary = {}
var events: Dictionary = {}
var fingerprint_before: Dictionary = {}
var resident_count: int = 0
var plant_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	process_physics_priority = 100
	game = get_parent()
	started_usec = Time.get_ticks_usec()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output_count := 0
	var slot_count := 0
	for index: int in range(args.size()-1):
		if args[index] == "--report-dir":
			output = args[index+1].simplify_path()
			output_count += 1
		if args[index] == "--wake-slot":
			slot = args[index+1]
			slot_count += 1
	var valid: bool = "--wake-review" in args and bool(game.verification) and output_count == 1 and output.is_absolute_path() and slot_count == 1 and _valid_slot(slot) and DisplayServer.get_name() != "headless"
	for flag: String in ["--verify","--capture","--benchmark","--traversal","--crash-probe","--smoke","--ui-review","--growth-timing","--filesystem-faults"]:
		valid = valid and not flag in args
	if not valid:
		push_error("Wake review requires normal graphics, only --wake-review, fresh absolute --report-dir and --wake-slot wake_review_<unique identifier>")
		game._quit_clean(2)
		return
	for filename: String in ["wake-review.json","wake-review.csv","flora-wave.csv","sleep.png","late-bloom.png","paused-midwake.png","awake.png","loaded.png","reset.png"]:
		if FileAccess.file_exists(output.path_join(filename)):
			push_error("Wake review refuses existing report/capture output")
			game._quit_clean(2)
			return
	var private_directory: String = "user://verification/"+slot
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(private_directory)):
		push_error("Wake review requires an unused private verification save slot")
		game._quit_clean(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Wake review report directory unavailable")
		game._quit_clean(2)
		return
	raw = FileAccess.open(output.path_join("wake-review.csv"),FileAccess.WRITE)
	if raw == null:
		push_error("Wake review CSV unavailable")
		game._quit_clean(2)
		return
	raw.store_line("monotonic_usec,elapsed_wall_s,elapsed_active_s,physics_frame,physics_delta_s,phase,paused,bloom_clock_s,visual_bloom,wake_clock_s,rotation_z_rad,resident_x,resident_z,resident_velocity_x,resident_velocity_z,mana,durable_awake,path_restored")
	fingerprint_before = _fingerprint()
	flora_raw = FileAccess.open(output.path_join("flora-wave.csv"),FileAccess.WRITE)
	if flora_raw == null:
		push_error("Flora wave CSV unavailable")
		raw.close()
		raw = null
		game._quit_clean(2)
		return
	flora_raw.store_line("monotonic_usec,elapsed_active_s,physics_frame,phase,paused,bloom_clock_s,visual_bloom,node_index,node_path,node_id,distance_xz_m,scale_y,observed_scale_progress,albedo_r,albedo_g,albedo_b,albedo_a,color_distance_muted,color_distance_restored,max_child_color_spread,mesh_children,all_child_colors_sha256,geometry_identity_exact")
	game.store.directory = private_directory
	game._preview_slot = private_directory
	game._reset_world()
	game._explore()
	game.save_timer = -1.0
	game.dirty = false
	_check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Existing physics is60Hz with ordinary time scale",{"physics_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale})
	_check(not bool(game.settings.reduced_effects) and not bool(game.settings.reduced_motion),"Normal graphics and motion settings remain enabled",game.settings)
	_check(bool(game.world.snapshot_loaded),"Current native baked world is actually loaded")
	_check(absf(game.resident_visual.rotation.z-EXPECTED_SLEEP_ANGLE) < .000001 and game.resident_wake_elapsed == 0.0,"Fresh reset immediately presents the sleeping pose",_state(0.0))
	resident_count = _count_named(game,"ResidentPlaceholder")
	_check(resident_count == 1,"Exactly one existing resident is present",resident_count)
	_check(game.patch_flora.size() == FLORA_COUNT,"All18 actual existing nearby flora are available",game.patch_flora.size())
	flora_identity_before = _flora_identity()
	flora_geometry_before = _geometry_signature_for_flora()
	_check(flora_identity_before.size() == FLORA_COUNT and flora_geometry_before.size() == FLORA_COUNT,"Native flora identities and geometry were observed for all18 nodes")
	_check_flora_state(false,"Reset begins with all18 actual flora muted")
	_check_hud("initial")
	game.set_appearance("night","sunny")
	game.player.teleport_safe(Vector3(13,0,.3),0.0)
	game.review_camera.position = Vector3(15.8,1.7,1.2)
	game.review_camera.fov = 60.0
	game.review_camera.look_at(Vector3(14,.5,-2))
	game.review_camera.make_current()
	# Compare strict raw Sun locals only at the same actual appearance endpoints.
	# Appearance normally refreshes its anchor during the2s day-to-night blend.
	phase = "appearance_settle"
	var settle_started_usec: int = Time.get_ticks_usec()
	while game.world.night_amount != 1.0 and not finished:
		await get_tree().process_frame
		if float(Time.get_ticks_usec()-settle_started_usec)/1000000.0 > 5.0:
			_check(false,"Ordinary night fixture failed to settle within5s",{"night_amount":game.world.night_amount,"night_target":game.world._night_target})
			_finish()
			return
	if finished: return
	await RenderingServer.frame_post_draw
	if finished: return
	_check(game.sky == "night" and game.world.night_amount == 1.0 and game.world._night_target == 1.0 and game.weather == "sunny","World preservation baseline observes fully settled ordinary night1 after post-draw",{"sky":game.sky,"night_amount":game.world.night_amount,"night_target":game.world._night_target,"settle_wall_s":float(Time.get_ticks_usec()-settle_started_usec)/1000000.0,"physics_frame":Engine.get_physics_frames()})
	world_geometry_before = _world_geometry_signature()
	sun_native_before = _sun_native_readback()
	_check_sun_anchor("baseline",sun_native_before)
	_check_sky_bindings("baseline",world_geometry_before)
	var outside_static_meshes := 0
	var world_colliders := 0
	for record: Dictionary in world_geometry_before.values():
		if float(record.get("minimum_bounds_distance_xz_m",0.0)) > FLORA_RADIUS:
			outside_static_meshes += 1
		if record.class == "CollisionShape3D":
			world_colliders += 1
	_check(outside_static_meshes > 0 and world_colliders > 0,"Native signature includes real outside3.5m scenery and world colliders",{"records":world_geometry_before.size(),"outside_bounds_meshes":outside_static_meshes,"collider_shapes":world_colliders})
	events["native_preservation_baseline"] = {"flora_geometry":flora_geometry_before,"world_geometry":world_geometry_before,"dynamic_sky_pose":_dynamic_sky_pose(),"appearance_fixture":{"sky":game.sky,"night_amount":game.world.night_amount,"night_target":game.world._night_target,"post_draw_observed":true},"scope":"Same settled night1 appearance endpoints after ordinary setup, before any Plant. Sun local anchor legitimately changes across appearance setup and is not claimed unchanged from reset day. All world MeshInstance3D/MultiMesh native arrays, resource/node/parent identities, local bounds, aliases and static BaseMaterial3D albedos are strict.49 known celestial descendants have byte-exact local mesh transforms. The positively bound VisibleSun has exact local basis/scale/native fields and an explicit measured local-origin endpoint distance<=0.0001m at matching night1; actual numeric origin/anchor readback is retained, and each origin must byte-match its current source-owned anchor. Existing camera-follow/orbit parent globals are recorded separately. The existing World-child Moon has a source-driven local/global origin: its basis/scale/immutable anchor/native arrays/aliases/IDs remain strict and origin is recorded separately. All static mesh global transforms/bounds and every collider local/global transform/shape field remain strict. Flora geometry/child transforms/aliases remain exact; only root Y scale and override albedo are intended mutable channels. Camera-follow sky has no flora-radius classification. Shader uniforms, particle buffers and light/sky animation are not compared."}
	sampling = true
	phase = "sleep_fixture"
	await _ticks(30)
	if finished: return
	await _capture("sleep.png")
	game._update_context()
	_check(game.player.is_on_floor() and game.context == "patch_plant","Ordinary ground-supported patch context exposes Plant",{"context":game.context,"floor":game.player.is_on_floor(),"position":str(game.player.position)})
	game._interact()
	plant_button = _find_button("Moonbell")
	_check(game.mode == "plant_preview" and get_tree().paused and plant_button != null and not plant_button.disabled,"Contextual Interact opens the ordinary available Moonbell Plant button")
	if failed > 0 or plant_button == null:
		_finish()
		return
	phase = "bloom_wake"
	planted_usec = Time.get_ticks_usec()
	active_elapsed = 0.0
	planted = true
	var signal_before: int = Time.get_ticks_usec()
	plant_button.pressed.emit()
	accepted = _state(0.0)
	events["plant_pressed_signal"] = {"before_usec":signal_before,"after_usec":Time.get_ticks_usec(),"accepted_state":accepted,"input_kind":"Actual production Button.pressed signal; physical mouse/controller input is not claimed"}
	_check(game.mana == 75.0 and game.restoration_state == "bloomed" and game.resident_awake and game.path_restored,"Normal Plant commits exactly one25-magic debit and coupled outcomes",accepted)
	_check(game.bloom_clock == 0.0 and game.resident_wake_elapsed == 0.0 and absf(game.resident_visual.rotation.z-EXPECTED_SLEEP_ANGLE) < .000001,"Payment begins natural bloom while the resident remains asleep",accepted)
	_check(game.mode == "explore" and not get_tree().paused,"Accepted Plant returns ordinary exploration")
	paid_snapshot = game.store.load_snapshot()
	_check(bool(paid_snapshot.get("ok",false)),"The normal paid save is readable immediately")
	if bool(paid_snapshot.get("ok",false)):
		var data: Dictionary = paid_snapshot["data"]
		_check(data.mana == 75.0 and data.restoration.state == "bloomed" and data.restoration.resident_awake and data.restoration.path_restored,"Paid snapshot commits the final outcome before presentation finishes",data.restoration)
	_check_repeat("same_tick_repeat")
	if failed > 0:
		_finish()
		return
	# No clock assignment or finish shortcut follows the primary Plant.
	# Capture the actual unobscured late bloom, then continue ordinary ticks.
	while float(game.bloom_clock) >= 0.0 and float(game.bloom_clock) < 2.5 and active_elapsed < 2.7 and not finished:
		await observed_tick
	if finished: return
	var late_flora: Array[Dictionary] = _flora_readback()
	_check(game.bloom_clock >= 2.5-READBACK_EPSILON and game.bloom_clock <= 2.5+2.0/60.0 and game.patch_visual_bloom == 1.0 and not get_tree().paused and not game.modal.visible,"Late-bloom frame is ordinary unobscured exploration near2.5s with the central plant open",last_state)
	_check(_is_mixed_ring(late_flora),"The late-bloom view contains actually restored, intermediate and still-muted flora",late_flora)
	_check_hud("late_bloom")
	_check(game.notice.is_visible_in_tree() and not game.notice.text.is_empty() and game.mana_label.is_visible_in_tree(),"Actual HUD text is visible over the bright-petal late-bloom scene",{"notice":game.notice.text,"mana":game.mana_label.text,"central_plant_meshes":_count_meshes(game.patch_node.get_node("Plant"))})
	await _capture("late-bloom.png")
	if finished: return
	while float(game.resident_wake_elapsed) < .30 and active_elapsed < 4.0 and not finished:
		await observed_tick
	if finished: return
	_check(game.bloom_clock < 0.0 and game.resident_wake_elapsed >= .30 and game.resident_wake_elapsed < .50 and game.resident_visual.rotation.z > .20 and game.resident_visual.rotation.z < 1.05,"A real intermediate wake pose is available for pause",last_state)
	phase = "pause_midwake"
	game._pause()
	var pause_before: Dictionary = _pause_signature()
	var pause_first_usec: int = Time.get_ticks_usec()
	await _ticks(PAUSE_TICKS)
	if finished: return
	var pause_after: Dictionary = _pause_signature()
	_check(get_tree().paused and var_to_bytes(pause_before) == var_to_bytes(pause_after),"Ordinary Pause freezes wake clock, complete resident pose/velocity, bloom and mana across30physics ticks",{"before":pause_before,"after":pause_after})
	events["paused_midwake"] = {"ticks":PAUSE_TICKS,"wall_seconds":float(Time.get_ticks_usec()-pause_first_usec)/1000000.0,"before":pause_before,"after":pause_after,"exact":var_to_bytes(pause_before) == var_to_bytes(pause_after)}
	await _capture("paused-midwake.png")
	game._explore()
	phase = "bloom_wake"
	while float(game.resident_wake_elapsed) < EXPECTED_WAKE_SECONDS and active_elapsed < 4.5 and not finished:
		await observed_tick
	if finished: return
	_validate_natural()
	_validate_flora_wave()
	_check(game.resident_wake_elapsed >= EXPECTED_WAKE_SECONDS and absf(game.resident_visual.rotation.z) < .000001,"Natural wake reaches the upright pose without a finish shortcut",last_state)
	phase = "awake_walk"
	var walk_start: Vector2 = Vector2(game.resident.position.x,game.resident.position.z)
	var target: Vector2 = Vector2(16,-4)
	await _ticks(60)
	if finished: return
	var walk_end: Vector2 = Vector2(game.resident.position.x,game.resident.position.z)
	_check(walk_end.distance_to(walk_start) > .15 and walk_end.distance_to(target) < walk_start.distance_to(target),"Only after fully awake, the ordinary night routine moves toward its target",{"start":[walk_start.x,walk_start.y],"end":[walk_end.x,walk_end.y],"target":[target.x,target.y]})
	_check_repeat("awake_repeat")
	await _capture("awake.png")
	# Loading the real already-paid snapshot is a separate final-state case.
	phase = "paid_load"
	game._pause()
	var source_save_sha: String = FileAccess.get_sha256(private_directory.path_join("clearing.json"))
	game._load_data(paid_snapshot["data"])
	var loaded_immediate: Dictionary = _state(0.0)
	_check(game.mana == 75.0 and game.bloom_clock < 0.0 and game.patch_visual_bloom == 1.0 and game.resident_wake_elapsed == EXPECTED_WAKE_SECONDS and game.resident_visual.rotation.z == 0.0,"Loading paid state applies complete bloom and upright pose immediately",loaded_immediate)
	_check_flora_state(true,"Loading the paid snapshot immediately restores all18 flora without replay")
	_check(_count_named(game,"ResidentPlaceholder") == resident_count and _count_named(game.patch_node,"Plant") == 1,"Paid load does not duplicate the resident or plant")
	events["paid_load_immediate"] = loaded_immediate
	await _capture("loaded.png")
	game._explore()
	await _ticks(12)
	if finished: return
	_check(game.resident_wake_elapsed == EXPECTED_WAKE_SECONDS and game.resident_visual.rotation.z == 0.0 and game.bloom_clock < 0.0,"Following natural ticks keep loaded paid state upright without replay")
	_check(FileAccess.get_sha256(private_directory.path_join("clearing.json")) == source_save_sha,"Loading paid state did not rewrite or re-debit its durable snapshot")
	_check_flora_state(true,"Paid flora remains complete through following natural ticks")
	phase = "reset_sleep"
	game._reset_world()
	var reset_immediate: Dictionary = _state(0.0)
	_check(not game.resident_awake and game.resident_wake_elapsed == 0.0 and absf(game.resident_visual.rotation.z-EXPECTED_SLEEP_ANGLE) < .000001 and game.resident_visual.position.y == Vector3(0,-.02,0).y,"Reset immediately restores the sleeping tilt and offset",reset_immediate)
	events["reset_immediate"] = reset_immediate
	_check_flora_state(false,"Reset immediately returns all18 flora to muted color and scale")
	await _ticks(12)
	if finished: return
	_check(not game.resident_awake and game.resident_wake_elapsed == 0.0 and absf(game.resident_visual.rotation.z-EXPECTED_SLEEP_ANGLE) < .000001,"Reset sleeping pose persists through ordinary ticks")
	await _capture("reset.png")
	await _validate_pause_and_skip(private_directory)
	if finished: return
	var flora_geometry_after: Dictionary = _geometry_signature_for_flora()
	_check(game.sky == "night" and game.world.night_amount == 1.0 and game.world._night_target == 1.0 and game.weather == "sunny","World preservation endpoint observes the same fully settled ordinary night1",{"sky":game.sky,"night_amount":game.world.night_amount,"night_target":game.world._night_target,"physics_frame":Engine.get_physics_frames()})
	var world_geometry_after: Dictionary = _world_geometry_signature()
	var sun_native_after: Dictionary = _sun_native_readback()
	_check_sun_anchor("after",sun_native_after)
	var sun_origin_delta: float = (sun_native_before.origin as Vector3).distance_to(sun_native_after.origin as Vector3)
	_check(is_finite(sun_origin_delta) and sun_origin_delta <= SUN_LOCAL_ORIGIN_MAX_DISTANCE_M and var_to_bytes(sun_native_before.basis) == var_to_bytes(sun_native_after.basis) and var_to_bytes(sun_native_before.scale) == var_to_bytes(sun_native_after.scale),"Only the source-reapplied Sun local origin has a bounded0.0001m endpoint difference; native basis/scale stay exact",{"origin_distance_m":sun_origin_delta,"maximum_origin_distance_m":SUN_LOCAL_ORIGIN_MAX_DISTANCE_M,"before":sun_native_before,"after":sun_native_after})
	events["sun_local_origin_preservation"] = {"origin_distance_m":sun_origin_delta,"maximum_origin_distance_m":SUN_LOCAL_ORIGIN_MAX_DISTANCE_M,"origin_within_bound":is_finite(sun_origin_delta) and sun_origin_delta <= SUN_LOCAL_ORIGIN_MAX_DISTANCE_M,"basis_exact":var_to_bytes(sun_native_before.basis) == var_to_bytes(sun_native_after.basis),"scale_exact":var_to_bytes(sun_native_before.scale) == var_to_bytes(sun_native_after.scale),"before":sun_native_before,"after":sun_native_after,"scope":"Only the positively bound existing VisibleSun origin uses this numerical allowance at matched night1. All49 other celestial locals, all static local/global transforms/bounds, every collider and all mesh arrays/aliases/IDs stay exact. No rounded signatures or global tolerances."}
	_check_sky_bindings("after",world_geometry_after)
	_check(var_to_bytes(flora_geometry_before) == var_to_bytes(flora_geometry_after),"All18 native flora geometry, aliases, positions and child transforms remain exact across natural bloom/pause/load/reset/Skip")
	_check(var_to_bytes(world_geometry_before) == var_to_bytes(world_geometry_after),"All native mesh arrays/aliases/IDs and static global/collider fields remain exact;49 sky locals and Sun/Moon basis/scale stay exact",{"world_geometry_exact":var_to_bytes(world_geometry_before) == var_to_bytes(world_geometry_after),"dynamic_sky_origin_exception":"Existing source-driven celestial parent globals/direct Moon origin are separate; only existing Sun local origin has its measured<=0.0001m bound. See dynamic_sky_pose and sun_local_origin_preservation."})
	events["native_preservation_after"] = {"flora_geometry":flora_geometry_after,"world_geometry":world_geometry_after,"dynamic_sky_pose":_dynamic_sky_pose(),"appearance_fixture":{"sky":game.sky,"night_amount":game.world.night_amount,"night_target":game.world._night_target},"flora_exact":var_to_bytes(flora_geometry_before) == var_to_bytes(flora_geometry_after),"world_exact":var_to_bytes(world_geometry_before) == var_to_bytes(world_geometry_after)}
	_check(_fingerprint() == fingerprint_before,"Source or native executable/resource pack fingerprints remain unchanged")
	_finish()

func _physics_process(delta: float) -> void:
	if finished or not sampling: return
	if planted and not get_tree().paused:
		active_elapsed += delta
	var state: Dictionary = _state(delta)
	samples.append(state)
	if phase in ["bloom_wake","pause_midwake"]:
		natural_samples.append(state)
	last_state = state
	raw.store_line("%d,%.9f,%.9f,%d,%.9f,%s,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d,%d" % [state.monotonic_usec,state.elapsed_wall_s,state.elapsed_active_s,state.physics_frame,state.physics_delta_s,state.phase,int(state.paused),state.bloom_clock_s,state.visual_bloom,state.wake_clock_s,state.rotation_z_rad,state.resident_xz[0],state.resident_xz[1],state.resident_velocity_xz[0],state.resident_velocity_xz[1],state.mana,int(state.durable_awake),int(state.path_restored)])
	var observed: Array[Dictionary] = _flora_readback()
	if phase in ["bloom_wake","pause_midwake"]:
		flora_samples.append({"state":state,"flora":observed})
	for flora: Dictionary in observed:
		flora_raw.store_line("%d,%.9f,%d,%s,%d,%.9f,%.9f,%d,%s,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d,%s,%d" % [state.monotonic_usec,state.elapsed_active_s,state.physics_frame,state.phase,int(state.paused),state.bloom_clock_s,state.visual_bloom,flora.index,flora.path,flora.id,flora.distance,flora.scale_y,flora.progress,flora.color[0],flora.color[1],flora.color[2],flora.color[3],flora.distance_muted,flora.distance_restored,flora.color_spread,flora.children,flora.colors_sha256,int(flora.identity_exact)])
		flora_rows += 1
		var coherent: bool = flora.identity_exact and flora.children == FLORA_CHILD_COUNT and flora.color_spread <= READBACK_EPSILON and flora.color_scale_coherent and flora.progress >= -READBACK_EPSILON and flora.progress <= 1.0+READBACK_EPSILON
		if not coherent and wave_guard_first_failure.is_empty():
			wave_guard_first_failure = {"state":state,"flora":flora}
		wave_tick_guards = wave_tick_guards and coherent
	observed_tick.emit()

func _process(_delta: float) -> void:
	if not finished and raw != null and float(Time.get_ticks_usec()-started_usec)/1000000.0 > MAX_WALL_SECONDS:
		_check(false,"Bounded wake review exceeded45 wall seconds")
		_finish()

func _validate_natural() -> void:
	var monotone := true
	var sleeping_during_bloom := true
	var stationary_until_awake := true
	var clocks_monotone := true
	var all_finite := true
	var ordinary_tick_delta := true
	var max_step := 0.0
	var changed_ticks := 0
	var previous: Dictionary = accepted
	var wake_start_lower := -1.0
	var wake_start_upper := -1.0
	var wake_end := -1.0
	var bloom_end := -1.0
	var start_xz: Vector2 = Vector2(accepted.resident_xz[0],accepted.resident_xz[1])
	for state: Dictionary in natural_samples:
		var angle: float = float(state.rotation_z_rad)
		var clock: float = float(state.wake_clock_s)
		var prev_angle: float = float(previous.rotation_z_rad)
		all_finite = all_finite and is_finite(angle) and is_finite(clock) and is_finite(float(state.elapsed_active_s))
		ordinary_tick_delta = ordinary_tick_delta and absf(float(state.physics_delta_s)-1.0/60.0) < .000001
		monotone = monotone and angle <= prev_angle+.000001 and angle >= -.000001 and angle <= EXPECTED_SLEEP_ANGLE+.000001
		clocks_monotone = clocks_monotone and clock >= float(previous.wake_clock_s)-.000001 and clock <= EXPECTED_WAKE_SECONDS+.000001
		max_step = maxf(max_step,absf(angle-prev_angle))
		if angle < prev_angle-.000001:
			changed_ticks += 1
		if float(state.bloom_clock_s) >= 0.0:
			sleeping_during_bloom = sleeping_during_bloom and absf(angle-EXPECTED_SLEEP_ANGLE) < .000001 and clock == 0.0
		elif bloom_end < 0.0:
			bloom_end = float(state.elapsed_active_s)
		if clock < EXPECTED_WAKE_SECONDS:
			var xz: Vector2 = Vector2(state.resident_xz[0],state.resident_xz[1])
			stationary_until_awake = stationary_until_awake and xz.distance_to(start_xz) <= .00001 and absf(float(state.resident_velocity_xz[0])) < .000001 and absf(float(state.resident_velocity_xz[1])) < .000001
		if wake_start_upper < 0.0 and angle < EXPECTED_SLEEP_ANGLE-.000001:
			wake_start_lower = float(previous.elapsed_active_s)
			wake_start_upper = float(state.elapsed_active_s)
		if wake_end < 0.0 and clock >= EXPECTED_WAKE_SECONDS and absf(angle) < .000001:
			wake_end = float(state.elapsed_active_s)
		previous = state
	var duration_lower: float = wake_end-wake_start_upper
	var duration_upper: float = wake_end-wake_start_lower
	var duration_ok: bool = wake_start_lower >= 0.0 and wake_end > wake_start_upper and duration_lower >= EXPECTED_WAKE_SECONDS-2.0/60.0 and duration_upper <= EXPECTED_WAKE_SECONDS+2.0/60.0
	_check(not natural_samples.is_empty() and all_finite and ordinary_tick_delta,"Every natural observation is finite and comes from ordinary60Hz physics",natural_samples.size())
	_check(sleeping_during_bloom and bloom_end >= EXPECTED_BLOOM_SECONDS-1.0/60.0 and bloom_end <= EXPECTED_BLOOM_SECONDS+2.0/60.0,"Resident remains asleep throughout the natural three-second bloom",{"observed_bloom_end_active_seconds":bloom_end})
	_check(monotone and clocks_monotone and changed_ticks >= 40,"Wake tilt changes over many ticks monotonically toward zero",{"changed_ticks":changed_ticks,"angle_monotone":monotone,"wake_clock_monotone":clocks_monotone})
	_check(max_step <= MAX_ANGLE_STEP,"The real60Hz wake has no angular snap larger than0.04rad",max_step)
	_check(duration_ok,"Observed wake start/end brackets span0.8 active seconds within two physics ticks",{"start_bracket":[wake_start_lower,wake_start_upper],"end":wake_end,"duration_bracket":[duration_lower,duration_upper],"expected_seconds":EXPECTED_WAKE_SECONDS})
	_check(stationary_until_awake,"Resident XZ and horizontal velocity remain stationary until wake finishes")
	events["natural_timing"] = {"bloom_end_active_seconds":bloom_end,"wake_start_bracket_active_seconds":[wake_start_lower,wake_start_upper],"wake_end_active_seconds":wake_end,"wake_duration_bracket_seconds":[duration_lower,duration_upper],"maximum_angular_step_rad":max_step,"changed_angle_ticks":changed_ticks,"sampling":"After-parent priority100 physics callbacks; pause excluded only from active-time sum. No expected easing formula is evaluated."}

func _check_repeat(label: String) -> void:
	var before: Dictionary = {"mana":game.mana,"transaction":game.restoration_tx,"bloom_clock":game.bloom_clock,"wake_clock":game.resident_wake_elapsed,"angle":game.resident_visual.rotation.z,"resident_count":_count_named(game,"ResidentPlaceholder"),"plant_count":_count_named(game.patch_node,"Plant"),"flora":_flora_pause_signature()}
	# Pause rebuilds the modal and frees its former buttons. Obtain another real
	# production Plant control for the later replay case, without yielding a tick.
	if not is_instance_valid(plant_button):
		game._plant_menu(false)
		plant_button = _find_button("Moonbell")
	if plant_button == null or plant_button.disabled:
		_check(false,"Ordinary Plant control unavailable for replay: "+label)
		return
	plant_button.pressed.emit()
	var after: Dictionary = {"mana":game.mana,"transaction":game.restoration_tx,"bloom_clock":game.bloom_clock,"wake_clock":game.resident_wake_elapsed,"angle":game.resident_visual.rotation.z,"resident_count":_count_named(game,"ResidentPlaceholder"),"plant_count":_count_named(game.patch_node,"Plant"),"flora":_flora_pause_signature()}
	_check(var_to_bytes(before) == var_to_bytes(after),"Repeated ordinary Plant signal neither debits/duplicates nor restarts presentation: "+label,{"before":before,"after":after})
	events[label] = {"before":before,"after":after}

func _state(delta: float) -> Dictionary:
	return {"monotonic_usec":Time.get_ticks_usec(),"elapsed_wall_s":float(Time.get_ticks_usec()-planted_usec)/1000000.0 if planted else 0.0,"elapsed_active_s":active_elapsed,"physics_frame":Engine.get_physics_frames(),"physics_delta_s":delta,"phase":phase,"paused":get_tree().paused,"bloom_clock_s":float(game.bloom_clock),"visual_bloom":float(game.patch_visual_bloom),"wake_clock_s":float(game.resident_wake_elapsed),"rotation_z_rad":float(game.resident_visual.rotation.z),"resident_xz":[game.resident.position.x,game.resident.position.z],"resident_velocity_xz":[game.resident.velocity.x,game.resident.velocity.z],"mana":float(game.mana),"durable_awake":bool(game.resident_awake),"path_restored":bool(game.path_restored)}

func _pause_signature() -> Dictionary:
	return {"bloom_clock":game.bloom_clock,"wake_clock":game.resident_wake_elapsed,"resident_time":game.resident_time,"visual_rotation":game.resident_visual.rotation,"visual_position":game.resident_visual.position,"resident_position":game.resident.position,"resident_velocity":game.resident.velocity,"mana":game.mana,"active_elapsed":active_elapsed,"flora":_flora_pause_signature()}

func _flora_identity_for(flora: Node3D) -> Dictionary:
	var children: Array[Dictionary] = []
	for child: Node in flora.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			children.append({"node":mesh_node.get_instance_id(),"mesh":mesh_node.mesh.get_instance_id() if mesh_node.mesh != null else 0,"material":mesh_node.material_override.get_instance_id() if mesh_node.material_override != null else 0,"transform":mesh_node.transform})
	return {"node":flora.get_instance_id(),"path":str(game.get_path_to(flora)),"position":flora.position,"rotation":flora.rotation,"xz_scale":Vector2(flora.scale.x,flora.scale.z),"children":children}

func _flora_identity() -> Dictionary:
	var observed: Dictionary = {}
	for index: int in range(game.patch_flora.size()):
		var flora: Node3D = game.patch_flora[index] as Node3D
		observed[str(index)] = _flora_identity_for(flora)
	return observed

func _flora_pause_signature() -> Array[Dictionary]:
	var observed: Array[Dictionary] = []
	for flora: Node3D in game.patch_flora:
		var colors: Array[Color] = []
		for child: Node in flora.get_children():
			if child is MeshInstance3D and child.material_override is BaseMaterial3D:
				colors.append((child.material_override as BaseMaterial3D).albedo_color)
		observed.append({"id":flora.get_instance_id(),"scale":flora.scale,"colors":colors})
	return observed

func _color_distance(left: Color,right: Color) -> float:
	return sqrt(pow(left.r-right.r,2)+pow(left.g-right.g,2)+pow(left.b-right.b,2)+pow(left.a-right.a,2))

func _flora_readback() -> Array[Dictionary]:
	var observed: Array[Dictionary] = []
	for index: int in range(game.patch_flora.size()):
		var flora: Node3D = game.patch_flora[index] as Node3D
		var colors: Array[Color] = []
		for child: Node in flora.get_children():
			if child is MeshInstance3D and child.material_override is BaseMaterial3D:
				colors.append((child.material_override as BaseMaterial3D).albedo_color)
		var color: Color = colors[0] if not colors.is_empty() else Color(-1,-1,-1,-1)
		var spread := 0.0
		for child_color: Color in colors:
			spread = maxf(spread,_color_distance(child_color,color))
		var progress: float = (flora.scale.y-.45)/.55
		var expected_color: Color = MUTED_COLOR.lerp(RESTORED_COLOR,clampf(progress,0,1))
		var offset: Vector3 = flora.global_position-game.patch_node.global_position
		var identity_exact: bool = flora_identity_before.has(str(index)) and var_to_bytes(_flora_identity_for(flora)) == var_to_bytes(flora_identity_before[str(index)])
		observed.append({"index":index,"path":str(game.get_path_to(flora)),"id":flora.get_instance_id(),"distance":Vector2(offset.x,offset.z).length(),"scale_y":float(flora.scale.y),"progress":progress,"color":[color.r,color.g,color.b,color.a],"distance_muted":_color_distance(color,MUTED_COLOR),"distance_restored":_color_distance(color,RESTORED_COLOR),"color_spread":spread,"children":colors.size(),"colors_sha256":_digest(colors),"identity_exact":identity_exact,"color_scale_coherent":is_finite(progress) and _color_distance(color,expected_color) <= READBACK_EPSILON})
	return observed

func _is_mixed_ring(observed: Array[Dictionary]) -> bool:
	var restored := false
	var intermediate := false
	var muted := false
	for flora: Dictionary in observed:
		restored = restored or flora.progress >= 1.0-READBACK_EPSILON
		intermediate = intermediate or (flora.progress > .10 and flora.progress < .90)
		muted = muted or flora.progress <= READBACK_EPSILON
	return restored and intermediate and muted

func _check_flora_state(restored: bool,message: String) -> void:
	var observed: Array[Dictionary] = _flora_readback()
	var coherent: bool = observed.size() == FLORA_COUNT
	for flora: Dictionary in observed:
		var target: float = 1.0 if restored and flora.distance <= FLORA_RADIUS else 0.0
		coherent = coherent and absf(float(flora.progress)-target) <= READBACK_EPSILON and flora.color_scale_coherent and flora.color_spread <= READBACK_EPSILON and flora.identity_exact and flora.children == FLORA_CHILD_COUNT
	_check(coherent,message,observed)

func _validate_flora_wave() -> void:
	var muted_first_two := true
	var central_opens_while_muted := false
	var monotone := true
	var equal_rings := true
	var outside_muted := true
	var mixed_count := 0
	var first_all_full := -1.0
	var last_progress: Array[float] = []
	var start_times: Array[float] = []
	var finish_times: Array[float] = []
	var distances: Array[float] = []
	for index: int in range(FLORA_COUNT):
		last_progress.append(0.0)
		start_times.append(-1.0)
		finish_times.append(-1.0)
		distances.append(0.0)
	for sample: Dictionary in flora_samples:
		var state: Dictionary = sample.state
		var observed: Array[Dictionary] = sample.flora
		if observed.size() != FLORA_COUNT:
			monotone = false
			continue
		var clock: float = float(state.bloom_clock_s)
		var all_full := true
		for flora: Dictionary in observed:
			var index: int = int(flora.index)
			var progress: float = float(flora.progress)
			distances[index] = float(flora.distance)
			monotone = monotone and progress >= last_progress[index]-READBACK_EPSILON
			last_progress[index] = progress
			if clock >= 0.0 and clock <= 2.0+READBACK_EPSILON:
				muted_first_two = muted_first_two and absf(progress) <= READBACK_EPSILON and flora.distance_muted <= READBACK_EPSILON
				central_opens_while_muted = central_opens_while_muted or (float(state.visual_bloom) > .75 and float(state.visual_bloom) < 1.0)
			if progress > READBACK_EPSILON and start_times[index] < 0.0:
				start_times[index] = float(state.elapsed_active_s)
			if progress >= 1.0-READBACK_EPSILON and finish_times[index] < 0.0:
				finish_times[index] = float(state.elapsed_active_s)
			if flora.distance > FLORA_RADIUS:
				outside_muted = outside_muted and absf(progress) <= READBACK_EPSILON
			all_full = all_full and progress >= 1.0-READBACK_EPSILON
			for peer: Dictionary in observed:
				if absf(float(peer.distance)-float(flora.distance)) < .00001:
					equal_rings = equal_rings and absf(float(peer.progress)-progress) < .00002
		if clock >= 2.0 and clock <= 3.0 and _is_mixed_ring(observed):
			mixed_count += 1
		if all_full and first_all_full < 0.0:
			first_all_full = float(state.elapsed_active_s)
	var starts_in_window := true
	var finishes_in_window := true
	var distance_order := true
	var ordered_pairs := 0
	var outside_count := 0
	for near: int in range(FLORA_COUNT):
		if distances[near] > FLORA_RADIUS:
			outside_count += 1
			continue
		starts_in_window = starts_in_window and start_times[near] > 2.0 and start_times[near] < 3.0
		finishes_in_window = finishes_in_window and finish_times[near] > start_times[near] and finish_times[near] <= 3.0+1.0/60.0
		for far: int in range(FLORA_COUNT):
			if distances[far]-distances[near] > .20:
				ordered_pairs += 1
				distance_order = distance_order and start_times[near]+1.0/60.0-READBACK_EPSILON <= start_times[far] and finish_times[near]+1.0/60.0-READBACK_EPSILON <= finish_times[far]
	_check(wave_tick_guards and flora_rows == samples.size()*FLORA_COUNT,"Every sampled tick reads all18 actual flora with coherent color/scale and exact child geometry identities",{"flora_rows":flora_rows,"physics_rows":samples.size(),"first_failure":wave_guard_first_failure})
	_check(muted_first_two and central_opens_while_muted,"All18 flora stays muted for the first2s while the central plant visibly opens")
	_check(monotone and starts_in_window and finishes_in_window,"Actual flora color/scale restores monotonically over observed2–3s ticks",{"starts":start_times,"finishes":finish_times})
	_check(distance_order and ordered_pairs > 0 and equal_rings,"Nearer observed rings begin and finish restoration before farther rings; equal-distance nodes agree",{"ordered_pairs":ordered_pairs,"distances":distances})
	_check(mixed_count >= 5,"Several actual intermediate ticks contain restored, partial and muted rings",mixed_count)
	_check(first_all_full > 2.0 and first_all_full <= 3.0+1.0/60.0,"All18 actual flora is fully restored by the3s bloom boundary",first_all_full)
	_check(outside_muted,"Any actual tracked flora outside3.5m remains muted",{"actual_outside_flora":outside_count,"outside_fixture_added":false,"other_scenery_proof":"Whole native world geometry/collider/static-albedo signature is compared independently."})
	events["flora_wave_timing"] = {"distances_xz_m":distances,"first_nonmuted_active_s":start_times,"first_complete_active_s":finish_times,"first_all_complete_active_s":first_all_full,"mixed_ring_ticks":mixed_count,"ordered_distance_pairs":ordered_pairs,"actual_outside_flora":outside_count,"expectations":"Actual observations only: first2s muted, color/scale monotone, nearer rings earlier, mixed rings, all complete by3s. No implementation edge/feather formula is evaluated."}

func _check_hud(label: String) -> void:
	var observed: Dictionary = {}
	var valid := true
	var labels: Array[Label] = [game.prompt as Label,game.notice as Label,game.mana_label as Label,game.helper as Label]
	var names: Array[String] = ["prompt","notice","mana_label","helper"]
	var expected_sizes: Array[int] = [7,6,5,5]
	for index: int in range(labels.size()):
		var item: Label = labels[index]
		var color: Color = item.get_theme_color("font_shadow_color")
		var outline: int = item.get_theme_constant("shadow_outline_size")
		var actual: Dictionary = {"node_id":item.get_instance_id(),"class":item.get_class(),"text":item.text,"visible_in_tree":item.is_visible_in_tree(),"rect":item.get_global_rect(),"font_shadow_color":color,"shadow_outline_size":outline,"has_shadow_color_override":item.has_theme_color_override("font_shadow_color"),"has_outline_override":item.has_theme_constant_override("shadow_outline_size")}
		valid = valid and actual.has_shadow_color_override and actual.has_outline_override and color == Color.BLACK and outline == expected_sizes[index]
		observed[names[index]] = actual
	_check(valid,"Actual production HUD Labels carry black shadow outlines: "+label,observed)
	events["hud_"+label] = {"labels":observed,"style_readback_valid":valid,"pixel_contrast_proved":false,"human_readability_accepted":false}

func _validate_pause_and_skip(private_directory: String) -> void:
	# Independent reset transaction. The primary natural timeline above never skips.
	phase = "skip_fixture"
	game.set_appearance("night","sunny")
	game.player.teleport_safe(Vector3(13,0,.3),0.0)
	await _ticks(30)
	if finished: return
	game._update_context()
	_check(game.player.is_on_floor() and game.context == "patch_plant","Separate wave pause/Skip case uses the ordinary grounded Plant context")
	game._interact()
	plant_button = _find_button("Moonbell")
	if plant_button == null or plant_button.disabled:
		_check(false,"Separate wave pause/Skip fixture lacks the ordinary Plant button")
		return
	var mana_before: float = game.mana
	plant_button.pressed.emit()
	_check(game.mana == mana_before-25.0 and game.bloom_clock == 0.0,"Separate reset transaction pays exactly once before its wave/Skip case")
	var cast_receipt: Dictionary = _paid_file_observation(private_directory)
	var transaction: String = str(game.restoration_tx)
	var mana_after_cast: float = game.mana
	_check(_paid_semantics_match(cast_receipt,transaction) and float(cast_receipt.get("mana",-1.0)) == mana_before-25.0,"Separate cast immediately persists its single debit and coupled paid flags",cast_receipt)
	while game.bloom_clock >= 0.0 and game.bloom_clock < 2.5 and not finished:
		await observed_tick
	if finished: return
	_check(_is_mixed_ring(_flora_readback()),"Separate ordinary Pause begins during a real mixed radial wave")
	game._pause()
	var paused_before: Dictionary = _pause_signature()
	phase = "pause_midwave"
	await _ticks(PAUSE_TICKS)
	if finished: return
	var paused_after: Dictionary = _pause_signature()
	_check(get_tree().paused and var_to_bytes(paused_before) == var_to_bytes(paused_after),"Ordinary Pause freezes the partially restored18-node wave exactly across30physics ticks",{"before":paused_before,"after":paused_after})
	events["paused_midwave"] = {"before":paused_before,"after":paused_after,"ticks":PAUSE_TICKS,"exact":var_to_bytes(paused_before) == var_to_bytes(paused_after)}
	var finish_button: Button = _find_button("Finish the bloom")
	if finish_button == null:
		_check(false,"Ordinary Finish-the-bloom control is unavailable")
		return
	phase = "skip_pressed"
	var mana_at_skip: float = game.mana
	var before_button: Dictionary = _paid_file_observation(private_directory)
	finish_button.pressed.emit()
	var after_button: Dictionary = _paid_file_observation(private_directory)
	_check(get_tree().paused and game.bloom_clock < 0.0 and game.resident_wake_elapsed == 0.0 and absf(game.resident_visual.rotation.z-EXPECTED_SLEEP_ANGLE) < .000001,"Ordinary Finish-bloom applies the final flora while paused; resident wake waits for Resume")
	_check_flora_state(true,"Ordinary Finish-bloom restores all18 actual flora immediately")
	_check(_paid_semantics_match(before_button,transaction) and _paid_semantics_match(after_button,transaction) and float(before_button.get("mana",-1.0)) >= mana_after_cast and float(before_button.get("mana",101.0)) <= mana_at_skip+READBACK_EPSILON,"Cast paid transaction/flags survive ordinary waiting and legitimate recharge/autosave",{"cast":cast_receipt,"before_button":before_button,"after_button":after_button,"live_magic_after_cast":mana_after_cast,"live_magic_before_skip":mana_at_skip})
	_check(mana_at_skip > mana_after_cast and mana_at_skip <= 100.0 and game.mana == mana_at_skip and str(game.restoration_tx) == transaction and before_button.primary_sha256 == after_button.primary_sha256 and before_button.backup_sha256 == after_button.backup_sha256,"Immediate ordinary Finish-bloom signal changes no magic, transaction, primary or backup bytes",{"before_button":before_button,"after_button":after_button})
	events["ordinary_skip"] = {"input_kind":"Actual production Finish-the-bloom Button.pressed; separate reset transaction after primary natural case","transaction":transaction,"cast_receipt":cast_receipt,"immediate_pre_button_receipt":before_button,"immediate_post_button_receipt":after_button,"primary_bytes_exact_across_button":before_button.primary_sha256 == after_button.primary_sha256,"backup_bytes_exact_across_button":before_button.backup_sha256 == after_button.backup_sha256,"live_magic_after_cast":mana_after_cast,"live_magic_before_and_after_button":mana_at_skip,"expected_recharge":"Live magic can increase toward100 during normal waiting. Previously scheduled appearance autosave can persist changed recharge-delay/sky/player fields. Cast transaction and coupled paid outcomes stay exact; file-byte identity is required only across the immediate production Finish-bloom button action.","state":_state(0.0),"flora":_flora_pause_signature()}
	game._explore()
	phase = "skip_resume"
	await _ticks(60)
	if finished: return
	_check(game.resident_wake_elapsed == EXPECTED_WAKE_SECONDS and game.resident_visual.rotation.z == 0.0,"Resume after ordinary Skip still completes the natural0.8s resident wake")
	_check_flora_state(true,"Completed flora remains stable after ordinary Skip and Resume")

func _paid_file_observation(private_directory: String) -> Dictionary:
	var result: Dictionary = {"observed_usec":Time.get_ticks_usec(),"primary_sha256":FileAccess.get_sha256(private_directory.path_join("clearing.json")),"backup_sha256":FileAccess.get_sha256(private_directory.path_join("clearing.backup.json")) if FileAccess.file_exists(private_directory.path_join("clearing.backup.json")) else "missing","primary_valid":false}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(private_directory.path_join("clearing.json"))) == OK and json.data is Dictionary:
		var data: Dictionary = json.data as Dictionary
		result["primary_valid"] = game.store.validate(data).is_empty()
		result["schema_version"] = data.get("schema_version",-1)
		result["build_version"] = data.get("build_version","")
		result["restoration"] = data.get("restoration",{}).duplicate(true)
		result["mana"] = data.get("mana",-1.0)
		result["mana_delay"] = data.get("mana_delay",-1.0)
		result["sky"] = data.get("sky","")
		result["weather"] = data.get("weather","")
		result["player"] = data.get("player",{}).duplicate(true)
	return result

func _paid_semantics_match(receipt: Dictionary,transaction: String) -> bool:
	var restoration: Dictionary = receipt.get("restoration",{})
	return bool(receipt.get("primary_valid",false)) and int(receipt.get("schema_version",-1)) == 1 and receipt.get("build_version","") == "0.2.2" and restoration.get("state","") == "bloomed" and restoration.get("transaction_id","") == transaction and bool(restoration.get("resident_awake",false)) and bool(restoration.get("path_restored",false))

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _mesh_geometry(mesh: Mesh) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	if mesh == null: return {"null":true}
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(surface)
		var primitive: int = (mesh as ArrayMesh).surface_get_primitive_type(surface) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		surfaces.append({"primitive":primitive,"primitive_kind":"native_array_mesh_readback" if mesh is ArrayMesh else "primitive_mesh_triangles","arrays_sha256":_digest(mesh.surface_get_arrays(surface)),"blend_arrays_sha256":_digest(mesh.surface_get_blend_shape_arrays(surface)),"surface_material":material.get_instance_id() if material != null else 0})
	return {"id":mesh.get_instance_id(),"class":mesh.get_class(),"surfaces":surfaces}

func _geometry_signature_for_flora() -> Dictionary:
	var observed: Dictionary = {}
	for index: int in range(game.patch_flora.size()):
		var flora: Node3D = game.patch_flora[index] as Node3D
		var geometry: Array[Dictionary] = []
		for child: Node in flora.get_children():
			if child is MeshInstance3D:
				var part: MeshInstance3D = child as MeshInstance3D
				var material: BaseMaterial3D = part.material_override as BaseMaterial3D
				geometry.append({"mesh":_mesh_geometry(part.mesh),"node_id":part.get_instance_id(),"transform":part.transform,"material_id":material.get_instance_id() if material != null else 0,"roughness":material.roughness if material != null else -1.0,"emission":material.emission if material != null else Color.BLACK,"emission_energy_multiplier":material.emission_energy_multiplier if material != null else -1.0})
		observed[str(index)] = {"identity":_flora_identity_for(flora),"geometry":geometry}
	return observed

func _world_geometry_signature() -> Dictionary:
	var observed: Dictionary = {}
	_world_geometry_walk(game.world,observed,{})
	return observed

func _dynamic_sky_kind(node: Node) -> String:
	# Positive bindings to the existing source-owned sky, not a path-only exemption.
	var world: Node = game.world
	if node == world._moon and node.get_parent() == world and str(node.name) == "Moon":
		return "source_driven_moon_origin"
	if node == world._stars and node.get_parent() == world._r36_root and str(node.name) == "QuietSkyStars":
		return "fixed_local_camera_follow_sky"
	if node == world._r36_sun and node.get_parent() == world._r36_root and str(node.name) == "VisibleSun":
		return "source_reapplied_sun_origin"
	if node is MeshInstance3D and node.get_parent() == world._r36_lines and str(node.name).begins_with("ConstellationLink"):
		var suffix: String = str(node.name).trim_prefix("ConstellationLink")
		if suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) < 48 and str(int(suffix)) == suffix:
			return "fixed_local_camera_follow_sky"
	return ""

func _check_sky_bindings(label: String,signature: Dictionary) -> void:
	var world: Node = game.world
	var sky_nodes := 0
	var moon_nodes := 0
	var sun_nodes := 0
	for record: Dictionary in signature.values():
		if record.get("dynamic_sky_kind","") == "fixed_local_camera_follow_sky": sky_nodes += 1
		if record.get("dynamic_sky_kind","") == "source_driven_moon_origin": moon_nodes += 1
		if record.get("dynamic_sky_kind","") == "source_reapplied_sun_origin": sun_nodes += 1
	var positive: bool = world._r36_root.get_parent() == world and str(world._r36_root.name) == "ProposedSky36" and world._r36_lines.get_parent() == world._r36_root and str(world._r36_lines.name) == "FictionalConstellations" and world._r36_lines.get_child_count() == 48 and _dynamic_sky_kind(world._moon) == "source_driven_moon_origin" and _dynamic_sky_kind(world._stars) == "fixed_local_camera_follow_sky" and _dynamic_sky_kind(world._r36_sun) == "source_reapplied_sun_origin"
	_check(positive and sky_nodes == 49 and moon_nodes == 1 and sun_nodes == 1,"Sky handling positively binds exactly49 fixed-local meshes plus existing Sun/Moon origins: "+label,{"fixed_local_sky_meshes":sky_nodes,"direct_moon_meshes":moon_nodes,"bounded_sun_origin_meshes":sun_nodes,"binding_positive":positive})

func _xyz(value: Vector3) -> Array[float]:
	return [float(value.x),float(value.y),float(value.z)]

func _sun_native_readback() -> Dictionary:
	var sun_mesh: MeshInstance3D = game.world._r36_sun as MeshInstance3D
	var local: Transform3D = sun_mesh.transform
	var anchor: Vector3 = game.world._m37_anchor_sun_position
	return {"node_id":sun_mesh.get_instance_id(),"parent_id":sun_mesh.get_parent().get_instance_id(),"mesh_id":sun_mesh.mesh.get_instance_id(),"material_id":sun_mesh.material_override.get_instance_id(),"night_amount":game.world.night_amount,"night_target":game.world._night_target,"raw_local_transform":local,"origin":local.origin,"basis":local.basis,"scale":sun_mesh.scale,"anchor":anchor,"origin_xyz":_xyz(local.origin),"anchor_xyz":_xyz(anchor),"scale_xyz":_xyz(sun_mesh.scale),"basis_xyz_columns":[_xyz(local.basis.x),_xyz(local.basis.y),_xyz(local.basis.z)],"origin_native_sha256":_digest(local.origin),"anchor_native_sha256":_digest(anchor),"origin_anchor_distance_m":local.origin.distance_to(anchor),"origin_anchor_exact":var_to_bytes(local.origin) == var_to_bytes(anchor)}

func _check_sun_anchor(label: String,readback: Dictionary) -> void:
	var origin: Vector3 = readback.origin as Vector3
	var anchor: Vector3 = readback.anchor as Vector3
	var finite: bool = is_finite(origin.x) and is_finite(origin.y) and is_finite(origin.z) and is_finite(anchor.x) and is_finite(anchor.y) and is_finite(anchor.z)
	_check(finite and readback.origin_anchor_exact and readback.night_amount == 1.0 and readback.night_target == 1.0 and _dynamic_sky_kind(game.world._r36_sun) == "source_reapplied_sun_origin","Actual existing Sun origin byte-matches its current source anchor at night1: "+label,readback)

func _dynamic_sky_pose() -> Dictionary:
	var world: Node = game.world
	var camera: Camera3D = get_viewport().get_camera_3d()
	var moon: MeshInstance3D = world._moon as MeshInstance3D
	var sky_root: Node3D = world._r36_root as Node3D
	var sun_readback: Dictionary = _sun_native_readback()
	return {"observed_usec":Time.get_ticks_usec(),"physics_frame":Engine.get_physics_frames(),"active_camera_id":camera.get_instance_id() if camera != null else 0,"active_camera_global_transform":camera.global_transform if camera != null else Transform3D.IDENTITY,"sky_root_id":sky_root.get_instance_id(),"sky_root_parent_id":sky_root.get_parent().get_instance_id(),"sky_root_local_transform":sky_root.transform,"sky_root_global_transform":sky_root.global_transform,"moon_id":moon.get_instance_id(),"moon_parent_id":moon.get_parent().get_instance_id(),"moon_local_transform":moon.transform,"moon_global_transform":moon.global_transform,"moon_immutable_anchor":world._m37_anchor_moon_position,"sun_native_readback":sun_readback,"living_motion_elapsed_s":world._m37_elapsed,"flora_radius_classification":"none; camera-follow celestial geometry is not ground flora","source_contract":["lineage/entrance52-capture03/sky-world.gd:123–128 follows the active camera with ProposedSky36 global position","lineage/entrance52-capture03/motion-world.gd:193–202 applies orbit basis, reapplies the current Sun anchor and directly writes World-child Moon global origin"],"sun_origin_source_contract":["lineage/entrance52-capture03/sky-world.gd:121 reapplies Sun local origin from normalized light global basis at120m","lineage/entrance52-capture03/motion-world.gd:211–216 refreshes the current Sun anchor on appearance application; line201 reapplies it to the actual Sun"],"strict_signature":"49 descendants retain byte-exact mesh-local transforms/bounds; Sun local basis/scale/native channels remain exact and only its local origin is checked as measured endpoint distance<=0.0001m at matching night1 with exact origin-to-current-anchor proof. Moon retains exact native basis/scale/immutable anchor; all arrays/aliases/IDs remain exact. Raw/numeric Sun local transform/origin/basis/scale/anchor and dynamic global sky/direct Moon origin are recorded separately."}

func _world_geometry_walk(node: Node,observed: Dictionary,meshes: Dictionary) -> void:
	var path: String = str(game.world.get_path_to(node))
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var native: Dictionary = {"node_id":node.get_instance_id(),"parent_id":node.get_parent().get_instance_id(),"class":node.get_class()}
		var sky_kind: String = _dynamic_sky_kind(node)
		if sky_kind == "source_driven_moon_origin":
			native["dynamic_sky_kind"] = sky_kind
			native["local_basis"] = (node as Node3D).transform.basis
			native["local_scale"] = (node as Node3D).scale
			native["immutable_moon_anchor"] = game.world._m37_anchor_moon_position
			native["sky_root_id"] = game.world._r36_root.get_instance_id()
		elif sky_kind == "source_reapplied_sun_origin":
			native["dynamic_sky_kind"] = sky_kind
			native["local_basis"] = (node as Node3D).transform.basis
			native["local_scale"] = (node as Node3D).scale
			native["sky_root_id"] = game.world._r36_root.get_instance_id()
		else:
			native["local_transform"] = (node as Node3D).transform
			if sky_kind == "fixed_local_camera_follow_sky":
				native["dynamic_sky_kind"] = sky_kind
				native["sky_root_id"] = game.world._r36_root.get_instance_id()
			else:
				native["transform"] = (node as Node3D).global_transform
		var mesh: Mesh
		var bounds: AABB
		var local_bounds: AABB
		var material: Material
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node as MeshInstance3D
			mesh = mesh_node.mesh
			material = mesh_node.material_override
			local_bounds = mesh_node.get_aabb()
			bounds = mesh_node.global_transform*local_bounds
		else:
			var instance_node: MultiMeshInstance3D = node as MultiMeshInstance3D
			var multimesh: MultiMesh = instance_node.multimesh
			material = instance_node.material_override
			local_bounds = instance_node.get_aabb()
			bounds = instance_node.global_transform*local_bounds
			if multimesh != null:
				mesh = multimesh.mesh
				native["multimesh"] = {"id":multimesh.get_instance_id(),"instance_count":multimesh.instance_count,"visible_instance_count":multimesh.visible_instance_count,"buffer_sha256":_digest(multimesh.buffer),"transform_format":multimesh.transform_format,"use_colors":multimesh.use_colors,"use_custom_data":multimesh.use_custom_data}
		if mesh != null:
			var key: int = mesh.get_instance_id()
			if not meshes.has(key): meshes[key] = _mesh_geometry(mesh)
			native["mesh"] = meshes[key]
		else: native["mesh"] = {"null":true}
		native["material_id"] = material.get_instance_id() if material != null else 0
		native["local_bounds"] = local_bounds
		if material is BaseMaterial3D:
			native["static_albedo"] = (material as BaseMaterial3D).albedo_color
		if sky_kind.is_empty():
			native["world_bounds"] = bounds
			var center: Vector3 = game.patch_node.global_position
			var dx: float = maxf(maxf(bounds.position.x-center.x,0.0),center.x-(bounds.position.x+bounds.size.x))
			var dz: float = maxf(maxf(bounds.position.z-center.z,0.0),center.z-(bounds.position.z+bounds.size.z))
			native["minimum_bounds_distance_xz_m"] = Vector2(dx,dz).length()
		observed[path] = native
	elif node is CollisionObject3D:
		var body: CollisionObject3D = node as CollisionObject3D
		observed[path] = {"node_id":body.get_instance_id(),"parent_id":body.get_parent().get_instance_id(),"class":body.get_class(),"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,"local_transform":body.transform,"transform":body.global_transform}
	elif node is CollisionShape3D:
		var collider: CollisionShape3D = node as CollisionShape3D
		var fields: Dictionary = {}
		if collider.shape != null:
			for property: Dictionary in collider.shape.get_property_list():
				var field: String = str(property.name)
				if int(property.usage) & PROPERTY_USAGE_STORAGE and field not in ["resource_name","resource_path","resource_local_to_scene","script"]:
					fields[field] = collider.shape.get(field)
		observed[path] = {"node_id":collider.get_instance_id(),"parent_id":collider.get_parent().get_instance_id(),"class":collider.get_class(),"local_transform":collider.transform,"transform":collider.global_transform,"disabled":collider.disabled,"shape_id":collider.shape.get_instance_id() if collider.shape != null else 0,"shape_class":collider.shape.get_class() if collider.shape != null else "null","stored_shape_fields_sha256":_digest(fields)}
	for child: Node in node.get_children():
		_world_geometry_walk(child,observed,meshes)

func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count

func _ticks(count: int) -> void:
	for index: int in range(count):
		if finished: return
		await observed_tick

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	if finished: return
	var capture_state: Dictionary = _state(0.0)
	if filename == "late-bloom.png":
		_check(not get_tree().paused and not game.modal.visible and game.bloom_clock >= 2.5-READBACK_EPSILON and game.bloom_clock <= 2.5+4.0/60.0,"Actual late-bloom post-draw capture remains unobscured near2.5s",capture_state)
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var saved: int = frame.save_png(output.path_join(filename))
	_check(saved == OK and not frame.is_empty(),"Actual full-graphics rendered view written: "+filename,saved)
	captures.append({"file":filename,"png_sha256":FileAccess.get_sha256(output.path_join(filename)),"size":[frame.get_width(),frame.get_height()],"phase":phase,"state":capture_state,"flora":_flora_pause_signature(),"hud_style_event":"hud_late_bloom" if filename == "late-bloom.png" else "hud_initial","unobscured":not game.modal.visible,"pixel_outline_proof":false})

func _find_button(prefix: String) -> Button:
	for child: Node in game.content.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child as Button
	return null

func _count_named(node: Node,label: String) -> int:
	var count: int = 1 if str(node.name) == label else 0
	for child: Node in node.get_children():
		count += _count_named(child,label)
	return count

func _valid_slot(value: String) -> bool:
	if not value.begins_with("wake_review_") or value.length() > 64: return false
	for character: String in value:
		if not ((character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9") or character == "_"): return false
	return true

func _check(condition: bool,message: String,observed: Variant = null) -> void:
	assertions.append({"passed":condition,"message":message,"observed":observed})
	if not condition:
		failed += 1
		print("WAKE_REVIEW_ASSERTION_FAILED ",message," ",JSON.stringify(observed))

func _fingerprint() -> Dictionary:
	if OS.has_feature("editor"):
		var source: Dictionary = {}
		for filename: String in ["project.godot","scripts/main.gd","scripts/playable.gd","scripts/baked_world.gd","tests/wake_review.gd","baked/clearing.res"]:
			source[filename] = FileAccess.get_sha256("res://"+filename)
		return {"kind":"source","sha256":source}
	var packs: Dictionary = {}
	var directory: String = OS.get_executable_path().get_base_dir().path_join("../Resources")
	var access: DirAccess = DirAccess.open(directory)
	if access != null:
		for filename: String in access.get_files():
			if filename.ends_with(".pck"):
				packs[filename] = FileAccess.get_sha256(directory.path_join(filename))
	return {"kind":"native","executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"packs_sha256":packs}

func _finish() -> void:
	if finished: return
	finished = true
	sampling = false
	if raw != null:
		raw.flush()
		raw.close()
		raw = null
	if flora_raw != null:
		flora_raw.flush()
		flora_raw.close()
		flora_raw = null
	_check(wave_tick_guards and flora_rows == samples.size()*FLORA_COUNT,"Final per-tick flora log covers all18 native nodes with coherent readback",{"flora_rows":flora_rows,"physics_rows":samples.size(),"first_failure":wave_guard_first_failure})
	var report: Dictionary = {"schema":"mush-native-resident-wake-review/2","build":"0.2.2","passed":failed == 0,"failed_assertions":failed,"assertions":assertions,"physics_samples":samples.size(),"natural_samples":natural_samples.size(),"events":events,"captures":captures,"private_save_slot":str(game.store.directory),"raw_csv":"wake-review.csv","raw_csv_sha256":FileAccess.get_sha256(output.path_join("wake-review.csv")),"flora_csv":"flora-wave.csv","flora_csv_sha256":FileAccess.get_sha256(output.path_join("flora-wave.csv")),"flora_samples":flora_rows,"engine":Engine.get_version_info().string,"native_export":not OS.has_feature("editor"),"display_server":DisplayServer.get_name(),"fingerprint_before":fingerprint_before,"fingerprint_after":_fingerprint(),"art_approved":false,"physical_input_tested":false,"scope":"Normal contextual Plant Button.pressed transaction, primary natural bloom/wake physics, monotone/no-snap0.8s tilt, first2s muted flora, observed2–3s outward restoration across all18 native nodes, actual HUD shadow-outline readback and unobscured late-bloom PNG, ordinary midwave/midwake pause, pre-wake stationary XZ, post-wake night routine, idempotent repeated signal, real paid-snapshot immediate final flora/pose and reset; separate reset transaction using the real Finish-bloom control followed by natural wake. Native world geometry/collider signatures compare bounded baseline+after at fully settled actual night1 endpoints. Flora identities/geometry are captured before appearance setup and remain strict across the wave. The prelive reset-day Sun appearance transform is not claimed unchanged. All static mesh globals/bounds and every collider remain strict;49 known sky descendants retain byte-exact locals; the positively bound existing Sun basis/scale/native fields remain exact and only its measured local-origin endpoint distance<=0.0001m is allowed at matching night1, with exact current origin/anchor readback. Direct Moon native basis/scale/immutable anchor remain strict. Existing camera-follow/orbit sky globals and Moon origin are recorded separately, with no celestial flora-radius claim. Shader uniforms, particle buffers and light animation are explicitly outside that signature. Paid Skip semantics persist across legitimate recharge/autosave; primary/backup bytes are compared immediately around the actual button action. Rendered stills/style values do not establish pixel contrast or human visual/animation approval."}
	var file: FileAccess = FileAccess.open(output.path_join("wake-review.json"),FileAccess.WRITE)
	if file == null:
		print("WAKE_REVIEW_REPORT_WRITE_FAILED ",FileAccess.get_open_error())
		game._quit_clean(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("WAKE_REVIEW_COMPLETE ",JSON.stringify({"passed":failed == 0,"samples":samples.size(),"failed":failed,"report":output.path_join("wake-review.json")}))
	game._quit_clean(0 if failed == 0 else 1)
