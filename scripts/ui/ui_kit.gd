class_name UiKit
extends RefCounted
## Small builders for themed controls, so no screen styles a label or button by hand. They set only what every use shares
## (the theme variation, how the control takes the mouse and focus); the look itself comes from the game theme.


## A label that lets touches and clicks through. `variation` is a theme type variation such as `HudGold`.
static func label(text: String, variation: StringName = &"") -> Label:
	var made := Label.new()
	made.text = text
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != &"":
		made.theme_type_variation = variation
	return made


## A button that takes focus (keyboard and controller) and the mouse.
static func button(text: String, variation: StringName = &"") -> Button:
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_ALL
	if variation != &"":
		made.theme_type_variation = variation
	return made


## A bar from the theme (`BarHp`, `BarXp`, `BarBoss`) that takes a ratio from 0 to 1 and no clicks.
static func bar(variation: StringName) -> ProgressBar:
	var made := ProgressBar.new()
	made.theme_type_variation = variation
	made.show_percentage = false
	made.min_value = 0.0
	made.max_value = 1.0
	made.step = 0.0
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A one-frame icon sprite shown 1:1. With no art the rect is empty, so a missing sprite never crashes or hides the HUD.
static func icon(sprite_name: StringName) -> TextureRect:
	var made := TextureRect.new()
	var set_data := SpriteLibrary.find(sprite_name)
	if set_data != null:
		made.texture = set_data.sheet
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.stretch_mode = TextureRect.STRETCH_KEEP
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made
