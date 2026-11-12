extends Control
## In-game HUD: vitals, XP, rank, quest tracker, target frame, notifications and
## the panel/window buttons.  All values come from PlayerState — nothing is faked.

signal panel_requested(panel_id: String)
signal spell_requested

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")

var state: RefCounted
var quest_log: RefCounted

var health_bar: ProgressBar
var mana_bar: ProgressBar
var stamina_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var gold_label: Label
var rank_label: Label
var quest_label: RichTextLabel
var notice_label: Label
var target_panel: PanelContainer
var target_name: Label
var target_bar: ProgressBar
var clock_label: Label
var region_label: Label
var damage_flash: ColorRect
var interaction_prompt: Label

var notice_timer := 0.0
var _flash_timer := 0.0
var _panel_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build()
	_build()


func _build() -> void:
	# Damage vignette.
	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.7, 0.1, 0.1, 0.0)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)

	# --- top-left vitals ---------------------------------------------------
	var vitals := VBoxContainer.new()
	vitals.position = Vector2(20, 16)
	vitals.custom_minimum_size = Vector2(290, 0)
	vitals.add_theme_constant_override("separation", 4)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vitals)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vitals.add_child(header)
	level_label = UITheme.label("LV 1", 20, UITheme.GOLD)
	header.add_child(level_label)
	rank_label = UITheme.label("RANK F", 18, UITheme.ACCENT)
	header.add_child(rank_label)
	gold_label = UITheme.label("0 G", 18, UITheme.GOLD)
	header.add_child(gold_label)

	health_bar = UITheme.bar(UITheme.HEALTH, 16)
	vitals.add_child(health_bar)
	mana_bar = UITheme.bar(UITheme.MANA, 12)
	vitals.add_child(mana_bar)
	stamina_bar = UITheme.bar(UITheme.STAMINA, 10)
	vitals.add_child(stamina_bar)
	xp_bar = UITheme.bar(Color("c9a227"), 6)
	vitals.add_child(xp_bar)

	# --- top-right clock + region ------------------------------------------
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	info.offset_left = -300
	info.offset_right = -20
	info.offset_top = 16
	info.alignment = BoxContainer.ALIGNMENT_END
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	clock_label = UITheme.label("Day 1 · 07:00", 17, UITheme.PARCHMENT)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(clock_label)
	region_label = UITheme.label("Havenbrook", 15, UITheme.MUTED)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(region_label)

	# --- quest tracker (top centre) ----------------------------------------
	quest_label = RichTextLabel.new()
	quest_label.bbcode_enabled = true
	quest_label.fit_content = true
	quest_label.scroll_active = false
	quest_label.custom_minimum_size = Vector2(430, 0)
	quest_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	quest_label.offset_left = -215
	quest_label.offset_right = 215
	quest_label.offset_top = 14
	quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quest_label)

	# --- target frame ------------------------------------------------------
	target_panel = PanelContainer.new()
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target_panel.offset_left = -150
	target_panel.offset_right = 150
	target_panel.offset_top = 96
	target_panel.visible = false
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target_panel)
	var target_box := VBoxContainer.new()
	target_panel.add_child(target_box)
	target_name = UITheme.label("Monster", 17, UITheme.DANGER)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_box.add_child(target_name)
	target_bar = UITheme.bar(UITheme.DANGER, 10)
	target_box.add_child(target_bar)

	# --- interaction prompt + notice ---------------------------------------
	interaction_prompt = UITheme.label("", 18, UITheme.GOLD)
	interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	interaction_prompt.offset_left = -200
	interaction_prompt.offset_right = 200
	interaction_prompt.offset_top = 120
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(interaction_prompt)

	notice_label = UITheme.label("", 19, UITheme.PARCHMENT)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice_label.offset_left = -320
	notice_label.offset_right = 320
	notice_label.offset_top = -232
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice_label)

	# --- bottom-centre panel buttons ---------------------------------------
	var buttons := HBoxContainer.new()
	buttons.name = "PanelButtons"
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_left = 20
	buttons.offset_right = -400
	buttons.offset_top = -66
	buttons.offset_bottom = -12
	buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
	for entry in [["INV", "inventory"], ["EQUIP", "equipment"], ["QUESTS", "quests"], ["MAP", "map"], ["SPELLS", "spells"], ["GUILD", "guild"], ["SHOP", "shop"], ["SKILLS", "skills"]]:
		var button := UITheme.button(entry[0], Vector2(74, 46))
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func() -> void: emit_signal("panel_requested", entry[1]))
		buttons.add_child(button)
		_panel_buttons.append(button)


func bind(player_state: RefCounted, log: RefCounted) -> void:
	state = player_state
	quest_log = log
	refresh()


func set_action_buttons_visible(visible_state: bool) -> void:
	for button in _panel_buttons:
		button.visible = visible_state


func show_notice(text: String, seconds: float = 3.5) -> void:
	if notice_label == null:
		return
	notice_label.text = text
	notice_timer = seconds


func flash_damage() -> void:
	_flash_timer = 0.32


func refresh() -> void:
	if state == null:
		return
	health_bar.max_value = state.max_health()
	health_bar.value = state.health
	mana_bar.max_value = state.max_mana()
	mana_bar.value = state.mana
	stamina_bar.max_value = state.max_stamina()
	stamina_bar.value = state.stamina
	xp_bar.max_value = state.xp_needed()
	xp_bar.value = state.xp
	level_label.text = "LV %d" % state.level
	rank_label.text = "RANK %s" % state.rank
	gold_label.text = "%d G" % state.gold
	_refresh_quests()


func _refresh_quests() -> void:
	if quest_log == null:
		return
	var lines: Array[String] = []
	var ready := quest_log.ready_summaries()
	var active := quest_log.active_summaries()
	if not ready.is_empty():
		lines.append("[color=#e8c27a]◆ Ready to turn in[/color]")
		for title in ready:
			lines.append("  [color=#f2e6cd]%s[/color]" % title)
	if not active.is_empty():
		lines.append("[color=#7fd1c1]▸ Active contracts[/color]")
		for line in active:
			lines.append("  [color=#cfe0ea]%s[/color]" % line)
	if lines.is_empty():
		var available: Array[String] = state.available_quest_ids()
		if not available.is_empty():
			lines.append("[color=#8ea3b8]New contract at the guild hall[/color]")
	quest_label.text = "\n".join(lines)


func set_clock(text: String) -> void:
	clock_label.text = text


func set_region(text: String) -> void:
	region_label.text = text


func show_target(name_text: String, ratio: float, is_boss: bool) -> void:
	target_panel.visible = true
	target_name.text = ("☠ " if is_boss else "") + name_text
	target_name.add_theme_color_override("font_color", Color("ff9b6a") if is_boss else UITheme.DANGER)
	target_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


func hide_target() -> void:
	if target_panel != null:
		target_panel.visible = false


func set_interaction_prompt(text: String) -> void:
	if interaction_prompt != null:
		interaction_prompt.text = text


func _process(delta: float) -> void:
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0 and notice_label != null:
			notice_label.text = ""
	if _flash_timer > 0.0:
		_flash_timer -= delta
		damage_flash.color = Color(0.7, 0.1, 0.1, clampf(_flash_timer, 0.0, 0.32) * 0.9)
	else:
		damage_flash.color = Color(0.7, 0.1, 0.1, 0.0)
