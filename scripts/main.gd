extends Node3D
const State = preload("res://scripts/game_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Sphere = preload("res://scripts/sphere.gd")
const Cells = preload("res://scripts/world_cells.gd")
const Waypoints = preload("res://scripts/waypoints.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Enemy = preload("res://scripts/enemy.gd")
const TREE = preload("res://assets/gobkit/TreeMed001.glb")
const ROCK = preload("res://assets/gobkit/Rock001.glb")
const BUSH = preload("res://assets/gobkit/Bush001.glb")
const HOUSE = preload("res://assets/city/casa_simples.glb")

var state = State.new()
var player: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var chunks := {}
var enemies: Array[Node] = []
var herb_nodes: Array[Dictionary] = []
var sword_visual: MeshInstance3D
var map_panel: PanelContainer
var map_view: Control
var travel_buttons: HBoxContainer
var map_status: Label
var hud: Label
var notice: Label
var target_label: Label
var quest_label: Label
var touch_input := Vector2.ZERO
var held_directions := {}
var cooldown := 0.0
var spell_cooldown := 0.0
var save_timer := 0.0
var overview := false
var last_cell := ""
var notice_timer := 0.0

func _ready() -> void:
	var loaded = SaveStore.load_game()
	if loaded != null: state = loaded
	_make_environment()
	_make_planet()
	_make_player()
	_make_landmarks()
	_make_waypoints()
	_make_enemies()
	_make_herbs()
	_make_ui()
	_update_player()
	_update_chunks()
	_show_notice("WASD / arrows to move · E interact · Space attack · Q spell")

func _make_environment() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("172941")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9cbd4")
	settings.ambient_light_energy = 0.75
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings; add_child(env)
	sun = DirectionalLight3D.new(); sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-45, 30, 0); add_child(sun)

func _make_planet() -> void:
	# A real sphere; the prototype uses analytic surface constraints rather than physics collision.
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = Sphere.RADIUS; mesh.height = Sphere.RADIUS * 2
	mesh.radial_segments = 96; mesh.rings = 48
	body.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("628c64"); mat.roughness = 1.0
	body.material_override = mat; add_child(body)

func _make_player() -> void:
	player = Node3D.new(); add_child(player)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = 0.32; mesh.height = 1.4
	body.mesh = mesh; body.position.y = 0.8
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("e6c58e")
	body.material_override = mat; player.add_child(body)
	var cloak := MeshInstance3D.new(); var cloak_mesh := BoxMesh.new(); cloak_mesh.size = Vector3(0.7, 0.65, 0.35)
	cloak.mesh = cloak_mesh; cloak.position = Vector3(0, 0.75, 0)
	var blue := StandardMaterial3D.new(); blue.albedo_color = Color("345a8d"); cloak.material_override = blue; player.add_child(cloak)
	sword_visual = MeshInstance3D.new()
	var blade := BoxMesh.new(); blade.size = Vector3(0.12, 1.0, 0.18)
	sword_visual.mesh = blade; sword_visual.position = Vector3(0.5, 0.8, 0)
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color("cbd7db")
	sword_visual.material_override = steel; player.add_child(sword_visual)
	sword_visual.visible = state.sword_forged
	camera = Camera3D.new(); camera.fov = 55; camera.far = 1600; add_child(camera); camera.current = true

func _place(node: Node3D, dir: Vector3, offset: float = 0.0) -> void:
	var n: Vector3 = Sphere.north(dir)
	node.position = dir * (Sphere.RADIUS + offset)
	node.basis = Basis(n.cross(dir).normalized(), dir, -n).orthonormalized()

func _make_landmarks() -> void:
	# The house marks a guild outpost; it is not an enterable building.
	for entry in [[0.0, 0.012, 1.0], [-0.016, 0.019, 0.8], [0.018, 0.022, 0.8]]:
		var house: Node3D = HOUSE.instantiate(); add_child(house)
		_place(house, Sphere.direction(entry[0], entry[1])); house.scale = Vector3.ONE * entry[2]
	var guild := MeshInstance3D.new(); var m := CapsuleMesh.new(); m.radius = 0.3; m.height = 1.4; guild.mesh = m
	var material := StandardMaterial3D.new(); material.albedo_color = Color("e9aa51"); guild.material_override = material
	add_child(guild); _place(guild, Sphere.direction(0, 0.006), 0.7)

func _make_waypoints() -> void:
	for id in ["east", "north"]:
		var marker := MeshInstance3D.new(); var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32; mesh.bottom_radius = 0.5; mesh.height = 1.5
		marker.mesh = mesh
		var material := StandardMaterial3D.new(); material.albedo_color = Color("d7b676")
		marker.material_override = material; add_child(marker)
		_place(marker, Waypoints.position(id), 0.75)

func _make_enemies() -> void:
	for i in range(8):
		var id := "meadow_slime_%d" % i
		if id in state.defeated: continue
		var enemy = Enemy.new()
		enemy.initialize(id, Sphere.direction(-0.035 + (i % 4) * 0.021, 0.045 + floori(i / 4.0) * 0.023), self)
		add_child(enemy); enemies.append(enemy)

func _make_herbs() -> void:
	# Fixed collectible identities are persisted, preventing duplicate harvesting on reload.
	var locations := [[-0.035, 0.025], [0.033, 0.028], [-0.055, 0.048], [0.048, 0.05], [-0.04, 0.075], [0.04, 0.077], [0.0, 0.09], [0.07, 0.08]]
	for i in range(locations.size()):
		var id := "herb_%d" % i
		if id in state.gathered: continue
		var dir: Vector3 = Sphere.direction(locations[i][0], locations[i][1])
		var plant := MeshInstance3D.new(); var mesh := SphereMesh.new()
		mesh.radius = 0.35; mesh.height = 0.7; plant.mesh = mesh
		var material := StandardMaterial3D.new(); material.albedo_color = Color("be73e3")
		material.emission_enabled = true; material.emission = Color("5d2677"); plant.material_override = material
		add_child(plant); _place(plant, dir, 0.35)
		herb_nodes.append({"id": id, "direction": dir, "node": plant})

func _update_player() -> void:
	_place(player, state.direction)
	var n: Vector3 = Sphere.north(state.direction)
	if overview:
		camera.position = state.direction * (Sphere.RADIUS * 2.7) - n * Sphere.RADIUS * 0.5
		camera.look_at(Vector3.ZERO, n)
	else:
		camera.position = player.position + state.direction * 5.5 - n * 8.0
		camera.look_at(player.position + state.direction, state.direction)

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta); spell_cooldown = maxf(0.0, spell_cooldown - delta)
	var axis := touch_input
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): axis.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): axis.y -= 1
	axis = axis.limit_length(1.0)
	if not overview and not map_panel.visible: state.direction = Sphere.move(state.direction, axis, 5.0 * delta)
	state.mana = minf(State.MAX_MANA, state.mana + delta * 1.2)
	state.time_of_day = fposmod(state.time_of_day + delta / 600.0, 1.0)
	sun.rotation.x = state.time_of_day * TAU
	_update_player()
	var cell: String = Sphere.cell_id(state.direction)
	if cell != last_cell:
		last_cell = cell
		if state.discover(cell): _show_notice("Region discovered! +2 XP")
		_update_chunks()
	save_timer += delta
	if save_timer >= 30.0:
		save_timer = 0.0
		if not SaveStore.save_game(state): _show_notice("Autosave failed")
	if notice_timer > 0: notice_timer -= delta
	elif notice != null: notice.text = ""
	_update_hud()

func _update_chunks() -> void:
	var wanted: Array[String] = Cells.neighbors(state.direction)
	for id in wanted:
		if not chunks.has(id): _create_chunk(id)
	for id in chunks.keys():
		if id not in wanted:
			chunks[id].queue_free(); chunks.erase(id)

func _create_chunk(id: String) -> void:
	var root := Node3D.new(); add_child(root); chunks[id] = root
	var rng := RandomNumberGenerator.new(); rng.seed = hash(id)
	for i in range(4):
		var dir: Vector3 = Cells.point(id, rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
		if dir.distance_to(Vector3(0, 0, 1)) * Sphere.RADIUS < 9.0: continue
		var resource: PackedScene = [TREE, TREE, ROCK, BUSH][i]
		var asset: Node3D = resource.instantiate(); root.add_child(asset)
		_place(asset, dir)
		asset.scale = Vector3.ONE * rng.randf_range(0.7, 1.3)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if map_panel != null and map_panel.visible:
		if event.keycode == KEY_TAB: toggle_map()
		return
	match event.keycode:
		KEY_SPACE: attack()
		KEY_Q: cast_spell()
		KEY_E: interact()
		KEY_M: toggle_overview()
		KEY_TAB: toggle_map()
		KEY_C: craft_potion()
		KEY_H: use_potion()
		KEY_F: forge_sword()
		KEY_F5: save_now()

func _nearest_enemy(max_distance: float):
	var best = null; var best_distance := max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		var d: float = state.direction.distance_to(enemy.direction) * Sphere.RADIUS
		if d < best_distance: best = enemy; best_distance = d
	return best

func attack() -> void:
	if cooldown > 0: return
	cooldown = 0.5
	var enemy = _nearest_enemy(2.4)
	if enemy != null:
		var damage: float = state.melee_damage()
		enemy.hit(damage)
		if not enemy.is_queued_for_deletion(): _show_notice("Strike! %d damage" % damage)
	else: _show_notice("No enemy in reach")

func cast_spell() -> void:
	if spell_cooldown > 0: _show_notice("Spell recharging"); return
	if state.mana < 10: _show_notice("Not enough mana"); return
	var enemy = _nearest_enemy(10.0)
	if enemy == null: _show_notice("No enemy in spell range"); return
	state.mana -= 10; spell_cooldown = 2.0
	enemy.hit(25.0 + state.level * 2)
	if not enemy.is_queued_for_deletion(): _show_notice("Arcane bolt! −10 mana")

func enemy_defeated(enemy: Node) -> void:
	if state.defeat(enemy.enemy_id): _show_notice("Slime defeated · +12 XP · +3 gold")
	enemies.erase(enemy)

func take_damage(amount: float) -> void:
	state.health -= amount
	if state.health <= 0:
		state.health = state.max_health(); state.direction = Vector3(0, 0, 1)
		_show_notice("You were defeated. Returned to the guild outpost.")
	else: _show_notice("Slime hit you for %d" % amount)

func interact() -> void:
	var guild_dir: Vector3 = Sphere.direction(0, 0.006)
	if state.direction.distance_to(guild_dir) * Sphere.RADIUS < 3.0:
		var unlocked: bool = state.unlock_waypoint("outpost")
		var message: String = state.interact_guild()
		_show_notice(message + (" Outpost travel unlocked." if unlocked else "")); return
	for id in ["east", "north"]:
		if state.direction.distance_to(Waypoints.position(id)) * Sphere.RADIUS < 2.5:
			if state.unlock_waypoint(id): _show_notice("Travel unlocked: " + Waypoints.POINTS[id].name)
			else: _show_notice("Travel point: " + Waypoints.POINTS[id].name)
			return
	var closest := -1; var distance := 2.5
	for i in range(herb_nodes.size()):
		var d: float = state.direction.distance_to(herb_nodes[i].direction) * Sphere.RADIUS
		if d < distance: distance = d; closest = i
	if closest >= 0:
		var herb: Dictionary = herb_nodes[closest]
		if state.gather(herb.id):
			herb.node.queue_free(); herb_nodes.remove_at(closest)
			_show_notice("Herb gathered! %d in inventory." % state.herbs)
		return
	_show_notice("Talk near the registrar or gather a purple herb.")

func craft_potion() -> void:
	_show_notice(state.craft_potion())

func use_potion() -> void:
	_show_notice(state.use_potion())

func forge_sword() -> void:
	_show_notice(state.forge_sword())
	sword_visual.visible = state.sword_forged

func toggle_map() -> void:
	map_panel.visible = not map_panel.visible
	held_directions.clear(); touch_input = Vector2.ZERO
	if map_panel.visible:
		map_status.text = ""
		map_view.queue_redraw()
		_refresh_travel_buttons()

func _refresh_travel_buttons() -> void:
	for child in travel_buttons.get_children():
		travel_buttons.remove_child(child); child.queue_free()
	for id in state.waypoints:
		_button(travel_buttons, Waypoints.POINTS[id].name, fast_travel.bind(id))

func fast_travel(id: String) -> void:
	if id not in state.waypoints or not Waypoints.POINTS.has(id):
		_show_notice("Discover and activate this shrine first."); return
	var destination: Vector3 = Waypoints.position(id)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		if enemy.direction.distance_to(state.direction) * Sphere.RADIUS < 8.0 or enemy.direction.distance_to(destination) * Sphere.RADIUS < 8.0:
			_show_notice("Cannot travel while enemies are nearby at either end."); return
	state.direction = destination
	map_panel.visible = false
	_update_player()
	_show_notice("Travelled to " + Waypoints.POINTS[id].name)

func toggle_overview() -> void:
	overview = not overview
	_show_notice("Planet overview" if overview else "Adventure camera")

func save_now() -> void:
	_show_notice("World saved" if SaveStore.save_game(state) else "Save failed")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		held_directions.clear(); touch_input = Vector2.ZERO
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		SaveStore.save_game(state)

func _show_notice(text: String) -> void:
	if notice != null: notice.text = text; notice_timer = 4.0
	if map_status != null and map_panel != null and map_panel.visible: map_status.text = text

func _update_hud() -> void:
	if hud == null: return
	hud.text = "LV %d   %d / %d XP   |   HP %d / %d   MANA %d / 50   |   %d GOLD   RANK %s" % [state.level, state.xp, state.xp_needed(), state.health, state.max_health(), state.mana, state.gold, state.rank]
	var descriptions := {"available": "Speak to the guild registrar", "active": "Guild: defeat slimes %d / 3" % state.kills, "ready": "Return to the guild registrar", "completed": "Contract complete · explore the planet"}
	var objective: String = descriptions[state.quest]
	if state.quest == "completed":
		match state.herb_quest:
			"available": objective = "Speak to the registrar for a new contract"
			"active": objective = "Gather purple herbs: %d / 3" % mini(state.gathered.size(), 3)
			"ready": objective = "Return to the registrar with the herb report"
			"completed": objective = "Rank D reached · explore the planet" if state.rank == "D" else "Ask the registrar about promotion"
	quest_label.text = objective + " | Regions: %d | Herbs: %d | Potions: %d | Sword: %s" % [state.discovery_count(), state.herbs, state.potions, "iron" if state.sword_forged else "basic"]
	var enemy = _nearest_enemy(10.0)
	target_label.text = "SLIME  HP %d" % maxi(0, int(enemy.health)) if enemy != null else ""

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size = Vector2(82, 50)
	button.pressed.connect(callback); parent.add_child(button); return button

func _set_touch_direction(key: String, vector: Vector2, pressed: bool) -> void:
	if pressed: held_directions[key] = vector
	else: held_directions.erase(key)
	touch_input = Vector2.ZERO
	for value in held_directions.values(): touch_input += value

func _movement_button(parent: Control, text: String, vector: Vector2) -> void:
	var button := Button.new(); button.text = text; button.custom_minimum_size = Vector2(70, 50)
	button.button_down.connect(_set_touch_direction.bind(text, vector, true))
	button.button_up.connect(_set_touch_direction.bind(text, vector, false))
	parent.add_child(button)

func _make_ui() -> void:
	var canvas := CanvasLayer.new(); add_child(canvas)
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(root)
	var top := VBoxContainer.new(); top.position = Vector2(20, 16); root.add_child(top)
	hud = Label.new(); hud.add_theme_font_size_override("font_size", 20); top.add_child(hud)
	quest_label = Label.new(); quest_label.add_theme_font_size_override("font_size", 17); top.add_child(quest_label)
	target_label = Label.new(); top.add_child(target_label)
	notice = Label.new(); notice.add_theme_font_size_override("font_size", 19); top.add_child(notice)
	var bottom := HBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_top = -130; bottom.offset_left = 20; bottom.offset_right = -20; bottom.offset_bottom = -15; root.add_child(bottom)
	var movement := VBoxContainer.new(); bottom.add_child(movement)
	var row1 := HBoxContainer.new(); movement.add_child(row1)
	_movement_button(row1, "◀", Vector2(-1, 0)); _movement_button(row1, "▲", Vector2(0, 1)); _movement_button(row1, "▶", Vector2(1, 0))
	var row2 := HBoxContainer.new(); movement.add_child(row2); _movement_button(row2, "▼", Vector2(0, -1))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(spacer)
	var actions := VBoxContainer.new(); bottom.add_child(actions)
	var a := HBoxContainer.new(); actions.add_child(a)
	_button(a, "ATTACK", attack); _button(a, "SPELL", cast_spell); _button(a, "TALK", interact)
	var b := HBoxContainer.new(); actions.add_child(b)
	_button(b, "CRAFT", craft_potion); _button(b, "HEAL", use_potion); _button(b, "FORGE", forge_sword); _button(b, "PLANET", toggle_overview); _button(b, "MAP", toggle_map); _button(b, "SAVE", save_now)

	map_panel = PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.offset_left = 100; map_panel.offset_right = -100
	map_panel.offset_top = 85; map_panel.offset_bottom = -100
	root.add_child(map_panel)
	var map_layout := VBoxContainer.new(); map_panel.add_child(map_layout)
	var title := Label.new(); title.text = "WORLD MAP  |  discovered cells · unlocked shrines · player"
	map_layout.add_child(title)
	map_view = WorldMap.new(); map_view.state = state; map_layout.add_child(map_view)
	var legend := Label.new(); legend.text = "Green: discovered   Gold: activated shrine   White: you. Activate shrines with TALK."
	map_layout.add_child(legend)
	map_status = Label.new(); map_layout.add_child(map_status)
	travel_buttons = HBoxContainer.new(); map_layout.add_child(travel_buttons)
	_button(map_layout, "CLOSE MAP", toggle_map)
	map_panel.visible = false
