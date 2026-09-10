extends Node3D
## Builds the demo map: rolling grass ground, wind-animated grass, scattered
## trees / rocks, a soft boundary and some fill props. Everything procedural so
## there are no binary scene deps.

const MAP_RADIUS := 46.0
const GRASS_BLADES := 55000
const GRASS_FIELD := 40.0
const TREE_COUNT := 46
const ROCK_COUNT := 30

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20260910
	_build_ground()
	_build_grass()
	_build_trees()
	_build_rocks()
	_build_boundary()

# ---------------------------------------------------------------------------
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_RADIUS * 2.4, MAP_RADIUS * 2.4)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.19, 0.28, 0.12)
	mat.roughness = 1.0
	var noise_tex := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_tex.noise = n
	noise_tex.width = 512
	noise_tex.height = 512
	mat.albedo_texture = noise_tex
	mat.uv1_scale = Vector3(24, 24, 24)
	mat.detail_enabled = false

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
	box.size = Vector3(MAP_RADIUS * 3.0, 1.0, MAP_RADIUS * 3.0)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)

# ---------------------------------------------------------------------------
func _blade_mesh() -> ArrayMesh:
	# a small tuft: two crossed, tapered, slightly-curved blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.24
	var w := 0.022
	var segs := 3
	for a in [0.0, 1.5708]:
		var dir := Vector3(cos(a), 0, sin(a))
		var prev_y := 0.0
		for s in segs:
			var y0 := h * float(s) / segs
			var y1 := h * float(s + 1) / segs
			var w0 := w * (1.0 - float(s) / segs)
			var w1 := w * (1.0 - float(s + 1) / segs)
			var bend0 := 0.04 * (y0 / h) * (y0 / h)
			var bend1 := 0.04 * (y1 / h) * (y1 / h)
			var p := [
				dir * -w0 + Vector3(0, y0, bend0), dir * w0 + Vector3(0, y0, bend0),
				dir * w1 + Vector3(0, y1, bend1), dir * -w1 + Vector3(0, y1, bend1),
			]
			var v0 := y0 / h
			var v1 := y1 / h
			var uv := [Vector2(0, 1 - v0), Vector2(1, 1 - v0), Vector2(1, 1 - v1), Vector2(0, 1 - v1)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for i in tri:
					st.set_uv(uv[i])
					st.set_normal(Vector3.UP)
					st.add_vertex(p[i])
	return st.commit()

func _blade_texture() -> ImageTexture:
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _build_grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	mm.instance_count = GRASS_BLADES

	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/grass.gdshader")
	mat.set_shader_parameter("blade_tex", _blade_texture())
	mat.set_shader_parameter("sway_height", 0.24)
	mat.set_shader_parameter("wind_strength", 0.05)
	mat.set_shader_parameter("tip_color", Vector3(0.52, 0.63, 0.28))
	mat.set_shader_parameter("root_color", Vector3(0.12, 0.22, 0.09))

	for i in GRASS_BLADES:
		var r := sqrt(_rng.randf()) * GRASS_FIELD
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		var sc := _rng.randf_range(0.75, 1.5)
		basis = basis.scaled(Vector3(sc, _rng.randf_range(0.7, 1.7), sc))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var g := _rng.randf_range(0.8, 1.12)
		mm.set_instance_color(i, Color(g * 0.85, g, g * 0.6))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-GRASS_FIELD, 0, -GRASS_FIELD), Vector3(GRASS_FIELD * 2, 2, GRASS_FIELD * 2))
	add_child(mmi)

# ---------------------------------------------------------------------------
func _tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.28
	trunk.height = 3.2
	trunk.radial_segments = 7

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.6, 0)))

	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 10
	canopy.rings = 6
	for off in [Vector3(0, 4.1, 0), Vector3(0.9, 3.4, 0.3), Vector3(-0.7, 3.6, -0.6), Vector3(0.2, 4.7, -0.5)]:
		var s := _rng.randf_range(0.9, 1.5)
		st.append_from(canopy, 0, Transform3D(Basis().scaled(Vector3(s, s * 0.8, s)), off))
	st.generate_normals()
	return st.commit()

func _build_trees() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.20, 0.14, 0.10)
	trunk_mat.roughness = 1.0
	var mesh := _tree_mesh()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = TREE_COUNT

	var placed := 0
	while placed < TREE_COUNT:
		var r := _rng.randf_range(9.0, MAP_RADIUS - 3.0)
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.6))
		mm.set_instance_transform(placed, Transform3D(b, pos))
		var tint := _rng.randf_range(0.7, 1.15)
		mm.set_instance_color(placed, Color(0.35 * tint, 0.5 * tint, 0.24 * tint))
		# collision trunk
		var sb := StaticBody3D.new()
		sb.position = pos
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 4.0
		cs.shape = cyl
		cs.position.y = 2.0
		sb.add_child(cs)
		add_child(sb)
		placed += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	var foliage := StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo = true
	foliage.roughness = 0.95
	mmi.material_override = foliage
	add_child(mmi)

# ---------------------------------------------------------------------------
func _build_rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock := SphereMesh.new()
	rock.radius = 0.6
	rock.height = 0.9
	rock.radial_segments = 6
	rock.rings = 4
	mm.mesh = rock
	mm.instance_count = ROCK_COUNT
	for i in ROCK_COUNT:
		var r := _rng.randf_range(6.0, MAP_RADIUS - 2.0)
		var ang := _rng.randf() * TAU
		var pos := Vector3(cos(ang) * r, _rng.randf_range(-0.35, 0.0), sin(ang) * r)
		var b := Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), _rng.randf() * TAU)
		b = b.scaled(Vector3(_rng.randf_range(0.4, 1.6), _rng.randf_range(0.3, 0.9), _rng.randf_range(0.4, 1.4)))
		mm.set_instance_transform(i, Transform3D(b, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.35, 0.36)
	m.roughness = 0.95
	mmi.material_override = m
	add_child(mmi)

# ---------------------------------------------------------------------------
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	var seg := 24
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
