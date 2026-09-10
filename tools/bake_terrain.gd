extends SceneTree
## Offline bake: generate the Terrain3D region data for the demo map from noise
## (gentle rolling hills, a flat clearing at spawn, auto-shader enabled so the
## runtime material blends grass on flat ground / rock on the slopes).
##
##   godot --headless --path . --script tools/bake_terrain.gd
##
## Writes res://assets/terrain/*.res  (commit these).

const DATA_DIR := "res://assets/terrain"
const REGION := 256            # region_size
const SPACING := 1.0           # metres per vertex
const HALF := 192              # map extends +/- this many metres from origin
const CLEARING := 9.0          # flat radius around spawn
const HILL_AMP := 8.5
const RIDGE_AMP := 6.0

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var t: Node = ClassDB.instantiate("Terrain3D")
	t.set("region_size", REGION)
	t.set("vertex_spacing", SPACING)
	t.set("data_directory", DATA_DIR)
	get_root().add_child(t)
	await process_frame
	await process_frame
	var data = t.get("data")

	# regions covering [-HALF, HALF] on both axes
	var rmin := int(floor(-HALF / float(REGION)))
	var rmax := int(floor((HALF - 1) / float(REGION)))
	for rx in range(rmin, rmax + 1):
		for rz in range(rmin, rmax + 1):
			data.add_region_blank(Vector2i(rx, rz))
	await process_frame
	print("regions: ", data.get_region_count())

	var base := FastNoiseLite.new()
	base.noise_type = FastNoiseLite.TYPE_PERLIN
	base.frequency = 0.0055
	base.fractal_octaves = 4
	base.fractal_gain = 0.45
	base.seed = 20260911

	var warp := FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_PERLIN
	warp.frequency = 0.02
	warp.seed = 77

	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_PERLIN
	detail.frequency = 0.06
	detail.seed = 5

	var n := 0
	for z in range(-HALF, HALF + 1):
		for x in range(-HALF, HALF + 1):
			var fx := x + warp.get_noise_2d(x, z) * 12.0
			var fz := z + warp.get_noise_2d(x + 100.0, z - 50.0) * 12.0
			var h := base.get_noise_2d(fx, fz) * HILL_AMP
			# a soft ridge rising toward the north-east edge for a horizon line
			var d := Vector2(x, z).length()
			h += clampf((d - 60.0) / 120.0, 0.0, 1.0) * RIDGE_AMP * (0.5 + 0.5 * base.get_noise_2d(fx * 0.6, fz * 0.6))
			h += detail.get_noise_2d(x, z) * 0.55
			# flatten the spawn clearing
			var c := smoothstep(CLEARING, CLEARING + 7.0, d)
			h = lerpf(0.0, h, c)
			data.set_height(Vector3(x, 0.0, z), h)
			# enable the auto-shader (grass/rock by slope) everywhere
			data.set_control_auto(Vector3(x, 0.0, z), true)
			n += 1
		if z % 64 == 0:
			await process_frame

	data.calc_height_range()
	data.update_maps(0, true, false)
	print("set %d verts, height range %s" % [n, data.get_height_range()])
	data.save_directory(DATA_DIR)
	await process_frame
	await process_frame
	print("saved to ", DATA_DIR)
	quit()
