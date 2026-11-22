class_name EnemyElement
extends Resource
## The element half of an enemy: its affinity, its colour and the scrolls it drops. It has no stat
## flavour of its own, so a Thunder Tank is exactly as tough as a Land Tank.

@export var id: StringName
## "Fire", "Thunder", ... or empty for no element, so the composed name has no stray space.
@export var display_name: String
@export_enum("None:-1", "Fire:0", "Thunder:1", "Land:2", "Sea:3") var element: int = -1
@export var color: Color = Color(0.75, 0.75, 0.75)
@export var drop_table: DropTable
@export var spawn_weight: float = 1.0
