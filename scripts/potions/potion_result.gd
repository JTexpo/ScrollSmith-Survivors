class_name PotionResult
extends RefCounted
## What drinking a potion did: whether it worked, why not if it did not, and the potion.

var ok: bool = false
var reason: String = ""
var potion: PotionData
