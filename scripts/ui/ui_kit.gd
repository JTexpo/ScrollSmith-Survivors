class_name UiKit
extends RefCounted
## Small builders for themed controls, so no screen styles a label or button by hand. They set only what every use shares
## (the theme variation, how the control takes the mouse and focus); the look itself comes from the game theme.


## A full screen's cream page: 2 px in from the screen edge (the backdrop shows round it), and its content starts 2 px
## lower so text clears the page's outline.
const WINDOW_RECT := Rect2(2, 2, 476, 266)
const CONTENT_TOP := 2.0
const BACKDROP_COLOR := Color("6fd3ff")
const SCREEN_WIDTH := 480.0
## The smallest a main action button (Confirm, Cancel, Close) may be: a thumb has to hit it on a phone.
const ACTION_SIZE := Vector2(72, 28)

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


## The cream page every full screen sits on: a sky-blue backdrop that hides the world, a cream panel almost as big as the
## screen, and a content area inside it. Returns the content area. The backdrop and panel let touches through (the screen's
## own root decides who takes input).
static func window(parent: Control) -> Control:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backdrop)
	var page := Panel.new()
	page.name = "Window"
	page.position = WINDOW_RECT.position
	page.size = WINDOW_RECT.size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	var content := Control.new()
	content.name = "Content"
	content.position = Vector2(0.0, CONTENT_TOP)
	content.size = Vector2(480.0, 266.0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(content)
	return content


## Puts a control back where its middle is `center_x` (after a label has resized to fit new text), kept on the screen.
static func fit_centered(control: Control, center_x: float) -> void:
	control.position.x = clampf(center_x - control.size.x * 0.5, 0.0, maxf(SCREEN_WIDTH - control.size.x, 0.0))
