extends Node
## Diagnostic-only visual bark triangles on a query-only layer.
const LAYER: int=1<<29
const REGION:=AABB(Vector3(12,-1,-23),Vector3(12,6,15))
var game: Node3D
var proxies: Node3D
var inventory: Array[Dictionary]=[]
var rows: Array[Dictionary]=[]
var originals: String
var enabled: bool=false
var unique_faces: Dictionary={}

func configure(value: Node3D) -> void:
	game=value; process_priority=500
	originals=_bodies()
	proxies=Node3D.new(); proxies.name="DiagnosticBarkQueries"; game.world.add_child(proxies)
	var bark: Material=game.world._materials.bark
	for node: Node in game.world.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		if not node is MeshInstance3D and not node is MultiMeshInstance3D: continue
		if node.material_override!=bark: continue
		var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
		if mesh==null: continue
		if node is MeshInstance3D: _packet(node,mesh,node.global_transform,-1)
		else:
			for i: int in range(node.multimesh.instance_count): _packet(node,mesh,node.global_transform*node.multimesh.get_instance_transform(i),i)
	unique_faces.clear()

func _packet(node: GeometryInstance3D,mesh: Mesh,pose: Transform3D,index: int) -> void:
	var bound: AABB=pose*mesh.get_aabb()
	if not bound.intersects(REGION): return
	var key: int=mesh.get_instance_id()
	if not unique_faces.has(key): unique_faces[key]=_render_faces(mesh)
	var local: PackedVector3Array=unique_faces[key]
	var faces:=PackedVector3Array()
	for i: int in range(0,local.size(),3):
		var a: Vector3=pose*local[i]; var b: Vector3=pose*local[i+1]; var c: Vector3=pose*local[i+2]
		var box:=AABB(a,Vector3.ZERO).expand(b).expand(c).grow(.00001)
		if not box.intersects(REGION): continue
		faces.append(a); faces.append(b); faces.append(c)
	if faces.is_empty(): return
	var body:=StaticBody3D.new(); body.name="BarkPacket_%d"%inventory.size(); body.collision_layer=LAYER; body.collision_mask=0
	body.set_meta("source",str(node.get_path())); body.set_meta("instance",index)
	var shape:=ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision=true
	var contact:=CollisionShape3D.new(); contact.shape=shape; body.add_child(contact); proxies.add_child(body)
	inventory.append({"source":str(node.get_path()),"instance":index,"pose":str(pose),"triangles":faces.size()/3,"world_bounds":str(bound),"query_body":str(body.get_path())})

func _process(_delta: float) -> void:
	if not enabled: return
	var player: Node3D=game.player
	if player.global_position.x<12 or player.global_position.z> -10: return
	var camera: Camera3D=player.get_camera()
	var row: Dictionary={"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"player":_v(player.global_position),"camera":_v(camera.global_position),"pivot":_v(player._camera_pivot.global_position),"yaw":player.camera_yaw,"pitch":player._camera_pitch,"arm":player._spring_arm.get_hit_length(),"requested_arm":player._spring_arm.spring_length,"camera_fade":player._camera_fade,"state":player.state,"rays":{}}
	for bone: String in ["head","body"]:
		var index: int=player._skeleton.find_bone(bone)
		var target: Vector3=player._skeleton.global_transform*player._skeleton.get_bone_global_pose(index).origin
		row.rays[bone]={"target":_v(target),"visual":_ray(camera.global_position,target,LAYER),"physics":_ray(camera.global_position,target,player.CAMERA_MASK),"screen":str(camera.unproject_position(target)),"behind":camera.is_position_behind(target)}
	row.rays["pivot"]={"visual":_ray(camera.global_position,player._camera_pivot.global_position,LAYER),"physics":_ray(camera.global_position,player._camera_pivot.global_position,player.CAMERA_MASK)}
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=player._spring_arm.shape; query.transform=camera.global_transform; query.collision_mask=LAYER; query.margin=.001
	var hits: Array[Dictionary]=game.world.get_world_3d().direct_space_state.intersect_shape(query,32)
	row["visual_sphere_overlaps"]=[]; row["visual_sphere_saturated"]=hits.size()==32
	for hit: Dictionary in hits: row.visual_sphere_overlaps.append({"source":hit.collider.get_meta("source"),"instance":hit.collider.get_meta("instance")})
	rows.append(row)

func finish() -> Dictionary:
	enabled=false; proxies.free()
	return {"diagnostic_integrity":not inventory.is_empty() and not rows.is_empty() and _bodies()==originals,"inventory":inventory,"rows":rows,"original_bodies_restored":_bodies()==originals,"scope":"Exact native static bark triangles clipped conservatively to east-tree route; diagnostic-only proxies never enter gameplay/camera masks. Bone-center rays are not a full pixel-visibility or full-frustum proof."}

func _ray(from: Vector3,to: Vector3,mask: int) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(from,to,mask,[game.player.get_rid()]); q.hit_back_faces=true; q.hit_from_inside=true
	var hit: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return {}
	return {"source":str(hit.collider.get_meta("source",hit.collider.get_path())),"instance":hit.collider.get_meta("instance",-1),"point":_v(hit.position),"normal":_v(hit.normal),"shape":hit.shape,"distance":from.distance_to(hit.position)}

func _bodies() -> String:
	var rows_native: Array=[]
	for node: Node in game.world.find_children("*","CollisionShape3D",true,false):
		if is_instance_valid(proxies) and proxies.is_ancestor_of(node): continue
		rows_native.append([node.get_instance_id(),node.global_transform,node.disabled,node.shape.get_instance_id(),node.get_parent().get_instance_id(),node.get_parent().collision_layer,node.get_parent().collision_mask])
	var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(var_to_bytes(rows_native)); return h.finish().hex_encode()
func _v(value: Vector3) -> Array: return [value.x,value.y,value.z]

func _render_faces(mesh: Mesh) -> PackedVector3Array:
	var faces:=PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty(): faces.append_array(vertices)
		else:
			for i: int in indices: faces.append(vertices[i])
	return faces
