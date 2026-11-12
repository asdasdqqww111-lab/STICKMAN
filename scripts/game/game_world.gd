extends Node3D
## The playable scene: builds the planet, the Havenbrook slice, the player,
## streaming, combat, audio and the full UI, and owns the gameplay loop.

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const PlanetMesh = preload("res://scripts/planet/planet_mesh.gd")
const Regions = preload("res://scripts/planet/planet_regions.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const QuestLog = preload("res://scripts/core/quest_log.gd")
const AudioManager = preload("res://scripts/core/audio_manager.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const CameraRig = preload("res://scripts/player/camera_rig.gd")
const EnemyActor = preload("res://scripts/combat/enemy_actor.gd")
const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const Vfx = preload("res://scripts/combat/vfx.gd")
const MonsterDefinitions = preload("res://scripts/data/monster_definitions.gd")
const LootTable = preload("res://scripts/data/loot_table.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const WorldClock = preload("res://scripts/world/world_clock.gd")
const WorldBuilder = preload("res://scripts/world/world_builder.gd")
const WorldSimulation = preload("res://scripts/world/world_simulation.gd")
const DungeonBuilder = preload("res://scripts/world/dungeon_builder.gd")
const ResourceNodeScript = preload("res://scripts/world/resource_node.gd")
const InteractableScript = preload("res://scripts/world/interactable.gd")
const NpcActor = preload("res://scripts/world/npc_actor.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const GamePanels = preload("res://scripts/ui/game_panels.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")

## How the session was started: "new" or "continue".
var start_mode := "new"
var hero_name := "Wanderer"

var state: RefCounted
var settings: RefCounted
var quest_log: RefCounted
var audio: Node
var clock: Node
var simulation: Node
var vfx: Node
var combat: Node

var planet_root: Node3D
var props_root: Node3D
var entities_root: Node3D
var player: Node3D
var camera_rig: Node3D
var sun: DirectionalLight3D
var environment: Environment
var world_environment: WorldEnvironment

var hud: Control
var controls: Control
var panels: Control

var interactables: Array = []
var resource_nodes: Array = []
var npcs: Array = []
var enemies: Array = []
var dungeon_entered := false
var nearest_interactable: Node3D
var nearest_resource: Node3D
var target_enemy: Node3D
var autosave_timer := 0.0
var play_seconds := 0.0
var _notice_cooldown := 0.0
var _planet_faces: Array[MeshInstance3D] = []
var _fps_samples: Array[float] = []
var _session_death_handled := false


func _ready() -> void:
	Engine.max_fps = 60
	settings = (load("res://scripts/core/game_settings.gd") as GDScript).new()
	settings.load_settings()
	if start_mode == "continue":
		var loaded := SaveGame.load_state()
		if loaded != null:
			state = loaded
		else:
			start_mode = "new"
	if state == null:
		state = PlayerState.new()
		state.hero_name = hero_name
		state.direction = Math3D.direction(0.0, 0.003)
		state.health = state.max_health()
		state.mana = state.max_mana()
		state.stamina = state.max_stamina()
		state.add_item("healing_potion", 2)
		state.add_item("purple_herb", 1)

	quest_log = QuestLog.new(state)

	_build_environment()
	_build_planet()
	_build_clock()
	_build_audio()
	_build_player()
	_build_simulation()
	_build_world_content()
	_build_vfx_and_combat()
	_build_ui()
	_bind_events()

	settings.apply_to_viewport()
	audio.enabled = settings.audio_on()
	_update_camera_immediately()
	if start_mode == "continue":
		hud.show_notice("Welcome back, %s. Day %d." % [state.hero_name, state.day], 5.0)
	else:
		hud.show_notice("Welcome to Havenbrook, %s. Registrar Maeve waits at the guild hall." % state.hero_name, 6.0)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("2f4f7a")
	sky_material.sky_horizon_color = Color("9fc6d8")
	sky_material.ground_bottom_color = Color("1a2233")
	sky_material.ground_horizon_color = Color("51708a")
	sky.set_material(sky_material)
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_light_color = Color("9fc6d8")
	environment.fog_sky_affect = 0.25
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50, 40, 0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_energy = 0.35
	fill.omni_range = 60.0
	fill.position = Vector3(0, 0, 0)
	add_child(fill)


func _build_planet() -> void:
	planet_root = Node3D.new()
	planet_root.name = "Planet"
	add_child(planet_root)
	var resolution: int = int(settings.preset().get("planet_resolution", 14))
	var material := PlanetMesh.make_planet_material()
	for face in ["px", "nx", "py", "ny", "pz", "nz"]:
		var payload := PlanetMesh.build_face(face, resolution)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, payload.arrays)
		var instance := MeshInstance3D.new()
		instance.name = "Face_" + face
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		planet_root.add_child(instance)
		_planet_faces.append(instance)
	# Ocean shell.
	var ocean := MeshInstance3D.new()
	var ocean_mesh := SphereMesh.new()
	ocean_mesh.radius = Math3D.RADIUS + Terrain.WATER_LEVEL
	ocean_mesh.height = (Math3D.RADIUS + Terrain.WATER_LEVEL) * 2.0
	ocean_mesh.radial_segments = 64
	ocean_mesh.rings = 32
	ocean.mesh = ocean_mesh
	ocean.material_override = PlanetMesh.make_ocean_material()
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(ocean)
	# Starfield backdrop.
	var stars := MeshInstance3D.new()
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 1800.0
	star_mesh.height = 3600.0
	stars.mesh = star_mesh
	var star_material := StandardMaterial3D.new()
	star_material.albedo_color = Color("0a1220")
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.cull_mode = BaseMaterial3D.CULL_FRONT
	stars.material_override = star_material
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


func _build_clock() -> void:
	clock = (load("res://scripts/world/world_clock.gd") as GDScript).new()
	clock.name = "WorldClock"
	clock.add_to_group("world_clock")
	add_child(clock)
	clock.configure(sun, environment)
	clock.set_time(state.time_of_day)
	clock.day = state.day


func _build_audio() -> void:
	audio = (load("res://scripts/core/audio_manager.gd") as GDScript).new()
	audio.name = "Audio"
	audio.add_to_group("audio")
	add_child(audio)


func _build_player() -> void:
	entities_root = Node3D.new()
	entities_root.name = "Entities"
	add_child(entities_root)
	player = (load("res://scripts/player/player_controller.gd") as GDScript).new()
	player.name = "Player"
	entities_root.add_child(player)
	player.setup(state, AssetCatalog.PLAYER_BODY)
	camera_rig = (load("res://scripts/player/camera_rig.gd") as GDScript).new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(player)
	player.camera_rig = camera_rig


func _build_world_content() -> void:
	props_root = Node3D.new()
	props_root.name = "WorldProps"
	add_child(props_root)
	_build_village()
	_build_shrines()
	_build_resources()
	_build_chests()
	_build_npcs()
	_build_camps()
	_build_scatter()
	_build_dungeon()


func _place_prop(scene: PackedScene, direction: Vector3, scale_value: float = 1.0, yaw: float = 0.0, region_id: String = "") -> Node3D:
	if scene == null:
		return null
	var instance: Node3D = scene.instantiate()
	props_root.add_child(instance)
	instance.global_position = Terrain.ground_point(direction)
	instance.global_transform.basis = Math3D.frame_at(direction).rotated(direction, yaw).scaled(Vector3.ONE * scale_value)
	if simulation != null and region_id != "":
		simulation.register_prop(region_id, instance)
	elif region_id != "":
		instance.set_meta("region", region_id)
	return instance


func _build_village() -> void:
	var building_scenes := {
		AssetCatalog.CITY_BUILDING_A: _load_scene(AssetCatalog.CITY_BUILDING_A),
		AssetCatalog.CITY_BUILDING_B: _load_scene(AssetCatalog.CITY_BUILDING_B),
		AssetCatalog.CITY_BUILDING_C: _load_scene(AssetCatalog.CITY_BUILDING_C),
	}
	for spec in WorldBuilder.BUILDINGS:
		var scene: PackedScene = building_scenes.get(spec["asset"], null)
		var direction := Math3D.direction(spec["lon"], spec["lat"])
		_place_prop(scene, direction, spec["scale"], spec["yaw"], Regions.region_of(direction))
	# Guild registrar + forge + shop counters.
	_add_interactable(InteractableScript.Kind.NPC, "registrar", Math3D.direction(0.013, 0.0115), "Registrar Maeve", "Talk to the guild registrar", Color("e8c27a"))
	_add_interactable(InteractableScript.Kind.FORGE, "forge", Math3D.direction(0.004, 0.0155), "Havenbrook Forge", "Use the forge", Color("ff8b5c"))
	_add_interactable(InteractableScript.Kind.SHOP, "shop", Math3D.direction(0.019, 0.0065), "Provisions Stall", "Open the shop", Color("9ae6b4"))
	# Benches and market boxes.
	var bench := _load_scene(AssetCatalog.CITY_BENCH)
	var box := _load_scene(AssetCatalog.CITY_BOX)
	for i in range(4):
		var angle := TAU * float(i) / 4.0
		var centre := Math3D.direction(0.012, 0.010)
		var tangent := Math3D.east(centre) * cos(angle) + Math3D.north(centre) * sin(angle)
		var point := (centre + tangent * (7.0 / Math3D.RADIUS)).normalized()
		_place_prop(bench, point, 1.6, angle, Regions.region_of(point))
		if i % 2 == 0:
			_place_prop(box, (centre + tangent * (4.0 / Math3D.RADIUS)).normalized(), 1.4, angle * 1.7, Regions.region_of(point))


func _build_shrines() -> void:
	for spec in WorldBuilder.SHRINES:
		var direction := Math3D.direction(spec["lon"], spec["lat"])
		var shrine := _add_interactable(InteractableScript.Kind.SHRINE, spec["id"], direction, spec["name"], "Activate shrine", Color(spec["colour"]), 2.6)
		shrine.set_used(spec["id"] in state.waypoints)
		# Stone base under the marker.
		var base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 1.1
		base_mesh.bottom_radius = 1.4
		base_mesh.height = 0.5
		base.mesh = base_mesh
		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color("6b6459")
		base.material_override = base_material
		shrine.add_child(base)
		base.position.y = 0.25


func _build_resources() -> void:
	for spec in WorldBuilder.RESOURCES:
		if spec["id"] in state.gathered:
			continue
		var direction := WorldBuilder.resource_direction(spec)
		var node: Node3D = (load("res://scripts/world/resource_node.gd") as GDScript).new()
		node.name = "Resource_" + spec["id"]
		entities_root.add_child(node)
		node.configure(spec["id"], spec["item"], 1, Terrain.ground_point(direction), Math3D.frame_at(direction), ItemDB.display_name(spec["item"]))
		node.build_visual(Color(spec["colour"]), 0.75 if spec["item"] == "purple_herb" else 0.6)
		node.harvested.connect(_on_resource_harvested)
		resource_nodes.append(node)


func _build_chests() -> void:
	var chest_scene := _load_scene(AssetCatalog.DUNGEON_CHEST)
	var gold_scene := _load_scene(AssetCatalog.DUNGEON_CHEST_GOLD)
	for spec in WorldBuilder.CHESTS:
		var direction := Math3D.direction(spec["lon"], spec["lat"])
		var chest := _add_interactable(InteractableScript.Kind.CHEST, spec["id"], direction, "Treasure Chest", "Open chest", Color("ffd166"), 1.0)
		var scene: PackedScene = gold_scene if spec["gold"] else chest_scene
		if scene != null:
			var instance: Node3D = scene.instantiate()
			chest.add_child(instance)
			instance.scale = Vector3.ONE * 1.2
		chest.set_used(spec["id"] in state.opened_chests)


func _build_npcs() -> void:
	var village := Math3D.direction(WorldBuilder.VILLAGE_LON, WorldBuilder.VILLAGE_LAT)
	var rows := [
		{"id": "farmer_lysa", "name": "Lysa the Farmer", "role": "farmer", "offset": Vector2(0.006, -0.004), "colour": Color("9ae6b4")},
		{"id": "smith_brann", "name": "Brann the Smith", "role": "smith", "offset": Vector2(-0.005, 0.006), "colour": Color("ffb066")},
		{"id": "scout_ivy", "name": "Ivy the Scout", "role": "scout", "offset": Vector2(0.010, 0.008), "colour": Color("8ecae6")},
	]
	for row in rows:
		var home: Vector3 = (village + Math3D.east(village) * row["offset"].x + Math3D.north(village) * row["offset"].y).normalized()
		var npc: Node3D = (load("res://scripts/world/npc_actor.gd") as GDScript).new()
		npc.name = "NPC_" + row["id"]
		entities_root.add_child(npc)
		var schedule: Array[Dictionary] = [
			{"from": 0.0, "to": 8.0, "anchor": home},
			{"from": 8.0, "to": 18.0, "anchor": WorldBuilder.village_direction()},
			{"from": 18.0, "to": 24.0, "anchor": home},
		]
		npc.configure(row["id"], row["name"], row["role"], home, schedule)
		npc.build_visual()
		npc.interacted.connect(_on_npc_interacted)
		npcs.append(npc)


func _build_camps() -> void:
	for row in WorldBuilder.CAMPS:
		var archetype: String = row[0]
		var directions := WorldBuilder.camp_directions(row)
		for index in range(directions.size()):
			var instance_id := "%s_%d_%d" % [archetype, hash(row[1]), index]
			if instance_id in state.defeated:
				continue
			_spawn_enemy(archetype, directions[index], instance_id)


func _build_scatter() -> void:
	var scatter_count: int = int(settings.preset().get("scatter", 52))
	var village := WorldBuilder.village_direction()
	var tree_like := [
		_load_scene(AssetCatalog.CITY_BUSH),
		_load_scene(AssetCatalog.DUNGEON_RUBBLE),
	]
	var points := WorldBuilder.scatter_points(village, 95.0, scatter_count, 11)
	for i in range(points.size()):
		var point: Vector3 = points[i]
		var scene: PackedScene = tree_like[i % tree_like.size()]
		var region := Regions.region_of(point)
		_place_prop(scene, point, randf_range(0.7, 1.4), randf_range(0.0, TAU), region)


func _build_dungeon() -> void:
	var direction := WorldBuilder.dungeon_direction()
	var built := DungeonBuilder.build(self, direction)
	_dungeon_root = built.get("root")
	_dungeon_monster_root = built.get("monster_root")
	_dungeon_chest_data = built
	# The boss hall shares the surface planet but sits underground; spawn the
	# dungeon roster inside the built geometry.
	if _dungeon_monster_root != null:
		for spawn in built.get("monster_spawns", []):
			var archetype: String = spawn["archetype"]
			var instance_id := "dungeon_%s_%d" % [archetype, hash(spawn["position"])]
			if instance_id in state.defeated:
				continue
			var local: Vector3 = spawn["position"]
			var world_position: Vector3 = _dungeon_root.global_transform * local
			_spawn_enemy_at_position(archetype, world_position, instance_id)
	_add_interactable(InteractableScript.Kind.DUNGEON, "barrow", direction, "The Barrow — Dungeon", "Enter the Barrow", Color("b06cff"), 3.2)
	# Dungeon chest.
	var chest := _add_interactable(InteractableScript.Kind.CHEST, "dungeon_chest", direction, "Warden's Cache", "Open cache", Color("ffd166"), 1.0)
	chest.set_used("dungeon_chest" in state.opened_chests)

var _dungeon_root: Node3D
var _dungeon_monster_root: Node3D
var _dungeon_chest_data: Dictionary


func _build_simulation() -> void:
	simulation = (load("res://scripts/world/world_simulation.gd") as GDScript).new()
	simulation.name = "WorldSimulation"
	add_child(simulation)
	simulation.bind(player, state)
	simulation.stream_radius = int(settings.preset().get("stream_radius", 2))
	simulation.max_active_monsters = int(settings.preset().get("max_active_monsters", 16))
	simulation.region_entered.connect(_on_region_entered)
	# Register all props already built (they carry their region in metadata).
	if props_root != null:
		for child in props_root.get_children():
			if child.has_meta("region"):
				simulation.register_prop(String(child.get_meta("region")), child)


func _build_vfx_and_combat() -> void:
	vfx = (load("res://scripts/combat/vfx.gd") as GDScript).new()
	vfx.name = "Vfx"
	add_child(vfx)
	combat = (load("res://scripts/combat/combat_system.gd") as GDScript).new()
	combat.name = "Combat"
	add_child(combat)
	combat.bind(player, state)
	combat.audio = audio
	combat.damage_number.connect(_on_damage_number)
	combat.hit_flash.connect(_on_hit_flash)
	combat.player_hit.connect(_on_player_hit)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	canvas.layer = 10
	add_child(canvas)
	hud = (load("res://scripts/ui/hud.gd") as GDScript).new()
	canvas.add_child(hud)
	hud.bind(state, quest_log)
	controls = (load("res://scripts/ui/touch_controls.gd") as GDScript).new()
	canvas.add_child(controls)
	panels = (load("res://scripts/ui/game_panels.gd") as GDScript).new()
	canvas.add_child(panels)
	panels.bind(state, quest_log, player, settings)
	panels.settings_changed.connect(_on_settings_changed)
	hud.set_performance_readout(settings.show_fps)


func _bind_events() -> void:
	state.notice.connect(func(text: String) -> void: hud.show_notice(text))
	state.level_up.connect(_on_level_up)
	state.rank_changed.connect(_on_rank_changed)
	state.died.connect(_on_player_died)
	state.items_changed.connect(func() -> void:
		player.refresh_equipment()
		hud.refresh()
	)
	state.stats_changed.connect(func() -> void: hud.refresh())
	state.gold_changed.connect(func(_amount: int, _total: int) -> void:
		hud.refresh()
		panels.refresh_if_open()
	)
	quest_log.quest_ready.connect(func(quest_id: String) -> void:
		hud.show_notice("Contract ready to turn in: %s" % quest_id.replace("_", " ").capitalize(), 3.5)
		hud.refresh()
	)
	quest_log.quest_completed.connect(func(quest_id: String, xp: int, gold: int) -> void:
		hud.show_notice("Contract complete: %s (+%d XP, +%d G)" % [quest_id.replace("_", " ").capitalize(), xp, gold], 4.0)
		hud.refresh()
	)
	quest_log.quest_available.connect(func(quest_id: String) -> void:
		hud.show_notice("New contract available at the guild: %s" % quest_id.replace("_", " ").capitalize(), 3.0)
	)
	hud.panel_requested.connect(_on_panel_requested)
	panels.closed.connect(_on_panel_closed)
	panels.action_requested.connect(_on_panel_action)
	controls.move_changed.connect(_on_move)
	controls.look_delta.connect(_on_look)
	controls.jump_pressed.connect(func() -> void: player.jump())
	controls.attack_pressed.connect(_on_attack)
	controls.dodge_pressed.connect(func() -> void: player.dodge(player.move_input))
	controls.interact_pressed.connect(_on_interact)
	controls.spell_pressed.connect(_cast_selected_spell)
	controls.pause_pressed.connect(func() -> void: _on_panel_requested("pause"))
	player.attacked.connect(_on_player_attacked)
	clock.phase_changed.connect(_on_phase_changed)
	quest_log.refresh()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _update_camera_immediately() -> void:
	player.current_direction = state.direction.normalized()
	player.facing = state.yaw
	player._update_transform()
	camera_rig._update_follow(1.0)


func _add_interactable(kind: int, id: String, direction: Vector3, label: String, prompt: String, colour: Color, marker_height: float = 2.2) -> Node3D:
	var node: Node3D = (load("res://scripts/world/interactable.gd") as GDScript).new()
	node.name = "Interact_" + id
	entities_root.add_child(node)
	node.configure(kind, id, Terrain.ground_point(direction), Math3D.frame_at(direction), label)
	node.prompt = prompt
	node.build_marker(colour, marker_height)
	node.activated.connect(_on_interactable_activated)
	interactables.append(node)
	return node


func _spawn_enemy(archetype: String, direction: Vector3, instance_id: String) -> Node3D:
	return _spawn_enemy_at_position(archetype, Terrain.ground_point(direction), instance_id)


func _spawn_enemy_at_position(archetype: String, world_position: Vector3, instance_id: String) -> Node3D:
	var data: Resource = MonsterDefinitions.create(archetype)
	if data == null:
		return null
	var enemy: Node3D = (load("res://scripts/combat/enemy_actor.gd") as GDScript).new()
	enemy.name = "Enemy_" + instance_id
	entities_root.add_child(enemy)
	enemy.configure(data, instance_id, world_position.normalized())
	enemy.build_visual()
	# Dungeon monsters are placed by the dungeon transform (they sit below the
	# analytic surface height), surface monsters use terrain elevation.
	if absf(world_position.length() - (Math3D.RADIUS + Terrain.elevation(world_position.normalized()))) > 2.0:
		enemy.global_position = world_position
		enemy.current_direction = (world_position - Math3D.RADIUS * world_position.normalized()).normalized()
		enemy.home_direction = enemy.current_direction
	enemy.bind_player(player, state)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attacked_player.connect(_on_enemy_attacked)
	enemy.phase_changed.connect(_on_boss_phase)
	enemy.damaged.connect(func(node: Node, _amount: float) -> void: combat.register_enemy(node))
	enemies.append(enemy)
	if combat != null:
		combat.register_enemy(enemy)
	if simulation != null:
		simulation.register_monster(enemy)
	return enemy


# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_move(vector: Vector2) -> void:
	if panels.is_open():
		player.move_input = Vector2.ZERO
		return
	player.move_input = vector
	player.running = vector.length() > 0.92


func _on_look(delta: Vector2) -> void:
	if panels.is_open():
		return
	var sensitivity: float = settings.sensitivity
	var invert := -1.0 if settings.invert_look else 1.0
	player.set_look_input(Vector2(delta.x * sensitivity, 0.0))
	camera_rig.orbit(delta.y * sensitivity * invert * 0.9)


func _on_attack(heavy: bool) -> void:
	if panels.is_open():
		return
	if player.attack(heavy):
		var forward: Vector3 = player.forward_tangent()
		vfx.slash(player.chest_point(), forward, player.current_direction, Color("ffe9b0") if not heavy else Color("ffc27a"))


func _on_player_attacked(heavy: bool) -> void:
	var hits: int = 0
	if combat != null:
		hits = combat.resolve_melee(heavy)
	if hits == 0 and audio != null:
		audio.play_attack()


func _on_interact() -> void:
	if panels.is_open():
		return
	if nearest_resource != null and is_instance_valid(nearest_resource):
		var result: Dictionary = nearest_resource.harvest()
		if not result.is_empty():
			player.interact_animation()
			return
	if nearest_interactable != null and is_instance_valid(nearest_interactable):
		player.interact_animation()
		nearest_interactable.activate()


func _cast_selected_spell() -> void:
	if panels.is_open():
		return
	var spell_id := "ember_bolt"
	for known in state.known_spells:
		if state.spell_ready(known, play_seconds):
			spell_id = known
			break
	var now := play_seconds
	var result: Dictionary = combat.cast_spell(spell_id, now)
	if bool(result.get("ok", false)):
		var spell := SpellDB.create(spell_id)
		if spell != null:
			vfx.bolt(player.chest_point(), player.chest_point() + player.forward_tangent() * minf(spell.range_metres, 12.0), spell.effect_color)
			if spell.heal_amount > 0.0:
				vfx.heal_burst(player.global_position + player.current_direction)
	hud.show_notice(String(result.get("message", "")), 2.0)


# ---------------------------------------------------------------------------
# World event handlers
# ---------------------------------------------------------------------------

func _on_resource_harvested(node_id: String, item_id: String, amount: int) -> void:
	if state.add_item(item_id, amount) and state.rank != "":
		state.gathered.append(node_id)
		var name := ItemDB.display_name(item_id)
		hud.show_notice("Harvested %s ×%d" % [name, amount], 2.5)
		if audio != null:
			audio.play_ui("cloth")
		quest_log.notify_world_changed()
		var node = _find_resource(node_id)
		if node != null:
			node.visible = false


func _find_resource(node_id: String) -> Node3D:
	for node in resource_nodes:
		if is_instance_valid(node) and node.node_id == node_id:
			return node
	return null


func _on_interactable_activated(node: Node3D) -> void:
	match node.kind:
		InteractableScript.Kind.SHRINE:
			_activate_shrine(node)
		InteractableScript.Kind.CHEST:
			_open_chest(node)
		InteractableScript.Kind.NPC:
			_talk_to_registrar()
		InteractableScript.Kind.FORGE:
			panels.open("crafting")
			_set_controls_enabled(false)
		InteractableScript.Kind.SHOP:
			panels.open("shop")
			_set_controls_enabled(false)
		InteractableScript.Kind.DUNGEON:
			_enter_dungeon()


func _activate_shrine(node: Node3D) -> void:
	if node.id in state.waypoints:
		hud.show_notice("%s is already lit." % node.label, 2.5)
		return
	if state.unlock_waypoint(node.id):
		node.set_used(true)
		hud.show_notice("Shrine activated: %s (+8 XP). Fast travel unlocked." % node.label, 3.5)
		if audio != null:
			audio.play_ui("page")
		quest_log.notify_world_changed()
		panels.refresh_if_open()


func _open_chest(node: Node3D) -> void:
	if node.id in state.opened_chests:
		hud.show_notice("This chest is empty.", 2.0)
		return
	state.opened_chests.append(node.id)
	node.set_used(true)
	var table: Resource = (load("res://scripts/data/loot_table.gd") as GDScript).new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	table.min_rolls = 2
	table.max_rolls = 3
	table.entries.assign([
		{"item_id": "healing_potion", "weight": 3.0, "min": 1, "max": 2},
		{"item_id": "iron_ore", "weight": 3.0, "min": 1, "max": 3},
		{"item_id": "purple_herb", "weight": 2.0, "min": 1, "max": 2},
		{"item_id": "crystal_shard", "weight": 1.0, "min": 1, "max": 1},
		{"item_id": "amber_resin", "weight": 1.0, "min": 1, "max": 1},
	])
	if node.id == "dungeon_chest" or node.id == "chest_barrow":
		table.entries.append({"item_id": "bone_shard", "weight": 2.5, "min": 2, "max": 3})
		table.entries.append({"item_id": "greatsword", "weight": 1.0, "min": 1, "max": 1})
	var drops: Array = table.roll(rng)
	var lines: Array[String] = []
	for drop in drops:
		state.add_item(String(drop["item_id"]), int(drop["count"]))
		lines.append("%s ×%d" % [ItemDB.display_name(String(drop["item_id"])), int(drop["count"])])
	var gold_bonus := rng.randi_range(8, 24)
	state.add_gold(gold_bonus)
	if audio != null:
		audio.play_coin()
	hud.show_notice("Chest opened: %s, %d gold" % [", ".join(lines), gold_bonus], 4.0)
	quest_log.notify_world_changed()


func _talk_to_registrar() -> void:
	quest_log.register_talk("registrar")
	if not state.available_quest_ids().is_empty():
		quest_log.accept_available()
		hud.show_notice("Maeve: " + quest_log.active_summaries().back() if not quest_log.active_summaries().is_empty() else "Maeve: Your ledger is full for now.", 4.0)
	elif not quest_log.ready_summaries().is_empty():
		var rewards: Array = quest_log.turn_in_ready()
		var parts: Array[String] = []
		for reward in rewards:
			parts.append("%s (+%d XP, +%d G)" % [reward["title"], int(reward["xp"]), int(reward["gold"])])
		hud.show_notice("Contracts complete: " + ", ".join(parts), 5.0)
		if audio != null:
			audio.play_coin()
	else:
		hud.show_notice("Maeve: " + Rank_rules_describe(), 4.5)
	if state.can_promote():
		state.try_promote()
	panels.refresh_if_open()


func Rank_rules_describe() -> String:
	return RankRules.describe(state.rank, state.stats, state.discovered.size(), state.quests_completed(), state.level, state.reputation)


func _on_npc_interacted(npc: Node) -> void:
	hud.show_notice(npc.display_name + " greets you.", 2.0)


func _enter_dungeon() -> void:
	if not dungeon_entered:
		dungeon_entered = true
		state.dungeon_cleared = true
		quest_log.notify_world_changed()
	if _dungeon_root == null:
		return
	var entrance: Vector3 = _dungeon_root.global_transform * Vector3(0, 0, 6.0)
	player.current_direction = entrance.normalized()
	player.height_offset = entrance.length() - Math3D.RADIUS
	player._update_transform()
	hud.show_notice("You descend into the Barrow. Torchlight, bone and a warden await.", 5.0)
	if audio != null:
		audio.play_ui("door")


func _on_region_entered(region_id: String, first_time: bool) -> void:
	if first_time:
		hud.show_notice("Region discovered! (%d total)" % state.discovered.size(), 2.5)
		quest_log.notify_world_changed()
	hud.set_region(_region_label(region_id))


func _region_label(region_id: String) -> String:
	var direction := Regions.region_center(region_id)
	var label := Terrain.region_name(direction)
	if Math3D.arc_distance(direction, WorldBuilder.dungeon_direction()) < 40.0:
		return "The Barrow"
	if Math3D.arc_distance(direction, WorldBuilder.village_direction()) < 40.0:
		return "Havenbrook Village"
	return "%s · %s" % [label, Regions.region_label(region_id)]


func _on_enemy_defeated(enemy: Node, archetype: String) -> void:
	state.defeated.append(enemy.instance_id)
	state.register_kill(archetype)
	var data: Resource = enemy.data
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var xp: int = data.xp_reward
	var gold: int = rng.randi_range(data.gold_min, data.gold_max)
	state.gain_xp(xp)
	state.add_gold(gold)
	var lines: Array[String] = []
	for drop in _loot_for(data.loot_table_id).roll(rng):
		state.add_item(String(drop["item_id"]), int(drop["count"]))
		lines.append("%s ×%d" % [ItemDB.display_name(String(drop["item_id"])), int(drop["count"])])
	if archetype.begins_with("boss_"):
		state.defeated_bosses.append(archetype)
		state.add_item("warden_sigil", 1)
		state.dungeon_cleared = true
		hud.show_notice("The Bone Warden falls! +%d XP, +%d gold, Warden Sigil" % [xp, gold], 6.0)
		camera_rig.shake(0.6)
		if audio != null:
			audio.play_ui("door")
	else:
		hud.show_notice("Defeated %s · +%d XP, +%d G%s" % [data.display_name, xp, gold, (", " + ", ".join(lines)) if not lines.is_empty() else ""], 3.0)
	if audio != null:
		audio.play_hit()
	if combat != null:
		combat.unregister_enemy(enemy)
	if simulation != null:
		simulation.unregister_monster(enemy)
	enemies.erase(enemy)
	target_enemy = null
	hud.hide_target()
	quest_log.notify_world_changed()
	panels.refresh_if_open()


func _loot_for(table_id: String) -> Resource:
	var table: Resource = (load("res://scripts/data/loot_table.gd") as GDScript).new()
	match table_id:
		"slime":
			table.entries.assign([{"item_id": "purple_herb", "weight": 3.0, "min": 1, "max": 1}, {"item_id": "healing_potion", "weight": 1.0, "min": 1, "max": 1}])
		"skeleton":
			table.entries.assign([{"item_id": "bone_shard", "weight": 3.0, "min": 1, "max": 2}, {"item_id": "iron_ore", "weight": 1.5, "min": 1, "max": 1}])
		"mage":
			table.entries.assign([{"item_id": "crystal_shard", "weight": 2.0, "min": 1, "max": 1}, {"item_id": "mana_potion", "weight": 2.0, "min": 1, "max": 1}])
		"golem":
			table.entries.assign([{"item_id": "iron_ore", "weight": 3.0, "min": 2, "max": 3}, {"item_id": "amber_resin", "weight": 1.0, "min": 1, "max": 1}])
		"boss":
			table.guaranteed.assign([{"item_id": "bone_shard", "min": 3, "max": 5}, {"item_id": "elixir", "min": 1, "max": 1}])
			table.entries.assign([{"item_id": "greatsword", "weight": 1.0, "min": 1, "max": 1}, {"item_id": "bone_plate", "weight": 1.0, "min": 1, "max": 1}])
		_:
			return table
	return table


func _on_enemy_attacked(enemy: Node, amount: float) -> void:
	combat.receive_attack(enemy, amount)


func _on_boss_phase(enemy: Node, phase: int) -> void:
	hud.show_notice("%s enters phase %d!" % [enemy.display_name(), phase], 3.0)
	vfx.boss_phase_burst(enemy.global_position + enemy.current_direction, Color("ff5c2b"))
	camera_rig.shake(0.35)


func _on_damage_number(position: Vector3, amount: float, is_crit: bool, is_player: bool) -> void:
	vfx.damage_number(position, amount, is_crit, is_player)


func _on_hit_flash(enemy: Node) -> void:
	if enemy.model_root != null:
		var tween := create_tween()
		tween.tween_property(enemy.model_root, "scale", Vector3.ONE * 1.08, 0.06)
		tween.tween_property(enemy.model_root, "scale", Vector3.ONE, 0.1)
	camera_rig.shake(0.08)


func _on_player_hit() -> void:
	hud.flash_damage()
	camera_rig.shake(0.18)


func _on_level_up(new_level: int) -> void:
	hud.show_notice("Level %d! +1 skill point. Maximum health increased." % new_level, 4.0)
	vfx.heal_burst(player.global_position + player.current_direction)
	hud.refresh()


func _on_rank_changed(new_rank: String, _old: String) -> void:
	hud.show_notice("Guild rank promoted to %s!" % new_rank, 5.0)
	if audio != null:
		audio.play_ui("page")
	quest_log.notify_world_changed()


func _on_player_died() -> void:
	player.on_death()
	controls.set_actions_enabled(false)
	panels.open("death")
	if audio != null:
		audio.play_ui("cloth")


func _on_phase_changed(phase: String) -> void:
	var messages := {
		"dawn": "Dawn breaks over the planet.",
		"day": "The sun climbs.",
		"dusk": "Dusk. The skeletons grow bolder.",
		"night": "Night falls. Beware the ridge.",
	}
	if messages.has(phase):
		hud.show_notice(messages[phase], 3.0)


func _on_panel_requested(panel_id: String) -> void:
	if panel_id == "map":
		camera_rig.set_overview(true)
	panels.open(panel_id)
	_set_controls_enabled(false)


func _on_panel_closed() -> void:
	camera_rig.set_overview(false)
	_set_controls_enabled(true)


func _set_controls_enabled(enabled: bool) -> void:
	controls.set_actions_enabled(enabled)
	player.move_input = Vector2.ZERO if not enabled else player.move_input
	player.set_look_input(Vector2.ZERO)
	hud.set_action_buttons_visible(enabled)


func _on_panel_action(action: String, payload: Dictionary) -> void:
	match action:
		"equip":
			state.equip(String(payload.get("item", "")))
		"unequip":
			state.unequip(String(payload.get("slot", "")))
		"use":
			state.use_item(String(payload.get("item", "")))
			if audio != null:
				audio.play_potion()
		"sell":
			state.sell_item(String(payload.get("item", "")), 1)
			if audio != null:
				audio.play_coin()
		"buy":
			_buy_item(String(payload.get("item", "")), int(payload.get("price", 0)))
		"craft":
			var message: String = state.craft(String(payload.get("recipe", "")))
			hud.show_notice(message, 3.0)
			quest_log.notify_world_changed()
		"skill":
			state.spend_skill_point(String(payload.get("skill", "")))
		"cast":
			var result: Dictionary = combat.cast_spell(String(payload.get("spell", "")), play_seconds)
			hud.show_notice(String(result.get("message", "")), 2.5)
		"travel":
			_travel_to(String(payload.get("waypoint", "")))
		"guild_accept":
			var line: String = quest_log.accept_available()
			hud.show_notice("Maeve: " + line if line != "" else "Maeve: Nothing new to hand out.", 4.0)
		"guild_turn_in":
			var rewards: Array = quest_log.turn_in_ready()
			if rewards.is_empty():
				hud.show_notice("Maeve: Finish an objective first.", 3.0)
			else:
				var parts: Array[String] = []
				for reward in rewards:
					parts.append(reward["title"])
				hud.show_notice("Turned in: " + ", ".join(parts), 4.0)
				if audio != null:
					audio.play_coin()
		"guild_promote":
			if state.try_promote():
				hud.refresh()
			else:
				hud.show_notice("Requirements not met yet.", 3.0)
		"save":
			_save_now(true)
		"main_menu":
			_save_now(false)
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			return
		"settings_applied":
			audio.enabled = settings.audio_on()
			settings.apply_to_viewport()
			hud.set_performance_readout(settings.show_fps)
		"respawn":
			_respawn()
		"quit":
			_save_now(false)
			get_tree().quit()
	if is_instance_valid(panels) and panels.is_open():
		panels.refresh_if_open()
	hud.refresh()


func _buy_item(item_id: String, price: int) -> void:
	if not state.spend_gold(price):
		hud.show_notice("Not enough gold.", 2.0)
		return
	state.add_item(item_id, 1)
	hud.show_notice("Bought %s for %d gold." % [ItemDB.display_name(item_id), price], 2.5)
	if audio != null:
		audio.play_coin()


func _travel_to(waypoint_id: String) -> void:
	if waypoint_id not in state.waypoints:
		hud.show_notice("Light the shrine first.", 2.5)
		return
	for spec in WorldBuilder.SHRINES:
		if spec["id"] != waypoint_id:
			continue
		player.current_direction = Math3D.direction(spec["lon"], spec["lat"])
		player.height_offset = Terrain.elevation(player.current_direction)
		player._update_transform()
		camera_rig.set_overview(false)
		panels.close_panel()
		_update_camera_immediately()
		hud.show_notice("Travelled to %s." % spec["name"], 3.0)
		return


func _respawn() -> void:
	var respawn_direction := Math3D.direction(0.0, 0.004)
	state.revive_at(respawn_direction)
	player.respawn(respawn_direction)
	panels.close_panel()
	controls.set_actions_enabled(true)
	_session_death_handled = false
	hud.refresh()
	hud.show_notice("You awaken at the Havenbrook shrine.", 3.5)


func _save_now(announce: bool) -> void:
	state.time_of_day = clock.time_of_day
	state.day = clock.day
	state.stats["played_seconds"] = play_seconds
	var result := SaveGame.save(state)
	var ok: bool = result.ok
	if announce or not ok:
		hud.show_notice("Game saved." if ok else "Save failed: " + result.reason, 3.0)


# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	play_seconds += delta
	clock.advance(delta)
	state.time_of_day = clock.time_of_day
	state.day = clock.day
	if state.is_alive():
		state.regenerate(delta, combat.in_combat())
	_scan_nearby()
	_update_hud(delta)
	_update_target_frame()
	_autosave(delta)
	_sample_fps(delta)
	_update_performance_readout()


func _scan_nearby() -> void:
	nearest_interactable = null
	nearest_resource = null
	var best_distance := 4.2
	for node in interactables:
		if not is_instance_valid(node) or node.used:
			continue
		var distance: float = player.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest_interactable = node
	var best_resource := 4.0
	for node in resource_nodes:
		if not is_instance_valid(node) or not node.visible:
			continue
		var distance: float = player.global_position.distance_to(node.global_position)
		if distance < best_resource:
			best_resource = distance
			nearest_resource = node
	if nearest_interactable != null:
		hud.set_interaction_prompt("[E] " + nearest_interactable.prompt)
	elif nearest_resource != null:
		hud.set_interaction_prompt("[E] Gather " + nearest_resource.display_name)
	else:
		hud.set_interaction_prompt("")


func _update_hud(delta: float) -> void:
	_notice_cooldown -= delta
	hud.refresh()
	var hour := int(floorf(clock.time_of_day * 24.0))
	var minute := int(floorf(fposmod(clock.time_of_day * 24.0, 1.0) * 60.0))
	hud.set_clock("Day %d · %02d:%02d · %s" % [clock.day, hour, minute, clock.current_phase().capitalize()])
	var spell := SpellDB.create("ember_bolt")
	if spell != null:
		var remaining: float = float(state.spell_cooldowns.get("ember_bolt", 0.0)) - play_seconds
		var ready := remaining <= 0.0
		controls.set_spell_cooldown(0.0 if ready else clampf(remaining / maxf(0.01, spell.cooldown), 0.0, 1.0), ready)


func _update_target_frame() -> void:
	var nearest: Node = combat.nearest_enemy(14.0)
	target_enemy = nearest
	if nearest == null:
		hud.hide_target()
		return
	hud.show_target(nearest.display_name(), nearest.health_ratio(), nearest.data.is_boss())


func _autosave(delta: float) -> void:
	autosave_timer += delta
	if autosave_timer < 45.0:
		return
	autosave_timer = 0.0
	_save_now(false)


func _sample_fps(delta: float) -> void:
	if delta <= 0.0:
		return
	_fps_samples.append(1.0 / delta)
	if _fps_samples.size() > 600:
		_fps_samples.remove_at(0)


func _on_settings_changed() -> void:
	audio.enabled = settings.audio_on()
	settings.apply_to_viewport()
	hud.set_performance_readout(settings.show_fps)


func _update_performance_readout() -> void:
	if hud == null or not settings.show_fps:
		return
	var fps := Engine.get_frames_per_second()
	var objects := 0
	if simulation != null:
		objects = simulation.active_monster_count()
	hud.update_performance(
		"FPS %d · avg %d · 1%% low %d" % [fps, int(round(average_fps())), int(round(low_fps_percentile()))],
		"draw %d · nodes %d · active monsters %d · quality %s" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			objects,
			settings.quality,
		]
	)


func average_fps() -> float:
	if _fps_samples.is_empty():
		return 0.0
	var total := 0.0
	for value in _fps_samples:
		total += value
	return total / float(_fps_samples.size())


func low_fps_percentile() -> float:
	if _fps_samples.is_empty():
		return 0.0
	var copy := _fps_samples.duplicate()
	copy.sort()
	return copy[int(copy.size() * 0.05)]


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_save_now(false)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_save_now(false)
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_now(false)
