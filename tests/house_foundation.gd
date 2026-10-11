extends "res://tests/paving_surface.gd"
## Installed closest-home support: deterministic native parity, contacts and paired views.
## The fixture removes its installed support at shutdown and holds every other owner.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const Contacts = preload("res://tests/forest_trunk_contacts.gd")
const HOME: String = "ForestBeyondTheClearing/@Node3D@3758"
const STEM: String = "BatchedStaticWorld/Static_-9223371995264055848_2_-3"
const STEM_SHA: String = "824354dfc27ceed7c6b40e701ae3f2135b745352dbfaaf07f8fb1fd94173d0e4"
const CENTER: Vector3 = Vector3(16.5,2.0,-18.5)
const SOIL: String = "BatchedStaticWorld/Static_-9223371995029174788_0_0"
var trial: Node3D
var support_mesh: ArrayMesh
var support_body: StaticBody3D
var soil_probe: StaticBody3D
var soil_faces: PackedVector3Array = PackedVector3Array()
var stem_bottom: PackedVector2Array = PackedVector2Array()
var foot_faces: PackedVector3Array = PackedVector3Array()
var geometry_report: Dictionary = {}
var contact_report: Dictionary = {}
var camera_report: Array[Dictionary] = []
var artifact: Dictionary = {"passed":false}
var original_bindings: String = ""
var binding_rows_before: Dictionary = {}
var restoration_diagnostic: Dictionary = {}
var original_native: String = ""
var original_material_art: String = ""
var original_rng: int = 0
var source_meshes: Array[MeshInstance3D] = []
var appearance_before: Array = []
var player_before: Dictionary = {}
var removed: bool = false

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output=arg.trim_prefix("--report-dir=")
	var reports: String=ProjectSettings.globalize_path("res://reports/").simplify_path().trim_suffix("/")
	output=output.simplify_path()
	if output.is_empty() or not output.is_absolute_path() or not output.begins_with(reports+"/") or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: quit(2); return
	if not _check("Rendered benchmark isolation without automatic runners",DisplayServer.get_name()!="headless" and "--benchmark" in OS.get_cmdline_user_args() and not "--smoke" in OS.get_cmdline_user_args() and not "--verify" in OS.get_cmdline_user_args() and not "--capture" in OS.get_cmdline_user_args()): await _finish(); return
	game=load("res://main.tscn").instantiate(); game.set_script(PavingSurfaceGame); root.add_child(game)
	var deadline: int=Time.get_ticks_msec()+90000
	while game.get("environment_controller")==null and Time.get_ticks_msec()<deadline: await process_frame
	controller=game.get("environment_controller")
	if not _check("Actual Main, native world and fresh verification profile",controller!=null and game.world.snapshot_loaded and game.mode=="explore" and str(game.store.directory).begins_with("user://verification/paving_surface_") and not paused): await _finish(); return
	owner=game.world.paving_preview_prebuilt
	root.unfocusable=true; root.mouse_passthrough=true
	root.size=Vector2i(960,960); root.content_scale_size=Vector2i(960,960)
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.player.release_controls(); game.ui.hide(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	appearance_before=[game.sky,game.weather,controller.inspection_state,controller.foreground,game.world._environment_foreground]
	player_before={"pose":game.player.global_position,"yaw":game.player.camera_yaw,"pitch":game.player._camera_pitch,"enabled":game.player.enabled,"physics":game.player.is_physics_processing(),"process":game.player.is_processing(),"visible":game.player.visible,"visual_mode":game.player._visual.process_mode,"camera":root.get_camera_3d(),"settings":Contacts.new()._settings(game.player)}
	game.player.release_controls(); await _frames(15)
	trial=game.world.get_node_or_null("ClosestHomeFoundation") as Node3D
	if not _check("Actual startup foundation owner with four static nodes",game.world.closest_home_foundation_report.get("passed",false) and game.world.closest_home_foundation_report.get("installed",false) and trial!=null and trial.get_child_count()==2 and trial.find_children("*","",true,false).size()==3): await _finish(); return
	var render: MeshInstance3D=trial.get_node_or_null("StoneLedge") as MeshInstance3D
	support_body=trial.get_node_or_null("StoneContact") as StaticBody3D
	var contact: CollisionShape3D=trial.get_node_or_null("StoneContact/Surface") as CollisionShape3D
	if not _check("Installed shared stone and unsafe exact triangle contact",render!=null and render.mesh is ArrayMesh and render.material_override==game.world._materials.stone_light and support_body!=null and support_body.collision_layer==1 and support_body.collision_mask==2 and support_body.get_meta("unsafe_support",false) and contact!=null and contact.shape is ConcavePolygonShape3D and not contact.disabled): await _finish(); return
	if not _check("Exact closest-home native stem packet and immutable source owners",_admit_sources()): await _finish(); return
	original_bindings=_original_bindings(); binding_rows_before=_support_binding_rows(true); original_native=_native_sources()
	_materials_held() # Prime lazy native material storage before held maps.
	original_material_art=_material_art()
	original_rng=game.world._rng.state
	await _soil_queries()
	if not _check("Native render soil registered for the local footprint",soil_probe!=null and not soil_faces.is_empty()): await _finish(); return
	var expected: ArrayMesh=_build_mesh()
	support_mesh=render.mesh
	if not _check("Installed resource equals deterministic native authoring and buried footprint",expected!=null and geometry_report.get("passed",false) and var_to_bytes(NativeReader.mesh_record(expected))==var_to_bytes(NativeReader.mesh_record(support_mesh)) and var_to_bytes(RenderingServer.mesh_get_surface(expected.get_rid(),0))==var_to_bytes(RenderingServer.mesh_get_surface(support_mesh.get_rid(),0))): await _finish(); return
	var shape: ConcavePolygonShape3D=contact.shape
	_check("Same installed native render/contact faces, shared stone, one opaque surface",shape.get_faces().to_byte_array()==support_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array() and support_mesh.surface_get_material(0)==null and render.material_override==game.world._materials.stone_light and render.global_transform==Transform3D.IDENTITY and support_body.global_transform==Transform3D.IDENTITY and not support_body.has_meta("entrance48_step_surface"))
	_check("Original owners/native arrays/RNG held through construction",_original_bindings()==original_bindings and _native_sources()==original_native and game.world._rng.state==original_rng)
	geometry_report["nearby_tree_contacts"]=_nearby_tree_contacts()
	_check("Nearby native trunk cylinders neither cross nor lie inside the new rock",geometry_report.nearby_tree_contacts.passed)
	await _contacts_and_cameras()
	game.player.release_controls(); game.player.enabled=false; game.player.set_process(false); game.player.set_physics_process(false); game.player._visual.process_mode=Node.PROCESS_MODE_DISABLED; game.player.visible=false
	game.world.set_living_motion_enabled(false)
	for label: String in ["front-day","side-day","wide-day","front-night","side-night","wide-night"]: await _support_pair(label)
	await _finish()

func _admit_sources() -> bool:
	var home: Node3D=game.world.get_node_or_null(HOME) as Node3D
	var stem: MeshInstance3D=game.world.get_node_or_null(STEM) as MeshInstance3D
	var stub: MeshInstance3D=home.get_node_or_null("@MeshInstance3D@3759") as MeshInstance3D if home!=null else null
	if home==null or home.global_transform!=Transform3D(Basis.IDENTITY,CENTER) or stub==null or stub.mesh!=null or stub.global_transform!=Transform3D(Basis.IDENTITY,Vector3(16.5,2.9,-18.5)) or stem==null or not stem.mesh is ArrayMesh or stem.global_transform!=Transform3D.IDENTITY or stem.material_override!=stub.material_override: return false
	var arrays: Array=stem.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	if positions.size()!=3072 or arrays[Mesh.ARRAY_INDEX]!=null or _sha(positions.slice(0,1536).to_byte_array())!=STEM_SHA: return false
	var unique: Dictionary={}
	for p: Vector3 in positions.slice(0,1536):
		if p.y==CENTER.y and Vector2(p.x-CENTER.x,p.z-CENTER.z).length()>.01: unique[var_to_bytes(p)]=Vector2(p.x,p.z)
	for p: Vector2 in unique.values(): stem_bottom.append(p)
	if stem_bottom.size()!=64: return false
	source_meshes=[stem,game.world.get_node(SOIL)]
	for n: MeshInstance3D in game.world.forest_backdrop.root.get_children(): source_meshes.append(n)
	return source_meshes.size()==4

func _soil_queries() -> void:
	soil_probe=StaticBody3D.new(); soil_probe.name="ClosestHomeSoilQuery"; soil_probe.collision_layer=1<<30; soil_probe.collision_mask=0; game.world.add_child(soil_probe)
	for node: MeshInstance3D in source_meshes.slice(1):
		var native: PackedVector3Array=_native_faces(node.mesh)
		var local: PackedVector3Array=PackedVector3Array()
		for offset: int in range(0,native.size(),3):
			var tri: PackedVector3Array=PackedVector3Array([node.global_transform*native[offset],node.global_transform*native[offset+1],node.global_transform*native[offset+2]])
			var box: AABB=AABB(tri[0],Vector3.ZERO).expand(tri[1]).expand(tri[2])
			if box.position.x>19.4 or box.end.x<15.3 or box.position.z> -16.7 or box.end.z< -21.8: continue
			local.append_array(tri)
		soil_faces.append_array(local)
		if not local.is_empty():
			var shape: ConcavePolygonShape3D=ConcavePolygonShape3D.new(); shape.set_faces(local)
			var contact: CollisionShape3D=CollisionShape3D.new(); contact.shape=shape; soil_probe.add_child(contact)
	await physics_frame; await physics_frame

func _ground(point: Vector3) -> Dictionary:
	return game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,5.0,point.z),Vector3(point.x,-2.0,point.z),1<<30))

func _build_mesh() -> ArrayMesh:
	# Existing deterministic rock morphology; no calls to _rock or the world RNG.
	var outline: PackedVector2Array=PackedVector2Array()
	for i: int in range(16):
		var p: Vector3=game.world._rock_point(TAU*float(i)/16.0,PI*.5,2.31)
		var radial: Vector2=Vector2(p.x,p.z)
		outline.append(radial*.92)

	var disk: bool=outline.size()>=8
	var top_polygon: PackedVector2Array=PackedVector2Array()
	for p: Vector2 in outline: top_polygon.append(p.normalized()*.76+Vector2(CENTER.x,CENTER.z))
	for p: Vector2 in stem_bottom: disk=disk and Geometry2D.is_point_in_polygon(p,top_polygon)
	var profiles: Array[Vector2]=[Vector2(2.006,1.0),Vector2(1.73,1.24),Vector2(1.10,1.64),Vector2(.34,1.63),Vector2(0.0,1.36)]
	var centers: Array[Vector2]=[Vector2.ZERO,Vector2(.18,-.16),Vector2(.78,-.46),Vector2(.91,-.70),Vector2(.90,-.80)]
	var x_scales: Array[float]=[1.0,.72,.57,.52,.60]
	var rings: Array[PackedVector3Array]=[]
	var native_foot_rows: Array[Dictionary]=[]
	var buried: bool=true
	for ring: int in range(profiles.size()):
		var points: PackedVector3Array=PackedVector3Array()
		for p: Vector2 in outline:
			var point: Vector3=Vector3(CENTER.x+p.x*profiles[ring].y*x_scales[ring]+centers[ring].x,profiles[ring].x,CENTER.z+p.y*profiles[ring].y+centers[ring].y)
			# Preserve the native stem disk, give the lower ledge a broad rear shoulder,
			if ring==0:
				point=Vector3(CENTER.x+p.normalized().x*.76,2.006,CENTER.z+p.normalized().y*.76)
			# and leave the existing west trunk a separate rooted footprint.

			if ring>0 and ring<profiles.size()-1: point.y+=.12*sin(atan2(p.y,p.x)*3.0+.7)*minf(float(ring),1.5)
			if ring==profiles.size()-1:
				var hit: Dictionary=_ground(point)
				if hit.is_empty() or hit.collider!=soil_probe: buried=false
				else:
					point.y=hit.position.y-.04
					native_foot_rows.append({"point":str(point),"soil":str(hit.position),"burial_m":hit.position.y-point.y})
			points.append(point)
		rings.append(points)
	var vertices: PackedVector3Array=PackedVector3Array(); var normals: PackedVector3Array=PackedVector3Array(); var uv: PackedVector2Array=PackedVector2Array(); var colors: PackedColorArray=PackedColorArray()
	for ring: int in range(rings.size()-1):
		for i: int in range(outline.size()):
			var j: int=(i+1)%outline.size()
			_emit(rings[ring][i],rings[ring+1][i],rings[ring+1][j],false,vertices,normals,uv,colors)
			_emit(rings[ring][i],rings[ring+1][j],rings[ring][j],false,vertices,normals,uv,colors)
	# Smooth only shared side vertices; keep the hidden top and buried base caps sharp.
	var adjoining: Dictionary={}
	for offset: int in range(0,vertices.size(),3):
		var area_normal: Vector3=(vertices[offset+2]-vertices[offset]).cross(vertices[offset+1]-vertices[offset])
		for k: int in range(3):
			var key: PackedByteArray=var_to_bytes(vertices[offset+k])
			if not adjoining.has(key): adjoining[key]=[]
			adjoining[key].append(area_normal)
	for i: int in range(vertices.size()):
		var smooth: Vector3=Vector3.ZERO
		for face: Vector3 in adjoining[var_to_bytes(vertices[i])]:
			if face.normalized().dot(normals[i])>=.5: smooth+=face
		normals[i]=(normals[i]*.25+smooth.normalized()*.75).normalized()
	var foot_center: Vector3=Vector3(CENTER.x+centers[-1].x,0,CENTER.z+centers[-1].y)
	var center_hit: Dictionary=_ground(foot_center)
	buried=buried and not center_hit.is_empty() and center_hit.get("collider") == soil_probe
	var bottom: Vector3=Vector3(foot_center.x,float(center_hit.get("position",Vector3.ZERO).y)-.04,foot_center.z)
	for i: int in range(outline.size()):
		var j: int=(i+1)%outline.size()
		_emit(Vector3(CENTER.x,2.006,CENTER.z),rings[0][i],rings[0][j],true,vertices,normals,uv,colors)
		var start: int=vertices.size()
		_emit(bottom,rings[-1][j],rings[-1][i],true,vertices,normals,uv,colors)
		foot_faces.append_array(vertices.slice(start,vertices.size()))
	var finite: bool=true; var outward: bool=true; var minimum_area: float=INF; var maximum_radius: float=0.0
	var incidences: Dictionary={}
	for offset: int in range(0,vertices.size(),3):
		var a: Vector3=vertices[offset]; var b: Vector3=vertices[offset+1]; var c: Vector3=vertices[offset+2]
		var cross: Vector3=(c-a).cross(b-a); minimum_area=minf(minimum_area,cross.length()*.5)
		for k: int in range(3):
			var index: int=offset+k; var p: Vector3=vertices[index]
			finite=finite and p.is_finite() and normals[index].is_finite() and uv[index].is_finite() and is_equal_approx(normals[index].length(),1.0)
			outward=outward and cross.dot(normals[index])>0.0
			maximum_radius=maxf(maximum_radius,Vector2(p.x-CENTER.x,p.z-CENTER.z).length())
			var from: String=var_to_bytes(vertices[index]).hex_encode(); var to: String=var_to_bytes(vertices[offset+(k+1)%3]).hex_encode()
			var key: String=from+":"+to if from<to else to+":"+from
			if not incidences.has(key): incidences[key]=[0,0]
			incidences[key][0]+=1; incidences[key][1]+=1 if from<to else -1
	var closed: bool=true
	for edge: Array in incidences.values(): closed=closed and edge[0]==2 and edge[1]==0
	var burial: Dictionary=_foot_burial()
	geometry_report={"passed":finite and outward and minimum_area>.00000001 and closed and disk and buried and burial.passed and maximum_radius<=3.4,"triangles":vertices.size()/3,"corners":vertices.size(),"finite_unit_channels":finite,"outward_winding":outward,"minimum_triangle_area_m2":minimum_area,"closed_directed_edges":closed,"stem_64_point_disk_covered":disk,"native_stem_sha256":STEM_SHA,"native_foot_samples":native_foot_rows,"buried_footprint":burial,"maximum_xz_radius_m":maximum_radius,"profiles_y_radius":profiles,"ring_xz_offsets":centers,"clearance_design":"Rear/NE irregular ledge; lower X rings compressed and shifted east to leave the existing west camera-turn corridor clear; 3.4m envelope is an authoring bound, native nearby-body tests remain required.","morphology_source":"Existing world._rock_point, fixed seed2.31; native radial outline; compact stem collar and irregular rounded shoulders, no RNG draws."}
	if not geometry_report.passed: return null
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_COLOR]=colors
	var mesh: ArrayMesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface: SurfaceTool=SurfaceTool.new(); surface.create_from(mesh,0); surface.generate_tangents()
	var committed: ArrayMesh=surface.commit()
	geometry_report["positions_commit_exact"]=committed!=null and committed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array()==vertices.to_byte_array()
	geometry_report.passed=geometry_report.passed and geometry_report.positions_commit_exact and NativeReader.mesh_record(committed).eligible
	return committed if geometry_report.passed else null

func _emit(a: Vector3,b: Vector3,c: Vector3,cap: bool,vertices: PackedVector3Array,normals: PackedVector3Array,uv: PackedVector2Array,colors: PackedColorArray) -> void:
	var normal: Vector3=(c-a).cross(b-a).normalized()
	var center: Vector3=(a+b+c)/3.0
	var expected: Vector3=Vector3(0,1 if center.y>1.99 else -1,0) if cap else Vector3(center.x-CENTER.x,0,center.z-CENTER.z)
	if not cap or normal.dot(expected)<0.0:
		var swap: Vector3=b; b=c; c=swap; normal=-normal
	for p: Vector3 in [a,b,c]:
		vertices.append(p); normals.append(normal); colors.append(Color.WHITE)
		uv.append(Vector2(p.x,p.z) if cap else Vector2(atan2(p.x-CENTER.x,p.z-CENTER.z)*1.25,p.y))

func _foot_burial() -> Dictionary:
	var minimum: float=INF; var maximum_area_error: float=0.0; var covered: bool=true; var witnesses: int=0
	for offset: int in range(0,foot_faces.size(),3):
		var bottom: PackedVector3Array=foot_faces.slice(offset,offset+3)
		var polygon: PackedVector2Array=_xz_polygon(bottom)
		var plane: Plane=Plane(bottom[0],bottom[1],bottom[2])
		var expected: float=_area(polygon); var actual: float=0.0
		for soil_offset: int in range(0,soil_faces.size(),3):
			var native: PackedVector3Array=soil_faces.slice(soil_offset,soil_offset+3)
			var soil_plane: Plane=Plane(native[0],native[1],native[2])
			if absf(soil_plane.normal.y)<.000001: continue
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(_scaled_polygon(polygon,128.0),_scaled_polygon(_xz_polygon(native),128.0)):
				clipped=_scaled_polygon(clipped,1.0/128.0)
				actual+=_area(clipped)
				for p: Vector2 in clipped:
					var depth: float=_plane_y(soil_plane,p)-_plane_y(plane,p); minimum=minf(minimum,depth); witnesses+=1
		var error: float=absf(actual-expected); maximum_area_error=maxf(maximum_area_error,error)
		covered=covered and error<=maxf(.000001,expected*.00001)
	return {"passed":covered and witnesses>0 and minimum>=.015,"native_clip_witnesses":witnesses,"projected_area_coverage_exact_within_declared_limit":covered,"maximum_area_error_m2":maximum_area_error,"minimum_complete_footprint_burial_m":minimum,"required_burial_m":.015,"scope":"Native soil/bottom triangle intersections; affine height difference checked at every clipped polygon vertex."}

func _xz_polygon(points: PackedVector3Array) -> PackedVector2Array:
	var result: PackedVector2Array=PackedVector2Array()
	for p: Vector3 in points: result.append(Vector2(p.x-CENTER.x,p.z-CENTER.z))
	return result
func _scaled_polygon(polygon: PackedVector2Array,scale: float) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p: Vector2 in polygon: result.append(p*scale)
	return result
func _area(polygon: PackedVector2Array) -> float:
	if polygon.size()<3: return 0.0
	var total: float=0.0
	var origin: Vector2=polygon[0]
	for i: int in range(1,polygon.size()-1):
		var ax: float=float(polygon[i].x)-float(origin.x)
		var ay: float=float(polygon[i].y)-float(origin.y)
		var bx: float=float(polygon[i+1].x)-float(origin.x)
		var by: float=float(polygon[i+1].y)-float(origin.y)
		total+=ax*by-ay*bx
	return absf(total)*.5
func _plane_y(plane: Plane,p: Vector2) -> float:
	var x: float=float(p.x)+float(CENTER.x)
	var z: float=float(p.y)+float(CENTER.z)
	return (plane.d-plane.normal.x*x-plane.normal.z*z)/plane.normal.y

func _nearby_tree_contacts() -> Dictionary:
	var rows: Array=[]
	var passed: bool=true
	var vertices: PackedVector3Array=support_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for body: Node in game.world.find_children("*","StaticBody3D",true,false):
		if not body.has_meta("forest_root"): continue
		for node: Node in body.get_children():
			if not node is CollisionShape3D or not node.shape is CylinderShape3D: continue
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=node.shape; query.transform=node.global_transform; query.collision_mask=1; query.exclude=[body.get_rid()]; query.margin=0.0
			var hits: Array[Dictionary]=game.world.get_world_3d().direct_space_state.intersect_shape(query,256)
			var selected: bool=false
			for hit: Dictionary in hits: selected=selected or hit.collider==support_body
			var crossings: Array[float]=[]; var ambiguous: bool=false
			# Concave shapes are hollow: also refuse complete cylinder containment.
			if support_mesh.get_aabb().has_point(node.global_position):
				var direction: Vector3=Vector3(1,.137,.331).normalized()
				for offset: int in range(0,vertices.size(),3):
					var hit: Variant=Geometry3D.ray_intersects_triangle(node.global_position,direction,vertices[offset],vertices[offset+1],vertices[offset+2])
					if hit==null: continue
					for edge: int in range(3): ambiguous=ambiguous or (hit as Vector3).distance_to(Geometry3D.get_closest_point_to_segment(hit,vertices[offset+edge],vertices[offset+(edge+1)%3]))<.00001
					crossings.append((hit as Vector3).distance_to(node.global_position))
			var inside: bool=crossings.size()%2==1
			var one: bool=not selected and not inside and not ambiguous and hits.size()<256
			passed=passed and one
			rows.append({"path":str(game.world.get_path_to(node)),"shell_overlap":selected,"center_inside":inside,"ambiguous_ray":ambiguous,"crossings":crossings,"hits":hits.size(),"passed":one})
	return {"passed":passed and rows.size()==23,"shapes":rows,"scope":"All20 current middle-layer cylinders plus3 admitted outer-trunk cylinders; exact native shell queries and center-containment guard. Other visual-only scenery and passage widths are separate."}

func _contacts_and_cameras() -> void:
	var helper: RefCounted=Contacts.new(); var player: Variant=game.player
	var observer: Contacts.AfterPlayer=Contacts.AfterPlayer.new(); observer.process_physics_priority=player.process_physics_priority+100; game.add_child(observer)
	var body_list: Array[StaticBody3D]=[support_body]
	var ground: Dictionary=helper._ground_at(player,Vector3(19.6,0,-18.5),body_list)
	var before: int=int(player.entrance48_step_readback().started)
	player.visible=true; player.enabled=true; player.set_process(true); player.set_physics_process(true); player._visual.process_mode=player_before.visual_mode; player.get_camera().make_current()
	if _check("Supported east approach outside water with actual player",not ground.is_empty()):
		player.teleport_safe(ground.position+Vector3.UP*.008,PI*.5); await helper._frames(observer,25)
		var valid: bool=player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position) and not player.get("_require_release") and not helper._capsule_overlap(player,support_body).selected
		_check("Settled collision-free native approach pose",valid)
		if valid:
			contact_report["approach"]=await helper._phase(player,support_body,CENTER,observer,Vector3.LEFT,90)
			contact_report["slide"]=await helper._phase(player,support_body,CENTER,observer,Vector3(-.3,0,1).normalized(),36)
			contact_report["retreat"]=await helper._phase(player,support_body,CENTER,observer,Vector3.RIGHT,30)
			var a: Dictionary=contact_report.approach; var s: Dictionary=contact_report.slide; var r: Dictionary=contact_report.retreat
			contact_report["passed"]=a.valid and a.body_contact_ticks>0 and a.obstructed_contact_ticks>0 and s.valid and s.displacement[2]>.25 and r.valid and r.displacement[0]>.5
			_check("Actual obstruction, slide/retreat and every-tick no overlap",contact_report.passed)
		helper._release(); await helper._frames(observer,15)
		for pitch: float in [-60.0,-10.0,15.0]:
			for yaw: float in [PI*.5,-PI*.5]:
				player._camera_pitch=deg_to_rad(pitch); player.teleport_safe(ground.position+Vector3.UP*.008,yaw); await helper._frames(observer,35)
				var camera: Camera3D=player.get_camera(); var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
				query.shape=player._spring_arm.shape; query.transform=camera.global_transform; query.collision_mask=1; query.exclude=[player.get_rid()]; query.margin=.001
				var hits: Array[Dictionary]=player.get_world_3d().direct_space_state.intersect_shape(query,32)
				var selected: int=0
				for hit: Dictionary in hits:
					if hit.collider==support_body: selected+=1
				var one: bool=hits.size()<32 and selected==0 and camera.global_position.is_finite() and player.is_on_floor() and player._valid_safe_position(player.global_position)
				camera_report.append({"passed":one,"pitch_degrees":pitch,"yaw":yaw,"player":str(player.global_position),"camera":str(camera.global_position),"candidate_lens_hits":selected,"all_query_hits":hits.size(),"query_saturated":hits.size()==32})
		_check("Six actual spring-arm camera poses clear the new support",camera_report.size()==6 and camera_report.all(func(row: Dictionary) -> bool: return bool(row.passed)))
	var feet: Vector3=Vector3(CENTER.x,2.026,CENTER.z)
	var raw: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.08,feet-Vector3.UP*.12,1,[player.get_rid()]))
	contact_report["unsafe_support"]={"raw_candidate_hit":not raw.is_empty() and raw.collider==support_body,"ordinary_refused":player._support_at(feet,.12).is_empty(),"float_refused":not player._safe_hover_support(feet),"safe_refused":not player._valid_safe_position(feet)}
	_check("Actual support cap is refused by ordinary/Float/safe support",contact_report.unsafe_support.raw_candidate_hit and contact_report.unsafe_support.ordinary_refused and contact_report.unsafe_support.float_refused and contact_report.unsafe_support.safe_refused)
	contact_report["step_started_delta"]=int(player.entrance48_step_readback().started)-before
	_check("Support remains unsteppable",contact_report.step_started_delta==0)
	helper._release(); player.release_controls(); player._camera_pitch=player_before.pitch; player.teleport_safe(player_before.pose,player_before.yaw); await helper._frames(observer,30)
	contact_report["endpoint_restored"]=helper._xz(player.global_position,player_before.pose)<.03 and absf(player.global_position.y-player_before.pose.y)<.06 and player.is_on_floor() and player.state=="Grounded" and player._valid_safe_position(player.global_position)
	_check("Player endpoint/native controller settings restored",contact_report.endpoint_restored and helper._settings(player)==player_before.settings)
	observer.queue_free(); await process_frame

func _support_pair(label: String) -> void:
	var night: bool=label.ends_with("night")
	var camera: Vector3=Vector3(18.7,1.30,-13.6); var target: Vector3=Vector3(16.5,2.0,-18.5)
	if label.begins_with("side"): camera=Vector3(12.9,1.35,-16.6); target=Vector3(16.5,1.35,-18.5)
	if label.begins_with("wide"): camera=Vector3(18.5,2.20,-10.5); target=Vector3(16.5,2.5,-18.5)
	game.review_camera.global_position=camera; game.review_camera.fov=55.0 if not label.begins_with("wide") else 65.0; game.review_camera.look_at(target); game.review_camera.make_current()
	controller.set_foreground(true); game.world.set_environment_foreground(true); controller.set_inspection_state("night" if night else "calm"); game.set_appearance("night" if night else "day","sunny")
	await create_timer(4.0).timeout
	controller.set_foreground(false); game.world.set_environment_foreground(false); await _frames(3)
	_materials_held(); var material_state: String=_materials_held(); var held: String=_context(); var held_all_bindings: String=_sha(var_to_bytes(_support_binding_rows()))
	var pair_ok: bool=true
	for selected: bool in [false,true]:
		trial.visible=selected
		await _frames(10); await RenderingServer.frame_post_draw
		var image: Image=root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
		var file: String=label+("-after.png" if selected else "-before.png")
		var one: bool=image.get_size()==Vector2i(960,960) and image.save_png(output.path_join(file))==OK and _context()==held and _sha(var_to_bytes(_support_binding_rows()))==held_all_bindings and _materials_held()==material_state and _original_bindings()==original_bindings and _native_sources()==original_native
		views.append({"file":file,"label":file.trim_suffix(".png"),"passed":one,"width":image.get_width(),"height":image.get_height(),"png_sha256":FileAccess.get_sha256(output.path_join(file)),"rgba_sha256":_sha(image.get_data())})
		pair_ok=pair_ok and one
	_check(label+": matched held lighting/materials/owners and native arrays",pair_ok)
	pairs.append({"label":label,"passed":pair_ok,"context_held":pair_ok,"camera":str(camera),"target":str(target),"night":game.world.night_amount,"scope":"Fixed diagnostic camera; candidate collision retained during both frozen stills, player processing disabled."})
	trial.show()

func _support_binding_rows(qualify_live_sky: bool=false) -> Dictionary:
	var rows: Dictionary={}
	for node: Node in game.world.find_children("*","Node3D",true,false):
		if (trial!=null and (node==trial or trial.is_ancestor_of(node))) or (soil_probe!=null and (node==soil_probe or soil_probe.is_ancestor_of(node))): continue
		if node is MeshInstance3D: rows[str(node.get_path())]=[node.get_instance_id(),node.global_transform,node.mesh.get_instance_id() if node.mesh!=null else 0,node.material_override.get_instance_id() if node.material_override!=null else 0,node.material_overlay,node.visible]
		elif node is MultiMeshInstance3D: rows[str(node.get_path())]=[node.get_instance_id(),node.global_transform,node.multimesh.get_instance_id() if node.multimesh!=null else 0,node.multimesh.buffer if node.multimesh!=null else null,node.material_override.get_instance_id() if node.material_override!=null else 0,node.multimesh.mesh.get_instance_id() if node.multimesh!=null and node.multimesh.mesh!=null else 0,node.visible]
		elif node is CollisionShape3D: rows[str(node.get_path())]=[node.get_instance_id(),node.global_transform,node.disabled,node.shape.get_instance_id(),node.get_parent().collision_layer,node.get_parent().collision_mask]
		if qualify_live_sky and rows.has(str(node.get_path())):
			var relative: String=str(game.world.get_path_to(node))
			var sky: bool=relative in ["Moon","ProposedSky36/QuietSkyStars","ProposedSky36/VisibleSun"]
			var prefix: String="ProposedSky36/FictionalConstellations/ConstellationLink"
			if relative.begins_with(prefix):
				var suffix: String=relative.trim_prefix(prefix)
				sky=sky or (suffix.is_valid_int() and int(suffix)>=0 and int(suffix)<48)
			if sky:
				# Known live sky follows camera and time/appearance. Keep identities,
				# meshes/materials and buffers exact; full poses/visibility held per pair.
				rows[str(node.get_path())][1]="live sky pose"
				rows[str(node.get_path())][-1]="live sky visibility"
	return rows
func _original_bindings() -> String: return _sha(var_to_bytes(_support_binding_rows(true)))
func _native_sources() -> String:
	var rows: Array=[]
	for node: MeshInstance3D in source_meshes: rows.append([str(game.world.get_path_to(node)),NativeReader.mesh_record(node.mesh),RenderingServer.mesh_get_surface(node.mesh.get_rid(),0)])
	return _sha(var_to_bytes(rows))
func _materials_held() -> String:
	var rows: Array=[]; var omit: Array[String]=[]
	var materials: Dictionary=_materials_and_aliases().materials; var ids: Array=materials.keys(); ids.sort()
	for id: int in ids:
		var material: Material=materials[id]
		var stored: Variant=owner.call("_stored",material,omit)
		rows.append([id,stored,_parameters(material) if material is ShaderMaterial else {}])
	return _sha(var_to_bytes(rows))
func _material_art() -> String:
	var material: ShaderMaterial=game.world._materials.stone_light
	var rows: Dictionary=_parameters(material)
	for key: String in rows.keys():
		if key.begins_with("env_") or key in ["night_amount","rain_amount","base_color","accent_color"]: rows.erase(key)
	return _sha(var_to_bytes([material.get_instance_id(),material.shader.code,rows]))

func _finish() -> void:
	if is_instance_valid(game):
		if is_instance_valid(trial): trial.queue_free()
		if is_instance_valid(soil_probe): soil_probe.queue_free()
		await process_frame; await physics_frame
		removed=not is_instance_valid(trial) and not is_instance_valid(soil_probe); trial=null; soil_probe=null
		if not appearance_before.is_empty():
			controller.set_foreground(true); game.world.set_environment_foreground(true); controller.set_inspection_state(appearance_before[2]); game.set_appearance(appearance_before[0],appearance_before[1]); await _frames(4)
			controller.set_foreground(appearance_before[3]); game.world.set_environment_foreground(appearance_before[4])
		if not player_before.is_empty():
			game.player.enabled=player_before.enabled; game.player.set_physics_process(player_before.physics); game.player.set_process(player_before.process); game.player.visible=player_before.visible; game.player._visual.process_mode=player_before.visual_mode
			if is_instance_valid(player_before.camera): player_before.camera.make_current()
		if not original_bindings.is_empty():
			var now: Dictionary=_support_binding_rows(true)
			var changed: Array=[]
			for path: String in binding_rows_before:
				if not now.has(path) or var_to_bytes(now[path])!=var_to_bytes(binding_rows_before[path]): changed.append({"path":path,"before":str(binding_rows_before[path]),"after":str(now.get(path))})
			restoration_diagnostic={"removed":removed,"bindings":_original_bindings()==original_bindings,"native":_native_sources()==original_native,"material_art":_material_art()==original_material_art,"rng":game.world._rng.state==original_rng,"changed_binding_rows":changed}
			_check("Actual node removal; original native owners/material/RNG restored",removed and restoration_diagnostic.bindings and restoration_diagnostic.native and restoration_diagnostic.material_art and restoration_diagnostic.rng)
	_check("Six paired daylight/night views complete",views.size()==12 and pairs.size()==6)
	var failed: int=0
	for row: Dictionary in checks:
		if not row.passed: failed+=1
	if failed==0 and removed and support_mesh!=null:
		var file: String=output.path_join("closest-home-support.res")
		var before: Dictionary=NativeReader.mesh_record(support_mesh)
		var native: PackedByteArray=var_to_bytes(RenderingServer.mesh_get_surface(support_mesh.get_rid(),0))
		var saved: bool=ResourceSaver.save(support_mesh,file,ResourceSaver.FLAG_COMPRESS)==OK
		var loaded: ArrayMesh=ResourceLoader.load(file,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh if saved else null
		var exact: bool=loaded!=null and var_to_bytes(NativeReader.mesh_record(loaded))==var_to_bytes(before) and var_to_bytes(RenderingServer.mesh_get_surface(loaded.get_rid(),0))==native
		artifact={"passed":saved and exact,"file":"closest-home-support.res","bytes":FileAccess.get_file_as_bytes(file).size() if saved else 0,"sha256":FileAccess.get_sha256(file) if saved else "","native_record":NativeReader.mesh_record(loaded) if loaded!=null else {},"native_surface_sha256":_sha(native),"all13_config_buffers_reload_exact":exact,"material_free":loaded!=null and loaded.surface_get_material(0)==null}
		_check("Saved material-free resource freshly reloads all13/config/native buffers exact",artifact.passed)
		if not artifact.passed: failed+=1
	var pins: Dictionary={}
	for file: String in [get_script().resource_path,"res://tests/paving_surface.gd","res://tests/forest_trunk_contacts.gd","res://scripts/closest_home_foundation.gd","res://assets/world/closest-home-support.res","res://scripts/cap57_prebuilt.gd","res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"]: pins[file]=FileAccess.get_sha256(file)
	var report: Dictionary={"schema":"mush-closest-home-foundation/1","passed":failed==0,"failed":failed,"checks":checks,"geometry":geometry_report,"contacts":contact_report,"camera":camera_report,"views":views,"pairs":pairs,"actual_added_node_removal":removed,"restoration_diagnostic":restoration_diagnostic,"artifact":artifact,"pins":pins,"closest_home_only":true,"other_home_support_open":true,"added_draw_nodes":1,"added_static_bodies":1,"added_shapes":1,"candidate_nodes":4,"collision_kind":"Exact native render-triangle concave surface, layer1/mask2, unsafe_support=true","binding_scope":"All original mesh/material/physics identities held; exact poses/visibility except51known camera-following sky rows across phases. Every pose and visibility held exactly within each frozen pair.","main_logic_suppressed_until_shutdown":true,"perframe_work_added":false,"art_approved":false,"motion_approved":false,"performance_measured":false,"scope":"Actual startup cached foundation with native deterministic authoring parity; fixed-camera pairs and finite player contact/camera samples. Existing house geometry/materials/elevations and original bodies retained."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var file: FileAccess=FileAccess.open(output.path_join("house-support.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"  ")); file.flush(); file.close()
	print("HOUSE_SUPPORT_COMPLETE ",JSON.stringify({"passed":failed==0,"failed":failed,"checks":checks.size(),"views":views.size()}))
	if is_instance_valid(game): game._quit_clean(0 if failed==0 else 2)
	else: quit(2)

func _native_faces(mesh: Mesh) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	if mesh==null or mesh.get_surface_count()==0: return result
	for surface: int in range(mesh.get_surface_count()):
		if mesh is ArrayMesh:
			if (mesh as ArrayMesh).surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return PackedVector3Array()
		elif mesh is CylinderMesh:
			# Exact native CylinderMesh prototype is triangle-only. PrimitiveMesh
			# does not bind ArrayMesh.surface_get_primitive_type in GDScript.
			if mesh.get_surface_count()!=1: return PackedVector3Array()
		else: return PackedVector3Array()
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.size()!=Mesh.ARRAY_MAX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array): return PackedVector3Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX]!=null:
			if not (arrays[Mesh.ARRAY_INDEX] is PackedInt32Array): return PackedVector3Array()
			indices=arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		if count==0 or count%3!=0: return PackedVector3Array()
		for corner: int in range(count):
			var index: int = indices[corner] if not indices.is_empty() else corner
			if index<0 or index>=vertices.size() or not vertices[index].is_finite(): return PackedVector3Array()
			result.append(vertices[index])
	return result
