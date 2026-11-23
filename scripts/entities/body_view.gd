class_name BodyView
extends Node2D
## What an entity looks like: a sprite from the art pipeline that plays animations, flips by facing, can be tinted and
## outlined, with the old coloured square as a fallback when there is no art. It replaces the `Body` colour rectangle.
## The hit flash sets this node's `modulate` and a state tint is the sprite's `self_modulate`, so the two multiply and
## never fight. It builds its own children, so a scene only needs a `Node2D` with this script.

signal animation_done(animation: StringName)

const FALLBACK_SIZE := 12.0

## The colour of the fallback square (what `Body.color` used to be).
var fallback_color: Color = Color(0.9, 0.25, 0.25):
	set(value):
		fallback_color = value
		if _fallback != null:
			_fallback.color = value

var _set_data: SpriteSetData
var _outline_set: SpriteSetData
var _outline: AnimatedSprite2D
var _sprite: AnimatedSprite2D
var _fallback: ColorRect
var _facing: float = 1.0


func _ready() -> void:
	_ensure_children()
	# Only a shown outline needs to follow the sprite's frame, so 300 plain enemies run no script each frame.
	set_process(_outline.visible)


func _process(_delta: float) -> void:
	# The outline copies the sprite's frame, so it is always the same pose, a pixel bigger.
	if _outline.visible and _sprite.animation != &"" and _outline.sprite_frames != null and _outline.sprite_frames.has_animation(_sprite.animation):
		_outline.animation = _sprite.animation
		_outline.frame = _sprite.frame


## Shows the sprite `<name>` in a variant (an element id), falling back to its base. False when there is no art, in
## which case the coloured square is shown.
func set_look(sprite_name: StringName, variant: StringName = &"base") -> bool:
	_ensure_children()
	var found := SpriteLibrary.find(sprite_name, variant)
	if found == null:
		_set_data = null
		_outline_set = null
		_sprite.visible = false
		_outline.visible = false
		set_process(false)
		_fallback.visible = true
		return false
	set_set(found)
	set_outline_set(SpriteLibrary.find_silhouette(sprite_name))
	return true


## Shows this set directly (for tests, and for `set_look`).
func set_set(set_data: SpriteSetData) -> void:
	_ensure_children()
	_set_data = set_data
	_sprite.sprite_frames = set_data.frames()
	_sprite.visible = true
	_fallback.visible = false
	_sprite.flip_h = _facing < 0.0
	_outline.flip_h = _facing < 0.0


## The silhouette used for an outline (null for none).
func set_outline_set(silhouette: SpriteSetData) -> void:
	_ensure_children()
	_outline_set = silhouette
	_outline.sprite_frames = silhouette.frames() if silhouette != null else null


func has_art() -> bool:
	return _set_data != null


func has_animation(animation: StringName) -> bool:
	return _set_data != null and _set_data.has_animation(animation)


## Plays an animation. A missing one is ignored (the current one keeps going), and the one already playing is not
## restarted.
func play(animation: StringName) -> void:
	_ensure_children()
	if not has_animation(animation):
		return
	if _sprite.animation == animation and _sprite.is_playing():
		return
	_sprite.play(animation)


func current_animation() -> StringName:
	if _set_data == null:
		return &""
	return _sprite.animation


## Flips the sprite to face a direction (a zero keeps the last facing).
func set_facing(direction_x: float) -> void:
	_ensure_children()
	var facing := _facing
	if direction_x < 0.0:
		facing = -1.0
	elif direction_x > 0.0:
		facing = 1.0
	if facing == _facing and _sprite != null:
		return
	_facing = facing
	_sprite.flip_h = _facing < 0.0
	_outline.flip_h = _facing < 0.0


## A state tint on the sprite (white is none). Separate from the hit flash.
func set_tint(color: Color) -> void:
	_ensure_children()
	_sprite.self_modulate = color


## A material for the sprite and its outline (a shader that bobs a pickup, say). Null removes it.
func set_sprite_material(sprite_material: Material) -> void:
	_ensure_children()
	_sprite.material = sprite_material
	_outline.material = sprite_material


## Shows or hides the silhouette outline behind the sprite, in a colour. Nothing is shown when there is no sprite or
## no silhouette.
func set_outline(color: Color, enabled: bool) -> void:
	_ensure_children()
	_outline.self_modulate = color
	_outline.visible = enabled and _outline_set != null and _set_data != null
	set_process(_outline.visible)


## Keeps the sprite's pixels 1:1 whatever the owner's scale (the owner's scale sizes its hit shapes). The fallback
## square is left to scale with its owner, as it always did.
func counter_scale(parent_scale: Vector2) -> void:
	_ensure_children()
	var inverse := Vector2.ONE
	if absf(parent_scale.x) > 0.0001 and absf(parent_scale.y) > 0.0001:
		inverse = Vector2.ONE / parent_scale
	_sprite.scale = inverse
	_outline.scale = inverse


func _ensure_children() -> void:
	if _sprite != null:
		return
	_outline = AnimatedSprite2D.new()
	_outline.name = "Outline"
	_outline.visible = false
	add_child(_outline)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.visible = false
	_sprite.animation_finished.connect(func() -> void: animation_done.emit(_sprite.animation))
	add_child(_sprite)
	_fallback = ColorRect.new()
	_fallback.name = "Fallback"
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.offset_left = -FALLBACK_SIZE / 2.0
	_fallback.offset_top = -FALLBACK_SIZE / 2.0
	_fallback.offset_right = FALLBACK_SIZE / 2.0
	_fallback.offset_bottom = FALLBACK_SIZE / 2.0
	_fallback.color = fallback_color
	add_child(_fallback)
