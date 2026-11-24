class_name ThemeBuilder
extends RefCounted
## Writes the game's one Godot theme (`resources/ui/game_theme.tres`) as text, like `ArtBuilder.set_text` writes a sprite set:
## `ResourceSaver` gives sub-resources random ids, so its output would never be the same twice. Every panel, button and bar
## is a `StyleBoxTexture` cut from a sliced UI sprite and drawn by tiling (never stretching), so a pixel keeps its size. The
## sprites are read from their `.sprite` sources (frame size and slice) and the sheet paths follow the art tool's naming, so the
## theme can be built before the sheets are imported. A style whose sprite or sheet is missing is left out, and a missing font
## leaves its line out, so the theme always loads. `project.godot` points `gui/theme/custom` at the result.

const THEME_PATH := "res://resources/ui/game_theme.tres"
const SPRITE_DIR := "res://art/sprites"
const SHEET_DIR := "res://assets/sprites"
const PALETTE_PATH := "res://art/palette.txt"

const PLUM := Color("3b2a5c")
const PLUM_LIGHT := Color("6b5a8c")
const CREAM := Color("fff6e8")
const WHITE := Color("ffffff")
const RED := Color("e0483c")
const YELLOW := Color("ffd24a")
const HEADING_BLUE := Color("2a5aa0")

## Text inside a button: left, top, right, bottom (the sprite's own 4 px slice is the outline, shade and corners).
const BUTTON_CONTENT := Vector4(4, 2, 4, 3)
const PANEL_CONTENT := Vector4(6, 6, 6, 6)
const SLOT_CONTENT := Vector4(2, 2, 2, 2)
## The fill of a bar sits inside the trough's 1 px outline.
const BAR_CONTENT := Vector4(1, 1, 1, 1)

## [type, style name, sprite, frame, content margins (Vector4(-1, ...) for none)]
const STYLES := [
	["Panel", "panel", "ui_panel", 0, PANEL_CONTENT],
	["PanelContainer", "panel", "ui_panel", 0, PANEL_CONTENT],
	["TooltipPanel", "panel", "ui_panel", 0, Vector4(4, 4, 4, 4)],
	["PanelDark", "panel", "ui_panel_dark", 0, PANEL_CONTENT],
	["HudToast", "normal", "ui_panel_dark", 0, Vector4(6, 3, 6, 3)],
	["PanelSlot", "panel", "ui_slot", 0, SLOT_CONTENT],
	["PanelSlotSelected", "panel", "ui_slot", 1, SLOT_CONTENT],
	["Button", "normal", "ui_button_cream", 0, BUTTON_CONTENT],
	["Button", "hover", "ui_button_cream", 1, BUTTON_CONTENT],
	["Button", "pressed", "ui_button_cream", 2, BUTTON_CONTENT],
	["Button", "disabled", "ui_button_cream", 3, BUTTON_CONTENT],
	["Button", "focus", "ui_focus", 0, BUTTON_CONTENT],
	["ButtonRed", "normal", "ui_button_red", 0, BUTTON_CONTENT],
	["ButtonRed", "hover", "ui_button_red", 1, BUTTON_CONTENT],
	["ButtonRed", "pressed", "ui_button_red", 2, BUTTON_CONTENT],
	["ButtonRed", "disabled", "ui_button_red", 3, BUTTON_CONTENT],
	["ButtonRed", "focus", "ui_focus", 0, BUTTON_CONTENT],
	["ButtonGreen", "normal", "ui_button_green", 0, BUTTON_CONTENT],
	["ButtonGreen", "hover", "ui_button_green", 1, BUTTON_CONTENT],
	["ButtonGreen", "pressed", "ui_button_green", 2, BUTTON_CONTENT],
	["ButtonGreen", "disabled", "ui_button_green", 3, BUTTON_CONTENT],
	["ButtonGreen", "focus", "ui_focus", 0, BUTTON_CONTENT],
	["ButtonYellow", "normal", "ui_button_yellow", 0, BUTTON_CONTENT],
	["ButtonYellow", "hover", "ui_button_yellow", 1, BUTTON_CONTENT],
	["ButtonYellow", "pressed", "ui_button_yellow", 2, BUTTON_CONTENT],
	["ButtonYellow", "disabled", "ui_button_yellow", 3, BUTTON_CONTENT],
	["ButtonYellow", "focus", "ui_focus", 0, BUTTON_CONTENT],
	["ProgressBar", "background", "ui_bar_back", 0, BAR_CONTENT],
	["ProgressBar", "fill", "ui_bar_hp", 0, Vector4(-1, -1, -1, -1)],
	["BarHp", "background", "ui_bar_back", 0, BAR_CONTENT],
	["BarHp", "fill", "ui_bar_hp", 0, Vector4(-1, -1, -1, -1)],
	["BarXp", "background", "ui_bar_back_thin", 0, BAR_CONTENT],
	["BarXp", "fill", "ui_bar_xp", 0, Vector4(-1, -1, -1, -1)],
	["BarBoss", "background", "ui_bar_back", 0, BAR_CONTENT],
	["BarBoss", "fill", "ui_bar_boss", 0, Vector4(-1, -1, -1, -1)],
]

## Variation name to its base type.
const VARIATIONS := {
	"PanelDark": "Panel", "PanelSlot": "Panel", "PanelSlotSelected": "Panel",
	"ButtonRed": "Button", "ButtonGreen": "Button", "ButtonYellow": "Button",
	"HudLabel": "Label", "HudToast": "Label", "HudGold": "Label", "Heading": "Label", "Muted": "Label", "Warning": "Label",
	"BarHp": "ProgressBar", "BarXp": "ProgressBar", "BarBoss": "ProgressBar",
}

## [type, colour name, colour]
const COLORS := [
	["Label", "font_color", PLUM],
	["HudLabel", "font_color", WHITE],
	["HudToast", "font_color", CREAM],
	["HudGold", "font_color", YELLOW],
	["Heading", "font_color", HEADING_BLUE],
	["Muted", "font_color", PLUM_LIGHT],
	["Warning", "font_color", RED],
	["Button", "font_color", PLUM],
	["Button", "font_hover_color", PLUM],
	["Button", "font_pressed_color", PLUM],
	["Button", "font_focus_color", PLUM],
	["Button", "font_disabled_color", PLUM_LIGHT],
	["ButtonRed", "font_color", CREAM],
	["ButtonRed", "font_hover_color", WHITE],
	["ButtonRed", "font_pressed_color", CREAM],
	["ButtonRed", "font_focus_color", CREAM],
	["ButtonRed", "font_disabled_color", PLUM_LIGHT],
	["ButtonGreen", "font_color", CREAM],
	["ButtonGreen", "font_hover_color", WHITE],
	["ButtonGreen", "font_pressed_color", CREAM],
	["ButtonGreen", "font_focus_color", CREAM],
	["ButtonGreen", "font_disabled_color", PLUM_LIGHT],
	["ButtonYellow", "font_color", PLUM],
	["ButtonYellow", "font_hover_color", PLUM],
	["ButtonYellow", "font_pressed_color", PLUM],
	["ButtonYellow", "font_focus_color", PLUM],
	["ButtonYellow", "font_disabled_color", PLUM_LIGHT],
]


## The theme file's text. `sprite_dir` holds the `.sprite` sources and `sheet_dir` the built sheets.
static func theme_text(sprite_dir: String = SPRITE_DIR, sheet_dir: String = SHEET_DIR) -> String:
	var palette := ArtPalette.parse(FileAccess.get_file_as_string(PALETTE_PATH))
	var externals: Array[Array] = []
	var blocks := PackedStringArray()
	var props: Array[String] = []
	var count := 0
	for spec in STYLES:
		var sprite := _sprite(String(spec[2]), sprite_dir, sheet_dir, palette)
		if sprite.is_empty():
			continue
		count += 1
		var id := "style_%d" % count
		var slice: Vector4i = sprite["slice"]
		var frame: Vector2i = sprite["frame"]
		var content: Vector4 = spec[4]
		var lines := PackedStringArray(["[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % id])
		if content.x >= 0.0:
			lines.append("content_margin_left = %s" % _float(content.x))
			lines.append("content_margin_top = %s" % _float(content.y))
			lines.append("content_margin_right = %s" % _float(content.z))
			lines.append("content_margin_bottom = %s" % _float(content.w))
		lines.append("texture = ExtResource(\"%s\")" % _external(externals, "Texture2D", sprite["sheet"]))
		lines.append("texture_margin_left = %s" % _float(slice.x))
		lines.append("texture_margin_top = %s" % _float(slice.y))
		lines.append("texture_margin_right = %s" % _float(slice.z))
		lines.append("texture_margin_bottom = %s" % _float(slice.w))
		lines.append("axis_stretch_horizontal = %d" % StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
		lines.append("axis_stretch_vertical = %d" % StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
		lines.append("region_rect = Rect2(%d, 0, %d, %d)" % [int(spec[3]) * frame.x, frame.x, frame.y])
		blocks.append("\n".join(lines) + "\n")
		props.append("%s/styles/%s = SubResource(\"%s\")" % [spec[0], spec[1], id])
	props.append("Label/constants/line_spacing = 0")
	for variation in VARIATIONS:
		props.append("%s/base_type = &\"%s\"" % [variation, VARIATIONS[variation]])
	for entry in COLORS:
		props.append("%s/colors/%s = %s" % [entry[0], entry[1], var_to_str(entry[2])])
	if FileAccess.file_exists(UiFont.plain_path):
		props.append("default_font = ExtResource(\"%s\")" % _external(externals, "FontFile", UiFont.plain_path))
		props.append("default_font_size = %d" % UiFont.SIZE)
	if FileAccess.file_exists(UiFont.outlined_path):
		for variation in ["HudLabel", "HudToast", "HudGold"]:
			props.append("%s/fonts/font = ExtResource(\"%s\")" % [variation, _external(externals, "FontFile", UiFont.outlined_path)])
	props.sort()
	var out := PackedStringArray(["[gd_resource type=\"Theme\" format=3]", ""])
	for external in externals:
		out.append("[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % [external[0], external[1], external[2]])
	out.append("")
	for block in blocks:
		out.append(block)
	out.append("[resource]")
	out.append_array(props)
	return "\n".join(out) + "\n"


## Writes the theme to `THEME_PATH`. Returns the problems found (empty when all is well).
static func write(sprite_dir: String = SPRITE_DIR, sheet_dir: String = SHEET_DIR) -> PackedStringArray:
	var handle := FileAccess.open(THEME_PATH, FileAccess.WRITE)
	if handle == null:
		return PackedStringArray(["cannot write %s" % THEME_PATH])
	handle.store_string(theme_text(sprite_dir, sheet_dir))
	handle.close()
	return PackedStringArray()


## {"sheet": png path, "frame": Vector2i, "slice": Vector4i}, or empty when the source or its sheet is missing or bad.
static func _sprite(sprite_name: String, sprite_dir: String, sheet_dir: String, palette: ArtPalette) -> Dictionary:
	var source_path := "%s/%s.sprite" % [sprite_dir, sprite_name]
	var sheet := "%s/%s_base.png" % [sheet_dir, sprite_name]
	if not FileAccess.file_exists(source_path) or not FileAccess.file_exists(sheet):
		return {}
	var source := SpriteSource.parse(FileAccess.get_file_as_string(source_path), palette)
	if not source.errors.is_empty():
		return {}
	return {"sheet": sheet, "frame": source.frame_size, "slice": source.slice}


static func _external(externals: Array[Array], type: String, path: String) -> String:
	for external in externals:
		if external[1] == path:
			return external[2]
	var id := str(externals.size() + 1)
	externals.append([type, path, id])
	return id


static func _float(value: float) -> String:
	return "%.1f" % value
