class_name SpellBar
extends Control
## A row of five spell slots. Reads the loadout and never
## changes it. A tap on a slot is forwarded as slot_pressed, and Main routes it to select().
## Locked slots are dimmed, and a slot follows its spell when crafting replaces it.

signal slot_pressed(index: int)

const GAP := 2.0

var widgets: Array[SpellSlotWidget] = []

var _loadout: SpellLoadout
## The instance each widget currently follows, so a replaced spell can be unhooked.
var _bound: Array[SpellInstance] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(loadout: SpellLoadout) -> void:
	_loadout = loadout
	for i in SpellLoadout.SLOT_COUNT:
		var widget := SpellSlotWidget.new()
		add_child(widget)
		widget.position = Vector2(i * (SpellSlotWidget.SIZE.x + GAP), 0.0)
		widget.pressed.connect(_on_widget_pressed)
		widgets.append(widget)
		_bound.append(null)
		_follow(i)
	loadout.selection_changed.connect(_on_selection_changed)
	loadout.cast_failed_dry.connect(_on_cast_failed_dry)
	loadout.slot_changed.connect(_follow)
	loadout.slot_unlocked.connect(_follow)
	_on_selection_changed(loadout.selected_index)


## Points a widget at whatever its slot holds now.
func _follow(index: int) -> void:
	var widget := widgets[index]
	var old := _bound[index]
	if old != null and old.mana_changed.is_connected(widget.set_mana):
		old.mana_changed.disconnect(widget.set_mana)
	var instance := _loadout.slots[index]
	_bound[index] = instance
	widget.setup(index, instance.data if instance != null else null)
	if instance != null:
		widget.set_mana(instance.current_mana, instance.max_mana())
		instance.mana_changed.connect(widget.set_mana)
	widget.set_locked(not _loadout.is_unlocked(index))
	widget.set_selected(index == _loadout.selected_index)


func _on_widget_pressed(index: int) -> void:
	slot_pressed.emit(index)


func _on_selection_changed(index: int) -> void:
	for i in widgets.size():
		widgets[i].set_selected(i == index)


func _on_cast_failed_dry(index: int) -> void:
	widgets[index].flash_dry()
