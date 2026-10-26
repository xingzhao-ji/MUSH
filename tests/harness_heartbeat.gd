extends Node
## Diagnostic heartbeat for long capture harnesses. Every 2 s of wall time it prints frame
## counters, whether the window can draw and has focus, and the harness's current phase and step
## labels. It runs in _process (PROCESS_MODE_ALWAYS), so it keeps reporting while a harness
## coroutine waits on a draw that does not come; it changes nothing it observes.
var phase: String = "start"
var step: String = ""
var _last: int = 0
var _post_draws: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.frame_post_draw.connect(_count_post_draw)

func _count_post_draw() -> void:
	_post_draws += 1

## Waits for the next drawn frame, up to limit_ms of wall time, polling process frames (which
## keep running when the window cannot draw). False means no frame was drawn in time: the
## harness then fails explicitly instead of waiting on a frame that never comes.
func await_draw(limit_ms: int = 20000) -> bool:
	var target: int = _post_draws + 1
	var start: int = Time.get_ticks_msec()
	while _post_draws < target:
		if Time.get_ticks_msec() - start > limit_ms: return false
		await get_tree().process_frame
	return true

## Window state for a failure report.
func state() -> Dictionary:
	return {"phase": phase, "step": step, "process": Engine.get_process_frames(), "drawn": Engine.get_frames_drawn(), "post_draw": _post_draws, "can_draw": DisplayServer.window_can_draw(), "focused": DisplayServer.window_is_focused()}

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last < 2000: return
	_last = now
	print("HARNESS_HEARTBEAT ", JSON.stringify({"ms": now, "phase": phase, "step": step, "process": Engine.get_process_frames(), "physics": Engine.get_physics_frames(), "drawn": Engine.get_frames_drawn(), "post_draw": _post_draws, "can_draw": DisplayServer.window_can_draw(), "focused": DisplayServer.window_is_focused()}))
