extends "res://lineage/scenery-revision-18/proposals/night-readability-01/night-world.gd"

# Detached render substitution AFTER the complete unchanged original pipeline.
const _REVIEW19_GENERATOR = preload("res://lineage/scenery-revision-19/proposals/clump-mesh-02/clump-mesh-library.gd")
const _REVIEW19_LABELS: Array[String] = ["cushion_a", "cushion_b", "broadleaf_a", "broadleaf_b"]
var _review19_contexts: Dictionary = {}
var _review19_context_used: Dictionary = {}
var _review19_original_entries: Array[Dictionary] = []
var _review19_original_library: Dictionary = {}
var _review19_stones: Array[Dictionary] = []
var _review19_meshes: Dictionary = {}
var _review19_samples: Dictionary = {}
var _review19_rows: Array[Dictionary] = []
var _review19_chunks: Array[Dictionary] = []
var _review19_errors: Array[String] = []
var _review19_original_rooted_records: Array[Dictionary] = []
var _review19_original_rooted_stats: Dictionary = {}
var _review19_original_rooted_status: Dictionary = {}
var _review19_rng_after_super: int = 0
var _review19_flush_count: int = 0
var _review19_applied: bool = false
var _review19_status: String = "not_started"
var _review19_counters: Dictionary = {}
var _review19_by_label: Dictionary = {}
var _review19_by_category: Dictionary = {}
var _review19_fallback_reasons: Dictionary = {}

func _ready() -> void:
	super._ready()
	_review19_rng_after_super = _rng.state
	_apply_review19_clumps()

func _foreground_understory_choice(id: String, old_mesh: ArrayMesh, source_origin: Vector3, point: Vector3, turn: Vector3, size_value: Vector3, reach: float) -> Dictionary:
	var result: Dictionary = super._foreground_understory_choice(id, old_mesh, source_origin, point, turn, size_value, reach)
	var actual_mesh: ArrayMesh = result["mesh"] as ArrayMesh
	var label: String = _review19_old_label(actual_mesh)
	if not label.is_empty():
		var selected_id: String = result["id"] as String
		var xf: Transform3D = Transform3D(Basis.from_euler(turn).scaled(size_value), point)
		_review19_queue_context(label, selected_id, xf, {"category": "clustered", "source_mode": "original_choice", "origin": point, "turn": turn, "scale": size_value, "reach": reach, "original_attempt_index": -1, "family": result["family"]})
	return result

func _flush_foliage() -> void:
	_review19_flush_count += 1
	if _review19_flush_count == 1:
		_review19_original_library = _foreground_understory_meshes.duplicate()
		_review19_original_rooted_records = _rooted_foreground_group_records.duplicate(true)
		_review19_original_rooted_stats = _rooted_foreground_group_stats.duplicate(true)
		_review19_original_rooted_status = _rooted_foreground_group_load_status.duplicate(true)
		# Static batching later clears original MeshInstance3D meshes. Cache actual
		# local-space stone triangles now, without altering their objects/resources.
		_review19_stones = _rooted_ground_stone_cache()
		for record: Dictionary in _rooted_foreground_group_records:
			if not bool(record["accepted"]):
				continue
			var label: String = record["label"] as String
			if not _REVIEW19_LABELS.has(label):
				continue
			var id: String = record["id"] as String
			var origin: Vector3 = record["origin"] as Vector3
			var turn: Vector3 = record["turn"] as Vector3
			var size_value: Vector3 = record["scale"] as Vector3
			var xf: Transform3D = Transform3D(Basis.from_euler(turn).scaled(size_value), origin)
			_review19_queue_context(label, id, xf, {"category": "rooted", "source_mode": String(_rooted_foreground_group_load_status.get("mode", "unknown")), "origin": origin, "turn": turn, "scale": size_value, "reach": float(record["reach"]), "original_attempt_index": int(record["attempt_index"]), "family": "rooted"})
		for key: String in _foliage_chunks.keys():
			var entry: Dictionary = _foliage_chunks[key] as Dictionary
			var original_mesh: ArrayMesh = entry["mesh"] as ArrayMesh
			var label: String = _review19_old_label(original_mesh)
			if label.is_empty():
				continue
			_review19_original_entries.append({"key": key, "label": label, "id": entry["id"], "mesh": original_mesh, "transforms": (entry["transforms"] as Array).duplicate()})
	else:
		_review19_errors.append("Original foliage flush called more than once")
	super._flush_foliage()

func _review19_old_label(mesh: ArrayMesh) -> String:
	for label: String in _REVIEW19_LABELS:
		if _foreground_understory_meshes.get(label) == mesh:
			return label
	return ""

func _review19_context_key(label: String, id: String, xf: Transform3D) -> String:
	return label + "|" + id + "|" + var_to_bytes(xf).hex_encode()

func _review19_queue_context(label: String, id: String, xf: Transform3D, context: Dictionary) -> void:
	var key: String = _review19_context_key(label, id, xf)
	if not _review19_contexts.has(key):
		_review19_contexts[key] = []
	(_review19_contexts[key] as Array).append(context)

func _review19_take_context(label: String, id: String, xf: Transform3D) -> Dictionary:
	var key: String = _review19_context_key(label, id, xf)
	var queue: Array = _review19_contexts.get(key, []) as Array
	var used: int = int(_review19_context_used.get(key, 0))
	if used >= queue.size():
		return {}
	_review19_context_used[key] = used + 1
	return queue[used] as Dictionary

func _review19_prepare_meshes() -> bool:
	var generator: RefCounted = _REVIEW19_GENERATOR.new() as RefCounted
	var generated: Variant = generator.call("build_meshes")
	if not generated is Dictionary or (generated as Dictionary).size() != 4:
		_review19_errors.append("Generator must return exactly four resources")
		return false
	_review19_meshes = generated as Dictionary
	for label: String in _REVIEW19_LABELS:
		var mesh: ArrayMesh = _review19_meshes.get(label) as ArrayMesh
		if mesh == null:
			_review19_errors.append("Missing new mesh: " + label)
			return false
		var issue: String = _review19_mesh_quality_issue(mesh)
		if not issue.is_empty():
			_review19_errors.append(label + ": " + issue)
			return false
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var guard: PackedVector3Array = PackedVector3Array()
		var unique: Dictionary = {}
		for vertex: Vector3 in vertices:
			if not unique.has(vertex):
				unique[vertex] = true
				guard.append(vertex)
		mesh.set_meta("review09_understory_guard_vertices", guard)
		mesh.set_meta("review09_understory_label", label)
		var old_mesh: ArrayMesh = _review19_original_library[label] as ArrayMesh
		mesh.set_meta("review09_understory_shadow", bool(old_mesh.get_meta("review09_understory_shadow", false)))
		_review19_samples[label] = _rooted_group_samples(mesh)
	return true

func _review19_mesh_quality_issue(mesh: ArrayMesh) -> String:
	if mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return "Expected one triangle surface"
	var arrays: Array = mesh.surface_get_arrays(0)
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return "Required typed channels missing"
	if arrays[Mesh.ARRAY_INDEX] != null and (not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array or not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty()):
		return "Resolved expanded surface required by original sample helper"
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	if v.is_empty() or v.size() % 3 != 0 or n.size() != v.size() or u.size() != v.size() or c.size() != v.size():
		return "Channel cardinality differs"
	for index: int in range(v.size()):
		if not v[index].is_finite() or not n[index].is_finite() or not u[index].is_finite() or not is_finite(c[index].r) or not is_finite(c[index].g) or not is_finite(c[index].b) or not is_finite(c[index].a):
			return "Nonfinite channel"
		if absf(n[index].length_squared() - 1.0) > 0.002:
			return "Nonunit normal"
	for index: int in range(0, v.size(), 3):
		var face: Vector3 = (v[index + 2] - v[index]).cross(v[index + 1] - v[index])
		if face.length_squared() <= 0.000000000000000001:
			return "Degenerate face"
		for corner: int in range(3):
			if face.dot(n[index + corner]) <= 0.0:
				return "CW face opposes corner normal"
	return ""

func _review19_relevant_stones(origin: Vector3, reach: float) -> Array[Dictionary]:
	# Same source stone query admits10um AABB tolerance; reach gate admits1um.
	# Excluding only boxes beyond their sum preserves every possible source hit.
	var radius: float = reach + 0.000011
	var result: Array[Dictionary] = []
	for stone: Dictionary in _review19_stones:
		var bounds: AABB = stone["bounds"] as AABB
		if bounds.end.x < origin.x - radius or bounds.position.x > origin.x + radius or bounds.end.z < origin.z - radius or bounds.position.z > origin.z + radius:
			continue
		result.append(stone)
	return result

func _review19_guard_row(row: Dictionary) -> String:
	var context: Dictionary = row["context"] as Dictionary
	var xf: Transform3D = row["transform"] as Transform3D
	var point: Vector3 = context["origin"] as Vector3
	var turn: Vector3 = context["turn"] as Vector3
	var size_value: Vector3 = context["scale"] as Vector3
	var reach: float = float(context["reach"])
	var reconstructed: Transform3D = Transform3D(Basis.from_euler(turn).scaled(size_value), point)
	if var_to_bytes(reconstructed) != var_to_bytes(xf):
		return "context_pose_mismatch"
	var label: String = row["label"] as String
	var mesh: ArrayMesh = _review19_meshes[label] as ArrayMesh
	var reason: String = _foreground_understory_guard(mesh, point, turn, size_value, reach)
	if not reason.is_empty():
		return "vertex/" + reason
	var support: Dictionary = _rooted_ground_support(xf.origin)
	if support.is_empty():
		return "missing_root_support"
	if xf.origin.y < float(support["height"]) - 0.002:
		return "root_soil_penetration"
	var samples: PackedVector3Array = _review19_samples[label] as PackedVector3Array
	var relevant: Array[Dictionary] = _review19_relevant_stones(xf.origin, reach)
	return _rooted_group_guard(xf.origin, xf.basis, reach, samples, relevant)

func _review19_build_multimesh(mesh: Mesh, transforms: Array, source: MultiMesh) -> MultiMesh:
	var result: MultiMesh = MultiMesh.new()
	result.transform_format = source.transform_format
	result.use_colors = source.use_colors
	result.use_custom_data = source.use_custom_data
	result.mesh = mesh
	result.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		result.set_instance_transform(index, transforms[index] as Transform3D)
	if bool(get_meta("portable_export", false)) or source.has_meta("portable_authored_instance_transforms"):
		result.set_meta("portable_authored_instance_transforms", transforms.duplicate())
	return result

func _review19_increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

func _apply_review19_clumps() -> void:
	if _review19_applied:
		return
	_review19_applied = true
	_review19_status = "preparing"
	if _review19_flush_count != 1 or _review19_original_entries.is_empty() or not _review19_errors.is_empty():
		_review19_errors.append("Exactly one captured original nonempty foliage plan required")
		_review19_status = "integrity_failed"
		return
	var foliage: Node3D = get_node_or_null("SpatiallyChunkedFoliage") as Node3D
	if foliage == null or not _review19_prepare_meshes():
		_review19_errors.append("Original foliage/new resource preparation unavailable")
		_review19_status = "integrity_failed"
		return
	# Resolve all original nodes/context BEFORE any rendering state is changed.
	for entry: Dictionary in _review19_original_entries:
		var key: String = entry["key"] as String
		var label: String = entry["label"] as String
		var id: String = entry["id"] as String
		var instance: MultiMeshInstance3D = foliage.get_node_or_null(NodePath(key)) as MultiMeshInstance3D
		var transforms: Array = entry["transforms"] as Array
		if instance == null or instance.multimesh == null:
			_review19_errors.append("Original MultiMesh node missing: " + key)
			continue
		var original_mm: MultiMesh = instance.multimesh
		if original_mm.mesh != entry["mesh"] or original_mm.instance_count != transforms.size() or instance.material_override != _materials[id] or original_mm.transform_format != MultiMesh.TRANSFORM_3D or original_mm.use_colors or original_mm.use_custom_data:
			_review19_errors.append("Original MultiMesh resource/format/material differs: " + key)
			continue
		var chunk: Dictionary = {"key": key, "label": label, "id": id, "instance": instance, "original_multimesh": original_mm, "original_path": String(instance.get_path()), "original_count": transforms.size(), "original_cast_shadow": instance.cast_shadow, "row_sequences": [], "accepted_old_indices": [], "fallback_old_indices": [], "replacement_path": "", "fallback_path": ""}
		for index: int in range(transforms.size()):
			var xf: Transform3D = transforms[index] as Transform3D
			var context: Dictionary = _review19_take_context(label, id, xf)
			if context.is_empty():
				_review19_errors.append("Original caller context missing: %s/%d" % [key, index])
				continue
			var row: Dictionary = {"sequence": _review19_rows.size(), "chunk": key, "old_index": index, "label": label, "id": id, "category": context["category"], "source_mode": context["source_mode"], "caller_reach": context["reach"], "transform": xf, "context": context, "substituted": false, "reason": "not_evaluated", "render_path": "", "render_index": -1}
			(chunk["row_sequences"] as Array).append(_review19_rows.size())
			_review19_rows.append(row)
		_review19_chunks.append(chunk)
	for key: String in _review19_contexts.keys():
		if int(_review19_context_used.get(key, 0)) != (_review19_contexts[key] as Array).size():
			_review19_errors.append("Unused original caller context: " + key)
	if not _review19_errors.is_empty():
		_review19_status = "integrity_failed"
		return
	_review19_counters = {"attempted": _review19_rows.size(), "substituted": 0, "fallback": 0, "target_chunks": _review19_chunks.size(), "fully_replaced_chunks": 0, "mixed_chunks": 0, "unchanged_fallback_chunks": 0, "added_multimesh_nodes": 0, "shadow_poses_before": 0, "shadow_poses_after": 0}
	for row: Dictionary in _review19_rows:
		var reason: String = _review19_guard_row(row)
		var accepted: bool = reason.is_empty()
		row["substituted"] = accepted
		row["reason"] = "accepted" if accepted else reason
		var key: String = "substituted" if accepted else "fallback"
		_review19_increment(_review19_counters, key)
		var label: String = row["label"] as String
		var category: String = row["category"] as String
		if not _review19_by_label.has(label):
			_review19_by_label[label] = {"attempted": 0, "substituted": 0, "fallback": 0}
		if not _review19_by_category.has(category):
			_review19_by_category[category] = {"attempted": 0, "substituted": 0, "fallback": 0}
		_review19_increment(_review19_by_label[label] as Dictionary, "attempted")
		_review19_increment(_review19_by_label[label] as Dictionary, key)
		_review19_increment(_review19_by_category[category] as Dictionary, "attempted")
		_review19_increment(_review19_by_category[category] as Dictionary, key)
		if not accepted:
			_review19_increment(_review19_fallback_reasons, reason)
	for chunk: Dictionary in _review19_chunks:
		var accepted: Array = []
		var fallback: Array = []
		for sequence: int in chunk["row_sequences"] as Array:
			var row: Dictionary = _review19_rows[sequence]
			var xf: Transform3D = row["transform"] as Transform3D
			if bool(row["substituted"]):
				row["render_index"] = accepted.size()
				accepted.append(xf)
				(chunk["accepted_old_indices"] as Array).append(row["old_index"])
			else:
				row["render_index"] = fallback.size()
				fallback.append(xf)
				(chunk["fallback_old_indices"] as Array).append(row["old_index"])
		var instance: MultiMeshInstance3D = chunk["instance"] as MultiMeshInstance3D
		var original_mm: MultiMesh = chunk["original_multimesh"] as MultiMesh
		var mesh: ArrayMesh = _review19_meshes[chunk["label"]] as ArrayMesh
		if accepted.is_empty():
			chunk["fallback_path"] = String(instance.get_path())
			_review19_increment(_review19_counters, "unchanged_fallback_chunks")
		elif fallback.is_empty():
			# Every pose remains in its original buffer and order; only its mesh swaps.
			instance.multimesh.mesh = mesh
			chunk["replacement_path"] = String(instance.get_path())
			_review19_increment(_review19_counters, "fully_replaced_chunks")
		else:
			var replacement: MultiMeshInstance3D = instance.duplicate() as MultiMeshInstance3D
			replacement.name = String(instance.name) + "_Review19Clump"
			replacement.multimesh = _review19_build_multimesh(mesh, accepted, original_mm)
			foliage.add_child(replacement)
			instance.multimesh = _review19_build_multimesh(original_mm.mesh, fallback, original_mm)
			chunk["replacement_path"] = String(replacement.get_path())
			chunk["fallback_path"] = String(instance.get_path())
			_review19_increment(_review19_counters, "mixed_chunks")
			_review19_increment(_review19_counters, "added_multimesh_nodes")
		if int(chunk["original_cast_shadow"]) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_review19_counters["shadow_poses_before"] = int(_review19_counters["shadow_poses_before"]) + int(chunk["original_count"])
			_review19_counters["shadow_poses_after"] = int(_review19_counters["shadow_poses_after"]) + accepted.size() + fallback.size()
		for sequence: int in chunk["row_sequences"] as Array:
			var row: Dictionary = _review19_rows[sequence]
			row["render_path"] = chunk["replacement_path"] if bool(row["substituted"]) else chunk["fallback_path"]
	_review19_status = "complete"

func _review19_render_groups() -> Array[Dictionary]:
	# Targeted final render groups only; every unaffected chunk keeps its original name.
	var groups: Array[Dictionary] = []
	for chunk: Dictionary in _review19_chunks:
		for substituted: bool in [true, false]:
			var path_key: String = "replacement_path" if substituted else "fallback_path"
			var indices_key: String = "accepted_old_indices" if substituted else "fallback_old_indices"
			var render_path: String = chunk[path_key] as String
			if render_path.is_empty():
				continue
			var old_indices: Array[int] = []
			for old_index: int in chunk[indices_key] as Array:
				old_indices.append(old_index)
			var node: MultiMeshInstance3D = get_node_or_null(NodePath(render_path)) as MultiMeshInstance3D
			groups.append({"node": node, "original_key": chunk["key"], "old_indices": old_indices, "substituted": substituted, "id": chunk["id"], "label": chunk["label"], "render_path": render_path})
	return groups

func get_review19_substitution_report() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in _review19_rows:
		var item: Dictionary = row.duplicate()
		var xf: Transform3D = item["transform"] as Transform3D
		item.erase("transform")
		item.erase("context")
		item["exact_transform_hex"] = var_to_bytes(xf).hex_encode()
		item["origin"] = [xf.origin.x, xf.origin.y, xf.origin.z]
		item["basis_columns"] = [[xf.basis.x.x, xf.basis.x.y, xf.basis.x.z], [xf.basis.y.x, xf.basis.y.y, xf.basis.y.z], [xf.basis.z.x, xf.basis.z.y, xf.basis.z.z]]
		rows.append(item)
	var chunks: Array[Dictionary] = []
	for chunk: Dictionary in _review19_chunks:
		var item: Dictionary = chunk.duplicate()
		item.erase("instance")
		item.erase("original_multimesh")
		chunks.append(item)
	var render_groups: Array[Dictionary] = []
	for group: Dictionary in _review19_render_groups():
		var item: Dictionary = group.duplicate()
		item.erase("node")
		render_groups.append(item)
	return {"schema": "mush-r19-rooted-substitution/1", "status": _review19_status, "errors": _review19_errors.duplicate(), "counters": _review19_counters.duplicate(true), "by_label": _review19_by_label.duplicate(true), "by_category": _review19_by_category.duplicate(true), "fallback_reasons": _review19_fallback_reasons.duplicate(), "original_rooted_load_status": _review19_original_rooted_status.duplicate(true), "original_rng_after_super": _review19_rng_after_super, "current_rng": _rng.state, "rows": rows, "chunks": chunks, "render_groups": render_groups, "render_groups_scope": "targeted_only; unaffected original chunks retain original names", "support_scope": "Original reach/root margin/2mm source guards with new actual vertices and seven samples per triangle; discrete samples do not prove continuous clipping or wind clearance."}

func get_review19_substitution_evidence() -> Dictionary:
	return {"original_entries": _review19_original_entries, "records": _review19_rows, "new_meshes": _review19_meshes, "original_library": _review19_original_library, "stones": _review19_stones, "original_rooted_records": _review19_original_rooted_records, "original_rooted_stats": _review19_original_rooted_stats, "original_rooted_load_status": _review19_original_rooted_status, "chunks": _review19_render_groups(), "target_chunks": _review19_chunks, "chunks_scope": "targeted_only; unaffected original chunks retain original names"}
