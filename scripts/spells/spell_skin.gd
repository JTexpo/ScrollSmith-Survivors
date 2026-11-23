class_name SpellSkin
extends RefCounted
## Dresses an area spell in its element's look. The exact hit polygon stays as a faint tint with a bright 1 px edge, and
## effect sprites (flames and spikes rising, bolts and water falling) play over it. The sprites are only a skin: they
## never change the polygon, its hitbox or its timing. With no element look, nothing changes, and with no sprite art only
## the tint and edge appear.

## How long the effect plays, for an instant area (the Cone and the Line): its sprites start over the first 40% of this.
const INSTANT_LIFE := 0.35
const WINDOW_SHARE := 0.4
## How long each sprite fades after it has played.
const FADE := 0.15
const EDGE_NAME := "Edge"


## Tints the visual, adds the edge, and spawns the sprites. `polygon` is the exact hit area in `area`'s own coordinates and
## `origin` is the caster's point in them (rising effects start nearest it). Returns the sprites spawned.
static func dress(area: Node2D, visual: Polygon2D, polygon: PackedVector2Array, spell: SpellData, origin: Vector2, life: float, rng: RandomNumberGenerator) -> Array[EffectSprite]:
	var looks := _looks(spell)
	if looks.is_empty():
		return [] as Array[EffectSprite]
	visual.color = looks[0].tint
	_add_edge(visual, polygon, looks[0].edge)
	return _spawn(area, polygon, looks, origin, life, rng)


## A fresh set of sprites only, for a Zone's damage tick: the tint and edge are already there.
static func pulse(area: Node2D, polygon: PackedVector2Array, spell: SpellData, origin: Vector2, life: float, rng: RandomNumberGenerator) -> Array[EffectSprite]:
	var looks := _looks(spell)
	if looks.is_empty():
		return [] as Array[EffectSprite]
	return _spawn(area, polygon, looks, origin, life, rng)


static func _looks(spell: SpellData) -> Array[ElementLook]:
	var looks: Array[ElementLook] = []
	for element in spell.elements:
		var look := ElementLooks.for_element(element)
		if look != null:
			looks.append(look)
	return looks


static func _add_edge(visual: Polygon2D, polygon: PackedVector2Array, color: Color) -> void:
	var old := visual.get_node_or_null(EDGE_NAME)
	if old != null:
		old.free()
	var edge := Line2D.new()
	edge.name = EDGE_NAME
	edge.width = 1.0
	edge.default_color = color
	var points := PackedVector2Array(polygon)
	points.append(polygon[0])
	edge.points = points
	visual.add_child(edge)


static func _spawn(area: Node2D, polygon: PackedVector2Array, looks: Array[ElementLook], origin: Vector2, life: float, rng: RandomNumberGenerator) -> Array[EffectSprite]:
	var result: Array[EffectSprite] = []
	if not area.is_inside_tree() or polygon.size() < 3:
		return result
	var count := EffectPlan.count_for(EffectPlan.area_of(polygon))
	var spots := EffectPlan.spots(polygon, count, rng)
	var delays := EffectPlan.delays(spots, looks[0].rises, origin, life * WINDOW_SHARE, rng)
	# The sprites outlive an instant area, so they go next to it, not under it.
	var parent: Node = area.get_parent() if area.get_parent() != null else area
	for i in spots.size():
		var look := looks[i % looks.size()]
		var sprite := EffectSprite.spawn(parent, look.effect_sprite, area.to_global(spots[i]), delays[i], FADE)
		if sprite != null:
			result.append(sprite)
	return result
