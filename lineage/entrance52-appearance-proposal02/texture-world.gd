extends "res://lineage/entrance52-author02/landform-world.gd"
# Source-owned CPU conversion before GPU upload; no imported texture is loaded here.
const _T50_SOURCE: String = "res://lineage/entrance52-appearance-proposal02/texture-world.gd"
const _T50_FILES: Dictionary = {
	"bark":{"path":"res://assets/world/textures/bark-albedo-proposal-v1.png","sha256":"164507e71043b92c2d14a1757f6ea1087d1de7fe379985de8f0dff2041d60570","import_sha256":"968ca1f4ab0b4a065029ba013b70adcdff63f6e8204102fdcabe4c9e89257217"},
	"moss":{"path":"res://assets/world/textures/moss-albedo-proposal-v1.png","sha256":"5cbcec5b42550430fbfb4c84b09d304be037d44e069ae138cf4ab1d52adf5de5","import_sha256":"12374fb07f44f31306f7b801e1125c23c808f9b9410aa3d71ba7f299923ae1ff"}}
var _t50_records: Dictionary = {}
var _t50_errors: Array[String] = []

func _t50_sha(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _t50_load_rgba(key: String) -> Texture2D:
	var entry: Dictionary = _T50_FILES[key]
	var path: String = ProjectSettings.globalize_path(str(entry["path"]))
	if FileAccess.get_sha256(path) != entry["sha256"] or FileAccess.get_sha256(path+".import") != entry["import_sha256"]:
		_t50_errors.append("Pinned original PNG/import identity refused: "+key)
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_format() != Image.FORMAT_RGB8 or image.has_mipmaps() or image.get_width() != 1254 or image.get_height() != 1254:
		_t50_errors.append("Original RGB8/no-mip image contract refused: "+key)
		return null
	var rgb: PackedByteArray = image.get_data()
	var pixels: int = image.get_width()*image.get_height()
	if rgb.size() != pixels*3:
		_t50_errors.append("Original RGB byte cardinality refused: "+key)
		return null
	# Independent byte construction preserves every quantized source channel.
	var expected: PackedByteArray = PackedByteArray()
	expected.resize(pixels*4)
	for i: int in range(pixels):
		expected[i*4] = rgb[i*3]
		expected[i*4+1] = rgb[i*3+1]
		expected[i*4+2] = rgb[i*3+2]
		expected[i*4+3] = 255
	image.convert(Image.FORMAT_RGBA8)
	var cpu_exact: bool = image.get_format() == Image.FORMAT_RGBA8 and not image.has_mipmaps() and image.get_data() == expected
	if not cpu_exact:
		_t50_errors.append("CPU conversion differs from independent RGB+opaque-alpha bytes: "+key)
		return null
	# No GPU resource exists until the CPU image already has the admitted format.
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var native: Image = texture.get_image() if texture != null else null
	var native_exact: bool = native != null and not native.is_empty() and native.get_format() == Image.FORMAT_RGBA8 and not native.has_mipmaps() and native.get_width() == image.get_width() and native.get_height() == image.get_height() and native.get_data() == expected
	_t50_records[key] = {"texture":texture,"expected_rgba":expected,"path":str(entry["path"]),"cpu_exact":cpu_exact,"native_initial_exact":native_exact,
		"width":image.get_width(),"height":image.get_height(),"pixels":pixels,"rgb_sha256":_t50_sha(rgb),"rgba_sha256":_t50_sha(expected)}
	if not native_exact: _t50_errors.append("Native RGBA image differs from independent complete expected bytes: "+key)
	return texture

func _create_materials() -> void:
	_material("cap", Color("ed9b7c"), Color("b56e59"), 0.83, 3.0, 0.30, 2.0)
	_material("cap_rim", Color("efab84"), Color("ba785b"), 0.86, 4.0, 0.25, 2.0)
	_material("plaster", Color("eee2bd"), Color("c3b082"), 0.92, 3.0, 0.35, 1.0)
	_material("wood", Color("825136"), Color("3e2519"), 0.89, 7.0, 0.58, 1.0)
	_material("wood_light", Color("b58550"), Color("79503b"), 0.90, 5.0, 0.47, 1.0)
	_material("floor", Color("c4a276"), Color("8b6548"), 0.90, 4.0, 0.32, 1.0)
	_material("stone", Color("858675"), Color("414b40"), 0.97, 4.0, 0.36)
	_material("stone_light", Color("afa78b"), Color("657060"), 0.95, 4.0, 0.32)
	_material("moss", Color("5a772e"), Color("244c26"), 0.96, 6.0, 0.40)
	_material("soil", Color("575336"), Color("2e3e26"), 0.97, 4.0, 0.30)
	_material("path", Color("b7a181"), Color("7c7760"), 0.98, 6.0, 0.40)
	_material("leaf", Color("48752e"), Color("a3ac49"), 0.88, 3.0, 0.22)
	_material("leaf_gold", Color("718b33"), Color("c0b74d"), 0.88, 3.0, 0.24)
	_material("leaf_dark", Color("2f5b39"), Color("577731"), 0.90, 3.0, 0.26)
	_material("bark", Color("66563c"), Color("322d24"), 0.95, 7.0, 0.55, 1.0)
	_material("flower_white", Color("eee9c8"), Color("d0c9a9"), 0.78, 3.0, 0.16)
	_material("flower_pink", Color("d8a7bd"), Color("99558e"), 0.78, 3.0, 0.20)
	_material("flower_blue", Color("ad9cce"), Color("6561b7"), 0.78, 3.0, 0.20)
	_material("gold", Color("d6a14a"), Color("94632b"), 0.50, 7.0, 0.16)
	_material("iron", Color("343227"), Color("756749"), 0.45, 3.0, 0.12)
	_material("pot", Color("b1774d"), Color("734933"), 0.93, 5.0, 0.32)
	var gill: ShaderMaterial = _material("gill", Color("ebd9b2"), Color("bdae81"), 0.93, 3.0, 0.12, 0.0)
	gill.set_shader_parameter("emission_color", Color("584df1"))
	_gill_materials.append(gill)
	gill.set_meta("emission_scale", 0.45)
	gill.set_shader_parameter("lamella_emission",1.0)
	gill.set_shader_parameter("lamella_recess",0.28)
	var gill_back: ShaderMaterial = _material("gill_back", Color("dfd0ac"), Color("b5a578"), 0.95, 3.0, 0.12, 0.0)
	gill_back.set_shader_parameter("emission_color", Color("584df1"))
	gill_back.set_meta("emission_scale", 0.0)
	_gill_materials.append(gill_back)
	var glow: ShaderMaterial = _material("glow", Color("ffcf7b"), Color("ffd589"), 0.50, 1.0, 0.0)
	glow.set_shader_parameter("emission_color", Color("ffb95b"))
	glow.set_shader_parameter("emission_strength", 1.4)
	for id: String in ["leaf", "leaf_gold", "leaf_dark"]:
		(_materials[id] as ShaderMaterial).set_shader_parameter("foliage", 1.0)
		(_materials[id] as ShaderMaterial).shader = load("res://assets/world/foliage.gdshader") as Shader
	var bark_texture: Texture2D = _t50_load_rgba("bark")
	var moss_texture: Texture2D = _t50_load_rgba("moss")
	(_materials["bark"] as ShaderMaterial).set_shader_parameter("surface_albedo",bark_texture)
	(_materials["bark"] as ShaderMaterial).set_shader_parameter("surface_blend",.94)
	for id: String in ["moss","soil"]:
		var mat: ShaderMaterial = _materials[id] as ShaderMaterial
		mat.set_shader_parameter("surface_albedo",moss_texture)
		mat.set_shader_parameter("surface_blend",.90 if id=="moss" else .78)
		mat.set_shader_parameter("surface_triplanar",true)
		mat.set_shader_parameter("surface_scale",1.20 if id=="moss" else .60)
	_materials["leaf_shadow"] = _materials["leaf"]
	var fairy: ShaderMaterial = _material("fairy", Color("9c9ee8"), Color("c4d0fc"), 0.55, 2.0, 0.06)
	fairy.set_shader_parameter("emission_color", Color("898bf4"))
	fairy.set_shader_parameter("emission_strength", 0.12)

func _t50_material_binding(material: Material,node_path: String,parameter: String) -> Dictionary:
	var shader_material: ShaderMaterial = material as ShaderMaterial
	var expected: Texture2D = _t50_records.get("moss",{}).get("texture") as Texture2D
	var actual: Texture2D = shader_material.get_shader_parameter(parameter) as Texture2D if shader_material != null else null
	return {"node_path":node_path,"material_id":str(material.get_instance_id()) if material != null else "", "parameter":parameter,
		"texture_id":str(actual.get_instance_id()) if actual != null else "","exact_shared_moss_reference":expected != null and actual == expected}

func _t50_shoulder_ledger(node: Node,rows: Array) -> void:
	var mesh: Mesh = null
	var override_material: Material = null
	if node is MeshInstance3D:
		mesh = node.mesh
		override_material = node.material_override
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
		override_material = node.material_override
	var materials: Array[Material] = []
	if override_material != null: materials.append(override_material)
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(surface)
			if material != null and not materials.has(material): materials.append(material)
	for material: Material in materials:
		var selected: ShaderMaterial = material as ShaderMaterial
		if selected != null and selected.shader != null and selected.shader.resource_path == "res://assets/world/foreground_stone_moss_proposal_v1.gdshader":
			rows.append(_t50_material_binding(material,str(node.get_path()),"shoulder_moss_texture"))
	for child: Node in node.get_children(): _t50_shoulder_ledger(child,rows)

func get_texture50_report() -> Dictionary:
	var observations: Dictionary = {}
	var all_exact: bool = _t50_records.size() == 2 and _t50_errors.is_empty()
	for key: String in ["bark","moss"]:
		var entry: Dictionary = _T50_FILES[key]
		var row: Dictionary = _t50_records.get(key,{})
		var texture: ImageTexture = row.get("texture") as ImageTexture
		var native: Image = texture.get_image() if texture != null else null
		var expected: PackedByteArray = row.get("expected_rgba",PackedByteArray())
		var native_exact: bool = native != null and native.get_format() == Image.FORMAT_RGBA8 and not native.has_mipmaps() and native.get_width() == 1254 and native.get_height() == 1254 and native.get_data() == expected
		var source_exact: bool = FileAccess.get_sha256(str(entry["path"])) == entry["sha256"] and FileAccess.get_sha256(str(entry["path"])+".import") == entry["import_sha256"]
		var passed: bool = row.get("cpu_exact",false) and row.get("native_initial_exact",false) and native_exact and source_exact
		all_exact = all_exact and passed
		observations[key] = {"passed":passed,"source_path":entry["path"],"source_sha256":entry["sha256"],"import_sha256":entry["import_sha256"],"source_files_exact":source_exact,
			"original_format":"RGB8","native_format":"RGBA8" if native_exact else "refused","width":row.get("width",0),"height":row.get("height",0),"pixels_checked":row.get("pixels",0),
			"original_RGB_sha256":row.get("rgb_sha256",""),"independent_RGBA_sha256":row.get("rgba_sha256",""),"native_RGBA_sha256":_t50_sha(native.get_data()) if native != null else "",
			"CPU_RGB_and_added_alpha255_exact":row.get("cpu_exact",false),"native_all_RGBA_bytes_exact":native_exact,"native_has_mipmaps":native.has_mipmaps() if native != null else true,
			"native_texture_class":texture.get_class() if texture != null else "","native_resource_path":texture.resource_path if texture != null else "","native_resource_id":str(texture.get_instance_id()) if texture != null else ""}
	var bindings: Array = []
	for key: String in ["bark","moss","soil"]:
		var material: ShaderMaterial = _materials.get(key) as ShaderMaterial
		var expected_key: String = "bark" if key == "bark" else "moss"
		var actual: Texture2D = material.get_shader_parameter("surface_albedo") as Texture2D if material != null else null
		var expected_texture: Texture2D = _t50_records.get(expected_key,{}).get("texture") as Texture2D
		var exact: bool = expected_texture != null and actual == expected_texture
		bindings.append({"material_key":key,"parameter":"surface_albedo","material_id":str(material.get_instance_id()) if material != null else "","texture_id":str(actual.get_instance_id()) if actual != null else "","expected_image":expected_key,"exact_reference":exact})
		all_exact = all_exact and exact
	var shoulders: Array = []
	_t50_shoulder_ledger(self,shoulders)
	var shoulder_exact: bool = not shoulders.is_empty()
	for row: Dictionary in shoulders: shoulder_exact = shoulder_exact and row["exact_shared_moss_reference"]
	all_exact = all_exact and shoulder_exact
	return {"schema":"mush-texture50-cpu-rgba-observation/1","passed":all_exact,"performed":_t50_records.size()==2,"errors":_t50_errors.duplicate(),"original_images_checked":_t50_records.size(),"images":observations,
		"current_material_bindings":bindings,"current_shoulder_texture_bindings":shoulders,"current_binding_ledger_exact":all_exact and shoulder_exact,
		"source_path":_T50_SOURCE,"source_sha256":FileAccess.get_sha256(_T50_SOURCE),"intentional_texture_resource_class_and_path_change":true,
		"original_RGB_every_texel_preserved":all_exact,"added_alpha":255,"mipmaps_generated":false,"original_shader_sampler_and_material_knobs_changed":false,
		"sampler_policy":"Inherited source_color/filter_linear_mipmap_anisotropic/repeat_enable; inherited UV/triplanar coordinates; original no-mip/lossless/no-premult source policy retained.",
		"source_adopted":false,"native_adopted":false,"art_approved":false,"visual_equivalence_verified":false,"performance_measured":false,
		"scope":"Exact source RGB -> independent RGB+255 CPU bytes -> full native RGBA readback at explicit boundary. ImageTexture with empty resource_path intentionally replaces the two imported CompressedTexture2D resources; all other source method expressions and downstream native scene proofs remain required. No assets rewritten and no imported ctex load occurs in this override."}
