class_name HealthBar
extends Control
## The player's health: a heart and a pink bar. It only shows what a HealthComponent reports.

const ICON_WIDTH := 13.0
const BAR_HEIGHT := 8.0

var ratio: float = 1.0

var _bar: ProgressBar


func _ready() -> void:
	var icon := UiKit.icon(&"icon_heart")
	icon.name = "Icon"
	add_child(icon)
	_bar = UiKit.bar(&"BarHp")
	_bar.name = "Bar"
	_bar.position = Vector2(ICON_WIDTH, 1.0)
	_bar.custom_minimum_size = Vector2(size.x - ICON_WIDTH, BAR_HEIGHT)
	_bar.size = _bar.custom_minimum_size
	_bar.value = ratio
	add_child(_bar)


func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	ratio = current / maximum if maximum > 0.0 else 0.0
	if _bar != null:
		_bar.value = ratio
