extends RefCounted
## Spherical maths shared by the planet mesh, the player controller and the map.
##
## The world is a real sphere of radius RADIUS metres.  Every gameplay position is
## expressed either as a unit direction from the planet centre or as a 3D point;
## the conversion helpers live here so no system re-implements them.

const RADIUS := 250.0
const SURFACE_TOLERANCE := 0.05

## Direction (unit vector) for a longitude / latitude pair in radians.
static func direction(lon: float, lat: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat)).normalized()

## Longitude / latitude (radians) for a unit direction.
static func coordinates(up: Vector3) -> Vector2:
	var d := up.normalized()
	return Vector2(atan2(d.x, d.z), asin(clampf(d.y, -1.0, 1.0)))

## A stable "north" tangent at a surface point (never parallel to `up`).
static func north(up: Vector3) -> Vector3:
	var n := Vector3.UP - up * up.dot(Vector3.UP)
	if n.length_squared() < 0.000001:
		n = Vector3.FORWARD - up * up.dot(Vector3.FORWARD)
	return n.normalized()

## East tangent at a surface point.
static func east(up: Vector3) -> Vector3:
	return north(up).cross(up).normalized()

## Orthonormal frame on the sphere: x = east, y = up, z = -north.
static func frame_at(up: Vector3) -> Basis:
	var n := north(up)
	var e := n.cross(up).normalized()
	return Basis(e, up, -n).orthonormalized()

## Great-circle position `metres` away along the tangent `input` (x = east, y = north).
static func move(up: Vector3, input: Vector2, metres: float, radius: float = RADIUS) -> Vector3:
	var tangent := east(up) * input.x + north(up) * input.y
	if tangent.length_squared() < 0.0000001:
		return up
	var angle := metres * minf(tangent.length(), 1.0) / radius
	return (up * cos(angle) + tangent.normalized() * sin(angle)).normalized()

## Great-circle distance in metres between two unit directions.
static func arc_distance(a: Vector3, b: Vector3, radius: float = RADIUS) -> float:
	return a.angle_to(b) * radius

## Point on the surface at `height` metres above the base radius.
static func surface_point(up: Vector3, height: float = 0.0) -> Vector3:
	return up.normalized() * (RADIUS + height)

## Project an arbitrary world point back onto the planet sphere (unit direction).
static func direction_of(point: Vector3) -> Vector3:
	return point.normalized()

## Altitude of a world point above the base radius.
static func altitude_of(point: Vector3) -> float:
	return point.length() - RADIUS

## Tangent basis used to orient buildings/props so their local Y matches planet up.
static func prop_basis(up: Vector3, yaw: float = 0.0) -> Basis:
	var basis := frame_at(up)
	return basis.rotated(up, yaw)

## Interpolate a direction along a great circle (used by NPC schedules / projectiles).
static func slerp_direction(a: Vector3, b: Vector3, weight: float) -> Vector3:
	return a.slerp(b, clampf(weight, 0.0, 1.0)).normalized()

## Screen-space safe area helper for Android notches (returns a Rect in pixels).
static func safe_area(control: Control) -> Rect2:
	var window := control.get_viewport_rect()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2(Vector2.ZERO, window.size)
	return Rect2(Vector2(safe.position), Vector2(safe.size))
