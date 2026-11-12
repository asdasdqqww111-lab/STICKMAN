extends Control
## All gameplay windows: inventory, equipment, quests, map, spells, guild,
## shop, skills, crafting, pause/settings.  One Control, one panel visible at a
## time, every list built from live PlayerState data.

signal closed
signal action_requested(action: String, payload: Dictionary)

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")
const QuestDB = preload("res://scripts/data/quest_database.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const Regions = preload("res://scripts/planet/planet_regions.gd")
const WorldBuilder = preload("res://scripts/world/world_builder.gd")
const Math3D = preload("res://scripts/planet/sphere_math.gd")

const PANEL_TITLES := {
	"inventory": "Inventory", "equipment": "Equipment", "quests": "Quest Journal",
	"map": "World Map", "spells": "Grimoire", "guild": "Guild Registrar",
	"shop": "Village Shop", "skills": "Skills", "crafting": "Forge & Crafting",
	"pause": "Paused", "settings": "Settings", "death": "You Have Fallen",
}

var state: RefCounted
var quest_log: RefCounted
var player: Node3D
var settings: RefCounted
var active_panel := ""

var _frame: PanelContainer
var _title: Label
var _body: VBoxContainer
var _footer: Label
var _map_view: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = 40
	_frame.offset_right = -40
	_frame.offset_top = 32
	_frame.offset_bottom = -32
	add_child(_frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_frame.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = UITheme.label("Panel", 26, UITheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := UITheme.button("CLOSE ✕", Vector2(120, 44))
	close.pressed.connect(close_panel)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)

	_footer = UITheme.label("", 14, UITheme.MUTED)
	layout.add_child(_footer)


func bind(player_state: RefCounted, log: RefCounted, player_node: Node3D, settings_ref: RefCounted = null) -> void:
	state = player_state
	quest_log = log
	player = player_node
	settings = settings_ref


func is_open() -> bool:
	return visible and active_panel != ""


func open(panel_id: String) -> void:
	if state == null:
		return
	active_panel = panel_id
	visible = true
	_title.text = PANEL_TITLES.get(panel_id, panel_id.capitalize())
	_clear(_body)
	_map_view = null
	match panel_id:
		"inventory": _build_inventory()
		"equipment": _build_equipment()
		"quests": _build_quests()
		"map": _build_map()
		"spells": _build_spells()
		"guild": _build_guild()
		"shop": _build_shop()
		"skills": _build_skills()
		"crafting": _build_crafting()
		"pause": _build_pause()
		"settings": _build_settings()
		"death": _build_death()
		_: _body.add_child(UITheme.label("Nothing here yet.", 18, UITheme.MUTED))


func close_panel() -> void:
	active_panel = ""
	visible = false
	emit_signal("closed")


func refresh_if_open() -> void:
	if is_open():
		var current := active_panel
		open(current)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func _build_inventory() -> void:
	var rows := state.inventory_rows()
	if rows.is_empty():
		_body.add_child(UITheme.label("Your pack is empty. Harvest herbs and ore in the meadows.", 18, UITheme.MUTED))
	else:
		for row in rows:
			var item_id: String = row["id"]
			var definition := ItemDB.create(item_id)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			var name_label := UITheme.label("%s  ×%d" % [definition.display_name, int(row["count"])], 18)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(name_label)
			var description := UITheme.label(definition.description, 14, UITheme.MUTED)
			description.custom_minimum_size.x = 260
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.add_child(description)
			if definition.is_equipment():
				var equip := UITheme.button("EQUIP", Vector2(96, 40))
				equip.pressed.connect(func() -> void: _emit_and_refresh("equip", {"item": item_id}))
				line.add_child(equip)
			if definition.heal > 0.0 or definition.mana > 0.0:
				var use := UITheme.button("USE", Vector2(80, 40))
				use.pressed.connect(func() -> void: _emit_and_refresh("use", {"item": item_id}))
				line.add_child(use)
			var sell := UITheme.button("SELL %dG" % state.sell_price(item_id), Vector2(110, 40))
			sell.pressed.connect(func() -> void: _emit_and_refresh("sell", {"item": item_id}))
			line.add_child(sell)
			_body.add_child(line)
			_body.add_child(HSeparator.new())
	_footer.text = "Gold: %d · Slots used: %d · Rarity colour hints value" % [state.gold, state.inventory_slots_used()]


func _build_equipment() -> void:
	for slot in ["weapon", "offhand", "armour"]:
		var item_id: String = state.equipment.get(slot, "")
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var slot_label := UITheme.label(slot.capitalize() + ":", 18, UITheme.MUTED)
		slot_label.custom_minimum_size.x = 110
		line.add_child(slot_label)
		var name_text := "— empty —" if item_id == "" else ItemDB.display_name(item_id)
		var name_label := UITheme.label(name_text, 18, UITheme.PARCHMENT if item_id != "" else UITheme.MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		if item_id != "":
			var definition := ItemDB.create(item_id)
			var stats := []
			if definition.attack > 0.0:
				stats.append("+%d ATK" % int(definition.attack))
			if definition.defence > 0.0:
				stats.append("+%d DEF" % int(definition.defence))
			if definition.power > 0.0:
				stats.append("+%d POW" % int(definition.power))
			line.add_child(UITheme.label(" ".join(stats), 16, UITheme.ACCENT))
			var unequip := UITheme.button("REMOVE", Vector2(100, 40))
			unequip.pressed.connect(func() -> void: _emit_and_refresh("unequip", {"slot": slot}))
			line.add_child(unequip)
		_body.add_child(line)
	_body.add_child(HSeparator.new())
	_body.add_child(UITheme.label("Attack %d  ·  Defence %d  ·  Spell power %d%%" % [int(state.attack_power()), int(state.defence()), int(state.spell_power() * 100.0)], 18, UITheme.GOLD))
	_body.add_child(UITheme.label("Equip gear from the Inventory panel. Two-handed weapons clear the offhand.", 15, UITheme.MUTED))


func _build_quests() -> void:
	var any := false
	for spec in QuestDB.ordered():
		var quest_id: String = spec["id"]
		var quest_state := state.quest_state(quest_id)
		if quest_state == QuestData.State.LOCKED:
			continue
		any = true
		var box := VBoxContainer.new()
		var row := HBoxContainer.new()
		var title := UITheme.label(spec["title"], 19, UITheme.GOLD if quest_state != QuestData.State.COMPLETED else UITheme.MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var state_names := ["Locked", "Available", "Active", "Ready", "Completed"]
		row.add_child(UITheme.label(state_names[clampi(quest_state, 0, 4)], 16, UITheme.ACCENT if quest_state == QuestData.State.READY else UITheme.MUTED))
		box.add_child(row)
		box.add_child(UITheme.label(spec.get("summary", ""), 15, UITheme.MUTED))
		var quest := QuestDB.create(quest_id)
		if quest != null:
			box.add_child(UITheme.label(quest.objective_text(state.quest_progress(quest_id)), 16, UITheme.PARCHMENT))
		if quest_state == QuestData.State.ACTIVE or quest_state == QuestData.State.READY:
			box.add_child(UITheme.label("Reward: %d XP · %d gold" % [spec.get("xp", 0), spec.get("gold", 0)], 14, UITheme.MUTED))
		_body.add_child(box)
		_body.add_child(HSeparator.new())
	if not any:
		_body.add_child(UITheme.label("No contracts yet. Speak with Registrar Maeve at the guild hall.", 18, UITheme.MUTED))
	_footer.text = "Completed %d / %d contracts. Turn in ready contracts at the registrar." % [state.quests_completed(), QuestDB.count()]


func _build_map() -> void:
	var map := Control.new()
	map.custom_minimum_size = Vector2(0, 420)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(func() -> void: _draw_map(map))
	_body.add_child(map)
	_map_view = map
	_body.add_child(UITheme.label("● green = discovered region   ◆ gold = activated shrine   ○ white = you", 15, UITheme.MUTED))
	for entry in WorldBuilder.SHRINES:
		var shrine_id: String = entry["id"]
		if shrine_id not in state.waypoints:
			continue
		var row := HBoxContainer.new()
		var shrine_label := UITheme.label("Shrine: %s" % entry["name"], 16)
		shrine_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(shrine_label)
		var travel := UITheme.button("TRAVEL", Vector2(110, 40))
		travel.pressed.connect(func() -> void: _emit_and_refresh("travel", {"waypoint": shrine_id}))
		row.add_child(travel)
		_body.add_child(row)
	_footer.text = "Regions discovered: %d · Shrines lit: %d" % [state.discovered.size(), state.waypoints.size()]


func _draw_map(canvas: Control) -> void:
	var size := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("0b1420"))
	for i in range(1, 6):
		canvas.draw_line(Vector2(size.x * i / 6.0, 0), Vector2(size.x * i / 6.0, size.y), Color("1b2b3d"))
		canvas.draw_line(Vector2(0, size.y * i / 6.0), Vector2(size.x, size.y * i / 6.0), Color("1b2b3d"))
	for region_id in state.discovered:
		var direction: Vector3 = Regions.region_center(region_id)
		if direction == Vector3.ZERO:
			continue
		canvas.draw_circle(_map_point(direction, size), 4.5, Color("83b586"))
	for entry in WorldBuilder.SHRINES:
		var direction: Vector3 = Math3D.direction(entry["lon"], entry["lat"])
		var colour := Color("dcbf76") if entry["id"] in state.waypoints else Color("4a4636")
		canvas.draw_circle(_map_point(direction, size), 6.0, colour)
	for row in WorldBuilder.CAMPS:
		var direction: Vector3 = Math3D.direction(row[1], row[2])
		canvas.draw_rect(Rect2(_map_point(direction, size) - Vector2(3, 3), Vector2(6, 6)), Color(0.8, 0.3, 0.25, 0.75))
	var dungeon: Vector3 = Math3D.direction(WorldBuilder.DUNGEON_LON, WorldBuilder.DUNGEON_LAT)
	canvas.draw_circle(_map_point(dungeon, size), 7.0, Color("b06cff"))
	canvas.draw_circle(_map_point(state.direction, size), 6.0, Color("f7f3e8"))


func _map_point(direction: Vector3, size: Vector2) -> Vector2:
	var ll := Math3D.coordinates(direction)
	return Vector2((ll.x / TAU + 0.5) * size.x, (0.5 - ll.y / PI) * size.y)


func _build_spells() -> void:
	for school_id in SpellDB.SCHOOLS.keys():
		var school: Dictionary = SpellDB.SCHOOLS[school_id]
		_body.add_child(UITheme.label(school["name"], 21, school["color"]))
		for spell_id in SpellDB.ids():
			var spell := SpellDB.create(spell_id)
			if spell.school != school_id:
				continue
			var known := state.knows_spell(spell_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var name_label := UITheme.label(spell.display_name, 18, UITheme.PARCHMENT if known else UITheme.MUTED)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(UITheme.label("%d MP · %.1fs" % [int(spell.mana_cost), spell.cooldown], 15, UITheme.MANA if known else UITheme.MUTED))
			if known:
				var cast := UITheme.button("CAST", Vector2(90, 40))
				cast.pressed.connect(func() -> void: _emit_and_refresh("cast", {"spell": spell_id}))
				row.add_child(cast)
			else:
				row.add_child(UITheme.label("LV %d · Rank %s" % [spell.required_level, spell.required_rank], 15, UITheme.MUTED))
			_body.add_child(row)
			_body.add_child(UITheme.label("   " + spell.description, 14, UITheme.MUTED))
		_body.add_child(HSeparator.new())
	_footer.text = "Known spells: %d / %d · Spell power %d%%" % [state.known_spells.size(), SpellDB.ids().size(), int(state.spell_power() * 100.0)]


func _build_guild() -> void:
	_body.add_child(UITheme.label("Registrar Maeve", 22, UITheme.GOLD))
	_body.add_child(UITheme.label("Guild rank: %s — %s" % [state.rank, RankRules.title(state.rank)], 18, UITheme.ACCENT))
	_body.add_child(UITheme.label(RankRules.describe(state.rank, state.stats, state.discovered.size(), state.quests_completed(), state.level, state.reputation), 16, UITheme.MUTED))
	var requirements := RankRules.requirements_for_next(state.rank, state.stats, state.discovered.size(), state.quests_completed(), state.level, state.reputation)
	for key in requirements.keys():
		var row: Dictionary = requirements[key]
		var text := "✔ %s %d/%d" % [key.capitalize(), row["have"], row["need"]] if row["met"] else "✘ %s %d/%d" % [key.capitalize(), row["have"], row["need"]]
		_body.add_child(UITheme.label(text, 16, UITheme.ACCENT if row["met"] else UITheme.DANGER))
	_body.add_child(HSeparator.new())
	_body.add_child(UITheme.label("Statistics", 19, UITheme.GOLD))
	_body.add_child(UITheme.label("Kills %d · Quests %d · Regions %d · Reputation %d · Deaths %d" % [
		int(state.stats.get("kills", 0)), state.quests_completed(), state.discovered.size(), state.reputation, int(state.stats.get("deaths", 0))], 16, UITheme.PARCHMENT))
	var accept := UITheme.button("ACCEPT CONTRACT", Vector2(240, 48))
	accept.pressed.connect(func() -> void: _emit_and_refresh("guild_accept", {}))
	_body.add_child(accept)
	var turn_in := UITheme.button("TURN IN READY CONTRACTS", Vector2(280, 48))
	turn_in.pressed.connect(func() -> void: _emit_and_refresh("guild_turn_in", {}))
	_body.add_child(turn_in)
	var promote := UITheme.button("REQUEST PROMOTION", Vector2(240, 48))
	promote.disabled = not state.can_promote()
	promote.pressed.connect(func() -> void: _emit_and_refresh("guild_promote", {}))
	_body.add_child(promote)
	_footer.text = "Promotion is granted here, never automatically."


func _build_shop() -> void:
	_body.add_child(UITheme.label("Havenbrook Provisions — sells gear, buys surplus", 18, UITheme.MUTED))
	for item_id in ["healing_potion", "mana_potion", "round_shield", "apprentice_robe", "apprentice_staff", "dagger"]:
		var definition := ItemDB.create(item_id)
		var price: int = int(definition.value * 1.6)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := UITheme.label("%s — %d G" % [definition.display_name, price], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UITheme.label(definition.description, 14, UITheme.MUTED))
		var buy := UITheme.button("BUY", Vector2(90, 40))
		buy.disabled = state.gold < price
		buy.pressed.connect(func() -> void: _emit_and_refresh("buy", {"item": item_id, "price": price}))
		row.add_child(buy)
		_body.add_child(row)
	_body.add_child(HSeparator.new())
	_body.add_child(UITheme.label("Sell your gathered goods from the Inventory panel.", 15, UITheme.MUTED))
	_footer.text = "Your gold: %d" % state.gold


func _build_skills() -> void:
	_body.add_child(UITheme.label("Unspent skill points: %d" % state.unspent_skill_points, 20, UITheme.GOLD))
	var descriptions := {
		"toughness": "+15 maximum health per point.",
		"focus": "+12 maximum mana and +8% spell power per point.",
		"swiftness": "+10 stamina and +0.35 m/s movement per point.",
	}
	for skill_id in state.skills.keys():
		var level: int = int(state.skills[skill_id])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := UITheme.label("%s  %s" % [skill_id.capitalize(), "●".repeat(level) + "○".repeat(maxi(0, 5 - level))], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var upgrade := UITheme.button("+1", Vector2(80, 40))
		upgrade.disabled = state.unspent_skill_points <= 0 or level >= 5
		upgrade.pressed.connect(func() -> void: _emit_and_refresh("skill", {"skill": skill_id}))
		row.add_child(upgrade)
		_body.add_child(row)
		_body.add_child(UITheme.label("   " + descriptions.get(skill_id, ""), 14, UITheme.MUTED))
	_footer.text = "Skills are permanent and saved with your character."


func _build_crafting() -> void:
	_body.add_child(UITheme.label("Forge recipes (rank-gated)", 20, UITheme.GOLD))
	for recipe_id in ItemDB.RECIPES.keys():
		var recipe: Dictionary = ItemDB.RECIPES[recipe_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var inputs: Array[String] = []
		var missing := false
		for input_id in recipe["inputs"].keys():
			var needed: int = recipe["inputs"][input_id]
			var have := state.item_count(input_id)
			inputs.append("%s %d/%d" % [ItemDB.display_name(input_id), have, needed])
			if have < needed:
				missing = true
		var label_text := "%s ← %s + %dG" % [ItemDB.display_name(recipe_id), ", ".join(inputs), recipe["gold"]]
		var name_label := UITheme.label(label_text, 17, UITheme.MUTED if missing else UITheme.PARCHMENT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var craft := UITheme.button("CRAFT", Vector2(96, 40))
		craft.disabled = not state.can_craft(recipe_id)
		craft.pressed.connect(func() -> void: _emit_and_refresh("craft", {"recipe": recipe_id}))
		row.add_child(craft)
		_body.add_child(row)
	_footer.text = "Craft at the forge in Havenbrook. Higher ranks unlock better recipes."


func _build_pause() -> void:
	var resume := UITheme.button("RESUME", Vector2(260, 52))
	resume.pressed.connect(close_panel)
	_body.add_child(resume)
	var save := UITheme.button("SAVE GAME", Vector2(260, 52))
	save.pressed.connect(func() -> void: _emit("save", {}))
	_body.add_child(save)
	var settings_button := UITheme.button("SETTINGS", Vector2(260, 52))
	settings_button.pressed.connect(func() -> void: open("settings"))
	_body.add_child(settings_button)
	var menu := UITheme.button("SAVE & MAIN MENU", Vector2(260, 52))
	menu.pressed.connect(func() -> void: _emit("main_menu", {}))
	_body.add_child(menu)
	var quit := UITheme.button("QUIT GAME", Vector2(260, 52))
	quit.pressed.connect(func() -> void: _emit("quit", {}))
	_body.add_child(quit)
	var meta := SaveGame.peek_metadata()
	if not meta.is_empty():
		_footer.text = "Last save: %s · Level %d · Rank %s (%s)" % [meta.get("saved_at", "?"), int(meta.get("level", 1)), meta.get("rank", "F"), meta.get("hero_name", "Wanderer")]
	else:
		_footer.text = "No save written yet."


func _build_settings() -> void:
	if settings == null:
		_body.add_child(UITheme.label("Settings unavailable.", 18, UITheme.DANGER))
		return
	_body.add_child(UITheme.label("Graphics quality", 19, UITheme.GOLD))
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 10)
	for level in ["Low", "Medium", "High"]:
		var button := UITheme.button(level, Vector2(120, 46))
		button.disabled = settings.quality == level.to_lower()
		button.pressed.connect(func() -> void:
			settings.set_quality(level.to_lower())
			open("settings")
		)
		quality_row.add_child(button)
	_body.add_child(quality_row)

	_body.add_child(UITheme.label("Camera sensitivity: %d%%" % int(settings.sensitivity * 100.0), 18))
	var slider := HSlider.new()
	slider.min_value = 0.4
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = settings.sensitivity
	slider.custom_minimum_size = Vector2(0, 34)
	slider.value_changed.connect(func(value: float) -> void: settings.sensitivity = value)
	_body.add_child(slider)

	var audio_check := CheckBox.new()
	audio_check.text = "Sound effects"
	audio_check.button_pressed = settings.audio_enabled
	audio_check.toggled.connect(func(pressed: bool) -> void: settings.audio_enabled = pressed)
	_body.add_child(audio_check)

	var invert_check := CheckBox.new()
	invert_check.text = "Invert vertical camera drag"
	invert_check.button_pressed = settings.invert_look
	invert_check.toggled.connect(func(pressed: bool) -> void: settings.invert_look = pressed)
	_body.add_child(invert_check)

	var apply := UITheme.button("APPLY & SAVE SETTINGS", Vector2(300, 50))
	apply.pressed.connect(func() -> void:
		settings.save()
		_emit("settings_applied", {})
		open("settings")
	)
	_body.add_child(apply)
	_footer.text = "Settings are stored in user://settings.cfg"


func _build_death() -> void:
	_body.add_child(UITheme.label("Your journey ends here — for now.", 24, UITheme.DANGER))
	_body.add_child(UITheme.label("You will respawn at the Havenbrook shrine with 60% health. Your progress, gold and quests are kept.", 17, UITheme.PARCHMENT))
	var respawn := UITheme.button("RESPAWN", Vector2(260, 54))
	respawn.pressed.connect(func() -> void: _emit("respawn", {}))
	_body.add_child(respawn)
	var menu := UITheme.button("MAIN MENU", Vector2(260, 50))
	menu.pressed.connect(func() -> void: _emit("main_menu", {}))
	_body.add_child(menu)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Opens settings as a standalone scene-level window (used by the main menu).
func open_settings_only(settings_ref: RefCounted) -> void:
	settings = settings_ref
	_title.text = PANEL_TITLES.get("settings", "Settings")
	_clear(_body)
	_build_settings()
	active_panel = "settings"
	visible = true


func _emit(action: String, payload: Dictionary) -> void:
	emit_signal("action_requested", action, payload)


func _emit_and_refresh(action: String, payload: Dictionary) -> void:
	emit_signal("action_requested", action, payload)
	var current := active_panel
	open(current)
