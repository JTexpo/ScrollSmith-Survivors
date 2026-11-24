class_name PlayerProfile
extends RefCounted
## What persists between runs: total XP (the level is computed from it, so the two can never
## disagree), Gold, the equipment the player owns and what is equipped in each slot. A `buff_picks`
## field in an old save is ignored.

## The largest XP or Gold a save accepts (2^53, the last whole number a JSON float holds exactly).
const MAX_VALUE := 9007199254740992
const SLOT_COUNT := 3
## The map an old save's flat bests belong to (the only map there was).
const OLD_BESTS_MAP := &"first_map"
## The most of one potion an old save could hold (a count above it is a bad save).
const LEGACY_MAX_POTIONS := 99

var total_xp: int = 0
var gold: int = 0
## The player turned the sound off (the mute button or the M key). Saved so a phone player does not mute again every launch.
var muted: bool = false
var owned: Array[StringName] = []
## Slot (int, 0 to SLOT_COUNT - 1) to equipment id (StringName).
var equipped: Dictionary = {}
## Potions an OLD save held between runs (id to count). Potions last one run now (`RunPotions`), so `Main` cashes these in for Gold once
## (`ShopSystem.cash_in_legacy_potions`). Never written back.
var legacy_potions: Dictionary = {}
## The player's records per map (Sprint 16a): map id (String) to `{"seconds": int, "enemies": int}`, the longest survival in whole seconds
## and the most enemies defeated in one run on that map. Saved only when any is above 0, so an old save and an old reader are unaffected.
## An old save's flat bests (Sprint 15b, with a level) load as the ruins' (`first_map`) records and the level is dropped.
var bests: Dictionary = {}


## Null if a field is missing (version and total_xp), has a wrongly typed or out-of-range value, or
## the file is from another save version. Optional fields (gold, owned, equipped) default when absent.
static func from_dict(data: Dictionary) -> PlayerProfile:
	if not _is_whole_in_range(data.get("version")) or int(data["version"]) != SaveGame.VERSION:
		return null
	if not _is_whole_in_range(data.get("total_xp")):
		return null
	var profile := PlayerProfile.new()
	profile.total_xp = int(data["total_xp"])
	if data.has("gold"):
		if not _is_whole_in_range(data["gold"]):
			return null
		profile.gold = int(data["gold"])
	if data.get("muted") is bool:
		profile.muted = data["muted"]
	if data.has("owned"):
		if not data["owned"] is Array:
			return null
		for id in data["owned"]:
			if not id is String:
				return null
			profile.grant(StringName(id))
	if data.has("equipped"):
		if not data["equipped"] is Dictionary:
			return null
		for key in data["equipped"]:
			if not key is String or not key.is_valid_int() or not data["equipped"][key] is String:
				return null
			var slot := int(key)
			if slot < 0 or slot >= SLOT_COUNT or str(slot) != key:
				return null
			var id := StringName(data["equipped"][key])
			if profile.owns(id):
				profile.equipped[slot] = id
	if data.has("bests"):
		if not data["bests"] is Dictionary:
			return null
		var found: Dictionary = data["bests"]
		if found.has("seconds") or found.has("enemies") or found.has("level"):
			for key in ["seconds", "enemies", "level"]:
				if found.has(key) and not _is_whole_in_range(found[key]):
					return null
			profile.set_best(OLD_BESTS_MAP, int(found.get("seconds", 0)), int(found.get("enemies", 0)))
		else:
			for map_id in found:
				if not map_id is String or not found[map_id] is Dictionary:
					return null
				var entry: Dictionary = found[map_id]
				for key in ["seconds", "enemies"]:
					if entry.has(key) and not _is_whole_in_range(entry[key]):
						return null
				profile.set_best(StringName(map_id), int(entry.get("seconds", 0)), int(entry.get("enemies", 0)))
	if data.has("potions"):
		if not data["potions"] is Dictionary:
			return null
		for key in data["potions"]:
			var count = data["potions"][key]
			if not key is String or not _is_whole_in_range(count) or int(count) > LEGACY_MAX_POTIONS:
				return null
			if int(count) > 0:
				profile.legacy_potions[StringName(key)] = int(count)
	return profile


## JSON gives every number as a float, so a whole-number float counts. Rejects anything that is not
## exactly whole, below 0 or above MAX_VALUE (compared as a float, so 1e19 cannot overflow an int).
static func _is_whole_in_range(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return number == floorf(number) and number >= 0.0 and number <= float(MAX_VALUE)


func level(track: LevelTrack) -> int:
	return track.level_for_xp(total_xp)


func add_xp(amount: int) -> void:
	total_xp = _added(total_xp, amount)


func add_gold(amount: int) -> void:
	gold = _added(gold, amount)


## Spends Gold. False, with nothing changed, if the amount is not positive or more than the player has.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	return true


func owns(id: StringName) -> bool:
	return owned.has(id)


## Adds an item to the owned list. Never adds one twice.
func grant(id: StringName) -> void:
	if not owned.has(id):
		owned.append(id)


func equip(slot: int, id: StringName) -> void:
	equipped[slot] = id


func unequip(slot: int) -> void:
	equipped.erase(slot)


## &"" when nothing is equipped in that slot.
func equipped_id(slot: int) -> StringName:
	return equipped.get(slot, &"")


func to_dict() -> Dictionary:
	var owned_ids: Array[String] = []
	for id in owned:
		owned_ids.append(str(id))
	var equipped_ids := {}
	for slot in equipped:
		equipped_ids[str(slot)] = str(equipped[slot])
	var data := {
		"version": SaveGame.VERSION,
		"total_xp": total_xp,
		"gold": gold,
		"owned": owned_ids,
		"equipped": equipped_ids,
	}
	if muted:
		data["muted"] = true
	var written := {}
	for map_id in bests:
		var entry: Dictionary = bests[map_id]
		if int(entry["seconds"]) > 0 or int(entry["enemies"]) > 0:
			written[map_id] = {"seconds": int(entry["seconds"]), "enemies": int(entry["enemies"])}
	if not written.is_empty():
		data["bests"] = written
	return data


func best_seconds(map_id: StringName) -> int:
	return int((bests.get(String(map_id), {}) as Dictionary).get("seconds", 0))


func best_enemies(map_id: StringName) -> int:
	return int((bests.get(String(map_id), {}) as Dictionary).get("enemies", 0))


func set_best(map_id: StringName, seconds: int, enemies: int) -> void:
	bests[String(map_id)] = {"seconds": seconds, "enemies": enemies}


## `current + amount` held at MAX_VALUE, ignoring amounts at or below 0 (and safe from int overflow).
static func _added(current: int, amount: int) -> int:
	if amount <= 0:
		return current
	if amount >= MAX_VALUE - current:
		return MAX_VALUE
	return current + amount
