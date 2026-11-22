class_name BossPhase
extends Resource
## One phase of a boss fight. It starts when the boss's health ratio falls to `health_threshold` and uses
## its own attack list, pace and speed.

## The phase starts at or below this fraction of health (1.0 for the first phase).
@export var health_threshold: float = 1.0
@export var attacks: Array[BossAttack] = []
## Seconds of idle chasing between attacks.
@export var attack_interval: float = 2.5
@export var speed_multiplier: float = 1.0
