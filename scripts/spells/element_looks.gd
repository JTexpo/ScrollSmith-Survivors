class_name ElementLooks
extends RefCounted
## Finds the `ElementLook` of an element (`SpellData.Element`). Null for no element or an unknown value, which is how a
## caller knows to keep the flat look.

const PATHS := {
	SpellData.Element.FIRE: "res://resources/spells/element_looks/fire.tres",
	SpellData.Element.THUNDER: "res://resources/spells/element_looks/thunder.tres",
	SpellData.Element.LAND: "res://resources/spells/element_looks/land.tres",
	SpellData.Element.SEA: "res://resources/spells/element_looks/sea.tres",
}

static var _cache: Dictionary = {}


## The id an enemy's element carries (`fire`, `thunder`, `land`, `sea`), and `none` for no element or an unknown value.
static func id_of(element: int) -> StringName:
	match element:
		SpellData.Element.FIRE:
			return &"fire"
		SpellData.Element.THUNDER:
			return &"thunder"
		SpellData.Element.LAND:
			return &"land"
		SpellData.Element.SEA:
			return &"sea"
	return &"none"


static func for_element(element: int) -> ElementLook:
	if not PATHS.has(element):
		return null
	if not _cache.has(element):
		_cache[element] = load(PATHS[element]) as ElementLook
	return _cache[element]
