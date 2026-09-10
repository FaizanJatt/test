extends Node3D
## Demo map: a Terrain3D heightmap with a PBR grass/rock auto-blend (Poly Haven
## CC0), a wind-animated grass-blade layer, and scattered props - all dropped
## onto the terrain surface. A ring wall keeps the player in the play area.

const MAP_RADIUS := 150.0
const PROP_FIELD := 130.0
const GRASS_BLADES := 46000
const GRASS_FIELD := 46.0

const PROPS := "res://assets/props/"
const PH := "res://assets/props/polyhaven/"

# Kenney low-poly trees (kept for the silhouettes; prop_kit tones them down)
const TREE_MODELS := [
	"tree_default.glb", "tree_oak.glb", "tree_detailed.glb",
	"tree_pineRoundA.glb", "tree_pineRoundC.glb", "tree_pineTallA.glb", "tree_thin.glb",
]
# Poly Haven CC0 photoscans (loaded from polyhaven/<slug>/<slug>.gltf)
const PH_ROCKS := ["boulder_01", "namaqualand_boulder_02", "namaqualand_boulder_04", "namaqualand_rocks_01"]
const PH_DEADFALL := ["dead_tree_trunk", "tree_stump_01", "tree_stump_02", "dry_branches_medium_01"]
const PH_DETAIL := ["fern_02", "grass_medium_01", "grass_medium_02", "moss_01"]

const PropKit := preload("res://scripts/world/prop_kit.gd")
const TerrainScript := preload("res://scripts/world/terrain.gd")

const TREE_SCALE := 3.2
const PROP_SCALE := 1.0

var _rng := RandomNumberGenerator.new()
var _kit := PropKit.new()
var _terrain: Node3D
var _cam_hooked := false
var _tree_mats := {}   # foliage colour -> shared wind ShaderMaterial

func _tree_mat(col: Color, leaf: bool) -> ShaderMaterial:
	var key := "%s_%s" % [col, leaf]
	if _tree_mats.has(key):
		return _tree_mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/world/tree_wind.gdshader")
	sm.set_shader_parameter("albedo", Vector3(col.r, col.g, col.b))
	sm.set_shader_parameter("sway", 0.07 if leaf else 0.02)
	sm.set_shader_parameter("stiffness", 2.4 if leaf else 3.4)
	sm.set_shader_parameter("backlight", Vector3(0.10, 0.16, 0.06) if leaf else Vector3(0.0, 0.0, 0.0))
	_tree_mats[key] = sm
	return sm

func _ready() -> void:
	_rng.seed = 20260910
	_terrain = TerrainScript.new()
	_terrain.name = "Terrain"
	add_child(_terrain)
	_terrain.build(null)

	_build_grass()
	# keep a clear ~11m ring around spawn so the wardrobe preview camera never
	# ends up inside foliage
	_scatter(TREE_MODELS, 78, 14.0, TREE_SCALE, Vector2(0.7, 1.8), true, PROPS, "glb", true)
	_scatter(PH_ROCKS, 34, 10.0, 1.0, Vector2(0.5, 2.6), true, PH, "gltf")
	_scatter(PH_DEADFALL, 20, 11.0, 1.0, Vector2(0.7, 1.5), false, PH, "gltf")
	_scatter(["flower_redA.glb", "flower_yellowA.glb", "flower_purpleA.glb"], 140, 8.0, 1.4, Vector2(0.7, 1.3), false, PROPS, "glb")
	_detail_scatter("fern_02", 120, 9.0, Vector2(0.7, 1.5))
	_detail_scatter("grass_medium_02", 220, 6.0, Vector2(0.8, 1.7))
	_detail_scatter("moss_01", 320, 6.0, Vector2(1.2, 3.5))
	_build_boundary()

func _process(_dt: float) -> void:
	# Terrain3D needs the active camera for its clipmap LOD; grab it once it exists
	if not _cam_hooked:
		var c := get_viewport().get_camera_3d()
		if c:
			_terrain.terrain.call("set_camera", c)
			_cam_hooked = true

func terrain_height(pos: Vector3) -> float:
	return _terrain.height(pos) if _terrain else 0.0

# ---------------------------------------------------------------------------
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.22
	var w := 0.016
	var segs := 4
	for a in [0.0, 1.0472, 2.0944]:
		var dir := Vector3(cos(a), 0, sin(a))
		for s in segs:
			var y0 := h * float(s) / segs
			var y1 := h * float(s + 1) / segs
			var w0 := w * (1.0 - float(s) / float(segs))
			var w1 := w * (1.0 - float(s + 1) / float(segs))
			var b0 := 0.05 * pow(y0 / h, 2.0)
			var b1 := 0.05 * pow(y1 / h, 2.0)
			var p := [
				dir * -w0 + Vector3(0, y0, b0), dir * w0 + Vector3(0, y0, b0),
				dir * w1 + Vector3(0, y1, b1), dir * -w1 + Vector3(0, y1, b1),
			]
			var uv := [Vector2(0, 1 - y0 / h), Vector2(1, 1 - y0 / h),
				Vector2(1, 1 - y1 / h), Vector2(0, 1 - y1 / h)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for i in tri:
					st.set_uv(uv[i])
					st.set_normal(Vector3.UP)
					st.add_vertex(p[i])
	return st.commit()

func _grass_tuft_mesh() -> Mesh:
	var path := PROPS + "grass.glb"
	if ResourceLoader.exists(path):
		var scn: PackedScene = load(path)
		var root := scn.instantiate()
		for mi in _kit._mesh_instances(root):
			var m: Mesh = mi.mesh
			root.queue_free()
			return m
		root.queue_free()
	return _blade_mesh()

func _build_grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_tuft_mesh()
	mm.instance_count = GRASS_BLADES

	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/grass.gdshader")
	mat.set_shader_parameter("sway_height", 0.22)
	mat.set_shader_parameter("wind_strength", 0.05)
	mat.set_shader_parameter("tip_color", Vector3(0.44, 0.57, 0.24))
	mat.set_shader_parameter("root_color", Vector3(0.12, 0.22, 0.07))

	for i in GRASS_BLADES:
		var r := sqrt(_rng.randf()) * GRASS_FIELD
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pos.y = terrain_height(pos)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		var sc := _rng.randf_range(0.45, 1.15)
		basis = basis.scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.6), sc))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var g := _rng.randf_range(0.72, 1.18)
		mm.set_instance_color(i, Color(g * 0.8, g, g * 0.5))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassBlades"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-GRASS_FIELD, -20, -GRASS_FIELD),
		Vector3(GRASS_FIELD * 2, 40, GRASS_FIELD * 2))
	add_child(mmi)

# ---------------------------------------------------------------------------
func _model_path(m: String, base: String, ext: String) -> String:
	return "%s%s/%s.%s" % [base, m, m, ext] if ext == "gltf" else base + m

func _scatter(models: Array, count: int, inner: float, base_scale: float,
		scale_range: Vector2, collide: bool, base := PROPS, ext := "glb", wind := false) -> void:
	var cache := {}
	var group := Node3D.new()
	group.name = "Scatter_" + String(models[0]).get_basename()
	add_child(group)
	var is_ph := ext == "gltf"

	for _i in count:
		var m: String = models[_rng.randi() % models.size()]
		if not cache.has(m):
			var path := _model_path(m, base, ext)
			cache[m] = load(path) if ResourceLoader.exists(path) else null
		var packed: PackedScene = cache[m]
		if packed == null:
			continue
		var inst := packed.instantiate()
		if is_ph:
			_fix_ph(inst)
		elif wind:
			_windify(inst)
		else:
			_kit.fix(inst)
		var r := _rng.randf_range(inner, PROP_FIELD)
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pos.y = terrain_height(pos) - (0.12 if is_ph else 0.05)
		inst.position = pos
		inst.rotation = Vector3(
			_rng.randf_range(-0.06, 0.06) if is_ph else 0.0,
			_rng.randf() * TAU,
			_rng.randf_range(-0.06, 0.06) if is_ph else 0.0)
		var s := base_scale * _rng.randf_range(scale_range.x, scale_range.y)
		inst.scale = Vector3(s, s * _rng.randf_range(0.9, 1.15), s)
		group.add_child(inst)

		if collide:
			var sb := StaticBody3D.new()
			sb.position = pos
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = (0.5 if is_ph else 0.35) * s
			cyl.height = 6.0
			cs.shape = cyl
			cs.position.y = 2.0
			sb.add_child(cs)
			add_child(sb)

## swap the Kenney tree's flat materials for the wind shader (muted palette,
## leaf translucency, canopy sway)
func _windify(root: Node) -> void:
	for mi in _kit._mesh_instances(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var n := String(src.resource_name) if src else "_defaultMat"
			var leaf := n.begins_with("leafs") or n == "grass"
			var col: Color = _kit.PALETTE.get(n, Color(0.4, 0.3, 0.2))
			mi.set_surface_override_material(s, _tree_mat(col, leaf))

## alpha-scissor foliage, kill the metal the gltf importer sometimes leaves on
func _fix_ph(root: Node) -> void:
	for mi in _kit._mesh_instances(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			mat = mat.duplicate()
			mat.metallic = 0.0
			if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
					or mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.5
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.backlight_enabled = true
				mat.backlight = Color(0.16, 0.22, 0.1)
			mi.set_surface_override_material(s, mat)

## dense ground detail as one MultiMesh draw (Poly Haven foliage)
func _detail_scatter(model: String, count: int, inner: float, scale_range: Vector2) -> void:
	var path := _model_path(model, PH, "gltf")
	if not ResourceLoader.exists(path):
		return
	var src := (load(path) as PackedScene).instantiate()
	_fix_ph(src)
	var mis := _kit._mesh_instances(src)
	if mis.is_empty():
		return
	var proto: MeshInstance3D = mis[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = proto.mesh
	mm.instance_count = count
	var field := PROP_FIELD * 0.55
	for i in count:
		var r := sqrt(_rng.randf()) * field + inner
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pos.y = terrain_height(pos) - 0.06
		var b := Basis(Vector3.UP, _rng.randf() * TAU)
		var sc := _rng.randf_range(scale_range.x, scale_range.y)
		b = b.scaled(Vector3(sc, sc * _rng.randf_range(0.85, 1.25), sc))
		mm.set_instance_transform(i, Transform3D(b, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Detail_" + model
	mmi.multimesh = mm
	if proto.mesh.get_surface_count() > 0:
		mmi.material_override = proto.get_active_material(0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-field - inner, -20, -field - inner), Vector3((field + inner) * 2, 40, (field + inner) * 2))
	add_child(mmi)
	src.queue_free()

# ---------------------------------------------------------------------------
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	var seg := 40
	for i in seg:
		var a := TAU * i / seg
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(MAP_RADIUS * TAU / seg + 1.0, 40.0, 1.0)
		wall.shape = box
		var p := Vector3(cos(a) * MAP_RADIUS, 0.0, sin(a) * MAP_RADIUS)
		p.y = terrain_height(p) + 10.0
		wall.position = p
		wall.rotation.y = -a
		body.add_child(wall)
	add_child(body)
