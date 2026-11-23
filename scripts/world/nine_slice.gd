class_name NineSlice
extends RefCounted
## Draws a wall of any size from one small tile cut into nine parts: four corners drawn as they are, four edges and a
## centre repeated 1:1 (never stretched), so a 16 px wall and a long one both look like one piece and keep crisp pixels.
## The edges and the corners are drawn in one pass and the centres in a second, so where two walls cross, the centre of
## one covers the border of the other and the junction has no line across it.


## The nine parts of a tile cut by `slice` (left, top, right, bottom margins) and where each goes in `dest`. Each is
## {"src": Rect2, "dest": Rect2, "kind": "corner" | "edge" | "centre"}. A destination smaller than the margins gets
## smaller margins, so the parts always fill it exactly.
static func parts(src_size: Vector2, slice: Vector4i, dest: Rect2) -> Array[Dictionary]:
	var left := minf(float(slice.x), floorf(dest.size.x / 2.0))
	var right := minf(float(slice.z), dest.size.x - left)
	var top := minf(float(slice.y), floorf(dest.size.y / 2.0))
	var bottom := minf(float(slice.w), dest.size.y - top)
	var src_x := [0.0, left, src_size.x - right, src_size.x]
	var src_y := [0.0, top, src_size.y - bottom, src_size.y]
	var dest_x := [dest.position.x, dest.position.x + left, dest.end.x - right, dest.end.x]
	var dest_y := [dest.position.y, dest.position.y + top, dest.end.y - bottom, dest.end.y]
	var result: Array[Dictionary] = []
	for row in 3:
		for column in 3:
			var kind := "centre" if row == 1 and column == 1 else ("corner" if row != 1 and column != 1 else "edge")
			result.append({
				"src": Rect2(src_x[column], src_y[row], src_x[column + 1] - src_x[column], src_y[row + 1] - src_y[row]),
				"dest": Rect2(dest_x[column], dest_y[row], dest_x[column + 1] - dest_x[column], dest_y[row + 1] - dest_y[row]),
				"kind": kind,
			})
	return result


## Draws the corners and edges (`centres` false) or the centre (`centres` true) of `dest` from `texture`.
static func draw(canvas: CanvasItem, texture: Texture2D, src_size: Vector2, slice: Vector4i, dest: Rect2, centres: bool) -> void:
	for part in parts(src_size, slice, dest):
		if (part["kind"] == "centre") == centres:
			_tile(canvas, texture, part["src"], part["dest"])


## Repeats `src` over `dest` from the top-left, cutting the last repeat short.
static func _tile(canvas: CanvasItem, texture: Texture2D, src: Rect2, dest: Rect2) -> void:
	if src.size.x <= 0.0 or src.size.y <= 0.0 or dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	var y := dest.position.y
	while y < dest.end.y - 0.001:
		var height := minf(src.size.y, dest.end.y - y)
		var x := dest.position.x
		while x < dest.end.x - 0.001:
			var width := minf(src.size.x, dest.end.x - x)
			canvas.draw_texture_rect_region(texture, Rect2(x, y, width, height), Rect2(src.position, Vector2(width, height)))
			x += src.size.x
		y += src.size.y
