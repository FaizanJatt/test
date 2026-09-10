extends RefCounted
## The Kenney Nature Kit GLTF pack ships with placeholder material colours (teal
## foliage, salmon bark) and metallic=1. This remaps every prop material by name
## to a natural palette and fixes the PBR values. Materials are cached and shared.

# muted, slightly desaturated palette so the low-poly trees sit better next to
# the photoscanned ground / rocks
const PALETTE := {
	"leafsGreen":   Color(0.24, 0.34, 0.15),
	"leafsDark":    Color(0.16, 0.25, 0.11),
	"grass":        Color(0.28, 0.4, 0.18),
	"woodBark":     Color(0.28, 0.21, 0.15),
	"woodBarkDark": Color(0.2, 0.15, 0.11),
	"woodInner":    Color(0.55, 0.44, 0.31),
	"dirt":         Color(0.33, 0.25, 0.18),
	"colorRed":     Color(0.6, 0.2, 0.2),
	"colorYellow":  Color(0.82, 0.66, 0.24),
	"colorPurple":  Color(0.44, 0.33, 0.62),
	"_defaultMat":  Color(0.5, 0.5, 0.5),
}

var _cache := {}

func _mat(name: String) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]
	var m := StandardMaterial3D.new()
	var is_leaf := name.begins_with("leafs") or name == "grass"
	m.albedo_color = PALETTE.get(name, Color(0.5, 0.5, 0.5))
	m.metallic = 0.0
	m.roughness = 0.98 if is_leaf else 0.9
	m.metallic_specular = 0.2
	# break the flat-shaded look: a touch of vertex-driven AO + soft leaf translucency
	if is_leaf:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.1, 0.16, 0.06)
		m.roughness = 1.0
	_cache[name] = m
	return m

func fix(root: Node) -> void:
	for mi in _mesh_instances(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var n := src.resource_name if src else "_defaultMat"
			mi.set_surface_override_material(s, _mat(n))

func _mesh_instances(n: Node, acc: Array = []) -> Array:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_mesh_instances(c, acc)
	return acc
