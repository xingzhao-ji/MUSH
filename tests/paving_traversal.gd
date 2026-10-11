extends SceneTree
## Real Main/current CharacterBody traversal. No geometry or controller changes.
## Historical 28+30 targets and arrival limits; native contacts, not rays, earn coverage.
class TraversalGame:
	extends "res://scripts/playable.gd"
	func _start_new() -> void:
		verification = true
		_preview_slot = "user://verification/paving_traversal_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		store.directory = _preview_slot
		super._start_new()
	func _title() -> void: _start_new()
	func _start_benchmark() -> void: pass
	func _start_acceptance() -> void: pass
	func _capture_review() -> void: pass

class PostPlayerObserver:
	extends Node
	signal after_player
	var serial: int = 0
	var native_delta: float = 0.0
	var callback_active: bool = false
	func _physics_process(delta: float) -> void:
		serial += 1
		native_delta = delta
		callback_active = true
		after_player.emit()
		callback_active = false

const CurrentPlayer = preload("res://scripts/air_capsule_guard.gd")
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ACTIONS := ["move_left", "move_right", "move_forward", "move_back", "float", "glow", "interact", "decorate", "pause", "touch_move_left", "touch_move_right", "touch_move_forward", "touch_move_back"]
const SETTINGS := ["motion_mode", "up_direction", "floor_max_angle", "floor_snap_length", "floor_stop_on_slope", "floor_constant_speed", "floor_block_on_wall", "wall_min_slide_angle", "max_slides", "safe_margin", "slide_on_ceiling", "platform_floor_layers", "platform_wall_layers", "platform_on_leave"]
const SOURCE_CONTACT_SHA := "dd340a548d27f0e57de9e40dd01642d8a4068e3a079495bba52fb9e1f72b10ef"
const CONTACT_SHA := "5c3e9e406fb00a944ec6f9bc6c9e0084de1447bf91128554c7ec33bc7479ac09"
const SOURCE_ARTIFACT := "res://baked/paving-preview192.res"
const SOURCE_ARTIFACT_SHA := "6d5d78516898be3099d0496f07f02057b28b8eb944091d4b27b1018592657aa9"
const SOURCE_ROOF_SHA := "d0613c5f227ca9ce4b9c2d7c709c6ef77294ec230374b23359f8c8d7ca5df76a"
const ROOF_SHA := "de438db5b6dcb196134193e1e39ef0ffc19b30bf5cb4d2975f0c8a715daca803"
const SOURCE_LOWER_FEET := ["336eb4bf0000fc40562b55bf3d0afb4084ed8bbeb81efd4077f7d8be33330b41ee2802bf52b80c41adeaa9bfc3f50c41494fcabf66660c41085fc9bf713d0a41", "ce8c32beb81efd40a25f3f3e295cfb40048e0b3ff628fc409620063fae470141119ed03e66660a416b55963e8fc20b41a9d837be9a990b414ccf9ebe7b140a41"]
const LOWER_FEET := ["336eb4bf0000fc40562b55bf3d0afb40b62279beb81efd404e9bc9be33330b4197f1fabe52b80c41adeaa9bfc3f50c41494fcabf66660c41085fc9bf713d0a41", "204551beb81efd404f9e373e295cfb40048e0b3ff628fc409620063fae470141119ed03e66660a416b55963e8fc20b41fb9056be9a990b41752baebe7b140a41"]
const SOURCE_UPPER_FEET := ["a0369ebfb81edd40370234bfec51dc4073fc11be6666de4051cf8abec3f5f44045b2cdbed7a3f840c0a888bf0000f840ee98acbf3333f7404ce9aebf52b8f240", "45a558bc48e1de406a00d53ec3f5dc40c8ee383fae47dd4076bf313f0000e440c27b0e3f7b14f640801ad33eec51f840286a29bc295cf740319404be3333f340"]
const UPPER_FEET := ["a0369ebfb81edd40370234bfec51dc40f0cfc7bd6666de402d8a67bec3f5f44045b2cdbed7a3f840c0a888bf0000f840ee98acbf3333f7404ce9aebf52b8f240", "3d7b6ebd48e1de406a00d53ec3f5dc40c8ee383fae47dd4076bf313f0000e440c27b0e3f7b14f640801ad33eec51f840286a29bc295cf740aca832be3333f340"]
# Native79 bent-cut XZ controls, qualified only with the exact retained roof packet.
const SOURCE_CUT := [Vector2(-.15556006133556366, 6.840000152587891), Vector2(-.0489768385887146, 6.980000019073486), Vector2(-.17335791885852814, 7.599999904632568), Vector2(-.04856511577963829, 7.820000171661377)]
const CUT := [Vector2(-0.15556006133556366, 6.840000152587891), Vector2(-0.07920201122760773, 6.980000019073486), Vector2(-0.19527797400951385, 7.599999904632568), Vector2(-0.04856511577963829, 7.820000171661377)]
const CUT_CONTROLS_XYZ := "f09b48bd3bdf8f3e295cdf40bd8431be3de8103e3333f340"
const ROUTES := [
	["slow_analog", .25, [["left_soil", -.95, 9.4], ["left_ascent", -.95, 7.60], ["left_descent", -.95, 9.4], ["right_soil", .18, 9.4], ["right_ascent", .18, 7.60], ["right_descent", .18, 9.4]]],
	["ordinary_walk", 1.0, [["diagonal_A_start", -1.45, 9.25], ["diagonal_A_ascent", .32, 7.65], ["diagonal_A_descent", -1.45, 9.25], ["diagonal_B_start", .72, 9.25], ["diagonal_B_ascent", -1.30, 7.65], ["diagonal_B_descent", .72, 9.25], ["outer_right_soil", .78, 8.36], ["side_seam_left", -1.80, 8.36], ["side_seam_right", .78, 8.36], ["front_stagger_right", .78, 8.68], ["front_stagger_left", -1.80, 8.82], ["front_stagger_return", .78, 8.68]]],
	["maximum_walk_runup", 1.0, [["left_runup", -.95, 9.85], ["left_ascent", -.95, 7.60], ["left_descent", -.95, 9.85], ["right_runup", .18, 9.85], ["right_ascent", .18, 7.60], ["right_descent", .18, 9.85]]],
	["doorway", 1.0, [["door_approach", 0, 3.7], ["open_threshold_inward", 0, 1.0], ["open_threshold_outward", 0, 3.7], ["outside_return", .18, 9.4]]],
	["upper_slow", .25, [["left_approach", -.83, 8.08], ["left_ascent", -.83, 7.17], ["left_descent", -.83, 8.08], ["right_approach", .33, 8.08], ["right_ascent", .33, 7.17], ["right_descent", .33, 8.08]]],
	["upper_full", 1.0, [["left_approach", -.83, 8.08], ["left_ascent", -.83, 7.17], ["left_descent", -.83, 8.08], ["right_approach", .33, 8.08], ["right_ascent", .33, 7.17], ["right_descent", .33, 8.08]]],
	["upper_diagonal", 1.0, [["A_approach", -1.05, 8.05], ["A_ascent", .43, 7.19], ["A_descent", -1.05, 8.05], ["B_approach", .43, 8.05], ["B_ascent", -.93, 7.19], ["B_descent", .43, 8.05]]],
	["upper_outer_edges", 1.0, [["left_front", -1.23, 7.60], ["left_backward", -1.23, 7.20], ["left_forward", -1.23, 7.60], ["right_front", .57, 7.60], ["right_backward", .57, 7.20], ["right_forward", .57, 7.60]]],
	["upper_bent_cut", 1.0, [["front", -.38, 7.67], ["back", -.08, 7.14], ["front_return", -.38, 7.67], ["left_cross", -.55, 7.38], ["right_cross", .28, 7.38], ["left_return", -.55, 7.38]]]
]
const MAX_TICKS := 9000
const MAX_CSV_TICKS := 9200
const MAX_CSV_BYTES := 32 * 1024 * 1024
var game: Node3D
var player: CurrentPlayer
var owner: RefCounted
var body: StaticBody3D
var shape: ConcavePolygonShape3D
var shape_index: int = -1
var observer: PostPlayerObserver
var output: String = ""
var csv: FileAccess
var checks: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var profiles: Array[Dictionary] = []
var lower_feet: Array[PackedVector2Array] = []
var upper_feet: Array[PackedVector2Array] = []
var upper_faces: Array[Dictionary] = []
var owner_before: Dictionary = {}
var settings_before: PackedByteArray
var active_leg: Dictionary = {}
var active_label: String = "setup"
var requested: float = 0.0
var previous_position := Vector3.ZERO
var previous_frame: int = -1
var previous_serial: int = 0
var ticks: int = 0
var movement_start_tick: int = 0
var started: int = 0
var fatal: bool = false
var callbacks_exact: bool = true
var attribution_qualified: bool = false
var candidate_path: String = ""
var candidate_library: MeshLibrary
var candidate_proof: Dictionary = {}
var candidate_receipt: Dictionary = {}
var candidate_active: bool = false
var baseline_meshes: Array[ArrayMesh] = []
var baseline_shape: ConcavePolygonShape3D
var baseline_identity: Dictionary = {}
var baseline_restored: bool = false
var expected_contact_sha: String = CONTACT_SHA
var expected_roof_sha: String = ROOF_SHA
var active_cut := PackedVector2Array(CUT)
var movement_passed: bool = false
var contact_coverage_passed: bool = false
var restored: bool = false
var total_upper: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func _setup() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output = arg.trim_prefix("--report-dir=")
		if arg.begins_with("--candidate="): candidate_path = arg.trim_prefix("--candidate=")
	var reports := ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output = output.simplify_path()
	if output.is_empty() or not output.is_absolute_path() or not output.begins_with(reports + "/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Traversal requires a new --report-dir= directory beneath res://reports/")
		quit(2); return false
	if DirAccess.make_dir_recursive_absolute(output) != OK: quit(2); return false
	var scene := load("res://main.tscn") as PackedScene
	if not _check("Real Main and native rendered display", scene != null and DisplayServer.get_name() != "headless"):
		_finish(); return false
	game = scene.instantiate() as Node3D
	game.set_script(TraversalGame)
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 90000
	while game.get("environment_controller") == null and Time.get_ticks_msec() < deadline: await process_frame
	player = game.get("player") as CurrentPlayer
	owner = game.world.get("paving_preview_prebuilt") as RefCounted
	if not _check("Real startup and installed preview owner", game.get("environment_controller") != null and player != null and owner != null and game.world.snapshot_loaded and bool(owner.call("verify", game.world, true))):
		_finish(); return false
	body = owner.get("_body") as StaticBody3D
	shape = owner.get("_shape_new") as ConcavePolygonShape3D
	shape_index = int(owner.get("_shape_index"))
	game.get_window().unfocusable = true
	game.get_window().mouse_passthrough = true
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.ui.hide(); game.save_timer = -1.0
	game.door_state = "open"; game.world.door_hinge.rotation.y = deg_to_rad(-95.0)
	_release()
	game._explore()
	for _i: int in range(30): await physics_frame; await process_frame
	var capsule_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var door: StaticBody3D = game.world.get("door_body") as StaticBody3D
	var ready: bool = player.get_script() == CurrentPlayer and player.is_physics_processing() and player.can_process() and player.enabled and not paused and player.is_on_floor() and player.state == "Grounded" and bool(player.call("_valid_safe_position", player.global_position))
	ready = ready and capsule_node != null and not capsule_node.disabled and capsule_node.shape is CapsuleShape3D and capsule_node.shape == player.get("_capsule") and PhysicsServer3D.body_get_shape_count(player.get_rid()) == 1 and PhysicsServer3D.body_get_shape(player.get_rid(), 0) == capsule_node.shape.get_rid()
	ready = ready and player.collision_layer == 2 and player.collision_mask == 21 and is_equal_approx(player.floor_max_angle, deg_to_rad(35.0)) and is_equal_approx(player.floor_snap_length, .18) and is_equal_approx(player.safe_margin, .005) and Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
	ready = ready and body != null and shape != null and shape_index >= 0 and door != null and door.collision_layer != 0 and PhysicsServer3D.body_get_shape_count(door.get_rid()) > 0 and str(game.store.directory).begins_with("user://verification/paving_traversal_")
	if not _check("Current unchanged capsule, 35-degree floor, physical open door, 60Hz and unique QA profile", ready):
		_finish(); return false
	settings_before = var_to_bytes(_settings())
	owner_before = _owner_identity()
	if not _check("Exact current registered contact and roof authority", _qualify_contacts()):
		_finish(); return false
	for raw: String in LOWER_FEET: lower_feet.append(_foot(raw))
	for raw: String in UPPER_FEET: upper_feet.append(_foot(raw))
	if not candidate_path.is_empty():
		if not _check("Candidate native artifact, explicit mapping/feet/roof/cut authority", _admit_candidate(reports)):
			_finish(); return false
		_set_candidate(true)
		for _i: int in range(30): await physics_frame; await process_frame
		owner_before = _owner_identity()
		if not _check("Candidate registered on the same body and classification qualified", _candidate_binding_exact() and _qualify_contacts()):
			_finish(); return false
	csv = FileAccess.open(output.path_join("paving-traversal-ticks.csv"), FileAccess.WRITE)
	if not _check("Fresh bounded CSV opened", csv != null): _finish(); return false
	csv.store_csv_line(PackedStringArray(["serial", "physics_frame", "delta", "label", "requested_input", "observed_input", "position_f32_hex", "velocity_f32_hex", "displacement_f32_hex", "floor", "ceiling", "state", "step_phase", "enabled", "require_release", "paused", "safe_position_f32_hex", "contacts_json"]))
	observer = PostPlayerObserver.new()
	observer.name = "PavingPostPlayerObserver"
	observer.process_physics_priority = player.process_physics_priority + 1
	observer.after_player.connect(_observe)
	previous_position = player.global_position
	previous_frame = Engine.get_physics_frames()
	root.add_child(observer)
	return true

func _run() -> void:
	if not await _setup(): return
	var pose := player.global_position
	var yaw: float = player.get("camera_yaw")
	started = Time.get_ticks_usec(); movement_start_tick = ticks
	total_upper = _coverage()
	var all_legs := true
	for group: Array in ROUTES:
		# Match the original lower28 restoration before upper30; never inter-leg teleport.
		if str(group[0]) == "upper_slow":
			active_label = "lower_endpoint_restore"; requested = 0.0; _release()
			player.teleport_safe(pose, yaw); previous_position = player.global_position
			await _frames(30)
			if not _check("Lower28 endpoint restored through ordinary validated teleport", _restored(pose)): all_legs = false; break
		var profile := _coverage()
		for point: Array in group[2]:
			if not await _drive(Vector3(float(point[1]), 0.0, float(point[2])), str(group[0]) + "/" + str(point[0]), float(group[1])):
				all_legs = false; break
			_merge_coverage(profile, routes.back().coverage)
			if str(group[0]).begins_with("upper_"):
				var leg: Dictionary = routes.back()
				var expected_foot := -1
				var need_any := false
				var need_cut_context := false
				var point_name := str(point[0])
				if str(group[0]) in ["upper_slow", "upper_full", "upper_outer_edges"]:
					if point_name.begins_with("left_") and not point_name in ["left_approach", "left_front"]: expected_foot = 0
					if point_name.begins_with("right_") and not point_name in ["right_approach", "right_front"]: expected_foot = 1
				elif str(group[0]) == "upper_diagonal":
					need_any = point_name.ends_with("ascent") or point_name.ends_with("descent")
					need_cut_context = need_any
				elif str(group[0]) == "upper_bent_cut":
					need_any = true; need_cut_context = true
				var leg_contact_ok: bool = expected_foot < 0 or leg.coverage.upper_stone[expected_foot] > 0
				if need_any: leg_contact_ok = leg_contact_ok and leg.coverage.upper_stone[0] + leg.coverage.upper_stone[1] + leg.coverage.upper_roof_support > 0
				if need_cut_context: leg_contact_ok = leg_contact_ok and leg.coverage.center_near_cut_ticks > 0
				leg["contact_requirement"] = {"corresponding_foot":expected_foot, "upper_support_required":need_any, "center_cut_context_required":need_cut_context, "passed":leg_contact_ok}
				_check("Actual upper leg support/cut context " + str(leg.label), leg_contact_ok)
		var upper: bool = str(group[0]).begins_with("upper_")
		var profile_ok: bool = true
		if upper:
			profile_ok = profile.upper_stone[0] > 0 and profile.upper_stone[1] > 0
			_merge_coverage(total_upper, profile)
		elif str(group[0]) != "doorway":
			profile_ok = profile.lower_stone[0] > 0 and profile.lower_stone[1] > 0 and profile.lower_edge[0] < .12 and profile.lower_edge[1] < .12 and profile.lower_soil > 0 and (str(group[0]) != "maximum_walk_runup" or profile.runup_speed > 1.9)
		profiles.append({"name":group[0], "passed":profile_ok, "coverage":profile})
		_check("Actual contact coverage in profile " + str(group[0]), profile_ok)
		if not all_legs or fatal: break
	movement_passed = all_legs and routes.size() == 58 and callbacks_exact and not fatal
	_check("All original 58 braking-aware route legs passed", movement_passed)
	contact_coverage_passed = attribution_qualified and profiles.size() == ROUTES.size() and total_upper.upper_stone[0] > 0 and total_upper.upper_stone[1] > 0 and total_upper.upper_edge[0] < .12 and total_upper.upper_edge[1] < .12 and total_upper.moving_roof > 0 and total_upper.moving_near_cut_roof > 0
	for profile: Dictionary in profiles: contact_coverage_passed = contact_coverage_passed and bool(profile.passed)
	for leg: Dictionary in routes:
		if leg.has("contact_requirement"): contact_coverage_passed = contact_coverage_passed and bool(leg.contact_requirement.passed)
	_check("Full-route actual feet/edges and moving roof/near-cut roof coverage", contact_coverage_passed)
	active_leg = {}; active_label = "final_endpoint_restore"; requested = 0.0; _release()
	player.teleport_safe(pose, yaw); previous_position = player.global_position
	await _frames(30)
	restored = _restored(pose)
	_check("Final ordinary endpoint restoration and installed owner exact", restored)
	_check("Adjacent post-player callbacks, unchanged capsule/settings and budget", callbacks_exact and not fatal and _held())
	_finish()

func _drive(target: Vector3, label: String, effective: float) -> bool:
	if not _check("Installed owner/settings held before " + label, _held()): return false
	active_label = label; requested = 0.0; _release(); await _frames(3)
	var start := player.global_position
	active_leg = {"samples":0, "travel_m":0.0, "gap":0, "longest_unsupported_ticks":0, "blocked":0, "longest_blocked_ticks":0, "recovery_ticks":0, "ceiling_ticks":0, "max_up":0.0, "max_down":0.0, "input_exact":true, "coverage":_coverage()}
	var first_tick := ticks
	var deadzone := 0.0
	for action: String in ["move_left", "move_right", "move_forward", "move_back"]: deadzone += InputMap.action_get_deadzone(action) / 4.0
	var strength := deadzone + (1.0 - deadzone) * effective
	var limit := mini(1200, int(ceil(Vector2(target.x - start.x, target.z - start.z).length() / (2.2 * effective) * 60.0)) + 180)
	var predicted_release := false
	var prediction_error := -1.0
	var brake_attempts: Array = []
	var settled_after_release := false
	for _i: int in range(limit):
		if fatal or ticks - movement_start_tick >= MAX_TICKS or Time.get_ticks_usec() - started > 150000000:
			fatal = true; break
		var stop := Vector3.ZERO
		var future := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var delta := player.get_physics_process_delta_time()
		for _j: int in range(20):
			future.x = move_toward(future.x, 0.0, 16.0 * delta)
			future.z = move_toward(future.z, 0.0, 16.0 * delta)
			stop += future * delta
		var predicted := player.global_position + stop
		prediction_error = Vector2(predicted.x - target.x, predicted.z - target.z).length()
		if player.is_on_floor() and player.state == "Grounded" and player.get("_step48_phase") == "idle" and prediction_error <= .03 and player._valid_safe_position(player.global_position) and player._valid_safe_position(predicted):
			# The braking estimate omits native slide correction. Confirm the
			# same 20-tick settle, then refine toward the unchanged target if
			# it stopped on a steep seam. All observations and limits remain.
			var attempt := {"position":_v(player.global_position), "prediction":_v(predicted), "current_safe":player._valid_safe_position(player.global_position), "predicted_safe":player._valid_safe_position(predicted)}
			requested = 0.0; _release(); await _frames(20)
			settled_after_release = true
			attempt["settled_position"] = _v(player.global_position)
			attempt["settled_safe"] = player._valid_safe_position(player.global_position)
			brake_attempts.append(attempt)
			if bool(attempt.settled_safe):
				predicted_release = true; break
			if brake_attempts.size() >= 3: break
			continue
		var offset := target - player.global_position
		player.camera_yaw = atan2(-offset.x, -offset.z)
		settled_after_release = false
		requested = effective; Input.action_press("move_forward", strength)
		await _frames(1)
		if player.state == "Recovering" or not player.enabled or player.get("_require_release") or paused: break
	requested = 0.0; _release()
	if not settled_after_release: await _frames(20)
	# Settling also spends real ticks/time; an arrival cannot bypass the cap.
	if ticks - movement_start_tick >= MAX_TICKS or Time.get_ticks_usec() - started > 150000000: fatal = true
	var support: Dictionary = player.call("_support_at", player.global_position, .22)
	var height_error := -1.0
	if not support.is_empty(): height_error = absf(player.global_position.y - (support.position as Vector3).y)
	var result := active_leg.duplicate(true)
	result.erase("gap"); result.erase("blocked")
	result["brake_attempts"] = brake_attempts
	result.merge({"label":label, "from":_v(start), "target":_v(target), "end":_v(player.global_position), "first_tick":first_tick, "last_tick":ticks, "effective_input":effective, "predicted_release":predicted_release, "predicted_release_error_m":prediction_error, "settled_xz_error_m":Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length(), "settled_floor":player.is_on_floor(), "settled_state":player.state, "settled_safe_valid":bool(player.call("_valid_safe_position", player.global_position)), "support_height_error_m":height_error, "displacement":_v(player.global_position - start)}, true)
	var movement_ok: bool = predicted_release and result.settled_xz_error_m <= .06 and result.travel_m > .02 and result.settled_floor and result.settled_state == "Grounded" and result.settled_safe_valid and height_error >= 0.0 and height_error <= .06 and result.recovery_ticks == 0 and result.ceiling_ticks == 0 and result.longest_unsupported_ticks <= 18 and result.longest_blocked_ticks <= 90 and result.max_up <= .22 and result.max_down <= .22 and result.input_exact and callbacks_exact and not fatal and _held()
	result["passed"] = movement_ok
	if not movement_ok:
		result["step_diagnostics"] = player.entrance48_step_readback()
	routes.append(result); active_leg = {}
	return _check("Actual settled movement/grounding/recovery " + label, movement_ok)

func _observe() -> void:
	if csv == null or ticks >= MAX_CSV_TICKS: fatal = true; return
	var frame := Engine.get_physics_frames()
	var callback_ok: bool = observer.callback_active and Engine.is_in_physics_frame() and observer.serial == previous_serial + 1 and frame == previous_frame + 1 and absf(observer.native_delta - 1.0 / 60.0) < .000001 and observer.process_physics_priority == player.process_physics_priority + 1 and observer.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT and player.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
	callbacks_exact = callbacks_exact and callback_ok
	var p := player.global_position
	var displacement := p - previous_position
	var planar := Vector2(displacement.x, displacement.z).length()
	var input: Vector2 = player.call("_movement_input")
	var moving: bool = not active_leg.is_empty() and requested > .2 and planar > .001 and player.is_on_floor()
	var contacts: Array[Dictionary] = []
	for i: int in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(i)
		for j: int in range(collision.get_collision_count()):
			if contacts.size() >= 128: fatal = true; break
			var point := collision.get_position(j)
			var normal := collision.get_normal(j)
			var selected: bool = collision.get_collider_rid(j) == body.get_rid() and collision.get_collider_shape_index(j) == shape_index
			var attribution: Dictionary = _attribute(point) if selected else {"regions":[], "faces":[]}
			var collider := collision.get_collider(j) as Node
			contacts.append({"path":str(collider.get_path()) if is_instance_valid(collider) else "", "rid":str(collision.get_collider_rid(j)), "shape":collision.get_collider_shape_index(j), "selected":selected, "point_f32_hex":_hex(point), "normal_f32_hex":_hex(normal), "regions":attribution.regions, "matched_registered_faces":attribution.faces})
			if not active_leg.is_empty() and selected and normal.y >= cos(player.floor_max_angle):
				_count_contact(active_leg.coverage, point, attribution, moving)
	if not active_leg.is_empty():
		active_leg.samples += 1; active_leg.travel_m += planar
		active_leg.gap = 0 if player.is_on_floor() else int(active_leg.gap) + 1
		active_leg.longest_unsupported_ticks = maxi(active_leg.longest_unsupported_ticks, active_leg.gap)
		active_leg.blocked = int(active_leg.blocked) + 1 if requested > .2 and planar < .001 else 0
		active_leg.longest_blocked_ticks = maxi(active_leg.longest_blocked_ticks, active_leg.blocked)
		if active_leg.blocked == 30 and not active_leg.has("blocked_motion_probes"):
			var attempt: Dictionary = player.get("_step48_last_attempt")
			var wire: Array = attempt.get("direction", [0.0, 0.0, 0.0])
			var direction := Vector3(float(wire[0]), float(wire[1]), float(wire[2]))
			var actual := Vector3(player.velocity.x, 0.0, player.velocity.z) * observer.native_delta
			var probes: Array = []
			for motion: Vector3 in [actual, direction * .05]:
				for recovery: bool in [false, true]:
					var query: Dictionary = player.call("_step48_motion", player.global_transform, motion, recovery)
					probes.append({"recovery_as_collision":recovery, "query":player.call("_step48_receipt", query)})
			active_leg["blocked_motion_probes"] = {"position":_v(p), "last_attempt":attempt.duplicate(true), "queries":probes}
		if player.state == "Recovering": active_leg.recovery_ticks += 1
		if player.is_on_ceiling(): active_leg.ceiling_ticks += 1
		active_leg.max_up = maxf(active_leg.max_up, displacement.y); active_leg.max_down = maxf(active_leg.max_down, -displacement.y)
		active_leg.input_exact = active_leg.input_exact and absf(input.length() - requested) < .00001
		if p.z > 8.9 and p.z < 9.4: active_leg.coverage.runup_speed = maxf(active_leg.coverage.runup_speed, Vector2(player.velocity.x, player.velocity.z).length())
		if _cut_distance(Vector2(p.x, p.z)) <= (player.get("_capsule") as CapsuleShape3D).radius: active_leg.coverage.center_near_cut_ticks += 1
		var safe: bool = p.is_finite() and player.velocity.is_finite() and player.enabled and not player.get("_require_release") and not paused and player.state != "Recovering" and not player.is_on_ceiling() and not bool(player.call("_outside_playable", p)) and not bool(player.call("_over_water", p)) and absf(displacement.y) <= .22
		if not safe: fatal = true
	csv.store_csv_line(PackedStringArray([str(observer.serial), str(frame), str(observer.native_delta), active_label, str(requested), str(input.length()), _hex(p), _hex(player.velocity), _hex(displacement), str(player.is_on_floor()), str(player.is_on_ceiling()), player.state, str(player.get("_step48_phase")), str(player.enabled), str(player.get("_require_release")), str(paused), _hex(player.safe_position), JSON.stringify(contacts)]))
	ticks += 1; previous_frame = frame; previous_serial = observer.serial; previous_position = p
	if csv.get_position() > MAX_CSV_BYTES or csv.get_error() != OK: fatal = true

func _qualify_contacts() -> bool:
	var faces := shape.get_faces()
	attribution_qualified = faces.size() == 7323 and _sha(faces.to_byte_array()) == expected_contact_sha and _sha(faces.slice(2387 * 3, 2439 * 3).to_byte_array()) == expected_roof_sha and body.global_transform == Transform3D.IDENTITY and PhysicsServer3D.body_get_shape(body.get_rid(), shape_index) == shape.get_rid()
	if not attribution_qualified: return false
	upper_faces.clear()
	for index: int in range(2049, 2441):
		var a := faces[index * 3]; var b := faces[index * 3 + 1]; var c := faces[index * 3 + 2]
		var normal := (c - a).cross(b - a).normalized()
		var region := "upper_left" if index < 2219 else ("upper_right" if index < 2387 else ("roof" if index < 2439 else "front_cap"))
		upper_faces.append({"face":index, "region":region, "a":a, "normal":normal, "polygon":PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]), "min_x":minf(a.x, minf(b.x, c.x)), "max_x":maxf(a.x, maxf(b.x, c.x)), "min_z":minf(a.z, minf(b.z, c.z)), "max_z":maxf(a.z, maxf(b.z, c.z))})
	return true

func _attribute(point: Vector3) -> Dictionary:
	var result := {"regions":[], "faces":[]}
	var margin := player.safe_margin + .0001
	var p := Vector2(point.x, point.z)
	for face: Dictionary in upper_faces:
		if point.x < face.min_x - margin or point.x > face.max_x + margin or point.z < face.min_z - margin or point.z > face.max_z + margin: continue
		if face.normal.y < cos(player.floor_max_angle) or absf((point - face.a).dot(face.normal)) > margin: continue
		if not Geometry2D.is_point_in_polygon(p, face.polygon) and _boundary(p, face.polygon) > .00001: continue
		result.faces.append(face.face)
		if not face.region in result.regions: result.regions.append(face.region)
	return result

func _count_contact(coverage: Dictionary, point: Vector3, attribution: Dictionary, moving: bool) -> void:
	var p := Vector2(point.x, point.z)
	var inside_lower := false
	for k: int in range(2):
		if Geometry2D.is_point_in_polygon(p, lower_feet[k]): coverage.lower_stone[k] += 1; inside_lower = true
		if point.z > 7.7 and point.z < 9.1: coverage.lower_edge[k] = minf(coverage.lower_edge[k], _boundary(p, lower_feet[k]))
	if not inside_lower and point.z > 7.7 and point.z < 9.1: coverage.lower_soil += 1
	if attribution.regions.size() > 1: coverage.ambiguous += 1; return
	if attribution.regions.is_empty(): return
	var region: String = attribution.regions[0]
	for k: int in range(2):
		if region == ("upper_left" if k == 0 else "upper_right"):
			coverage.upper_stone[k] += 1
			coverage.upper_edge[k] = minf(coverage.upper_edge[k], _boundary(p, upper_feet[k]))
	if region == "roof":
		coverage.upper_roof_support += 1
		if moving:
			coverage.moving_roof += 1
			if _cut_distance(p) < .12: coverage.moving_near_cut_roof += 1

func _coverage() -> Dictionary:
	return {"lower_stone":[0, 0], "lower_edge":[1000000.0, 1000000.0], "lower_soil":0, "upper_stone":[0, 0], "upper_edge":[1000000.0, 1000000.0], "upper_roof_support":0, "moving_roof":0, "moving_near_cut_roof":0, "ambiguous":0, "center_near_cut_ticks":0, "runup_speed":0.0}

func _merge_coverage(target: Dictionary, source: Dictionary) -> void:
	for key: String in ["lower_stone", "upper_stone"]:
		for k: int in range(2): target[key][k] += source[key][k]
	for key: String in ["lower_edge", "upper_edge"]:
		for k: int in range(2): target[key][k] = minf(target[key][k], source[key][k])
	for key: String in ["lower_soil", "upper_roof_support", "moving_roof", "moving_near_cut_roof", "ambiguous", "center_near_cut_ticks"]: target[key] += source[key]
	target.runup_speed = maxf(target.runup_speed, source.runup_speed)

func _owner_identity() -> Dictionary:
	var meshes: Array[Dictionary] = []
	for entry: Dictionary in owner.get("_entries"):
		var mesh: ArrayMesh = entry.node.mesh as ArrayMesh
		var native: Dictionary = owner.call("_native_prebuilt_record", mesh)
		meshes.append({"node":str(entry.node.get_path()), "node_id":str(entry.node.get_instance_id()), "mesh_id":str(mesh.get_instance_id()), "mesh_rid":str(mesh.get_rid()), "all13_sha256":str(native.get("all13_sha256", "")), "native_record_sha256":_sha(var_to_bytes(native)), "material_id":str(entry.node.material_override.get_instance_id())})
	return {"owner_id":str(owner.get_instance_id()), "meshes":meshes, "body_id":str(body.get_instance_id()), "body_rid":str(body.get_rid()), "shape_id":str(shape.get_instance_id()), "shape_rid":str(shape.get_rid()), "shape_index":shape_index, "registered_shape_rid":str(PhysicsServer3D.body_get_shape(body.get_rid(), shape_index)), "faces_sha256":_sha(shape.get_faces().to_byte_array()), "shape_configuration_sha256":_sha(var_to_bytes(owner.call("_shape_configuration", shape))), "body_state_sha256":_sha(var_to_bytes(owner.call("_body_native_state"))), "capsule_settings_sha256":_sha(var_to_bytes(_settings()))}

func _settings() -> Dictionary:
	var result: Dictionary = {}
	for key: String in SETTINGS: result[key] = player.get(key)
	var node := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := node.shape as CapsuleShape3D
	result["capsule"] = {"id":str(capsule.get_instance_id()), "rid":str(capsule.get_rid()), "registered_rid":str(PhysicsServer3D.body_get_shape(player.get_rid(), 0)), "radius":capsule.radius, "height":capsule.height, "transform":node.transform, "disabled":node.disabled, "layer":player.collision_layer, "mask":player.collision_mask, "player_rid":str(player.get_rid()), "priority":player.process_physics_priority}
	return result

func _held() -> bool:
	var binding_ok: bool = _candidate_binding_exact() if candidate_active else bool(owner.call("verify", game.world, true))
	return binding_ok and var_to_bytes(_settings()) == settings_before and var_to_bytes(_owner_identity()) == var_to_bytes(owner_before)

func _integer_array_equal(value: Variant, expected: Array) -> bool:
	# JSON numbers decode as floats. Compare exact numeric values without integer
	# truncation; native Array equality also compares element types.
	if not value is Array or value.size()!=expected.size(): return false
	for i: int in range(expected.size()):
		if typeof(value[i])!=TYPE_INT and typeof(value[i])!=TYPE_FLOAT: return false
		if float(value[i])!=float(expected[i]): return false
	return true

func _admit_candidate(reports: String) -> bool:
	candidate_path = candidate_path.simplify_path()
	if not candidate_path.is_absolute_path() or not candidate_path.begins_with(reports + "/") or not FileAccess.file_exists(candidate_path): return false
	var proof_path := candidate_path.get_base_dir().path_join("paving-shape.json")
	var file := FileAccess.open(proof_path, FileAccess.READ)
	if file == null: return false
	if file.get_length() <= 0 or file.get_length() > 8 * 1024 * 1024: file.close(); return false
	var parsed: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not parsed is Dictionary: return false
	candidate_proof = parsed
	if candidate_proof.get("schema", "") != "mush-paving-shape-candidate/2" or not candidate_proof.get("passed", false) or not candidate_proof.get("native_save_reload_exact", false) or not candidate_proof.get("source_resources_unchanged", false) or not candidate_proof.get("failures", ["missing"]).is_empty(): return false
	for check: Dictionary in candidate_proof.get("checks", []):
		if not check.get("passed", false): return false
	var artifact: Dictionary = candidate_proof.get("artifact", {})
	file = FileAccess.open(candidate_path, FileAccess.READ)
	if file == null: return false
	var size := file.get_length(); file.close()
	if size <= 0 or size > 4 * 1024 * 1024 or not artifact.get("passed", false) or size != int(artifact.get("bytes", -1)) or candidate_path != str(artifact.get("file", "")).simplify_path() or FileAccess.get_sha256(candidate_path) != artifact.get("sha256", ""): return false
	var manifest: Dictionary = candidate_proof.get("manifest", {})
	var mapping: Dictionary = manifest.get("contact_mapping", {})
	var roof: Dictionary = manifest.get("roof52", {})
	var feet: Array = manifest.get("feet", [])
	if manifest.get("original_contact_sha256", "") != SOURCE_CONTACT_SHA or int(manifest.get("contact_corners", 0)) != 7323 or not _integer_array_equal(manifest.get("corners", []), [4638, 3078, 9501]) or not mapping.get("passed", false) or not mapping.get("unchanged_complement_exact", false) or not roof.get("passed", false) or not mapping.get("nonroof_source_to_candidate_mapping_exact", false) or not roof.get("topology_replaced", false) or roof.get("actual_source_to_candidate_mapping_exact", true) or roof.get("same_face_slots_and_order", true) or not _integer_array_equal(roof.get("face_range", []), [2387, 2439]) or feet.size() != 4: return false
	var cut_source := str(manifest.get("cut_source_XZ_hex", "")).hex_decode()
	var cut_candidate := str(manifest.get("cut_candidate_XZ_hex", "")).hex_decode()
	var controls_source := str(manifest.get("cut_controls_source_XYZ_hex", "")).hex_decode()
	var controls_candidate := str(manifest.get("cut_controls_candidate_XYZ_hex", "")).hex_decode()
	if not manifest.get("cut_controls_mapping_verified", false) or cut_source != PackedVector2Array(SOURCE_CUT).to_byte_array() or cut_candidate.size() != 32 or controls_source != CUT_CONTROLS_XYZ.hex_decode() or controls_candidate.size() != 24: return false
	if cut_candidate.slice(0, 8) != cut_source.slice(0, 8) or cut_candidate.slice(24, 32) != cut_source.slice(24, 32): return false
	var candidate_cut := _foot(cut_candidate.hex_encode())
	for point: Vector2 in candidate_cut:
		if not point.is_finite(): return false
	for control: int in range(2):
		var old_point := Vector3(controls_source.decode_float(control * 12), controls_source.decode_float(control * 12 + 4), controls_source.decode_float(control * 12 + 8))
		var new_point := Vector3(controls_candidate.decode_float(control * 12), controls_candidate.decode_float(control * 12 + 4), controls_candidate.decode_float(control * 12 + 8))
		if not new_point.is_finite() or old_point.z != new_point.z or Vector2(old_point.x, old_point.z) != SOURCE_CUT[control + 1] or Vector2(new_point.x, new_point.z) != candidate_cut[control + 1]: return false
	candidate_library = ResourceLoader.load(candidate_path, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	if candidate_library == null or not bool(owner.call("_library_exact", candidate_library)): return false
	# The proof derives from immutable192. The active installed baseline may be
	# its adopted successor; preserve and restore those actual live pointers.
	if FileAccess.get_sha256(SOURCE_ARTIFACT) != SOURCE_ARTIFACT_SHA or candidate_proof.get("source_artifact_sha256", "") != SOURCE_ARTIFACT_SHA: return false
	var source_library := ResourceLoader.load(SOURCE_ARTIFACT, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MeshLibrary
	if source_library == null or not bool(owner.call("_library_exact", source_library)): return false
	var source_shape := source_library.get_item_shapes(0)[0] as ConcavePolygonShape3D
	if source_shape == null or _sha(source_shape.get_faces().to_byte_array()) != SOURCE_CONTACT_SHA: return false
	var expected_original: Array = manifest.get("original", [])
	var expected_candidate: Array = manifest.get("candidate", [])
	if expected_original.size() != 3 or expected_candidate.size() != 3: return false
	for item: int in range(3):
		var entry: Dictionary = owner.get("_entries")[item]
		var original_mesh := source_library.get_item_mesh(item) as ArrayMesh
		var mesh := candidate_library.get_item_mesh(item) as ArrayMesh
		if mesh == null or mesh == original_mesh or not NativeReader._wire_descriptor_matches(owner.call("_native_prebuilt_record", original_mesh), expected_original[item]) or not NativeReader._wire_descriptor_matches(owner.call("_native_prebuilt_record", mesh), expected_candidate[item]) or var_to_bytes(owner.call("_mesh_configuration", original_mesh)) != var_to_bytes(owner.call("_mesh_configuration", mesh)): return false
	var new_shape := candidate_library.get_item_shapes(0)[0] as ConcavePolygonShape3D
	if new_shape == null or new_shape == shape or var_to_bytes(owner.call("_shape_configuration", new_shape)) != var_to_bytes(owner.call("_shape_configuration", shape)): return false
	var before := source_shape.get_faces(); var after := new_shape.get_faces()
	if after.size() != before.size() or before.to_byte_array() != str(mapping.get("source_XYZ_hex", "")).hex_decode() or after.to_byte_array() != str(mapping.get("candidate_XYZ_hex", "")).hex_decode() or _sha(after.to_byte_array()) != manifest.get("contact_sha256", ""): return false
	# The roof is retriangulated. Its corners cannot honestly be checked in old
	# face slots; establish a single native map on the retained nonroof domain.
	var native_map: Dictionary = {}
	for index: int in range(before.size()):
		if index>=2387*3 and index<2439*3: continue
		var key:=_hex(before[index])
		if native_map.has(key) and _hex(native_map[key])!=_hex(after[index]): return false
		native_map[key]=after[index]
	var rebuilt: Dictionary=load("res://tools/paving_upper_roof.gd").new().build(before.slice(2387*3,2439*3),native_map)
	if not rebuilt.get("passed",false) or not rebuilt.evidence.interior_authoring_25_degrees_passed or not rebuilt.evidence.topology.no_new_steep_coverage_over_source_walkable_within_area_limit or rebuilt.triangles.to_byte_array()!=after.slice(2387*3,2439*3).to_byte_array() or rebuilt.controls.to_byte_array()!=controls_candidate: return false
	var visible_roof: PackedVector3Array=candidate_library.get_item_mesh(2).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if visible_roof.slice(3113*3,3165*3).to_byte_array()!=rebuilt.triangles.to_byte_array(): return false
	var control_indices: Array = [[], []]
	var endpoints_found: Array[bool] = [false, false]
	for index: int in range(after.size()):
		for control: int in range(2):
			if _hex(after[index])==controls_candidate.slice(control*12,control*12+12).hex_encode(): control_indices[control].append(index)
		for endpoint: int in range(2):
			var cut_index:=0 if endpoint==0 else 3
			if Vector2(after[index].x,after[index].z)==SOURCE_CUT[cut_index]: endpoints_found[endpoint]=true
	if control_indices[0].is_empty() or control_indices[1].is_empty() or not endpoints_found[0] or not endpoints_found[1]: return false
	var moved: Array[int] = []; var changed_faces: Array[int] = []; var roof_moved: Array[int] = []
	for index: int in range(before.size()):
		if _hex(before[index]) != _hex(after[index]):
			moved.append(index)
			var face := int(index / 3)
			if changed_faces.is_empty() or changed_faces.back() != face: changed_faces.append(face)
			if index >= 2387 * 3 and index < 2439 * 3: roof_moved.append(index)
	if moved.is_empty() or not _integer_array_equal(mapping.get("moved_corner_indices", []), moved) or not _integer_array_equal(mapping.get("changed_face_indices", []), changed_faces) or not _integer_array_equal(roof.get("moved_corner_indices", []), roof_moved): return false
	var source_roof := before.slice(2387 * 3, 2439 * 3).to_byte_array()
	var candidate_roof := after.slice(2387 * 3, 2439 * 3).to_byte_array()
	if _sha(source_roof) != SOURCE_ROOF_SHA or source_roof != str(roof.get("source_XYZ_hex", "")).hex_decode() or candidate_roof != str(roof.get("candidate_XYZ_hex", "")).hex_decode() or roof.get("source_sha256", "") != SOURCE_ROOF_SHA or _sha(candidate_roof) != roof.get("candidate_sha256", ""): return false
	var old_feet: Array = SOURCE_LOWER_FEET + SOURCE_UPPER_FEET
	var mapped_feet: Array[PackedVector2Array] = []
	for stone: int in range(4):
		var row: Dictionary = feet[stone]
		if int(row.get("stone", -1)) != stone or row.get("source_XZ_hex", "") != old_feet[stone] or not row.get("native_render_contact_verified", false): return false
		var old_polygon := _foot(str(row.source_XZ_hex)); var new_polygon := _foot(str(row.get("candidate_XZ_hex", "")))
		if old_polygon.size() != 8 or new_polygon.size() != 8: return false
		for corner: int in range(8):
			if not new_polygon[corner].is_finite(): return false
			var found := false
			for index: int in range(before.size()):
				if Vector2(before[index].x, before[index].z) == old_polygon[corner]:
					if not (index>=2387*3 and index<2439*3) and Vector2(after[index].x, after[index].z) != new_polygon[corner]: return false
					found = true
			if not found: return false
		mapped_feet.append(new_polygon)
	baseline_identity = owner_before.duplicate(true); baseline_shape = shape
	for entry: Dictionary in owner.get("_entries"): baseline_meshes.append(entry.node.mesh as ArrayMesh)
	lower_feet.assign(mapped_feet.slice(0, 2)); upper_feet.assign(mapped_feet.slice(2, 4))
	active_cut = candidate_cut
	expected_contact_sha = str(manifest.contact_sha256); expected_roof_sha = str(roof.candidate_sha256)
	candidate_receipt = {"resource":candidate_path, "resource_sha256":artifact.sha256, "proof":proof_path, "proof_sha256":FileAccess.get_sha256(proof_path), "native_payloads_exact":true, "nonroof_mapping_exact":true, "roof_topology_native_rebuilt_exact":true, "roof_render_contact_exact":true, "roof_same_face_order":false, "moved_contact_corners":moved.size(), "changed_contact_faces":changed_faces.size(), "mapped_roof_corners":roof_moved.size(), "source_roof_sha256":SOURCE_ROOF_SHA, "candidate_roof_sha256":expected_roof_sha, "foot_wires":feet, "cut_source_XZ_hex":cut_source.hex_encode(), "cut_candidate_XZ_hex":cut_candidate.hex_encode(), "cut_controls_source_XYZ_hex":controls_source.hex_encode(), "cut_controls_candidate_XYZ_hex":controls_candidate.hex_encode(), "cut_control_registered_corners":control_indices, "cut_controls_mapping_exact":true, "cut_endpoints_exact":true, "genuine_preview_owner_rewritten":false}
	return true

func _set_candidate(selected: bool) -> void:
	for item: int in range(3): owner.get("_entries")[item].node.mesh = candidate_library.get_item_mesh(item) if selected else baseline_meshes[item]
	shape = candidate_library.get_item_shapes(0)[0] as ConcavePolygonShape3D if selected else baseline_shape
	owner.get("_collision").shape = shape
	candidate_active = selected

func _candidate_binding_exact() -> bool:
	if not candidate_active or baseline_meshes.size() != 3 or baseline_shape != owner.get("_shape_new") or owner.get("_collision").shape != shape or not bool(owner.call("_body_binding_exact", shape)) or PhysicsServer3D.body_get_shape(body.get_rid(), shape_index) != shape.get_rid(): return false
	var mesh_property: Array[String] = ["mesh"]
	for item: int in range(3):
		var entry: Dictionary = owner.get("_entries")[item]
		if entry.candidate != baseline_meshes[item] or entry.node.mesh != candidate_library.get_item_mesh(item) or entry.node.material_override != entry.material or entry.material.shader != entry.shader or var_to_bytes(owner.call("_node_state", entry.node, mesh_property)) != var_to_bytes(entry.state): return false
	return _sha(baseline_shape.get_faces().to_byte_array()) == CONTACT_SHA

func _restored(pose: Vector3) -> bool:
	return player.is_on_floor() and player.state == "Grounded" and Vector2(player.global_position.x - pose.x, player.global_position.z - pose.z).length() < .03 and absf(player.global_position.y - pose.y) < .06 and _held()

func _frames(count: int) -> void:
	for _i: int in range(count): await observer.after_player

func _release() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func _foot(raw: String) -> PackedVector2Array:
	var bytes := raw.hex_decode()
	var result := PackedVector2Array()
	for i: int in range(0, bytes.size(), 8): result.append(Vector2(bytes.decode_float(i), bytes.decode_float(i + 4)))
	return result

func _boundary(p: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for i: int in range(polygon.size()): distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])))
	return distance

func _cut_distance(p: Vector2) -> float:
	var distance := INF
	for i: int in range(active_cut.size() - 1): distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, active_cut[i], active_cut[i + 1])))
	return distance

func _check(name: String, ok: bool) -> bool:
	checks.append({"name":name, "passed":ok})
	return ok

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

func _hex(value: Vector3) -> String: return PackedVector3Array([value]).to_byte_array().hex_encode()
func _v(value: Vector3) -> Array: return [value.x, value.y, value.z]

func _finish() -> void:
	_release()
	if observer != null: observer.set_physics_process(false)
	if csv != null: csv.flush(); csv.close(); csv = null
	var owner_after := _owner_identity() if not owner_before.is_empty() and is_instance_valid(player) else {}
	var baseline_after: Dictionary = {}
	if candidate_active:
		player.enabled = false
		_set_candidate(false)
		for _i: int in range(2): await physics_frame; await process_frame
		baseline_after = _owner_identity()
		baseline_restored = bool(owner.call("verify", game.world, true)) and var_to_bytes(baseline_after) == var_to_bytes(baseline_identity)
		_check("Genuine baseline mesh/shape pointers and native owner restored after candidate", baseline_restored)
		var inputs_exact: bool = FileAccess.get_sha256(candidate_path) == candidate_receipt.resource_sha256 and FileAccess.get_sha256(str(candidate_receipt.proof)) == candidate_receipt.proof_sha256
		_check("Candidate resource and authoring proof held byte-exact", inputs_exact)
	var failed := 0
	for check: Dictionary in checks:
		if not check.passed: failed += 1
	var report := {"schema":"mush-paving-traversal/1", "passed":failed == 0 and movement_passed and contact_coverage_passed and restored, "checks":checks, "assertions":checks.size(), "failed":failed, "routes":routes, "profiles":profiles, "movement_passed":movement_passed, "contact_coverage_passed":contact_coverage_passed, "full_route_contact_gate":movement_passed and contact_coverage_passed and restored and (candidate_path.is_empty() or baseline_restored), "coverage":total_upper, "owner_before":owner_before, "owner_after":owner_after, "owner_exact":not owner_before.is_empty() and var_to_bytes(owner_before) == var_to_bytes(owner_after), "candidate":candidate_receipt, "baseline_before_candidate":baseline_identity, "baseline_after_candidate":baseline_after, "baseline_restored":baseline_restored, "callback_count":ticks, "post_player_callbacks_exact":callbacks_exact, "restored":restored, "fatal_or_budget_failure":fatal, "source_sha256":FileAccess.get_sha256(get_script().resource_path), "profile":str(game.store.directory) if is_instance_valid(game) and game.get("store") != null else "", "contact_authority":{"full_contact_sha256":expected_contact_sha, "roof52_sha256":expected_roof_sha, "roof_registered_faces":[2387, 2439], "qualified":attribution_qualified, "classification_margin_m":player.safe_margin + .0001 if is_instance_valid(player) else 0.0, "engine_triangle_index_available":false, "ambiguous_regions_earn_no_credit":true, "near_cut_distance_m":.12}, "arrival":{"release_window_m":.03, "released_callbacks":20, "settled_xz_limit_m":.06, "deceleration_mps2":16.0, "collision_prediction":false}, "limits":{"movement_callbacks":MAX_TICKS, "movement_wall_seconds":150, "csv_callbacks":MAX_CSV_TICKS, "csv_bytes":MAX_CSV_BYTES}, "scope":"Actual Main/current capsule input movement and selected native slide contacts. Geometric face attribution is not a unique engine triangle ID. Moving roof requires pressed input, planar displacement>1mm, on-floor, floor-angle normal and a sole qualified roof region. Setup/released callbacks, center context and endpoint support rays never earn roof credit. Optional candidate swaps only three existing mesh pointers and one registered shape; the genuine owner is retained and restored. No controller edits, art, performance, audio, manual or device acceptance."}
	var trace_path := output.path_join("paving-traversal-ticks.csv")
	if FileAccess.file_exists(trace_path):
		var trace := FileAccess.open(trace_path, FileAccess.READ)
		report["tick_evidence"] = {"path":trace_path.get_file(), "bytes":trace.get_length(), "sha256":FileAccess.get_sha256(trace_path)}
		trace.close()
	var file := FileAccess.open(output.path_join("paving-traversal.json"), FileAccess.WRITE)
	if file == null: push_error("Traversal report could not be retained"); quit(2); return
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("PAVING_TRAVERSAL ", JSON.stringify({"passed":report.passed, "assertions":report.assertions, "failed":report.failed, "routes":routes.size(), "movement_passed":movement_passed, "coverage":total_upper}))
	var exit_code := 0 if report.passed else 2
	if is_instance_valid(game) and game.get("player") != null: game._quit_clean(exit_code)
	else: quit(exit_code)
