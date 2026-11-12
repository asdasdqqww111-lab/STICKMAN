extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_test")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else: failures += 1; printerr("FAIL: ", message)
func run_test() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	check(game.chunks.size() > 0 and game.chunks.size() <= 9, "bounded chunks loaded")
	for path in ["res://assets/gobkit/TreeMed001.glb", "res://assets/gobkit/Rock001.glb", "res://assets/gobkit/Bush001.glb", "res://assets/city/casa_simples.glb"]:
		check(load(path) is PackedScene, "imported scene loads: " + path)
	check(game.enemies.size() == 8, "slimes spawned")
	var start_direction: Vector3 = game.state.direction
	game.fast_travel("east")
	check(game.state.direction == start_direction, "undiscovered destination cannot be used")
	game._set_touch_direction("up", Vector2.UP, true)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._set_touch_direction("up", Vector2.UP, false)
	check(game.touch_input == Vector2.ZERO, "focus loss clears movement without a stale release")
	game._set_touch_direction("up", Vector2.UP, true)
	game.toggle_map()
	game._set_touch_direction("up", Vector2.UP, false)
	check(game.map_panel.visible and game.touch_input == Vector2.ZERO and game.travel_buttons.get_child_count() == 0, "map opens without undiscovered travel and clears held input")
	await process_frame
	game.toggle_map()
	game.interact()
	check(game.state.quest == "active" and "outpost" in game.state.waypoints, "guild interaction starts quest and activates outpost")
	var enemy = game.enemies[0]
	game.state.direction = enemy.direction
	game.attack(); game.cooldown = 0; game.attack(); game.cooldown = 0; game.attack()
	check(game.state.kills == 1 and game.state.defeated.size() == 1, "combat advances quest")
	var mana: float = game.state.mana
	game.cast_spell()
	check(game.state.mana < mana, "spell spends mana on target")
	while game.state.kills < 3:
		var next_enemy = game.enemies[0]
		game.state.direction = next_enemy.direction
		while is_instance_valid(next_enemy) and not next_enemy.is_queued_for_deletion():
			game.cooldown = 0
			game.attack()
	check(game.state.quest == "ready", "three kills make quest ready")
	game.state.direction = Vector3(0, 0, 1)
	game.interact()
	check(game.state.quest == "completed" and game.state.gold == 29, "registrar grants reward")
	game.interact()
	check(game.state.herb_quest == "active" and game.herb_nodes.size() == 8, "herb contract and resources exist in the world")
	for i in range(5):
		game.state.direction = game.herb_nodes[0].direction
		game.interact()
	check(game.state.herb_quest == "ready" and game.state.herbs == 5 and game.herb_nodes.size() == 3, "interaction gathers world resources")
	game.state.direction = Vector3(0, 0, 1)
	game.interact()
	check(game.state.herb_quest == "completed", "gathering contract completed at guild")
	while game.state.slime_count() < 5:
		var next_enemy = game.enemies[0]
		game.state.direction = next_enemy.direction
		while is_instance_valid(next_enemy) and not next_enemy.is_queued_for_deletion():
			game.cooldown = 0; game.attack()
	game.state.direction = Vector3(0, 0, 1)
	game.interact()
	check(game.state.rank == "E", "promotion is awarded at registrar")
	game.forge_sword()
	check(game.state.sword_forged and game.sword_visual.visible and game.state.herbs == 3, "forging changes equipped visual and inventory")
	game.craft_potion()
	game.state.health = 50
	game.use_potion()
	check(game.state.potions == 0 and game.state.health == 90, "scene crafting and healing affect player")
	var sphere = preload("res://scripts/sphere.gd")
	var waypoints = preload("res://scripts/waypoints.gd")
	game.state.direction = sphere.direction(0.3, 0.2)
	game._physics_process(0.016)
	check(game.chunks.size() <= 9 and game.state.discovered.size() >= 2, "region transition unloads and discovers")
	var guard = game.enemies[0]
	var guard_direction: Vector3 = guard.direction
	guard.direction = game.state.direction
	var blocked_position: Vector3 = game.state.direction
	game.fast_travel("outpost")
	check(game.state.direction == blocked_position, "nearby enemy blocks fast travel")
	guard.direction = waypoints.position("outpost")
	game.fast_travel("outpost")
	check(game.state.direction == blocked_position, "enemy near destination blocks fast travel")
	guard.direction = guard_direction
	game.state.direction = sphere.direction(PI - 0.00001, 0.25)
	game._physics_process(0.016)
	game.state.direction = sphere.direction(-PI + 0.00001, 0.25)
	game._physics_process(0.016)
	check(game.chunks.has(sphere.cell_id(game.state.direction)) and game.chunks.size() <= 9, "streamed cells survive longitude seam crossing")
	game.state.direction = waypoints.position("east")
	game.interact()
	check("east" in game.state.waypoints, "interacting with shrine activates it")
	game.toggle_map()
	check(game.travel_buttons.get_child_count() == 2, "map exposes only activated destinations")
	game.travel_buttons.get_child(0).pressed.emit()
	check(not game.map_panel.visible and game.state.direction.is_equal_approx(waypoints.position("outpost")), "map button travels to activated outpost")
	var Store = preload("res://scripts/save_store.gd")
	var path := "user://scene_test_save.json"; var backup := "user://scene_test_backup.json"; var temp := "user://scene_test_temp.json"
	check(Store.save_game(game.state, path, backup, temp), "scene state saves")
	var loaded = Store.load_game(path, backup)
	check(loaded != null and loaded.rank == "E" and loaded.sword_forged and loaded.gathered.size() == 5 and loaded.waypoints.has("east") and loaded.waypoints.has("outpost"), "scene progress and waypoints reload")
	for file in [path, backup, temp]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	game.queue_free()
	await process_frame
	var game_reloaded = packed.instantiate()
	game_reloaded.state = loaded
	root.add_child(game_reloaded)
	await process_frame
	check(game_reloaded.herb_nodes.size() == 3 and game_reloaded.enemies.size() == 3 and game_reloaded.sword_visual.visible, "reloaded world honors collected, defeated and equipment state")
	game_reloaded.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
