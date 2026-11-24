class_name BossAttack
extends Resource
## One attack a boss can make. Every attack has a warning (`telegraph_time`) so it can be avoided by moving.
## SLAM marks the player's spot and blasts it, CHARGE dashes along a line fixed at the start of the warning
## and then leaves the boss open, BURST fires a ring of projectiles, SUMMON calls minions, and LIGHTNING marks several spots around the
## player (the first on the player) that all blast when the warning ends.

## New kinds are only ever added at the end, so saved numbers stay valid.
enum Kind { SLAM, CHARGE, BURST, SUMMON, LIGHTNING }

@export var kind: Kind = Kind.SLAM
## Seconds of warning before the attack happens.
@export var telegraph_time: float = 1.0
## SLAM: the blast radius. LIGHTNING: the radius of each strike.
@export var radius: float = 48.0
## SLAM, CHARGE and LIGHTNING: the damage of the blast, the dash or each strike. BURST: the damage of each projectile.
@export var damage: float = 20.0
## CHARGE: how fast and for how long it dashes.
@export var dash_speed: float = 260.0
@export var dash_time: float = 0.6
## Seconds the boss stays still after the attack. After a CHARGE this is the vulnerability window.
@export var recover_time: float = 0.3
## CHARGE: while recovering the boss takes this fraction more damage (0.5 is +50%).
@export var vulnerability_bonus: float = 0.0
## CHARGE: extra dashes after the first (a stampede). Each is warned for `chain_warning` and re-aimed at the player; a wall ends the chain.
@export var repeats: int = 0
## CHARGE: seconds of warning before each chained dash (the first dash uses `telegraph_time`).
@export var chain_warning: float = 0.6
## BURST: the projectiles' speed and range.
@export var projectile_speed: float = 100.0
@export var projectile_range: float = 260.0
## BURST: how many projectiles in the ring. SUMMON: how many minions. LIGHTNING: how many strikes.
@export var count: int = 4
## LIGHTNING: how far from the player the other strikes may land (the first lands on the player).
@export var spread: float = 80.0
## SUMMON: the kind of minion.
@export var summon_archetype: EnemyArchetype


## LIGHTNING: how much farther a player at `player_speed` runs during the warning than the strikes reach (`spread + radius`). Positive means a
## player who runs straight away can always leave every strike before it lands; the Dragon's data keeps this above zero.
func escape_margin(player_speed: float) -> float:
	return player_speed * telegraph_time - (spread + radius)


## CHARGE: how many dashes the attack makes in a row (one, plus `repeats`).
func dash_count() -> int:
	return 1 + maxi(repeats, 0)
