class_name ImpactConfig
extends Resource
## Every number behind the 13f polish, in one place so the feel can be tuned without touching code. The impact weight (0 to 1) of a
## spell is a blend of its wait and its damage per hit, each normalised between two values here; the weight then scales the burst,
## the shake, the flash and the hit sound. The health numbers drive the low-health warning. The comfort limits (shake size, flash
## opacity and gap, pulse opacity and rate) are pinned by tests so no tuning can make the effects bother a player.

const DEFAULT_PATH := "res://resources/fx/impact_config.tres"

@export_group("Impact weight")
@export var wait_min: float = 0.3
@export var wait_max: float = 1.5
@export var damage_min: float = 6.0
@export var damage_max: float = 40.0
## How much of the weight comes from the wait; the rest comes from the damage.
@export var wait_share: float = 0.6

@export_group("Impact effects")
## The weights where the shake and the flash start.
@export var shake_from: float = 0.35
@export var flash_from: float = 0.5
@export var shake_max_px: float = 4.0
@export var flash_max_alpha: float = 0.12
@export var flash_seconds: float = 0.08
@export var shake_gap_msec: int = 80
@export var flash_gap_msec: int = 334
@export var particles_light: int = 3
@export var particles_heavy: int = 24
## At weight 1 the hit sound's pitch is multiplied by (1 - this) and it is this many dB louder.
@export var sound_pitch_drop: float = 0.25
@export var sound_volume_up_db: float = 4.0

@export_group("Health warning")
## The heart starts to beat below the first, the red frame and the heartbeat below the second (fractions of full health).
@export var health_beat_from: float = 0.5
@export var health_warn_from: float = 0.3
@export var warn_max_alpha: float = 0.4
## Pulse rates in Hz: the frame at the warning threshold and near death, and the slow heart beat above the threshold.
@export var warn_rate_low: float = 0.8
@export var warn_rate_high: float = 2.0
@export var beat_rate_slow: float = 0.5


static func default_config() -> ImpactConfig:
	return load(DEFAULT_PATH) as ImpactConfig
