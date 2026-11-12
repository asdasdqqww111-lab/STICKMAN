extends "res://tests/test_runner.gd"
## Spherical maths, terrain determinism, biomes and region grid.

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const PlanetMesh = preload("res://scripts/planet/planet_mesh.gd")
const Regions = preload("res://scripts/planet/planet_regions.gd")


func _tests() -> void:
	suite_name = "planet"
	_test_sphere_math()
	_test_terrain()
	_test_regions()
	_test_mesh_generation()


func _test_sphere_math() -> void:
	var direction := Math3D.direction(0.75, 0.3)
	check_near(direction.length(), 1.0, 0.0001, "direction() returns a unit vector")
	var coordinates := Math3D.coordinates(direction)
	check_near(coordinates.x, 0.75, 0.0001, "longitude round-trips")
	check_near(coordinates.y, 0.3, 0.0001, "latitude round-trips")
	check_near(Math3D.north(direction).dot(direction), 0.0, 0.0001, "north is tangent")
	check_near(Math3D.east(direction).dot(direction), 0.0, 0.0001, "east is tangent")
	# Great-circle movement preserves the radius and the arc length.
	var start := Vector3(0, 0, 1)
	var moved := Math3D.move(start, Vector2(1, 0), 25.0)
	check_near(moved.length(), 1.0, 0.0001, "movement stays on the sphere")
	check_near(Math3D.arc_distance(start, moved), 25.0, 0.01, "movement covers the requested distance")
	# Moving "north" then "south" by the same amount returns to the start.
	var up := Math3D.move(start, Vector2(0, 1), 40.0)
	var back := Math3D.move(up, Vector2(0, -1), 40.0)
	check_near(Math3D.arc_distance(back, start), 0.0, 0.05, "opposite moves cancel out")
	check_near(Math3D.arc_distance(start, start), 0.0, 0.0001, "zero distance to self")
	var frame := Math3D.frame_at(direction)
	check_near(frame.y.dot(direction), 1.0, 0.0001, "frame Y axis is planet-up")
	check_near(frame.x.dot(frame.z), 0.0, 0.0001, "frame is orthogonal")
	# Pole handling must not produce NaN.
	var pole := Vector3(0, 1, 0)
	check_true(is_finite(Math3D.north(pole).x), "north at the pole is finite")
	check_true(Math3D.north(pole).length() > 0.9, "north at the pole is well defined")


func _test_terrain() -> void:
	# Determinism: the same direction must always give the same elevation.
	var probe := Math3D.direction(0.12, 0.05)
	var first := Terrain.elevation(probe)
	var second := Terrain.elevation(probe)
	check_eq(first, second, "terrain elevation is deterministic")
	check_true(first >= Terrain.SEA_FLOOR, "elevation respects the sea floor")
	check_true(first <= Terrain.MAX_ELEVATION + 6.0, "elevation respects the cap")
	# The spawn plateau is guaranteed dry land.
	check_true(Terrain.elevation(Terrain.SPAWN_UP) > Terrain.WATER_LEVEL + 1.0, "spawn point is dry land")
	check_false(Terrain.is_water(Terrain.SPAWN_UP), "spawn point is not water")
	# Ground point sits exactly at radius + elevation.
	var ground := Terrain.ground_point(probe)
	check_near(ground.length(), Math3D.RADIUS + Terrain.elevation(probe), 0.001, "ground_point matches elevation")
	# Normals point outward-ish.
	var normal := Terrain.ground_normal(probe)
	check_true(normal.dot(probe) > 0.3, "terrain normal points away from the planet core")
	check_near(normal.length(), 1.0, 0.01, "terrain normal is normalised")
	# Biome coverage: a scan of the sphere should find both land and water.
	var counts := {}
	for i in range(240):
		var lon := TAU * float(i) / 240.0
		var lat := -1.2 + 2.4 * float(i % 37) / 37.0
		var direction := Math3D.direction(lon, lat)
		var biome := Terrain.biome_at(direction)
		counts[biome] = int(counts.get(biome, 0)) + 1
	check_true(counts.keys().size() >= 3, "at least three biomes exist on the planet")
	check_true(counts.has(Terrain.Biome.MEADOW) or counts.has(Terrain.Biome.FOREST), "grassland biomes exist")
	check_true(counts.has(Terrain.Biome.OCEAN), "oceans exist")
	for biome in counts.keys():
		check_true(Terrain.biome_name(biome) != "", "biome %d has a name" % biome)


func _test_regions() -> void:
	var direction := Math3D.direction(0.05, 0.02)
	var region := Regions.region_of(direction)
	check_true(region != "", "region_of returns an id")
	var parts := region.split(":")
	check_eq(parts.size(), 3, "region id has three parts")
	check_true(parts[0] in Regions.FACES, "region face is valid")
	check_true(Regions.is_valid(region), "region id validates")
	var centre := Regions.region_center(region)
	check_near(centre.length(), 1.0, 0.0001, "region centre is on the sphere")
	# The centre of the region must map back to the same region id.
	check_eq(Regions.region_of(centre), region, "region lookup round-trips")
	var neighbours := Regions.neighborhood(direction, 1)
	check_true(neighbours.size() >= 8, "neighbourhood returns at least 8 regions")
	check_true(region in neighbours, "neighbourhood contains the current region")
	var unique := {}
	for id in neighbours:
		unique[id] = true
		check_true(Regions.is_valid(id), "neighbour id is valid: " + id)
	check_eq(unique.size(), neighbours.size(), "neighbours are unique")
	# All six cube faces must be reachable.
	var faces := {}
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var id := Regions.region_of(axis)
		check_true(id != "", "face axis maps to a region")
		faces[id.split(":")[0]] = true
	check_eq(faces.size(), 6, "all six cube faces are addressable")
	check_eq(Regions.region_of(Vector3.ZERO), "", "zero direction has no region")
	check_eq(Regions.region_center("bogus"), Vector3.ZERO, "invalid region id returns zero")
	check_near(Regions.region_radius_metres(), 32.72, 1.0, "region radius is about 33 m")


func _test_mesh_generation() -> void:
	var payload := PlanetMesh.build_face("pz", 4)
	check_eq(payload.arrays.size(), Mesh.ARRAY_MAX, "mesh payload has all arrays")
	var verts: PackedVector3Array = payload.arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = payload.arrays[Mesh.ARRAY_INDEX]
	var colours: PackedColorArray = payload.arrays[Mesh.ARRAY_COLOR]
	check_eq(verts.size(), 25, "4x4 grid has 25 vertices")
	check_eq(indices.size(), 4 * 4 * 6, "4x4 grid has 96 indices")
	check_eq(colours.size(), 25, "every vertex has a colour")
	var radii_ok := true
	for vertex in verts:
		if absf(vertex.length() - Math3D.RADIUS) > Terrain.MAX_ELEVATION + 12.0:
			radii_ok = false
	check_true(radii_ok, "all vertices stay near the planet radius")
	# Index buffer must reference valid vertices.
	var index_ok := true
	for index in indices:
		if index < 0 or index >= verts.size():
			index_ok = false
	check_true(index_ok, "index buffer is in range")
	# Cube-face parametrisation continuity at the shared edge.
	var a := PlanetMesh.face_direction("pz", 1.0, 0.0)
	var b := PlanetMesh.face_direction("px", -1.0, 0.0)
	check_near(Math3D.arc_distance(a, b), 0.0, 0.01, "adjacent cube faces meet at the seam")
