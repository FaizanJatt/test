extends RefCounted
## Rebuilds a Godot StandardMaterial3D for every glb material, using the real
## outfit textures extracted from the Blender file (assets/textures/outfits/,
## with assets/textures/ as fallback). Skin materials take a runtime tint.

const DIRS := ["res://assets/textures/outfits/", "res://assets/textures/"]

enum Kind { SKIN, HAIR, EYE, CLOTH, METAL, GLASS, TEETH, NAILS }

# glb material name -> { kind, albedo, normal, orm (roughness/metal), alpha }
const MAT := {
	"Freja_Body_Nude":  {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja_Body_OW2":   {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja Face":       {"kind": Kind.SKIN, "albedo": "Freja_Body_Diffuse", "normal": "Freja_Body_Normal"},
	"Freja_Scarlett_Body": {"kind": Kind.SKIN, "albedo": "Freja_Scarlett_Body_Diffuse", "normal": "Freja_Scarlett_Body_Normal"},
	"Freja_Body_FingerNails": {"kind": Kind.NAILS, "albedo": "Freja_FingerNails_Diffuse"},
	"Freja_Body_ToeNails":    {"kind": Kind.NAILS, "albedo": "Freja_ToeNails_Diffuse"},

	"Freja_Outfit_OW2": {"kind": Kind.CLOTH, "albedo": "Freja_Outfit_OW2_Diffuse",
		"normal": "Freja_Outfit_OW2_Normal", "rough": "Freja_Outfit_OW2_Roughness", "metal": "Freja_Outfit_OW2_Metallic"},
	"Freja_Heart_of_Courage_Body": {"kind": Kind.METAL, "albedo": "Freja_Heart_of_Courage_Body_Diffuse",
		"normal": "Freja_Heart_of_Courage_Body_Normal", "rough": "Freja_Heart_of_Courage_Body_Roughness",
		"metal": "Freja_Heart_of_Courage_Body_Metalness"},
	"Freja_Heart_of_Courage_Skirt": {"kind": Kind.CLOTH, "albedo": "Freja_Heart_of_Courage_Skirt_Diffuse",
		"normal": "Freja_Heart_of_Courage_Skirt_Normal", "rough": "Freja_Heart_of_Courage_Skirt_Roughness"},
	"Freja_Scarlett_Body_Outfit": {"kind": Kind.CLOTH, "albedo": "Freja_Scarlett_Body_Diffuse"},
	"Streetwear_Body":  {"kind": Kind.CLOTH, "albedo": "Streetwear_Body_Diffuse", "rough": "Streetwear_Body_PBR"},
	"Streetwear_Decals": {"kind": Kind.CLOTH, "albedo": "Streetwear_Decals_00000297B2033470", "alpha": true},
	"Archangel_Body":   {"kind": Kind.METAL, "albedo": "Archangel_Body_Diffuse",
		"normal": "Archangel_Body_Normal", "rough": "Archangel_Body_PBR"},

	"Freja_Hair":                   {"kind": Kind.HAIR, "albedo": "Freja_Hair_Diffuse", "normal": "Freja_Hair_Normal"},
	"Freja_Scarlett_Hair":          {"kind": Kind.HAIR, "albedo": "Freja_Scarlett_Hair_Diffuse"},
	"Streetwear_Hair":              {"kind": Kind.HAIR, "albedo": "Streetwear_Hair_Diffuse", "normal": "Streetwear_Hair_Normal"},
	"Archangel_Hair":               {"kind": Kind.HAIR, "albedo": "Archangel_Hair_Diffuse"},
	"Freja_Heart_of_Courage_Hair":  {"kind": Kind.HAIR, "albedo": "Freja_Hair_HOC_Gradient"},

	"Freja Eye":  {"kind": Kind.EYE, "albedo": "Freja_Eye_Diffuse", "normal": "Eye_Normal_2"},
	"Eye Inner":  {"kind": Kind.EYE, "albedo": "Eye_Inner"},
	"Eye AO":     {"kind": Kind.GLASS},
	"Refract":    {"kind": Kind.GLASS},
	"Freja_Heart_of_Courage_Refraction": {"kind": Kind.GLASS},
	"Streetwear_Weapon_Glass": {"kind": Kind.GLASS},

	"Freja_SportsBra": {"kind": Kind.CLOTH, "color": Color(0.12, 0.12, 0.14)},
	"Freja_Panties":   {"kind": Kind.CLOTH, "color": Color(0.12, 0.12, 0.14)},
	"Freja_Stockings": {"kind": Kind.CLOTH, "albedo": "Stockings_Pattern"},
	"Freja Teeth":  {"kind": Kind.TEETH},
	"Freja Tongue": {"kind": Kind.TEETH, "color": Color(0.7, 0.4, 0.42)},
}

const FALLBACK := {
	Kind.SKIN:  {"color": Color(0.86, 0.66, 0.56), "rough": 0.5},
	Kind.HAIR:  {"color": Color(0.2, 0.14, 0.1), "rough": 0.42},
	Kind.EYE:   {"color": Color(0.35, 0.45, 0.55), "rough": 0.1},
	Kind.CLOTH: {"color": Color(0.24, 0.24, 0.27), "rough": 0.85},
	Kind.METAL: {"color": Color(0.55, 0.56, 0.6), "rough": 0.35},
	Kind.GLASS: {"color": Color(0.85, 0.9, 1.0, 0.12), "rough": 0.05},
	Kind.TEETH: {"color": Color(0.93, 0.9, 0.86), "rough": 0.3},
	Kind.NAILS: {"color": Color(0.88, 0.7, 0.66), "rough": 0.25},
}

var _cache := {}

func _tex(name_no_ext: String) -> Texture2D:
	if name_no_ext == "":
		return null
	for d in DIRS:
		for suffix in [".png", ".jpg", ".1001.png"]:
			var path: String = d + name_no_ext + str(suffix)
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null

func build(mat_name: String, skin_tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := mat_name + "|" + str(skin_tint)
	if _cache.has(key):
		return _cache[key]

	var spec: Dictionary = MAT.get(mat_name, {"kind": Kind.CLOTH})
	var kind: int = spec.get("kind", Kind.CLOTH)
	var fb: Dictionary = FALLBACK[kind]
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name

	var albedo := _tex(spec.get("albedo", ""))
	if albedo:
		m.albedo_texture = albedo
		m.albedo_color = Color.WHITE
	else:
		m.albedo_color = spec.get("color", fb["color"])

	var nrm := _tex(spec.get("normal", ""))
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm

	var rough := _tex(spec.get("rough", ""))
	if rough:
		m.roughness_texture = rough
		m.roughness = 1.0
	else:
		m.roughness = fb["rough"]

	var metal := _tex(spec.get("metal", ""))
	if metal:
		m.metallic_texture = metal
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.metallic = 1.0
	else:
		m.metallic = 0.0

	match kind:
		Kind.SKIN:
			m.albedo_color = (Color.WHITE if albedo else fb["color"]) * skin_tint
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.22
			m.subsurf_scatter_skin_mode = true
			m.roughness = 0.55
			m.metallic = 0.0
		Kind.HAIR:
			# low threshold so the scalp / hairline surfaces on Freja_Nude_Body
			# don't get punched full of holes; still trims hair-card silhouettes
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.12
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.5
			m.metallic = 0.0
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON
			if albedo == null:
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		Kind.EYE:
			m.roughness = 0.08
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
			m.metallic = 0.0
		Kind.GLASS:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.85, 0.9, 1.0, 0.1)
			m.roughness = 0.05
			m.metallic = 0.0
		Kind.METAL:
			if metal == null:
				m.metallic = 0.6
			if rough == null:
				m.roughness = 0.35
		_:
			pass

	if spec.get("alpha", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5

	_cache[key] = m
	return m
