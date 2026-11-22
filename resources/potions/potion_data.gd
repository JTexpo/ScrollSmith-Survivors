class_name PotionData
extends Resource
## One potion. Behaviour comes from `kind` and the numbers, never from the id. HEAL restores
## `magnitude` of maximum health, RESTORE_MANA restores `magnitude` of every spell's pool, TIMED_BONUS
## adds `modifiers` for `duration` seconds, and INVULNERABILITY blocks all damage for `duration` seconds.

enum Kind { HEAL, RESTORE_MANA, TIMED_BONUS, INVULNERABILITY }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var price: int = 0
@export var kind: Kind = Kind.HEAL
## A fraction (0.4 is 40%). Used by HEAL and RESTORE_MANA.
@export var magnitude: float = 0.0
## Seconds the effect lasts. Used by TIMED_BONUS and INVULNERABILITY.
@export var duration: float = 0.0
## Seconds before this potion type can be drunk again.
@export var cooldown: float = 0.0
## The timed stat bonuses of a TIMED_BONUS potion.
@export var modifiers: Array[EquipmentModifier] = []
## Placeholder colour, standing in for the icon.
@export var color: Color = Color.WHITE
