extends RefCounted
## Versioned, atomic, rotating save storage.
##
## Guarantees:
##   * a save written by a newer build is never overwritten by an older build;
##   * the previous good generation is rotated to a backup before replacement;
##   * writes go to a temp file then rename (atomic on the platforms we target);
##   * a corrupt primary falls back to the backup, and the corrupt file is kept
##     as .corrupt for offline diagnosis.

const PlayerState = preload("res://scripts/core/player_state.gd")
const CURRENT_VERSION := 4

const PRIMARY := "user://saves/microworld.sav"
const BACKUP := "user://saves/microworld.bak"
const TEMP := "user://saves/microworld.tmp"
const CORRUPT := "user://saves/microworld.corrupt"

signal save_written(path: String)
signal save_failed(reason: String)


## Result of a save attempt, for HUD/telemetry.
class SaveResult:
	var ok := false
	var reason := ""
	var bytes := 0


static func _ensure_dir(path: String) -> bool:
	var directory := path.get_base_dir()
	if directory == "" or DirAccess.dir_exists_absolute(directory):
		return true
	return DirAccess.make_dir_recursive_absolute(directory) == OK


## Serialise + write.  `state` is a PlayerState.
static func save(state: PlayerState, primary: String = PRIMARY, backup: String = BACKUP, temp: String = TEMP) -> SaveResult:
	var result := SaveResult.new()
	if not _ensure_dir(primary):
		result.reason = "cannot create save directory"
		return result
	var payload := state.serialize()
	payload["version"] = CURRENT_VERSION
	payload["__saved_at"] = Time.get_datetime_string_from_system(true)
	payload["__build"] = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var text := JSON.stringify(payload, "\t")

	# Refuse to clobber a save from a newer client.
	var existing_version := peek_version(primary)
	if existing_version > CURRENT_VERSION:
		result.reason = "existing save is version %d (newer than %d)" % [existing_version, CURRENT_VERSION]
		return result

	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		result.reason = "cannot open temp file (%s)" % error_string(FileAccess.get_open_error())
		return result
	file.store_string(text)
	file.flush()
	file.close()

	# Rotate the current primary into the backup before replacing it.
	if FileAccess.file_exists(primary):
		var previous := FileAccess.get_file_as_string(primary)
		if previous != "" and validate_text(previous):
			var backup_file := FileAccess.open(backup, FileAccess.WRITE)
			if backup_file != null:
				backup_file.store_string(previous)
				backup_file.flush()
				backup_file.close()

	var absolute_temp := ProjectSettings.globalize_path(temp)
	var absolute_primary := ProjectSettings.globalize_path(primary)
	# On Android rename across the same filesystem is atomic; remove first when the
	# platform refuses to replace.
	var error := DirAccess.rename_absolute(absolute_temp, absolute_primary)
	if error != OK:
		DirAccess.remove_absolute(absolute_primary)
		error = DirAccess.rename_absolute(absolute_temp, absolute_primary)
	if error != OK:
		result.reason = "rename failed (%s)" % error_string(error)
		return result
	result.ok = true
	result.bytes = text.length()
	return result


static func peek_version(path: String = PRIMARY) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var data := _parse(path)
	if data.is_empty():
		return 0
	return int(data.get("version", 0))


static func _parse(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	return parser.data


static func validate_text(text: String) -> bool:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return false
	var candidate := PlayerState.new()
	return candidate.restore(migrate(parser.data))


## Load the newest valid generation, falling back to the backup.
## Returns a PlayerState or null when neither file is usable.
static func load_state(primary: String = PRIMARY, backup: String = BACKUP) -> PlayerState:
	var data := _parse(primary)
	if data.is_empty() or not _restore_into(data):
		if FileAccess.file_exists(primary):
			_quarantine(primary)
		data = _parse(backup)
		if data.is_empty() or not _restore_into(data):
			return null
	var state := PlayerState.new()
	if not state.restore(migrate(data)):
		return null
	return state


static func _restore_into(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var probe := PlayerState.new()
	return probe.restore(migrate(data))


static func _quarantine(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return
	var file := FileAccess.open(CORRUPT, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


static func has_save(primary: String = PRIMARY, backup: String = BACKUP) -> bool:
	if not FileAccess.file_exists(primary) and not FileAccess.file_exists(backup):
		return false
	return _restore_into(_parse(primary)) or _restore_into(_parse(backup))


## Metadata for the "Continue" button (level, rank, play time, timestamp).
static func peek_metadata(primary: String = PRIMARY, backup: String = BACKUP) -> Dictionary:
	var data := _parse(primary)
	if data.is_empty() or not _restore_into(data):
		data = _parse(backup)
		if data.is_empty() or not _restore_into(data):
			return {}
	data = migrate(data)
	return {
		"hero_name": data.get("hero_name", "Wanderer"),
		"level": int(data.get("level", 1)),
		"rank": data.get("rank", "F"),
		"gold": int(data.get("gold", 0)),
		"saved_at": data.get("__saved_at", ""),
		"version": int(data.get("version", 0)),
	}


## Explicit, testable migration chain.  Never mutates the input dictionary.
static func migrate(input: Dictionary) -> Dictionary:
	var data := input.duplicate(true)
	var version := int(data.get("version", 0))
	if version > CURRENT_VERSION:
		# A newer client wrote this file; never downgrade it.
		return {}
	if version < 1:
		# Pre-versioned prototype documents carried stage flags (herbs/potions).
		version = 1
		data["version"] = version

	# v1 -> v2: prototype stage script (quest/herb_quest) becomes a quest map.
	if int(data.get("version", 0)) == 1:
		var quests := {}
		var legacy_stage := String(data.get("quest", "available"))
		var stage_map := {"available": 1, "active": 2, "ready": 3, "completed": 4}
		quests["welcome_to_havenbrook"] = {"state": 4, "progress": 1}
		quests["slime_cull"] = {"state": stage_map.get(legacy_stage, 1), "progress": int(data.get("kills", 0))}
		quests["moonbell_harvest"] = {"state": 1, "progress": 0}
		if data.has("herb_quest"):
			var herb_map := {"locked": 0, "available": 1, "active": 2, "ready": 4, "completed": 4}
			quests["moonbell_harvest"]["state"] = herb_map.get(String(data.get("herb_quest")), 1)
		data["quests"] = quests
		data["gathered"] = data.get("gathered", [])
		data["defeated"] = data.get("defeated", [])
		# herbs / potions / sword_forged are consumed by the v2 -> v3 step below.
		data.erase("kills")
		data["version"] = 2

	# v2 -> v3: flat stats -> inventory rows, equipment dict, reputation.
	if int(data.get("version", 0)) == 2:
		var inventory: Array = []
		var herbs := int(data.get("herbs", 0))
		if herbs > 0:
			inventory.append({"id": "purple_herb", "count": herbs})
		var potions := int(data.get("potions", 0))
		if potions > 0:
			inventory.append({"id": "healing_potion", "count": potions})
		data["inventory"] = inventory
		data["equipment"] = {
			"weapon": "iron_sword" if bool(data.get("sword_forged", false)) else "rusty_sword",
			"offhand": "",
			"armour": "",
		}
		data["reputation"] = 0
		if not data.has("stamina"):
			data["stamina"] = 100.0
		data.erase("herbs")
		data.erase("potions")
		data.erase("sword_forged")
		data.erase("herb_quest")
		data["version"] = 3

	# v3 -> v4: region ids moved from cube-cell grid (SIZE 64) to streamed regions (SIZE 12).
	if int(data.get("version", 0)) == 3:
		var Regions = load("res://scripts/planet/planet_regions.gd")
		var migrated: Array = []
		for entry in data.get("discovered", []):
			if not entry is String:
				continue
			var direction := Vector3.ZERO
			var parts: PackedStringArray = entry.split(":")
			if parts.size() == 3 and parts[0] in ["px", "nx", "py", "ny", "pz", "nz"] and parts[1].is_valid_int():
				var u := (float(int(parts[1])) + 0.5) / 64.0 * 2.0 - 1.0
				var v := (float(int(parts[2])) + 0.5) / 64.0 * 2.0 - 1.0
				var PlanetMesh = load("res://scripts/planet/planet_mesh.gd")
				direction = PlanetMesh.face_direction(parts[0], u, v)
			if direction != Vector3.ZERO:
				var region: String = Regions.region_of(direction)
				if region != "" and region not in migrated:
					migrated.append(region)
		data["discovered"] = migrated
		data["hero_name"] = data.get("hero_name", "Wanderer")
		data["known_spells"] = data.get("known_spells", ["ember_bolt"])
		data["skills"] = data.get("skills", {"toughness": 0, "focus": 0, "swiftness": 0})
		data["unspent_skill_points"] = data.get("unspent_skill_points", 0)
		data["quests"] = data.get("quests", {})
		data["opened_chests"] = data.get("opened_chests", [])
		data["defeated_bosses"] = data.get("defeated_bosses", [])
		data["dungeon_cleared"] = data.get("dungeon_cleared", false)
		data["properties"] = data.get("properties", [])
		data["kill_counts"] = data.get("kill_counts", {})
		data["crafted_counts"] = data.get("crafted_counts", {})
		data["stats"] = data.get("stats", {})
		data["day"] = data.get("day", 1)
		data["yaw"] = data.get("yaw", 0.0)
		data["spell_cooldowns"] = data.get("spell_cooldowns", {})
		data["version"] = 4
	return data


## Delete all save generations (used by the "New Game" flow after confirmation).
static func erase_all() -> void:
	for path in [PRIMARY, BACKUP, TEMP, CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
