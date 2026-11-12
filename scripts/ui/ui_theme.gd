extends RefCounted
## Shared Stylized-Fantasy UI theme, built in code so it scales from a 5" phone
## to a tablet without shipping font/image assets.

const GOLD := Color("e8c27a")
const PARCHMENT := Color("f2e6cd")
const INK := Color("1d1a17")
const PANEL := Color("14243a")
const PANEL_LIGHT := Color("1d3350")
const ACCENT := Color("7fd1c1")
const DANGER := Color("e46b5a")
const MANA := Color("6aa8ff")
const STAMINA := Color("8ecf74")
const HEALTH := Color("e05d5d")
const MUTED := Color("8ea3b8")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.94)
	panel.border_color = GOLD
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	theme.set_stylebox("panel", "PanelContainer", panel)

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = PANEL_LIGHT
	button_normal.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	button_normal.set_border_width_all(1)
	button_normal.set_corner_radius_all(8)
	button_normal.content_margin_left = 14
	button_normal.content_margin_right = 14
	button_normal.content_margin_top = 8
	button_normal.content_margin_bottom = 8

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color("2b4a6b")
	button_hover.border_color = GOLD

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color("0e1a2a")
	button_pressed.border_color = ACCENT

	var button_disabled := button_normal.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Color(0.10, 0.12, 0.16, 0.75)
	button_disabled.border_color = Color(0.5, 0.5, 0.5, 0.35)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", button_hover)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_font_size("font_size", "Button", 18)

	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.65))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	# Progress bars (health / mana / stamina / xp).
	for bar_name in ["HealthBar", "ManaBar", "StaminaBar", "XpBar"]:
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.05, 0.07, 0.10, 0.85)
		background.set_corner_radius_all(6)
		background.border_color = Color(0, 0, 0, 0.5)
		background.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = HEALTH
		fill.set_corner_radius_all(6)
		theme.set_stylebox("background", bar_name, background)
		theme.set_stylebox("fill", bar_name, fill)

	theme.set_color("font_color", "RichTextLabel", PARCHMENT)
	theme.set_font_size("normal_font_size", "RichTextLabel", 17)
	theme.set_stylebox("panel", "TooltipPanel", panel)
	return theme


## Convenience: a styled label.
static func label(text: String, size: int = 18, colour: Color = PARCHMENT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	return node


static func title(text: String, size: int = 34) -> Label:
	var node := label(text, size, GOLD)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


static func button(text: String, minimum: Vector2 = Vector2(180, 52)) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = minimum
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_size_override("font_size", 18)
	return node


## A thin progress bar used in the HUD.
static func bar(colour: Color, height: float = 14.0) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size = Vector2(0, height)
	node.show_percentage = false
	node.max_value = 100.0
	node.value = 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	background.set_corner_radius_all(int(height * 0.5))
	background.border_color = Color(0, 0, 0, 0.55)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(int(height * 0.5))
	node.add_theme_stylebox_override("background", background)
	node.add_theme_stylebox_override("fill", fill)
	return node
