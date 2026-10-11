extends RefCounted
## Cached rock support for the closest elevated home; no per-frame processing.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT := "res://assets/world/closest-home-support.res"
const ARTIFACT_SHA := "e28c423d198ea90b80478c1902ce8f05a3215dfca308644a93376991cfe31e2c"
const ARTIFACT_BYTES := 6771
const NATIVE_SURFACE_SHA := "2fc214efe2246c2951afd4210cd2cb539a6451e6e00fd24c324f4258e03098e3"
const HOME := "ForestBeyondTheClearing/@Node3D@3758"
const STUB := HOME + "/@MeshInstance3D@3759"
const STEM := "BatchedStaticWorld/Static_-9223371995264055848_2_-3"
const STEM_SHA := "824354dfc27ceed7c6b40e701ae3f2135b745352dbfaaf07f8fb1fd94173d0e4"
const ROOT := "ClosestHomeFoundation"

static func install(world: Node3D, artifact_path: String = ARTIFACT) -> Dictionary:
	var report: Dictionary = {"schema":"mush-closest-home-support-runtime/1", "passed":false, "installed":false, "artifact":artifact_path, "artifact_sha256":ARTIFACT_SHA, "root":ROOT, "render_geometry_generated":false, "perframe_work":false, "art_approved":false, "performance_measured":false, "other_distant_homes_fixed":false}
	if world == null or not world.is_inside_tree() or world.global_transform != Transform3D.IDENTITY or world.has_node(ROOT):
		return _fail(report, "Ready identity world and absent owned root required")
	if not _source_admitted(world):
		return _fail(report, "Exact original home, stub/material binding and native stem packet required")
	var palettes: Variant = world.get("_materials")
	if not palettes is Dictionary:
		return _fail(report, "Existing material palette required")
	var material: ShaderMaterial = palettes.get("stone_light") as ShaderMaterial
	if material == null:
		return _fail(report, "Existing shared stone_light required")
	var file: FileAccess = FileAccess.open(artifact_path, FileAccess.READ)
	if file == null:
		return _fail(report, "Pinned artifact missing")
	var bytes: int = file.get_length()
	file.close()
	if bytes != ARTIFACT_BYTES or FileAccess.get_sha256(artifact_path) != ARTIFACT_SHA:
		return _fail(report, "Artifact bytes/hash mismatch")
	var mesh: ArrayMesh = ResourceLoader.load(artifact_path, "ArrayMesh") as ArrayMesh
	var record: Dictionary = NativeReader.mesh_record(mesh)
	if not record.get("eligible", false) or record.get("corners", 0) != 480:
		return _fail(report, "Material-free unindexed native 480-corner artifact required")
	if _sha(var_to_bytes(RenderingServer.mesh_get_surface(mesh.get_rid(), 0))) != NATIVE_SURFACE_SHA:
		return _fail(report, "Loaded native surface buffers mismatch")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var root: Node3D = Node3D.new()
	root.name = ROOT
	var render: MeshInstance3D = MeshInstance3D.new()
	render.name = "StoneLedge"
	render.mesh = mesh
	render.material_override = material
	root.add_child(render)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "StoneContact"
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("unsafe_support", true)
	root.add_child(body)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	var contact: CollisionShape3D = CollisionShape3D.new()
	contact.name = "Surface"
	contact.shape = shape
	body.add_child(contact)
	world.add_child(root)
	var exact: bool = root.get_parent() == world and root.global_transform == Transform3D.IDENTITY and render.global_transform == Transform3D.IDENTITY and body.global_transform == Transform3D.IDENTITY and contact.global_transform == Transform3D.IDENTITY
	exact = exact and render.mesh == mesh and render.material_override == material and render.material_overlay == null and mesh.surface_get_material(0) == null
	exact = exact and not contact.disabled and contact.shape == shape and body.collision_layer == 1 and body.collision_mask == 2 and body.get_meta("unsafe_support", false) and not body.has_meta("entrance48_step_surface")
	exact = exact and shape.get_faces().to_byte_array() == vertices.to_byte_array() and _source_admitted(world)
	if not exact:
		root.free()
		report["owned_root_removed"] = not world.has_node(ROOT)
		return _fail(report, "Post-install ownership/contact readback refused; own subtree removed")
	report.merge({"passed":true, "installed":true, "native_surface_verified":true, "native_surface_sha256":NATIVE_SURFACE_SHA, "native_arrays_sha256":record.arrays_sha256, "original_stem_packet_sha256":STEM_SHA, "material":"stone_light", "material_instance_id":material.get_instance_id(), "added_draw_nodes":1, "added_static_bodies":1, "added_shapes":1, "added_nodes":4, "triangles":160, "corners":480, "encoded_resource_bytes":bytes, "contact_faces_native_exact":true, "collision_kind":"Concave triangle shell copied from cached native render vertices"}, true)
	return report

static func _source_admitted(world: Node3D) -> bool:
	var home: Node3D = world.get_node_or_null(HOME) as Node3D
	var stub: MeshInstance3D = world.get_node_or_null(STUB) as MeshInstance3D
	var stem: MeshInstance3D = world.get_node_or_null(STEM) as MeshInstance3D
	if home == null or stub == null or stem == null or not stem.mesh is ArrayMesh:
		return false
	if home.global_transform != Transform3D(Basis.IDENTITY, Vector3(16.5, 2.0, -18.5)) or stub.global_transform != Transform3D(Basis.IDENTITY, Vector3(16.5, 2.9, -18.5)) or stem.global_transform != Transform3D.IDENTITY:
		return false
	if stub.mesh != null or stub.material_override == null or stem.material_override != stub.material_override or stem.material_overlay != null or stem.mesh.get_surface_count() != 1 or (stem.mesh as ArrayMesh).surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return false
	var arrays: Array = stem.mesh.surface_get_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or arrays[Mesh.ARRAY_INDEX] != null:
		return false
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size() == 3072 and _sha(vertices.slice(0, 1536).to_byte_array()) == STEM_SHA

static func _sha(bytes: PackedByteArray) -> String:
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

static func _fail(report: Dictionary, reason: String) -> Dictionary:
	report["failure"] = reason
	return report
