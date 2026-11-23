class_name ShopSystem
extends RefCounted
## The shop's rules, in one place with no screen: buy, equip, unequip and the bonuses of what is
## worn. A failed action changes nothing, so the player never loses Gold or an item to a refusal.

const REASON_UNKNOWN := "That item is not for sale."
const REASON_OWNED := "You already own that."
const REASON_BROKE := "Not enough Gold."
const REASON_NOT_OWNED := "You don't own that."
const REASON_FULL := "You can't carry any more."


## Spends the Gold, grants the item and equips it into its slot (the item it replaces stays owned).
## All or nothing.
static func buy(profile: PlayerProfile, catalog: EquipmentCatalog, id: StringName) -> ShopResult:
	var result := ShopResult.new()
	var item := catalog.find(id)
	if item == null:
		result.reason = REASON_UNKNOWN
	elif profile.owns(id):
		result.reason = REASON_OWNED
	elif not can_afford(profile, item):
		result.reason = REASON_BROKE
	else:
		if item.price > 0:
			profile.spend_gold(item.price)
		profile.grant(id)
		profile.equip(int(item.slot()), id)
		result.ok = true
		result.item = item
	return result


## What a potion costs at a price multiplier (a merchant charges extra): rounded up, never free when it has a price.
static func potion_price(potion: PotionData, price_multiplier: float = 1.0) -> int:
	if potion.price <= 0:
		return 0
	return maxi(ceili(potion.price * price_multiplier), 1)


## Buys one potion. Nothing changes on any failure (unknown id, too little Gold, already at the limit).
static func buy_potion(profile: PlayerProfile, catalog: PotionCatalog, id: StringName, price_multiplier: float = 1.0) -> ShopResult:
	var result := ShopResult.new()
	var potion := catalog.find(id)
	if potion == null:
		result.reason = REASON_UNKNOWN
	elif not can_afford_potion(profile, potion, price_multiplier):
		result.reason = REASON_BROKE
	elif profile.potion_count(id) >= PlayerProfile.MAX_POTIONS:
		result.reason = REASON_FULL
	else:
		profile.spend_gold(potion_price(potion, price_multiplier))
		profile.add_potion(id)
		result.ok = true
		result.potion = potion
	return result


static func can_afford_potion(profile: PlayerProfile, potion: PotionData, price_multiplier: float = 1.0) -> bool:
	return profile.gold >= potion_price(potion, price_multiplier)


## Puts an owned item on, for free.
static func equip(profile: PlayerProfile, catalog: EquipmentCatalog, id: StringName) -> ShopResult:
	var result := ShopResult.new()
	var item := catalog.find(id)
	if item == null:
		result.reason = REASON_UNKNOWN
	elif not profile.owns(id):
		result.reason = REASON_NOT_OWNED
	else:
		profile.equip(int(item.slot()), id)
		result.ok = true
		result.item = item
	return result


## Takes off what is in a slot (it stays owned). False if the slot was empty.
static func unequip(profile: PlayerProfile, slot: int) -> bool:
	if profile.equipped_id(slot) == &"":
		return false
	profile.unequip(slot)
	return true


## The sum of every equipped item's modifiers. Skips ids that are unknown, not owned, or sitting in a
## slot they do not belong to (a hand-edited save), so a bad file can never grant a bonus.
static func bonuses(profile: PlayerProfile, catalog: EquipmentCatalog) -> StatBonuses:
	var total := StatBonuses.new()
	for slot in profile.equipped:
		var item := catalog.find(profile.equipped[slot])
		if item == null or not profile.owns(item.id) or int(item.slot()) != int(slot):
			continue
		for modifier in item.modifiers:
			total.add(modifier.stat, modifier.amount)
	return total


static func can_afford(profile: PlayerProfile, item: EquipmentData) -> bool:
	return profile.gold >= item.price
