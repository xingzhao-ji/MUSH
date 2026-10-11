extends RefCounted
## One cached offline mesh; native instancing and shared GPU wind are retained.
const ARTIFACT := "res://baked/ground-flower.res"
const ARTIFACT_SHA := "d16b4985a881a5dc8e9ede662702514e3c1f5add6a9828f076031f06b48ffb5e"
const PROOF := "res://baked/ground-flower-proof.json"
const PROOF_SHA := "cf9f42a3cd17e5d1232f1fd05f8880694efcd18d775eb9f465825be371d4e4aa"
const FACTORY := "res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"
const FACTORY_SHA := "a758c4d69479fd3ea445efb2fac1a4bd3f0b25ff337b8a76faed0b1516d6afc1"
var candidate: ArrayMesh
var original: ArrayMesh
var nodes: Array[MultiMeshInstance3D] = []
var installed := false
var _template: Dictionary = {}

func install(world: Node3D) -> Dictionary:
	var report := {"passed":false,"installed":false,"new_draw_nodes":0,"new_triangles":0,"new_textures":0,"new_colliders":0,"perframe_work":false}
	if installed or not nodes.is_empty() or world == null or not world.is_inside_tree(): return report
	candidate = load_candidate()
	if candidate == null or FileAccess.get_sha256(FACTORY) != FACTORY_SHA: return report
	var factory: Node3D = load(FACTORY).new()
	var old: ArrayMesh = factory._make_flower_mesh()
	factory.free()
	var old_channels := var_to_bytes(old.surface_get_arrays(0))
	var old_bounds := old.get_aabb()
	if not old_bounds.grow(.000001).encloses(candidate.get_aabb()): return report
	var selected: Array[MultiMeshInstance3D] = []
	var count := 0
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		var mesh: Mesh = node.multimesh.mesh if node.multimesh != null else null
		if mesh is ArrayMesh and mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) == 282 and mesh.surface_get_format(0) == old.surface_get_format(0) and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES and mesh.get_aabb() == old_bounds and var_to_bytes(mesh.surface_get_arrays(0)) == old_channels:
			if node.has_meta("mobile_environment_cull") or mesh.surface_get_material(0) != null: return report
			if original != null and mesh != original: return report
			original = mesh
			selected.append(node)
			count += node.multimesh.instance_count
	if selected.size() != 119 or count != 1430: return report
	nodes = selected
	var before := _instance_state()
	for node: MultiMeshInstance3D in nodes: node.multimesh.mesh = candidate
	if before != _instance_state():
		restore_original()
		return report
	installed = true
	report.merge({"passed":true,"installed":true,"nodes":nodes.size(),"instances":count,"triangles_per_instance":94,"asset_bytes":9613,"artifact_sha256":ARTIFACT_SHA,"pre_environment_scan":true,"instance_state_exact":true,"original_retained":true},true)
	return report

func load_candidate(path: String = ARTIFACT, expected_sha: String = ARTIFACT_SHA) -> ArrayMesh:
	# Explicit arguments support isolated refusal tests without editing resources.
	if expected_sha != ARTIFACT_SHA or FileAccess.get_sha256(path) != expected_sha or FileAccess.get_sha256(PROOF) != PROOF_SHA: return null
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
	if not proof is Dictionary or not proof.get("passed",false) or proof.get("sha256","") != ARTIFACT_SHA or proof.get("triangles",0) != 94 or proof.get("root_corners",0) != 6 or proof.get("channels",[]).size() != Mesh.ARRAY_MAX: return null
	var mesh := load(path) as ArrayMesh
	if mesh == null or mesh.get_script() != null or mesh.get_surface_count() != 1 or mesh.surface_get_material(0) != null or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return null
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() != 282: return null
	var root_corners := 0
	for vertex: Vector3 in vertices:
		if not vertex.is_finite() or vertex.y < 0.0: return null
		if vertex.y == 0.0: root_corners += 1
	if root_corners != 6: return null
	var encoded: Array[PackedByteArray] = []
	var hashes: Array[String] = []
	for index: int in range(Mesh.ARRAY_MAX):
		var bytes := var_to_bytes(arrays[index])
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		var digest := hash.finish().hex_encode()
		if digest != proof.channels[index]: return null
		encoded.append(bytes); hashes.append(digest)
	_template = {"family":"flower","constructor":"pinned_ground_flower","source_line":0,"root_y":0.0,"root_corners":root_corners,"vertex_count":vertices.size(),"root_plane_exact":true,"channel_bytes":encoded,"channels_sha256":hashes,"format":mesh.surface_get_format(0),"primitive":mesh.surface_get_primitive_type(0),"aabb_bytes":var_to_bytes(mesh.get_aabb())}
	return mesh

func environment_template() -> Dictionary:
	return _template.duplicate() if installed else {}

func restore_original() -> bool:
	if original == null or nodes.is_empty(): return false
	for node: MultiMeshInstance3D in nodes:
		if not is_instance_valid(node) or node.multimesh == null or node.multimesh.mesh != candidate: return false
	for node: MultiMeshInstance3D in nodes: node.multimesh.mesh = original
	installed = false
	return true

func reinstall() -> bool:
	if candidate == null or nodes.is_empty(): return false
	for node: MultiMeshInstance3D in nodes:
		if not is_instance_valid(node) or node.multimesh == null or node.multimesh.mesh != original: return false
	for node: MultiMeshInstance3D in nodes: node.multimesh.mesh = candidate
	installed = true
	return true

func _instance_state() -> PackedByteArray:
	var rows: Array = []
	for node: MultiMeshInstance3D in nodes:
		rows.append([node.get_instance_id(),node.multimesh.get_instance_id(),node.multimesh.buffer,node.multimesh.instance_count,node.multimesh.visible_instance_count,node.transform,node.global_transform,node.material_override,node.cast_shadow,node.extra_cull_margin,node.custom_aabb])
	return var_to_bytes(rows)
