extends RefCounted
## Persisted user settings (quality, sensitivity, audio) in user://settings.cfg.

const PATH := "user://settings.cfg"

const QUALITY_PRESETS := {
	"low": {
		"planet_resolution": 10,
		"scatter": 26,
		"shadows": false,
		"msaa": 0,
		"render_scale": 0.75,
		"view_distance": 120.0,
		"max_active_monsters": 12,
		"stream_radius": 1,
	},
	"medium": {
		"planet_resolution": 14,
		"scatter": 52,
		"shadows": true,
		"msaa": 1,
		"render_scale": 0.9,
		"view_distance": 220.0,
		"max_active_monsters": 20,
		"stream_radius": 2,
	},
	"high": {
		"planet_resolution": 18,
		"scatter": 90,
		"shadows": true,
		"msaa": 2,
		"render_scale": 1.0,
		"view_distance": 400.0,
		"max_active_monsters": 32,
		"stream_radius": 2,
	},
}

var quality := "medium"
var sensitivity := 1.0
var invert_look := false
var audio_enabled := true
var fullscreen := true
var language := "en"
var show_fps := false


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	quality = String(config.get_value("graphics", "quality", quality))
	if not QUALITY_PRESETS.has(quality):
		quality = "medium"
	sensitivity = clampf(float(config.get_value("controls", "sensitivity", sensitivity)), 0.4, 2.0)
	invert_look = bool(config.get_value("controls", "invert_look", invert_look))
	audio_enabled = bool(config.get_value("audio", "enabled", audio_enabled))
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	language = String(config.get_value("display", "language", language))
	show_fps = bool(config.get_value("display", "show_fps", show_fps))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("controls", "invert_look", invert_look)
	config.set_value("audio", "enabled", audio_enabled)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "language", language)
	config.set_value("display", "show_fps", show_fps)
	config.save(PATH)


func preset() -> Dictionary:
	return QUALITY_PRESETS.get(quality, QUALITY_PRESETS["medium"])


func set_quality(value: String) -> void:
	if QUALITY_PRESETS.has(value):
		quality = value
		apply_to_viewport()


## Applies graphics quality to the live viewport (mobile-friendly knobs only).
func apply_to_viewport() -> void:
	var viewport := Engine.get_main_loop() as SceneTree
	if viewport == null or viewport.root == null:
		return
	var settings := preset()
	viewport.root.msaa_3d = int(settings.get("msaa", 1))
	viewport.root.scaling_3d_scale = float(settings.get("render_scale", 1.0))


func audio_on() -> bool:
	return audio_enabled
