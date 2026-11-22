class_name EnemyBehaviorData
extends Resource
## What an archetype does besides walking at the player. `kind` picks the behaviour, and only the
## numbers of that kind are used. Nothing branches on an enemy's name.

enum Kind { CHASE, KEEP_DISTANCE, EXPLODE, SUPPORT }

@export var kind: Kind = Kind.CHASE

@export_group("Keep distance (Ranged)")
## It approaches until it is about this far from the player, and backs off when closer.
@export var preferred_distance: float = 90.0
@export var shoot_interval: float = 2.0
@export var projectile_speed: float = 110.0
@export var projectile_damage: float = 8.0
@export var projectile_range: float = 220.0

@export_group("Explode (Exploder)")
## How close it gets before it stops and starts its fuse.
@export var trigger_distance: float = 28.0
@export var fuse_time: float = 0.8
@export var blast_radius: float = 36.0
@export var blast_damage: float = 24.0

@export_group("Support")
@export var support_radius: float = 70.0
@export var heal_per_second: float = 6.0
