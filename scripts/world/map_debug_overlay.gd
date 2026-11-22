class_name MapDebugOverlay
extends Node2D
## DEBUG: draws the map's bounds, the player start and a labelled marker per placement, so a layout
## can be seen while tuning it. Hidden until `GameMap.toggle_debug` (F7). Delete when no longer needed.

const LINE_COLOR := Color(1.0, 0.2, 0.8, 0.9)
const MARKER_RADIUS := 6.0

var _data: MapData


func setup(data: MapData) -> void:
	_data = data
	queue_redraw()


## The player start plus one marker per placement.
func marker_count() -> int:
	return 0 if _data == null else 1 + _data.placements.size()


func _draw() -> void:
	if _data == null:
		return
	draw_rect(_data.bounds(), LINE_COLOR, false, 2.0)
	_draw_marker(_data.player_start, "start")
	for placement in _data.placements:
		if placement != null and placement.scene != null:
			_draw_marker(placement.position, placement.scene.resource_path.get_file().get_basename())


func _draw_marker(at: Vector2, label: String) -> void:
	draw_line(at - Vector2(MARKER_RADIUS, 0), at + Vector2(MARKER_RADIUS, 0), LINE_COLOR, 1.0)
	draw_line(at - Vector2(0, MARKER_RADIUS), at + Vector2(0, MARKER_RADIUS), LINE_COLOR, 1.0)
	draw_string(ThemeDB.fallback_font, at + Vector2(MARKER_RADIUS + 2.0, -MARKER_RADIUS), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LINE_COLOR)
