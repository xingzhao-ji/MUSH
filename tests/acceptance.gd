extends Node
## Runs inside the real clearing. Movement uses Godot input and physics, rather
## than calling the controller's translation or ability implementation directly.
const SaveStore = preload("res://scripts/save_store.gd")
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "float", "glow", "interact", "decorate", "pause"]
var game: Node
var results: Array[Dictionary] = []
var current: Dictionary = {}
var began_usec := 0
var original_fps := 0
var mechanics_render_probe := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	game.get_window().unfocusable = true
	game.get_window().mouse_passthrough = true
	game.mobile_release_requested.connect(_debug_release237)
	process_physics_priority = game.player.process_physics_priority + 1
	call_deferred("_run")


func _run() -> void:
	began_usec = Time.get_ticks_usec()
	var fingerprint_start := _build_fingerprint()
	original_fps = Engine.max_fps
	Engine.max_fps = 120
	await _frames(30)
	var selected := ""
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()-1):
		if arguments[index]=="--test": selected=arguments[index+1]
	mechanics_render_probe = "--mechanics-render-probe" in arguments
	if mechanics_render_probe and selected != "T02":
		_begin("selection", "Mechanics rendering diagnostic command-line validation")
		_assert(false, "--mechanics-render-probe requires --test T02")
		_finish()
	for scenario: Array in [["T01",_t01],["T02",_t02],["T03",_t03],["T04",_t04],["T05",_t05],["T06",_t06],["T07",_t07],["T08",_t08],["T09",_t09],["T10",_t10],["T11",_t11],["T12",_t12],["T13",_t13],["T14",_t14],["T16",_t16]]:
		if not (mechanics_render_probe and selected != "T02") and (selected.is_empty() or selected==scenario[0]): await scenario[1].call()
	if results.is_empty():
		_begin("selection","Verification command-line validation")
		_assert(false,"Unknown test ID",selected)
		_finish()
	_release_all()
	Engine.max_fps = original_fps
	get_tree().paused = false
	var failed := 0
	for result in results:
		if result.automated_status == "fail": failed += 1
	var fingerprint_end := _build_fingerprint()
	var build_unchanged := _same_data(fingerprint_start,fingerprint_end)
	if not build_unchanged:
		failed+=1
		print("VERIFY_BUILD_CHANGED: build/source files changed while verification was running; rerun the stable build.")
	var report := {
		"build_version": "0.3.0", "engine": Engine.get_version_info(),
		"platform": OS.get_name(), "os_version": OS.get_version(), "processor": OS.get_processor_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"executable": OS.get_executable_path().get_file(), "native_export": not OS.has_feature("editor"),
		"build_fingerprint": fingerprint_start,"build_unchanged_during_verification":build_unchanged,"final_build_fingerprint":fingerprint_end,
		"elapsed_seconds": float(Time.get_ticks_usec() - began_usec) / 1000000.0,
		"mechanics_render_probe": mechanics_render_probe,
		"automated_failed_scenarios": failed, "acceptance_complete": false,
		"pending_gates": ["T15 separate measured performance captures", "Actual user review of fixed day/night views", "Manual scope listed for each scenario; automated assertions do not certify visual motion quality or physical-controller behavior"],
		"tests": results
	}
	var report_dir := _report_directory()
	var error := DirAccess.make_dir_recursive_absolute(report_dir)
	if error == OK:
		var file := FileAccess.open(report_dir.path_join("acceptance.json"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
			file.flush()
			file.close()
		else: error = FileAccess.get_open_error()
	if error != OK:
		push_error("Cannot write verification report: " + error_string(error))
		failed += 1
	print("VERIFY_COMPLETE failed=", failed, " report=", report_dir.path_join("acceptance.json"))
	# Allow this async test stack and its local resources to return before exit.
	game._quit_clean.call_deferred(0 if failed == 0 else 1)


func _begin(id: String, scope: String, manual: Array = []) -> void:
	current = {"id": id, "automated_scope": scope, "manual_or_external_scope": manual, "assertions": [], "measurements": {}}
	current.measurements.desktop_input_isolation243={"window_no_focus":game.get_window().unfocusable,"window_mouse_passthrough":game.get_window().mouse_passthrough,"native_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"native_mouse_passthrough":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH),"verification_cursor_visible":Input.mouse_mode==Input.MOUSE_MODE_VISIBLE}
	_release_all()
	game._explore()


func _assert(condition: bool, requirement: String, evidence: Variant = null) -> void:
	current.assertions.append({"pass": condition, "requirement": requirement, "evidence": evidence})
	if not condition:
		print("VERIFY_ASSERT_FAIL ", current.id, " ", requirement, " ", str(evidence))


func _finish() -> void:
	var failed := 0
	for assertion in current.assertions:
		if not assertion.pass: failed += 1
	current.automated_status = "pass" if failed == 0 else "fail"
	current.full_gate_status = "failed" if failed > 0 else "partial" if not current.manual_or_external_scope.is_empty() else "passed"
	results.append(current)
	print("VERIFY ", current.id, " ", current.automated_status, " assertions=", current.assertions.size(), " remaining=", current.manual_or_external_scope.size())


func _t01() -> void:
	_begin("T01", "Input-driven traversal of the complete canonical loop, home stairs, door and annex")
	game._reset_world()
	await _frames(12)
	var waypoints: Array[Vector3] = [Vector3(-1,0,11), Vector3(4,0,9), Vector3(6.7,0,7.5), Vector3(11.3,0,7.5), Vector3(14,0,2), Vector3(12,0,-6), Vector3(5,0,-9), Vector3(-5,0,-7), Vector3(-7,0,5), Vector3(-1,0,11), Vector3(-2,0,18)]
	var trace: Array = []
	var traversed := true
	for point in waypoints:
		var reached := await _drive_to(point)
		trace.append({"target": _vec(point), "actual": _vec(game.player.position), "reached": reached})
		_assert(reached, "Required loop waypoint is reached without recovery or teleport", trace.back())
		if not reached:
			traversed = false
			break
	current.measurements.loop_trace = trace
	_assert(traversed, "Complete loop returns to spawn")
	await _place(Vector3(-1,0,11))
	_assert(await _drive_to(Vector3(0,0,3.7)), "Stair ramp reaches front-door approach")
	await _tap("interact")
	await _seconds(.7)
	_assert(game.door_state == "open", "Contextual Interact opens front door", game.door_state)
	_assert(await _drive_to(Vector3(0,.6,1)), "Actual movement passes open threshold")
	_assert(await _drive_to(Vector3(-1.4,.6,0)), "Living-room route reaches annex approach")
	_assert(await _drive_to(Vector3(-4,.6,-.4)), "Actual movement passes west arch into annex")
	_assert(game.player.position.y > .45, "Interior floor supports the player", _vec(game.player.position))
	_finish()


func _t02() -> void:
	_begin("T02", "Actual input movement under 30/60/120 render-rate caps with fixed 60 Hz physics", ["Visual foot sliding tolerance and normal/half-speed motion review"])
	if mechanics_render_probe:
		# Diagnostic presentation only: preserve the complete current world,
		# collision, controller, input path and physics frequency. These settings
		# cannot establish ordinary-view appearance or the T15 frame budget.
		game.get_window().content_scale_size = Vector2i(320,200)
		game.get_window().content_scale_factor = 1.0
		game.get_window().size = Vector2i(320,200)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		game.world.sun.shadow_enabled = false
		game.world.environment.ssao_enabled = false
		game.world.environment.ssr_enabled = false
		game.world.environment.glow_enabled = false
		await _frames(30)
		_assert(Vector2i(get_viewport().get_texture().get_size()) == Vector2i(320,200), "Mechanics probe uses an actual 320x200 render target")
		_assert(Engine.physics_ticks_per_second == 60, "Mechanics probe preserves 60 Hz physics")
		current.automated_scope = "Current-world input/collision mechanics at measured 30/60/120 render fps, with explicitly reduced diagnostic rendering"
		current.measurements.render_probe = {
			"not_T15": true, "not_visual_acceptance": true,
			"render_resolution": [get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()],
			"window_resolution": [game.get_window().size.x,game.get_window().size.y],
			"physics_hz": Engine.physics_ticks_per_second, "vsync": DisplayServer.window_get_vsync_mode(),
			"sun_shadows": game.world.sun.shadow_enabled,
			"ssao": game.world.environment.ssao_enabled, "ssr": game.world.environment.ssr_enabled,
			"glow": game.world.environment.glow_enabled, "taa": get_viewport().use_taa,
			"msaa_3d": int(get_viewport().msaa_3d), "scaling_3d_scale": get_viewport().scaling_3d_scale,
			"world_snapshot_sha256": FileAccess.get_sha256("res://baked/clearing.res"),
			"render_rate_tolerance_fraction": 0.05,
			"scope": "No world nodes, collision surfaces, controller, input or physics timing are removed or substituted. Pixel count and named rendering effects are reduced only in this opt-in diagnostic."
		}
	var samples: Array = []
	var all_rates_achieved := true
	for fps in [30,60,120]:
		Engine.max_fps = fps
		await _place(Vector3(-2,0,18))
		game.player.camera_yaw = 0
		_action("move_forward", true)
		await _seconds(.25)
		var from: Vector3 = game.player.position
		var frame_start := Engine.get_process_frames()
		var physics_start := Engine.get_physics_frames()
		var time_start := Time.get_ticks_usec()
		await _seconds(1.2)
		var seconds := float(Time.get_ticks_usec()-time_start)/1000000.0
		var physics_seconds := float(Engine.get_physics_frames()-physics_start)/60.0
		var distance := Vector2(game.player.position.x-from.x, game.player.position.z-from.z).length()
		var sample := {"cap":fps,"actual_render_fps":float(Engine.get_process_frames()-frame_start)/seconds,"physics_seconds":physics_seconds,"distance":distance,"speed":distance/physics_seconds}
		var rate_achieved: bool = absf(float(sample.actual_render_fps)-float(fps)) <= float(fps)*0.05
		sample["render_rate_achieved_within_5_percent"] = rate_achieved
		all_rates_achieved = all_rates_achieved and rate_achieved
		samples.append(sample)
		_assert(absf(sample.speed-2.2)<.10, "Walk speed stays 2.2 m/s at cap " + str(fps), sample)
		if mechanics_render_probe:
			_assert(rate_achieved, "Mechanics probe actually reaches render fps " + str(fps) + " within 5 percent", sample)
		_release_all()
		await _seconds(.25)
		_assert(Vector2(game.player.velocity.x,game.player.velocity.z).length()<.05, "Braking reaches idle without stuck movement")
	current.measurements.render_caps = samples
	current.measurements.all_requested_render_rates_achieved = all_rates_achieved
	if not mechanics_render_probe and not all_rates_achieved:
		current.manual_or_external_scope.append("Ordinary-view rendering did not achieve every requested 30/60/120 fps condition; caps alone do not prove unsupported actual render rates. See the separately labelled mechanics rendering probe.")
	Engine.max_fps = 120
	await _place(Vector3(-2,0,18))
	game.player.camera_yaw = 0
	_action("move_forward",true)
	_action("move_right",true)
	await _seconds(.4)
	_assert(absf(Vector2(game.player.velocity.x,game.player.velocity.z).length()-2.2)<.05, "Diagonal movement is normalized")
	_release_all()
	await _seconds(.3)
	_action("move_back",true)
	await _seconds(.4)
	_assert(game.player.velocity.z>2.0, "Reverse input changes direction without frame-dependent delay")
	_release_all()
	_finish()


func _t03() -> void:
	_begin("T03", "Twenty real Float press/release cycles, interrupted rise, descent re-press and a temporary collision ceiling")
	await _place(Vector3(-2,0,12))
	var maximum_height := 0.0
	var landings := 0
	for cycle in range(20):
		var baseline: float = game.player.position.y
		_action("float",true)
		await _seconds(.10 if cycle % 2 == 0 else .48)
		maximum_height = maxf(maximum_height,game.player.position.y-baseline)
		_action("float",false)
		if cycle % 4 == 0:
			await _frames(2)
			_action("float",true)
			await _frames(2)
			_action("float",false)
		await _seconds(.6)
		if game.player.state == "Grounded" and game.player.is_on_floor(): landings += 1
	_assert(landings==20, "All twenty interrupted/repeated Float cycles land", landings)
	_assert(maximum_height<=.64, "Repeated Float does not stack altitude", maximum_height)
	_assert(_count_named(game.player,"FloatRing")==1, "One Float effect is reused")
	# The normal interior has generous headroom. This fixture adds a real solid
	# ceiling inside it to exercise the actual capsule sweep against low clearance.
	await _place(Vector3(0,.6,-.8))
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer=1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(1.5,.15,1.5)
	collision.shape=box
	ceiling.position=Vector3(0,1.9,-.8)
	ceiling.add_child(collision)
	game.add_child(ceiling)
	await _frames(4)
	_action("float",true)
	await _seconds(.6)
	_assert(game.player.position.y+.95<=1.84, "Low ceiling truncates capsule rise without penetration", game.player.position.y)
	_action("float",false)
	await _seconds(.65)
	_assert(game.player.state=="Grounded", "Ceiling contact remains landable", game.player.state)
	ceiling.queue_free()
	await _frames(2)
	_finish()


func _t04() -> void:
	_begin("T04", "Physics-input Glow parity, illumination on first accepted tick, reuse while walking and hovering")
	await _place(Vector3(-2,0,12))
	game.player.set_glow(false)
	await _frames(2)
	_action("glow",true)
	await _frames(1)
	_assert(game.player.glow_on and game.player.get_node("AbilityEffects/GlowLight").visible, "Glow enables actual light on the accepted physics tick")
	_action("glow",false)
	await _frames(2)
	for number in range(11):
		await _tap("glow")
	_assert(not game.player.glow_on, "Twelve distinct presses preserve parity")
	_assert(_count_named(game.player,"GlowLight")==1, "Rapid toggles retain exactly one Glow light")
	_action("float",true)
	await _seconds(.5)
	await _tap("glow")
	_assert(game.player.glow_on and game.player.state=="Hovering", "Glow remains available while hovering")
	_action("move_forward",true)
	await _seconds(.3)
	_assert(game.player.glow_on, "Movement does not cancel Glow")
	_release_all()
	await _seconds(.6)
	_finish()


func _t05() -> void:
	_begin("T05", "Contextual door input, spam, real leaf collision, occupied close, pause and backtracking")
	game.door_state="closed"
	game.world.door_hinge.rotation.y=0
	await _place(Vector3(0,0,3.7))
	await _tap_door_physics("interact")
	_assert(game.door_state=="opening", "Door enters Opening after one Interact", {"door":game.door_state,"position":_vec(game.player.position),"state":game.player.state,"context":game.context,"mode":game.mode,"notice":game.notice.text})
	for number in range(4): await _tap_door_physics("interact")
	_assert(game.door_state=="opening", "Repeated input during swing does not stack/toggle it", {"door":game.door_state,"door_time":game.door_time,"physics_hz":Engine.physics_ticks_per_second})
	game._pause()
	var angle: float = game.world.door_hinge.rotation.y
	await _seconds(.25)
	_assert(is_equal_approx(game.world.door_hinge.rotation.y,angle), "Pause freezes moving door")
	game._explore()
	await _seconds(.7)
	_assert(game.door_state=="open", "Door completes opening after resume")
	_assert(await _drive_to(Vector3(0,.6,1.2)), "Player crosses actual open doorway")
	await _place(Vector3(-1.4,.6,1.4))
	_assert(game.request_door(), "A player clear of swing may start manual closing")
	await _frames(3)
	game.player.position=Vector3(0,.61,2)
	await _frames(3)
	_assert(game.door_state=="opening", "Entering closing sweep stops and reopens door")
	await _seconds(.7)
	_assert(game.door_state=="open", "Occupied entry ends safely Open")
	_assert(await _drive_to(Vector3(0,0,4.1)), "Backing outside remains possible")
	_assert(game.world.door_body.collision_layer!=0, "Door leaf retains a solid collider")
	_finish()


func _t06() -> void:
	_begin("T06", "In-scene socket style preview, keyboard cancel, Empty, invalid IDs and occupied swap")
	await _place(Vector3(0,.6,-.3))
	_assert(game.commit_furniture("main_chair","chair_honey"), "Valid socket commits a chair")
	game._socket_menu("main_chair")
	game._preview_furniture("chair_moss")
	_assert(game.furniture.main_chair=="chair_honey", "Preview never mutates committed assignment")
	await _tap("pause")
	_assert(not game.decor_preview and game.furniture.main_chair=="chair_honey", "Escape cancels preview and restores prior assignment")
	game._socket_menu("main_chair")
	game._preview_furniture("")
	_press_button("Done without applying")
	_assert(game.mode=="explore" and game.furniture.main_chair=="chair_honey", "Done discards Empty preview without applying")
	_assert(game.commit_furniture("main_chair",""), "Empty is an explicit reversible commit")
	_assert(not game.furniture.has("main_chair"), "Empty removes its committed collider")
	_assert(not game.commit_furniture("main_chair","table_honey"), "Incompatible styles are rejected")
	_assert(not game.commit_furniture("unknown","chair_honey"), "Unknown socket IDs are rejected")
	await _place(Vector3(-1.35,.6,1.1))
	_assert(not game.commit_furniture("main_chair","chair_moss"), "Occupied socket refuses materialization around player")
	await _place(Vector3(0,.6,-.3))
	game.commit_furniture("main_chair","chair_moss")
	game.commit_furniture("main_chair","chair_moss")
	_assert(game.furniture_nodes.size()==game.furniture.size(), "Repeated commits do not create duplicate nodes")
	game._explore()
	_finish()


func _t07() -> void:
	_begin("T07", "Growth preview/cancel, blocked reservation, pause, atomic final floor/plug and input traversal into one room")
	game._reset_world()
	await _place(Vector3(1.5,.6,.6))
	game._growth_menu()
	await _tap("pause")
	_assert(not game.room_growing and not game.room_ready and not game.world.right_room.visible, "Escape cancels dormant preview and removes its growth proxy")
	game.player.position=Vector3(4.95,.62,.6)
	_assert(not game.begin_growth(), "Player inside growth reservation blocks confirmation")
	await _place(Vector3(1.5,.6,.6))
	var obstruction := StaticBody3D.new()
	obstruction.name="AcceptanceGrowthObstruction"
	obstruction.position=Vector3(4.95,1.1,.6)
	obstruction.collision_layer=1
	var obstruction_shape := CollisionShape3D.new()
	var obstruction_box := BoxShape3D.new()
	obstruction_box.size=Vector3(.6,.6,.6)
	obstruction_shape.shape=obstruction_box
	obstruction.add_child(obstruction_shape)
	game.add_child(obstruction)
	await _frames(3)
	var blocked: bool=not game.begin_growth()
	_assert(blocked, "An actual solid obstacle in the growth reservation rejects confirmation")
	if not blocked:
		game.room_growing=false
		game.reservation.collision_layer=0
		game.world.set_room_growth(0)
	obstruction.queue_free()
	await _frames(3)
	game.verification=false
	game.store.fail_stage="write"
	game._growth_menu()
	_press_button("Grow this room")
	_assert(not game.room_growing and not game.room_ready and game.reservation.collision_layer==0, "Failed stable pre-growth save rejects the structural transaction")
	_assert(game.mode=="save_error" and _find_button("Retry")!=null and _find_button("Continue unsaved")!=null, "Growth save failure retains Retry/Continue unsaved error dialog")
	game.store.fail_stage=""
	_press_button("Continue unsaved")
	game.verification=true
	_assert(game.begin_growth(), "Unobstructed growth begins")
	_assert(not game.begin_growth(), "Second growth request is consumed without a duplicate room")
	_assert(game.reservation.collision_layer!=0 and game.world.wall_plug.visible, "Growth retains reservation blocker and closed arch")
	game._pause()
	var progress: float = game.growth_time
	await _seconds(.3)
	_assert(is_equal_approx(game.growth_time,progress), "Pause freezes room growth")
	game._explore()
	var boundary_consistent := true
	var growth_deadline := Time.get_ticks_msec()+6000
	while game.room_growing and Time.get_ticks_msec()<growth_deadline:
		await _frames(1)
		if game.room_ready:
			if game.world.wall_plug.visible or game.reservation.collision_layer!=0: boundary_consistent=false
	await _frames(2)
	_assert(not game.room_growing, "Room finishes within its expected four-second sequence")
	_assert(boundary_consistent, "Final readiness, wall-plug removal and reservation release agree at physics boundary")
	_assert(game.room_ready and not game.world.wall_plug.visible, "Final connected room replaces the wall plug")
	var floor := _ray(Vector3(4.95,1,.6),Vector3(4.95,.4,.6))
	_assert(not floor.is_empty() and absf(floor.position.y-.6)<.05, "Final room has a supporting floor before entry", _hit_info(floor))
	_assert(await _drive_to(Vector3(4.95,.6,.6)), "Player crosses the connected east arch by actual movement")
	_assert(_count_named(game.world,"GrowableRightRoom")==1 and not game.begin_growth(), "Exactly one persistent attached room exists")
	_finish()


func _t08() -> void:
	_begin("T08", "Stable snapshots plus confirmed-live child application forced termination and fresh process restart during room growth and style preview")
	game._reset_world()
	await _place(Vector3(1.5,.6,.6))
	game._save_now()
	game.begin_growth()
	await _seconds(.3)
	_assert(not game._save_now(), "Mid-growth save is deferred")
	var stable: Dictionary = game.store.load_snapshot()
	_assert(stable.ok and not stable.data.room_right, "Last on-disk snapshot contains the complete pre-growth house")
	game._load_data(stable.data)
	game._explore()
	await _frames(3)
	_assert(not game.room_growing and not game.room_ready and game.world.wall_plug.visible, "Loading pre-growth state cannot create a half-room")
	game.commit_furniture("main_chair","chair_honey")
	game._save_now()
	game._socket_menu("main_chair")
	game._preview_furniture("chair_moss")
	var preview_save: Dictionary = game.store.load_snapshot()
	_assert(preview_save.ok and preview_save.data.furniture.main_chair=="chair_honey", "Preview is excluded from the durable snapshot")
	game._load_data(preview_save.data)
	game._explore()
	_assert(not game.decor_preview and game.preview_node==null and game.furniture.main_chair=="chair_honey", "Reload drops preview without ghost or duplicate item")
	await _crash_restart("room")
	await _crash_restart("preview")
	_finish()


func _t09() -> void:
	_begin("T09", "Save/read/load semantic round-trip with actual furniture/garden nodes, both lighting states and safe support")
	game._reset_world()
	await _place(Vector3(0,.6,-.3))
	game.room_ready=true
	game.world.set_room_ready(true)
	await _frames(2)
	for socket: String in game.SOCKETS:
		var kind: String = socket.split("_")[1]
		_assert(game.commit_furniture(socket,kind+"_honey"), "Fill authored socket " + socket)
	for row in range(2):
		for column in range(4):
			# Fixture setup grants mana for each paid plant; T16 verifies the economy.
			game.mana=100.0
			game.mana_delay=0.0
			_assert(game.plant_garden(Vector3(-5.6+column*.5,0,2.8+row*.6)), "Commit garden plant within eight-plant limit")
	game.player.set_glow(true)
	game.door_state="open"
	game.world.door_hinge.rotation.y=deg_to_rad(-95)
	for choice in ["day","night"]:
		game.set_appearance(choice,"rain")
		game.mana=67.0
		game.mana_delay=.75
		var expected: Dictionary = game._snapshot()
		_assert(game._save_now(), "Stable world snapshot writes for " + choice)
		var loaded: Dictionary = game.store.load_snapshot()
		_assert(loaded.ok and _same_data(loaded.data,expected), "Serialized state round-trips for " + choice)
		game._reset_world()
		game._load_data(loaded.data)
		game._explore()
		var actual: Dictionary = game._snapshot()
		var expected_position: Array = expected.player.position
		actual.player.position=expected_position.duplicate()
		_assert(_same_data(actual,expected), "Loading restores all semantic fields for " + choice)
		_assert(game.furniture_nodes.size()==6 and game.garden_nodes.size()==8, "Six furniture and eight plant nodes load exactly once")
		await _frames(4)
		_assert(game.player.position.distance_to(Vector3(expected_position[0],expected_position[1],expected_position[2]))<.05, "Safe player position is retained after physics-boundary support validation")
		_assert(game.player.is_on_floor(), "Loaded actor resumes grounded on physical support")
	game.door_state="open"
	game.world.door_hinge.rotation.y=deg_to_rad(-95)
	_assert(await _drive_to(Vector3(-1.6,.6,0)), "Full furniture combination preserves west approach")
	_assert(await _drive_to(Vector3(-4,.6,-.4)), "Full furniture combination preserves annex exit route")
	await _place(Vector3(1.5,.6,.6))
	_assert(await _drive_to(Vector3(4.4,.6,.6)), "Full furniture combination preserves right-room connection")
	_finish()


func _t10() -> void:
	_begin("T10", "Fault-injected write/flush/replace/permission/full-disk failures and real corrupt/future/oversized local files", ["Actual full-device and OS permission-denial conditions are simulated at the write boundary"])
	var save := SaveStore.new()
	save.directory="user://verification_faults"
	_clean_slot(save)
	var snapshot: Dictionary=game._snapshot()
	_assert(save.save_snapshot(snapshot).ok, "Fault fixture primary is valid")
	_assert(save.save_snapshot(snapshot).ok, "Fault fixture backup is valid")
	# The native controller admits supported terrain below world height zero.
	var negative_height: Dictionary=snapshot.duplicate(true)
	negative_height.player.position=[15.0,-0.0341201573610306,-2.0]
	_assert(save.save_snapshot(negative_height).ok, "Supported negative player height saves without clamping")
	var height_reader := SaveStore.new()
	height_reader.directory=save.directory
	var negative_loaded: Dictionary=height_reader.load_snapshot()
	_assert(negative_loaded.ok and negative_loaded.source=="primary" and _same_data(negative_loaded.data,negative_height), "A fresh store round-trips every field with the exact negative player height")
	var height_primary := FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))
	var height_backup := FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))
	for rejected_position: Array in [["below recovery height",[15.0,-1.500001,-2.0]],["nonfinite player height",[15.0,NAN,-2.0]],["outside player X bounds",[20.000001,0.0,-2.0]],["outside player Z bounds",[15.0,0.0,26.000001]]]:
		var rejected_height: Dictionary=snapshot.duplicate(true)
		rejected_height.player.position=rejected_position[1]
		var height_rejection: Dictionary=save.save_snapshot(rejected_height)
		_assert(not save.validate(rejected_height).is_empty() and not height_rejection.ok, "Player position validation rejects " + str(rejected_position[0]))
		_assert(FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))==height_primary and FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))==height_backup, "Rejected " + str(rejected_position[0]) + " preserves both durable files")
	# Explicit fixture versions are independent of the runtime's supported list.
	# All writes stay inside the existing private verification_faults slot.
	current.measurements.supported_content_version_fixtures=["0.1.0","0.2.0","0.2.1","0.2.2","0.3.0"]
	for supported_version: String in ["0.1.0","0.2.0","0.2.1","0.2.2","0.3.0"]:
		var compatible: Dictionary=snapshot.duplicate(true)
		compatible.build_version=supported_version
		var compatible_text := JSON.stringify(compatible)
		_write_slot(save,SaveStore.PRIMARY,compatible_text)
		var backup_before_load := FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))
		var compatible_load: Dictionary=save.load_snapshot()
		_assert(compatible_load.ok and compatible_load.source=="primary" and _same_data(compatible_load.data,compatible), "Supported " + supported_version + " primary loads every schema1 semantic field", {"fixture_version":supported_version,"loaded_source":compatible_load.source,"loaded_version":compatible_load.data.get("build_version",null)})
		_assert(FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))==compatible_text and FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))==backup_before_load, "Reading supported " + supported_version + " leaves both durable files unchanged")
		var upgraded: Dictionary=save.save_snapshot(snapshot)
		var current_load: Dictionary=save.load_snapshot()
		_assert(upgraded.ok and current_load.ok and current_load.source=="primary" and _same_data(current_load.data,snapshot), "Saving supported " + supported_version + " retains every semantic field in current0.3.0", {"fixture_version":supported_version,"current_version":current_load.data.get("build_version",null)})
		_assert(FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))==compatible_text, "Saving supported " + supported_version + " keeps its exact validated prior primary as backup")
	var original_primary := FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))
	var original_backup := FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))
	for stage in ["write","flush","permission","full_disk","validate","backup","replace"]:
		save.fail_stage=stage
		var outcome: Dictionary=save.save_snapshot(snapshot)
		_assert(not outcome.ok and not outcome.error.is_empty(), "Failure reports error at " + stage)
		_assert(FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))==original_primary and FileAccess.get_file_as_string(save.directory.path_join(SaveStore.BACKUP))==original_backup, "Failure preserves both files at " + stage)
	save.fail_stage=""
	_write_slot(save,SaveStore.PRIMARY,"{corrupt")
	_assert(save.load_snapshot().source=="backup", "Corrupt JSON recovers validated backup with notice")
	_write_slot(save,SaveStore.PRIMARY," ".repeat(SaveStore.MAX_BYTES+1))
	_assert(save.load_snapshot().source=="backup", "Oversized file is rejected before parsing")
	var future: Dictionary=snapshot.duplicate(true)
	future.schema_version=2
	_write_slot(save,SaveStore.PRIMARY,JSON.stringify(future))
	_assert(save.load_snapshot().source=="future" and not save.save_snapshot(snapshot).ok, "Future schema cannot be loaded or overwritten")
	var invalid: Dictionary=snapshot.duplicate(true)
	invalid.furniture["main_chair"]="res://arbitrary.gd"
	_assert(not save.validate(invalid).is_empty(), "Arbitrary resource paths are rejected by registry validation")
	var unsupported: Dictionary=snapshot.duplicate(true)
	unsupported.build_version="0.4.0"
	_write_slot(save,SaveStore.PRIMARY,JSON.stringify(unsupported))
	_assert(save.load_snapshot().source=="future" and not save.save_snapshot(snapshot).ok, "Unsupported content version cannot fall back and overwrite newer content")
	var unsupported_alias: Dictionary=snapshot.duplicate(true)
	unsupported_alias.content_version="0.4.0"
	_write_slot(save,SaveStore.PRIMARY,JSON.stringify(unsupported_alias))
	_assert(save.load_snapshot().source=="future" and not save.save_snapshot(snapshot).ok and FileAccess.get_file_as_string(save.directory.path_join(SaveStore.PRIMARY))==JSON.stringify(unsupported_alias), "Unknown content_version alias stays protected before strict schema-key validation")
	_clean_slot(save)
	_finish()


func _t11() -> void:
	_begin("T11", "Actual spring-arm wall compression, camera collision query, doorway hysteresis and 16:9/16:10 layouts", ["Rendered camera clipping/readability and UI usability require visual inspection"])
	game.door_state="open"
	game.world.door_hinge.rotation.y=deg_to_rad(-95)
	await _place(Vector3(0,.6,-1.5))
	game.player.camera_yaw=PI
	await _seconds(.8)
	var arm: SpringArm3D=game.player.get_node("CameraRig/SpringArm3D")
	_assert(arm.get_hit_length()<2.2, "Real wall compresses spring arm below its interior nominal distance", arm.get_hit_length())
	_assert(_camera_clear(), "Camera lens does not occupy a world solid")
	await _camera_fast_turn_regression()
	await _place(Vector3(0,0,3.6))
	await _seconds(.4)
	_assert(not game.player._indoor, "Front approach uses outdoor camera volume", {"position":_vec(game.player.position),"indoor":game.player._indoor,"nominal":game.player._camera_nominal})
	game.player.position=Vector3(0,.6,2.8)
	await _seconds(.25)
	_assert(game.player._indoor, "Threshold crossing selects interior volume")
	var stable := true
	for n in range(12):
		game.player.position=Vector3(0,.6,2.96+(.04 if n%2==0 else -.04))
		await _frames(2)
		if not game.player._indoor: stable=false
	_assert(stable, "Threshold jitter remains inside hysteresis without camera flicker")
	var window_size := get_window().size
	for size: Vector2i in [Vector2i(960,540),Vector2i(960,600)]:
		get_window().size=size
		await _frames(4)
		game._pause()
		var rect: Rect2=game.modal.get_global_rect()
		_assert(rect.size.x>300 and rect.size.y>300, "Pause panel keeps positive usable dimensions at " + str(size), {"size":str(rect.size)})
		game._explore()
	get_window().size=window_size
	_finish()


func _t12() -> void:
	_begin("T12", "Held Float during pause, fresh-input requirement, real keyboard rebinding/conflict and simulated controller disconnect", ["Physical controller unplug/reconnect and genuine OS application focus loss"])
	await _place(Vector3(-2,0,12))
	_action("float",true)
	await _seconds(.45)
	game._pause()
	_assert(game.player.state=="Descending", "Opening Pause clears held Float and initiates safe descent")
	game._explore()
	await _seconds(.7)
	_assert(game.player.state=="Grounded", "Held control cannot reactivate Float after resume")
	_action("float",false)
	await _frames(3)
	_action("float",true)
	await _seconds(.45)
	_assert(game.player.state=="Hovering", "A freshly released/repressed control can Float")
	_release_all()
	await _seconds(.6)
	game._controls_menu()
	game.rebind_action="glow"
	_key(KEY_W,true)
	await _frames(2)
	_key(KEY_W,false)
	_assert(game.settings.bindings.glow==KEY_G and game.rebind_action=="glow", "A conflicting key is refused without changing binding")
	_key(KEY_H,true)
	await _frames(2)
	_key(KEY_H,false)
	_assert(game.settings.bindings.glow==KEY_H and game.rebind_action.is_empty(), "A free physical keyboard key rebinds Glow")
	game._explore()
	await _frames(3)
	var glow_before: bool=game.player.glow_on
	_key(KEY_H,true)
	await _frames(2)
	_key(KEY_H,false)
	_assert(game.player.glow_on!=glow_before, "Rebound physical keyboard event activates the ability")
	Input.joy_connection_changed.emit(91,false)
	await _frames(2)
	_assert(game.mode=="pause" and get_tree().paused, "Controller disconnection signal pauses and releases controls")
	game.settings.bindings=game.BINDINGS.duplicate()
	game._setup_input()
	game._explore()
	_finish()


func _t13() -> void:
	_begin("T13", "Real falls into empty stream/bounds and save-overlap recovery using physical support queries")
	await _place(Vector3(-2,0,12))
	var safe: Vector3=game.player.safe_position
	game.player.position=Vector3(9,.5,12)
	game.player.velocity=Vector3.ZERO
	await _seconds(1.6)
	_assert(game.player.state=="Grounded" and game.player.is_on_floor() and game.player.position.distance_to(safe)<.2, "Water fall recovers once to previously safe support", _vec(game.player.position))
	game.player.position=Vector3(21,0,12)
	await _seconds(.55)
	_assert(game.player.state=="Grounded" and game.player.position.x<=20 and game.player.velocity.length()<.05, "Bounds recovery clears velocity and restores grounded control")
	await _place(Vector3(0,.6,-.3))
	game.commit_furniture("main_chair","chair_honey")
	var overlapped: Dictionary=game._snapshot()
	overlapped.player.position=[-1.35,.6,1.1]
	game._load_data(overlapped)
	game._explore()
	await _frames(4)
	_assert(game.player.position.distance_to(Vector3(-1.35,.6,1.1))>.5 and game.player._valid_safe_position(game.player.position), "Saved position inside furniture resolves to a clear safe marker", _vec(game.player.position))
	var start: Vector3=game.player.position
	_action("move_forward",true)
	await _seconds(.25)
	_release_all()
	_assert(game.player.position.distance_to(start)>.1, "Recovery returns actual movement control")
	_finish()


func _t14() -> void:
	_begin("T14", "Four appearance presets, rapid/cancel/apply/reload, paused blend and unchanged physical collision", ["Visual path legibility and rain masking under the home/cap"])
	await _place(Vector3(-2,0,12))
	var collision_before := _collision_signature(game.world)
	for pair: Array in [["day","sunny"],["day","rain"],["night","sunny"],["night","rain"]]:
		game.set_appearance(pair[0],pair[1])
		_assert(game.sky==pair[0] and game.weather==pair[1], "Freely select " + str(pair))
		_assert(_collision_signature(game.world)==collision_before, "Appearance preserves world collision for " + str(pair))
	game.set_appearance("day","sunny")
	game.set_appearance("night","rain")
	game.set_appearance("day","rain")
	_assert(game.sky=="day" and game.weather=="rain" and game.world._night_target==0 and game.world._rain_target==1, "Rapid Apply is last-selection-wins")
	game._appearance_menu()
	game.appearance_sky="night"
	game.appearance_weather="sunny"
	await _tap("pause")
	_assert(game.sky=="day" and game.weather=="rain", "Back discards unapplied selection")
	game._appearance_menu()
	game.set_appearance("night","rain")
	await _seconds(2.2)
	_assert(game.world.night_amount>.98 and game.world.rain_amount>.98, "UI appearance blend completes while gameplay remains paused", {"night":game.world.night_amount,"rain":game.world.rain_amount})
	game.settings.reduced_effects=true
	game._apply_settings()
	await _frames(4)
	_assert(not game.world.rain_particles.emitting and game.weather=="rain", "Reduced effects removes rain particles and retains mood")
	game._save_now()
	var loaded: Dictionary=game.store.load_snapshot()
	game.world.night_amount=0
	game.world.rain_amount=0
	game._load_data(loaded.data)
	_assert(game.sky=="night" and game.weather=="rain", "Selected target round-trips without a forced clock")
	_assert(game.world.night_amount>.98 and game.world.rain_amount>.98, "Reload applies target directly rather than storing a half-transition")
	game.settings.reduced_effects=false
	game._apply_settings()
	game._explore()
	_finish()


func _t16() -> void:
	_begin("T16", "Current paid planting and resident learning: actual contextual menus, natural wake, one debit, recharge, garden/resident/path and coupled persistence", ["Visual bloom quality, full restoration radius/color spread, and resident wake easing"])
	game._reset_world()
	await _place(Vector3(12,0,-4))
	_assert(await _drive_to(Vector3(15,0,-7)), "Scenic path is physically traversable while forest is faded")
	await _place(Vector3(13,0,.3))
	await _tap("interact")
	_assert(game.mode=="plant_preview", "Focused patch Interact opens reusable seed choice")
	var locked: Button=_find_button("Sunfern")
	_assert(locked!=null and locked.disabled, "Locked plant selection communicates unavailable seed")
	await _tap("pause")
	_assert(game.restoration_state=="faded", "Plant preview Cancel leaves soil unchanged")
	game.mana=24
	game.mana_delay=1
	await _tap("interact")
	_press_button("Moonbell")
	await _frames(3)
	_assert(game.mana==24 and game.restoration_state=="faded", "Low-magic planting leaves currency, soil and rewards unchanged")
	_assert(game.mode=="explore", "Rejected planting returns control so magic can recharge")
	game.mana=100
	game.mana_delay=0
	await _tap("interact")
	_press_button("Moonbell")
	_assert(game.mana==75 and game.restoration_state=="bloomed", "Accepted planting debits exactly 25 and commits its immediate bloom")
	var transaction: String=game.restoration_tx
	_assert(not game.plant_patch() and not game.cast_plant() and game.mana==75 and game.restoration_tx==transaction, "Repeated planting or growth confirmation cannot debit or reward twice")
	_assert(_has_emission(game.patch_node), "Accepted casting produces same-tick visible luminous feedback")
	var pending: Dictionary=game.store.load_snapshot()
	_assert(pending.ok and pending.data.mana==75 and pending.data.restoration.state=="bloomed" and pending.data.restoration.resident_awake and pending.data.restoration.path_restored, "Debit and final forest/resident/path outcomes persist together before bloom ends")
	game._pause()
	var clock: float=game.bloom_clock
	await _seconds(.25)
	_assert(is_equal_approx(game.bloom_clock,clock) and game.mana==75, "Pause freezes bloom and mana regeneration")
	game._explore()
	await _seconds(3.15)
	_assert(game.patch_visual_bloom>=.99 and game.bloom_clock<0, "Visible bloom completes within the three-second presentation", {"visual":game.patch_visual_bloom,"clock":game.bloom_clock,"mana":game.mana,"mode":game.mode,"paused":get_tree().paused})
	_assert(game.mana>93 and game.resident_awake and game.path_restored, "Mana recharges and both idempotent outcomes are active", {"mana":game.mana,"delay":game.mana_delay,"clock":game.bloom_clock})
	await _seconds(.9)
	_assert(game.bloom_clock<0 and game.resident_awake and game.resident_wake_elapsed==game.RESIDENT_WAKE_SECONDS and absf(game.resident_visual.rotation.z)<.000001, "Natural post-bloom ticks complete the resident wake before any reload", {"bloom_clock":game.bloom_clock,"wake_clock":game.resident_wake_elapsed,"angle":game.resident_visual.rotation.z})
	var resident_count := _count_named(game,"ResidentPlaceholder")
	game._load_data(pending.data)
	game._explore()
	_assert(game.patch_visual_bloom==1 and game.bloom_clock<0 and game.mana==75 and _count_named(game,"ResidentPlaceholder")==resident_count, "Reload finishes pending visuals without a second debit or resident")
	await _place(Vector3(12,0,-4))
	_assert(await _drive_to(Vector3(15,0,-7)), "Same scenic route remains traversable after restoration")
	await _place(game.resident.position+Vector3(1,0,0))
	await _tap("interact")
	_assert(game.mode=="dialogue", "Awake resident interaction opens one dialogue")
	await _tap("pause")
	_assert(game.mode=="explore" and not game.resident_talking, "Dialogue Cancel always restores control and routine")
	await _place(Vector3(-4.8,0,4.8))
	game._begin_garden_preview("moonbell")
	await _tap("pause")
	_assert(game.garden.is_empty() and game.garden_ghost==null, "Free-garden Cancel discards uncommitted preview")
	_assert(not game.plant_garden(Vector3(-4.8,0,3.5),"sunfern"), "Locked garden seed type cannot plant")
	_assert(not game.plant_garden(Vector3(0,0,0)), "Garden rejects positions outside its soil bounds")
	game.mana=100
	game.mana_delay=0
	_assert(game.plant_garden(Vector3(-5.3,0,3.2)), "Ground-supported free position creates one garden plant")
	_assert(not game.plant_garden(Vector3(-5.3,0,3.2)) and game.garden.size()==1, "Repeated overlapping confirmation cannot duplicate garden plant")
	game.mana=100
	game.mana_delay=0
	game.verification=false
	game.store.fail_stage="write"
	_assert(game.plant_garden(Vector3(-4.75,0,3.2)), "A second accepted paid planting retains its outcome when writing fails")
	var id: String=game.garden[1].id
	_assert(game.garden[1].state=="bloomed" and game.mana==75, "Failed plant write preserves the coherent single-debit outcome in memory")
	_assert(game.mode=="save_error" and _find_button("Retry")!=null and _find_button("Continue unsaved")!=null, "Paid planting save failure retains Retry and Continue unsaved")
	game.store.fail_stage=""
	_press_button("Retry")
	_assert(game.mode=="explore" and not game.dirty, "Retry persists the same plant transaction and resumes play")
	game.verification=true
	_assert(not game.cast_plant(id) and game.mana==75 and game.restoration_tx==transaction, "Garden replay never awards forest restoration again")
	game._save_now()
	var garden_snapshot: Dictionary=game.store.load_snapshot()
	loaded_garden_check(garden_snapshot,id)
	game._load_data(garden_snapshot.data)
	game._explore()
	await _frames(3)
	_assert(game.garden_bloom.is_empty() and game.garden_nodes[id].scale.is_equal_approx(Vector3.ONE), "Loading paid garden bloom clears transient clocks and keeps final appearance")
	_assert(game.mana==75 and game.garden.size()==2, "Reloaded garden outcome does not add another debit or plant")
	game.mana=24
	game.mana_delay=1
	_assert(not game.plant_garden(Vector3(-5.3,0,3.9)) and game.mana==24 and game.garden.size()==2, "Low-magic garden planting preserves the existing two plants and currency")
	_assert(not game.plant_garden(Vector3(NAN,0,3.9)) and game.garden.size()==2, "Nonfinite garden coordinates are rejected before mutation")
	await _place(game.resident.position+Vector3(1,0,0))
	var learning_settle210: Dictionary = await _settled_safe_pose210()
	current.measurements["negative_height_fixture_settle210"]={"learning":learning_settle210}
	await _tap("interact")
	_assert(game.mode=="dialogue" and game.resident_talking, "Contextual resident interaction offers learning after the natural wake")
	var learning_mana: float=game.mana
	var learning_restoration: Dictionary=game._snapshot().restoration.duplicate(true)
	var learning_payload_before: Dictionary=game._save_payload()
	var learning_before: Dictionary={"mode":game.mode,"paused":get_tree().paused,"resident_awake":game.resident_awake,"bloom_clock":game.bloom_clock,"resident_wake_elapsed":game.resident_wake_elapsed,"required_wake_seconds":game.RESIDENT_WAKE_SECONDS,"unlocked_plants":game.unlocked_plants.duplicate(),"mana":game.mana,"store_directory":game.store.directory,"store_fail_stage":game.store.fail_stage,"protected_save":game.protected_save,"dirty":game.dirty,"save_timer":game.save_timer,"active_profile_loaded":game._active_profile_loaded,"save_payload":learning_payload_before.duplicate(true),"save_payload_validation_issue":game.store.validate(learning_payload_before),"notice":game.notice.text}
	_press_button("Learn to plant Sunfern")
	var learning_store := SaveStore.new()
	learning_store.directory=game.store.directory
	var learned_snapshot: Dictionary=learning_store.load_snapshot()
	var learning_payload_after: Dictionary=game._save_payload()
	var learning_after: Dictionary={"mode":game.mode,"paused":get_tree().paused,"resident_awake":game.resident_awake,"bloom_clock":game.bloom_clock,"resident_wake_elapsed":game.resident_wake_elapsed,"unlocked_plants":game.unlocked_plants.duplicate(),"mana":game.mana,"store_fail_stage":game.store.fail_stage,"protected_save":game.protected_save,"dirty":game.dirty,"save_timer":game.save_timer,"save_payload":learning_payload_after.duplicate(true),"save_payload_validation_issue":game.store.validate(learning_payload_after),"notice":game.notice.text}
	var learning_evidence: Dictionary={"before":learning_before,"after":learning_after,"fresh_store_snapshot":learned_snapshot.duplicate(true)}
	current.measurements.sunfern_learning=learning_evidence
	_assert(learned_snapshot.ok and learned_snapshot.source=="primary" and learned_snapshot.data.unlocked_plants==["moonbell","sunfern"] and game.unlocked_plants==["moonbell","sunfern"], "The accepted resident offer durably teaches Sunfern in a fresh store read",learning_evidence)
	_assert(learned_snapshot.ok and learning_store.validate(learned_snapshot.data).is_empty() and learned_snapshot.data.player.position[1]<0.0 and learned_snapshot.data.player.position[1]>=-1.5 and _same_data(learned_snapshot.data.player.position,learning_payload_before.player.position), "The learned primary preserves the actual supported negative player height without clamping",learning_evidence)
	_assert(learned_snapshot.ok and game.mana==learning_mana and learned_snapshot.data.mana==learning_mana, "Learning Sunfern spends no magic in memory or the durable snapshot",learning_evidence)
	_assert(learned_snapshot.ok and _same_data(learned_snapshot.data.restoration,learning_restoration) and _same_data(game._snapshot().restoration,learning_restoration), "Learning Sunfern retains the existing restoration transaction without another reward",learning_evidence)
	await _tap("pause")
	await _tap("interact")
	learning_evidence["repeated_dialogue"]={"mode":game.mode,"offer_present":_find_button("Learn to plant Sunfern")!=null,"unlocked_plants":game.unlocked_plants.duplicate(),"mana":game.mana,"fresh_store_snapshot":learning_store.load_snapshot()}
	_assert(game.mode=="dialogue" and _find_button("Learn to plant Sunfern")==null and game.unlocked_plants==["moonbell","sunfern"], "Repeated resident dialogue neither offers nor duplicates the learned seed",learning_evidence.repeated_dialogue)
	if learned_snapshot.ok: game._load_data(learned_snapshot.data)
	learning_evidence["reloaded"]={"unlocked_plants":game.unlocked_plants.duplicate(),"mana":game.mana,"restoration":game._snapshot().restoration.duplicate(true)}
	_assert(learned_snapshot.ok and game.unlocked_plants==["moonbell","sunfern"] and game.mana==learning_mana and _same_data(game._snapshot().restoration,learning_restoration), "Reloading the actual earned snapshot retains Sunfern without debit or repeated restoration",learning_evidence.reloaded)
	game._explore()
	await _frames(8)
	current.measurements["negative_height_fixture_settle210"]["reload"]=await _settled_safe_pose210()
	var earned_position: Array=learning_payload_before.player.position
	var earned_point := Vector3(earned_position[0],earned_position[1],earned_position[2])
	learning_evidence["ordinary_reloaded_support"]={"pending_teleport":game.player._pending_teleport,"is_on_floor":game.player.is_on_floor(),"position":_vec(game.player.global_position),"safe_position":_vec(game.player.safe_position),"earned_position":earned_position.duplicate(),"state":game.player.state}
	_assert(learned_snapshot.ok and not game.player._pending_teleport and game.player.is_on_floor() and game.player.global_position.distance_to(earned_point)<.05 and game.player.safe_position.distance_to(earned_point)<.05 and game.player.safe_position.y<0.0, "Ordinary physics reloads the earned negative-height pose on native ground",learning_evidence.ordinary_reloaded_support)
	game.mana=100
	_assert(game.plant_garden(Vector3(-5.3,0,3.9),"sunfern") and game.mana==75 and game.garden[2].type=="sunfern", "Unlocked Sunfern blooms for one paid garden placement")
	_assert(game.unlocked_plants==["moonbell","sunfern"] and not game.plant_garden(Vector3(-5.3,0,3.9),"sunfern") and game.mana==75, "Unlocked varieties remain reusable and overlapping placement does not charge again")
	await _crash_restart("bloom")
	# Interleave the logical transaction APIs while the structural transaction is
	# deliberately in flight; player route/interaction reach is covered above.
	game._reset_world()
	await _place(Vector3(1.5,.6,.6))
	_assert(game.begin_growth(), "Structural transaction begins for the paid-cast interleaving regression")
	_assert(game.plant_patch() and game.mana==75, "A paid planting during room growth debits exactly once")
	var interleaved: Dictionary=game.store.load_snapshot()
	_assert(interleaved.ok and interleaved.data.mana==75 and interleaved.data.restoration.state=="bloomed" and interleaved.data.restoration.resident_awake and interleaved.data.restoration.path_restored and not interleaved.data.room_right, "Paid outcome persists immediately while growing room remains stable Dormant on disk")
	_assert(not game.cast_plant() and game.mana==75, "Concurrent transaction retries do not charge a second time")
	await _seconds(4.2)
	_assert(game.room_ready and game.restoration_state=="bloomed", "Structural completion retains the already-committed paid plant outcome")
	await _crash_restart("mixed")
	game._reset_world()
	var legacy: Dictionary=game._snapshot()
	legacy.build_version="0.1.0"
	legacy.restoration.state="planted"
	game._load_data(legacy)
	game._explore()
	_assert(game.cast_plant() and game.mana==75 and game.restoration_state=="bloomed", "A compatible earlier unactivated bud finishes through the single paid path")
	_assert(not game.cast_plant() and game.mana==75, "A legacy bud cannot replay its debit or restoration reward")
	_finish()


func loaded_garden_check(snapshot: Dictionary, id: String) -> void:
	_assert(snapshot.ok and snapshot.data.garden.size()==2 and snapshot.data.garden[1].id==id and snapshot.data.garden[1].state=="bloomed" and snapshot.data.mana==75, "Garden paid outcome and stable ID persist as one snapshot")


func _frames(count: int) -> void:
	for number in range(count):
		await get_tree().physics_frame
		# physics_frame precedes node physics callbacks, so resume after callbacks.
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds,true,false,true).timeout


func _action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action=action
	event.pressed=pressed
	event.strength=1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)


func _tap(action: String) -> void:
	_action(action,true)
	await _frames(2)
	_action(action,false)
	await _frames(2)


func _tap_door_physics(action: String) -> void:
	_action(action,true)
	for number in range(2): await get_tree().physics_frame
	_action(action,false)
	for number in range(2): await get_tree().physics_frame

func _release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)


func _place(position: Vector3) -> void:
	_release_all()
	game._explore()
	game.player.teleport_safe(position,0)
	await _frames(8)


func _drive_to(target: Vector3) -> bool:
	_release_all()
	await _frames(3)
	var distance := Vector2(target.x-game.player.position.x,target.z-game.player.position.z).length()
	var deadline := Time.get_ticks_msec()+int((distance/1.4+3.0)*1000)
	var reached := false
	_action("move_forward",true)
	while Time.get_ticks_msec()<deadline:
		var offset := Vector3(target.x-game.player.position.x,0,target.z-game.player.position.z)
		if offset.length()<.16:
			reached=true
			break
		if game.player.state=="Recovering": break
		game.player.camera_yaw=atan2(-offset.x,-offset.z)
		await _frames(1)
	_release_all()
	await _seconds(.16)
	if not reached:
		var collisions: Array=[]
		for index in range(game.player.get_slide_collision_count()):
			var collision: KinematicCollision3D=game.player.get_slide_collision(index)
			collisions.append({"collider":str(collision.get_collider().name),"normal":_vec(collision.get_normal())})
		current.measurements.last_movement_failure={"target":_vec(target),"actual":_vec(game.player.position),"state":game.player.state,"floor":game.player.is_on_floor(),"velocity":_vec(game.player.velocity),"collisions":collisions,"mode":game.mode,"enabled":game.player.enabled,"require_release":game.player._require_release,"context":game.context,"notice":game.notice.text}
	return reached and Vector2(target.x-game.player.position.x,target.z-game.player.position.z).length()<.5 and game.player.position.y>-.2


func _find_button(prefix: String) -> Button:
	for child: Node in game.content.get_children():
		if child is Button and child.text.begins_with(prefix): return child
	return null


func _press_button(prefix: String) -> void:
	var button := _find_button(prefix)
	_assert(button!=null and not button.disabled, "Reachable enabled UI button: " + prefix)
	if button!=null and not button.disabled: button.pressed.emit()


func _ray(from: Vector3,to: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1|4|16,[game.player.get_rid()]))


func _camera_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius=.02
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,game.player.get_camera().global_position)
	query.collision_mask=1|4|16|32
	query.exclude=[game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty()


func _collision_signature(node: Node) -> Array:
	var values: Array=[]
	if node is CollisionObject3D:
		values.append([str(node.get_path()),node.collision_layer,node.collision_mask])
	if node is CollisionShape3D: values.append([str(node.get_path()),node.disabled,str(node.global_transform)])
	for child: Node in node.get_children(): values.append_array(_collision_signature(child))
	return values


func _has_emission(node: Node) -> bool:
	if node is MeshInstance3D and node.material_override is StandardMaterial3D and node.material_override.emission_enabled: return true
	for child: Node in node.get_children():
		if _has_emission(child): return true
	return false


func _count_named(node: Node, label: String) -> int:
	var count := 1 if node.name==label else 0
	for child: Node in node.get_children(): count+=_count_named(child,label)
	return count


func _same_data(actual: Variant,expected: Variant) -> bool:
	if typeof(actual) in [TYPE_INT,TYPE_FLOAT] and typeof(expected) in [TYPE_INT,TYPE_FLOAT]: return is_equal_approx(float(actual),float(expected))
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _same_data(actual[key],expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size()!=expected.size(): return false
		for index in range(actual.size()):
			if not _same_data(actual[index],expected[index]): return false
		return true
	return typeof(actual)==typeof(expected) and actual==expected


func _clean_slot(save: RefCounted) -> void:
	DirAccess.make_dir_recursive_absolute(save.directory)
	for filename in [SaveStore.PRIMARY,SaveStore.BACKUP,SaveStore.TEMP,SaveStore.BACKUP_TEMP,SaveStore.BACKUP_ROLLBACK]:
		if FileAccess.file_exists(save.directory.path_join(filename)): DirAccess.remove_absolute(save.directory.path_join(filename))


func _write_slot(save: RefCounted,filename: String,text: String) -> void:
	var file := FileAccess.open(save.directory.path_join(filename),FileAccess.WRITE)
	file.store_string(text)
	file.flush()
	file.close()


func _crash_restart(kind: String) -> void:
	var directory := ProjectSettings.globalize_path(_report_directory()).path_join("crash_"+kind)
	DirAccess.make_dir_recursive_absolute(directory)
	for filename in ["ready.json","resume.json"]:
		if FileAccess.file_exists(directory.path_join(filename)): DirAccess.remove_absolute(directory.path_join(filename))
	var setup_args := _child_arguments("setup_"+kind,kind,directory)
	var setup_pid := OS.create_process(OS.get_executable_path(),setup_args)
	_assert(setup_pid>0, "Crash probe application starts for " + kind)
	if setup_pid<=0: return
	var ready_path := directory.path_join("ready.json")
	var deadline := Time.get_ticks_msec()+20000
	while not FileAccess.file_exists(ready_path) and OS.is_process_running(setup_pid) and Time.get_ticks_msec()<deadline:
		await _seconds(.1)
	var ready: Variant=JSON.parse_string(FileAccess.get_file_as_string(ready_path)) if FileAccess.file_exists(ready_path) else {}
	var confirmed_live: bool=ready is Dictionary and ready.get("ready",false) and OS.is_process_running(setup_pid)
	_assert(confirmed_live, "Crash probe is confirmed live mid-transaction for " + kind, ready)
	if not confirmed_live:
		if OS.is_process_running(setup_pid): OS.kill(setup_pid)
		return
	# On the native Unix target OS.kill sends SIGKILL, waits for completion and
	# removes its child handle. Polling that removed handle produces an engine
	# error; successful kill is the authoritative terminal result.
	var kill_result := OS.kill(setup_pid)
	_assert(kill_result==OK, "Forced termination kills and reaps the actual application before restart for " + kind)
	if kill_result!=OK: return
	var resume_pid := OS.create_process(OS.get_executable_path(),_child_arguments("resume_"+kind,kind,directory))
	_assert(resume_pid>0, "A fresh application process restarts for " + kind)
	if resume_pid<=0: return
	var resume_path := directory.path_join("resume.json")
	deadline=Time.get_ticks_msec()+20000
	while not FileAccess.file_exists(resume_path) and OS.is_process_running(resume_pid) and Time.get_ticks_msec()<deadline: await _seconds(.1)
	var result: Variant=JSON.parse_string(FileAccess.get_file_as_string(resume_path)) if FileAccess.file_exists(resume_path) else {}
	_assert(result is Dictionary and result.get("ok",false), "Fresh application validates crash-recovered scene for " + kind,result)
	var child_alive := OS.is_process_running(resume_pid)
	deadline=Time.get_ticks_msec()+3000
	while child_alive and Time.get_ticks_msec()<deadline:
		await _seconds(.05)
		child_alive=OS.is_process_running(resume_pid)
	if child_alive: OS.kill(resume_pid)
	current.measurements["crash_"+kind] = {"setup":ready,"resume":result}


func _child_arguments(stage: String,kind: String,directory: String) -> PackedStringArray:
	var args := PackedStringArray(["--headless","--log-file",directory.path_join(stage+".log")])
	if OS.has_feature("editor"):
		args.append_array(PackedStringArray(["--path",ProjectSettings.globalize_path("res://")]))
	args.append_array(PackedStringArray(["--","--crash-probe","--probe-stage",stage,"--probe-slot","verification_crash_"+kind,"--report-dir",directory]))
	return args


func _vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]


func _hit_info(hit: Dictionary) -> Dictionary:
	return {} if hit.is_empty() else {"position":_vec(hit.position),"collider":str(hit.collider.name)}


func _report_directory() -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()-1):
		if arguments[index]=="--report-dir": return arguments[index+1]
	return "res://review" if OS.has_feature("editor") else "user://verification"


func _build_fingerprint() -> Dictionary:
	if OS.has_feature("editor"):
		var files: Dictionary={}
		for filename in ["project.godot","main.tscn","scripts/playable.gd","scripts/baked_world.gd","scripts/forest_enclosure.gd","scripts/world_snapshot_state.gd","scripts/main.gd","scripts/world.gd","scripts/player.gd","scripts/save_store.gd","scripts/props.gd","assets/world/fireflies.gdshader","baked/clearing.res","tests/acceptance.gd","tests/crash_probe.gd","scripts/paving_preview_prebuilt.gd","scripts/paw_grounding.gd","baked/paving-preview192.res","baked/paving-preview192.json","scripts/air_capsule_guard.gd","lineage/entrance48-player-step-proposal02/player.gd"]:
			files[filename]=FileAccess.get_sha256("res://"+filename)
		return {"kind":"editor_source","source_sha256":files}
	var packs: Dictionary={}
	var resource_dir := OS.get_executable_path().get_base_dir().path_join("../Resources")
	var directory := DirAccess.open(resource_dir)
	if directory:
		for filename in directory.get_files():
			if filename.ends_with(".pck"): packs[filename]=FileAccess.get_sha256(resource_dir.path_join(filename))
	return {"kind":"native_export","executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"resource_pack_sha256":packs}

func _camera_rendered_clearance() -> Dictionary:
	var player: Variant=game.player
	var camera: Camera3D=player.get_camera()
	var ray := PhysicsRayQueryParameters3D.create(player._camera_pivot.global_position,camera.global_position,player.CAMERA_MASK,[player.get_rid()])
	ray.hit_from_inside=true
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	return {"render_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"player":_vec(player.global_position),"pivot":_vec(player._camera_pivot.global_position),"camera":_vec(camera.global_position),"camera_yaw":player.camera_yaw,"pivot_yaw":player._camera_pivot.rotation.y,"requested_arm":player._spring_arm.spring_length,"hit_length":player._spring_arm.get_hit_length(),"lens_clear":_camera_clear(),"pivot_to_lens_obstructed":not hit.is_empty(),"ray_hit":{} if hit.is_empty() else {"node":str(hit.collider.get_path()),"point":_vec(hit.position),"normal":_vec(hit.normal)}}

func _camera_fast_turn_regression() -> void:
	var window: Window=get_window()
	var saved_fps: int=Engine.max_fps
	var saved_vsync: int=DisplayServer.window_get_vsync_mode()
	var saved_size: Vector2i=window.size
	var saved_content_size: Vector2i=window.content_scale_size
	var saved_content_factor: float=window.content_scale_factor
	var saved_pitch: float=game.player._camera_pitch
	window.content_scale_size=Vector2i(640,360)
	window.content_scale_factor=1.0
	window.size=Vector2i(640,360)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.player._camera_pitch=deg_to_rad(-10)
	await _frames(4)
	var resolution: Vector2i=Vector2i(game.get_viewport().get_texture().get_size())
	_assert(resolution==Vector2i(640,360),"Fast-turn regression uses its actual 640x360 render target",str(resolution))
	var cases: Array=[]
	var first_bad_samples: Array=[]
	for cap: int in [30,60,120]:
		Engine.max_fps=cap
		for location: Array in [["annex_path",Vector3(-6.4,0,0.6)],["main_interior",Vector3(0,0.6,-1.5)],["entrance",Vector3(0,0.6,3.5)]]:
			await _place(location[1])
			await _seconds(0.7)
			var pose_valid: bool=game.player.global_position.distance_to(location[1])<0.10 and game.player.state=="Grounded" and game.player.is_on_floor() and game.player.enabled and not get_tree().paused
			_assert(pose_valid,"Fast-turn camera case starts at its supported native pose: %s cap %d"%[location[0],cap],{"requested":_vec(location[1]),"actual":_vec(game.player.global_position),"state":game.player.state,"floor":game.player.is_on_floor()})
			var start: int=Time.get_ticks_usec()
			var samples: int=0
			var lens_frames: int=0
			var blocked_frames: int=0
			var pose_all_samples_valid: bool=pose_valid
			var first_sample: Dictionary={}
			var last_sample: Dictionary={}
			while float(Time.get_ticks_usec()-start)/1000000.0<2.5:
				var elapsed_s: float=float(Time.get_ticks_usec()-start)/1000000.0
				game.player.camera_yaw=elapsed_s*TAU*2.0
				await RenderingServer.frame_post_draw
				last_sample=_camera_rendered_clearance()
				if samples==0: first_sample=last_sample
				samples+=1
				pose_all_samples_valid=pose_all_samples_valid and game.player.global_position.distance_to(location[1])<0.10 and game.player.state=="Grounded" and game.player.is_on_floor() and game.player.enabled and not get_tree().paused
				if not last_sample.lens_clear: lens_frames+=1
				if last_sample.pivot_to_lens_obstructed: blocked_frames+=1
				if (not last_sample.lens_clear or last_sample.pivot_to_lens_obstructed) and first_bad_samples.size()<16:
					first_bad_samples.append({"location":location[0],"render_cap":cap,"elapsed_s":elapsed_s,"sample":last_sample})
			var seconds: float=float(Time.get_ticks_usec()-start)/1000000.0
			var actual_fps: float=float(samples)/seconds
			var evidence: Dictionary={"location":location[0],"render_cap":cap,"requested_position":_vec(location[1]),"actual_position":_vec(game.player.global_position),"pose_valid_before":pose_valid,"pose_all_samples_valid":pose_all_samples_valid,"samples":samples,"seconds":seconds,"actual_render_fps":actual_fps,"lens_overlap_frames":lens_frames,"pivot_to_lens_obstructed_frames":blocked_frames,"first_sample":first_sample,"last_sample":last_sample}
			cases.append(evidence)
			_assert(samples>0 and seconds>=2.5 and is_finite(actual_fps) and actual_fps>0.0 and pose_all_samples_valid and lens_frames==0,"Rendered camera center remains clear during 720 degree/s turns: %s cap %d"%[location[0],cap],evidence)
			_assert(samples>0 and pose_all_samples_valid and blocked_frames==0,"Rendered pivot-to-lens ray remains unobstructed during fast turns: %s cap %d"%[location[0],cap],evidence)
	Engine.max_fps=saved_fps
	DisplayServer.window_set_vsync_mode(saved_vsync)
	window.content_scale_size=saved_content_size
	window.content_scale_factor=saved_content_factor
	window.size=saved_size
	game.player._camera_pitch=saved_pitch
	await _frames(4)
	var restored: bool=Engine.max_fps==saved_fps and DisplayServer.window_get_vsync_mode()==saved_vsync and window.size==saved_size and window.content_scale_size==saved_content_size and window.content_scale_factor==saved_content_factor and game.player._camera_pitch==saved_pitch
	_assert(restored,"Fast-turn regression restores FPS/vsync/window/content/pitch before existing camera/layout tests",{"fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"window":str(window.size),"content":str(window.content_scale_size),"content_factor":window.content_scale_factor})
	current.measurements.fast_turn_camera={"cases":cases,"first_obstruction_samples":first_bad_samples,"yaw_speed_degrees_s":720,"sample_window_s":2.5,"physics_hz":Engine.physics_ticks_per_second,"render_resolution":str(resolution),"settings_restored":restored,"scope":"Rendered-frame camera-center sphere and pivot-to-lens ray at nine valid pose/cap cases; actual frame rates recorded. This does not prove full-frustum coverage, exported performance, camera comfort or continuous motion quality."}


# Diagnostic fixture readiness only. Observe ordinary native physics; never
# assign a pose, velocity, marker, state, stability clock or controller limit.
func _safe_pose_state210() -> Dictionary:
	var p: Variant = game.player
	return {"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"ticks_usec":Time.get_ticks_usec(),"feet":_vec(p.global_position),"marker":_vec(p.safe_position),"feet_native_hex":var_to_bytes(p.global_position).hex_encode(),"marker_native_hex":var_to_bytes(p.safe_position).hex_encode(),"vertical_velocity":p.velocity.y,"native_floor":p.is_on_floor(),"state":p.state,"pending_teleport":p._pending_teleport,"paused":get_tree().paused,"stable_time":p._stable_time,"reserved":p._reserved_marker_area(p.global_position),"feet_valid":p._valid_safe_position(p.global_position),"marker_valid":p._valid_safe_position(p.safe_position),"marker_feet_distance":p.safe_position.distance_to(p.global_position)}

func _settled_safe_pose210() -> Dictionary:
	_release_all()
	var before: Dictionary = _safe_pose_state210()
	var actual: Dictionary = before
	var observations := 0
	for attempt in range(61):
		var ready: bool = not actual.pending_teleport and not actual.paused and actual.state=="Grounded" and actual.native_floor and absf(actual.vertical_velocity)<.25 and actual.stable_time>=.30 and not actual.reserved and actual.feet_valid and actual.marker_valid and actual.marker_feet_distance<.002
		if ready or attempt==60:
			return {"passed":ready,"before":before,"after":actual,"observations":observations,"physics_callbacks_elapsed":int(actual.physics_frame)-int(before.physics_frame),"elapsed_usec":int(actual.ticks_usec)-int(before.ticks_usec),"scope":"Ordinary physics wait only; no forced negativeheight or pose/marker assignment. Original negativeheight assertions remain mandatory."}
		await _frames(1)
		observations+=1
		actual=_safe_pose_state210()
	return {"passed":false}


# Read-only T01/T02/T03 input and state provenance. No input, controller, mode or clock writes.
var _debug_last237 := ""

func _debug_record237(kind: String, extra: Dictionary = {}) -> void:
	if not is_instance_valid(game) or game._quitting or not is_instance_valid(game.player): return
	if current.get("id","") not in ["T01","T02","T03"]: return
	if not current.measurements.has("input_diagnostic241"):
		current.measurements["input_diagnostic241"]=[]
	var rows: Array=current.measurements.input_diagnostic241
	if rows.size()>=8192: return
	var row: Dictionary={"kind":kind,"frame_cap":Engine.max_fps,"on_floor":game.player.is_on_floor(),"camera_yaw":game.player.camera_yaw,"float_pressed":Input.is_action_pressed("float"),"float_toggle":game.player.float_toggle,"float_latched":game.player._float_latched,"float_buffered":game.player._float_buffered,"float_just_pressed":Input.is_action_just_pressed("float"),"state_time":game.player._state_time,"touch_hover_latched":game.player.touch_hover_latched,"physics_delta":get_physics_process_delta_time(),"mouse_mode":Input.mouse_mode,"actual_input":[game.player._movement_input().x,game.player._movement_input().y],"wall_usec":Time.get_ticks_usec(),"physics_frame":Engine.get_physics_frames(),"render_frame":Engine.get_process_frames(),"mode":game.mode,"tree_paused":get_tree().paused,"enabled":game.player.enabled,"require_release":game.player._require_release,"verification":game.verification,"position":_vec(game.player.global_position),"velocity":_vec(game.player.velocity),"state":game.player.state,"step_phase":game.player._step48_phase,"move_forward_pressed":Input.is_action_pressed("move_forward")}
	row.merge(extra,true)
	rows.append(row)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_debug_record237("mouse_motion",{"relative":[event.relative.x,event.relative.y],"device":event.device})
	elif event.is_action("pause") or event.is_action("float") or event.is_action("move_forward") or event.is_action("move_back") or event.is_action("move_left") or event.is_action("move_right"):
		_debug_record237("control_input",{"event_class":event.get_class(),"event_text":event.as_text(),"pressed":event.is_pressed(),"echo":event.is_echo(),"device":event.device})

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or game._quitting or not is_instance_valid(game.player): return
	if current.get("id","") not in ["T01","T02","T03"]: return
	var key: String=str([game.mode,get_tree().paused,game.player.enabled,game.player._require_release,game.player.state])
	if key!=_debug_last237:
		_debug_last237=key
		_debug_record237("state_transition")

func _debug_release237(reason: String) -> void:
	if reason=="menu":
		_debug_record237("menu_release",{"call_stack":get_stack()})

func _physics_process(_delta: float) -> void:
	if current.get("id","") in ["T02","T03"]: _debug_record237("post_player_physics")
