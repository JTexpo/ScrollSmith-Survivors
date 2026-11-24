class_name PerfOverlay
extends CanvasLayer
## One small line of engine counters (frames per second, frame time, enemies alive, nodes in the tree) over the game, so a tester on a
## phone can send a screenshot. It shows when `FxSettings.perf_overlay` is on (F3, or a long press on the mute button) and does no work
## while hidden. It reads counters only, refreshes four times a second, allocates nothing per frame and never takes a touch.

const REFRESH_SECONDS := 0.25

var _spawner: EnemySpawner
var _label: Label
var _since_refresh: float = 0.0
var _frames: int = 0
var _frame_total: float = 0.0
var _ms: float = 0.0


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_label = Label.new()
	_label.name = "Line"
	_label.theme_type_variation = &"HudLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(150, 2)
	_label.size = Vector2(180, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	sync()


func _process(delta: float) -> void:
	advance(delta)


func bind(spawner: EnemySpawner) -> void:
	_spawner = spawner


## Shows or hides the overlay to match the switch, and processes only while shown.
func sync() -> void:
	visible = FxSettings.perf_overlay
	set_process(visible)
	if visible:
		refresh_now()


## Moves the refresh timer forward (`_process` calls it every frame; tests call it by hand).
func advance(delta: float) -> void:
	_frames += 1
	_frame_total += delta
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		refresh_now()


func refresh_now() -> void:
	if _frames > 0:
		_ms = _frame_total / _frames * 1000.0
	_frames = 0
	_frame_total = 0.0
	_since_refresh = 0.0
	if _label != null:
		_label.text = line_text()


func shown_text() -> String:
	return _label.text if _label != null else ""


## "fps 98  10.2 ms  enemies 300  nodes 1423".
func line_text() -> String:
	var enemies := _spawner.alive if _spawner != null else 0
	return "fps %d  %.1f ms  enemies %d  nodes %d" % [Engine.get_frames_per_second(), _ms, enemies, roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
