extends "res://lineage/scenery-revision-16/proposals/cap-rim-gills-03/detached-world.gd"

const MAIN_GILL_FLESH_SHADER: Shader = preload("res://lineage/scenery-revision-17/proposals/gill-material-02/main-gill-flesh-02.gdshader")

func _cap(origin: Vector3, radius: float, crown: float, parent: Node3D) -> void:
	super._cap(origin, radius, crown, parent)
	if radius <= 4.0:
		return
	var underbody: MeshInstance3D = parent.get_node_or_null("ContinuousPleatedCreamUnderbody") as MeshInstance3D
	if underbody == null:
		push_error("Review17 main gill material target is absent")
		return
	var main_gill: ShaderMaterial = underbody.material_override as ShaderMaterial
	if main_gill == null:
		push_error("Review17 main gill target has no ShaderMaterial override")
		return
	main_gill.shader = MAIN_GILL_FLESH_SHADER
	main_gill.set_shader_parameter("base_color", Color("f1e2c9"))
	main_gill.set_shader_parameter("accent_color", Color("bfa184"))
	main_gill.set_shader_parameter("roughness_value", 0.86)
	main_gill.set_shader_parameter("lamella_recess", 0.34)
	main_gill.set_meta("review_material_trial", "17-main-gill02")
