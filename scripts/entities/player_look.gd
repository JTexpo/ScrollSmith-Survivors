class_name PlayerLook
extends RefCounted
## Dresses the wizard: the layers `robe`, `beard`, `headwear` and `weapon` on the player's `BodyView`, from what the profile has
## equipped (the same ownership and slot rules as `ShopSystem.bonuses`). With nothing equipped in a slot the robe and the
## headwear show the starter look and the weapon shows nothing. The white beard is part of the wizard, not an item: it is always
## worn, over the robe and under the headwear, and with the shadow of the hat it hides every bit of skin.
## It holds no state, so applying it twice gives the same result.

## The layers in draw order: the layer, the equipment slot it shows, and the starter sprite for it (none for a weapon).
const LAYERS := [
	[&"robe", EquipmentData.Slot.ROBE, &"robe_starter"],
	[&"beard", -1, &"beard_white"],
	[&"headwear", EquipmentData.Slot.HEADWEAR, &"hat_starter"],
	[&"weapon", EquipmentData.Slot.WEAPON, &""],
]


static func apply(body: BodyView, profile: PlayerProfile = null, catalog: EquipmentCatalog = null) -> void:
	for entry in LAYERS:
		var layer: StringName = entry[0]
		var starter: StringName = entry[2]
		body.add_layer(layer)
		var item := _equipped(profile, catalog, entry[1])
		if item != null and item.sprite_name != &"" and body.set_layer(layer, item.sprite_name, item.sprite_variant if item.sprite_variant != &"" else &"base"):
			continue
		if starter != &"":
			body.set_layer(layer, starter)
		else:
			body.clear_layer(layer)


## The item worn in a slot, or null (unknown, not owned or in the wrong slot are ignored, as the bonuses do).
static func _equipped(profile: PlayerProfile, catalog: EquipmentCatalog, slot: int) -> EquipmentData:
	if profile == null or catalog == null:
		return null
	for key in profile.equipped:
		var item := catalog.find(profile.equipped[key])
		if item != null and profile.owns(item.id) and int(item.slot()) == int(key) and int(key) == slot:
			return item
	return null
