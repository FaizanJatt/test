extends SceneTree
## Pack the loose Poly Haven maps into the RGBA layout Terrain3D wants:
##   albedo_texture  = albedo.rgb  + displacement -> alpha  (height blending)
##   normal_texture  = normal.rgb  + roughness    -> alpha
## Saves them next to the sources. Run once, commit the output.
##
##   godot --headless --path . --script tools/pack_terrain_textures.gd

const SRC := "res://assets/textures/terrain/src/"
const OUT := "res://assets/textures/terrain/"
const NAMES := ["lawn_grass", "gray_rocks", "forrest_ground_01"]
const SIZE := 512      # plenty for a tiling ground texture; keeps the APK small

func _init() -> void:
	for n in NAMES:
		_pack(n)
	print("done")
	quit()

func _pack(n: String) -> void:
	var alb := _img(SRC + n + "_diff.jpg")
	var disp := _img(SRC + n + "_disp.jpg")
	var nrm := _img(SRC + n + "_nor_gl.jpg")
	var rgh := _img(SRC + n + "_rough.jpg")
	if alb == null or nrm == null:
		push_error("missing maps for " + n)
		return
	var w := SIZE
	var h := SIZE
	alb.resize(w, h)
	nrm.resize(w, h)
	if disp: disp.resize(w, h)
	if rgh: rgh.resize(w, h)

	var albedo := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var normal := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := alb.get_pixel(x, y)
			a.a = disp.get_pixel(x, y).r if disp else 0.5
			albedo.set_pixel(x, y, a)
			var nn := nrm.get_pixel(x, y)
			nn.a = rgh.get_pixel(x, y).r if rgh else 0.85
			normal.set_pixel(x, y, nn)
	albedo.save_webp(ProjectSettings.globalize_path(OUT + n + "_alb_ht.webp"), true, 0.92)
	normal.save_webp(ProjectSettings.globalize_path(OUT + n + "_nrm_rgh.webp"), true, 0.92)
	print("packed ", n, " (", w, "x", h, ")")

func _img(path: String) -> Image:
	var p := ProjectSettings.globalize_path(path)
	var im := Image.new()
	if im.load(p) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im
