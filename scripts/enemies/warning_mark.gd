class_name WarningMark
extends RefCounted
## The bold diamond that marks a warning on the ground (a blast zone's rings, the boss's charge line). One upright 1:1
## sprite on a world point, dim or bright. Null without art, which is how a caller knows to draw its old shapes.

const SPRITE := &"fx_warning_mark"
## The depth every enemy attack is drawn at (a shot, a blast zone, its warning marks and its burst): above the player's effect
## sprites (depth 0), so a spell played over an enemy attack never hides it, and above the pickups (1 and 2).
const ATTACK_Z := 3

static var _set_cache: Dictionary = {}


## A mark on the world point `at`, a top-level child of `parent` (so a scaled or rotated parent never touches it).
static func make(parent: Node2D, at: Vector2, bright: bool) -> Sprite2D:
	var found := _find()
	if found == null:
		return null
	var mark := Sprite2D.new()
	mark.texture = found.sheet
	mark.region_enabled = true
	mark.top_level = true
	mark.z_as_relative = false
	mark.z_index = ATTACK_Z
	parent.add_child(mark)
	mark.global_position = at.round()
	set_bright(mark, bright)
	return mark


static func set_bright(mark: Sprite2D, bright: bool) -> void:
	var found := _find()
	if found == null:
		return
	var size := Vector2(found.frame_size)
	mark.region_rect = Rect2(Vector2(size.x * (1 if bright else 0), 0.0), size)


static func _find() -> SpriteSetData:
	var key := "%s|%s" % [SpriteLibrary.root, SPRITE]
	if not _set_cache.has(key):
		var found := SpriteLibrary.find(SPRITE)
		if found == null:
			return null
		_set_cache[key] = found
	return _set_cache[key]
