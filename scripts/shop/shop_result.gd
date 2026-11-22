class_name ShopResult
extends RefCounted
## What a shop action did: whether it worked, why not if it did not, and the item it was about.

var ok: bool = false
var reason: String = ""
var item: EquipmentData
## The potion a potion purchase was about (item stays null).
var potion: PotionData
