class_name ClearingSave
extends RefCounted

## One application-local, validated save slot. Visual previews are never data.
## The caller owns safe-support checks and commits paid growth before animation.
const SCHEMA_VERSION := 1
const SUPPORTED_CONTENT_VERSIONS := ["0.1.0", "0.2.0", "0.2.1", "0.2.2", "0.3.0"]
# Uneven clearing ground can lie below world zero. Match the player's existing
# below-terrain recovery boundary; load still resolves real safe support.
const PLAYER_MIN_HEIGHT := -1.5
const MAX_BYTES := 1048576
const PRIMARY := "clearing.json"
const BACKUP := "clearing.backup.json"
const TEMP := "clearing.pending.json"
const BACKUP_TEMP := "clearing.backup.pending.json"
const BACKUP_ROLLBACK := "clearing.backup.previous.json"
const ROOT_KEYS := ["schema_version", "build_version", "seed", "sky", "weather", "player", "glow", "door", "room_right", "mana", "mana_delay", "unlocked_plants", "restoration", "furniture", "garden", "settings"]
const SOCKETS := {"main_chair": "chair", "main_table": "table", "main_lamp": "lamp", "annex_plant": "plant", "right_chair": "chair", "right_lamp": "lamp"}
const PLANT_TYPES := ["moonbell", "sunfern"]
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "glow", "float", "interact", "decorate", "pause"]
const SETTINGS_KEYS := ["float_toggle", "reduced_motion", "reduced_effects", "invert_y", "sensitivity", "prompt_scale", "music_volume", "ambience_volume", "effects_volume", "bindings"]

var directory: String = "user://"
## Test-only faults occur before a durable file is changed.
var fail_stage: String = ""


func save_snapshot(snapshot: Dictionary) -> Dictionary:
	var issue := _directory_issue()
	if not issue.is_empty():
		return _failure(issue)
	issue = validate(snapshot)
	if not issue.is_empty():
		return _failure("Save rejected: " + issue)
	var payload := JSON.stringify(snapshot, "\t")
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Save rejected: the file exceeds the 1 MiB limit.")
	var primary := _read_slot(PRIMARY)
	var backup := _read_slot(BACKUP)
	if primary.status == "future" or backup.status == "future":
		return _failure(primary.error if primary.status == "future" else backup.error)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK:
		return _failure(_io_failure("Cannot create the local save directory", mkdir_error))
	_cleanup_pending()
	issue = _write_pending(TEMP, payload)
	if not issue.is_empty():
		_cleanup_pending()
		return _failure(issue)
	if fail_stage == "validate":
		_cleanup_pending()
		return _failure("Save verification failed (simulated). Previous saves are unchanged.")
	var verified := _read_slot(TEMP)
	if verified.status != "valid":
		_cleanup_pending()
		return _failure("The pending save could not be verified. Previous saves are unchanged.")
	# Only a validated primary may become a backup. A damaged primary must never
	# replace a good backup recovered by load_snapshot().
	var replace_backup: bool = primary.status == "valid"
	if replace_backup:
		issue = _write_pending(BACKUP_TEMP, primary.text)
		if not issue.is_empty():
			_cleanup_pending()
			return _failure(issue)
		if _read_slot(BACKUP_TEMP).status != "valid":
			_cleanup_pending()
			return _failure("The backup could not be verified. Previous saves are unchanged.")
	if fail_stage in ["backup", "replace"]:
		_cleanup_pending()
		return _failure("Save replacement failed (simulated). Previous saves are unchanged.")
	var had_backup := FileAccess.file_exists(_path(BACKUP))
	if replace_backup:
		# Retain the old backup by rename so rollback does not require disk space.
		_remove_if_present(BACKUP_ROLLBACK)
		if had_backup:
			var move_error := DirAccess.rename_absolute(_path(BACKUP), _path(BACKUP_ROLLBACK))
			if move_error != OK:
				_cleanup_pending()
				return _failure(_io_failure("Cannot preserve the backup", move_error))
		var backup_error := DirAccess.rename_absolute(_path(BACKUP_TEMP), _path(BACKUP))
		if backup_error != OK:
			if had_backup:
				DirAccess.rename_absolute(_path(BACKUP_ROLLBACK), _path(BACKUP))
			_cleanup_pending()
			return _failure(_io_failure("Cannot replace the backup", backup_error))
	# Native-platform tests verify replacement of an existing file. At no point
	# is the primary deleted first: rename failure retains its previous contents.
	var replace_error := DirAccess.rename_absolute(_path(TEMP), _path(PRIMARY))
	if replace_error != OK:
		if replace_backup:
			_remove_if_present(BACKUP)
			if had_backup:
				DirAccess.rename_absolute(_path(BACKUP_ROLLBACK), _path(BACKUP))
		_cleanup_pending()
		return _failure(_io_failure("Cannot replace the save", replace_error))
	_remove_if_present(BACKUP_ROLLBACK)
	_cleanup_pending()
	return {"ok": true, "error": ""}


func load_snapshot() -> Dictionary:
	var issue := _directory_issue()
	if not issue.is_empty():
		return {"ok": false, "data": {}, "error": issue, "source": "error"}
	var primary := _read_slot(PRIMARY)
	if primary.status == "future":
		return {"ok": false, "data": {}, "error": primary.error, "source": "future"}
	if primary.status == "valid":
		return {"ok": true, "data": primary.data, "error": "", "source": "primary"}
	var backup := _read_slot(BACKUP)
	if backup.status == "future":
		return {"ok": false, "data": {}, "error": backup.error, "source": "future"}
	if backup.status == "valid":
		return {"ok": true, "data": backup.data, "error": "The primary save could not be read. The last validated backup was loaded; the original files are preserved.", "source": "backup"}
	if primary.status == "missing" and backup.status == "missing":
		return {"ok": false, "data": {}, "error": "", "source": "new"}
	return {"ok": false, "data": {}, "error": "No valid local save could be loaded. " + primary.error + " " + backup.error + " Start a new game to continue; the existing files have been preserved.", "source": "corrupt"}


func validate(data: Dictionary) -> String:
	var issue := _keys_issue(data, ROOT_KEYS, "save")
	if not issue.is_empty():
		return issue
	if not _whole_number(data.schema_version) or data.schema_version != SCHEMA_VERSION:
		return "Unsupported save schema version."
	if not data.build_version is String or data.build_version not in SUPPORTED_CONTENT_VERSIONS:
		return "Unknown build content version."
	if not _whole_number(data.seed) or not _between(data.seed, 0, 2147483647):
		return "Invalid world seed."
	if not data.sky is String or data.sky not in ["day", "night"]:
		return "Unknown sky preset."
	if not data.weather is String or data.weather not in ["sunny", "rain"]:
		return "Unknown weather preset."
	if not data.player is Dictionary:
		return "Invalid player state."
	issue = _keys_issue(data.player, ["position", "yaw"], "player")
	if not issue.is_empty():
		return issue
	if not _position_valid(data.player.position, -20.0, 20.0, -20.0, 26.0, PLAYER_MIN_HEIGHT, 10.0):
		return "Player position is outside the clearing or is not finite."
	if not _between(data.player.yaw, -10000.0, 10000.0):
		return "Invalid player yaw."
	if not data.glow is bool or not data.room_right is bool:
		return "Invalid Glow or room state."
	if not data.door is String or data.door not in ["open", "closed"]:
		return "Door state must be stable and known."
	if not _between(data.mana, 0.0, 100.0) or not _between(data.mana_delay, 0.0, 1.0):
		return "Invalid mana or recharge delay."
	if not data.unlocked_plants is Array or data.unlocked_plants.is_empty() or data.unlocked_plants.size() > PLANT_TYPES.size():
		return "Invalid unlocked plant list."
	var unlocked_seen: Dictionary = {}
	for plant_type in data.unlocked_plants:
		if not plant_type is String or plant_type not in PLANT_TYPES or unlocked_seen.has(plant_type):
			return "Unknown or duplicate unlocked plant type."
		unlocked_seen[plant_type] = true
	if not data.restoration is Dictionary:
		return "Invalid restoration state."
	issue = _keys_issue(data.restoration, ["state", "transaction_id", "resident_awake", "path_restored"], "restoration")
	if not issue.is_empty():
		return issue
	var restoration: Dictionary = data.restoration
	if not restoration.state is String or restoration.state not in ["faded", "planted", "bloomed"]:
		return "Unknown restoration state."
	if not _identifier_valid(restoration.transaction_id, true):
		return "Invalid restoration transaction ID."
	if not restoration.resident_awake is bool or not restoration.path_restored is bool:
		return "Invalid restoration reward flags."
	var restored: bool = restoration.state == "bloomed"
	if restoration.resident_awake != restored or restoration.path_restored != restored:
		return "Restoration and resident/path outcomes must be committed together."
	if restored and restoration.transaction_id.is_empty():
		return "A restored patch requires its committed transaction ID."
	if not data.furniture is Dictionary or data.furniture.size() > 6:
		return "Invalid furniture assignments or more than six sockets."
	for socket_id in data.furniture:
		if not socket_id is String or not SOCKETS.has(socket_id):
			return "Unknown furniture socket ID."
		var style: Variant = data.furniture[socket_id]
		if not style is String or style not in ["", SOCKETS[socket_id] + "_honey", SOCKETS[socket_id] + "_moss"]:
			return "Unknown or incompatible furniture style ID."
		if socket_id.begins_with("right_") and not style.is_empty() and not data.room_right:
			return "Right-room furniture requires the completed room."
	if not data.garden is Array or data.garden.size() > 8:
		return "Invalid garden or more than eight plants."
	var garden_ids: Dictionary = {}
	var garden_positions: Array[Vector3] = []
	for plant in data.garden:
		if not plant is Dictionary:
			return "Invalid garden plant."
		issue = _keys_issue(plant, ["id", "type", "position", "state", "transaction_id"], "garden plant")
		if not issue.is_empty():
			return issue
		if not _identifier_valid(plant.id) or garden_ids.has(plant.id):
			return "Invalid or duplicate garden plant ID."
		garden_ids[plant.id] = true
		if not plant.type is String or plant.type not in PLANT_TYPES or not unlocked_seen.has(plant.type):
			return "Unknown or locked garden plant type."
		if not _position_valid(plant.position, -5.8, -3.8, 2.5, 4.5, 0.0, 1.0):
			return "Garden plant position is outside its allowed ground area."
		var position := Vector3(float(plant.position[0]), float(plant.position[1]), float(plant.position[2]))
		for prior in garden_positions:
			if Vector2(position.x, position.z).distance_to(Vector2(prior.x, prior.z)) < 0.3499:
				return "Garden plant positions overlap."
		garden_positions.append(position)
		if not plant.state is String or plant.state not in ["seed", "bloomed"] or not _identifier_valid(plant.transaction_id, true):
			return "Invalid garden growth state or transaction ID."
		if plant.state == "bloomed" and plant.transaction_id.is_empty():
			return "A bloomed garden plant requires its committed transaction ID."
	if not data.settings is Dictionary:
		return "Invalid accessibility and controls settings."
	issue = _keys_issue(data.settings, SETTINGS_KEYS, "settings")
	if not issue.is_empty():
		return issue
	for boolean_key in ["float_toggle", "reduced_motion", "reduced_effects", "invert_y"]:
		if not data.settings[boolean_key] is bool:
			return "Invalid accessibility setting: " + boolean_key
	if not _between(data.settings.sensitivity, 0.1, 5.0) or not _between(data.settings.prompt_scale, 0.75, 2.0):
		return "Invalid look sensitivity or prompt scale."
	for volume_key in ["music_volume", "ambience_volume", "effects_volume"]:
		if not _between(data.settings[volume_key], 0.0, 1.0):
			return "Invalid audio volume: " + volume_key
	if not data.settings.bindings is Dictionary:
		return "Invalid input bindings."
	issue = _keys_issue(data.settings.bindings, ACTIONS, "input bindings")
	if not issue.is_empty():
		return issue
	for action in ACTIONS:
		if not _whole_number(data.settings.bindings[action]) or not _between(data.settings.bindings[action], 1, 2147483647):
			return "Invalid keycode for action: " + action
	return ""


func _directory_issue() -> String:
	if not directory.begins_with("user://"):
		return "Save directory must be application-local."
	var relative := directory.trim_prefix("user://").trim_suffix("/")
	if relative.is_empty():
		return ""
	for segment in relative.split("/"):
		if not _identifier_valid(segment):
			return "Invalid application-local save directory."
	return ""


func _read_slot(filename: String) -> Dictionary:
	var path := _path(filename)
	if not FileAccess.file_exists(path):
		return {"status": "missing", "error": "A save file is missing."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": "invalid", "error": "A save file cannot be opened: " + error_string(FileAccess.get_open_error())}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"status": "invalid", "error": "A save exceeds the 1 MiB limit."}
	var contents := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"status": "invalid", "error": "A save contains malformed JSON."}
	var data: Dictionary = parser.data
	if data.has("schema_version") and _whole_number(data.schema_version) and data.schema_version > SCHEMA_VERSION:
		return {"status": "future", "error": "A newer save schema is present. The files are preserved and cannot be overwritten by this build."}
	# build_version is this build's content-version field. Preserve future files
	# that spell it content_version too, before the strict current-schema check.
	for version_field: String in ["build_version", "content_version"]:
		if data.has(version_field) and data[version_field] is String and data[version_field] not in SUPPORTED_CONTENT_VERSIONS:
			return {"status": "future", "error": "An unsupported save content version is present. No migration is available; the files are preserved and cannot be overwritten by this build."}
	var issue := validate(data)
	if not issue.is_empty():
		return {"status": "invalid", "error": issue}
	return {"status": "valid", "error": "", "data": data, "text": contents}


func _write_pending(filename: String, payload: String) -> String:
	if fail_stage in ["write", "permission", "full_disk"]:
		if fail_stage == "permission":
			return "Save write failed: permission denied (simulated). Continue unsaved or Retry."
		if fail_stage == "full_disk":
			return "Save write failed: the disk is full (simulated). Continue unsaved or Retry."
		return "Save write failed (simulated). Continue unsaved or Retry."
	var file := FileAccess.open(_path(filename), FileAccess.WRITE)
	if file == null:
		return _io_failure("Save write failed", FileAccess.get_open_error())
	file.store_string(payload)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _io_failure("Save flush failed", write_error)
	if fail_stage == "flush":
		return "Save flush failed (simulated). Previous saves are unchanged."
	return ""


func _io_failure(operation: String, code: int) -> String:
	# Godot's native macOS file/rename errors can be generic. Add only facts
	# observed after failure; never preempt a successful save based on headroom.
	var path: String = ProjectSettings.globalize_path(directory)
	var permissions: int = FileAccess.get_unix_permissions(path)
	if permissions > 0 and (permissions & 0b010010010) == 0:
		return operation + ": the local save folder has no write permission. Restore its write permission and Retry."
	if code == ERR_UNAUTHORIZED or code == ERR_FILE_NO_PERMISSION:
		return operation + ": writing the local save was denied. Check its file and folder permissions and Retry."
	var access: DirAccess = DirAccess.open(directory)
	var space_left: int = access.get_space_left() if access != null else 0
	if space_left > 0 and space_left < 4 * MAX_BYTES:
		# A maximum-size pending save, backup and filesystem metadata need more
		# headroom than the payload alone. This is a low-space observation, not
		# an assertion that the API exposed an ENOSPC errno.
		return operation + ": the drive reports very little free space. Free some space and Retry."
	return operation + ": " + error_string(code) + ". Continue unsaved or Retry."


func _keys_issue(data: Dictionary, expected: Array, label: String) -> String:
	if data.size() != expected.size():
		return "Missing or unknown fields in " + label + "."
	for key in expected:
		if not data.has(key):
			return "Missing field in " + label + ": " + str(key)
	return ""


func _number_valid(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


func _whole_number(value: Variant) -> bool:
	return _number_valid(value) and floor(float(value)) == float(value)


func _between(value: Variant, low: float, high: float) -> bool:
	return _number_valid(value) and float(value) >= low and float(value) <= high


func _position_valid(value: Variant, min_x: float, max_x: float, min_z: float, max_z: float, min_y: float, max_y: float) -> bool:
	return value is Array and value.size() == 3 and _between(value[0], min_x, max_x) and _between(value[1], min_y, max_y) and _between(value[2], min_z, max_z)


func _identifier_valid(value: Variant, allow_empty: bool = false) -> bool:
	if not value is String or value.length() > 64:
		return false
	if value.is_empty():
		return allow_empty
	for character in value:
		if not ((character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9") or character in ["_", "-"]):
			return false
	return true


func _path(filename: String) -> String:
	return directory.path_join(filename)


func _remove_if_present(filename: String) -> void:
	if FileAccess.file_exists(_path(filename)):
		DirAccess.remove_absolute(_path(filename))


func _cleanup_pending() -> void:
	_remove_if_present(TEMP)
	_remove_if_present(BACKUP_TEMP)


func _failure(issue: String) -> Dictionary:
	return {"ok": false, "error": issue}
