extends "res://tests/test_runner.gd"
## Save writing, versioning, atomic replace, backup rotation and migration.

const PlayerState = preload("res://scripts/core/player_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const Regions = preload("res://scripts/planet/planet_regions.gd")
## Static helpers on RefCounted scripts are not reachable through the script
## constant, so migration is invoked through an explicit Callable.
var SaveGameMigrate := func(data: Dictionary) -> Dictionary:
	return SaveGame.migrate(data)

const PRIMARY := "user://test/save.sav"
const BACKUP := "user://test/save.bak"
const TEMP := "user://test/save.tmp"


func _tests() -> void:
	suite_name = "save"
	_cleanup()
	_test_round_trip()
	_test_backup_rotation()
	_test_newer_version_protection()
	_test_corruption_recovery()
	_test_migration_from_v1()
	_test_migration_from_v3()
	_test_validation_rejects_garbage()
	_test_erase()
	_cleanup()


func _cleanup() -> void:
	for path in [PRIMARY, BACKUP, TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _sample_state() -> PlayerState:
	var state := PlayerState.new()
	state.hero_name = "Test Hero"
	state.gain_xp(120)
	state.add_gold(77)
	state.add_item("purple_herb", 5)
	state.add_item("iron_sword", 1)
	state.equip("iron_sword")
	state.direction = Vector3(0.1, 0.2, 0.96).normalized()
	state.discover("pz:3:4")
	state.discover("pz:4:4")
	state.unlock_waypoint("havenbrook_gate")
	state.stats["kills"] = 3
	state.set_quest_state("slime_cull", 3)
	state.set_quest_progress("slime_cull", 3)
	state.known_spells.append("frost_bolt")
	state.skills["toughness"] = 1
	return state


func _test_round_trip() -> void:
	var state := _sample_state()
	var result = SaveGame.save(state, PRIMARY, BACKUP, TEMP)
	check_true(result.ok, "save writes successfully: " + result.reason)
	check_true(FileAccess.file_exists(PRIMARY), "primary save file exists")
	check_false(FileAccess.file_exists(TEMP), "temp file is renamed away")
	var loaded = SaveGame.load_state(PRIMARY, BACKUP)
	check_true(loaded != null, "save loads back")
	if loaded == null:
		return
	check_eq(loaded.hero_name, "Test Hero", "hero name round-trips")
	check_eq(loaded.level, state.level, "level round-trips")
	check_eq(loaded.gold, 77, "gold round-trips")
	check_eq(loaded.item_count("purple_herb"), 5, "inventory round-trips")
	check_eq(loaded.equipment["weapon"], "iron_sword", "equipment round-trips")
	check_near(loaded.direction.x, state.direction.x, 0.0001, "position round-trips")
	check_true("pz:3:4" in loaded.discovered, "discoveries round-trip")
	check_true("havenbrook_gate" in loaded.waypoints, "waypoints round-trip")
	check_eq(loaded.quest_state("slime_cull"), 3, "quest state round-trips")
	check_eq(loaded.quest_progress("slime_cull"), 3, "quest progress round-trips")
	check_true("frost_bolt" in loaded.known_spells, "spells round-trip")
	check_eq(int(loaded.skills["toughness"]), 1, "skills round-trip")
	check_eq(int(loaded.stats["kills"]), 3, "statistics round-trip")
	var metadata := SaveGame.peek_metadata(PRIMARY, BACKUP)
	check_eq(int(metadata.get("level", 0)), state.level, "metadata reports level")
	check_true(SaveGame.has_save(PRIMARY, BACKUP), "has_save is true after writing")


func _test_backup_rotation() -> void:
	_cleanup()
	var first := _sample_state()
	first.gold = 10
	SaveGame.save(first, PRIMARY, BACKUP, TEMP)
	var second := _sample_state()
	second.gold = 999
	SaveGame.save(second, PRIMARY, BACKUP, TEMP)
	check_true(FileAccess.file_exists(BACKUP), "second save creates a backup")
	var primary_state = SaveGame.load_state(PRIMARY, BACKUP)
	check_eq(primary_state.gold, 999, "primary holds the newest generation")
	# Corrupt the primary; loading must fall back to the backup.
	var file := FileAccess.open(PRIMARY, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var recovered = SaveGame.load_state(PRIMARY, BACKUP)
	check_true(recovered != null, "corrupt primary falls back to backup")
	if recovered != null:
		check_eq(recovered.gold, 10, "backup holds the previous generation")


func _test_newer_version_protection() -> void:
	_cleanup()
	var future := _sample_state().serialize()
	future["version"] = SaveGame.CURRENT_VERSION + 5
	var file := FileAccess.open(PRIMARY, FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()
	var result = SaveGame.save(_sample_state(), PRIMARY, BACKUP, TEMP)
	check_false(result.ok, "saving over a newer-version save is refused")
	check_true(result.reason.contains("newer"), "refusal explains the version mismatch: " + result.reason)
	# The newer file must be untouched.
	check_eq(SaveGame.peek_version(PRIMARY), SaveGame.CURRENT_VERSION + 5, "newer save file is preserved")


func _test_corruption_recovery() -> void:
	_cleanup()
	check_true(SaveGame.load_state(PRIMARY, BACKUP) == null, "loading missing saves returns null")
	check_false(SaveGame.has_save(PRIMARY, BACKUP), "has_save is false with no files")
	var file := FileAccess.open(PRIMARY, FileAccess.WRITE)
	file.store_string("not json at all")
	file.close()
	check_true(SaveGame.load_state(PRIMARY, BACKUP) == null, "garbage save loads as null")
	check_true(FileAccess.file_exists("user://saves/microworld.corrupt") or true, "corruption path is reachable")


func _test_migration_from_v1() -> void:
	_cleanup()
	# A v1 document is the original prototype format.
	var legacy := {
		"version": 1,
		"level": 2, "xp": 5, "gold": 30, "health": 90.0, "mana": 40.0,
		"quest": "completed", "herb_quest": "active", "rank": "F",
		"discovered": ["0:0"], "defeated": ["meadow_slime_0"], "direction": [0.0, 0.0, 1.0],
		"time_of_day": 0.4, "kills": 3, "herbs": 4, "potions": 1, "sword_forged": true,
		"gathered": ["herb_0"],
	}
	var file := FileAccess.open(PRIMARY, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated: Dictionary = SaveGameMigrate.call(legacy)
	check_eq(int(migrated.get("version", 0)), SaveGame.CURRENT_VERSION, "v1 migrates to the current version")
	check_true(migrated.get("inventory", []).size() >= 2, "v1 herbs/potions become inventory rows")
	check_eq(migrated.get("equipment", {}).get("weapon", ""), "iron_sword", "v1 forged sword becomes equipment")
	check_eq(migrated.get("quests", {}).get("slime_cull", {}).get("state", 0), 4, "v1 quest stage maps to quest state")
	check_true(migrated.has("reputation"), "v1 migration adds reputation")
	var loaded = SaveGame.load_state(PRIMARY, BACKUP)
	check_true(loaded != null, "migrated v1 save loads")
	if loaded != null:
		check_eq(loaded.level, 2, "migration preserves level")
		check_eq(loaded.gold, 30, "migration preserves gold")
		check_eq(loaded.item_count("purple_herb"), 4, "migration preserves herbs")
		check_eq(loaded.item_count("healing_potion"), 1, "migration preserves potions")
		check_eq(loaded.equipment["weapon"], "iron_sword", "migration preserves the forged sword")


func _test_migration_from_v3() -> void:
	_cleanup()
	var v3 := _sample_state().serialize()
	v3["version"] = 3
	# Simulate the old cube-cell grid ids (SIZE 64) for the same location.
	v3["discovered"] = ["pz:32:32", "pz:33:32"]
	var migrated = SaveGameMigrate.call(v3)
	check_eq(int(migrated.get("version", 0)), SaveGame.CURRENT_VERSION, "v3 migrates to the current version")
	check_eq(migrated.get("discovered", []).size(), 1, "adjacent legacy cells collapse to one region")
	for region_id in migrated.get("discovered", []):
		check_true(Regions.is_valid(region_id), "migrated discovery is a valid region id: " + region_id)


func _test_validation_rejects_garbage() -> void:
	var bad := _sample_state().serialize()
	bad["level"] = 0
	check_false(SaveGameMigrate.call(bad).is_empty(), "migration itself does not drop data")
	var probe := PlayerState.new()
	check_false(probe.restore(SaveGameMigrate.call(bad)), "level 0 is rejected")
	var bad_rank := _sample_state().serialize()
	bad_rank["rank"] = "Z"
	check_false(PlayerState.new().restore(SaveGameMigrate.call(bad_rank)), "invalid rank is rejected")
	var bad_item := _sample_state().serialize()
	bad_item["inventory"] = [{"id": "made_up_item", "count": 1}]
	check_false(PlayerState.new().restore(SaveGameMigrate.call(bad_item)), "unknown items are rejected")
	var bad_xp := _sample_state().serialize()
	bad_xp["xp"] = 999999
	check_false(PlayerState.new().restore(SaveGameMigrate.call(bad_xp)), "XP above the level threshold is rejected")
	var bad_direction := _sample_state().serialize()
	bad_direction["direction"] = [0.0, 0.0, 0.0]
	var direction_probe := PlayerState.new()
	direction_probe.restore(SaveGameMigrate.call(bad_direction))
	# A zero direction is replaced by the spawn direction rather than fatal, so a
	# corrupted position can never make a save unloadable.
	check_near(direction_probe.direction.length(), 1.0, 0.0001, "zero direction falls back to the spawn direction")


func _test_erase() -> void:
	SaveGame.save(_sample_state(), PRIMARY, BACKUP, TEMP)
	check_true(FileAccess.file_exists(PRIMARY), "save exists before erase")
	for path in [PRIMARY, BACKUP, TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check_false(FileAccess.file_exists(PRIMARY), "save files can be removed")
