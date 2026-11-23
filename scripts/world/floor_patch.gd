class_name FloorPatch
extends Node2D
## A floor tile repeated over a rectangle (a zone, the whole map or the world's edge). It is only a drawing, so it
## never catches a touch, and a flat colour under it stays as the fallback. A soft patch (a zone) has a ragged, organic
## edge: its middle is one tiled rectangle and the outer 16 px is drawn in 8 px cells of the same tile with some cells
## left out, more at the very edge than just inside it, so the floor below shows through and the zones blend into each
## other instead of meeting in a straight line.

## Side of one edge cell, in pixels. Two cells make the 16 px soft band, and a tile is two cells wide.
const CELL := 8.0
const BAND_CELLS := 2
## The chance that a cell is left out, by how many cells in from the edge it is.
const OMIT_CHANCE := [0.45, 0.18]

## The covered rectangle, in the parent's coordinates.
var area: Rect2 = Rect2()

var _texture: Texture2D
var _tile: Vector2 = Vector2(16, 16)
var _soft: bool = false
var _omitted: Array[Rect2] = []
var _edge_cells: Array[Rect2] = []


## `soft` gives the ragged edge, picked by `seed_value` so the same map always looks the same.
func setup(covered: Rect2, set_data: SpriteSetData, soft: bool = false, seed_value: int = 0) -> void:
	area = covered
	_texture = set_data.sheet
	_tile = Vector2(set_data.frame_size)
	_soft = soft
	position = covered.position
	_omitted.clear()
	_edge_cells.clear()
	if soft:
		_pick_edge_cells(seed_value)
	queue_redraw()


## The cells of the soft band that are left out, in the patch's own coordinates. Empty for a hard patch.
func omitted_cells() -> Array[Rect2]:
	return _omitted


## The part drawn as one tiled rectangle, in the patch's own coordinates: everything for a hard patch, and the area
## shrunk by the soft band for a soft one (empty when the area is too small to have a middle).
func interior_rect() -> Rect2:
	if not _soft:
		return Rect2(Vector2.ZERO, area.size)
	var band := CELL * BAND_CELLS
	var size := Vector2(maxf(area.size.x - band * 2.0, 0.0), maxf(area.size.y - band * 2.0, 0.0))
	return Rect2(Vector2(band, band), size)


func _pick_edge_cells(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var columns := ceili(area.size.x / CELL)
	var rows := ceili(area.size.y / CELL)
	for row in rows:
		for column in columns:
			var depth := mini(mini(column, row), mini(columns - 1 - column, rows - 1 - row))
			if depth >= BAND_CELLS:
				continue
			var cell := Rect2(column * CELL, row * CELL, minf(CELL, area.size.x - column * CELL), minf(CELL, area.size.y - row * CELL))
			if rng.randf() < OMIT_CHANCE[depth]:
				_omitted.append(cell)
			else:
				_edge_cells.append(cell)


func _draw() -> void:
	if _texture == null:
		return
	if not _soft:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, area.size), true)
		return
	var inner := interior_rect()
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_texture_rect(_texture, inner, true)
	for cell in _edge_cells:
		var source := Vector2(fposmod(cell.position.x, _tile.x), fposmod(cell.position.y, _tile.y))
		draw_texture_rect_region(_texture, cell, Rect2(source, cell.size))
