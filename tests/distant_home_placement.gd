extends "res://tests/house_foundation.gd"
## Actual startup placement, paired with retained baseline meshes; exact rollback.
const Placement=preload("res://scripts/distant_home_placement.gd")
var proof: Dictionary={}
var mesh_pairs: Array[Dictionary]=[]
var homes: Array[Node3D]=[]
var original_poses: Array[Transform3D]=[]
var installed_poses: Array[Transform3D]=[]
var held_nodes: String=""
var held_meshes: String=""
var held_aliases: String=""
var held_lights: String=""
var held_rng: int=0
var held_state: Dictionary={}
var admitted: bool=false

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	var reports: String=ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output=output.simplify_path()
	if output.is_empty() or not output.is_absolute_path() or not output.begins_with(reports+"/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: quit(2); return
	if not _check("Rendered private benchmark entry",DisplayServer.get_name()!="headless" and "--benchmark" in OS.get_cmdline_user_args()): await _finish(); return
	root.unfocusable=true; root.mouse_passthrough=true; root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	game=load("res://main.tscn").instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline: int=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	controller=game.get("environment_controller")
	if not _check("Ordinary startup installed both homes in a private slot",controller!=null and game.world.snapshot_loaded and game.world.distant_home_placement_report.get("passed",false) and game.world.distant_home_placement_report.get("installed",false) and game.mode=="explore" and str(game.store.directory).begins_with("user://verification/paving_surface_")): await _finish(); return
	owner=game.world.paving_preview_prebuilt
	held_state={"sky":game.sky,"weather":game.weather,"inspection":controller.inspection_state,"foreground":controller.foreground,"world_foreground":game.world._environment_foreground,"living":game.world._m37_enabled,"camera":root.get_camera_3d(),"review_pose":game.review_camera.global_transform,"review_fov":game.review_camera.fov,"ui":game.ui.visible,"player_visible":game.player.visible,"mouse":Input.mouse_mode}
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled=false; await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false); game.player._visual.process_mode=Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false); controller.set_foreground(false); game.world.set_environment_foreground(false)
	game.ui.hide(); game.player.visible=false; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; await _frames(3)
	proof=JSON.parse_string(FileAccess.get_file_as_string(Placement.PROOF))
	var state: Resource=ResourceLoader.load("res://baked/clearing-renderer-neutral.res","Resource",ResourceLoader.CACHE_MODE_IGNORE)
	var baseline: Node3D=state.scene.instantiate()
	var valid: bool=proof.get("meshes",[]).size()==16 and proof.get("homes",[]).size()==2
	for row: Dictionary in proof.get("meshes",[]):
		var live: MeshInstance3D=game.world.get_node_or_null(row.path)
		var old: MeshInstance3D=baseline.get_node_or_null(row.path)
		var one: bool=live!=null and old!=null and live.mesh is ArrayMesh and old.mesh is ArrayMesh and NativeReader._wire_descriptor_matches(NativeReader.mesh_record(live.mesh),row.candidate) and NativeReader._wire_descriptor_matches(NativeReader.mesh_record(old.mesh),row.original)
		valid=valid and one
		if one: mesh_pairs.append({"node":live,"old":old.mesh,"current":live.mesh}); source_meshes.append(live)
	for row: Dictionary in proof.get("homes",[]):
		var home: Node3D=game.world.get_node_or_null(row.path)
		var original_pose: Variant=bytes_to_var(str(row.original_transform_hex).hex_decode())
		var installed_pose: Variant=bytes_to_var(str(row.candidate_transform_hex).hex_decode())
		valid=valid and home!=null and original_pose is Transform3D and installed_pose is Transform3D and home.transform==installed_pose
		if home!=null and original_pose is Transform3D and installed_pose is Transform3D: homes.append(home); original_poses.append(original_pose); installed_poses.append(installed_pose)
	baseline.free(); state=null
	if not _check("Actual16 installed native batches and2poses equal saved artifact, retained original batches admitted separately",valid and mesh_pairs.size()==16 and homes.size()==2): await _finish(); return
	source_meshes.append(game.world.get_node("ClosestHomeFoundation/StoneLedge"))
	_materials_held(); held_nodes=_original_bindings(); held_meshes=_native_sources(); held_aliases=_bindings(); held_lights=_light_transforms(); held_rng=game.world._rng.state
	admitted=true
	for mood: String in ["day","night"]:
		controller.set_foreground(true); game.world.set_environment_foreground(true); controller.set_inspection_state("night" if mood=="night" else "calm"); game.set_appearance(mood,"sunny")
		await create_timer(4.0).timeout
		controller.set_foreground(false); game.world.set_environment_foreground(false); await _frames(3)
		_check(mood+": appearance endpoint settled",absf(game.world.night_amount-(1.0 if mood=="night" else 0.0))<.001 and game.world.rain_amount<.001)
		for pose: Dictionary in [
			{"name":"home2-close","position":Vector3(18.4,1.85,-17),"target":Vector3(21.25,5.7,-25)},
			{"name":"home2-wide","position":Vector3(17.5,1.9,-12.5),"target":Vector3(20.7,4.6,-24)},
			{"name":"home3-ground-obscured","position":Vector3(-10.9,1.65,-19.1),"target":Vector3(-15.5,6.1,-24.5)},
			{"name":"home3-elevated-diagnostic","position":Vector3(-12,7.6,-19.5),"target":Vector3(-15.5,5.8,-24.5)}]:
			game.review_camera.global_position=pose.position; game.review_camera.fov=65; game.review_camera.look_at(pose.target); game.review_camera.make_current()
			await _placement_pair(pose.name+"-"+mood)
	await _finish()

func _assign(installed: bool) -> void:
	for row: Dictionary in mesh_pairs: row.node.mesh=row.current if installed else row.old
	for i: int in range(homes.size()): homes[i].transform=installed_poses[i] if installed else original_poses[i]

func _placement_pair(label: String) -> void:
	var held_context: String=_context(); var material_state: String=_materials_held()
	_assign(false); await _frames(10); await RenderingServer.frame_post_draw
	var before: bool=_context()==held_context and _materials_held()==material_state
	before=_save_placement_view(label+"-original") and before
	_assign(true); await _frames(10); await RenderingServer.frame_post_draw
	var after: bool=_context()==held_context and _materials_held()==material_state and _original_bindings()==held_nodes and _native_sources()==held_meshes and _bindings()==held_aliases and _light_transforms()==held_lights and game.world._rng.state==held_rng
	after=_save_placement_view(label+"-installed") and after
	_check(label+": matched lighting, complete pictures and exact installed pointer/parent/light restoration",before and after)
	pairs.append({"label":label,"passed":before and after,"context_held":before and after})

func _save_placement_view(label: String) -> bool:
	var image: Image=root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
	var file: String=label+".png"
	var ok: bool=image.get_size()==Vector2i(1280,720) and image.save_png(output.path_join(file))==OK
	views.append({"label":label,"file":file,"passed":ok,"png_sha256":FileAccess.get_sha256(output.path_join(file)),"rgba_sha256":_sha(image.get_data()),"scope":"Fixed diagnostic camera, including retained foliage obstruction; not gameplay reachability or motion proof"})
	return ok

func _light_transforms() -> String:
	var rows: Array=[]
	for home: Node3D in homes:
		rows.append([home.get_instance_id(),home.transform])
		for light: Node3D in home.find_children("*","OmniLight3D",true,false): rows.append([light.get_instance_id(),light.get_parent().get_instance_id(),light.transform,light.global_transform,light.omni_range,light.omni_attenuation,light.shadow_enabled])
	var membership: Array=[]
	for light: OmniLight3D in game.world._practical_lights: membership.append(light.get_instance_id())
	rows.append(membership); return _sha(var_to_bytes(rows))

func _finish() -> void:
	var restored: bool=false
	if is_instance_valid(game) and admitted:
		_assign(true)
		controller.set_foreground(true); game.world.set_environment_foreground(true); controller.set_inspection_state(held_state.inspection); game.set_appearance(held_state.sky,held_state.weather)
		await create_timer(4.0).timeout
		controller.set_foreground(held_state.foreground); game.world.set_environment_foreground(held_state.world_foreground)
		game.review_camera.global_transform=held_state.review_pose; game.review_camera.fov=held_state.review_fov
		if is_instance_valid(held_state.camera): held_state.camera.make_current()
		restored=_original_bindings()==held_nodes and _native_sources()==held_meshes and _bindings()==held_aliases and _light_transforms()==held_lights and game.world._rng.state==held_rng
		_check("Actual installed scene, original resources, aliases, lights, closest foundation and RNG restored",restored)
		game.ui.visible=held_state.ui; game.player.visible=held_state.player_visible; Input.mouse_mode=held_state.mouse; game.world.set_living_motion_enabled(held_state.living)
	var failed: int=0
	for row: Dictionary in checks:
		if not row.passed: failed+=1
	var passed: bool=admitted and restored and failed==0 and pairs.size()==8 and views.size()==16
	var report: Dictionary={"schema":"mush-installed-distant-home-placement/1","passed":passed,"failed":failed,"checks":checks,"pairs":pairs,"views":views,"scene_restored":restored,"startup":game.world.distant_home_placement_report if is_instance_valid(game) else {},"verification_slot":str(game.store.directory) if is_instance_valid(game) else "","whole_foot_coverage_proved":false,"art_approved":false,"motion_verified":false,"performance_measured":false}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var file: FileAccess=FileAccess.open(output.path_join("home-placement.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"  ")); file.flush(); file.close()
	print("HOME_PLACEMENT_COMPLETE ",JSON.stringify({"passed":passed,"failed":failed}))
	if is_instance_valid(game): game._quit_clean(0 if passed else 2)
	else: quit(2)
