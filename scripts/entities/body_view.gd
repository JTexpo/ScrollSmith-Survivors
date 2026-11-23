class_name BodyView
extends Node2D
## What an entity looks like: a sprite from the art pipeline that plays animations, flips by facing, can be tinted and
## outlined, with the old coloured square as a fallback when there is no art. It replaces the `Body` colour rectangle.
## The hit flash sets this node's `modulate` and a state tint is the sprite's `self_modulate`, so the two multiply and
## never fight. It builds its own children, so a scene only needs a `Node2D` with this script.

signal animation_done(animation: StringName)

const FALLBACK_SIZE := 12.0
## The widths of the shadow sprites (`shadow_<width>`), and how see-through a shadow is.
const SHADOW_WIDTHS: Array[int] = [8, 12, 16, 24, 32]
const SHADOW_ALPHA := 0.4
## The one depth every shadow is drawn at, whatever its owner's depth. Sprites are at 0 and `GameMap` puts the floor layers
## below this, so all the shadows come together in the draw order and batch (a shadow between every pair of sprites
## halved the frame rate at 300 enemies).
const SHADOW_Z := -1

## The colour of the fallback square (what `Body.color` used to be).
var fallback_color: Color = Color(0.9, 0.25, 0.25):
	set(value):
		fallback_color = value
		if _fallback != null:
			_fallback.color = value

## Whether this body draws a soft oval shadow on the ground under its sprite. Things that move, can be picked up or can
## be used have one and static things (walls, trees, decorations) do not, so a player can tell them apart.
@export var shadow_enabled: bool = false:
	set(value):
		shadow_enabled = value
		if _sprite != null:
			_refresh_shadow()

var _set_data: SpriteSetData
var _shadow: Sprite2D
var _shadow_y: float = 0.0
var _shadow_width: int = 0
var _outline_set: SpriteSetData
var _outline: AnimatedSprite2D
var _sprite: AnimatedSprite2D
var _fallback: ColorRect
var _facing: float = 1.0
var _jitter: Vector2 = Vector2.ZERO
var _jitter_base: Vector2 = Vector2.ZERO
## Layers drawn over the body sprite (a worn robe, headwear, a weapon), by name, in the order they were added. Each copies the
## body's animation, frame and flip every frame, and runs nothing while it is hidden.
var _layers: Dictionary = {}


func _ready() -> void:
	_ensure_children()
	# Only a shown outline or layer needs to follow the sprite's frame, so 300 plain enemies run no script each frame.
	_refresh_processing()


func _process(_delta: float) -> void:
	_sync_followers()


## The outline and every layer copy the sprite's animation and frame. This runs the moment the sprite's frame or animation changes
## (its signals), because the sprite advances after this node's own `_process`, so syncing only there lagged a frame behind and a
## worn hat jumped off the head for a moment on every step. `_process` stays for the flip and for anything that changed no frame.
func _sync_followers() -> void:
	# The outline copies the sprite's frame, so it is always the same pose, a pixel bigger.
	if _outline.visible and _sprite.animation != &"" and _outline.sprite_frames != null and _outline.sprite_frames.has_animation(_sprite.animation):
		_outline.animation = _sprite.animation
		_outline.frame = _sprite.frame
	_sync_layers()


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
		_fallback.visible = true
		_refresh_shadow()
		_refresh_processing()
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
	_refresh_shadow()


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
	for layer in _layers.values():
		layer.flip_h = _facing < 0.0


## Moves the whole body (the sprite, its layers, its outline and its shadow) by a whole-pixel offset, for a hurt jitter. Zero restores it.
func set_jitter(offset: Vector2) -> void:
	if _jitter == Vector2.ZERO and offset != Vector2.ZERO:
		_jitter_base = position
	_jitter = offset.round()
	position = _jitter_base + _jitter


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
	_refresh_processing()


## Keeps the sprite's pixels 1:1 whatever the owner's scale (the owner's scale sizes its hit shapes). The fallback
## square is left to scale with its owner, as it always did.
func counter_scale(parent_scale: Vector2) -> void:
	_ensure_children()
	var inverse := Vector2.ONE
	if absf(parent_scale.x) > 0.0001 and absf(parent_scale.y) > 0.0001:
		inverse = Vector2.ONE / parent_scale
	_sprite.scale = inverse
	_outline.scale = inverse
	for layer in _layers.values():
		layer.scale = inverse
	_shadow.scale = inverse
	_shadow.position = Vector2(0.0, _shadow_y) * inverse


## Adds an empty layer drawn above the body and above the layers added before it. Adding one twice changes nothing.
func add_layer(layer_name: StringName) -> void:
	_ensure_children()
	if _layers.has(layer_name):
		return
	var layer := AnimatedSprite2D.new()
	layer.name = "Layer_%s" % layer_name
	layer.visible = false
	add_child(layer)
	_layers[layer_name] = layer


## Shows `sprite_name` in a variant on a layer (added if it was never added). False and the layer hidden when there is no art.
func set_layer(layer_name: StringName, sprite_name: StringName, variant: StringName = &"base") -> bool:
	add_layer(layer_name)
	var layer := _layers[layer_name] as AnimatedSprite2D
	var found := SpriteLibrary.find(sprite_name, variant)
	if found == null:
		layer.visible = false
		_refresh_processing()
		return false
	layer.sprite_frames = found.frames()
	layer.visible = true
	layer.flip_h = _facing < 0.0
	_sync_layers()
	_refresh_processing()
	return true


func clear_layer(layer_name: StringName) -> void:
	if _layers.has(layer_name):
		(_layers[layer_name] as AnimatedSprite2D).visible = false
		_refresh_processing()


## The layers' names, in the order they were added (the order they are drawn).
func layer_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for layer_name in _layers:
		names.append(layer_name)
	return names


## Processing is only on while an outline or a layer is shown.
func _refresh_processing() -> void:
	var needed := _outline != null and _outline.visible
	for layer in _layers.values():
		if layer.visible:
			needed = true
	set_process(needed)


## Every shown layer takes the body's animation, frame and flip.
func _sync_layers() -> void:
	for layer in _layers.values():
		if not layer.visible or layer.sprite_frames == null:
			continue
		if _sprite.animation != &"" and layer.sprite_frames.has_animation(_sprite.animation):
			if layer.animation != _sprite.animation:
				layer.animation = _sprite.animation
			layer.frame = _sprite.frame
		layer.flip_h = _sprite.flip_h


## The content width of the shadow in use (0 when there is none).
func shadow_width() -> int:
	return _shadow_width if _shadow != null and _shadow.visible else 0


## Shows the biggest shadow no wider than the sprite, at its feet, or hides it. Only with art and `shadow_enabled`.
func _refresh_shadow() -> void:
	_ensure_children()
	_shadow.visible = false
	_shadow_width = 0
	if not shadow_enabled or _set_data == null:
		return
	var width := SHADOW_WIDTHS[0]
	for candidate in SHADOW_WIDTHS:
		if candidate <= _set_data.frame_size.x:
			width = candidate
	var shadow_set := SpriteLibrary.find(StringName("shadow_%d" % width))
	if shadow_set == null:
		return
	_shadow.texture = shadow_set.sheet
	_shadow_width = width
	# At the feet, in world pixels: the sprite is drawn 1:1, so its feet are half its height below the middle.
	_shadow_y = floorf(_set_data.frame_size.y / 2.0) - 1.0
	_shadow.position = Vector2(0.0, _shadow_y) * _shadow.scale
	_shadow.visible = true


func _ensure_children() -> void:
	if _sprite != null:
		return
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.visible = false
	_shadow.modulate = Color(1.0, 1.0, 1.0, SHADOW_ALPHA)
	_shadow.z_as_relative = false
	_shadow.z_index = SHADOW_Z
	add_child(_shadow)
	_outline = AnimatedSprite2D.new()
	_outline.name = "Outline"
	_outline.visible = false
	add_child(_outline)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.visible = false
	_sprite.animation_finished.connect(func() -> void: animation_done.emit(_sprite.animation))
	_sprite.frame_changed.connect(_sync_followers)
	_sprite.animation_changed.connect(_sync_followers)
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
