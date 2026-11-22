class_name DifficultyCurve
extends Resource
## How hard the run gets as it goes on. Every method takes run seconds (negative counts as 0) and
## returns the multiplier or number for that moment. All the numbers are exported, so tuning the
## game is a data edit.

const DEFAULT_PATH := "res://resources/enemies/difficulty_curve.tres"

@export_group("Enemy scaling (per minute)")
@export var health_per_minute: float = 0.12
@export var damage_per_minute: float = 0.06
@export var speed_per_minute: float = 0.02
## Speed never rises more than this fraction (0.25 is +25%).
@export var speed_cap: float = 0.25

@export_group("Spawning")
@export var base_interval: float = 0.5
@export var interval_rate: float = 0.15
@export var min_interval: float = 0.12
@export var base_max_alive: int = 150
@export var max_alive_per_minute: float = 20.0
@export var max_alive_cap: int = 300

@export_group("Elites")
@export var elite_start_seconds: float = 120.0
@export var elite_per_minute: float = 0.02
@export var elite_cap: float = 0.2

@export_group("Bosses")
@export var boss_interval_seconds: float = 300.0
@export var boss_health_per_extra: float = 0.5
@export var boss_damage_per_extra: float = 0.2


static func default_curve() -> DifficultyCurve:
	return load(DEFAULT_PATH) as DifficultyCurve


func health_scale(seconds: float) -> float:
	return 1.0 + health_per_minute * _minutes(seconds)


func damage_scale(seconds: float) -> float:
	return 1.0 + damage_per_minute * _minutes(seconds)


func speed_scale(seconds: float) -> float:
	return 1.0 + minf(speed_per_minute * _minutes(seconds), speed_cap)


func spawn_interval(seconds: float) -> float:
	return maxf(base_interval / (1.0 + interval_rate * _minutes(seconds)), min_interval)


func max_alive(seconds: float) -> int:
	return mini(base_max_alive + int(max_alive_per_minute * _minutes(seconds)), max_alive_cap)


## The chance a spawn is an elite: 0 until `elite_start_seconds`, then rising to the cap.
func elite_chance(seconds: float) -> float:
	if seconds <= elite_start_seconds:
		return 0.0
	return minf((seconds - elite_start_seconds) / 60.0 * elite_per_minute, elite_cap)


## Boss number 1 is the plain boss. Later ones grow (numbers below 1 count as 1).
func boss_health_scale(boss_number: int) -> float:
	return 1.0 + boss_health_per_extra * (maxi(boss_number, 1) - 1)


func boss_damage_scale(boss_number: int) -> float:
	return 1.0 + boss_damage_per_extra * (maxi(boss_number, 1) - 1)


func _minutes(seconds: float) -> float:
	return maxf(seconds, 0.0) / 60.0
