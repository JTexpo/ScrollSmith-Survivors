class_name ValueGem
extends Area2D
## XP or Gold lying on the ground (an XP gem or a Gold coin, told apart by `kind`). Passive: only the
## player's PickupCollector looks for it. Its value can grow when the dropper merges a new drop into
## it at the cap, so nothing is ever lost.

enum Kind { XP, GOLD }

const XP_POINTS := [Vector2(0, -4), Vector2(4, 3), Vector2(-4, 3)]
const GOLD_POINTS := [Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]
## TEMPORARY colours (placeholder art).
const XP_COLOR := Color(1.0, 0.92, 0.55)
const GOLD_COLOR := Color(1.0, 0.72, 0.1)

@export var kind: Kind = Kind.XP

var value: int = 0

var _collected: bool = false

@onready var _shape: Polygon2D = $Shape
@onready var _body: BodyView = $Body


func _ready() -> void:
	add_to_group(&"xp_gems" if kind == Kind.XP else &"gold_coins")
	_shape.polygon = PackedVector2Array(XP_POINTS if kind == Kind.XP else GOLD_POINTS)
	_shape.color = XP_COLOR if kind == Kind.XP else GOLD_COLOR
	# The sprite sparkles and bobs; with no art the flat polygon stays.
	var has_art := _body.set_look(&"pickup_xp" if kind == Kind.XP else &"pickup_gold")
	_body.visible = has_art
	_shape.visible = not has_art
	if has_art:
		_body.set_sprite_material(_shape.material)
		_body.play(&"sparkle")


func setup(amount: int) -> void:
	value = amount


func add_value(amount: int) -> void:
	value += amount


## Returns the value the first time and 0 every time after.
func collect() -> int:
	if _collected:
		return 0
	_collected = true
	set_deferred("monitorable", false)
	queue_free()
	return value
