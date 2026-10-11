extends "res://tests/paving_surface.gd"
## Actual startup admission plus frozen shape comparison; no motion-quality claim.
var flower_owner: RefCounted
var support_report: Dictionary = {}
var fresh_admission_verified := false
var flower: ArrayMesh
var old_flower: ArrayMesh
var flowers: Array[MultiMeshInstance3D] = []
var flower_packets: String
var other_packets: String
var body_packets: String
var inventory: Array[Dictionary] = []
var selected_new: bool = false

func _run() -> void:
	var candidate_file := "res://baked/ground-flower.res"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
		if arg.begins_with("--candidate="): candidate_file=arg.trim_prefix("--candidate=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not output.begins_with(ProjectSettings.globalize_path("res://reports/")): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	flower=load(candidate_file) as ArrayMesh
	var template_bytes: PackedByteArray=var_to_bytes(flower.surface_get_arrays(0))
	var scene: PackedScene=load("res://main.tscn")
	game=scene.instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	controller=game.get("environment_controller")
	if not _check("Actual Main with fresh verification profile and rendered display",controller!=null and game.world.snapshot_loaded and str(game.store.directory).begins_with("user://verification/") and DisplayServer.get_name()!="headless"):
		_finish(); return
	owner=game.world.paving_preview_prebuilt
	flower_owner=game.world.ground_flower
	old_flower=flower_owner.original
	game.get_window().unfocusable=true; game.get_window().mouse_passthrough=true
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled=false
	await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false); game.player._visual.process_mode=Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false); game.ui.hide(); game.player.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; paused=false
	game.get_window().size=Vector2i(960,960); game.get_window().content_scale_size=Vector2i(960,960)
	var instances:=0
	for node: Node in game.world.find_children("*","MultiMeshInstance3D",true,false):
		var mesh: Mesh=node.multimesh.mesh
		if mesh is ArrayMesh and mesh.get_surface_count()==1 and mesh.surface_get_array_len(0)==282 and var_to_bytes(mesh.surface_get_arrays(0))==template_bytes and mesh.get_aabb()==flower.get_aabb():
			flowers.append(node); instances+=node.multimesh.instance_count
			inventory.append({"node":str(game.world.get_path_to(node)),"instances":node.multimesh.instance_count})
	if not _check("Exactly119 installed successor nodes and1430 instances freshly admitted",flowers.size()==119 and instances==1430 and flower!=null and flower.get_faces().size()==282):
		_finish(); return
	var unique_origins: Dictionary={}
	var floats:=0
	for node: MultiMeshInstance3D in flowers:
		floats+=node.multimesh.buffer.size()
		for instance: int in range(node.multimesh.instance_count): unique_origins[var_to_bytes(node.multimesh.get_instance_transform(instance).origin)]=true
	_check("Rendered native getters expose distinct real instance placements",unique_origins.size()>1400 and floats==1430*12)
	flower_packets=_flower_packets(); other_packets=_other_packets(); body_packets=_bodies()
	_check("Ordinary startup install precedes first scan and retains original", game.world.ground_flower_report.get("passed",false) and game.world.ground_flower_report.get("pre_environment_scan",false) and flower_owner.candidate==flower and old_flower!=flower)
	var proof: Dictionary=controller._ground_factory_proof
	_check("Original five proofs and separate sixth successor template admitted",proof.get("passed",false) and proof.families.size()==5 and proof.get("flower_successor",{}).get("passed",false) and controller._ground_templates.size()==6)
	var admitted:=0
	for row: Dictionary in controller._bounds:
		if row.node is MultiMeshInstance3D and row.node in flowers:
			var ok: bool=row.motion_admitted and row.native_mesh_id==str(flower.get_instance_id()) and row.source_root_plane_exact and row.native_root_corners==6 and row.anchor_readback_exact and row.cull_readback_exact and row.native_channels_exact.size()==Mesh.ARRAY_MAX
			for flag: bool in row.native_channels_exact: ok=ok and flag
			if ok: admitted+=1
	fresh_admission_verified=_check("All119 successor nodes freshly receive exact native root/wind/cull admission",admitted==119)
	var refusing: RefCounted=load("res://scripts/ground_flower_prebuilt.gd").new()
	_check("Wrong identity/resource refused without installation",refusing.load_candidate("res://baked/ground-flower.res","wrong")==null and refusing.load_candidate("res://baked/stream-banks.res")==null and refusing.nodes.is_empty())
	var rolled: bool=flower_owner.restore_original()
	for node: MultiMeshInstance3D in flowers: rolled=rolled and node.multimesh.mesh==old_flower
	_check("Owner restores actual original pointers and reinstalls candidate",rolled and _flower_packets()==flower_packets and flower_owner.reinstall())
	support_report=_support()
	_check("New leaf corners do not penetrate native ground across all1430 placements more than5mm",support_report.queries==38610 and support_report.penetrating==0 and support_report.missing_support==0)
	for state: String in ["gust","night","rain"]:
		controller.set_inspection_state(state)
		for frame: int in range(12): controller._process(1.0/60.0)
		var coherent:=true
		for node: MultiMeshInstance3D in flowers:
			var mat: ShaderMaterial=node.material_override
			coherent=coherent and mat.get_shader_parameter("env_time")==controller.clock_seconds and mat.get_shader_parameter("env_wind_direction")==controller.wind_direction and mat.get_shader_parameter("env_anchor_enabled")==1.0
		_check(state+": shared clock, wind direction and anchor bound on all flowers",coherent)
	for label: String in ["close-day","wide-day","close-night","close-rain"]:
		await _flower_pair(label)
	_finish()

func _flower_pair(label: String) -> void:
	var night:=label=="close-night"; var rain:=label=="close-rain"; var wide:=label=="wide-day"
	game.review_camera.position=Vector3(4.8,2.65,17.0) if wide else Vector3(2.2,1.0,9.0)
	game.review_camera.fov=58.0 if wide else 52.0
	game.review_camera.look_at(Vector3(0,1.3,3.6) if wide else Vector3(1.7,.25,5.6)); game.review_camera.make_current()
	controller.set_foreground(true); controller.set_inspection_state("rain" if rain else ("night" if night else "calm"))
	game.set_appearance("night" if night else "day","rain" if rain else "sunny")
	await create_timer(4.0).timeout
	controller.set_foreground(false); game.world.set_environment_foreground(false)
	await _frames(3)
	var held:=_flower_context()
	var held_poses:=_poses()
	for after: bool in [false,true]:
		for node: MultiMeshInstance3D in flowers: node.multimesh.mesh=flower if after else old_flower
		selected_new=after
		await _frames(10); await RenderingServer.frame_post_draw
		var frame: Image=root.get_texture().get_image()
		var name:=label+("-after.png" if after else "-before.png")
		frame.convert(Image.FORMAT_RGBA8)
		var ok:=frame.get_size()==Vector2i(960,960) and frame.save_png(output.path_join(name))==OK and _flower_context()==held and _poses()==held_poses and _flower_packets()==flower_packets
		for node: MultiMeshInstance3D in flowers: ok=ok and node.multimesh.mesh==(flower if after else old_flower)
		_check(name+": frozen context, buffers/materials/root poses exact",ok)
		views.append({"file":name,"sha256":FileAccess.get_sha256(output.path_join(name)),"passed":ok})
	for node: MultiMeshInstance3D in flowers: node.multimesh.mesh=flower
	selected_new=false

func _flower_packets() -> String:
	var rows: Array=[]
	for node: MultiMeshInstance3D in flowers:
		rows.append([node.get_instance_id(),node.multimesh.get_instance_id(),node.multimesh.buffer,node.multimesh.instance_count,node.multimesh.visible_instance_count,node.transform,node.global_transform,node.material_override.get_instance_id(),node.cast_shadow,node.extra_cull_margin,node.custom_aabb,owner.call("_metadata",node)])
	return _sha(var_to_bytes(rows))
func _other_packets() -> String:
	var rows: Array=[]
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false):
		if node is MultiMeshInstance3D and node in flowers: continue
		var mesh: Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null)
		var channels: Array=[]
		if mesh is ArrayMesh:
			for surface: int in range(mesh.get_surface_count()): channels.append(mesh.surface_get_arrays(surface))
		rows.append([node.get_instance_id(),node.material_override.get_instance_id() if node.material_override!=null else 0,mesh.get_instance_id() if mesh!=null else 0,channels])
	return _sha(var_to_bytes(rows))
func _poses() -> String:
	var rows: Array=[]
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false): rows.append([node.get_instance_id(),node.transform])
	return _sha(var_to_bytes(rows))
func _bodies() -> String:
	var rows: Array=[]
	var omit: Array[String]=[]
	for node: Node in game.world.find_children("*","CollisionShape3D",true,false):
		rows.append([node.get_instance_id(),node.transform,node.disabled,node.shape.get_instance_id(),owner.call("_stored",node.shape,omit),node.get_parent().get_instance_id()])
	return _sha(var_to_bytes(rows))
func _flower_context() -> String:
	var materials: Dictionary={}
	for node: MultiMeshInstance3D in flowers: materials[node.material_override.get_instance_id()]=_parameters(node.material_override)
	return _sha(var_to_bytes([game._review_lighting_state(),game.review_camera.global_transform,game.review_camera.fov,root.get_visible_rect().size,controller.clock_seconds,controller.detail_clock_seconds,controller.cloud_offset,controller.wetness,game.world.night_amount,game.world.rain_amount,materials]))
func _support() -> Dictionary:
	var result: Dictionary={"failures":[],"queries":0,"penetrating":0,"missing_support":0,"minimum_clearance_m":INF,"scope":"Native layer1 ray clearance for unique new leaf vertices across all119 chunks; not full blade/rock/wind-deformed coverage."}
	var bridge: StaticBody3D=game.world.get_node_or_null("ArchedTimberBridge/@StaticBody3D@1612") as StaticBody3D
	_check("Ground clearance explicitly distinguishes the retained overhead bridge",bridge!=null and bridge.collision_layer==1)
	if bridge==null: return result
	result["architectural_exclusion"]=str(game.world.get_path_to(bridge))
	result["bridge_occluded_corners"]=0
	result["scope"]="Native layer1 rays for unique leaf vertices across all119 chunks, excluding the identified overhead bridge. Full blade/rock/wind-deformed coverage remains unverified."
	var vertices: PackedVector3Array=flower.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var unique: Array[Vector3]=[]
	for index: int in range(36,108):
		if not vertices[index] in unique: unique.append(vertices[index])
	for node: MultiMeshInstance3D in flowers:
		for instance: int in range(node.multimesh.instance_count):
			var pose: Transform3D=node.global_transform*node.multimesh.get_instance_transform(instance)
			for vertex: Vector3 in unique:
				var point: Vector3=pose*vertex
				var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.15,point-Vector3.UP*.6,1)
				var hit: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.collider==bridge:
					result.bridge_occluded_corners+=1
					query.exclude=[bridge.get_rid()]
					hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
				result.queries+=1
				if hit.is_empty(): result.missing_support+=1; continue
				var clearance: float=point.y-hit.position.y
				result.minimum_clearance_m=minf(result.minimum_clearance_m,clearance)
				if clearance < -.005:
					result.penetrating+=1
					result.failures.append({"node":str(node.name),"instance":instance,"vertex":str(vertex),"point":str(point),"pose":str(pose),"hit":str(hit.position),"body":str(hit.collider.get_path()),"clearance":clearance})
	return result
func _finish() -> void:
	for node: MultiMeshInstance3D in flowers: node.multimesh.mesh=flower
	if not flower_packets.is_empty():
		_check("Installed successor pointer restored and unrelated native mesh/collision preservation",_flower_packets()==flower_packets and _other_packets()==other_packets and _bodies()==body_packets and bool(owner.call("verify",game.world,true)))
	_check("Eight matched frames complete",views.size()==8)
	var failed:=0
	for check: Dictionary in checks:
		if not check.passed: failed+=1
	var report: Dictionary={"passed":failed==0,"checks":checks,"views":views,"inventory":inventory,"candidate_sha256":FileAccess.get_sha256(flower.resource_path) if flower!=null else "","candidate_wind_admission_verified":fresh_admission_verified,"support":support_report,"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),"motion_verified":false,"scope":"Actual Main startup admission and frozen native shape comparison. No GPU-deformed-vertex readback or continuous motion claim."}
	FileAccess.open(output.path_join("flower-capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FLOWER_CAPTURE ",failed," failures, ",checks.size()," checks")
	if is_instance_valid(game): game._quit_clean(0 if failed==0 else 2)
	else: quit(2)
