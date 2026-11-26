class_name GameVersion
extends RefCounted
## The game's version, set once as `config/version` in project.godot and read from there everywhere (Credits, the home screen, the page text).


static func current() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


## Exactly `major.minor.patch`, digits only.
static func is_valid(text: String) -> bool:
	var parts := text.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return false
	return true
