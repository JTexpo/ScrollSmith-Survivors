class_name SpriteLibrary
extends RefCounted
## Finds the sprite sets the art tool built (or the user replaced). A variant that has no sheet falls back to the
## sprite's `base`, and a sprite with no art at all returns null (the caller shows its coloured square).

## Where the sets live. Tests point this at a temporary folder.
static var root: String = "res://assets/sprites"


static func find(sprite_name: StringName, variant: StringName = &"base") -> SpriteSetData:
	for candidate in [variant, &"base"]:
		var set_path := "%s/%s_%s.tres" % [root, sprite_name, candidate]
		if ResourceLoader.exists(set_path):
			return load(set_path) as SpriteSetData
	return null


static func find_silhouette(sprite_name: StringName) -> SpriteSetData:
	var set_path := "%s/%s_silhouette.tres" % [root, sprite_name]
	if ResourceLoader.exists(set_path):
		return load(set_path) as SpriteSetData
	return null
