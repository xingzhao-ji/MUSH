extends RefCounted
## Three height groups reuse the existing meshes, materials and private seed.
## Four reachable stems receive cheap static collision. Crowns stay visual.
## reference_layout reproduces the preceding constructor for paired verification.

static func build(world: Node3D, reference_layout: bool=false) -> Dictionary:
	var foliage_mesh: Mesh
	var foliage_material: Material
	var smallest := 2147483647
	for entry: Dictionary in world._m37_canopies:
		var source: MultiMeshInstance3D = entry.node
		if source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var mesh: Mesh = source.multimesh.mesh
		var count: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		if count < smallest:
			smallest = count
			foliage_mesh = mesh
			foliage_material = source.material_override
	assert(foliage_mesh != null and foliage_material != null)
	var root := Node3D.new()
	root.name = "ForestMiddleReference" if reference_layout else "ForestMiddleLayer"
	world.add_child(root)
	var random := RandomNumberGenerator.new()
	random.seed = 530052
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var positions: Array[Vector3] = []
	var solid_count: int = 0
	var collision_shell_bound: float = 0.0
	# These radii are within the existing 22–32 m visual forest ring.
	for index: int in range(22):
		var angle: float = lerpf(-1.48,1.48,float(index)/21.0)
		var radius: float = random.randf_range(24.0,28.0)
		positions.append(Vector3(sin(angle)*radius,-.35,-cos(angle)*radius+2.0))
	for side: int in [-1,1]:
		for index: int in range(4):
			positions.append(Vector3(float(side)*random.randf_range(23.0,25.0),-.35,float(index)*5.0))
	for index: int in range(positions.size()):
		var origin: Vector3 = positions[index]
		# Keep the existing stream corridor open; this one seeded root was in water.
		if not reference_layout and origin.x>7.3 and origin.x<10.7: origin.x=11.4
		var tier: int = index % 7
		var height_scale: float = 1.0 if reference_layout else (.34 if tier in [0,3,5] else (.55 if tier in [1,6] else 1.0))
		var spread_scale: float = .85 if height_scale < .4 else (.94 if height_scale < .8 else 1.0)
		var crown_y: float = .78 if height_scale < .4 else (.90 if height_scale < .8 else 1.0)
		var height: float = random.randf_range(8.4,12.8)*height_scale
		var radius: float = random.randf_range(.24,.46)*sqrt(height_scale)
		var bend := Vector3(random.randf_range(-1.6,1.6),0,random.randf_range(-1.2,1.2))*height_scale
		var points: Array[Vector3] = []
		for segment: int in range(6):
			var t: float = float(segment)/5.0
			points.append(origin+Vector3(0,height*t,0)+bend*t*t)
		if not reference_layout and absf(origin.x)<20.4 and origin.z> -20.4 and origin.z<26.4:
			var body:=StaticBody3D.new(); body.name="TreeSolid_%d"%index
			body.collision_layer=1; body.collision_mask=2
			body.set_meta("unsafe_support",true); body.set_meta("forest_root",origin)
			root.add_child(body)
			for segment: int in range(5):
				var pose:=_segment(points[segment],points[segment+1],radius*lerpf(1.0,.34,float(segment)/5.0))
				var cylinder_shape:=CylinderShape3D.new()
				cylinder_shape.height=pose.basis.y.length(); cylinder_shape.radius=pose.basis.x.length()
				collision_shell_bound=maxf(collision_shell_bound,cylinder_shape.radius*(1.0-.88*cos(PI/8.0)))
				var contact:=CollisionShape3D.new(); contact.shape=cylinder_shape
				contact.transform=Transform3D(pose.basis.orthonormalized(),pose.origin); body.add_child(contact)
			solid_count+=1
		for segment: int in range(5):
			trunks.append(_segment(points[segment],points[segment+1],radius*lerpf(1.0,.34,float(segment)/5.0)))
		for branch: int in range(3):
			var angle: float = random.randf_range(0,TAU)
			var start: Vector3 = points[3+branch%2]
			var finish: Vector3 = start+Vector3(sin(angle)*random.randf_range(2.0,3.4),random.randf_range(.8,2.1),cos(angle)*random.randf_range(2.0,3.4))*Vector3(spread_scale,height_scale,spread_scale)
			trunks.append(_segment(start,finish,radius*.30))
			crowns.append(Transform3D(Basis.from_euler(Vector3(0,angle,.1)).scaled(Vector3(2.2*spread_scale,1.5*crown_y,2.0*spread_scale)),finish))
		for cluster: int in range(4):
			var angle: float = float(cluster)*TAU/4.0+random.randf_range(-.3,.3)
			var scale := Vector3(random.randf_range(2.2,3.0),random.randf_range(1.4,2.0),random.randf_range(2.0,2.8))*Vector3(spread_scale,crown_y,spread_scale)
			var position: Vector3 = points[5]+Vector3(sin(angle)*1.6,-float(cluster%2)*1.5,cos(angle)*1.6)*Vector3(spread_scale,height_scale,spread_scale)
			crowns.append(Transform3D(Basis.from_euler(Vector3(0,angle,0)).scaled(scale),position))
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.top_radius = .88
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var draws: int = _install_chunks(root,"BentTrunks",cylinder,world._materials.bark,trunks,0.0)
	draws += _install_chunks(root,"LayeredCanopies",foliage_mesh,foliage_material,crowns,.03)
	return {"schema":"mush-forest-middle-layer/1","trees":positions.size(),"trunk_segments":trunks.size(),"canopy_clusters":crowns.size(),"additional_draw_nodes":draws,"spatial_chunk_size_m":8.0,"seed":530052,"new_colliders":solid_count,"new_collision_shapes":solid_count*5,"maximum_trunk_collision_shell_m":collision_shell_bound,"height_cohorts":[0,0,30] if reference_layout else [13,9,8],"height_scales":[1.0] if reference_layout else [.34,.55,1.0],"stream_root_shifted":0 if reference_layout else 1,"reference_layout":reference_layout,"new_playable_area":false,"shared_existing_wind_material":true,"art_approved":false}

static func _segment(start: Vector3,finish: Vector3,radius: float) -> Transform3D:
	var direction: Vector3 = finish-start
	var rotation := Basis(Quaternion(Vector3.UP,direction.normalized()))
	return Transform3D(rotation*Basis.from_scale(Vector3(radius,direction.length(),radius)),(start+finish)*.5)

static func _install(parent: Node3D,label: String,mesh: Mesh,material: Material,poses: Array[Transform3D],margin: float) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for index: int in range(poses.size()): instances.set_instance_transform(index,poses[index])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = margin
	parent.add_child(node)

static func _install_chunks(parent: Node3D,label: String,mesh: Mesh,material: Material,poses: Array[Transform3D],margin: float) -> int:
	var chunks: Dictionary = {}
	for pose: Transform3D in poses:
		var key := Vector2i(int(floor(pose.origin.x/8.0)),int(floor(pose.origin.z/8.0)))
		if not chunks.has(key): chunks[key] = []
		chunks[key].append(pose)
	for key: Vector2i in chunks:
		var values: Array[Transform3D] = []
		values.assign(chunks[key])
		_install(parent,label+"_%d_%d"%[key.x,key.y],mesh,material,values,margin)
	return chunks.size()
