extends "res://tests/test_runner.gd"
## Scene-level integration: the real Game scene boots headlessly, builds the
## planet, spawns the world content, then completes a scripted play session.

const GameScene = "res://scenes/Game.tscn"
const AppScene = "res://scenes/App.tscn"
const SaveGame = preload("res://scripts/core/save_game.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")

var game: Node
var _started := false


func _initialize() -> void:
	call_deferred("_run_scene_tests")


func _run_scene_tests() -> void:
	suite_name = "scene"
	await _test_scene_files()
	await _test_app_scene()
	await _test_game_scene()
	await _test_play_session()
	print("RESULT %s: %d checks, %d failures" % [suite_name, checks, failures])
	quit(failures)


func _test_scene_files() -> void:
	for path in [GameScene, AppScene, "res://scenes/AssetShowcase.tscn"]:
		check_true(ResourceLoader.exists(path), "scene exists: " + path)
		var packed := load(path)
		check_true(packed is PackedScene, "scene resource loads: " + path)
		var instance: Node = (packed as PackedScene).instantiate()
		check_true(instance != null, "scene instantiates: " + path)
		instance.queue_free()
	await process_frame


func _test_app_scene() -> void:
	var packed := load(AppScene) as PackedScene
	var app: Node = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	check_true(app.menu != null, "main menu is created")
	if app.menu != null:
		check_true(app.menu.continue_button != null, "menu has a continue button")
		check_false(app.menu.continue_button.disabled and SaveGame.has_save(), "continue is enabled when a save exists")
		check_eq(app.menu.hero_name(), "Wanderer", "menu defaults the hero name")
	app.queue_free()
	await process_frame


func _test_game_scene() -> void:
	# Start from a clean save so the "new game" path is exercised.
	SaveGame.erase_all()
	var packed := load(GameScene) as PackedScene
	game = packed.instantiate()
	game.start_mode = "new"
	game.hero_name = "Tester"
	root.add_child(game)
	await process_frame
	await process_frame
	check_true(game.state != null, "game creates a PlayerState")
	check_eq(game.state.hero_name, "Tester", "hero name is applied")
	check_true(game.player != null, "player node exists")
	check_true(game.camera_rig != null and game.camera_rig.camera != null, "camera rig exists")
	check_true(game.planet_root != null, "planet is built")
	check_eq(game.planet_root.get_child_count() >= 6, true, "planet has six faces plus ocean")
	check_true(game.clock != null, "world clock exists")
	check_true(game.combat != null, "combat system exists")
	check_true(game.vfx != null, "vfx exists")
	check_true(game.audio != null, "audio exists")
	check_true(game.hud != null and game.controls != null and game.panels != null, "UI layers exist")
	check_true(game.interactables.size() >= 10, "interactables were placed (%d)" % game.interactables.size())
	check_true(game.resource_nodes.size() >= 10, "resource nodes were placed (%d)" % game.resource_nodes.size())
	check_true(game.npcs.size() >= 3, "NPCs were placed")
	check_true(game.enemies.size() >= 10, "monsters were spawned (%d)" % game.enemies.size())
	check_true(game.simulation != null, "streaming simulation exists")
	check_true(game.simulation.total_monsters() > 0, "simulation tracks monsters")
	# The player must be standing on the terrain surface.
	var altitude: float = game.player.global_position.length()
	var expected: float = 250.0 + preload("res://scripts/planet/terrain.gd").elevation(game.player.current_direction)
	check_near(altitude, expected, 0.5, "player is snapped to the terrain surface")
	check_true(game.state.health > 0.0, "player starts alive")


func _test_play_session() -> void:
	if game == null:
		return
	# --- movement ----------------------------------------------------------
	var start_direction: Vector3 = game.player.current_direction
	game.player.move_input = Vector2(0, 1)
	for i in range(20):
		await physics_frame
	game.player.move_input = Vector2.ZERO
	var moved: float = start_direction.angle_to(game.player.current_direction) * 250.0
	check_true(moved > 1.0, "player moves forward on the planet (%.1f m)" % moved)
	# --- camera stays outside the planet -----------------------------------
	check_true(game.camera_rig.camera.global_position.length() > 250.0, "camera stays outside the planet")
	# --- discovery ---------------------------------------------------------
	var discovered_before: int = game.state.discovered.size()
	for i in range(90):
		game.player.move_input = Vector2(1, 0)
		await physics_frame
	game.player.move_input = Vector2.ZERO
	check_true(game.state.discovered.size() >= discovered_before, "exploration records regions")
	# --- combat ------------------------------------------------------------
	var enemy: Node = null
	for candidate in game.enemies:
		if is_instance_valid(candidate) and candidate.alive:
			enemy = candidate
			break
	check_true(enemy != null, "a living monster exists for the combat test")
	if enemy != null:
		var health_before: float = enemy.health
		var damage: float = enemy.take_damage(25.0)
		check_true(damage > 0.0, "monster takes damage")
		check_true(enemy.health < health_before, "monster health decreases")
		var killed: bool = false
		enemy.defeated.connect(func(_node: Node, _archetype: String) -> void: killed = true)
		while enemy.alive and is_instance_valid(enemy):
			enemy.take_damage(1000.0)
			await process_frame
		check_true(killed, "monster defeat signal fires")
		check_true(game.state.total_kills_of(enemy.data.id) > 0, "kill is recorded in state")
	# --- harvesting --------------------------------------------------------
	var node = game.resource_nodes[0] if not game.resource_nodes.is_empty() else null
	check_true(node != null, "a resource node is available")
	if node != null:
		var herbs_before: int = game.state.item_count("purple_herb") + game.state.item_count("iron_ore")
		var result: Dictionary = node.harvest()
		check_false(result.is_empty(), "harvest returns loot")
		game._on_resource_harvested(node.node_id, result["item_id"], result["amount"])
		var herbs_after: int = game.state.item_count("purple_herb") + game.state.item_count("iron_ore")
		check_true(herbs_after > herbs_before, "harvested item enters the inventory")
		check_true(node.node_id in game.state.gathered, "harvested node is recorded as gathered")
	# --- shrine + fast travel ---------------------------------------------
	var shrine: Node = null
	for candidate in game.interactables:
		if candidate.kind == 0 and not candidate.used:
			shrine = candidate
			break
	if shrine != null:
		var waypoints_before: int = game.state.waypoints.size()
		game._on_interactable_activated(shrine)
		check_eq(game.state.waypoints.size(), waypoints_before + 1, "shrine activation unlocks a waypoint")
		game._travel_to(shrine.id)
		check_near(game.player.current_direction.angle_to(shrine.global_position.normalized()), 0.0, 0.01, "fast travel moves the player to the shrine")
	# --- chest -------------------------------------------------------------
	var chest: Node = null
	for candidate in game.interactables:
		if candidate.kind == 1 and not candidate.used:
			chest = candidate
			break
	if chest != null:
		var gold_before: int = game.state.gold
		game._on_interactable_activated(chest)
		check_true(game.state.gold > gold_before, "opening a chest grants gold")
		check_true(chest.id in game.state.opened_chests, "opened chest is recorded")
	# --- quest flow --------------------------------------------------------
	game._talk_to_registrar()
	await process_frame
	game.quest_log.register_talk("registrar")
	var ready := game.quest_log.turn_in_ready()
	check_true(ready.size() > 0, "the first contract can be turned in")
	check_true(game.state.quests_completed() >= 1, "quest completion is recorded")
	# --- crafting ----------------------------------------------------------
	game.state.add_item("purple_herb", 4)
	game.state.add_gold(10)
	var crafted: String = game.state.craft("healing_potion")
	check_true(crafted.begins_with("Crafted"), "potion crafting succeeds in the live session: " + crafted)
	# --- equipment ---------------------------------------------------------
	game.state.add_item("iron_sword", 1)
	check_true(game.state.equip("iron_sword"), "equipping a weapon works in the live session")
	game.player.refresh_equipment()
	await process_frame
	# --- save & reload -----------------------------------------------------
	game._save_now(false)
	await process_frame
	check_true(SaveGame.has_save(), "game writes a save file")
	var reloaded = SaveGame.load_state()
	check_true(reloaded != null, "saved game reloads")
	if reloaded != null:
		check_eq(reloaded.hero_name, "Tester", "reload preserves the hero")
		check_eq(reloaded.item_count("purple_herb"), game.state.item_count("purple_herb"), "reload preserves materials")
		check_eq(reloaded.equipment["weapon"], "iron_sword", "reload preserves equipment")
		check_true(SaveGame.peek_metadata().get("level", 0) >= 1, "save metadata is readable")
	# --- pause / panels ----------------------------------------------------
	game._on_panel_requested("inventory")
	await process_frame
	check_true(game.panels.is_open(), "inventory panel opens")
	game.panels.close_panel()
	await process_frame
	check_false(game.panels.is_open(), "panel closes")
	for panel_id in ["quests", "map", "spells", "guild", "shop", "skills", "crafting", "equipment", "pause", "settings"]:
		game._on_panel_requested(panel_id)
		await process_frame
		check_true(game.panels.is_open(), "panel renders: " + panel_id)
		game.panels.close_panel()
		await process_frame
	# --- death & respawn ---------------------------------------------------
	game.state.take_damage(10000.0)
	await process_frame
	check_false(game.state.is_alive(), "player can die")
	game._respawn()
	await process_frame
	check_true(game.state.is_alive(), "respawn restores the player")
	check_true(game.state.health > 0.0, "respawn grants health")
