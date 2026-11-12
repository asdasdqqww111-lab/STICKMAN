extends Control
## Root scene controller: shows the main menu over a live rotating planet and
## swaps into the playable scene when the player starts or continues.

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const GamePanels = preload("res://scripts/ui/game_panels.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")
const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const PlanetMesh = preload("res://scripts/planet/planet_mesh.gd")

var menu: Control
var settings_panel: Control
var settings: RefCounted

var _planet: Node3D
var _camera: Camera3D
var _menu_layer: CanvasLayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	settings = (load("res://scripts/core/game_settings.gd") as GDScript).new()
	settings.load_settings()
	_build_backdrop()
	_show_menu()


## A slowly rotating planet behind the menu — this *is* the game's planet model,
## not a placeholder image, so the menu previews the real world.
func _build_backdrop() -> void:
	_planet = Node3D.new()
	_planet.name = "MenuPlanet"
	add_child(_planet)
	var resolution := 12
	var material := PlanetMesh.make_planet_material()
	for face in ["px", "nx", "py", "ny", "pz", "nz"]:
		var payload := PlanetMesh.build_face(face, resolution)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, payload.arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		_planet.add_child(instance)
	var ocean := MeshInstance3D.new()
	var ocean_mesh := SphereMesh.new()
	ocean_mesh.radius = Math3D.RADIUS + Terrain.WATER_LEVEL
	ocean_mesh.height = (Math3D.RADIUS + Terrain.WATER_LEVEL) * 2.0
	ocean_mesh.radial_segments = 48
	ocean_mesh.rings = 24
	ocean.mesh = ocean_mesh
	ocean.material_override = PlanetMesh.make_ocean_material()
	_planet.add_child(ocean)

	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a1424")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("93b8cf")
	environment.ambient_light_energy = 1.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky.environment = environment
	add_child(sky)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 52, 0)
	sun.light_energy = 1.4
	add_child(sun)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 48.0
	_camera.far = 4000.0
	add_child(_camera)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.rotation = Vector3(0, 0, 0)


func _process(delta: float) -> void:
	if _planet != null:
		_planet.rotation.y += delta * 0.06
	if _camera != null and _planet != null:
		# Frame the planet from the spawn hemisphere.
		var spawn := Vector3(0, 0, 1)
		var camera_position := spawn * (Math3D.RADIUS * 2.55)
		camera_position += Vector3(0, Math3D.RADIUS * 0.25, 0)
		_camera.global_position = camera_position
		_camera.look_at(Vector3(0, Math3D.RADIUS * 0.10, 0), Vector3.UP)


func _show_menu() -> void:
	if menu != null:
		menu.queue_free()
	menu = (load("res://scripts/ui/main_menu.gd") as GDScript).new()
	add_child(menu)
	menu.new_game_requested.connect(_start_new_game)
	menu.continue_requested.connect(_continue_game)
	menu.settings_requested.connect(_show_settings)
	menu.quit_requested.connect(func() -> void: get_tree().quit())


func _show_settings() -> void:
	if settings_panel != null:
		settings_panel.queue_free()
	settings_panel = (load("res://scripts/ui/game_panels.gd") as GDScript).new()
	add_child(settings_panel)
	settings_panel.bind(null, null, null, settings)
	settings_panel.open_settings_only(settings)
	settings_panel.closed.connect(func() -> void: settings_panel.queue_free())


func _start_new_game() -> void:
	_launch("new", menu.hero_name() if menu != null else "Wanderer")


func _continue_game() -> void:
	_launch("continue", "Wanderer")


func _launch(mode: String, hero_name: String) -> void:
	var scene_path := "res://scenes/Game.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var game: Node = load(scene_path).instantiate()
	game.set("start_mode", mode)
	game.set("hero_name", hero_name)
	get_tree().root.add_child(game)
	# Remove this menu scene only after the game scene is in the tree.
	get_tree().current_scene = game
	queue_free()
