extends Node3D
## Demo map: textured grass ground, a wind-animated grass-blade layer, and
## scattered Kenney Nature Kit props (trees, rocks, bushes, flowers). Trees get
## trunk collision; a ring wall keeps the player in the play area.

const MAP_RADIUS := 44.0
const PROP_FIELD := 40.0
const GRASS_BLADES := 40000
const GRASS_FIELD := 31.0

const PROPS := "res://assets/props/"
const TREE_MODELS := [
	"tree_default.glb", "tree_oak.glb", "tree_detailed.glb",
	"tree_pineRoundA.glb", "tree_pineRoundC.glb", "tree_pineTallA.glb", "tree_thin.glb",
]
const ROCK_MODELS := ["rock_largeA.glb", "rock_largeC.glb", "rock_largeE.glb",
	"rock_smallA.glb", "rock_smallC.glb"]
const BUSH_MODELS := ["plant_bush.glb", "plant_bushLarge.glb", "plant_bushDetailed.glb",
	"grass_large.glb", "grass_leafsLarge.glb"]

const PropKit := preload("res://scripts/world/prop_kit.gd")

const TREE_SCALE := 3.2
const PROP_SCALE := 1.7

var _rng := RandomNumberGenerator.new()
var _kit := PropKit.new()

func _ready() -> void:
	_rng.seed = 20260910
	_build_ground()
	_build_grass()
	# keep a clear ~7m ring around spawn so the wardrobe preview camera never
	# ends up inside foliage
	_scatter(TREE_MODELS, 40, 11.0, TREE_SCALE, Vector2(0.8, 1.45), true)
	_scatter(ROCK_MODELS, 24, 8.0, PROP_SCALE, Vector2(0.5, 1.6), false)
	_scatter(BUSH_MODELS, 64, 7.5, PROP_SCALE, Vector2(0.7, 1.5), false)
	_scatter(["flower_redA.glb", "flower_yellowA.glb", "flower_purpleA.glb"], 80, 7.0, 1.4, Vector2(0.7, 1.2), false)
	_scatter(["log.glb", "mushroom_redGroup.glb"], 12, 9.0, 1.3, Vector2(0.7, 1.1), false)
	_build_boundary()

# ---------------------------------------------------------------------------
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_RADIUS * 3.0, MAP_RADIUS * 3.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _load_tex("grass_diff")
	mat.normal_enabled = true
	mat.normal_texture = _load_tex("grass_nor_gl")
	mat.roughness_texture = _load_tex("grass_rough")
	mat.uv1_scale = Vector3(26, 26, 26)
	mat.uv1_triplanar = false
	mat.albedo_color = Color(0.62, 0.78, 0.5)

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(MAP_RADIUS * 3.2, 1.0, MAP_RADIUS * 3.2)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)

func _load_tex(base: String) -> Texture2D:
	var p := "res://assets/textures/ground/" + base + ".jpg"
	return load(p) if ResourceLoader.exists(p) else null

# ---------------------------------------------------------------------------
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.2
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
	# Prefer the Kenney grass tuft (real 3D geometry); fall back to procedural blades.
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
	mat.set_shader_parameter("sway_height", 0.2)
	mat.set_shader_parameter("wind_strength", 0.045)
	mat.set_shader_parameter("tip_color", Vector3(0.46, 0.6, 0.26))
	mat.set_shader_parameter("root_color", Vector3(0.13, 0.24, 0.08))

	for i in GRASS_BLADES:
		var r := sqrt(_rng.randf()) * GRASS_FIELD
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		var sc := _rng.randf_range(0.4, 1.05)
		basis = basis.scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.5), sc))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var g := _rng.randf_range(0.78, 1.16)
		mm.set_instance_color(i, Color(g * 0.82, g, g * 0.52))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassBlades"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-GRASS_FIELD, 0, -GRASS_FIELD),
		Vector3(GRASS_FIELD * 2, 1.2, GRASS_FIELD * 2))
	add_child(mmi)

# ---------------------------------------------------------------------------
func _scatter(models: Array, count: int, inner: float, base_scale: float,
		scale_range: Vector2, collide: bool) -> void:
	var cache := {}
	var group := Node3D.new()
	group.name = "Scatter_" + models[0].get_basename()
	add_child(group)

	for _i in count:
		var m: String = models[_rng.randi() % models.size()]
		if not cache.has(m):
			var path := PROPS + m
			cache[m] = load(path) if ResourceLoader.exists(path) else null
		var packed: PackedScene = cache[m]
		if packed == null:
			continue
		var inst := packed.instantiate()
		_kit.fix(inst)
		var r := _rng.randf_range(inner, PROP_FIELD)
		var ang := _rng.randf() * TAU
		inst.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		inst.rotation.y = _rng.randf() * TAU
		var s := base_scale * _rng.randf_range(scale_range.x, scale_range.y)
		inst.scale = Vector3(s, s * _rng.randf_range(0.9, 1.15), s)
		group.add_child(inst)

		if collide:
			var sb := StaticBody3D.new()
			sb.position = inst.position
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35 * (s / base_scale)
			cyl.height = 5.0
			cs.shape = cyl
			cs.position.y = 2.5
			sb.add_child(cs)
			add_child(sb)

# ---------------------------------------------------------------------------
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	var seg := 26
	for i in seg:
		var a := TAU * i / seg
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(MAP_RADIUS * TAU / seg + 1.0, 8.0, 1.0)
		wall.shape = box
		wall.position = Vector3(cos(a) * MAP_RADIUS, 4.0, sin(a) * MAP_RADIUS)
		wall.rotation.y = -a
		body.add_child(wall)
	add_child(body)
