class_name HealthBar
extends Control
## The player's health: a heart and a pink bar. It only shows what a HealthComponent reports.

const ICON_WIDTH := 13.0
const BAR_HEIGHT := 8.0
## How long the beating heart shows on each beat.
const BEAT_SECONDS := 0.15

var ratio: float = 1.0

var _bar: ProgressBar
var _icon: TextureRect
var _beat_left: float = 0.0


func _ready() -> void:
	_icon = UiKit.icon(&"icon_heart")
	_icon.name = "Icon"
	add_child(_icon)
	set_process(false)
	_bar = UiKit.bar(&"BarHp")
	_bar.name = "Bar"
	_bar.position = Vector2(ICON_WIDTH, 1.0)
	_bar.custom_minimum_size = Vector2(size.x - ICON_WIDTH, BAR_HEIGHT)
	_bar.size = _bar.custom_minimum_size
	_bar.value = ratio
	add_child(_bar)


func _process(delta: float) -> void:
	_beat_left -= delta
	if _beat_left <= 0.0:
		_show_heart(&"icon_heart")
		set_process(false)


## The heart swaps to its fuller drawing for a moment (a beat). Never scaled: it is a second drawing.
func beat() -> void:
	if _icon == null or not FxSettings.heart_beat:
		return
	_show_heart(&"icon_heart_beat")
	_beat_left = BEAT_SECONDS
	set_process(true)


func heart_texture() -> Texture2D:
	return _icon.texture if _icon != null else null


func _show_heart(sprite_name: StringName) -> void:
	var set_data := SpriteLibrary.find(sprite_name)
	if set_data != null:
		_icon.texture = set_data.sheet


func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	ratio = current / maximum if maximum > 0.0 else 0.0
	if _bar != null:
		_bar.value = ratio
