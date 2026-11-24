class_name GameSettings
extends RefCounted
## The player's volume choices (0 is silent, 1 is full), the full screen choice and the map played last. Like `FxSettings` these are static because the project has no autoloads;
## `SettingsStore` saves and loads them and `SettingsEvents` announces a change so the sound board can follow.

const DEFAULT_VOLUME := 0.8
## The map the map select focuses when nothing was saved (the catalog's first; a test pins them equal).
const DEFAULT_MAP := &"forest"

static var music_volume: float = DEFAULT_VOLUME
static var sfx_volume: float = DEFAULT_VOLUME
## The player chose full screen (saved; a desktop applies it at start, a browser only after a tap).
static var fullscreen: bool = false
## The id of the map played last, so Play comes back to it (saved under `play`; the map select treats an id it does not know as the default).
static var last_map: StringName = DEFAULT_MAP


static func reset() -> void:
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	fullscreen = false
	last_map = DEFAULT_MAP


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


static func play_dict() -> Dictionary:
	return {"last_map": String(last_map)}


## Restores the saved play choices. A missing, wrongly typed or empty value is ignored.
static func apply_play(data: Dictionary) -> void:
	if data.get("last_map") is String and not String(data["last_map"]).is_empty():
		last_map = StringName(data["last_map"])
