extends RefCounted
const State = preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://world.json"
const BACKUP_PATH := "user://world.backup.json"
const TEMP_PATH := "user://world.tmp.json"

static func save_game(state: RefCounted, path: String = SAVE_PATH, backup_path: String = BACKUP_PATH, temp_path: String = TEMP_PATH) -> bool:
	# Never overwrite a valid future-version document with an older client.
	if FileAccess.file_exists(path):
		var current := FileAccess.open(path, FileAccess.READ)
		if current == null: return false
		var parser := JSON.new()
		if parser.parse(current.get_as_text()) == OK and parser.data is Dictionary:
			var version = parser.data.get("version")
			if typeof(version) in [TYPE_INT, TYPE_FLOAT] and version > 3: return false
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(state.serialize()))
	file.flush()
	file.close()
	# Keep the previous valid generation before replacing the primary.
	if FileAccess.file_exists(path):
		var previous = read_valid(path)
		if previous != null:
			var backup := FileAccess.open(backup_path, FileAccess.WRITE)
			if backup == null: return false
			backup.store_string(JSON.stringify(previous.serialize()))
			backup.flush()
			backup.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path)) == OK

static func read_valid(path: String):
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return null
	var data = parser.data
	if not data is Dictionary: return null
	var candidate = State.new()
	if not candidate.restore(data): return null
	return candidate

static func load_game(path: String = SAVE_PATH, backup_path: String = BACKUP_PATH):
	var state = read_valid(path)
	if state == null: state = read_valid(backup_path)
	return state
