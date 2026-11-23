class_name ScrollPickup
extends Area2D
## A scroll lying on the ground. Passive: only the player's PickupCollector looks for it.
## The shape depends on the category (round Base, square Area, diamond Buff), so categories
## can be told apart without colour. It bobs through a shader (no per-pickup script or tween
## work) and stays until collected.

const BASE_RADIUS := 5.0
const AREA_HALF_SIDE := 4.0
const BUFF_RADIUS := 6.0
const BASE_POINTS := 12
## The sprite name suffix of each category (`scroll_base`, `scroll_area`, `scroll_buff`).
const SPRITE_BY_CATEGORY := {ScrollData.Category.BASE: "base", ScrollData.Category.AREA: "area", ScrollData.Category.BUFF: "buff"}

var scroll: ScrollData

var _collected: bool = false

@onready var _shape: Polygon2D = $Shape
@onready var _body: BodyView = $Body


func _ready() -> void:
	add_to_group(&"scroll_pickups")


func setup(scroll_data: ScrollData) -> void:
	scroll = scroll_data
	_shape.polygon = shape_points(scroll_data.category)
	_shape.color = scroll_data.color
	_show_art()


## The sprite of the scroll's category, tinted by its colour, with a sparkle for a Rare one. With no art the flat
## polygon stays and the sprite hides. The bob shader moves onto the sprite, so it still bobs with no script.
func _show_art() -> void:
	var has_art := _body.set_look(StringName("scroll_%s" % SPRITE_BY_CATEGORY[scroll.category]))
	_body.visible = has_art
	_shape.visible = not has_art
	if has_art:
		_body.set_tint(scroll.color)
		_body.set_sprite_material(_shape.material)
		_body.play(&"sparkle" if scroll.rarity == ScrollData.Rarity.RARE else &"idle")


## Returns the scroll the first time and null every time after.
func collect() -> ScrollData:
	if _collected:
		return null
	_collected = true
	set_deferred("monitorable", false)
	queue_free()
	return scroll


static func shape_points(category: ScrollData.Category) -> PackedVector2Array:
	match category:
		ScrollData.Category.AREA:
			var side := AREA_HALF_SIDE
			return PackedVector2Array([Vector2(-side, -side), Vector2(side, -side), Vector2(side, side), Vector2(-side, side)])
		ScrollData.Category.BUFF:
			var reach := BUFF_RADIUS
			return PackedVector2Array([Vector2(0, -reach), Vector2(reach, 0), Vector2(0, reach), Vector2(-reach, 0)])
	var points := PackedVector2Array()
	for i in BASE_POINTS:
		points.append(Vector2.from_angle(TAU * i / BASE_POINTS) * BASE_RADIUS)
	return points
