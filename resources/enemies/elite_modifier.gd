class_name EliteModifier
extends Resource
## What makes an enemy an elite, whatever its archetype and element: tougher, harder hitting, a little
## faster, bigger, and worth more. It is applied to one Enemy instance, never to shared data.

const DEFAULT_PATH := "res://resources/enemies/elite_modifier.tres"

@export var health_multiplier: float = 3.0
@export var damage_multiplier: float = 1.5
@export var speed_multiplier: float = 1.15
@export var size_multiplier: float = 1.4
## Multiplies XP and Gold.
@export var reward_multiplier: float = 3.0
## Multiplies the drop chance.
@export var drop_chance_multiplier: float = 2.0
@export var outline_color: Color = Color(1.0, 0.85, 0.2, 1.0)


static func default_modifier() -> EliteModifier:
	return load(DEFAULT_PATH) as EliteModifier
