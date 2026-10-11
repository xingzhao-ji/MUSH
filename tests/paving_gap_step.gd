extends "res://tests/paving_traversal.gd"
## Regression for the inner-return snag: actual input and registered capsule.
## Reuse strict traversal observations/arrival limits; no upper-roof credit waiver.
const GAP_START := Vector3(-.17649707198143, .123129695653915, 7.90403032302856)
const GAP_ROUTES := [
	["slow_up", -.08, 7.14, .25],
	["slow_down", -.17649707198143, 8.20, .25],
	["full_up", -.08, 7.14, 1.0],
	["full_down", -.17649707198143, 8.20, 1.0]
]
var step_before: Dictionary = {}
var step_after: Dictionary = {}
var support_fixtures: Dictionary = {}

func _run() -> void:
	if not await _setup(): return
	var pose := player.global_position
	var yaw: float = player.camera_yaw
	player.teleport_safe(GAP_START, yaw)
	previous_position = player.global_position
	await _frames(30)
	if not _check("Regression setup uses ordinary validated teleport only", _restored(GAP_START)):
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
	if FileAccess.file_exists(trace_path): report["trace_sha256"] = FileAccess.get_sha256(trace_path)
	var file := FileAccess.open(output.path_join("paving-gap-step.json"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("PAVING_GAP_STEP ", JSON.stringify({"passed":report.passed, "assertions":checks.size(), "failed":failed, "routes":routes.size()}))
	if is_instance_valid(game): game._quit_clean(0 if report.passed else 2)
	else: quit(2)
