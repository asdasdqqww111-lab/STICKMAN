extends Control
## Main menu.  "Continue" only enables when a valid save actually exists, and
## shows the hero's level/rank read from that save.

signal new_game_requested
signal continue_requested
signal settings_requested
signal quit_requested

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")

var continue_button: Button
var save_info: Label
var hero_name_field: LineEdit
var _metadata := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_build()
	refresh()
	# Fade in so the 3D planet behind the menu reads as a title screen.
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.06, 0.10, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var centre := VBoxContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centre.custom_minimum_size = Vector2(460, 0)
	centre.offset_left = -230
	centre.offset_right = 230
	centre.offset_top = -230
	centre.offset_bottom = 230
	centre.add_theme_constant_override("separation", 12)
	add_child(centre)

	centre.add_child(UITheme.title("MICRO WORLD", 52))
	centre.add_child(UITheme.title("L I V I N G", 26))
	var tagline := UITheme.label("A living planet. One wanderer. Every region remembers.", 16, UITheme.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(tagline)
	centre.add_child(HSeparator.new())

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(UITheme.label("Name:", 18, UITheme.MUTED))
	hero_name_field = LineEdit.new()
	hero_name_field.placeholder_text = "Wanderer"
	hero_name_field.text = "Wanderer"
	hero_name_field.max_length = 16
	hero_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(hero_name_field)
	centre.add_child(name_row)

	continue_button = UITheme.button("CONTINUE", Vector2(0, 54))
	continue_button.pressed.connect(func() -> void:
		emit_signal("continue_requested")
	)
	centre.add_child(continue_button)

	save_info = UITheme.label("", 15, UITheme.MUTED)
	save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(save_info)

	var new_button := UITheme.button("NEW GAME", Vector2(0, 54))
	new_button.pressed.connect(_on_new_game)
	centre.add_child(new_button)

	var settings_button := UITheme.button("SETTINGS", Vector2(0, 50))
	settings_button.pressed.connect(func() -> void:
		emit_signal("settings_requested")
	)
	centre.add_child(settings_button)

	var quit_button := UITheme.button("QUIT", Vector2(0, 50))
	quit_button.pressed.connect(func() -> void:
		emit_signal("quit_requested")
	)
	centre.add_child(quit_button)

	var footer := UITheme.label("v%s  ·  Godot 4  ·  CC0 assets by Kay Lousberg & Kenney" % ProjectSettings.get_setting("application/config/version", "0.0.0"), 13, UITheme.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -34
	footer.offset_bottom = -10
	add_child(footer)


func refresh() -> void:
	_metadata = SaveGame.peek_metadata()
	var has_save := not _metadata.is_empty()
	if continue_button != null:
		continue_button.disabled = not has_save
	if save_info != null:
		if has_save:
			save_info.text = "%s · Level %d · Rank %s · %d gold" % [
				_metadata.get("hero_name", "Wanderer"),
				int(_metadata.get("level", 1)),
				_metadata.get("rank", "F"),
				int(_metadata.get("gold", 0)),
			]
		else:
			save_info.text = "No save found — start a new journey."


func hero_name() -> String:
	var value: String = hero_name_field.text.strip_edges() if hero_name_field != null else "Wanderer"
	return value if value != "" else "Wanderer"


func _on_new_game() -> void:
	# A new game overwrites the save only after the player is told it will.
	if not _metadata.is_empty():
		_confirm_overwrite()
	else:
		emit_signal("new_game_requested")


func _confirm_overwrite() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Overwrite save?"
	dialog.dialog_text = "Starting a new game replaces your existing save (a backup is kept)."
	dialog.ok_button_text = "Start New Game"
	dialog.cancel_button_text = "Keep Save"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		emit_signal("new_game_requested")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
