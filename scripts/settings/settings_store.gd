class_name SettingsStore
extends RefCounted
## Saves and loads the settings (the volumes and every effect switch) as one versioned JSON file, `user://settings.json`, apart from the
## progress save: New game erases progress and keeps settings, and a bad settings file never touches progress. The path is a parameter so
## tests never touch the player's real file. A missing file means defaults; an unusable one is kept as `.bak` and defaults apply.

const VERSION := 1
const DEFAULT_PATH := "user://settings.json"


## Resets everything to defaults, then applies the file when it can be used.
static func load_file(path: String = DEFAULT_PATH) -> void:
	GameSettings.reset()
	FxSettings.reset()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	var parsed = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not parsed is Dictionary or not _is_whole(parsed.get("version")) or int(parsed["version"]) != VERSION:
		_keep_as_backup(path)
		return
	if parsed.get("audio") is Dictionary:
		GameSettings.apply(parsed["audio"])
	if parsed.get("fx") is Dictionary:
		FxSettings.apply(parsed["fx"])


## Writes a temporary file and renames it over the old one. False on any failure, leaving the old file alone.
static func save_file(path: String = DEFAULT_PATH) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path.get_base_dir())):
		return false
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "audio": GameSettings.to_dict(), "fx": FxSettings.to_dict()}))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	return true


## Loads the saved settings and tells listeners, so a running sound board follows.
static func apply_saved(path: String = DEFAULT_PATH) -> void:
	load_file(path)
	SettingsEvents.announce()


static func _is_whole(value: Variant) -> bool:
	return (value is float or value is int) and float(value) == floorf(float(value))


static func _keep_as_backup(path: String) -> void:
	var backup := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(backup)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), backup)
