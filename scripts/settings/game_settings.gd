class_name GameSettings
extends RefCounted
## The player's volume choices (0 is silent, 1 is full) and the full screen choice. Like `FxSettings` these are static because the project has no autoloads;
## `SettingsStore` saves and loads them and `SettingsEvents` announces a change so the sound board can follow.

const DEFAULT_VOLUME := 0.8

static var music_volume: float = DEFAULT_VOLUME
static var sfx_volume: float = DEFAULT_VOLUME
## The player chose full screen (saved; a desktop applies it at start, a browser only after a tap).
static var fullscreen: bool = false


static func reset() -> void:
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	fullscreen = false


static func to_dict() -> Dictionary:
	return {"music": music_volume, "sfx": sfx_volume, "fullscreen": fullscreen}


## Restores saved values. Unknown keys and wrongly typed values are ignored; a volume is held between 0 and 1.
static func apply(data: Dictionary) -> void:
	if data.get("music") is float or data.get("music") is int:
		music_volume = clampf(float(data["music"]), 0.0, 1.0)
	if data.get("sfx") is float or data.get("sfx") is int:
		sfx_volume = clampf(float(data["sfx"]), 0.0, 1.0)
	if data.get("fullscreen") is bool:
		fullscreen = data["fullscreen"]
