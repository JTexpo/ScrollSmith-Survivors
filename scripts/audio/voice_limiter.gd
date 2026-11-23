class_name VoiceLimiter
extends RefCounted
## Decides whether a sound may play now, and on which voice. Pure: it knows only voice slots, sound data and the time it is given,
## so the rules are testable without audio. A sound is refused when it is too soon after its own last start (`min_gap_msec`) or
## already has `max_voices` playing. With a free voice it plays. With none, a LOW or NORMAL sound is dropped, and a HIGH one
## steals the oldest LOW voice, or else the oldest voice, so a boss warning is never lost to a crowd of hits.

var _voices: Array[Dictionary] = []
var _last_start: Dictionary = {}


func _init(voice_count: int) -> void:
	for i in voice_count:
		_voices.append({})


## The voice to use, or -1 to drop the sound. Changes nothing: call `started` once the voice really plays.
func request(data: SoundData, now_msec: int) -> int:
	if data.min_gap_msec > 0 and _last_start.has(data.id) and now_msec - int(_last_start[data.id]) < data.min_gap_msec:
		return -1
	if playing_count_of(data.id) >= data.max_voices:
		return -1
	for i in _voices.size():
		if _voices[i].is_empty():
			return i
	if data.priority != SoundData.Priority.HIGH:
		return -1
	var oldest_low := -1
	var oldest := 0
	for i in _voices.size():
		var voice := _voices[i]
		if int(voice["started"]) < int(_voices[oldest]["started"]):
			oldest = i
		if voice["data"].priority == SoundData.Priority.LOW and (oldest_low < 0 or int(voice["started"]) < int(_voices[oldest_low]["started"])):
			oldest_low = i
	return oldest_low if oldest_low >= 0 else oldest


func started(index: int, data: SoundData, now_msec: int) -> void:
	_voices[index] = {"data": data, "started": now_msec}
	_last_start[data.id] = now_msec


func finished(index: int) -> void:
	_voices[index] = {}


func playing_count() -> int:
	var count := 0
	for voice in _voices:
		if not voice.is_empty():
			count += 1
	return count


func playing_count_of(id: StringName) -> int:
	var count := 0
	for voice in _voices:
		if not voice.is_empty() and voice["data"].id == id:
			count += 1
	return count
