class_name WorldArt
extends RefCounted
## Finds the art a map names. The map data only holds names (a floor style, a wall material, a decoration style), and
## these look them up by one naming rule through `SpriteLibrary`, so a name with no art is simply null and the caller
## keeps its flat colour. Floors are `tile_<style>`, walls `wall_<material>`, round posts `post_<material>` and
## decorations `decor_<style>`.


static func floor_set(style: StringName) -> SpriteSetData:
	return _find("tile_", style)


static func wall_set(material: StringName) -> SpriteSetData:
	return _find("wall_", material)


static func post_set(material: StringName) -> SpriteSetData:
	return _find("post_", material)


static func decor_set(style: StringName) -> SpriteSetData:
	return _find("decor_", style)


static func _find(prefix: String, art_name: StringName) -> SpriteSetData:
	if art_name == &"":
		return null
	return SpriteLibrary.find(StringName(prefix + String(art_name)))
