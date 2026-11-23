class_name EffectSprite
extends AnimatedSprite2D
## One effect sprite of an area spell: hidden for a delay, then its `play` animation once, then it fades and frees itself.
## It is drawn upright and 1:1 whatever its parent does (it ignores the parent's rotation and scale, because a pixel is
## never scaled), it is placed in world pixels and it outlives the area that spawned it. At most MAX_LIVE exist: a new
## one frees the oldest.

const MAX_LIVE := 160

## The sprite sets found so far, by folder and name, so a hundred sprites share one set and one `SpriteFrames` instead of
## each loading and building its own (the library's resource cache lets go of a set nobody holds).
static var _sets: Dictionary = {}

var _delay: float = 0.0
var _wait_left: float = 0.0
var _fade_time: float = 0.1
var _fade_left: float = -1.0


## A sprite of `sprite_name` standing on the world point `at`, or null when there is no such art. `delay` is how long it
## waits, `fade_time` how long it fades once its animation has played.
static func spawn(parent: Node, sprite_name: StringName, at: Vector2, delay: float, fade_time: float) -> EffectSprite:
	var found := _find(sprite_name)
	if found == null or parent == null or not parent.is_inside_tree():
		return null
	var live := parent.get_tree().get_nodes_in_group(&"effect_sprites").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	while live.size() >= MAX_LIVE:
		live.pop_front().queue_free()
	var sprite := EffectSprite.new()
	sprite.sprite_frames = found.frames()
	sprite.animation = &"play"
	sprite._delay = delay
	sprite._wait_left = delay
	sprite._fade_time = maxf(fade_time, 0.001)
	sprite.top_level = true
	parent.add_child(sprite)
	# Its base sits on the spot, with a few pixels of ground under it, on whole pixels.
	sprite.global_position = (at - Vector2(0.0, found.frame_size.y / 2.0 - 2.0)).round()
	return sprite


static func _find(sprite_name: StringName) -> SpriteSetData:
	var key := "%s|%s" % [SpriteLibrary.root, sprite_name]
	if not _sets.has(key):
		var found := SpriteLibrary.find(sprite_name)
		if found == null:
			return null
		_sets[key] = found
	return _sets[key]


func _ready() -> void:
	add_to_group(&"effect_sprites")
	animation_finished.connect(_on_animation_finished)
	if _wait_left > 0.0:
		visible = false
		stop()
	else:
		play(&"play")


## How long it was told to wait before playing.
func start_delay() -> float:
	return _delay


func _process(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
		if _wait_left <= 0.0:
			visible = true
			play(&"play")
		return
	if _fade_left >= 0.0:
		_fade_left -= delta
		modulate.a = clampf(_fade_left / _fade_time, 0.0, 1.0)
		if _fade_left <= 0.0:
			queue_free()


func _on_animation_finished() -> void:
	_fade_left = _fade_time
