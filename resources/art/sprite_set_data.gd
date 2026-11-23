class_name SpriteSetData
extends Resource
## One sprite sheet and its animations: frames side by side, left to right, each `frame_size` big. The art tool
## writes these next to the sheets (`assets/sprites/<name>_<variant>.tres`), so replacing a sheet's PNG replaces the art
## and the animation data stays as it is.

@export var sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(16, 16)
@export var animations: Array[SpriteAnimationData] = []
## A repeating floor or wall tile: one full-bleed frame the world draws tiled.
@export var tile: bool = false
## A wall's 9-slice margins in pixels (left, top, right, bottom), zero when it has none.
@export var slice: Vector4i = Vector4i.ZERO

var _frames: SpriteFrames


func frame_count() -> int:
	if sheet == null or frame_size.x <= 0:
		return 0
	@warning_ignore("integer_division")
	return sheet.get_width() / frame_size.x


func has_animation(animation: StringName) -> bool:
	for candidate in animations:
		if candidate.name == animation:
			return true
	return false


## The Godot `SpriteFrames` for these animations, built once from regions of the sheet.
func frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	for animation in animations:
		_frames.add_animation(animation.name)
		_frames.set_animation_speed(animation.name, animation.fps)
		_frames.set_animation_loop(animation.name, animation.loop)
		for index in range(animation.first_frame, animation.last_frame + 1):
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
			_frames.add_frame(animation.name, region)
	return _frames
