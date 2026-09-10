extends Node3D
## Root orchestrator. Builds the world, spawns the player + Freja, wires the HUD
## and the customization screen. Everything is constructed in code so the scene
## files stay tiny and diffable.

const WorldBuilder := preload("res://scripts/world/world_builder.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const FrejaScript := preload("res://scripts/character/freja.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const CustomizerScreen := preload("res://scripts/ui/customization_screen.gd")

var world: Node3D
var player: CharacterBody3D
var freja: Node3D
var hud: CanvasLayer
var customizer_screen: Control
var config: Resource

func _ready() -> void:
	config = FrejaConfig.new()

	_build_environment()

	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)

	# --- player + character ---
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 2.0, 0)

	freja = FrejaScript.new()
	freja.name = "Freja"
	player.add_child(freja)
	freja.load_model()
	freja.apply_config(config)

	player.setup(freja)

	# --- UI ---
	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)

	var cust_layer := CanvasLayer.new()
	cust_layer.name = "CustomizerLayer"
	cust_layer.layer = 20
	add_child(cust_layer)
	customizer_screen = CustomizerScreen.new()
	customizer_screen.name = "CustomizerScreen"
	cust_layer.add_child(customizer_screen)
	customizer_screen.setup(freja, config)
	customizer_screen.visible = false

	if "--capture" in OS.get_cmdline_args() or "--capture" in OS.get_cmdline_user_args():
		var cap := preload("res://scripts/game/debug_capture.gd").new()
		cap.name = "DebugCapture"
		add_child(cap)

	hud.inventory_pressed.connect(_open_customizer)
	hud.move_input_changed.connect(player.set_mobile_move_vector)
	hud.look_input.connect(player.add_mobile_look)
	hud.jump_pressed.connect(player.request_jump)
	hud.crouch_toggled.connect(player.set_crouch_held)
	hud.sprint_toggled.connect(player.set_sprint_held)
	customizer_screen.closed.connect(_close_customizer)

	_close_customizer()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	# Poly Haven CC0 HDRI panorama sky -> realistic outdoor light + reflections
	var sky := Sky.new()
	var hdri := load("res://assets/textures/sky/rooitou_park_1k.hdr")
	if hdri:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = hdri
		pano.energy_multiplier = 1.0
		sky.sky_material = pano
	else:
		var proc := ProceduralSkyMaterial.new()
		proc.sky_horizon_color = Color(0.78, 0.82, 0.82)
		sky.sky_material = proc
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(35), 0)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.3
	env.ssao_power = 1.8
	env.ssao_detail = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.6

	# light distance haze so the tree line reads with depth (no volumetrics)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.74, 0.8, 0.86)
	env.fog_sun_scatter = 0.05
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0

	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -108, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.1
	sun.shadow_normal_bias = 1.5
	sun.shadow_bias = 0.035
	sun.light_angular_distance = 0.55
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.14
	sun.directional_shadow_split_3 = 0.36
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)

func _open_customizer() -> void:
	customizer_screen.open()
	hud.visible = false
	player.set_input_enabled(false)

func _close_customizer() -> void:
	customizer_screen.visible = false
	if is_instance_valid(hud):
		hud.visible = true
	player.set_input_enabled(true)
