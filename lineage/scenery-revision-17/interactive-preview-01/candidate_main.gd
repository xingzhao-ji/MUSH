extends "res://scripts/main.gd"
const CandidateWorld = preload("res://lineage/scenery-revision-17/proposals/water-rock-02/water-world.gd")
# Loader chooses only one of two fixed private slots before adding this node.
var _preview_slot: String = "user://revision17-preview-01"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_setup_input()
	world=CandidateWorld.new()
	world.name="WorldGeometry"
	add_child(world)
	player=PlayerScript.new()
	player.name="Player"
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.position=Vector3(-2,0,18)
	player.feedback.connect(_toast)
	store=SaveScript.new()
	store.directory=_preview_slot
	_build_gameplay()
	_build_ui()
	_build_audio()
	_apply_settings()
	review_camera=Camera3D.new()
	review_camera.name="FixedReviewCamera"
	review_camera.position=Vector3(6,3.3,20)
	review_camera.fov=60
	add_child(review_camera)
	review_camera.look_at(review_target)
	verification="--verify" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args() or "--traversal" in OS.get_cmdline_user_args() or "--crash-probe" in OS.get_cmdline_user_args()
	if verification:
		store.directory=_preview_slot
		_start_new()
	else:
		_title()
	get_tree().auto_accept_quit=false
	Input.joy_connection_changed.connect(_controller_change)
	if "--crash-probe" in OS.get_cmdline_user_args():
		_start_crash_probe.call_deferred()
	if "--verify" in OS.get_cmdline_user_args():
		_start_acceptance.call_deferred()
	if "--benchmark" in OS.get_cmdline_user_args() or "--traversal" in OS.get_cmdline_user_args():
		_start_benchmark.call_deferred()
