extends "res://lineage/scenery-revision-17/proposals/water-rock-02/water-world.gd"

# Detached night-only readability trial. Numeric values remain proposed.
func _apply_appearance() -> void:
	super._apply_appearance()
	var n: float = night_amount
	for id: String in ["leaf", "leaf_gold", "leaf_dark"]:
		(_materials[id] as ShaderMaterial).set_shader_parameter("night_amount", n * 0.55)
	for practical: OmniLight3D in _practical_lights:
		var lantern: Node = practical.get_parent()
		if lantern == null:
			continue
		var owner_node: Node = lantern.get_parent()
		if owner_node == null or owner_node.name != &"ArchedTimberBridge":
			continue
		practical.omni_range = lerpf(3.1, 4.6, n)
		practical.light_energy = lerpf(0.25, 1.18, n)
