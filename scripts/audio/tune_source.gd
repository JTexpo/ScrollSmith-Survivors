class_name TuneSource
extends RefCounted
## One tune read from a `.tune` text file: `tempo <bpm>`, an optional `loop` line, then for each voice a line
## `channel <wave> <volume>` followed by lines of cells separated by spaces (`|` is a bar line and is ignored). A cell is a
## note (`C4`, `F#3`, `Bb5`: a letter, an optional # or b, an octave), `-` (a rest) or `.` (keep the previous note sounding). One
## cell is one sixteenth note. On a `noise` channel an `x` is a short hit and `-` a rest. Every channel must have the same
## number of cells. `hand_made` marks a WAV the tool must not rebuild; `#` starts a comment. Mistakes are collected in
## `errors`, never thrown.

const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

var errors := PackedStringArray()
var hand_made := false
var loops := false
var tempo: float = 0.0
## Each: {"wave": StringName, "volume": float, "cells": PackedStringArray}.
var channels: Array[Dictionary] = []


static func parse(text: String) -> TuneSource:
	var source := TuneSource.new()
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
			"loop":
				source.loops = true
			"tempo":
				if parts.size() != 2 or not parts[1].is_valid_float() or float(parts[1]) <= 0.0:
					source.errors.append("line %d: expected 'tempo <bpm>' with a positive number" % number)
				else:
					source.tempo = float(parts[1])
			"channel":
				source._start_channel(number, parts)
			_:
				source._read_cells(number, parts)
	if source.tempo <= 0.0:
		source.errors.append("missing a positive 'tempo' line")
	if source.channels.is_empty():
		source.errors.append("a tune needs at least one 'channel'")
	else:
		var steps := (source.channels[0]["cells"] as PackedStringArray).size()
		for channel in source.channels:
			if (channel["cells"] as PackedStringArray).size() != steps:
				source.errors.append("every channel must have the same number of cells (%d), but a %s channel has %d" % [steps, channel["wave"], (channel["cells"] as PackedStringArray).size()])
	return source


func step_count() -> int:
	return (channels[0]["cells"] as PackedStringArray).size() if not channels.is_empty() else 0


## Seconds per cell: a sixteenth note.
func step_seconds() -> float:
	return 60.0 / tempo / 4.0 if tempo > 0.0 else 0.0


func duration() -> float:
	return float(step_count()) * step_seconds()


## The frequency of a note cell, or 0 for a rest, a hold or a noise hit. A4 is 440 Hz.
static func note_hz(cell: String) -> float:
	if not _is_note(cell):
		return 0.0
	var semitone: int = NOTE_OFFSETS[cell[0].to_upper()]
	var index := 1
	if cell[index] == "#":
		semitone += 1
		index += 1
	elif cell[index] == "b":
		semitone -= 1
		index += 1
	var octave := int(cell.substr(index))
	var midi := 12 * (octave + 1) + semitone
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


static func _is_note(cell: String) -> bool:
	if cell.length() < 2 or cell.length() > 4 or not NOTE_OFFSETS.has(cell[0].to_upper()):
		return false
	var index := 1
	if cell[index] == "#" or cell[index] == "b":
		index += 1
	return index < cell.length() and cell.substr(index).is_valid_int()


func _start_channel(number: int, parts: PackedStringArray) -> void:
	if parts.size() != 3 or not SfxSource.WAVES.has(StringName(parts[1])) or not parts[2].is_valid_float() or float(parts[2]) < 0.0:
		errors.append("line %d: expected 'channel <wave> <volume>' with a known wave" % number)
		channels.append({"wave": &"pulse50", "volume": 0.0, "cells": PackedStringArray(), "broken": true})
		return
	channels.append({"wave": StringName(parts[1]), "volume": float(parts[2]), "cells": PackedStringArray()})


func _read_cells(number: int, parts: PackedStringArray) -> void:
	if channels.is_empty():
		errors.append("line %d: cells before any 'channel' line" % number)
		return
	var channel := channels[channels.size() - 1]
	var cells: PackedStringArray = channel["cells"]
	var noise: bool = channel["wave"] == &"noise"
	for part in parts:
		if part == "|":
			continue
		if part == "-" or part == "." and not noise:
			cells.append(part)
		elif noise and part == "x":
			cells.append(part)
		elif not noise and _is_note(part):
			cells.append(part)
		else:
			errors.append("line %d: '%s' is not a valid cell here" % [number, part])
	channel["cells"] = cells
