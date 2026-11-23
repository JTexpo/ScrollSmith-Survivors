class_name ArtPalette
extends RefCounted
## The game's one palette, read from `art/palette.txt`. `color <letter> <hex>` lines are fixed colours. `variant <id> <hex1>
## .. <hex5>` lines give the colours of ramp slots 1 to 5 for one element (none, fire, thunder, land, sea), so a single
## sprite grid yields every element. `#` starts a comment. Mistakes are collected in `errors`, never thrown.

const TRANSPARENT_LETTER := "."
## Ramp slots: 1 to 3 are the body (dark, mid, light), 4 and 5 are the trim (dark, light).
const RAMP_LETTERS := "12345"

var errors := PackedStringArray()
## Fixed colours: letter to Color.
var colors: Dictionary = {}
## Variant id (StringName) to an Array of the five ramp Colors.
var variants: Dictionary = {}


static func parse(text: String) -> ArtPalette:
	var palette := ArtPalette.new()
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.replace("\t", " ").split(" ", false)
		match parts[0]:
			"color":
				palette._add_color(number, parts)
			"variant":
				palette._add_variant(number, parts)
			_:
				palette.errors.append("line %d: unknown directive '%s'" % [number, parts[0]])
	return palette


## The pixel colour for a grid letter in a variant: a ramp slot takes the variant's colour, a dot is transparent.
func color_for(letter: String, variant: StringName) -> Color:
	if letter == TRANSPARENT_LETTER:
		return Color(0, 0, 0, 0)
	var slot := RAMP_LETTERS.find(letter)
	if slot >= 0:
		if variants.has(variant):
			return (variants[variant] as Array)[slot]
		return Color.MAGENTA
	return colors.get(letter, Color.MAGENTA)


func has_letter(letter: String) -> bool:
	return letter == TRANSPARENT_LETTER or RAMP_LETTERS.contains(letter) or colors.has(letter)


## Every different colour in the palette: the fixed ones and every variant's.
func distinct_color_count() -> int:
	var seen := {}
	for letter in colors:
		seen[(colors[letter] as Color).to_html(true)] = true
	for id in variants:
		for color in variants[id]:
			seen[(color as Color).to_html(true)] = true
	return seen.size()


func _add_color(number: int, parts: PackedStringArray) -> void:
	if parts.size() != 3:
		errors.append("line %d: expected 'color <letter> <hex>'" % number)
		return
	var letter := parts[1]
	if letter.length() != 1:
		errors.append("line %d: the letter '%s' must be one character" % [number, letter])
	elif letter == TRANSPARENT_LETTER or RAMP_LETTERS.contains(letter):
		errors.append("line %d: the letter '%s' is reserved" % [number, letter])
	elif colors.has(letter):
		errors.append("line %d: the letter '%s' is already defined" % [number, letter])
	elif not Color.html_is_valid(parts[2]):
		errors.append("line %d: '%s' is not a colour" % [number, parts[2]])
	else:
		colors[letter] = Color.html(parts[2])


func _add_variant(number: int, parts: PackedStringArray) -> void:
	if parts.size() != 7:
		errors.append("line %d: a variant needs an id and exactly 5 colours" % number)
		return
	var id := StringName(parts[1])
	if variants.has(id):
		errors.append("line %d: the variant '%s' is already defined" % [number, id])
		return
	var ramp: Array[Color] = []
	for i in range(2, 7):
		if not Color.html_is_valid(parts[i]):
			errors.append("line %d: '%s' is not a colour" % [number, parts[i]])
			return
		ramp.append(Color.html(parts[i]))
	variants[id] = ramp
