extends "res://lineage/scenery-revision-17/interactive-preview-01/candidate_main.gd"

# Proposed tuning only; original regeneration, garden cap and bloom timing remain.
var planting_mana_cost: float = 25.0

func _init() -> void:
	# Root's guarded loader may choose a different fresh private integration slot.
	_preview_slot = "user://revision18-planting-mana-01"

func _planting_affordable() -> bool:
	if not is_finite(planting_mana_cost) or planting_mana_cost <= 0.0 or planting_mana_cost > 100.0:
		_toast("This planting setting is unavailable.")
		return false
	if not is_finite(mana) or mana < planting_mana_cost:
		_toast("Planting needs " + str(planting_mana_cost) + " magic. Yours returns on its own.")
		return false
	return true

func _plant_menu(is_garden: bool) -> void:
	_enter_menu("plant_preview")
	var description: String = "Planting uses " + str(planting_mana_cost) + " magic and begins blooming immediately. Your magic returns on its own. Unlocked seed varieties can be used again."
	if not is_garden:
		description += "\nThis designed restoration point uses Moonbell; other unlocked varieties belong in your garden."
	_clear_menu("A little light", description)
	for kind: String in SaveScript.PLANT_TYPES:
		var unlocked: bool = kind in unlocked_plants
		var available: bool = unlocked and (is_garden or kind == "moonbell")
		var label: String = "Moonbell" if kind == "moonbell" else "Sunfern"
		if not unlocked:
			label += "  ·  seed not yet unlocked"
		elif not available:
			label += "  ·  garden variety"
		else:
			label += "  ·  plant · " + str(planting_mana_cost) + " magic"
		_button(label, _planting_choose.bind(kind, is_garden), not available)
	_button("Cancel", _explore)
	_focus_first()

func _planting_choose(kind: String, is_garden: bool) -> void:
	if is_garden:
		_begin_garden_preview(kind)
		if mode != "garden_place" and mode != "save_error":
			_explore()
		return
	plant_patch()
	# Low mana returns to exploration so regeneration continues. A failed durable
	# write retains the inherited Retry / Continue unsaved menu and paid outcome.
	if mode != "save_error":
		_explore()

func plant_patch() -> bool:
	if restoration_state != "faded" or "moonbell" not in unlocked_plants:
		return false
	if not _planting_affordable():
		return false
	# Only a synchronous logical intermediate: no free bud mesh, frame or save.
	restoration_state = "planted"
	if cast_plant():
		return true
	restoration_state = "faded"
	return false

func plant_garden(pos: Vector3, type: String = "moonbell") -> bool:
	if type not in SaveScript.PLANT_TYPES or type not in unlocked_plants or not pos.is_finite():
		return false
	if not _garden_allowed(pos) or not _planting_affordable():
		return false
	var id: String = "garden_%d" % Time.get_ticks_usec()
	for existing: Dictionary in garden:
		if existing.id == id:
			return false
	# Keep the original record schema; cast commits debit + final state together.
	garden.append({"id": id, "type": type, "position": [pos.x, 0.0, pos.z], "state": "seed", "transaction_id": ""})
	if cast_plant(id):
		return true
	# cast_plant rejects before mutation. Remove only our synchronous new record.
	garden.remove_at(garden.size() - 1)
	return false

func cast_plant(id: String = "") -> bool:
	var target: Dictionary = {}
	if id.is_empty():
		if restoration_state != "planted":
			return false
	else:
		for plant: Dictionary in garden:
			if plant.id == id:
				target = plant
				break
		if target.is_empty() or target.state != "seed":
			return false
	if not _planting_affordable():
		return false
	mana -= planting_mana_cost
	mana_delay = 1
	var tx: String = "cast_%d_%d" % [Time.get_unix_time_from_system() * 1000, Time.get_ticks_usec()]
	if id.is_empty():
		restoration_state = "bloomed"
		restoration_tx = tx
		resident_awake = true
		path_restored = true
		bloom_clock = 0
		_update_patch(.05)
	else:
		target.state = "bloomed"
		target.transaction_id = tx
		_rebuild_garden()
		garden_bloom[id] = 0.0
		garden_nodes[id].scale = Vector3.ONE * .25
	# Same original paid outcome / save path, now called at planting acceptance.
	# Mark unsaved state explicitly because no earlier free-bud save is scheduled.
	dirty = true
	_save_now(true)
	_play_effect("growth")
	_toast("A little light takes root.")
	return true

func _grow_plant_menu(id: String) -> void:
	var pending: bool = restoration_state == "planted" if id.is_empty() else false
	if not id.is_empty():
		for plant: Dictionary in garden:
			if plant.id == id and plant.state == "seed":
				pending = true
				break
	if not pending:
		_toast("This plant is already blooming; no more magic is needed.")
		_explore()
		return
	_enter_menu("grow_plant")
	_clear_menu("Finish an earlier planting", str(planting_mana_cost) + " magic · this older unactivated bud begins blooming now. Your magic returns on its own. New plantings need no second cast.")
	_button("Finish planting  ·  %d magic available" % int(mana), _planting_finish_legacy.bind(id), mana < planting_mana_cost)
	_button("Cancel", _explore)
	_focus_first()

func _planting_finish_legacy(id: String) -> void:
	if cast_plant(id) and mode != "save_error":
		_explore()

func _update_context() -> void:
	super._update_context()
	if player.state != "Grounded" or not player.is_on_floor():
		return
	var label: String = ""
	if context == "patch_plant":
		label = "Plant a luminous Moonbell · " + str(planting_mana_cost) + " magic"
	elif context == "patch_grow" or context.begins_with("garden_grow:"):
		label = "Finish an earlier planting · " + str(planting_mana_cost) + " magic"
	elif context == "garden":
		label = "Plant in your garden · %d / 8 · " % garden.size() + str(planting_mana_cost) + " magic"
	if not label.is_empty():
		prompt.text = _action_hint("interact", "B") + "  ·  " + label

func _update_garden_preview() -> void:
	super._update_garden_preview()
	if not is_instance_valid(garden_ghost):
		return
	prompt.text += "  ·  " + str(planting_mana_cost) + " magic to plant"
	if mana < planting_mana_cost:
		prompt.text += " · magic is returning automatically"

func _end_garden_preview() -> void:
	if is_instance_valid(garden_ghost):
		garden_ghost.queue_free()
	garden_ghost = null
	# The inherited input handler calls here after any accepted garden planting.
	# Cleanup its preview without replacing a save-error Retry menu with Explore.
	if mode != "save_error":
		_explore()
