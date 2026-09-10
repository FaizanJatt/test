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

	if "--capture" in OS.get_cmdline_args():
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
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.82)
	sky_mat.ground_bottom_color = Color(0.32, 0.34, 0.30)
	sky_mat.ground_horizon_color = Color(0.72, 0.76, 0.74)
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.5
	env.ssao_intensity = 1.0
	env.ssao_power = 2.0
	env.ssao_detail = 0.4
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.79, 0.83, 0.87)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58, -132, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.shadow_enabled = true
	sun.shadow_blur = 0.1
	sun.shadow_normal_bias = 2.5
	sun.shadow_bias = 0.04
	sun.light_angular_distance = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 38.0
	sun.directional_shadow_split_1 = 0.045
	sun.directional_shadow_split_2 = 0.13
	sun.directional_shadow_split_3 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.9
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
