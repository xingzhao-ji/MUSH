extends RefCounted
## Three native cylinder segments close the confirmed pass-through outer trunk.
## Rendering and the ordinary spring-arm controller are unchanged.
const BATCH := "BatchedStaticWorld/Static_-9223371994861402623_1_-2"
const TREE := "OldGrowthForest/@Node3D@2808"
const PACKET_SHA := "83ee726ad28f038147f016f3e2c54b821a32e8b5e56201d7ef2d149ba86ffe66"

static func install(world: Node3D) -> bool:
	var mesh_owner := world.get_node_or_null(BATCH) as MeshInstance3D
	var tree := world.get_node_or_null(TREE) as Node3D
	if mesh_owner == null or tree == null or world.has_node("OuterTreeContact"):
		return false
	if mesh_owner.mesh == null or mesh_owner.global_transform != Transform3D.IDENTITY or mesh_owner.material_override != world._materials.bark:
		return false
	if not tree.global_position.is_equal_approx(Vector3(15.965662, 0, -15.513497)) or not tree.find_children("*", "StaticBody3D", true, false).is_empty():
		return false
	if mesh_owner.mesh.get_surface_count() != 1:
		return false
	var arrays: Array = mesh_owner.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() < 216 or (arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty()):
		return false
	var packet: PackedVector3Array = vertices.slice(0, 216)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(packet.to_byte_array())
	if digest.finish().hex_encode() != PACKET_SHA:
		return false
	var body := StaticBody3D.new()
	body.name = "OuterTreeContact"
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("unsafe_support", true)
	body.set_meta("forest_root", tree.global_position)
	for segment: int in range(3):
		# Reuse the existing forest's smooth cylinder contact approximation.
		# The two native 12-sided rings define each segment's axis and extent.
		var bottom := Vector3.ZERO
		var top := Vector3.ZERO
		for side: int in range(12):
			bottom += packet[segment * 72 + side * 6] / 12.0
			top += packet[segment * 72 + side * 6 + 4] / 12.0
		var axis: Vector3 = top - bottom
		var pose := Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), (bottom + top) * .5)
		var inverse: Transform3D = pose.affine_inverse()
		var radius: float = 0.0
		var half_height: float = 0.0
		for point: Vector3 in packet.slice(segment * 72, (segment + 1) * 72):
			var local: Vector3 = inverse * point
			radius = maxf(radius, Vector2(local.x, local.z).length())
			half_height = maxf(half_height, absf(local.y))
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = half_height * 2.0
		var contact := CollisionShape3D.new()
		contact.shape = shape
		contact.transform = pose
		body.add_child(contact)
	world.add_child(body)
	return true
