class_name AudioBuilder
extends RefCounted
## Renders sound recipes (and, from Task 2, tunes) into samples. Pure and deterministic: the same recipe always gives the same
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
