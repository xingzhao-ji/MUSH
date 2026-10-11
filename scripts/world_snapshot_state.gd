extends Resource
## Native resources and typed runtime values accompanying the frozen scene.
@export var values: Dictionary = {}
@export var scene: PackedScene

func restore(world: Node) -> void:
	for property: String in values:
		world.set(property, _decode(values[property], world))

func _decode(value: Variant, world: Node) -> Variant:
	if value is Dictionary:
		if value.has("$node"):
			return world if value["$node"] == "." else world.get_node(NodePath(value["$node"]))
		if value.has("$rng"):
			var random := RandomNumberGenerator.new()
			random.seed = value["$rng"][0]
			random.state = value["$rng"][1]
			return random
		if value.has("$rid"):
			if value["$rid"].is_empty():
				return RID()
			return world.get_node(NodePath(value["$rid"])).get_rid()
		if value.has("$array"):
			var result: Array = []
			if value.get("typed", false):
				result = Array([], int(value["builtin"]), StringName(value["class"]), value.get("script"))
			for item: Variant in value["$array"]:
				result.append(_decode(item, world))
			return result
		var result: Dictionary = {}
		for key: Variant in value:
			result[_decode(key, world)] = _decode(value[key], world)
		return result
	return value
