class_name HitIndicator
extends CanvasLayer
## Short red arcs at the edge of the screen that point at where the player was hit from. A pool of three pixel sprites (never rotated or
## scaled: a horizontal and a vertical drawing, flipped for the far side), each solid for 0.1 s and fading out by about 0.5 s. A new hit
## reuses the oldest arc at the cap. `FxSettings.hit_indicators` off shows nothing.

const MAX_ARCS := 3
const SOLID_SECONDS := 0.1
const TOTAL_SECONDS := 0.5
const SCREEN := Vector2(480, 270)
const MARGIN := 3.0
## How far along the edge an arc can slide from the middle, towards the hit's other component.
const SLIDE := 70.0

var _arcs: Array[Sprite2D] = []
var _ages: Array[float] = []


func _init() -> void:
	layer = 45


func _ready() -> void:
	for i in MAX_ARCS:
		var arc := Sprite2D.new()
		arc.centered = false
		arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arc.visible = false
		add_child(arc)
		_arcs.append(arc)
		_ages.append(TOTAL_SECONDS)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## `direction` points from the player towards where the hit came from.
func show_hit(direction: Vector2) -> void:
	if not FxSettings.hit_indicators or _arcs.is_empty():
		return
	var index := _free_arc()
	var arc := _arcs[index]
	var horizontal := absf(direction.x) >= absf(direction.y)
	var set_data := SpriteLibrary.find(&"fx_hit_edge_v" if horizontal else &"fx_hit_edge_h")
	arc.texture = set_data.sheet if set_data != null else null
	var size := arc.texture.get_size() if arc.texture != null else Vector2(6, 48)
	var along := clampf(direction.y / maxf(absf(direction.x), 0.001), -1.0, 1.0) if horizontal else clampf(direction.x / maxf(absf(direction.y), 0.001), -1.0, 1.0)
	if direction == Vector2.ZERO:
		along = 0.0
	if horizontal:
		var on_left := direction.x < 0.0
		arc.flip_h = not on_left
		arc.flip_v = false
		arc.position = Vector2(MARGIN if on_left else SCREEN.x - MARGIN - size.x, SCREEN.y * 0.5 - size.y * 0.5 + along * SLIDE)
	else:
		var on_top := direction.y < 0.0
		arc.flip_v = not on_top
		arc.flip_h = false
		arc.position = Vector2(SCREEN.x * 0.5 - size.x * 0.5 + along * SLIDE, MARGIN if on_top else SCREEN.y - MARGIN - size.y)
	arc.position = arc.position.round()
	arc.modulate.a = 1.0
	arc.visible = true
	_ages[index] = 0.0
	set_process(true)


func advance(delta: float) -> void:
	var any := false
	for i in _arcs.size():
		if not _arcs[i].visible:
			continue
		_ages[i] += delta
		if _ages[i] >= TOTAL_SECONDS:
			_arcs[i].visible = false
			continue
		any = true
		if _ages[i] > SOLID_SECONDS:
			_arcs[i].modulate.a = 1.0 - (_ages[i] - SOLID_SECONDS) / (TOTAL_SECONDS - SOLID_SECONDS)
	if not any:
		set_process(false)


func visible_arcs() -> Array[Sprite2D]:
	var shown: Array[Sprite2D] = []
	for arc in _arcs:
		if arc.visible:
			shown.append(arc)
	return shown


func clear() -> void:
	for i in _arcs.size():
		_arcs[i].visible = false
		_ages[i] = TOTAL_SECONDS


## A hidden arc if there is one, else the oldest.
func _free_arc() -> int:
	var oldest := 0
	for i in _arcs.size():
		if not _arcs[i].visible:
			return i
		if _ages[i] > _ages[oldest]:
			oldest = i
	return oldest
