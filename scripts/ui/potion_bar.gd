class_name PotionBar
extends Control
## A column of six potion slots at the top right, in catalog order. It reads
## the potion belt and the active effects and never changes them. A tap on a slot is forwarded as
## slot_pressed, and Main routes it to the belt. It only processes while a cooldown or an effect runs.

signal slot_pressed(index: int)

const KEYS: Array[String] = ["Z", "X", "C", "V", "B", "N"]
const GAP := 2.0

var widgets: Array[PotionSlotWidget] = []

var _belt: PotionBelt
var _effects: ActiveEffects
var _catalog: PotionCatalog


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(_delta: float) -> void:
	_refresh()


func bind(belt: PotionBelt, effects: ActiveEffects, catalog: PotionCatalog) -> void:
	_belt = belt
	_effects = effects
	_catalog = catalog
	for i in catalog.potions.size():
		var widget := PotionSlotWidget.new()
		add_child(widget)
		widget.position = Vector2(0.0, i * (PotionSlotWidget.SIZE.y + GAP))
		widget.setup(i, catalog.potions[i], KEYS[i] if i < KEYS.size() else "")
		widget.pressed.connect(_on_widget_pressed)
		widgets.append(widget)
	belt.changed.connect(_refresh)
	effects.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _belt == null:
		return
	var running := false
	for i in widgets.size():
		var id := _catalog.potions[i].id
		widgets[i].set_count(_belt.count(id))
		widgets[i].set_cooldown(_belt.cooldown_ratio(id))
		widgets[i].set_effect(_effects.ratio(id))
		widgets[i].set_selected(i == _belt.selected_index)
		if _belt.cooldown_left(id) > 0.0 or _effects.is_active(id):
			running = true
	set_process(running)


func _on_widget_pressed(index: int) -> void:
	slot_pressed.emit(index)
