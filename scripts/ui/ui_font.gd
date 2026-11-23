class_name UiFont
extends RefCounted
## The game's pixel font. `plain()` is white ink for text inside panels (tinted by the theme), `outlined()` has a baked dark
## outline for text over the world. Both are imported BMFonts with identical metrics, drawn at the one fixed `SIZE` (the
## line height) so a pixel is never scaled. A missing file falls back to the engine font, so a label still shows.

const SIZE := 10

## Where the fonts live. Tests point these at a missing file.
static var plain_path: String = "res://assets/fonts/ui_plain.fnt"
static var outlined_path: String = "res://assets/fonts/ui_outlined.fnt"


static func plain() -> Font:
	return _find(plain_path)


static func outlined() -> Font:
	return _find(outlined_path)


static func _find(font_path: String) -> Font:
	if ResourceLoader.exists(font_path):
		var font := load(font_path) as Font
		if font != null:
			return font
	return ThemeDB.fallback_font
