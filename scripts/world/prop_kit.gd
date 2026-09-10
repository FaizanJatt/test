extends RefCounted
## The Kenney Nature Kit GLTF pack ships with placeholder material colours (teal
## foliage, salmon bark) and metallic=1. This remaps every prop material by name
## to a natural palette and fixes the PBR values. Materials are cached and shared.

const PALETTE := {
	"leafsGreen":   Color(0.29, 0.45, 0.16),
	"leafsDark":    Color(0.19, 0.33, 0.12),
	"grass":        Color(0.34, 0.5, 0.2),
	"woodBark":     Color(0.33, 0.23, 0.15),
	"woodBarkDark": Color(0.25, 0.17, 0.11),
	"woodInner":    Color(0.66, 0.52, 0.36),
	"dirt":         Color(0.38, 0.28, 0.19),
	"colorRed":     Color(0.72, 0.19, 0.2),
	"colorYellow":  Color(0.92, 0.72, 0.22),
	"colorPurple":  Color(0.5, 0.36, 0.72),
	"_defaultMat":  Color(0.55, 0.55, 0.55),
}

var _cache := {}

func _mat(name: String) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]
	var m := StandardMaterial3D.new()
	m.albedo_color = PALETTE.get(name, Color(0.5, 0.5, 0.5))
	m.metallic = 0.0
	m.roughness = 0.92
	m.metallic_specular = 0.35
	if name.begins_with("leafs") or name == "grass":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
