class_name FxSettings
extends RefCounted
## The two comfort numbers for screen effects. 1.0 is the designed strength, 0.0 turns that effect off. Sprint 15's settings
## screen only has to set these two.

static var shake_scale: float = 1.0
static var flash_scale: float = 1.0


static func reset() -> void:
	shake_scale = 1.0
	flash_scale = 1.0
