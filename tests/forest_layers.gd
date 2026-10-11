extends "res://tests/forest_backdrop.gd"
var baseline: Node3D
var trial: Node3D
var candidate_report: Dictionary
var inventories: Dictionary
var geometry_hash: String
var physics_hash: String
var clearance_report: Dictionary={}

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not output.begins_with(ProjectSettings.globalize_path("res://reports/")): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	controller=game.get("environment_controller")
	if not _check("Actual rendered startup with fresh test profile",controller!=null and game.world.snapshot_loaded and str(game.store.directory).begins_with("user://verification/") and DisplayServer.get_name()!="headless"):
		_finish(); return
	owner=game.world.paving_preview_prebuilt
	game.get_window().unfocusable=true; game.get_window().mouse_passthrough=true
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.player.enabled=false
	await _frames(15)
	game.player.set_process(false); game.player.set_physics_process(false); game.player._visual.process_mode=Node.PROCESS_MODE_DISABLED
	game.world.set_living_motion_enabled(false); game.ui.hide(); game.player.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; paused=false
	game.get_window().size=Vector2i(1280,720); game.get_window().content_scale_size=Vector2i(1280,720)
	trial=game.world.get_node("ForestMiddleLayer")
	backdrop=game.world.forest_backdrop
	geometry_hash=_rest(); physics_hash=_bodies(); bodies_before=physics_hash
	load("res://scripts/forest_enclosure.gd").build(game.world,true)
	baseline=game.world.get_node("ForestMiddleReference")
	candidate_report=game.world.forest_enclosure
	trial.hide()
	inventories={"baseline":_inventory(baseline),"trial":_inventory(trial)}
	_check("Same450 instances and native meshes/materials; prior colliders exact",inventories.baseline.instances==450 and inventories.trial.instances==450 and inventories.baseline.triangles==inventories.trial.triangles and inventories.baseline.mesh_material_keys==inventories.trial.mesh_material_keys and _bodies()==physics_hash)
	_check("Layer comparison preserves all unrelated rest geometry",_rest()==geometry_hash)
	var lines: Array[String]=[]
	for row: Dictionary in inventories.baseline.nodes: lines.append(row.name+"="+row.buffer_sha256)
	lines.sort()
	_check("Reference constructor reproduces all preceding native chunk buffers",_sha("\n".join(lines).to_utf8_buffer())=="1ddd6241fbc22f8ead63b294cf26a00d3f4b236ab9b2075c1028cb0fb3fc997f")
	_check("Ordinary startup owns corrected layout and fixed native camera inset",candidate_report.height_cohorts==[13,9,8] and candidate_report.stream_root_shifted==1 and game.player.get_camera().get_parent().name=="ShapeCastCameraMargin" and game.player.get_camera().position==Vector3(0,0,-.05))
	await _native_clearance()
	var contacts: RefCounted=load("res://tests/forest_trunk_contacts.gd").new()
	clearance_report["contacts"]=await contacts.run(game,trial)
	_check("Actual trunk blocking/sliding regression",clearance_report.contacts.passed)
	for label: String in ["home-day","side-day","reverse-day","home-night","home-rain"]: await _forest_pair(label)
	await _camera_check()
	await _trunk_camera_check()
	_finish()

func _forest_pair(label: String) -> void:
	var night:=label.ends_with("night"); var rain:=label.ends_with("rain")
	var camera:=Vector3(0,2.8,18); var target:=Vector3(0,1.6,0)
	if label=="side-day": camera=Vector3(-12,2.2,7); target=Vector3(-17,1.8,-8)
	if label=="reverse-day": camera=Vector3(0,2.8,6); target=Vector3(0,1.3,25)
	game.review_camera.position=camera; game.review_camera.fov=65
	game.review_camera.look_at(target); game.review_camera.make_current()
	controller.set_foreground(true); game.world.set_environment_foreground(true)
	controller.set_inspection_state("rain" if rain else ("night" if night else "calm"))
	game.set_appearance("night" if night else "day","rain" if rain else "sunny")
	await create_timer(4.0).timeout
	controller.set_foreground(false); game.world.set_environment_foreground(false)
	await _frames(3)
	var held:=_held()
	var settled_rest:=_rest()
	for after: bool in [false,true]:
		baseline.visible=not after; trial.visible=after
		await _frames(10); await RenderingServer.frame_post_draw
		var frame: Image=root.get_texture().get_image(); frame.convert(Image.FORMAT_RGBA8)
		var name:=label+("-after.png" if after else "-before.png")
		var ok:=frame.get_size()==Vector2i(1280,720) and frame.save_png(output.path_join(name))==OK and _held()==held and _rest()==settled_rest and _bodies()==physics_hash
		_check(name+": frozen context and pre-existing rest/collision exact",ok)
		views.append({"file":name,"passed":ok,"sha256":FileAccess.get_sha256(output.path_join(name)),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	baseline.show(); trial.hide()

func _inventory(parent: Node3D) -> Dictionary:
	var report: Dictionary={"draw_nodes":0,"instances":0,"triangles":0,"mesh_material_keys":[],"nodes":[]}
	for node: Node in parent.get_children():
		if not node is MultiMeshInstance3D: continue
		var mesh: Mesh=node.multimesh.mesh
		var key:=str(mesh.get_instance_id())+":"+str(node.material_override.get_instance_id())
		# Cylinders are freshly built equivalent resources, so use native geometry hash.
		key=_sha(var_to_bytes(mesh.surface_get_arrays(0)))+":"+str(node.material_override.get_instance_id())
		if not key in report.mesh_material_keys: report.mesh_material_keys.append(key)
		report.draw_nodes+=1; report.instances+=node.multimesh.instance_count
		report.triangles+=mesh.get_faces().size()/3*node.multimesh.instance_count
		report.nodes.append({"name":str(node.name),"instances":node.multimesh.instance_count,"mesh_aabb":str(mesh.get_aabb()),"triangles_per_instance":mesh.get_faces().size()/3,"shader":node.material_override.shader.resource_path,"cull_margin":node.extra_cull_margin,"buffer_sha256":_sha(var_to_bytes(node.multimesh.buffer)),"mesh_material_key":key})
	return report

func _rest() -> String:
	var rows: Array=[]
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false):
		if (trial!=null and trial.is_ancestor_of(node)) or (baseline!=null and baseline.is_ancestor_of(node)): continue
		var mesh: Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null)
		rows.append([node.get_instance_id(),node.transform,mesh.get_instance_id() if mesh!=null else 0,node.multimesh.buffer if node is MultiMeshInstance3D else null,node.material_override.get_instance_id() if node.material_override!=null else 0,node.cast_shadow,node.extra_cull_margin,node.custom_aabb])
	return _sha(var_to_bytes(rows))

func _bodies() -> String:
	var rows: Array=[]; var omit: Array[String]=[]
	for node: Node in game.world.find_children("*","CollisionShape3D",true,false):
		if (trial!=null and trial.is_ancestor_of(node)) or (baseline!=null and baseline.is_ancestor_of(node)): continue
		rows.append([node.get_instance_id(),node.transform,node.disabled,node.shape.get_instance_id(),owner.call("_stored",node.shape,omit),node.get_parent().get_instance_id()])
	return _sha(var_to_bytes(rows))

func _held() -> String:
	var materials: Dictionary={}
	for node: Node in baseline.get_children(): materials[node.material_override.get_instance_id()]=_parameters(node.material_override)
	return _sha(var_to_bytes([game._review_lighting_state(),game.review_camera.global_transform,game.review_camera.fov,controller.clock_seconds,controller.detail_clock_seconds,controller.cloud_offset,controller.wetness,game.world.night_amount,game.world.rain_amount,materials]))

func _finish() -> void:
	if baseline!=null: baseline.hide()
	if trial!=null: trial.show()
	_check("Ten paired frames complete",views.size()==10)
	var failed:=0
	for row: Dictionary in checks:
		if not row.passed: failed+=1
	FileAccess.open(output.path_join("forest-layers.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":failed==0,"checks":checks,"views":views,"candidate_report":candidate_report,"camera":camera_rows,"clearance":clearance_report,"inventories":inventories,"motion_verified":false,"art_approved":false,"performance_measured":false},"  "))
	print("FOREST_COMPLETE ",failed," failures")
	if is_instance_valid(game): game._quit_clean(0 if failed==0 else 2)
	else: quit(2)

func _native_clearance() -> void:
	var probe:=StaticBody3D.new(); probe.collision_layer=1<<30; probe.collision_mask=0; game.world.add_child(probe)
	var floors: Array[MeshInstance3D]=[game.world.get_node(game.world.forest_backdrop.SOIL_PATH)]
	for node: MeshInstance3D in game.world.forest_backdrop.root.get_children(): floors.append(node)
	var maximum_ground: float=-INF
	for node: MeshInstance3D in floors:
		var faces: PackedVector3Array=node.mesh.get_faces()
		for i: int in range(faces.size()): faces[i]=node.global_transform*faces[i]; maximum_ground=maxf(maximum_ground,faces[i].y)
		var shape:=ConcavePolygonShape3D.new(); shape.set_faces(faces)
		var child:=CollisionShape3D.new(); child.shape=shape; probe.add_child(child)
	await physics_frame; await physics_frame
	var result: Dictionary={"leaf_queries":0,"leaf_high_corners":0,"leaf_misses":0,"channel_samples":0,"leaf_penetrations":0,"minimum_leaf_clearance_m":INF,"maximum_ground_y":maximum_ground,"root_queries":0,"root_gaps":0,"root_misses":0,"root_depth_min":INF,"root_depth_max":-INF,"trunk_reachable_corners":[],"wind_jacobian_lower":1.0,"wind_cull_passed":true,"native_bounds_passed":true,"finite_poses":true,"examples":[]}
	var root_keys: Dictionary={}; var mesh_cache: Dictionary={}
	for child_node: Node in trial.get_children():
		if not child_node is MultiMeshInstance3D: continue
		var node: MultiMeshInstance3D=child_node
		var crown:=str(node.name).begins_with("Layered")
		var mesh: Mesh=node.multimesh.mesh
		if not mesh_cache.has(mesh.get_instance_id()):
			var unique: Dictionary={}
			for p: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: unique[var_to_bytes(p)]=p
			mesh_cache[mesh.get_instance_id()]=unique.values()
		var native_bounds: AABB=node.multimesh.get_aabb().grow(.00001)
		for i: int in range(node.multimesh.instance_count):
			var pose: Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
			result.finite_poses=result.finite_poses and pose.is_finite() and pose.basis.determinant()>.000001
			if crown:
				var inverse_basis: Basis=pose.basis.inverse()
				var inverse_norm: float=sqrt(inverse_basis.x.length_squared()+inverse_basis.y.length_squared()+inverse_basis.z.length_squared())
				result.wind_jacobian_lower=minf(result.wind_jacobian_lower,1.0-1.2*.025*inverse_norm)
				result.wind_cull_passed=result.wind_cull_passed and node.global_transform==Transform3D.IDENTITY and node.extra_cull_margin>=.025 and node.material_override.shader==game.world._M37_WIND_SHADER
			else:
				var bottom: Vector3=pose*Vector3(0,-.5,0)
				if absf(bottom.y+.35)<.0001 and not root_keys.has(var_to_bytes(bottom)):
					root_keys[var_to_bytes(bottom)]=true; result.root_queries+=1
					var hit: Dictionary=_floor_hit(bottom)
					if hit.is_empty(): result.root_misses+=1
					else:
						var depth: float=hit.position.y-bottom.y
						result.root_depth_min=minf(result.root_depth_min,depth); result.root_depth_max=maxf(result.root_depth_max,depth)
						if depth<-.001: result.root_gaps+=1
			for point: Vector3 in mesh_cache[mesh.get_instance_id()]:
				var p: Vector3=pose*point
				result.native_bounds_passed=result.native_bounds_passed and native_bounds.has_point(p)
				if not crown:
					if absf(p.x)<20.4 and p.z> -20.4 and p.z<26.4 and p.y>-.3 and p.y<4.5: result.trunk_reachable_corners.append(str(p))
					continue
				if p.y>maximum_ground+.025: result.leaf_high_corners+=1; continue
				result.leaf_queries+=1
				var hit: Dictionary=_floor_hit(p)
				if hit.is_empty():
					if p.x>=7.79999 and p.x<=10.20001 and p.y>-.16+.025: result.channel_samples+=1
					else: result.leaf_misses+=1
					continue
				var delta: float=p.y-hit.position.y
				result.minimum_leaf_clearance_m=minf(result.minimum_leaf_clearance_m,delta)
				if delta<.025:
					result.leaf_penetrations+=1
					if result.examples.size()<12: result.examples.append({"node":str(node.name),"instance":i,"point":str(p),"ground":str(hit.position),"clearance_m":delta})
	probe.free(); await physics_frame
	clearance_report=result
	_check("Native crown vertices have25mm terrain clearance",result.leaf_misses==0 and result.leaf_penetrations==0)
	_check("Thirty grounded trunk bases",result.root_queries==30 and result.root_gaps==0 and result.root_misses==0)
	_check("Four reachable tree bodies with twenty stem shapes",candidate_report.new_colliders==4 and candidate_report.new_collision_shapes==20)
	_check("Stem colliders enclose corresponding native rendered segments",_stem_shapes())
	_check("Finite positive poses/native culling/analytic wind bound",result.finite_poses and result.native_bounds_passed and result.wind_cull_passed and result.wind_jacobian_lower>.9)
	_check("Query-only ground removed; bodies preserved",_bodies()==physics_hash)
	var concise:=result.duplicate(true); concise.trunk_reachable_corners=result.trunk_reachable_corners.size(); print("HEIGHT_CLEARANCE ",JSON.stringify(concise))

func _floor_hit(p: Vector3) -> Dictionary:
	return game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,10,p.z),Vector3(p.x,-2,p.z),1<<30))

func _stem_shapes() -> bool:
	var poses: Array[Transform3D]=[]
	for node: Node in trial.get_children():
		if not node is MultiMeshInstance3D or not str(node.name).begins_with("BentTrunks"): continue
		for i: int in range(node.multimesh.instance_count): poses.append(node.global_transform*node.multimesh.get_instance_transform(i))
	var count:=0; var worst: float=0.0
	for body: Node in trial.get_children():
		if not body is StaticBody3D: continue
		if body.collision_layer!=1 or body.collision_mask!=2 or not body.get_meta("unsafe_support",false) or body.has_meta("entrance48_step_surface"): return false
		for contact: CollisionShape3D in body.get_children():
			if not contact.shape is CylinderShape3D or contact.disabled: return false
			var found:=false
			for pose: Transform3D in poses:
				if not pose.origin.is_equal_approx(contact.global_position): continue
				if not pose.basis.orthonormalized().is_equal_approx(contact.global_basis): continue
				if absf(contact.shape.height-pose.basis.y.length())>.00001 or absf(contact.shape.radius-pose.basis.x.length())>.00001: continue
				found=true; break
			if not found: return false
			count+=1; worst=maxf(worst,contact.shape.radius*(1.0-.88*cos(PI/8.0)))
	clearance_report["collision_shape_native_matches"]=count
	clearance_report["maximum_collision_shell_m"]=worst
	return count==20 and worst<.09 and absf(worst-float(candidate_report.maximum_trunk_collision_shell_m))<.00001


func _trunk_camera_check() -> void:
	game.player.set_physics_process(true); game.player.set_process(true)
	var shortened:=0; var valid:=true; var count:=0
	for body: Node in trial.get_children():
		if not body is StaticBody3D: continue
		var site: Vector3=body.get_meta("forest_root")+Vector3(0,.35,1.5)
		var support: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(site+Vector3.UP*1.5,site-Vector3.UP,1))
		if support.is_empty(): valid=false; continue
		var point: Vector3=support.position+Vector3.UP*.008
		for pitch: float in [-65.0,-10.0,15.0]:
			game.player._camera_pitch=deg_to_rad(pitch); game.player.teleport_safe(point,PI)
			for i: int in range(45): await physics_frame
			var camera: Camera3D=game.player.get_camera()
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=game.player._spring_arm.shape; query.transform=camera.global_transform; query.collision_mask=1; query.margin=.001
			var hits:=0
			var overlaps: Array[Dictionary]=game.world.get_world_3d().direct_space_state.intersect_shape(query,32)
			for contact: Dictionary in overlaps:
				if trial.is_ancestor_of(contact.collider): hits+=1
			var arm: float=game.player._spring_arm.get_hit_length()
			var one: bool=camera.global_position.is_finite() and game.player.global_position.distance_to(point)<.3 and hits==0 and overlaps.size()<32
			camera_rows.append({"site":str(site),"pitch":pitch,"camera":str(camera.global_position),"player":str(game.player.global_position),"sphere_radius":query.shape.radius,"trunk_sphere_hits":hits,"overlap_query_hits":overlaps.size(),"overlap_query_saturated":overlaps.size()==32,"spring_arm_length":arm,"trunk_site":true,"passed":one})
			if pitch==15 and arm<2.0: shortened+=1
			valid=valid and one; count+=1
	game.player.set_physics_process(false); game.player.set_process(false)
	_check("Twelve actual camera-sphere poses clear the four new trunks",valid and count==12)
	_check("Native spring arm responds to all four trunks",shortened==4)
	_check("Camera checks leave original bodies exact",_bodies()==physics_hash)
