class_name BossAttack
extends Resource
## One attack a boss can make. Every attack has a warning (`telegraph_time`) so it can be avoided by moving.
## SLAM marks the player's spot and blasts it, CHARGE dashes along a line fixed at the start of the warning
## and then leaves the boss open, BURST fires a ring of projectiles, and SUMMON calls minions.

enum Kind { SLAM, CHARGE, BURST, SUMMON }

@export var kind: Kind = Kind.SLAM
## Seconds of warning before the attack happens.
@export var telegraph_time: float = 1.0
## SLAM: the blast radius.
@export var radius: float = 48.0
## SLAM and CHARGE: the damage of the blast or the dash. BURST: the damage of each projectile.
@export var damage: float = 20.0
## CHARGE: how fast and for how long it dashes.
@export var dash_speed: float = 260.0
@export var dash_time: float = 0.6
## Seconds the boss stays still after the attack. After a CHARGE this is the vulnerability window.
@export var recover_time: float = 0.3
## CHARGE: while recovering the boss takes this fraction more damage (0.5 is +50%).
@export var vulnerability_bonus: float = 0.0
## BURST: the projectiles' speed and range.
@export var projectile_speed: float = 100.0
@export var projectile_range: float = 260.0
## BURST: how many projectiles in the ring. SUMMON: how many minions.
@export var count: int = 4
## SUMMON: the kind of minion.
@export var summon_archetype: EnemyArchetype
