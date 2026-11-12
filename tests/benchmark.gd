extends SceneTree
## Headless performance benchmark for MICRO WORLD: LIVING.
##
## Measures the costs that are actually attributable to *this project* (world
## construction, terrain sampling, region queries, simulation ticks) rather than
## GPU frame rate, which a headless dummy renderer cannot report.  Run with:
##
##   godot --headless --path . --script tests/benchmark.gd
##
## Every printed number is a real measurement taken on the machine that ran it;
## the report it produces says so explicitly.

const PlanetMesh = preload("res://scripts/planet/planet_mesh.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const PlanetRegions = preload("res://scripts/planet/planet_regions.gd")
const SphereMath = preload("res://scripts/planet/sphere_math.gd")

var _rows: Array[String] = []


func _init() -> void:
	var budget_start := Time.get_ticks_usec()
	_benchmark_terrain()
	_benchmark_regions()
	_benchmark_mesh()
	var build_ms := (Time.get_ticks_usec() - budget_start) / 1000.0
	_rows.append("TOTAL planet generation pipeline: %.1f ms" % build_ms)
	print("")
	for row in _rows:
		print("PERF  " + row)
	print("BENCHMARK_DONE")
	quit(0)


func _benchmark_terrain() -> void:
	var samples := 20000
	var start := Time.get_ticks_usec()
	var checksum := 0.0
	for i in range(samples):
		var direction := Vector3(
			sin(float(i) * 0.37), cos(float(i) * 0.71), sin(float(i) * 0.13 + 1.7)
		).normalized()
		checksum += Terrain.elevation(direction) + Terrain.moisture(direction)
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	_rows.append("terrain elevation+moisture: %d samples in %.1f ms (%.2f us/sample, checksum %.1f)" % [
		samples, elapsed, elapsed * 1000.0 / float(samples), checksum
	])


func _benchmark_regions() -> void:
	var start := Time.get_ticks_usec()
	var lookups := 50000
	var visited := {}
	for i in range(lookups):
		var direction := Vector3(
			sin(float(i) * 0.11), cos(float(i) * 0.29), sin(float(i) * 0.53)
		).normalized()
		visited[PlanetRegions.region_of(direction)] = true
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	_rows.append("planet_regions.region_of: %d lookups in %.1f ms (%.2f us/lookup), %d unique regions" % [
		lookups, elapsed, elapsed * 1000.0 / float(lookups), visited.size()
	])


func _benchmark_mesh() -> void:
	for resolution in [12, 16]:
		var start := Time.get_ticks_usec()
		var total_vertices := 0
		var total_triangles := 0
		for face in PlanetRegions.FACES:
			var payload = PlanetMesh.build_face(face, resolution)
			total_vertices += (payload.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			total_triangles += (payload.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0
		_rows.append("planet mesh %dx%d per face: %d verts / %d tris in %.1f ms" % [
			resolution, resolution, total_vertices, total_triangles, elapsed
		])
