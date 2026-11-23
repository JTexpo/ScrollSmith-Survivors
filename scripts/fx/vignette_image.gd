class_name VignetteImage
extends RefCounted
## The low-health screen frame, built in code as one pixel image (the game's 480 by 270): red pixels within DEPTH of an edge, dithered
## with a 4 by 4 ordered pattern so it reads as a soft gradient in pixel art (solid at the very edge, sparse at the inner rim, a little
## denser in the corners) and fully clear in the middle. Pure and deterministic. It uses only the palette's red, so the pulse of the
## whole frame is just its opacity.

const DEPTH := 22
const RED := Color("e0483c")
const INNER_DENSITY := 0.2
## Ordered-dither thresholds (0 to 15) for a 4 by 4 tile.
const BAYER := [
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5,
]


static func build(size: Vector2i = Vector2i(480, 270), depth: int = DEPTH) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var edge_x := mini(x, size.x - 1 - x)
			var edge_y := mini(y, size.y - 1 - y)
			var ring := mini(edge_x, edge_y)
			if ring >= depth:
				continue
			# A corner has both edges close, so its pixels count as a little nearer the edge.
			var reach := 0.6 + 0.4 * minf(float(maxi(edge_x, edge_y)) / float(depth), 1.0)
			var distance := float(ring) * reach
			var density := 1.0 - (1.0 - INNER_DENSITY) * clampf(distance / float(depth - 1), 0.0, 1.0)
			if ring == 0 or float(BAYER[(y % 4) * 4 + (x % 4)]) < density * 16.0:
				image.set_pixel(x, y, RED)
	return image
