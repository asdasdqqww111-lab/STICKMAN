extends RefCounted
const RADIUS := 250.0
const Cells = preload("res://scripts/world_cells.gd")
const CELL := 0.045 # legacy latitude/longitude cell size for save migration

static func direction(lon: float, lat: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))

static func coordinates(up: Vector3) -> Vector2:
	return Vector2(atan2(up.x, up.z), asin(clampf(up.y, -1.0, 1.0)))

static func north(up: Vector3) -> Vector3:
	var n := Vector3.UP - up * up.dot(Vector3.UP)
	if n.length_squared() < 0.00001: n = Vector3.FORWARD - up * up.dot(Vector3.FORWARD)
	return n.normalized()

static func move(up: Vector3, input: Vector2, distance: float) -> Vector3:
	var n := north(up)
	var east := n.cross(up).normalized()
	var tangent := east * input.x + n * input.y
	if tangent.length_squared() < 0.00001: return up
	var angle := distance * minf(tangent.length(), 1.0) / RADIUS
	return (up * cos(angle) + tangent.normalized() * sin(angle)).normalized()

static func cell_id(up: Vector3) -> String:
	return Cells.cell(up)
