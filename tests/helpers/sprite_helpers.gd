extends RefCounted
## Sprite sheet comparisons for the art tests.


## How many pixels differ between frame `a` and frame `b` of a sheet.
static func frame_difference(set_data: SpriteSetData, a: int, b: int) -> int:
	var sheet := set_data.sheet.get_image()
	var size := set_data.frame_size
	var differing := 0
	for y in size.y:
		for x in size.x:
			if sheet.get_pixel(a * size.x + x, y) != sheet.get_pixel(b * size.x + x, y):
				differing += 1
	return differing
