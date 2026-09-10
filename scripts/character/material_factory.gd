extends RefCounted
## Rebuilds Godot StandardMaterial3D for each glb material name using the loose
## textures in assets/textures/. Blender's procedural CloudRig shaders don't
## survive glTF, so we approximate: real texture where we have a clean match,
## a tasteful solid otherwise. Skin materials accept a runtime tint.

const TEX_DIR := "res://assets/textures/"

enum Kind { SKIN, HAIR, EYE, CLOTH, METAL, LEATHER, GLASS, TEETH, NAILS }

# mat name (from glb) -> { kind, albedo, normal, rough, metal }
const MAT := {
	"Freja_Body_Nude":      {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja_Body_OW2":       {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja Face":           {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja_Scarlett_Body":  {"kind": Kind.SKIN, "albedo": "Freja_Scarlett_Body_Diffuse", "normal": "Freja_Scarlett_Body_Normal"},
	"Streetwear_Body":      {"kind": Kind.CLOTH, "albedo": "Streetwear_Body_00000297C8629500"},
	"Streetwear_Decals":    {"kind": Kind.CLOTH, "albedo": "Streetwear_Decals_00000297B2033470"},
	"Archangel_Body":       {"kind": Kind.METAL, "color": Color(0.10, 0.11, 0.13)},
	"Freja_Body_FingerNails": {"kind": Kind.NAILS, "albedo": "Freja_FingerNails_Diffuse"},
	"Freja_Body_ToeNails":  {"kind": Kind.NAILS, "albedo": "Freja_ToeNails_Diffuse"},

	"Freja_Hair":                    {"kind": Kind.HAIR, "albedo": "Freja_Hair_Diffuse", "normal": "Freja_Hair_Normal"},
	"Freja_Scarlett_Hair":          {"kind": Kind.HAIR, "albedo": "Freja_Scarlett_Hair_Diffuse", "normal": "Freja_Hair_Normal"},
	"Streetwear_Hair":              {"kind": Kind.HAIR, "albedo": "Streetwear_Hair_Diffuse", "normal": "Streetwear_Hair_Normal"},
	"Archangel_Hair":               {"kind": Kind.HAIR, "color": Color(0.05, 0.05, 0.06)},
	"Freja_Heart_of_Courage_Hair":  {"kind": Kind.HAIR, "albedo": "Freja_Hair_Diffuse", "normal": "Freja_Hair_Normal"},

	"Freja Eye":   {"kind": Kind.EYE, "albedo": "Freja_Eye_Diffuse"},
	"Eye Inner":   {"kind": Kind.EYE, "albedo": "Eye Inner"},
	"Refract":     {"kind": Kind.GLASS},
	"Eye AO":      {"kind": Kind.GLASS},
	"Freja_Heart_of_Courage_Refraction": {"kind": Kind.GLASS},
	"Streetwear_Weapon_Glass": {"kind": Kind.GLASS},

	"Freja_Outfit_OW2": {"kind": Kind.CLOTH, "albedo": "Freja_Outfit_OW2_Diffuse", "normal": "Freja_Outfit_OW2_Normal",
		"rough": "Freja_Outfit_OW2_Roughness", "metal": "Freja_Outfit_OW2_Metallic"},
	"Freja_Heart_of_Courage_Body": {"kind": Kind.METAL, "albedo": "Freja_Heart_of_Courage_Body_Diffuse",
		"normal": "Freja_Heart_of_Courage_Body_Normal", "rough": "Freja_Heart_of_Courage_Body_Roughness",
		"metal": "Freja_Heart_of_Courage_Body_Metalness"},
	"Freja_Heart_of_Courage_Skirt": {"kind": Kind.CLOTH, "albedo": "Freja_Heart_of_Courage_Skirt_Diffuse",
		"normal": "Freja_Heart_of_Courage_Skirt_Normal", "rough": "Freja_Heart_of_Courage_Skirt_Roughness"},
	"Freja_SportsBra": {"kind": Kind.CLOTH, "albedo": "Sports_Bra_Text_Greyscale_Freja"},
	"Freja_Panties":   {"kind": Kind.CLOTH},
	"Freja_Stockings": {"kind": Kind.CLOTH, "albedo": "Freja_Stockings_Diffuse"},

	"Freja Teeth":  {"kind": Kind.TEETH},
	"Freja Tongue": {"kind": Kind.TEETH},
}

const FALLBACK := {
	Kind.SKIN:    {"color": Color(0.86, 0.66, 0.56), "rough": 0.55, "metal": 0.0},
	Kind.HAIR:    {"color": Color(0.20, 0.14, 0.10), "rough": 0.42, "metal": 0.0},
	Kind.EYE:     {"color": Color(0.35, 0.45, 0.55), "rough": 0.10, "metal": 0.0},
	Kind.CLOTH:   {"color": Color(0.24, 0.24, 0.27), "rough": 0.85, "metal": 0.0},
	Kind.METAL:   {"color": Color(0.55, 0.56, 0.60), "rough": 0.35, "metal": 0.9},
	Kind.LEATHER: {"color": Color(0.18, 0.13, 0.10), "rough": 0.6, "metal": 0.0},
	Kind.GLASS:   {"color": Color(0.9, 0.95, 1.0, 0.15), "rough": 0.05, "metal": 0.0},
	Kind.TEETH:   {"color": Color(0.93, 0.90, 0.86), "rough": 0.3, "metal": 0.0},
	Kind.NAILS:   {"color": Color(0.88, 0.7, 0.66), "rough": 0.25, "metal": 0.1},
}

var _cache := {}

func _tex(name_no_ext: String) -> Texture2D:
	if name_no_ext == "":
		return null
	for suffix in [".png", ".1001.png", ".jpg"]:
		var path: String = TEX_DIR + name_no_ext + str(suffix)
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func build(mat_name: String, skin_tint: Color = Color.WHITE) -> StandardMaterial3D:
	var cache_key := mat_name + "|" + str(skin_tint)
	if _cache.has(cache_key):
		return _cache[cache_key]

	var spec: Dictionary = MAT.get(mat_name, {"kind": Kind.CLOTH})
	var kind: int = spec.get("kind", Kind.CLOTH)
	var fb: Dictionary = FALLBACK[kind]
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name

	var base_color: Color = spec.get("color", fb["color"])
	var albedo := _tex(spec.get("albedo", ""))
	if albedo:
		m.albedo_texture = albedo
	m.albedo_color = base_color if albedo == null else Color.WHITE

	var nrm := _tex(spec.get("normal", ""))
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm

	var rough := _tex(spec.get("rough", ""))
	if rough:
		m.roughness_texture = rough
	else:
		m.roughness = fb["rough"]

	var metal := _tex(spec.get("metal", ""))
	if metal:
		m.metallic_texture = metal
		m.metallic = 1.0
	else:
		m.metallic = fb["metal"]

	match kind:
		Kind.SKIN:
			m.albedo_color = m.albedo_color * skin_tint if albedo else skin_tint
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.28
			m.subsurf_scatter_skin_mode = true
			m.rim_enabled = true
			m.rim = 0.2
		Kind.HAIR:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.45
			m.metallic_specular = 0.4
		Kind.EYE:
			m.roughness = 0.08
			m.metallic_specular = 0.7
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
		Kind.GLASS:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.85, 0.9, 1.0, 0.12)
			m.roughness = 0.03
			m.metallic = 0.0
			m.refraction_enabled = false
		Kind.METAL:
			m.metallic = 0.85 if metal == null else m.metallic
			m.roughness = 0.3 if rough == null else m.roughness
		_:
			pass

	# CloudRig meshes frequently have single-sided garment shells
	if kind in [Kind.CLOTH, Kind.LEATHER]:
		m.cull_mode = BaseMaterial3D.CULL_BACK

	_cache[cache_key] = m
	return m
