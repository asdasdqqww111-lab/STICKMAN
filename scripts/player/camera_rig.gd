extends Node3D
## Third-person camera that stays *outside* the planet sphere and always looks
## along the surface, plus a planet-overview mode for the map screen.

const Math3D = preload("res://scripts/planet/sphere_math.gd")

const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 15.0
const MIN_PITCH := -0.55
const MAX_PITCH := 1.05

var target: Node3D
var camera: Camera3D
var distance := 8.4
var pitch := 0.22
var orbit_yaw := 0.0
var overview := false
var smoothing := 12.0
var _current_position := Vector3.ZERO
var _initialised := false
var _shake := 0.0


func setup(follow_target: Node3D) -> void:
	target = follow_target
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.1
	camera.far = 2000.0
	camera.current = true
	add_child(camera)
	_current_position = Vector3.ZERO


func orbit(delta_pitch: float) -> void:
	pitch = clampf(pitch + delta_pitch, MIN_PITCH, MAX_PITCH)


func zoom(amount: float) -> void:
	distance = clampf(distance + amount, MIN_DISTANCE, MAX_DISTANCE)


func set_overview(enabled: bool) -> void:
	overview = enabled


func shake(amount: float = 0.25) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null or camera == null:
		return
	_shake = maxf(0.0, _shake - delta * 2.0)
	if overview:
		_update_overview(delta)
	else:
		_update_follow(delta)


func _update_follow(delta: float) -> void:
	var up: Vector3 = target.current_direction if "current_direction" in target else target.global_position.normalized()
	var north := Math3D.north(up)
	var east := Math3D.east(up)
	# Orbit yaw is applied around the planet-up so the camera can circle the player.
	var forward := (north * cos(orbit_yaw) + east * sin(orbit_yaw)).normalized()
	var desired := target.global_position - forward * (distance * cos(pitch)) + up * (distance * sin(pitch) + 1.4)
	# Keep the camera outside the planet so it never clips into terrain.
	var minimum_radius := Math3D.RADIUS + 2.2
	if desired.length() < minimum_radius:
		desired = desired.normalized() * minimum_radius
	if not _initialised:
		_current_position = desired
		_initialised = true
	_current_position = _current_position.lerp(desired, clampf(delta * smoothing, 0.0, 1.0))
	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		shake_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	camera.global_position = _current_position + shake_offset
	camera.look_at(target.global_position + up * 1.2, up)


func _update_overview(delta: float) -> void:
	var up: Vector3 = target.current_direction if "current_direction" in target else target.global_position.normalized()
	var desired := up * (Math3D.RADIUS * 3.1)
	var north := Math3D.north(up)
	desired -= north * Math3D.RADIUS * 0.8
	_current_position = _current_position.lerp(desired, clampf(delta * 4.0, 0.0, 1.0))
	camera.global_position = _current_position
	camera.look_at(Vector3.ZERO, north)


## Camera-relative "forward" projected into the tangent plane at `up`.
func tangent_forward(up: Vector3) -> Vector3:
	var forward := -camera.global_transform.basis.z
	var tangent := forward - up * forward.dot(up)
	if tangent.length_squared() < 0.0001:
		return Math3D.north(up)
	return tangent.normalized()


func add_orbit(delta_yaw: float) -> void:
	orbit_yaw = wrapf(orbit_yaw + delta_yaw, -PI, PI)
