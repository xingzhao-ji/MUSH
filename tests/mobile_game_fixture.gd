extends "res://scripts/playable.gd"
# Test-only profile redirection before any title load; never ships as main scene.
func _title() -> void:
	verification = true
	_preview_slot = "user://verification/mobile_touch_owned01"
	store.directory = _preview_slot
	_start_new()
