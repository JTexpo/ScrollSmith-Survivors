class_name BossBar
extends Control
## The boss's name and health along the top while a boss lives. It only shows what the boss
## reports and holds no rules, and every control in it ignores the mouse.

const WIDTH := 160.0
const BAR_HEIGHT := 8.0

var _boss: Boss
var _ratio: float = 1.0

var _title: Label
var _bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_title = UiKit.label("", &"HudLabel")
	_title.name = "Title"
	_title.size = Vector2(WIDTH, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_bar = UiKit.bar(&"BarBoss")
	_bar.name = "Bar"
	_bar.position = Vector2(0, 11)
	_bar.custom_minimum_size = Vector2(WIDTH, BAR_HEIGHT)
	_bar.size = _bar.custom_minimum_size
	_bar.value = _ratio
	add_child(_bar)


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
	if _bar != null:
		_bar.value = _ratio


func _on_health_changed(current: float, maximum: float) -> void:
	_ratio = current / maximum if maximum > 0.0 else 0.0
	_bar.value = _ratio


func _on_boss_spawned(boss: Boss, _number: int) -> void:
	show_boss(boss)


func _on_boss_defeated(_number: int) -> void:
	hide_boss()


func _on_boss_died(_boss_that_died: Boss) -> void:
	hide_boss()
