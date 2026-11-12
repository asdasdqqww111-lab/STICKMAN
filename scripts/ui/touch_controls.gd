extends Control
## On-screen controls for Android: virtual stick (left thumb), action buttons
## (right thumb) and drag-to-look anywhere else on the screen.

signal move_changed(vector: Vector2)
signal look_delta(delta: Vector2)
signal jump_pressed
signal attack_pressed(heavy: bool)
signal dodge_pressed
signal interact_pressed
signal spell_pressed
signal pause_pressed

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const STICK_RADIUS := 86.0
const KNOB_RADIUS := 34.0
const LOOK_SENSITIVITY := 0.0055

var stick_origin := Vector2.ZERO
var stick_value := Vector2.ZERO
var stick_active := false
var stick_touch_index := -1
var look_touch_index := -1
var look_last_position := Vector2.ZERO
var buttons_enabled := true

var _stick_base: Panel
var _stick_knob: Panel
var _stick_canvas: Control
var _jump_button: Button
var _spell_button: Button
var _cooldowns := {"spell": 0.0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build()
	_build_stick()
	_build_buttons()
	_resize()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize()


func _build_stick() -> void:
	_stick_canvas = Control.new()
	_stick_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stick_canvas)

	_stick_base = Panel.new()
	_stick_base.custom_minimum_size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	_stick_base.size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.modulate = Color(1, 1, 1, 0.35)
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.13, 0.20, 0.55)
	base_style.border_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.5)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(int(STICK_RADIUS))
	_stick_base.add_theme_stylebox_override("panel", base_style)
	_stick_canvas.add_child(_stick_base)

	_stick_knob = Panel.new()
	_stick_knob.custom_minimum_size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_stick_knob.size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.75)
	knob_style.set_corner_radius_all(int(KNOB_RADIUS))
	_stick_knob.add_theme_stylebox_override("panel", knob_style)
	_stick_canvas.add_child(_stick_knob)


func _build_buttons() -> void:
	var right := VBoxContainer.new()
	right.name = "ActionColumn"
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)

	var row_one := HBoxContainer.new()
	row_one.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_one.alignment = BoxContainer.ALIGNMENT_END
	row_one.add_theme_constant_override("separation", 10)
	right.add_child(row_one)

	_spell_button = _action_button("SPELL", UITheme.MANA)
	_spell_button.pressed.connect(func() -> void: emit_signal("spell_pressed"))
	row_one.add_child(_spell_button)

	var attack := _action_button("ATTACK", UITheme.DANGER, 96.0)
	attack.button_down.connect(func() -> void: emit_signal("attack_pressed", false))
	row_one.add_child(attack)

	var row_two := HBoxContainer.new()
	row_two.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_two.alignment = BoxContainer.ALIGNMENT_END
	row_two.add_theme_constant_override("separation", 10)
	right.add_child(row_two)

	var dodge := _action_button("DODGE", UITheme.STAMINA)
	dodge.pressed.connect(func() -> void: emit_signal("dodge_pressed"))
	row_two.add_child(dodge)

	_jump_button = _action_button("JUMP", UITheme.ACCENT)
	_jump_button.pressed.connect(func() -> void: emit_signal("jump_pressed"))
	row_two.add_child(_jump_button)

	var interact := _action_button("INTERACT", UITheme.GOLD, 104.0)
	interact.pressed.connect(func() -> void: emit_signal("interact_pressed"))
	row_two.add_child(interact)

	var row_three := HBoxContainer.new()
	row_three.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_three.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(row_three)
	var pause := _action_button("MENU", UITheme.MUTED, 88.0)
	pause.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	row_three.add_child(pause)


func _action_button(text: String, colour: Color, size_px: float = 82.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(size_px, size_px)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(colour.r * 0.32, colour.g * 0.32, colour.b * 0.32, 0.82)
	normal.border_color = Color(colour.r, colour.g, colour.b, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(int(size_px * 0.5))
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(colour.r, colour.g, colour.b, 0.85)
	pressed.set_corner_radius_all(int(size_px * 0.5))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color.WHITE)
	return button


func _resize() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 0:
		return
	# Safe-area aware margins so notches / gesture bars never cover a thumb zone.
	var safe := DisplayServer.get_display_safe_area()
	var left_offset := maxf(28.0, float(safe.position.x) + 28.0)
	var bottom_offset := 24.0
	var stick_centre := Vector2(left_offset + STICK_RADIUS, viewport.y - bottom_offset - STICK_RADIUS)
	if safe.size.y > 0:
		stick_centre.y = minf(stick_centre.y, float(safe.position.y + safe.size.y) - bottom_offset - STICK_RADIUS)
	stick_origin = stick_centre
	if _stick_base != null:
		_stick_base.position = stick_centre - Vector2(STICK_RADIUS, STICK_RADIUS)
	if _stick_knob != null:
		_stick_knob.position = stick_centre - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	var column := get_node_or_null("ActionColumn") as Control
	if column != null:
		column.offset_left = viewport.x - 380.0
		column.offset_right = -20.0
		column.offset_top = viewport.y - 300.0
		column.offset_bottom = -bottom_offset
		column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		var touch_kind := InputEventScreenTouch.new()
		touch_kind.index = 0
		touch_kind.pressed = event.pressed
		touch_kind.position = event.position
		_handle_touch(touch_kind)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = event.position
		drag.relative = event.relative
		_handle_drag(drag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if not buttons_enabled:
		return
	var distance := event.position.distance_to(stick_origin)
	var in_stick_zone := distance < STICK_RADIUS * 1.7 and event.position.x < get_viewport_rect().size.x * 0.45
	if event.pressed:
		if in_stick_zone and stick_touch_index == -1:
			stick_touch_index = event.index
			stick_active = true
			_apply_stick(event.position)
		elif look_touch_index == -1:
			look_touch_index = event.index
			look_last_position = event.position
	else:
		if event.index == stick_touch_index:
			stick_touch_index = -1
			stick_active = false
			stick_value = Vector2.ZERO
			if _stick_knob != null:
				_stick_knob.position = stick_origin - Vector2(KNOB_RADIUS, KNOB_RADIUS)
			emit_signal("move_changed", stick_value)
		elif event.index == look_touch_index:
			look_touch_index = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == stick_touch_index:
		_apply_stick(event.position)
	elif event.index == look_touch_index:
		var delta := event.relative
		emit_signal("look_delta", delta * LOOK_SENSITIVITY)


func _apply_stick(position: Vector2) -> void:
	var offset := position - stick_origin
	if offset.length() > STICK_RADIUS:
		offset = offset.normalized() * STICK_RADIUS
	# Screen Y grows downwards; movement input uses +Y = forward.
	stick_value = Vector2(offset.x / STICK_RADIUS, -offset.y / STICK_RADIUS)
	if _stick_knob != null:
		_stick_knob.position = stick_origin + offset - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	emit_signal("move_changed", stick_value)


func set_actions_enabled(enabled: bool) -> void:
	buttons_enabled = enabled
	visible = enabled


## Keyboard fallback for desktop testing (WASD/arrows + J/K/L/E/F/Q).
func _process(delta: float) -> void:
	if not buttons_enabled:
		return
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y -= 1.0
	# Mouse look while right-dragging (desktop).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := Input.get_last_mouse_velocity()
		if motion.length() > 5.0:
			emit_signal("look_delta", motion * delta * 0.0006)
	emit_signal("move_changed", keyboard.limit_length(1.0) if keyboard.length_squared() > 0.0 else stick_value.limit_length(1.0))


func set_spell_cooldown(ratio: float, ready: bool) -> void:
	if _spell_button == null:
		return
	_spell_button.modulate = Color(1, 1, 1, 1.0) if ready else Color(0.65, 0.65, 0.7, 0.9)
	_spell_button.text = "SPELL" if ready else "SPELL\n%d%%" % int(clampf(ratio, 0.0, 1.0) * 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				emit_signal("jump_pressed")
			KEY_J:
				emit_signal("attack_pressed", false)
			KEY_K:
				emit_signal("attack_pressed", true)
			KEY_L:
				emit_signal("dodge_pressed")
			KEY_E:
				emit_signal("interact_pressed")
			KEY_Q:
				emit_signal("spell_pressed")
			KEY_ESCAPE:
				emit_signal("pause_pressed")
