class_name AudioBuilder
extends RefCounted
## Renders sound recipes and tunes into samples. Pure and deterministic: the same recipe always gives the same
## samples (the noise is a fixed shift register, never a random number), so a committed WAV can be compared with a fresh render.

const RATE := 22050
const NOISE_SEED := 1


## Every voice of the recipe mixed into `length * RATE` samples, clamped to -1..1.
static func render_sfx(source: SfxSource) -> PackedFloat32Array:
	var total := roundi(source.length * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	for voice in source.voices:
		_mix_voice(out, voice)
	for i in total:
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


## Every channel of the tune mixed into `duration * RATE` samples, clamped to -1..1. A note has a short attack, then a bouncy
## decay inside its step (a held note stretches it), and always fades out at its end, so the tune starts and ends silent and
## loops without a click.
static func render_tune(source: TuneSource) -> PackedFloat32Array:
	var step := float(RATE) * source.step_seconds()
	var total := roundi(float(source.step_count()) * step)
	var out := PackedFloat32Array()
	out.resize(total)
	for channel in source.channels:
		_mix_channel(out, channel, step)
	for i in total:
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


static func _mix_channel(out: PackedFloat32Array, channel: Dictionary, step: float) -> void:
	var cells: PackedStringArray = channel["cells"]
	var wave: StringName = channel["wave"]
	var volume: float = channel["volume"]
	var index := 0
	while index < cells.size():
		var cell := cells[index]
		var hz := TuneSource.note_hz(cell)
		var sounds := hz > 0.0 or (wave == &"noise" and cell == "x")
		var end := index + 1
		if sounds and wave != &"noise":
			while end < cells.size() and cells[end] == ".":
				end += 1
		if sounds:
			_mix_note(out, wave, volume, hz, roundi(float(index) * step), roundi(float(end) * step))
		index = end


static func _mix_note(out: PackedFloat32Array, wave: StringName, volume: float, hz: float, from: int, to: int) -> void:
	var span := maxi(to - from, 1)
	if wave == &"noise":
		span = mini(span, roundi(0.05 * RATE))
	var decay_rate := 1.2 if wave == &"triangle" else 2.6
	var phase := 0.0
	var lfsr := NOISE_SEED
	var noise_value := 1.0
	for i in span:
		var at := from + i
		if at >= out.size():
			break
		var t := float(i) / RATE
		var progress := float(i) / float(span)
		var value: float
		if wave == &"noise":
			phase += 9000.0 / RATE
			if phase >= 1.0:
				phase -= floorf(phase)
				var bit := (lfsr ^ (lfsr >> 1)) & 1
				lfsr = (lfsr >> 1) | (bit << 14)
				noise_value = 1.0 if (lfsr & 1) == 0 else -1.0
			value = noise_value
		else:
			phase = fposmod(phase + hz / RATE, 1.0)
			value = _tone(wave, phase)
		var env := minf(t / 0.004, 1.0) * exp(-decay_rate * progress)
		var remaining := float(span - i) / RATE
		env *= minf(remaining / 0.006, 1.0)
		out[at] += volume * env * value


static func _mix_voice(out: PackedFloat32Array, voice: Dictionary) -> void:
	var start := roundi(float(voice["delay"]) * RATE)
	var attack: float = voice["attack"]
	var decay: float = voice["decay"]
	var span := maxi(roundi((attack + decay) * RATE), 1)
	var wave: StringName = voice["wave"]
	var phase := 0.0
	var lfsr := NOISE_SEED
	var noise_value := 1.0
	var start_hz: float = voice["start_hz"]
	var end_hz: float = voice["end_hz"]
	for i in span:
		var at := start + i
		if at >= out.size():
			break
		var t := float(i) / RATE
		var progress := float(i) / float(span)
		var hz := _glide(start_hz, end_hz, progress)
		if float(voice["vibrato_hz"]) > 0.0 and hz > 0.0:
			hz *= pow(2.0, float(voice["vibrato_depth"]) * sin(TAU * float(voice["vibrato_hz"]) * t) / 12.0)
		var value: float
		if wave == &"noise":
			if hz <= 0.0:
				phase = 1.0
			else:
				phase += hz / RATE
			if phase >= 1.0:
				phase -= floorf(phase)
				var bit := (lfsr ^ (lfsr >> 1)) & 1
				lfsr = (lfsr >> 1) | (bit << 14)
				noise_value = 1.0 if (lfsr & 1) == 0 else -1.0
			value = noise_value
		else:
			phase = fposmod(phase + hz / RATE, 1.0)
			value = _tone(wave, phase)
		var env := (t / attack) if (attack > 0.0 and t < attack) else (1.0 - (t - attack) / decay if decay > 0.0 else 0.0)
		out[at] += float(voice["volume"]) * clampf(env, 0.0, 1.0) * value


## Pitch moves in a straight line on a log scale (so a slide sounds even), or in a straight line for noise speeds that touch 0.
static func _glide(from_hz: float, to_hz: float, progress: float) -> float:
	if from_hz > 0.0 and to_hz > 0.0:
		return from_hz * pow(to_hz / from_hz, progress)
	return lerpf(from_hz, to_hz, progress)


static func _tone(wave: StringName, phase: float) -> float:
	match wave:
		&"pulse12":
			return 1.0 if phase < 0.125 else -1.0
		&"pulse25":
			return 1.0 if phase < 0.25 else -1.0
		&"pulse50":
			return 1.0 if phase < 0.5 else -1.0
		&"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		&"saw":
			return 2.0 * phase - 1.0
	return 0.0


## Builds every `.sfx` in `<source_dir>/sounds` and `.tune` in `<source_dir>/music` into `<out_dir>/<id>.wav` (22,050 Hz mono
## 16 bit; a tune that says `loop` gets a loop chunk). A source with errors writes nothing and is reported; a `hand_made`
## source keeps the WAV already there (reported if it is missing). Returns the problems found.
static func build_all(source_dir: String, out_dir: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for kind in ["sounds", "music"]:
		var files := Array(DirAccess.get_files_at("%s/%s" % [source_dir, kind]))
		files.sort()
		for file in files:
			var extension := ".sfx" if kind == "sounds" else ".tune"
			if not String(file).ends_with(extension):
				continue
			var path := "%s/%s/%s" % [source_dir, kind, file]
			var text := FileAccess.get_file_as_string(path)
			var wav_path := "%s/%s.wav" % [out_dir, String(file).get_basename()]
			var errors := PackedStringArray()
			var hand_made := false
			var bytes := PackedByteArray()
			if kind == "sounds":
				var source := SfxSource.parse(text)
				errors = source.errors
				hand_made = source.hand_made
				if errors.is_empty() and not hand_made:
					bytes = WavWriter.encode(render_sfx(source), RATE)
			else:
				var tune := TuneSource.parse(text)
				errors = tune.errors
				hand_made = tune.hand_made
				if errors.is_empty() and not hand_made:
					bytes = WavWriter.encode(render_tune(tune), RATE, tune.loops)
			if not errors.is_empty():
				for error in errors:
					problems.append("%s: %s" % [path, error])
				continue
			if hand_made:
				if not FileAccess.file_exists(wav_path):
					problems.append("%s: hand_made needs its file %s" % [path, wav_path])
				continue
			var handle := FileAccess.open(wav_path, FileAccess.WRITE)
			if handle == null:
				problems.append("%s: cannot write %s" % [path, wav_path])
				continue
			handle.store_buffer(bytes)
			handle.close()
	return problems

