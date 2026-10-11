extends RefCounted
## Two opaque distant soil meshes and a native stream-mesh successor.
## Visual terrain extends beyond the existing recovery bounds, without new physics.
const PROOF := "res://baked/forest-backdrop-proof.json"
const PROOF_SHA := "1a93a125e97e1a708847e67dd543c1788f8319eae30091e93aeb242eb28a0ed2"
const SOIL_PATH := "BatchedStaticWorld/Static_-9223371995029174788_0_0"
var root: Node3D
var stream: MeshInstance3D
var original_water: Mesh
var water: ArrayMesh
var original_cull: float
var report: Dictionary={"passed":false,"new_colliders":0,"new_draw_nodes":2,"added_triangles":3216,"runtime_geometry_generation":false,"perframe_work":false,"playable_bounds_changed":false,"visual_terrain_extended":true,"art_approved":false,"performance_measured":false}

func install(world: Node3D) -> Dictionary:
	if world==null or world.global_transform!=Transform3D.IDENTITY or FileAccess.get_sha256(PROOF)!=PROOF_SHA or world.get_node_or_null("ForestBackdrop")!=null: return report
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROOF))
	var soil:=world.get_node_or_null(SOIL_PATH) as MeshInstance3D
	if soil==null or soil.global_transform!=Transform3D.IDENTITY or _sha(var_to_bytes(soil.mesh.surface_get_arrays(0)))!=proof.soil_arrays_sha256: return report
	stream=world.get_node_or_null(proof.water_source_path) as MeshInstance3D
	if stream==null or stream.material_override!=world._water_material or stream.mesh.get_surface_count()!=1 or stream.global_transform!=Transform3D(Basis.IDENTITY,Vector3(9,-.16,1)): return report
	original_water=stream.mesh; original_cull=stream.extra_cull_margin
	if _sha(var_to_bytes(original_water.surface_get_arrays(0)))!=proof.water_source_arrays_sha256: return report
	var meshes: Array[ArrayMesh]=[]
	for row: Dictionary in proof.files:
		var path: String="res://baked/"+str(row.file)
		if FileAccess.get_sha256(path)!=row.sha256: return report
		var mesh: ArrayMesh=load(path) as ArrayMesh
		if mesh==null or mesh.get_surface_count()!=1 or mesh.get_script()!=null or mesh.surface_get_material(0)!=null or _sha(var_to_bytes(mesh.surface_get_arrays(0)))!=row.arrays_sha256: return report
		meshes.append(mesh)
	if meshes.size()!=3: return report
	water=meshes[2]
	root=Node3D.new(); root.name="ForestBackdrop"; world.add_child(root)
	for index: int in range(2):
		var node:=MeshInstance3D.new(); node.name="West" if index==0 else "East"
		node.mesh=meshes[index]; node.material_override=soil.material_override
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(node)
	if not reinstall(): restore_original(); return report
	report.merge({"passed":true,"installed":true,"asset_bytes":49715,"native_render_seam_points":202,"shared_soil_material":true,"retained_water_node_and_material":true,"water_original_prefix_exact":true,"water_cull_margin_m":stream.extra_cull_margin,"approximation":"Opaque coarse distant ground and continued existing straight stream outside player bounds; no new playable area or terrain physics."},true)
	return report

func restore_original() -> bool:
	if not is_instance_valid(stream) or original_water==null or not is_instance_valid(root): return false
	root.hide(); stream.mesh=original_water; stream.extra_cull_margin=original_cull
	return stream.mesh==original_water and not root.visible

func reinstall() -> bool:
	if not is_instance_valid(stream) or water==null or not is_instance_valid(root): return false
	root.show(); stream.mesh=water
	# Both wave terms are bounded by12+8mm. Mesh rest-Y alone has no height.
	stream.extra_cull_margin=maxf(original_cull,.020001)
	return stream.mesh==water and root.visible

static func _sha(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes); return h.finish().hex_encode()
