class_name BossBar
extends Control
## TEMPORARY look: the boss's name and health along the top while a boss lives. It only shows what the boss
## reports and holds no rules, and every control in it ignores the mouse.

const WIDTH := 160.0
const BAR_HEIGHT := 7.0

var _boss: Boss
var _ratio: float = 1.0

var _title: Label
var _background: ColorRect
var _fill: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_title = Label.new()
	_title.size = Vector2(WIDTH, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 8)
	add_child(_title)
	_background = ColorRect.new()
	_background.position = Vector2(0, 11)
	_background.size = Vector2(WIDTH, BAR_HEIGHT)
	_background.color = Color(0.1, 0.1, 0.1, 0.85)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_fill = ColorRect.new()
	_fill.size = Vector2(WIDTH, BAR_HEIGHT)
	_fill.color = Color(0.85, 0.2, 0.15)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(_fill)


## Follows the director: shown when a boss spawns, hidden when it is defeated.
func bind(director: RunDirector) -> void:
	director.boss_spawned.connect(_on_boss_spawned)
	director.boss_defeated.connect(_on_boss_defeated)


func show_boss(boss: Boss) -> void:
	_unfollow()
	_boss = boss
	var health := boss.get_node("HealthComponent") as HealthComponent
	health.health_changed.connect(_on_health_changed)
	boss.died.connect(_on_boss_died)
	_title.text = boss.data.display_name
	_on_health_changed(health.current_health, health.max_health)
	visible = true


func hide_boss() -> void:
	_unfollow()
	visible = false


func is_showing() -> bool:
	return visible


func ratio() -> float:
	return _ratio


func title_text() -> String:
	return _title.text if _title != null else ""


func _unfollow() -> void:
	if is_instance_valid(_boss):
		var health := _boss.get_node("HealthComponent") as HealthComponent
		if health.health_changed.is_connected(_on_health_changed):
			health.health_changed.disconnect(_on_health_changed)
		if _boss.died.is_connected(_on_boss_died):
			_boss.died.disconnect(_on_boss_died)
	_boss = null
	_ratio = 1.0
	if _fill != null:
		_fill.size.x = WIDTH


func _on_health_changed(current: float, maximum: float) -> void:
	_ratio = current / maximum if maximum > 0.0 else 0.0
	_fill.size.x = WIDTH * _ratio


func _on_boss_spawned(boss: Boss, _number: int) -> void:
	show_boss(boss)


func _on_boss_defeated(_number: int) -> void:
	hide_boss()


func _on_boss_died(_boss_that_died: Boss) -> void:
	hide_boss()
