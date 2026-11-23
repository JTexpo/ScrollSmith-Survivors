class_name FxSettings
extends RefCounted
## Every screen effect has a switch here, and nothing else decides whether it shows. They are all on by default. A later settings
## screen only has to set these values and save `to_dict()` (and `apply` it at start): no effect code needs to change. The two
## scales run from 0 (off) to 1 (the designed strength); a value above 1 is never used, so the comfort maximums cannot be exceeded.

static var shake_scale: float = 1.0
static var flash_scale: float = 1.0
## Sparks, dust, stars and sparkles (impacts, blasts, pickups, level-ups, rare drops).
static var particles: bool = true
## The pulsing red frame round the screen edge when health is low.
static var low_health_frame: bool = true
## The heart on the health bar beating.
static var heart_beat: bool = true
## The wizard's red flash and jitter when hit.
static var hurt_feedback: bool = true
## The arcs at the screen edge that point at where a hit came from.
static var hit_indicators: bool = true
## A spell slot's mana fill pulsing red when the spell is nearly out of mana.
static var low_mana_pulse: bool = true

const SCALE_KEYS := ["shake_scale", "flash_scale"]
const SWITCH_KEYS := ["particles", "low_health_frame", "heart_beat", "hurt_feedback", "hit_indicators", "low_mana_pulse"]


static func reset() -> void:
	shake_scale = 1.0
	flash_scale = 1.0
	particles = true
	low_health_frame = true
	heart_beat = true
	hurt_feedback = true
	hit_indicators = true
	low_mana_pulse = true


## A comfort preset: no shake, no flashes and no jitter. The low-health frame, the heart and the hit arcs stay, because they tell the
## player something rather than decorate.
static func reduce_motion() -> void:
	shake_scale = 0.0
	flash_scale = 0.0
	hurt_feedback = false


## All the settings as plain data, for a settings screen to save.
static func to_dict() -> Dictionary:
	return {
		"shake_scale": shake_scale,
		"flash_scale": flash_scale,
		"particles": particles,
		"low_health_frame": low_health_frame,
		"heart_beat": heart_beat,
		"hurt_feedback": hurt_feedback,
		"hit_indicators": hit_indicators,
		"low_mana_pulse": low_mana_pulse,
	}


## Restores saved settings. Unknown keys and wrongly typed values are ignored; a scale is held between 0 and 1.
static func apply(data: Dictionary) -> void:
	for key in SCALE_KEYS:
		if data.get(key) is float or data.get(key) is int:
			var value := clampf(float(data[key]), 0.0, 1.0)
			if key == "shake_scale":
				shake_scale = value
			else:
				flash_scale = value
	for key in SWITCH_KEYS:
		if data.get(key) is bool:
			match key:
				"particles":
					particles = data[key]
				"low_health_frame":
					low_health_frame = data[key]
				"heart_beat":
					heart_beat = data[key]
				"hurt_feedback":
					hurt_feedback = data[key]
				"hit_indicators":
					hit_indicators = data[key]
				"low_mana_pulse":
					low_mana_pulse = data[key]
