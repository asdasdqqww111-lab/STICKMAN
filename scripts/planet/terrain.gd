extends RefCounted
## Deterministic, allocation-free terrain for the planet.
##
## Everything is a pure function of a unit direction, so the mesh generator, the
## gameplay height queries and the automated tests all agree without a heightmap
## texture or a physics bake.  Elevation is measured in metres above SphereMath.RADIUS.

const Math3D = preload("res://scripts/planet/sphere_math.gd")

const WATER_LEVEL := 0.35
const MAX_ELEVATION := 26.0
const SEA_FLOOR := -9.0

## Spawn plateau: guarantees the starting region is walkable land.
const SPAWN_UP := Vector3(0.0, 0.0, 1.0)
const SPAWN_RADIUS_METRES := 78.0
const SPAWN_HEIGHT := 6.0

enum Biome { OCEAN, BEACH, MEADOW, FOREST, ROCK, SNOW, RUINS }

const BIOME_COLORS := {
	Biome.OCEAN: Color("2f5f7a"),
	Biome.BEACH: Color("d8c99a"),
	Biome.MEADOW: Color("6f9e50"),
	Biome.FOREST: Color("3f6b3a"),
	Biome.ROCK: Color("7a7268"),
	Biome.SNOW: Color("dfe7ea"),
	Biome.RUINS: Color("6d6357"),
}

## --- value noise -----------------------------------------------------------

static func _hash3(x: int, y: int, z: int, seed_value: int) -> float:
	var h := x * 374761393 + y * 668265263 + z * 2147483647 + seed_value * 971
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7FFFFFFF) / float(0x7FFFFFFF)

static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

static func _lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t

## Trilinear value noise in [-1, 1].
static func _value_noise(p: Vector3, seed_value: int) -> float:
	var xi := floori(p.x)
	var yi := floori(p.y)
	var zi := floori(p.z)
	var fx := _smooth(p.x - xi)
	var fy := _smooth(p.y - yi)
	var fz := _smooth(p.z - zi)
	var c000 := _hash3(xi, yi, zi, seed_value)
	var c100 := _hash3(xi + 1, yi, zi, seed_value)
	var c010 := _hash3(xi, yi + 1, zi, seed_value)
	var c110 := _hash3(xi + 1, yi + 1, zi, seed_value)
	var c001 := _hash3(xi, yi, zi + 1, seed_value)
	var c101 := _hash3(xi + 1, yi, zi + 1, seed_value)
	var c011 := _hash3(xi, yi + 1, zi + 1, seed_value)
	var c111 := _hash3(xi + 1, yi + 1, zi + 1, seed_value)
	var x00 := _lerp(c000, c100, fx)
	var x10 := _lerp(c010, c110, fx)
	var x01 := _lerp(c001, c101, fx)
	var x11 := _lerp(c011, c111, fx)
	return _lerp(_lerp(x00, x10, fy), _lerp(x01, x11, fy), fz) * 2.0 - 1.0

static func _fbm(p: Vector3, octaves: int, seed_value: int) -> float:
	var total := 0.0
	var amplitude := 1.0
	var normaliser := 0.0
	var frequency := 1.0
	for i in range(octaves):
		total += _value_noise(p * frequency, seed_value + i * 131) * amplitude
		normaliser += amplitude
		amplitude *= 0.5
		frequency *= 2.0
	return total / normaliser

## --- elevation -------------------------------------------------------------

static func elevation(up: Vector3) -> float:
	var d := up.normalized()
	var continental := _fbm(d * 2.1, 3, 17)
	var detail := _fbm(d * 7.5, 3, 91)
	# Mask keeps oceans between continents while the spawn plateau stays dry.
	var land_mask := smoothstep(-0.12, 0.35, continental)
	var land := SEA_FLOOR + (MAX_ELEVATION - SEA_FLOOR) * land_mask
	land += detail * 5.5 * land_mask
	# Spawn plateau: a soft gaussian bump so the tutorial region is always playable.
	var spawn_distance := Math3D.arc_distance(d, SPAWN_UP)
	var plateau := exp(-pow(spawn_distance / SPAWN_RADIUS_METRES, 2.0) * 2.2)
	land = _lerp(land, SPAWN_HEIGHT, plateau * 0.92)
	# Flatten anything under water so the ocean floor stays readable.
	return clampf(land, SEA_FLOOR, MAX_ELEVATION + 6.0)

static func moisture(up: Vector3) -> float:
	return clampf(_fbm(up.normalized() * 3.4, 2, 401) * 0.5 + 0.5, 0.0, 1.0)

static func is_water(up: Vector3) -> bool:
	return elevation(up) <= WATER_LEVEL

## Surface point (world space) for a direction, following terrain.
static func ground_point(up: Vector3) -> Vector3:
	return up.normalized() * (Math3D.RADIUS + elevation(up))

## Average normal of the terrain at a direction (finite differences on the sphere).
static func ground_normal(up: Vector3) -> Vector3:
	var n := up.normalized()
	var step := 0.6
	var tangent_e := Math3D.east(n) * step
	var tangent_n := Math3D.north(n) * step
	var p0 := ground_point(n)
	var pe := ground_point((n + tangent_e / Math3D.RADIUS).normalized())
	var pn := ground_point((n + tangent_n / Math3D.RADIUS).normalized())
	var normal := (pe - p0).cross(pn - p0).normalized()
	if normal.dot(n) < 0.0:
		normal = -normal
	return normal

## --- biomes ----------------------------------------------------------------

static func biome_at(up: Vector3) -> int:
	var d := up.normalized()
	var height := elevation(d)
	if height <= WATER_LEVEL:
		return Biome.OCEAN
	if height <= WATER_LEVEL + 0.9:
		return Biome.BEACH
	if absf(d.y) > 0.86:
		return Biome.SNOW
	if height > 17.0:
		return Biome.ROCK
	var wet := moisture(d)
	if height > 12.0 and wet < 0.45:
		return Biome.ROCK
	if wet > 0.55:
		return Biome.FOREST
	return Biome.MEADOW

static func biome_color(biome: int) -> Color:
	return BIOME_COLORS.get(biome, Color.MAGENTA)

static func biome_name(biome: int) -> String:
	return ["Ocean", "Beach", "Meadow", "Forest", "Rock", "Snow", "Ruins"][biome]

## Names used by quests / region discovery UI.
static func region_name(up: Vector3) -> String:
	var d := up.normalized()
	if Math3D.arc_distance(d, SPAWN_UP) < 60.0:
		return "Havenbrook Village"
	if Math3D.arc_distance(d, d) < 0.0:
		return "Unknown"
	return biome_name(biome_at(d))
