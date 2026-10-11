extends RefCounted
## Static floor join meshes, authored and checked before export.
## Existing wood materials, other batch geometry and all collision stay in place.
const NativeReader = preload("res://scripts/cap57_prebuilt.gd")
const ARTIFACT = "res://baked/floor-seams.res"
const ARTIFACT_SHA = "9938115251c64982d3e8fa1e3c857a001778a914b3d74d0b88197e6fb702cc27"
const PATHS = ["BatchedStaticWorld/Static_-9223371995230501415_0_0", "BatchedStaticWorld/Static_-9223371995230501415_0_-1"]
const COUNTS = [23064, 360]
const OLD_ARRAYS = ["e24e8f1958574a052779107f9c3d9653214481ad33b9b3360675988250e6308b", "d7ed0f2a3935ba93cf4e821c2914b5fe539c3cc9c3708627af5640d37c9fd383"]
const NEW_ARRAYS = ["9d917ad01a57f7b0d8642599ee87158420e7411eb79a4412bc69cedd1b8a422b", "2c0d22ab04580a6fa245109bed7a723a8161d282bfb5b98978949484b0e55838"]

static func install(world: Node3D, artifact: String = ARTIFACT) -> Dictionary:
	var report := {"passed":false, "installed":false, "added_triangles":0, "added_draws":0, "collision_changed":false, "perframe_work":false}
	if world == null or FileAccess.get_sha256(artifact) != ARTIFACT_SHA:
		return report
	var library := ResourceLoader.load(artifact, "MeshLibrary") as MeshLibrary
	if library == null or library.get_item_list() != PackedInt32Array([0, 1]):
		return report
	var selected: Array[MeshInstance3D] = []
	var originals: Array[ArrayMesh] = []
	var candidates: Array[ArrayMesh] = []
	# Validate both targets before either live mesh reference changes.
	for index in range(2):
		var node := world.get_node_or_null(PATHS[index]) as MeshInstance3D
		var candidate := library.get_item_mesh(index) as ArrayMesh
		if node == null or not node.mesh is ArrayMesh or candidate == null or library.get_item_name(index) != PATHS[index] or node.transform != Transform3D.IDENTITY or node.material_override != world._materials["wood"]:
			return report
		var original := node.mesh as ArrayMesh
		var before := NativeReader.mesh_record(original)
		var after := NativeReader.mesh_record(candidate)
		if not before.eligible or not after.eligible or before.corners != COUNTS[index] or after.corners != COUNTS[index] or before.arrays_sha256 != OLD_ARRAYS[index] or after.arrays_sha256 != NEW_ARRAYS[index] or before.configuration != after.configuration:
			return report
		selected.append(node)
		originals.append(original)
		candidates.append(candidate)
	for index in range(2):
		selected[index].mesh = candidates[index]
	for index in range(2):
		if selected[index].mesh != candidates[index]:
			for rollback in range(2): selected[rollback].mesh = originals[rollback]
			return report
	return {"passed":true, "installed":true, "artifact_sha256":ARTIFACT_SHA, "selected_corners":684, "top_y":0.6006, "seam_depth":0.005, "added_triangles":0, "added_draws":0, "collision_changed":false, "perframe_work":false, "performance_measured":false}
