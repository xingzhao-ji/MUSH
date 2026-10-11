extends SceneTree
## Real trunk movement and ordinary-camera bark visibility regression.
const SurfaceFixture = preload("res://tests/paving_surface.gd")
const Contacts = preload("res://tests/forest_trunk_contacts.gd")

class CaptureObserver:
	extends Node
	var game: Node3D
	var frames: int = 0
	var invalid_frames: int = 0
	var animated_frames: int = 0
	func _process(_delta: float) -> void:
		frames+=1
		var player: Variant=game.player
		if game.get_tree().paused or game.get_viewport().get_camera_3d()!=player.get_camera() or not player.is_visible_in_tree() or not player.is_processing() or not player.is_physics_processing(): invalid_frames+=1
		if player._animator.is_playing(): animated_frames+=1

var game: Node3D
var output: String=""
var checks: Array[Dictionary]=[]
var contact_report: Dictionary={}
var capture_state: Dictionary={}
var camera_report: Dictionary={}
var outer_report: Dictionary={}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments: PackedStringArray=OS.get_cmdline_user_args()
	for arg: String in arguments:
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	var reports: String=ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output=output.simplify_path()
	if output.is_empty() or not output.is_absolute_path() or not output.begins_with(reports+"/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Outer-tree check requires a fresh --report-dir= beneath reports/"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: quit(2); return
	var isolated: bool="--benchmark" in arguments
	for flag: String in ["--smoke","--verify","--capture","--traversal"]: isolated=isolated and not flag in arguments
	if not _check("Benchmark isolation without automatic test/quit runners",isolated and DisplayServer.get_name()!="headless"):
		_finish(); return
	root.unfocusable=true; root.mouse_passthrough=true
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	var scene: PackedScene=load("res://main.tscn") as PackedScene
	if not _check("Actual main scene exists",scene!=null): _finish(); return
	game=scene.instantiate() as Node3D
	game.set_script(SurfaceFixture.PavingSurfaceGame)
	root.add_child(game)
	var deadline: int=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	var controller: Node=game.get("environment_controller") as Node
	if not _check("Rendered ordinary startup and unique verification profile",controller!=null and game.world.snapshot_loaded and str(game.store.directory).begins_with("user://verification/paving_surface_") and game.mode=="explore"):
		_finish(); return
	# Suppress Main's automatic interaction/save/UI logic, preserving child owners.
	game.set_process(false); game.set_physics_process(false)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled=true
	game.player.set_process(true); game.player.set_physics_process(true)
	game.ui.hide(); paused=false; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.player.get_camera().make_current()
	game.world.set_living_motion_enabled(true)
	controller.set_foreground(true); controller.set_inspection_state("gust")
	game.set_appearance("day","sunny")
	await create_timer(1.0).timeout
	var trial: Node3D=game.world.get_node_or_null("ForestMiddleLayer") as Node3D
	if not _check("Current corrected forest owns four bodies/twenty shapes",trial!=null and trial.is_visible_in_tree() and game.world.forest_enclosure.new_colliders==4 and game.world.forest_enclosure.new_collision_shapes==20):
		_finish(); return
	_check("Visible animated player, ordinary camera and live gust owners",game.player.is_visible_in_tree() and game.player._visual.process_mode!=Node.PROCESS_MODE_DISABLED and game.player._animator.is_playing() and root.get_camera_3d()==game.player.get_camera() and controller.is_processing() and controller.foreground and controller.inspection_state=="gust" and game.world.is_processing() and not paused)
	await RenderingServer.frame_post_draw
	_check("Rendered viewport is 1280x720",root.get_texture().get_size()==Vector2(1280,720))
	var source_contact: Script=load("res://scripts/outer_tree_contact.gd")
	var body: StaticBody3D=game.world.get_node_or_null("OuterTreeContact")
	if not _check("Ordinary startup installs the outer trunk contact",body!=null): _finish(); return
	var old_bindings: String=_unchanged_bindings(body)
	body.free()
	_check("Contact rollback removes only the owned body",not game.world.has_node("OuterTreeContact") and old_bindings==_unchanged_bindings(null))
	_check("Reinstall restores contact without replacing other owners",source_contact.install(game.world) and old_bindings==_unchanged_bindings(game.world.get_node_or_null("OuterTreeContact")))
	var camera_probe: Node=load("res://tests/bark_camera_probe.gd").new()
	game.add_child(camera_probe); camera_probe.configure(game)
	await physics_frame; await physics_frame
	camera_probe.enabled=true
	var observer:=CaptureObserver.new(); observer.game=game; observer.process_priority=200
	game.add_child(observer)
	var clock_before: float=controller.clock_seconds
	var physics_before: int=Engine.get_physics_frames()
	var process_before: int=Engine.get_process_frames()
	var helper: RefCounted=Contacts.new()
	contact_report=await helper.run(game,trial)
	observer.set_process(false)
	camera_report=camera_probe.finish(); camera_probe.queue_free()
	_check("Native camera diagnostic integrity",camera_report.get("diagnostic_integrity",false))
	var blocked: int=0
	var overlaps: int=0
	var hidden: int=0
	for row: Dictionary in camera_report.rows:
		if not row.rays.head.visual.is_empty() and not row.rays.body.visual.is_empty(): blocked+=1
		if not row.visual_sphere_overlaps.is_empty() or row.visual_sphere_saturated: overlaps+=1
		if row.camera_fade>.95 or row.rays.head.behind or row.rays.body.behind: hidden+=1
	camera_report["blocked_head_and_body_frames"]=blocked
	camera_report["overlapping_lens_frames"]=overlaps
	camera_report["faded_or_behind_frames"]=hidden
	_check("Character head/body sight lines remain clear of native bark through east routes",blocked==0)
	_check("Camera sphere stays clear of native bark through east routes",overlaps==0)
	_check("Character remains ahead of the camera without full fading",hidden==0)
	capture_state={"rendered_frames_observed":observer.frames,"invalid_camera_or_player_frames":observer.invalid_frames,"animated_frames":observer.animated_frames,"physics_ticks":Engine.get_physics_frames()-physics_before,"process_frames":Engine.get_process_frames()-process_before,"environment_clock_before":clock_before,"environment_clock_after":controller.clock_seconds,"inspection_state":controller.inspection_state,"ordinary_camera_path":str(game.player.get_camera().get_path()),"profile":str(game.store.directory),"root_automatic_processing_disabled":not game.is_processing() and not game.is_physics_processing()}
	_check("All four native blocking/sliding/retreat cases and restoration pass",contact_report.get("passed",false) and contact_report.get("cases",[]).size()==4 and contact_report.get("endpoint_restored",false) and contact_report.get("controller_settings_exact",false) and contact_report.get("original_collision_bindings_exact",false))
	_check("Ordinary camera and visible animation held through the recording",observer.frames>0 and observer.invalid_frames==0 and observer.animated_frames==observer.frames)
	_check("Living environment advanced in gust state without pause",controller.clock_seconds>clock_before and controller.inspection_state=="gust" and controller.foreground and game.world.is_processing() and not paused)
	observer.queue_free(); await process_frame
	outer_report=await load("res://tests/outer_trunk_contacts.gd").new().run(game)
	_check("New outer trunk direct movement and safe support pass",outer_report.get("passed",false))
	_finish()

func _check(label: String, passed: bool) -> bool:
	checks.append({"label":label,"passed":passed}); return passed

func _finish() -> void:
	var failed: int=0
	for row: Dictionary in checks:
		if not row.passed: failed+=1
	var passed: bool=failed==0 and bool(contact_report.get("passed",false))
	var file: FileAccess=FileAccess.open(output.path_join("contacts.json"),FileAccess.WRITE)
	if file==null:
		push_error("Could not write contacts.json"); passed=false
	else:
		file.store_string(JSON.stringify({"schema":"mush-outer-tree-contact/1","passed":passed,"failed":failed,"checks":checks,"contacts":contact_report,"capture":capture_state,"camera_diagnostic":camera_report,"outer_contacts":outer_report,"motion_acceptance":false,"art_approved":false,"audio_listened":false,"performance_measured":false,"scope":"Current Main/player; actual four trunk block/slide/retreat cases, ordinary camera and animated gust environment. Offline MovieWriter recording is not real-time pacing evidence."},"  "))
		file.flush(); file.close()
	print("OUTER_TREE_CONTACT ","PASS" if passed else "FAIL")
	if is_instance_valid(game) and is_instance_valid(game.get("player")) and is_instance_valid(game.get("world")): game._quit_clean(0 if passed else 2)
	else: quit(0 if passed else 2)

func _unchanged_bindings(excluded: Node) -> String:
	var rows: Array=[]
	for node: Node in game.world.find_children("*","Node3D",true,false):
		if node==excluded or (excluded!=null and excluded.is_ancestor_of(node)): continue
		if node is CollisionShape3D:
			rows.append([node.get_instance_id(),node.global_transform,node.shape.get_instance_id(),node.disabled,node.get_parent().collision_layer,node.get_parent().collision_mask])
		elif node is MeshInstance3D:
			rows.append([node.get_instance_id(),node.global_transform,node.mesh.get_instance_id() if node.mesh!=null else 0,node.material_override.get_instance_id() if node.material_override!=null else 0,node.visible])
		elif node is MultiMeshInstance3D:
			rows.append([node.get_instance_id(),node.global_transform,node.multimesh.get_instance_id(),node.material_override.get_instance_id() if node.material_override!=null else 0,node.visible])
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(rows)); return hash.finish().hex_encode()
