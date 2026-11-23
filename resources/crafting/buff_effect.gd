class_name BuffEffect
extends Resource
## What one stack of a buff does to a crafted spell. The Spell Builder folds the chosen stacks
## together: multipliers multiply once per stack, the bonus and the extra counts add per stack,
## and ignores_resistance is on if any stack sets it. Every buff raises the mana cost per cast.

@export var damage_multiplier: float = 1.0
@export var max_mana_multiplier: float = 1.0
## Multiplies the mana cost per cast. Damage and copies must cost at least what they buy.
@export var cost_multiplier: float = 1.0
## Added to the vulnerability scale (a strong hit's bonus is multiplied by 1 plus the total).
@export var vulnerability_bonus: float = 0.0
@export var ignores_resistance: bool = false
## Extra shots per cast (Duplicate Area).
@export var extra_copies: int = 0
## Extra element slots on the workbench (Additional Base).
@export var extra_bases: int = 0
## 0 means no limit.
@export var max_stacks: int = 0
## The colour of this buff's option on the starting-buff screen, and the icon (a sprite name) drawn on it. Data, so a new buff
## brings its own look.
@export var color: Color = Color.WHITE
@export var icon: StringName = &""
