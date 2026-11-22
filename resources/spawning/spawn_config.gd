class_name SpawnConfig
extends Resource

## Seconds between spawn attempts.
@export var interval: float = 0.5
@export var max_alive: int = 150
## How far outside the visible area enemies appear.
@export var spawn_margin: float = 24.0
@export var enemy_scene: PackedScene
## The enemies the spawner picks from, by each one's spawn_weight. Only used when `archetypes` is empty.
@export var enemy_pool: Array[EnemyData] = []
## The roles and elements an enemy is composed from (an archetype and an element, picked by weight).
@export var archetypes: Array[EnemyArchetype] = []
@export var elements: Array[EnemyElement] = []
## How the run gets harder with time. Null means no scaling: the interval and max_alive above are used.
@export var difficulty: DifficultyCurve
## What makes an enemy an elite. Null means no elites.
@export var elite_modifier: EliteModifier
