class_name SoundLibrary
extends RefCounted
## Finds the sounds the audio build made (or the user replaced). A sound with no file returns null and is reported once, so a
## missing file never crashes the game and never floods the log.

## Where the sounds live. Tests point this at another folder.
static var root: String = "res://assets/audio"
static var warnings_issued: int = 0

static var _cache: Dictionary = {}
static var _warned: Dictionary = {}


static func find(id: StringName) -> AudioStream:
	var key := "%s/%s" % [root, id]
	if _cache.has(key):
		return _cache[key]
	var file_path := "%s.wav" % key
	if ResourceLoader.exists(file_path):
		var stream := load(file_path) as AudioStream
		if stream != null:
			_cache[key] = stream
			return stream
	warn_once(id)
	return null


static func warn_once(id: StringName) -> void:
	if _warned.has(id):
		return
	_warned[id] = true
	warnings_issued += 1
	push_warning("SoundLibrary: no sound file for '%s' in %s" % [id, root])


static func has_warned(id: StringName) -> bool:
	return _warned.has(id)


static func reset_warnings() -> void:
	_warned.clear()
	warnings_issued = 0
	_cache.clear()
