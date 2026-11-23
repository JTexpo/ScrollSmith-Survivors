extends GutTest

var _root: Node2D
var _inventory: ScrollInventory
var _loadout: SpellLoadout
var _screen: CraftingScreen
var _fire: ScrollData
var _thunder: ScrollData
var _missile: ScrollData
var _wave: ScrollData


func _scroll(path: String) -> ScrollData:
	return load("res://resources/scrolls/%s.tres" % path) as ScrollData


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_inventory = ScrollInventory.new()
	add_child_autofree(_inventory)
	var spells: Array[SpellData] = [load("res://resources/spells/fire_missile.tres") as SpellData]
	_loadout = SpellLoadout.new()
	_loadout.starting_spells = spells
	_loadout.unlocked_slots = 1
	_loadout.projectile_root = _root
	add_child_autofree(_loadout)
	_screen = load("res://scenes/ui/crafting_screen.tscn").instantiate() as CraftingScreen
	_screen.pause_tree = false
	add_child_autofree(_screen)
	_fire = _scroll("base/fire")
	_thunder = _scroll("base/thunder")
	_missile = _scroll("area/missile")
	_wave = _scroll("area/wave")


func after_each() -> void:
	get_tree().paused = false
	GameTime.reset()


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_starts_closed_and_hidden() -> void:
	assert_false(_screen.is_open())
	assert_false(_screen.visible)


func test_open_shows_it_and_close_hides_it_and_emits_closed_once() -> void:
	watch_signals(_screen)
	_screen.open(_inventory, _loadout)
	assert_true(_screen.is_open())
	assert_true(_screen.visible)
	_screen.close()
	_screen.close()
	assert_false(_screen.is_open())
	assert_false(_screen.visible)
	assert_signal_emit_count(_screen, "closed", 1)


func test_open_pauses_and_close_unpauses_when_enabled() -> void:
	_screen.pause_tree = true
	_screen.open(_inventory, _loadout)
	var paused_while_open := get_tree().paused
	var clock_frozen := GameTime.is_frozen()
	_screen.close()
	assert_true(paused_while_open)
	assert_true(clock_frozen)
	assert_false(get_tree().paused)
	assert_false(GameTime.is_frozen())


func test_empty_inventory_opens_with_confirm_disabled_and_a_reason() -> void:
	_screen.open(_inventory, _loadout)
	assert_false(_screen.confirm_enabled())
	assert_false(_screen.message_text().is_empty())


func test_preview_matches_the_builder() -> void:
	_inventory.add(_thunder)
	_inventory.add(_wave)
	_screen.open(_inventory, _loadout)
	assert_true(_screen.choose_base(_thunder))
	assert_true(_screen.choose_area(_wave))
	assert_true(_screen.choose_range(2))
	var built := SpellBuilder.build([_thunder], _wave, CraftingRules.default_rules().option(2))
	var text := _screen.preview_text()
	assert_true(text.contains("Thunder Wave (Long)"), text)
	assert_true(text.contains("%.1f" % built.mana_cost), text)
	assert_true(text.contains("%d" % roundi(built.max_mana)), text)
	assert_true(_screen.confirm_enabled())


func test_current_spell_is_shown_beside_the_preview() -> void:
	_screen.open(_inventory, _loadout)
	assert_true(_screen.preview_text().contains("Fire Missile"))
	assert_true(_screen.preview_text().contains("Replaces Fire Missile"))


func test_confirm_crafts_consumes_and_closes() -> void:
	_inventory.add(_thunder)
	_inventory.add(_missile)
	_screen.open(_inventory, _loadout)
	watch_signals(_screen)
	_screen.choose_base(_thunder)
	_screen.choose_area(_missile)
	_screen.confirm()
	assert_eq(_loadout.slots[0].data.id, &"thunder_missile_normal")
	assert_eq(_inventory.count(_thunder), 0)
	assert_eq(_inventory.count(_missile), 0)
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)


func test_confirm_when_invalid_shows_the_reason_and_changes_nothing() -> void:
	_inventory.add(_thunder)
	_screen.open(_inventory, _loadout)
	var before := _loadout.slots[0]
	_screen.choose_base(_thunder)
	_screen.confirm()
	assert_true(_screen.is_open())
	assert_eq(_screen.message_text(), CraftingSystem.REASON_NO_AREA)
	assert_eq(_inventory.count(_thunder), 1)
	assert_eq(_loadout.slots[0], before)


func test_cancel_changes_nothing_and_closes() -> void:
	_inventory.add(_thunder)
	_inventory.add(_missile)
	_screen.open(_inventory, _loadout)
	_screen.choose_base(_thunder)
	_screen.choose_area(_missile)
	var before := _loadout.slots[0]
	_screen.cancel()
	assert_false(_screen.is_open())
	assert_eq(_loadout.slots[0], before)
	assert_eq(_inventory.total_count(), 2)


func test_locked_slot_cannot_be_chosen() -> void:
	_screen.open(_inventory, _loadout)
	assert_false(_screen.choose_slot(1))
	assert_eq(_screen.session.slot_index, 0)


func test_buffs_text_names_the_chosen_stacks() -> void:
	var damage := _scroll("buff/damage")
	var duplicate := _scroll("buff/duplicate_area")
	_inventory.add(damage, 2)
	_inventory.add(duplicate)
	_screen.open(_inventory, _loadout)
	assert_eq(_screen.buffs_text(), "Buffs: none")
	_screen.add_buff(damage)
	_screen.add_buff(damage)
	_screen.add_buff(duplicate)
	assert_eq(_screen.buffs_text(), "Buffs: Increased Damage x2, Duplicate Area x1")
	assert_false(_screen.choose_base(damage), "a buff is not a Base")
	assert_false(_screen.choose_area(damage), "a buff is not an Area")


func test_ui_cancel_and_pause_actions_close_it() -> void:
	_screen.open(_inventory, _loadout)
	_screen._unhandled_input(_action(&"ui_cancel"))
	assert_false(_screen.is_open())
	_screen.open(_inventory, _loadout)
	_screen._unhandled_input(_action(&"pause"))
	assert_false(_screen.is_open())


func test_actions_are_ignored_while_closed() -> void:
	_screen._unhandled_input(_action(&"ui_cancel"))
	assert_false(_screen.is_open())


func test_touch_is_bridged_while_open_and_ignored_while_closed() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(40, 40)
	assert_false(_screen.handle_input(touch), "closed")
	_screen.open(_inventory, _loadout)
	assert_true(_screen.handle_input(touch), "open")
	var drag := InputEventScreenDrag.new()
	assert_false(_screen.handle_input(drag), "only touches are bridged")


func test_choices_survive_a_rebuild_and_buttons_exist() -> void:
	_inventory.add(_fire, 2)
	_inventory.add(_missile)
	_screen.open(_inventory, _loadout)
	assert_eq(_screen.base_button_count(), 1)
	assert_eq(_screen.area_button_count(), 1)
	assert_eq(_screen.range_button_count(), 4)
	_screen.choose_base(_fire)
	assert_eq(_screen.session.bases, [_fire])
	assert_eq(_screen.base_button_count(), 1)


func _touch(pressed: bool, at: Vector2) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	touch.position = at
	return touch


func test_a_bridged_touch_does_not_press_the_global_cast_action() -> void:
	# The synthetic left click would otherwise also press `cast` (bound to the left mouse button),
	# and a finger held down when the screen closes could keep it pressed.
	_screen.open(_inventory, _loadout)
	_screen.handle_input(_touch(true, Vector2(40, 40)))
	await wait_process_frames(2)
	var pressed_cast := Input.is_action_pressed(&"cast")
	_screen.handle_input(_touch(false, Vector2(40, 40)))
	await wait_process_frames(2)
	Input.action_release(&"cast")
	assert_false(pressed_cast, "a bridged touch must not press the cast action")



func _own(path: String, amount: int = 1) -> ScrollData:
	var scroll := _scroll(path)
	_inventory.add(scroll, amount)
	return scroll


func _hybrid_recipe() -> Array:
	var fire := _own("base/fire")
	var sea := _own("base/sea")
	var extra := _own("buff/additional_base")
	var duplicate := _own("buff/duplicate_area")
	var damage := _own("buff/damage", 2)
	var missile := _own("area/missile")
	_screen.open(_inventory, _loadout)
	_screen.add_buff(extra)
	_screen.choose_base(fire)
	_screen.choose_base(sea)
	_screen.choose_area(missile)
	_screen.add_buff(duplicate)
	_screen.add_buff(damage)
	_screen.add_buff(damage)
	return [fire, sea, extra, duplicate, damage, missile]


func test_buff_buttons_exist_for_owned_buff_scrolls() -> void:
	_own("buff/damage")
	_own("buff/duplicate_area")
	_screen.open(_inventory, _loadout)
	assert_eq(_screen.buff_button_count(), 2)


func test_buff_stepper_respects_ownership_and_caps() -> void:
	var damage := _own("buff/damage", 2)
	_screen.open(_inventory, _loadout)
	assert_true(_screen.add_buff(damage))
	assert_true(_screen.add_buff(damage))
	assert_false(_screen.add_buff(damage))
	assert_true(_screen.remove_buff(damage))
	assert_eq(_screen.session.buff_stacks(damage), 1)


func test_preview_shows_elements_shots_and_drawbacks() -> void:
	_hybrid_recipe()
	var text := _screen.preview_text()
	assert_true(text.contains("Fire+Sea"), text)
	assert_true(text.contains("Shots 2"), text)
	assert_true(text.contains("casts become"), text)
	assert_true(text.contains("Now: Fire Missile"), text)


func test_preview_hides_unused_lines() -> void:
	var fire := _own("base/fire")
	var missile := _own("area/missile")
	_screen.open(_inventory, _loadout)
	_screen.choose_base(fire)
	_screen.choose_area(missile)
	var text := _screen.preview_text()
	assert_false(text.contains("Ignores resistance"), text)
	assert_false(text.contains("Vulnerable bonus"), text)


func test_preview_shows_vulnerability_and_ignore_resistance_when_set() -> void:
	var fire := _own("base/fire")
	var missile := _own("area/missile")
	var vulnerable := _own("buff/double_vulnerability")
	var ignore := _own("buff/ignore_resistance")
	_screen.open(_inventory, _loadout)
	_screen.choose_base(fire)
	_screen.choose_area(missile)
	_screen.add_buff(vulnerable)
	_screen.add_buff(ignore)
	var text := _screen.preview_text()
	assert_true(text.contains("Vulnerable bonus x2.0"), text)
	assert_true(text.contains("Ignores resistance"), text)


func test_base_heading_shows_the_limit() -> void:
	var extra := _own("buff/additional_base")
	_own("base/fire")
	_screen.open(_inventory, _loadout)
	assert_true(_screen.base_heading_text().contains("0 of 1"), _screen.base_heading_text())
	_screen.choose_base(_scroll("base/fire"))
	assert_true(_screen.base_heading_text().contains("1 of 1"), _screen.base_heading_text())
	_screen.add_buff(extra)
	assert_true(_screen.base_heading_text().contains("1 of 2"), _screen.base_heading_text())


func test_confirm_is_disabled_until_the_extra_base_is_picked() -> void:
	var fire := _own("base/fire")
	var sea := _own("base/sea")
	var extra := _own("buff/additional_base")
	var missile := _own("area/missile")
	_screen.open(_inventory, _loadout)
	_screen.choose_area(missile)
	_screen.add_buff(extra)
	_screen.choose_base(fire)
	assert_false(_screen.confirm_enabled())
	assert_eq(_screen.message_text(), CraftingSystem.need_bases_reason(1))
	_screen.choose_base(sea)
	assert_true(_screen.confirm_enabled())


func test_removing_additional_base_updates_the_screen() -> void:
	var fire := _own("base/fire")
	var sea := _own("base/sea")
	var extra := _own("buff/additional_base")
	_screen.open(_inventory, _loadout)
	_screen.add_buff(extra)
	_screen.choose_base(fire)
	_screen.choose_base(sea)
	assert_eq(_screen.session.bases.size(), 2)
	_screen.remove_buff(extra)
	assert_eq(_screen.session.bases.size(), 1)
	assert_true(_screen.base_heading_text().contains("1 of 1"))


func test_full_hybrid_craft_through_the_screen() -> void:
	_hybrid_recipe()
	watch_signals(_screen)
	_screen.confirm()
	var spell := (_loadout.slots[0] as SpellInstance).data
	assert_eq(spell.elements, [SpellData.Element.FIRE, SpellData.Element.SEA])
	assert_eq(spell.copies, 2)
	assert_eq(spell.buff_stacks[&"buff_damage"], 2)
	assert_eq(_inventory.total_count(), 0)
	assert_false(_screen.is_open())
	assert_signal_emit_count(_screen, "closed", 1)


func test_huge_stacks_keep_the_preview_readable() -> void:
	var fire := _own("base/fire")
	var missile := _own("area/missile")
	var damage := _own("buff/damage", 40)
	_screen.open(_inventory, _loadout)
	_screen.choose_base(fire)
	_screen.choose_area(missile)
	for i in 40:
		_screen.add_buff(damage)
	var text := _screen.preview_text().to_lower()
	assert_false(text.contains("inf"), text)
	assert_false(text.contains("nan"), text)
	assert_true(text.contains("too costly"), text)


func test_focus_survives_a_stepper_becoming_disabled() -> void:
	var damage := _own("buff/damage")
	_screen.open(_inventory, _loadout)
	var plus := _screen._buff_grid.find_children("*", "Button", true, false).filter(
		func(button: Node) -> bool: return str(button.get_meta(&"key", "")) == "buff+:%s" % damage.id)[0] as Button
	plus.grab_focus()
	plus.pressed.emit()
	await wait_process_frames(2)
	var owner := _screen.get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "the last owned stack disabled the plus button")
	assert_false((owner as Button).disabled)


func _stock_everything() -> void:
	for category in ["base", "area", "buff"]:
		for file in DirAccess.get_files_at("res://resources/scrolls/%s" % category):
			if String(file).ends_with(".tres"):
				_inventory.add(_scroll("%s/%s" % [category, String(file).get_basename()]), 9)


func _wrapped(text: String, width: float) -> Vector2:
	return UiFont.plain().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, UiFont.SIZE, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY)


func _button_with_text(text: String) -> Button:
	for button in _screen.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null


func test_the_screen_sits_on_a_window_panel() -> void:
	_screen.open(_inventory, _loadout)
	assert_not_null(_screen.find_child("Window", true, false))
	assert_not_null(_screen.find_child("Backdrop", true, false))


func test_the_confirm_button_is_red_and_cancel_is_green() -> void:
	_screen.open(_inventory, _loadout)
	assert_eq(_button_with_text("Confirm").theme_type_variation, &"ButtonRed")
	assert_eq(_button_with_text("Cancel").theme_type_variation, &"ButtonGreen")


func test_the_chosen_scrolls_are_yellow_buttons() -> void:
	_inventory.add(_fire)
	_inventory.add(_missile)
	_screen.open(_inventory, _loadout)
	_screen.choose_base(_fire)
	var found := false
	for button in _screen.find_children("*", "Button", true, false):
		if str(button.get_meta(&"key", "")) == "scroll:%s" % _fire.id:
			found = true
			assert_eq((button as Button).theme_type_variation, &"ButtonYellow")
	assert_true(found, "the Fire button")


func test_no_crafting_widget_sets_a_font_size() -> void:
	_stock_everything()
	_screen.open(_inventory, _loadout)
	for node in _screen.find_children("*", "Control", true, false):
		assert_false((node as Control).has_theme_font_size_override("font_size"), str(node.name))


func test_the_preview_and_drawbacks_fit_the_preview_panel() -> void:
	_stock_everything()
	_screen.open(_inventory, _loadout)
	_screen.add_buff(_scroll("buff/additional_base"))
	_screen.choose_base(_fire)
	_screen.choose_base(_thunder)
	_screen.choose_area(_wave)
	for id in ["damage", "double_vulnerability", "duplicate_area", "ignore_resistance", "max_mana"]:
		_screen.add_buff(_scroll("buff/%s" % id))
	var size := _wrapped(_screen.preview_text(), CraftingScreen.PREVIEW_SIZE.x)
	assert_lte(size.y, CraftingScreen.PREVIEW_SIZE.y, "the whole preview is inside its panel")
	assert_lte(_screen.preview_height(), CraftingScreen.PREVIEW_SIZE.y, "and so is the label that really draws it")
	assert_lte(_wrapped(_screen.message_text(), CraftingScreen.MESSAGE_SIZE.x).y, CraftingScreen.MESSAGE_SIZE.y)


func test_every_scroll_and_slot_button_text_fits_its_button() -> void:
	_stock_everything()
	_screen.open(_inventory, _loadout)
	for button in _screen.find_children("*", "Button", true, false):
		var text := (button as Button).text
		if text in ["Confirm", "Cancel", "-", "+"]:
			continue
		for line in text.split("\n"):
			var width := UiFont.plain().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
			assert_lte(width, (button as Button).custom_minimum_size.x - 8.0, line)


func test_a_buff_name_fits_beside_its_steppers() -> void:
	_stock_everything()
	_screen.open(_inventory, _loadout)
	for scroll in _screen.session.owned_buffs():
		var width := UiFont.plain().get_string_size(scroll.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
		assert_lte(width, CraftingScreen.BUFF_NAME_WIDTH, scroll.display_name)


func _long_named_loadout() -> SpellLoadout:
	var spells: Array[SpellData] = []
	for i in 5:
		var spell := (load("res://resources/spells/fire_missile.tres") as SpellData).duplicate() as SpellData
		spell.display_name = "Fire+Thunder Missile (Very long)"
		spells.append(spell)
	var loadout := SpellLoadout.new()
	loadout.starting_spells = spells
	loadout.unlocked_slots = 5
	loadout.projectile_root = _root
	add_child_autofree(loadout)
	return loadout


func test_long_spell_names_never_push_the_slot_row_off_the_screen() -> void:
	var loadout := _long_named_loadout()
	_screen.open(_inventory, loadout)
	for button in _screen.find_children("*", "Button", true, false):
		if str((button as Button).get_meta(&"key", "")).begins_with("slot:"):
			assert_lte((button as Button).get_combined_minimum_size().x, CraftingScreen.SLOT_SIZE.x, "a slot button keeps its width, the text is clipped")
	var row_width := 0.0
	for button in _screen.find_children("*", "Button", true, false):
		if str((button as Button).get_meta(&"key", "")).begins_with("slot:"):
			row_width += (button as Button).get_combined_minimum_size().x + 2.0
	assert_lte(row_width + 8.0, 480.0, "five slots fit across the screen")


func test_the_preview_of_a_long_named_replacement_at_very_long_range_fits_and_clears_the_message() -> void:
	_stock_everything()
	var loadout := _long_named_loadout()
	_screen.open(_inventory, loadout)
	_screen.add_buff(_scroll("buff/additional_base"))
	_screen.choose_base(_fire)
	_screen.choose_base(_thunder)
	_screen.choose_area(_wave)
	_screen.choose_range(3)
	for id in ["damage", "double_vulnerability", "duplicate_area", "ignore_resistance", "max_mana"]:
		_screen.add_buff(_scroll("buff/%s" % id))
	assert_lte(_screen.preview_height(), CraftingScreen.PREVIEW_SIZE.y, "the real label fits its box")
	assert_lte(CraftingScreen.PREVIEW_TOP + CraftingScreen.PREVIEW_SIZE.y, CraftingScreen.MESSAGE_TOP, "the message starts below the preview")


func test_every_refusal_message_fits_the_message_box() -> void:
	for reason in [CraftingSystem.REASON_NO_BASE, CraftingSystem.REASON_NO_AREA, CraftingSystem.REASON_WRONG_BASE, CraftingSystem.REASON_WRONG_AREA, CraftingSystem.REASON_BAD_RANGE, CraftingSystem.REASON_BAD_BUFF, CraftingSystem.REASON_STACK_CAP, CraftingSystem.REASON_TOO_MANY_BASES, CraftingSystem.REASON_DUPLICATE_ELEMENT, CraftingSystem.REASON_LOCKED_SLOT, CraftingSystem.REASON_MISSING, CraftingSystem.REASON_CANNOT_BUILD, CraftingSystem.REASON_TOO_COSTLY]:
		assert_lte(_wrapped(reason, CraftingScreen.MESSAGE_SIZE.x).y, CraftingScreen.MESSAGE_SIZE.y, reason)
	assert_lte(CraftingScreen.MESSAGE_TOP + CraftingScreen.MESSAGE_SIZE.y, CraftingScreen.BUTTONS_TOP, "the message ends above the buttons")
