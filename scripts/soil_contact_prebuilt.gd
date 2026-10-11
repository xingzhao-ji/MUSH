extends RefCounted
## Prebuilt native soil, stream bank and main/left foundation; one startup swap.
## The retained bank node is hidden so the same triangles are not drawn twice.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT = "res://baked/soil-contact.res"
const ARTIFACT_SHA = "faa61d68cdc48caf9896de3a60fdd4904eae9e7d19974d337fe0e172e6df365e"
const SOIL_PATH = "BatchedStaticWorld/Static_-9223371995029174788_0_0"
const OLD_ARRAYS = "d36f994042e1ac0b98d3095ba548bf0456fb0ecfea2f08420c1f2ce7a13bb088"
const NEW_ARRAYS = "d7db053201c76ef0fc9e0de38e936d84b90b6a7ebc9aa4280c5bb295346b7bbc"
const BANK_ARRAYS = "ff02525521107d893e90a60f66344ed20ebb79a07cd2ccab2e396578f8f44212"

static func install(world: Node3D, artifact: String = ARTIFACT) -> Dictionary:
	var report := {"passed":false,"installed":false,"added_triangles_vs_original_soil":432,"foundation_triangles":424,"bank_triangles":8,"new_draw_nodes":0,"new_colliders":0,"perframe_work":false,"performance_measured":false}
	if world == null or FileAccess.get_sha256(artifact) != ARTIFACT_SHA: return report
	var soil := world.get_node_or_null(SOIL_PATH) as MeshInstance3D
	var bank := world.get_node_or_null("StreamBankClosure") as MeshInstance3D
	var merged := ResourceLoader.load(artifact,"ArrayMesh") as ArrayMesh
	if soil == null or bank == null or not soil.mesh is ArrayMesh or not bank.mesh is ArrayMesh or merged == null: return report
	if soil.transform != Transform3D.IDENTITY or bank.transform != Transform3D.IDENTITY or not soil.visible or not bank.visible or soil.material_override != world._materials["soil"] or bank.material_override != soil.material_override: return report
	if not soil.material_override is ShaderMaterial or soil.get_active_material(0) != soil.material_override or bank.get_active_material(0) != soil.material_override: return report
	var original := soil.mesh as ArrayMesh
	var before := NativeReader.mesh_record(original)
	var after := NativeReader.mesh_record(merged)
	var bank_record := NativeReader.mesh_record(bank.mesh as ArrayMesh)
	if not before.eligible or not after.eligible or not bank_record.eligible or before.corners != 31953 or after.corners != 33249 or bank_record.corners != 24: return report
	if before.arrays_sha256 != OLD_ARRAYS or after.arrays_sha256 != NEW_ARRAYS or bank_record.arrays_sha256 != BANK_ARRAYS or before.configuration != after.configuration or before.aabb_sha256 != after.aabb_sha256: return report
	if NativeReader.node_record(soil) != NativeReader.node_record(bank): return report
	soil.mesh = merged
	bank.visible = false
	if soil.mesh != merged or bank.visible:
		soil.mesh = original
		bank.visible = true
		return report
	report.merge({"passed":true,"installed":true,"artifact_sha256":ARTIFACT_SHA,"original_arrays_sha256":OLD_ARRAYS,"merged_arrays_sha256":NEW_ARRAYS,"original_bounds_retained":true,"shared_soil_material":true,"bank_node_retained_hidden":true,"growable_right_room_included":false},true)
	return report
