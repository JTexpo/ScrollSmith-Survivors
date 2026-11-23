class_name SfxSource
extends RefCounted
## One sound effect read from a `.sfx` text recipe: `length <seconds>` and one or more
## `voice <wave> <start_hz> <end_hz> <volume> <attack> <decay>` lines, each optionally followed by `vibrato <hz> <depth_semitones>`
## and `delay <seconds>`. `wave` is pulse12, pulse25, pulse50, triangle, saw or noise (for noise the pitch only sets how fast the
## noise steps, 0 meaning every sample). A voice starts at its delay and lasts `attack + decay` seconds: its volume rises from 0
## over the attack, then falls to 0 over the decay, while its pitch glides from start to end. A line `hand_made` says the WAV was
## made by hand and the tool must not rebuild it; `#` starts a comment. Mistakes are collected in `errors`, never thrown.

const WAVES: Array[StringName] = [&"pulse12", &"pulse25", &"pulse50", &"triangle", &"saw", &"noise"]

var errors := PackedStringArray()
var hand_made := false
var length: float = 0.0
## Each: {"wave", "start_hz", "end_hz", "volume", "attack", "decay", "vibrato_hz", "vibrato_depth", "delay"}.
var voices: Array[Dictionary] = []


static func parse(text: String) -> SfxSource:
	var source := SfxSource.new()
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.get_slice("#", 0).strip_edges()
		if line.is_empty():
			continue
		var parts := line.replace("\t", " ").split(" ", false)
		match parts[0]:
			"hand_made":
				source.hand_made = true
			"length":
				source._read_length(number, parts)
			"voice":
				source._read_voice(number, parts)
			_:
				source.errors.append("line %d: unknown line '%s'" % [number, parts[0]])
	if source.length <= 0.0:
		source.errors.append("missing a positive 'length' line")
	if source.voices.is_empty():
		source.errors.append("a recipe needs at least one 'voice' line")
	return source


func _read_length(number: int, parts: PackedStringArray) -> void:
	if parts.size() != 2 or not parts[1].is_valid_float() or float(parts[1]) <= 0.0:
		errors.append("line %d: expected 'length <seconds>' with a positive number" % number)
		return
	length = float(parts[1])


func _read_voice(number: int, parts: PackedStringArray) -> void:
	if parts.size() < 7:
		errors.append("line %d: expected 'voice <wave> <start_hz> <end_hz> <volume> <attack> <decay>'" % number)
		return
	var wave := StringName(parts[1])
	if not WAVES.has(wave):
		errors.append("line %d: unknown wave '%s'" % [number, parts[1]])
		return
	var values: Array[float] = []
	for i in range(2, 7):
		if not parts[i].is_valid_float() or float(parts[i]) < 0.0:
			errors.append("line %d: '%s' must be a number, zero or more" % [number, parts[i]])
			return
		values.append(float(parts[i]))
	if wave != &"noise" and (values[0] <= 0.0 or values[1] <= 0.0):
		errors.append("line %d: a tonal voice needs a start and end pitch above zero" % number)
		return
	if values[3] + values[4] <= 0.0:
		errors.append("line %d: a voice must last (attack plus decay above zero)" % number)
		return
	var voice := {"wave": wave, "start_hz": values[0], "end_hz": values[1], "volume": values[2], "attack": values[3], "decay": values[4], "vibrato_hz": 0.0, "vibrato_depth": 0.0, "delay": 0.0}
	var i := 7
	while i < parts.size():
		if parts[i] == "vibrato" and i + 2 < parts.size() and parts[i + 1].is_valid_float() and parts[i + 2].is_valid_float():
			voice["vibrato_hz"] = float(parts[i + 1])
			voice["vibrato_depth"] = float(parts[i + 2])
			i += 3
		elif parts[i] == "delay" and i + 1 < parts.size() and parts[i + 1].is_valid_float() and float(parts[i + 1]) >= 0.0:
			voice["delay"] = float(parts[i + 1])
			i += 2
		else:
			errors.append("line %d: unexpected '%s' after the voice numbers" % [number, parts[i]])
			return
	voices.append(voice)
