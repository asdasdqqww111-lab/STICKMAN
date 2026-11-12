extends RefCounted
const Sphere = preload("res://scripts/sphere.gd")
const POINTS := {
	"outpost": {"name": "Guild Outpost", "lon": 0.0, "lat": 0.006},
	"east": {"name": "East Meadow Shrine", "lon": 0.10, "lat": 0.035},
	"north": {"name": "North Grove Shrine", "lon": -0.025, "lat": 0.125},
}
static func position(id: String) -> Vector3:
	if not POINTS.has(id): return Vector3.ZERO
	return Sphere.direction(POINTS[id].lon, POINTS[id].lat)
