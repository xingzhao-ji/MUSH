extends "res://tests/paving_traversal.gd"
## Regression for the inner-return snag: actual input and registered capsule.
## Reuse strict traversal observations/arrival limits; no upper-roof credit waiver.
const GAP_START := Vector3(-.17649707198143, .123129695653915, 7.90403032302856)
# Start on the lower row along the original approach line and physically
# cross the historical snag, independent of teleport clearance at that pose.
const APPROACH_Z := 8.20
const APPROACH_X := GAP_START.x + (APPROACH_Z - GAP_START.z) * (-.08 - GAP_START.x) / (7.14 - GAP_START.z)
const APPROACH_START := Vector3(APPROACH_X, .16, APPROACH_Z)
const GAP_ROUTES := [
	["slow_up", -.08, 7.14, .25],
	["slow_down", -.17649707198143, 8.20, .25],
	["full_up", -.08, 7.14, 1.0],
	["full_down", -.17649707198143, 8.20, 1.0]
]
var step_before: Dictionary = {}
var step_after: Dictionary = {}
var support_fixtures: Dictionary = {}
var setup_readback: Dictionary = {}
var historical_crossing_distance := INF

func _run() -> void:
	if not await _setup(): return
	var pose := player.global_position
	var yaw: float = player.camera_yaw
	setup_readback = {"requested_pose":str(APPROACH_START), "historical_pose":str(GAP_START), "historical_pose_valid_for_teleport":player._valid_safe_position(GAP_START)}
	player.teleport_safe(APPROACH_START, yaw)
	setup_readback["immediate_pose"] = str(player.global_position)
	previous_position = player.global_position
	await _frames(30)
	setup_readback["settled_pose"] = str(player.global_position)
	setup_readback["grounded"] = player.is_on_floor()
	setup_readback["state"] = player.state
	if not _check("Regression approach uses ordinary validated teleport only", _restored(APPROACH_START)):
		_finish(); return
	step_before = player.entrance48_step_readback()
	started = Time.get_ticks_usec(); movement_start_tick = ticks
	total_upper = _coverage()
	var all_legs := true
	for point: Array in GAP_ROUTES:
		if not await _drive(Vector3(point[1], 0.0, point[2]), str(point[0]), float(point[3])):
			all_legs = false; break
		_merge_coverage(total_upper, routes.back().coverage)
	step_after = player.entrance48_step_readback()
	movement_passed = all_legs and routes.size() == GAP_ROUTES.size() and callbacks_exact and not fatal
	_check("Slow/full ascent and descent through the narrow joint", movement_passed)
	_check("Slow approach physically crosses the historical snag location", historical_crossing_distance < .03)
	_check("Steps complete without aborts or increased rise budget", int(step_after.completed) > int(step_before.completed) and int(step_after.aborted) == int(step_before.aborted) and float(step_after.max_applied_rise_m) <= .206 and not step_after.active)
	active_leg = {}; active_label = "final_endpoint_restore"; requested = 0.0; _release()
	player.teleport_safe(pose, yaw); previous_position = player.global_position
	await _frames(30)
	restored = _restored(pose)
	_check("Ordinary endpoint restore, unchanged capsule and native geometry", restored and _held())
	var fixtures := preload("res://tests/native_paired_support.gd").new()
	support_fixtures = await fixtures.run(player, game)
	_check("Native paired-support positive and refusal fixtures", bool(support_fixtures.get("passed", false)))
	_check("Native paving owner and capsule held after fixture cleanup", _held() and _restored(pose))
	_finish()

func _observe() -> void:
	super._observe()
	if active_label == "slow_up":
		historical_crossing_distance = minf(historical_crossing_distance, Vector2(player.global_position.x - GAP_START.x, player.global_position.z - GAP_START.z).length())

func _finish() -> void:
	_release()
	if observer != null: observer.set_physics_process(false)
	if csv != null: csv.flush(); csv.close(); csv = null
	var after := _owner_identity() if not owner_before.is_empty() else {}
	var failed := 0
	for check: Dictionary in checks:
		if not check.passed: failed += 1
	var report := {"schema":"mush-paving-gap-step/1", "passed":failed == 0 and movement_passed and restored, "checks":checks, "assertions":checks.size(), "failed":failed, "routes":routes, "movement_passed":movement_passed, "coverage":total_upper, "step_before":step_before, "step_after":step_after, "owner_before":owner_before, "owner_after":after, "owner_exact":not owner_before.is_empty() and var_to_bytes(owner_before) == var_to_bytes(after), "restored":restored, "callbacks":ticks, "callbacks_exact":callbacks_exact, "fatal":fatal, "profile":str(game.store.directory) if is_instance_valid(game) else "", "scope":"Separate four-leg narrow-joint regression using original traversal arrival/normal/clearance limits. Native slide contacts alone earn coverage. Does not replace or pass the original 58-route roof-contact gate; no art, performance, manual or mobile acceptance."}
	var trace_path := output.path_join("paving-traversal-ticks.csv")
	report["support_fixtures"] = support_fixtures
	report["setup_readback"] = setup_readback
	report["historical_crossing_distance_m"] = historical_crossing_distance if is_finite(historical_crossing_distance) else null
	if FileAccess.file_exists(trace_path): report["trace_sha256"] = FileAccess.get_sha256(trace_path)
	var file := FileAccess.open(output.path_join("paving-gap-step.json"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("PAVING_GAP_STEP ", JSON.stringify({"passed":report.passed, "assertions":checks.size(), "failed":failed, "routes":routes.size()}))
	if is_instance_valid(game): game._quit_clean(0 if report.passed else 2)
	else: quit(2)
