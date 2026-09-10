extends Node3D
## Loads the Freja glb, indexes every garment mesh, and applies a FrejaConfig
## (outfit + pieces + colours + body shape). Also exposes the Skeleton3D so the
## procedural locomotion can pose it.

const GLB_PATH := "res://assets/characters/freja/freja.glb"
const Wardrobe := preload("res://scripts/character/wardrobe.gd")
const MaterialFactory := preload("res://scripts/character/material_factory.gd")

var skeleton: Skeleton3D
var model_root: Node3D
var meshes := {}                       # clean name -> MeshInstance3D
var _mat_factory := MaterialFactory.new()
var _base_materials := {}              # MeshInstance3D -> Array[Material] (original slot mats by our factory)
var _current_config: FrejaConfig

signal model_ready

func load_model() -> void:
	var packed: PackedScene = load(GLB_PATH)
	model_root = packed.instantiate()
	model_root.name = "Model"
	add_child(model_root)

	skeleton = _find_skeleton(model_root)
	assert(skeleton != null, "Freja glb has no Skeleton3D")

	for mi in _all_mesh_instances(model_root):
		var clean := _clean_name(mi.name)
		meshes[clean] = mi
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		_assign_materials(mi, Color.WHITE)

	# never render the internal cavity meshes
	for hidden_name in ["Freja_Tongue", "Freja_Teeth_Lower", "Freja_Teeth_Upper"]:
		if meshes.has(hidden_name):
			meshes[hidden_name].visible = false

	model_ready.emit()

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null

func _all_mesh_instances(n: Node, acc: Array = []) -> Array:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_all_mesh_instances(c, acc)
	return acc

static func _clean_name(raw: String) -> String:
	# Godot appends numeric suffixes on name clashes; strip a trailing digits run.
	var s := raw
	while s.length() > 1 and s[s.length() - 1].is_valid_int():
		s = s.substr(0, s.length() - 1)
	return s

func _assign_materials(mi: MeshInstance3D, skin_tint: Color) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	var mats: Array = []
	var is_body := _clean_name(mi.name) == Wardrobe.BODY_MESH
	for i in mesh.get_surface_count():
		var src: Material = mesh.surface_get_material(i)
		var mname: String = String(src.resource_name) if src != null else String(mi.name)
		var mat: StandardMaterial3D
		if is_body and mname.findn("hair") != -1:
			# the nude body carries 5 per-outfit hairline / scalp-cap surfaces that
			# use hair materials; the real hair meshes cover the head, so hide them
			mat = StandardMaterial3D.new()
			mat.resource_name = mname + "_hidden"
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 1.0
			mat.albedo_color = Color(0, 0, 0, 0)
		else:
			mat = _mat_factory.build(mname, skin_tint)
		mi.set_surface_override_material(i, mat)
		mats.append(mat)
	_base_materials[mi] = mats

# ---------------------------------------------------------------------------
func apply_config(cfg: FrejaConfig) -> void:
	_current_config = cfg

	# 1. hide every garment mesh from every outfit; only the nude skin body + eyes
	#    stay on. Everything else is turned back on per the active piece list.
	for mesh_name in meshes.keys():
		if _is_garment(mesh_name):
			meshes[mesh_name].visible = false

	_set_visible(Wardrobe.BODY_MESH, true)
	for mesh_name in Wardrobe.SHARED_ALWAYS:
		_set_visible(mesh_name, true)

	# 2. active outfit's pieces + shared underwear pieces
	var piece_state: Dictionary = cfg.pieces
	for p in Wardrobe.pieces_for(cfg.outfit_id):
		var on: bool = piece_state.get(p["id"], p["on"])
		for mesh_name in p["meshes"]:
			_set_visible(mesh_name, on)

	# 3. skin tint
	_retint_skin(_skin_tint_for(cfg))

	# 4. hair / eye colour overrides
	_tint_meshes_by_material_kind(MaterialFactory.Kind.HAIR, cfg.hair_color)
	_tint_meshes_by_material_kind(MaterialFactory.Kind.EYE, cfg.eye_color)

	# 5. body shape morphs
	_apply_body_shape(cfg.body)

func _is_garment(mesh_name: String) -> bool:
	if mesh_name == Wardrobe.BODY_MESH:
		return false
	for s in Wardrobe.SHARED_ALWAYS:
		if mesh_name == s:
			return false
	return true

func _set_visible(mesh_name: String, v: bool) -> void:
	if meshes.has(mesh_name):
		meshes[mesh_name].visible = v

func _skin_tint_for(cfg: FrejaConfig) -> Color:
	if cfg.outfit_id != 0:
		return Color(1, 1, 1)
	match cfg.skin_color:
		1: return Color(1.03, 0.92, 0.90)   # Raudr - warm
		2: return Color(0.94, 0.96, 1.02)   # Syren - cool
		3: return Color(0.98, 0.95, 1.03)   # Lavendel
		4: return Color(1.04, 1.0, 0.92)    # Solsikke - golden
		_: return Color(1, 1, 1)            # OW2 neutral

func _retint_skin(tint: Color) -> void:
	for mi in _base_materials.keys():
		if not is_instance_valid(mi):
			continue
		var mats: Array = _base_materials[mi]
		for i in mats.size():
			var mat := mats[i] as StandardMaterial3D
			if mat == null:
				continue
			if _mat_factory.MAT.get(mat.resource_name, {}).get("kind", -1) == MaterialFactory.Kind.SKIN:
				var rebuilt := _mat_factory.build(mat.resource_name, tint)
				mi.set_surface_override_material(i, rebuilt)
				mats[i] = rebuilt

func _tint_meshes_by_material_kind(kind: int, color: Color) -> void:
	for mi in _base_materials.keys():
		if not is_instance_valid(mi):
			continue
		var mats: Array = _base_materials[mi]
		for i in mats.size():
			var mat := mats[i] as StandardMaterial3D
			if mat == null:
				continue
			if _mat_factory.MAT.get(mat.resource_name, {}).get("kind", -1) == kind:
				mat.albedo_color = color

func _apply_body_shape(body: Dictionary) -> void:
	for mi in meshes.values():
		var mesh: Mesh = mi.mesh
		if mesh == null or mesh.get_blend_shape_count() == 0:
			continue
		for si in mesh.get_blend_shape_count():
			var bs_name: String = String(mesh.get_blend_shape_name(si))
			if body.has(bs_name):
				mi.set_blend_shape_value(si, float(body[bs_name]))

# ---------------------------------------------------------------------------
func get_outfit_name(outfit_id: int) -> String:
	return Wardrobe.get_outfit(outfit_id)["name"]
