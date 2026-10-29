extends RefCounted
## Exact C1 authoring results. Ordinary startup reads native packed arrays/meshes;
## only the explicit offline bake may run builders and populate this dictionary.
## Full source-asset hashes are checked offline. Startup hashes the small builder
## files and the one compressed artifact, without walking source mesh faces.
const SCHEMA := "mush-c1-derived/1"
const ARTIFACT := "res://baked/c1-derived.res"
const PROOF := "res://baked/c1-derived-proof.json"
const SELF := "res://scripts/c1_derived_cache.gd"
const MAX_ARTIFACT_BYTES := 268435456
const MAX_PROOF_BYTES := 2097152

var failed: bool = false
var _bake: bool = false
var _loaded: bool = false
var _source: String
var _values: Dictionary = {}
var _dependencies: Dictionary = {}
var _artifact: Resource
var _failure: String = ""

func _init(source: String, bake_mode: bool = false) -> void:
	_source = source
	_bake = bake_mode and OS.get_environment("MUSH_C1_DERIVED_BAKE") == "1"
	if bake_mode and not _bake:
		_refuse("Authoring requires MUSH_C1_DERIVED_BAKE=1")

func is_baking() -> bool:
	return _bake

func has_value(key: String) -> bool:
	if not _ensure_loaded(): return false
	if _values.has(key): return true
	if not _bake: _refuse("Missing derived key: " + key)
	return false

func get_value(key: String) -> Variant:
	if not has_value(key): return null
	return _values[key]

func put_value(key: String, value: Variant) -> void:
	if failed: return
	if not _bake:
		_refuse("Runtime attempted to author derived key: " + key)
		return
	if key.is_empty():
		_refuse("Empty derived key")
		return
	_values[key] = value

## Called by the offline tool after ordinary startup has collected model paths.
## The import settings are part of the derivation, even when source GLBs match.
func add_dependency(path: String) -> void:
	if not _bake or failed: return
	if not path.begins_with("res://") or not FileAccess.file_exists(path):
		_refuse("Missing source dependency: " + path)
		return
	_dependencies[path] = true
	if FileAccess.file_exists(path + ".import"):
		_dependencies[path + ".import"] = true

func save(path: String = ARTIFACT) -> Dictionary:
	if not _bake or failed: return {"passed": false, "reason": _failure if failed else "Authoring mode required"}
	if _values.is_empty(): return {"passed": false, "reason": "No derived values were collected"}
	if not path.begins_with("res://baked/") and not path.begins_with("res://reports/"):
		return {"passed": false, "reason": "Bake output must stay in baked/ or reports/"}
	var builders: Dictionary = {}
	for builder: String in [_source, SELF]:
		if not FileAccess.file_exists(builder): return {"passed": false, "reason": "Missing builder: " + builder}
		builders[builder] = FileAccess.get_sha256(builder)
	var dependencies: Dictionary = {}
	var paths: Array = _dependencies.keys()
	paths.sort()
	for dependency: String in paths:
		var file: FileAccess = FileAccess.open(dependency, FileAccess.READ)
		if file == null: return {"passed": false, "reason": "Unreadable dependency: " + dependency}
		var length: int = file.get_length()
		file.close()
		dependencies[dependency] = {"sha256": FileAccess.get_sha256(dependency), "bytes": length}
	var payload := Resource.new()
	payload.set_meta("schema", SCHEMA)
	payload.set_meta("values", _values)
	var parent: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return {"passed": false, "reason": "Cannot create bake output directory"}
	var error: Error = ResourceSaver.save(payload, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK: return {"passed": false, "reason": "Native resource save failed", "error": error}
	var saved: FileAccess = FileAccess.open(path, FileAccess.READ)
	if saved == null: return {"passed": false, "reason": "Saved native resource unreadable"}
	var artifact_bytes: int = saved.get_length()
	saved.close()
	if artifact_bytes <= 0 or artifact_bytes > MAX_ARTIFACT_BYTES:
		return {"passed": false, "reason": "Native resource exceeds the fixed size bound"}
	var keys: Array = _values.keys()
	keys.sort()
	var proof: Dictionary = {"schema": SCHEMA, "passed": true, "artifact": path,
		"artifact_sha256": FileAccess.get_sha256(path), "artifact_bytes": artifact_bytes,
		"builders": builders, "dependencies": dependencies, "keys": keys,
		"scope": "Exact native derived values; no collision or material substitution"}
	var proof_path: String = path.get_basename() + "-proof.json"
	var out: FileAccess = FileAccess.open(proof_path, FileAccess.WRITE)
	if out == null: return {"passed": false, "reason": "Cannot write native resource proof"}
	out.store_string(JSON.stringify(proof, "\t") + "\n")
	out.close()
	return {"passed": true, "artifact": path, "proof": proof_path, "bytes": artifact_bytes,
		"sha256": proof.artifact_sha256, "values": keys.size(), "dependencies": dependencies.size()}

func get_report() -> Dictionary:
	return {"bake_mode": _bake, "loaded": _loaded, "failed": failed,
		"reason": _failure, "values": _values.size(), "artifact": ARTIFACT}

func _ensure_loaded() -> bool:
	if failed: return false
	if _loaded: return true
	if _bake:
		_loaded = true
		return true
	var proof: Dictionary = _read_proof(PROOF)
	if proof.is_empty(): return _refuse("Missing or malformed derived proof; run the offline C1 bake")
	if proof.get("schema", "") != SCHEMA or not proof.get("passed", false) or proof.get("artifact", "") != ARTIFACT:
		return _refuse("Derived proof schema or artifact identity changed")
	var builders: Variant = proof.get("builders")
	if not builders is Dictionary or builders.size() != 2:
		return _refuse("Two bound builder sources required")
	for builder: String in [_source, SELF]:
		if not builders.has(builder) or not FileAccess.file_exists(builder) or FileAccess.get_sha256(builder) != str(builders[builder]):
			return _refuse("Stale derived builder: " + builder + "; rebake C1")
	var file: FileAccess = FileAccess.open(ARTIFACT, FileAccess.READ)
	if file == null: return _refuse("Derived native resource missing")
	var length: int = file.get_length()
	file.close()
	if length <= 0 or length > MAX_ARTIFACT_BYTES or length != int(proof.get("artifact_bytes", -1)) or FileAccess.get_sha256(ARTIFACT) != str(proof.get("artifact_sha256", "")):
		return _refuse("Derived native resource length or SHA256 differs from its proof")
	_artifact = ResourceLoader.load(ARTIFACT, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	if _artifact == null or _artifact.get_script() != null or _artifact.get_meta("schema", "") != SCHEMA or not _artifact.get_meta("values", null) is Dictionary:
		return _refuse("Unscripted native derived dictionary required")
	_values = _artifact.get_meta("values")
	var keys: Array = _values.keys()
	keys.sort()
	if keys != proof.get("keys", []): return _refuse("Derived key inventory differs from its proof")
	_loaded = true
	return true

func _refuse(reason: String) -> bool:
	if not failed:
		failed = true
		_failure = reason
		push_error("C1 derived cache refused: " + reason)
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null: tree.quit(2)
	return false

static func _read_proof(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > MAX_PROOF_BYTES:
		file.close()
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

## Full dependency verification belongs in authoring/final validation, rather
## than hashing all imported GLBs and settings on each child-process startup.
static func verify_dependencies(proof_path: String = PROOF) -> Dictionary:
	var proof: Dictionary = _read_proof(proof_path)
	var dependencies: Variant = proof.get("dependencies")
	if proof.get("schema", "") != SCHEMA or not dependencies is Dictionary or dependencies.is_empty():
		return {"passed": false, "reason": "Missing dependency manifest"}
	var mismatches: Array[String] = []
	for path: String in dependencies:
		var row: Variant = dependencies[path]
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null or not row is Dictionary:
			mismatches.append(path)
			continue
		var length: int = file.get_length()
		file.close()
		if length != int(row.get("bytes", -1)) or FileAccess.get_sha256(path) != str(row.get("sha256", "")):
			mismatches.append(path)
	return {"passed": mismatches.is_empty(), "dependencies": dependencies.size(), "mismatches": mismatches}
