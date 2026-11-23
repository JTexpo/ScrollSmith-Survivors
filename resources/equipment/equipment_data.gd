class_name EquipmentData
extends Resource
## One piece of equipment. Hats and Hoods behave the same and differ only in name and colour. Wands
## and Staffs share the Weapon slot, so only one of them is worn at a time.

enum Category { ROBE, WAND, STAFF, HAT, HOOD }
enum Slot { ROBE, WEAPON, HEADWEAR }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.ROBE
@export var price: int = 0
@export var modifiers: Array[EquipmentModifier] = []
## Placeholder colour, standing in for the icon.
@export var color: Color = Color.WHITE
## The sprite the wizard wears (`robe_wizard`, `hat_pointed`, `wand_short` ...) and its colourway (a palette variant). Empty means
## the slot's starter look (a robe and a hat) or nothing (a weapon).
@export var sprite_name: StringName = &""
@export var sprite_variant: StringName = &""


func slot() -> Slot:
	match category:
		Category.WAND, Category.STAFF:
			return Slot.WEAPON
		Category.HAT, Category.HOOD:
			return Slot.HEADWEAR
	return Slot.ROBE
