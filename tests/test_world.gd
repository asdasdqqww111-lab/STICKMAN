extends SceneTree
const Cells = preload("res://scripts/world_cells.gd")
const Sphere = preload("res://scripts/sphere.gd")
const State = preload("res://scripts/game_state.gd")
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, description: String) -> void:
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func run_tests() -> void:
	var valid := true
	var rng := RandomNumberGenerator.new(); rng.seed = 468271
	for i in range(3000):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var id: String = Cells.cell(dir)
		var neighbors: Array[String] = Cells.neighbors(dir)
		if Cells.parse(id).is_empty() or Cells.cell(Cells.point(id)) != id or id not in neighbors or neighbors.size() > 9 or neighbors.size() < 4: valid = false; break
		for n in neighbors:
			if Cells.parse(n).is_empty(): valid = false; break
	check(valid, "3000 sampled directions have canonical cells and bounded valid neighbors")
	for face in Cells.FACES:
		var middle: Vector3 = Cells.direction(face, 0, 0)
		check(Cells.cell(middle).begins_with(face + ":") and Cells.cell(Cells.point(Cells.cell(middle))) == Cells.cell(middle), "face center round trip " + face)
	var seam_a: Vector3 = Sphere.direction(PI - 0.00001, 0.25)
	var seam_b: Vector3 = Sphere.direction(-PI + 0.00001, 0.25)
	check((Cells.cell(seam_a) == Cells.cell(seam_b) or Cells.cell(seam_b) in Cells.neighbors(seam_a)), "longitude seam maps to the same or adjacent cube cells")
	var pole: Vector3 = Vector3.UP
	check(Cells.cell(pole).begins_with("py:") and Cells.neighbors(pole).size() <= 9, "north pole partition is valid")
	var face_a := Vector3(1.00001, 0.1, 1).normalized()
	var face_b := Vector3(1, 0.1, 1.00001).normalized()
	check(Cells.cell(face_a) != Cells.cell(face_b) and Cells.cell(face_b) in Cells.neighbors(face_a) and Cells.cell(face_a) in Cells.neighbors(face_b), "neighbor cells cross a cube edge")
	var edge_ok := true
	for face in Cells.FACES:
		for sign_value in [-1.0, 1.0]:
			for vertical in [false, true]:
				var a: Vector3 = Cells.direction(face, 0.37 if vertical else sign_value * 0.99999, sign_value * 0.99999 if vertical else 0.37)
				var b: Vector3 = Cells.direction(face, 0.37 if vertical else sign_value * 1.00001, sign_value * 1.00001 if vertical else 0.37)
				if Cells.cell(b) not in Cells.neighbors(a) or Cells.cell(a) not in Cells.neighbors(b): edge_ok = false
	check(edge_ok, "all face edges have neighboring cells across transitions")
	var old = State.new().serialize()
	old.version = 2; old.erase("waypoints"); old.discovered = ["0:0", "0:1", "-70:0"]
	var migrated = State.new()
	check(migrated.restore(old) and Cells.from_legacy("0:0") in migrated.discovered and migrated.waypoints.is_empty() and migrated.legacy_discovered == old.discovered and migrated.discovery_count() >= 3, "version 2 legacy cells and milestones migrate without unlocking travel")
	var polar_old = State.new().serialize()
	polar_old.version = 2; polar_old.erase("waypoints"); polar_old.erase("legacy_discovered"); polar_old.discovered = ["0:34", "1:34"]
	var polar = State.new()
	check(Cells.from_legacy("0:34") == Cells.from_legacy("1:34") and polar.restore(polar_old) and polar.discovery_count() == 2, "collapsed old cells retain exploration credit")
	polar.discover("px:0:0")
	check(polar.discovery_count() == 3, "new discoveries add to retained credit")
	var polar_round_trip = State.new()
	check(polar_round_trip.restore(JSON.parse_string(JSON.stringify(polar.serialize()))) and polar_round_trip.discovery_count() == 3 and polar_round_trip.legacy_discovered == ["0:34", "1:34"], "legacy exploration credit persists across version 3 reload")
	var before := migrated.serialize()
	check(migrated.unlock_waypoint("east") and not migrated.unlock_waypoint("east") and not migrated.unlock_waypoint("bogus"), "waypoints require known IDs and are idempotent")
	var restored = State.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(migrated.serialize()))) and restored.waypoints == ["east"], "waypoints persist in version 3")
	var bad: Dictionary = before.duplicate(true); bad.waypoints = ["bogus"]
	check(not restored.restore(bad) and restored.waypoints == ["east"], "unknown waypoint rejected without state mutation")
	print("Failures: ", failures)
	quit(1 if failures else 0)
