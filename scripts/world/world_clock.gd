extends Node
## Day/night cycle driving the sun, sky colours, NPC schedules and monster spawns.

signal hour_changed(hour: int)
signal day_changed(day: int)
signal phase_changed(phase: String)

## Real seconds for a full in-game day.  12 minutes keeps a session from dragging.
const SECONDS_PER_DAY := 720.0

var time_of_day := 0.30         # 0..1 (0 = midnight, 0.25 = sunrise)
var day := 1
var paused := false
var last_hour := -1
var phase := "dawn"

var sun: DirectionalLight3D
var environment: Environment
var _refresh_timer := 0.0


func configure(target_sun: DirectionalLight3D, target_environment: Environment) -> void:
	sun = target_sun
	environment = target_environment
	_apply()


func set_time(value: float) -> void:
	time_of_day = fposmod(value, 1.0)
	_apply()


func advance(seconds: float) -> void:
	if paused:
		return
	var previous := time_of_day
	time_of_day = fposmod(time_of_day + seconds / SECONDS_PER_DAY, 1.0)
	if time_of_day < previous:
		day += 1
		emit_signal("day_changed", day)
	_apply()


func hour() -> int:
	return int(floorf(time_of_day * 24.0))


## "night" / "dawn" / "day" / "dusk" — used by spawn tables and the HUD.
func current_phase() -> String:
	var value := time_of_day
	if value < 0.22 or value >= 0.80:
		return "night"
	if value < 0.30:
		return "dawn"
	if value < 0.72:
		return "day"
	return "dusk"


func is_night() -> bool:
	return current_phase() == "night"


func _apply() -> void:
	var t := time_of_day
	# Sun orbit: rotate around the planet's X axis so noon is overhead at the spawn meridian.
	var elevation := sin((t - 0.25) * TAU) * 75.0
	var azimuth := t * 360.0 - 90.0
	if sun != null:
		sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
		var daylight := clampf(sin((t - 0.25) * TAU) * 1.4 + 0.25, 0.03, 1.15)
		sun.light_energy = daylight
		sun.light_color = _sun_color(t)
		sun.visible = true
	if environment != null:
		var daylight_alpha := clampf(sin((t - 0.25) * TAU) * 1.25 + 0.32, 0.0, 1.0)
		environment.background_color = Color("101827").lerp(Color("9fd3e8"), daylight_alpha)
		environment.ambient_light_color = Color("3a4a68").lerp(Color("bfe0e6"), daylight_alpha)
		environment.ambient_light_energy = lerpf(0.35, 0.85, daylight_alpha)
		environment.fog_light_color = environment.background_color
	var new_hour := hour()
	if new_hour != last_hour:
		last_hour = new_hour
		emit_signal("hour_changed", new_hour)
	var new_phase := current_phase()
	if new_phase != phase:
		phase = new_phase
		emit_signal("phase_changed", phase)


func _sun_color(t: float) -> Color:
	# Warm at sunrise/sunset, neutral at noon, moonlight at night.
	var noon := Color("fff3dc")
	var golden := Color("ffb26a")
	var night := Color("7f96c8")
	var daylight := clampf(sin((t - 0.25) * TAU) * 1.6 + 0.2, 0.0, 1.0)
	var goldenness := clampf(1.0 - absf(daylight - 0.35) * 3.2, 0.0, 1.0)
	var base := night.lerp(noon, daylight)
	return base.lerp(golden, goldenness * 0.65)


func advance_and_report(delta: float) -> void:
	advance(delta)
