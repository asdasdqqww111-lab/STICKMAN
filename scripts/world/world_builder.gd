extends RefCounted
## Places the entire launch slice on the planet: village, guild hall, forge,
## shop, shrines, herb/ore nodes, monster camps, the barrow dungeon and the boss
## hall.  Every placement is a pure function of the sphere direction so it lands
## on the correct terrain height and stays consistent across saves.

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const Regions = preload("res://scripts/planet/planet_regions.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const Interactable = preload("res://scripts/world/interactable.gd")
const ResourceNode = preload("res://scripts/world/resource_node.gd")

## Village anchor: slightly north-east of the spawn plateau centre.
const VILLAGE_LON := 0.012
const VILLAGE_LAT := 0.010
const DUNGEON_LON := -0.028
const DUNGEON_LAT := 0.085


## Shrine positions: id -> [lon, lat, display name, region label].
const SHRINES := [
	{"id": "havenbrook_gate", "lon": 0.000, "lat": 0.004, "name": "Havenbrook Gate", "colour": "ffd166"},
	{"id": "east_meadow", "lon": 0.030, "lat": 0.006, "name": "East Meadow Shrine", "colour": "9ae6b4"},
	{"id": "north_grove", "lon": -0.010, "lat": 0.030, "name": "North Grove Shrine", "colour": "8ecae6"},
	{"id": "barrow_mouth", "lon": DUNGEON_LON, "lat": DUNGEON_LAT - 0.006, "name": "Barrow Mouth Shrine", "colour": "f6ad55"},
	{"id": "west_ridge", "lon": -0.040, "lat": 0.014, "name": "West Ridge Shrine", "colour": "c4b5fd"},
]

## Herb / ore spawns around the village.
const RESOURCES = [
	{"id": "herb_0", "item": "purple_herb", "lon": 0.006, "lat": 0.000, "colour": "be73e3"},
	{"id": "herb_1", "item": "purple_herb", "lon": -0.006, "lat": 0.004, "colour": "be73e3"},
	{"id": "herb_2", "item": "purple_herb", "lon": 0.014, "lat": 0.008, "colour": "be73e3"},
	{"id": "herb_3", "item": "purple_herb", "lon": -0.014, "lat": 0.012, "colour": "be73e3"},
	{"id": "herb_4", "item": "purple_herb", "lon": 0.020, "lat": -0.004, "colour": "be73e3"},
	{"id": "herb_5", "item": "purple_herb", "lon": -0.020, "lat": 0.020, "colour": "be73e3"},
	{"id": "herb_6", "item": "purple_herb", "lon": 0.008, "lat": 0.022, "colour": "be73e3"},
	{"id": "herb_7", "item": "purple_herb", "lon": -0.002, "lat": 0.026, "colour": "be73e3"},
	{"id": "herb_8", "item": "purple_herb", "lon": 0.026, "lat": 0.014, "colour": "be73e3"},
	{"id": "ore_0", "item": "iron_ore", "lon": -0.024, "lat": 0.006, "colour": "9aa5b1"},
	{"id": "ore_1", "item": "iron_ore", "lon": -0.030, "lat": 0.020, "colour": "9aa5b1"},
	{"id": "ore_2", "item": "iron_ore", "lon": 0.034, "lat": 0.020, "colour": "9aa5b1"},
	{"id": "ore_3", "item": "iron_ore", "lon": -0.036, "lat": -0.002, "colour": "9aa5b1"},
	{"id": "ore_4", "item": "iron_ore", "lon": 0.030, "lat": 0.030, "colour": "9aa5b1"},
]

## Monster camps: [archetype, lon, lat, count].
const CAMPS = [
	["meadow_slime", 0.024, 0.000, 3],
	["meadow_slime", -0.012, -0.006, 2],
	["skeleton_minion", 0.036, 0.012, 3],
	["skeleton_warrior", -0.022, 0.034, 2],
	["skeleton_rogue", 0.042, -0.008, 2],
	["skeleton_mage", -0.034, 0.030, 2],
	["forest_wolf", 0.016, 0.038, 1],
	["wraith", 0.044, 0.030, 1],
	["earth_golem", -0.044, 0.026, 1],
	["boar", -0.008, 0.042, 1],
]

## Chests: [id, lon, lat, kind]  kind: "normal" | "gold"
const CHESTS = [
	{"id": "chest_village", "lon": 0.014, "lat": 0.012, "gold": false},
	{"id": "chest_grove", "lon": -0.010, "lat": 0.032, "gold": false},
	{"id": "chest_ridge", "lon": -0.040, "lat": 0.016, "gold": true},
	{"id": "chest_barrow", "lon": DUNGEON_LON, "lat": DUNGEON_LAT + 0.004, "gold": true},
]

## Buildings placed around the village square.
const BUILDINGS = [
	{"id": "guild_hall", "lon": 0.012, "lat": 0.010, "asset": AssetCatalog.CITY_BUILDING_A, "scale": 2.6, "yaw": 0.0},
	{"id": "house_a", "lon": 0.006, "lat": 0.006, "asset": AssetCatalog.CITY_BUILDING_B, "scale": 2.1, "yaw": 0.7},
	{"id": "house_b", "lon": 0.018, "lat": 0.005, "asset": AssetCatalog.CITY_BUILDING_C, "scale": 2.1, "yaw": -0.6},
	{"id": "house_c", "lon": 0.020, "lat": 0.015, "asset": AssetCatalog.CITY_BUILDING_B, "scale": 1.9, "yaw": 2.4},
	{"id": "forge", "lon": 0.004, "lat": 0.014, "asset": AssetCatalog.CITY_BUILDING_C, "scale": 1.7, "yaw": 1.2},
	{"id": "outpost", "lon": -0.004, "lat": 0.010, "asset": AssetCatalog.CITY_BUILDING_A, "scale": 1.6, "yaw": -1.1},
]


static func shrine_direction(row: Dictionary) -> Vector3:
	return Terrain.ground_point(Math3D.direction(row["lon"], row["lat"]))


static func village_direction() -> Vector3:
	return Math3D.direction(VILLAGE_LON, VILLAGE_LAT)


static func dungeon_direction() -> Vector3:
	return Math3D.direction(DUNGEON_LON, DUNGEON_LAT)


static func resource_direction(row: Dictionary) -> Vector3:
	return Math3D.direction(row["lon"], row["lat"])


static func camp_directions(row: Array) -> Array[Vector3]:
	var centre := Math3D.direction(row[1], row[2])
	var result: Array[Vector3] = []
	var count: int = row[3]
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(1, count))
		var tangent := Math3D.east(centre) * cos(angle) + Math3D.north(centre) * sin(angle)
		var offset := 2.4 + 1.3 * float(i)
		result.append((centre + tangent * (offset / Math3D.RADIUS)).normalized())
	return result


## Deterministic village scatter (trees, bushes, benches, barrels).
static func scatter_points(centre: Vector3, radius_metres: float, count: int, salt: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(centre.snapped(Vector3.ONE * 0.001)) + salt * 7919
	var guard := 0
	while points.size() < count and guard < count * 12:
		guard += 1
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius_metres
		var tangent := Math3D.east(centre) * cos(angle) + Math3D.north(centre) * sin(angle)
		var candidate := (centre + tangent * (distance / Math3D.RADIUS)).normalized()
		if Terrain.is_water(candidate) or Terrain.elevation(candidate) < Terrain.WATER_LEVEL + 1.0:
			continue
		if Math3D.arc_distance(candidate, village_direction()) < 7.0:
			continue
		points.append(candidate)
	return points
