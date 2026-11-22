class_name EnemyArchetype
extends Resource
## An enemy's role: every stat, its size, its behaviour, when it first appears and how often. An
## element is added on top by the EnemyComposer and only supplies affinity, colour and drops.

@export var id: StringName
@export var display_name: String
@export var max_health: float = 20.0
@export var speed: float = 40.0
@export var contact_damage: float = 10.0
## Body size (the enemy node's scale).
@export var body_scale: float = 1.0
## Random speed spread as a fraction (0.15 means 85% to 115% of speed).
@export var speed_variation: float = 0.15
## Each enemy aims at a random point within this radius of the player, to spread a horde out.
@export var offset_radius: float = 24.0
@export var contact_cooldown: float = 1.0
@export var contact_knockback: float = 80.0
@export var xp_reward: int = 5
@export var gold_reward: int = 1
## How often the spawner picks this role, relative to the others unlocked.
@export var spawn_weight: float = 1.0
## Run seconds before this role starts to appear.
@export var unlock_seconds: float = 0.0
## How many enemies one spawn makes (Swarmers come in clusters).
@export var cluster_size: int = 1
## Multiplies the element's drop chance for this role (a Tank drops more).
@export var drop_chance_scale: float = 1.0
## Lightens (above 0) or darkens (below 0) the element colour, so roles can be told apart.
@export var shade: float = 0.0
@export var behavior: EnemyBehaviorData
