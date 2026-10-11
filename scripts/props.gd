class_name ClearingProps
extends RefCounted

static func material(color: Color, roughness: float = 0.8, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 20
	shape.rings = 10
	m.mesh = shape
	m.material_override = mat
	m.position = pos
	m.scale = size
	parent.add_child(m)
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	m.mesh = shape
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 24
	m.mesh = shape
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

static func furniture(kind: String, style: String) -> Node3D:
	var root := Node3D.new()
	var wood := material(Color("896044") if style.ends_with("honey") else Color("526b58"))
	var cloth := material(Color("d3a571") if style.ends_with("honey") else Color("88956a"))
	var dark := material(Color("4d3c2b"))
	match kind:
		"chair":
			box(root, Vector3(0,.35,0), Vector3(.56,.12,.54),wood)
			sphere(root, Vector3(0,.44,0),Vector3(.55,.16,.50),cloth)
			box(root,Vector3(0,.68,-.23),Vector3(.55,.43,.09),wood)
			for x in [-.21,.21]:
				for z in [-.19,.19]:
					cylinder(root,Vector3(x,.17,z),.038,.34,wood)
		"table":
			cylinder(root,Vector3(0,.65,0),.46,.12,wood)
			cylinder(root,Vector3(0,.31,0),.095,.62,wood)
			for x in [-.25,.25]:
				box(root,Vector3(x,.06,0),Vector3(.35,.1,.16),wood)
			cylinder(root,Vector3(.15,.74,0),.095,.09,cloth)
		"lamp":
			cylinder(root,Vector3(0,.045,0),.18,.09,dark)
			cylinder(root,Vector3(0,.48,0),.036,.9,wood)
			cylinder(root,Vector3(0,1.02,0),.26,.34,cloth,.16)
			var light := OmniLight3D.new()
			light.position.y=.98
			light.light_color=Color("ffc986")
			light.light_energy=.65
			light.omni_range=2.8
			root.add_child(light)
		"plant":
			cylinder(root,Vector3(0,.18,0),.18,.36,cloth,.24)
			var leaves := material(Color("638858"))
			for i in range(7):
				var a: float = i*TAU/7
				var leaf := sphere(root,Vector3(sin(a)*.14,.5+float(i%2)*.12,cos(a)*.14),Vector3(.16,.54,.09),leaves)
				leaf.rotation.z=sin(a)*.48
	var body := StaticBody3D.new()
	body.collision_layer=16
	body.collision_mask=2
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	var h: float = .90 if kind=="chair" else .75 if kind=="table" else 1.2 if kind=="lamp" else .8
	var w: float = .92 if kind=="table" else .6 if kind=="chair" else .5
	s.size=Vector3(w,h,w)
	c.shape=s
	c.position.y=h/2
	body.add_child(c)
	root.add_child(body)
	return root

static func plant(bloom: float, type: String = "moonbell") -> Node3D:
	var root := Node3D.new()
	var stem := material(Color("5d8352"))
	var petals := material(Color("adc6ff") if type=="moonbell" else Color("f7cb6b"),.55,.7*bloom)
	cylinder(root,Vector3(0,.18,0),.025,.36,stem)
	for i in range(3):
		var a: float=i*TAU/3
		var leaf:=sphere(root,Vector3(sin(a)*.12,.14,cos(a)*.12),Vector3(.23,.055,.11),stem)
		leaf.rotation.y=a
	if bloom<.05:
		sphere(root,Vector3(0,.39,0),Vector3(.14,.2,.14),petals)
	else:
		for i in range(6):
			var a: float = i*TAU/6
			var p := sphere(root,Vector3(sin(a)*.15*bloom,.40,cos(a)*.15*bloom),Vector3(.18,.07+.09*(1-bloom),.23),petals)
			p.rotation.y=a
		sphere(root,Vector3(0,.43,0),Vector3(.12,.1,.12),material(Color("ffe4a2"),.6,bloom))
	return root
