extends GutTest

const PATHS := [
	"res://resources/spells/fire_missile.tres",
	"res://resources/spells/thunder_cone.tres",
	"res://resources/spells/land_area.tres",
	"res://resources/spells/sea_line.tres",
	"res://resources/spells/sea_wave.tres",
]

var _root: Node2D
var _loadout: SpellLoadout
var _bar: SpellBar


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	var spells: Array[SpellData] = []
	for path in PATHS:
		spells.append(load(path) as SpellData)
	_loadout = SpellLoadout.new()
	_loadout.starting_spells = spells
	_loadout.projectile_root = _root
	add_child_autofree(_loadout)
	_bar = load("res://scenes/ui/spell_bar.tscn").instantiate() as SpellBar
	add_child_autofree(_bar)
	_bar.bind(_loadout)


func after_each() -> void:
	Input.action_release(&"cast")


func _touch(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = position
	return event


func test_five_widgets_with_the_spell_colours() -> void:
	assert_eq(_bar.widgets.size(), 5)
	for i in 5:
		assert_eq(_bar.widgets[i].element_color, (load(PATHS[i]) as SpellData).color)
		assert_false(_bar.widgets[i].empty)


func test_mana_ratio_follows_casts() -> void:
	assert_eq(_bar.widgets[0].ratio, 1.0)
	_loadout.try_cast(Vector2.ZERO, Vector2.RIGHT)
	var fire := _loadout.slots[0] as SpellInstance
	assert_eq(_bar.widgets[0].ratio, fire.current_mana / fire.data.max_mana)
	assert_eq(_bar.widgets[1].ratio, 1.0)


func test_depleted_spell_is_marked() -> void:
	var fire := _loadout.slots[0] as SpellInstance
	fire.current_mana = fire.data.mana_cost
	_loadout.try_cast(Vector2.ZERO, Vector2.RIGHT)
	assert_true(_bar.widgets[0].depleted)
	assert_false(_bar.widgets[1].depleted)


func test_selection_highlight_moves() -> void:
	assert_true(_bar.widgets[0].selected)
	_loadout.select(2)
	assert_false(_bar.widgets[0].selected)
	assert_true(_bar.widgets[2].selected)
	assert_false(_bar.widgets[1].selected)


func test_dry_cast_flashes_the_selected_widget() -> void:
	(_loadout.slots[0] as SpellInstance).current_mana = 0.0
	_loadout.try_cast(Vector2.ZERO, Vector2.RIGHT)
	assert_true(_bar.widgets[0].is_flashing())
	assert_false(_bar.widgets[1].is_flashing())


func test_touch_inside_a_widget_selects_it_and_does_not_cast() -> void:
	watch_signals(_bar)
	_bar.widgets[2]._input(_touch(_bar.widgets[2].get_global_rect().get_center()))
	assert_signal_emitted_with_parameters(_bar, "slot_pressed", [2])
	assert_false(Input.is_action_pressed(&"cast"))


func test_touch_outside_every_widget_is_ignored() -> void:
	watch_signals(_bar)
	for widget in _bar.widgets:
		widget._input(_touch(Vector2(-500, -500)))
	assert_signal_not_emitted(_bar, "slot_pressed")


func test_hidden_bar_ignores_touches() -> void:
	watch_signals(_bar)
	_bar.visible = false
	_bar.widgets[1]._input(_touch(_bar.widgets[1].get_global_rect().get_center()))
	assert_signal_not_emitted(_bar, "slot_pressed")


func test_mouse_click_on_a_widget_is_ignored() -> void:
	watch_signals(_bar)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _bar.widgets[1].get_global_rect().get_center()
	_bar.widgets[1]._input(click)
	assert_signal_not_emitted(_bar, "slot_pressed")


func test_touching_the_empty_slot_is_ignored_by_the_loadout() -> void:
	var spells: Array[SpellData] = [load(PATHS[0]) as SpellData, null, null, null, null]
	var sparse := SpellLoadout.new()
	sparse.starting_spells = spells
	sparse.projectile_root = _root
	add_child_autofree(sparse)
	var sparse_bar := load("res://scenes/ui/spell_bar.tscn").instantiate() as SpellBar
	add_child_autofree(sparse_bar)
	sparse_bar.bind(sparse)
	sparse_bar.slot_pressed.connect(sparse.select)
	assert_true(sparse_bar.widgets[1].empty)
	sparse_bar.widgets[1]._input(_touch(sparse_bar.widgets[1].get_global_rect().get_center()))
	assert_eq(sparse.selected_index, 0)


func _limited_bar(unlocked: int) -> Array:
	var spells: Array[SpellData] = [load(PATHS[0]) as SpellData]
	var loadout := SpellLoadout.new()
	loadout.starting_spells = spells
	loadout.unlocked_slots = unlocked
	loadout.projectile_root = _root
	add_child_autofree(loadout)
	var bar := load("res://scenes/ui/spell_bar.tscn").instantiate() as SpellBar
	add_child_autofree(bar)
	bar.bind(loadout)
	return [loadout, bar]


func test_locked_slots_are_dimmed_and_inert() -> void:
	var pair := _limited_bar(1)
	var bar := pair[1] as SpellBar
	assert_false(bar.widgets[0].locked)
	for i in range(1, 5):
		assert_true(bar.widgets[i].locked, "slot %d" % i)
	watch_signals(bar)
	assert_false(bar.widgets[2].handle_touch(bar.widgets[2].get_global_rect().get_center()))
	bar.widgets[2]._input(_touch(bar.widgets[2].get_global_rect().get_center()))
	assert_signal_not_emitted(bar, "slot_pressed")
	assert_lt(bar.widgets[2].modulate.a, 0.5)


func test_unlocking_a_slot_enables_its_widget() -> void:
	var pair := _limited_bar(1)
	var loadout := pair[0] as SpellLoadout
	var bar := pair[1] as SpellBar
	loadout.unlock_next()
	assert_false(bar.widgets[1].locked)
	assert_true(bar.widgets[1].empty)
	assert_true(bar.widgets[2].locked)


func test_a_replaced_slot_follows_the_new_instances_mana() -> void:
	var old := _loadout.slots[2] as SpellInstance
	var fresh := _loadout.equip(2, load(PATHS[4]) as SpellData)
	assert_eq(_bar.widgets[2].element_color, (load(PATHS[4]) as SpellData).color)
	_loadout.select(2)
	_loadout._process(1.0)
	_loadout.try_cast(Vector2.ZERO, Vector2.RIGHT)
	assert_almost_eq(_bar.widgets[2].ratio, fresh.mana_ratio(), 0.0001)
	assert_lt(_bar.widgets[2].ratio, 1.0)
	var shown: float = _bar.widgets[2].ratio
	old.restore_mana()
	old.current_mana = 1.0
	old.mana_changed.emit(1.0, old.data.max_mana)
	assert_eq(_bar.widgets[2].ratio, shown, "the old instance no longer drives the widget")


func test_a_slot_draws_the_slot_frame_with_a_selected_variation() -> void:
	var selected := _loadout.selected_index
	var other := 1 if selected != 1 else 2
	assert_eq(_bar.widgets[selected].frame_variation(), &"PanelSlotSelected")
	assert_eq(_bar.widgets[other].frame_variation(), &"PanelSlot")
	_loadout.select(other)
	assert_eq(_bar.widgets[other].frame_variation(), &"PanelSlotSelected")
	assert_eq(_bar.widgets[selected].frame_variation(), &"PanelSlot")


func test_the_mana_fill_still_follows_the_ratio() -> void:
	var widget := _bar.widgets[0]
	widget.set_mana(50.0, 100.0)
	assert_almost_eq(widget.mana_fill_width(), (SpellSlotWidget.SIZE.x - 4.0) * 0.5, 0.0001)
	widget.set_mana(0.0, 100.0)
	assert_eq(widget.mana_fill_width(), 0.0)


func test_the_slot_numbers_use_the_outlined_hud_label() -> void:
	assert_eq(_bar.widgets[0].number_variation(), &"HudLabel")
