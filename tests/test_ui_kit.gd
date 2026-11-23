extends GutTest


func test_a_label_ignores_the_mouse_and_takes_the_text_and_variation() -> void:
	var label := UiKit.label("Gold 5", &"HudGold")
	autofree(label)
	assert_eq(label.text, "Gold 5")
	assert_eq(label.theme_type_variation, &"HudGold")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_label_without_a_variation_keeps_the_default_type() -> void:
	var label := UiKit.label("x")
	autofree(label)
	assert_eq(label.theme_type_variation, &"")


func test_a_button_can_take_focus_and_takes_the_text_and_variation() -> void:
	var button := UiKit.button("Buy", &"ButtonRed")
	autofree(button)
	assert_eq(button.text, "Buy")
	assert_eq(button.theme_type_variation, &"ButtonRed")
	assert_eq(button.focus_mode, Control.FOCUS_ALL)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_a_bar_hides_its_percentage_and_ignores_the_mouse() -> void:
	var bar := UiKit.bar(&"BarHp")
	autofree(bar)
	assert_false(bar.show_percentage)
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(bar.theme_type_variation, &"BarHp")
	assert_eq(bar.max_value, 1.0)
	assert_eq(bar.step, 0.0)


func test_an_icon_shows_the_sprites_sheet_at_one_to_one_and_ignores_the_mouse() -> void:
	var icon := UiKit.icon(&"icon_heart")
	autofree(icon)
	assert_eq(icon.texture, SpriteLibrary.find(&"icon_heart").sheet)
	assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP)
	assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_an_icon_with_no_art_is_an_empty_rect_not_a_crash() -> void:
	var icon := UiKit.icon(&"no_such_icon")
	autofree(icon)
	assert_null(icon.texture)


func test_a_window_adds_a_backdrop_a_cream_panel_and_returns_the_content_area() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var content := UiKit.window(parent)
	assert_eq(content.get_parent(), parent)
	assert_not_null(parent.get_node_or_null("Backdrop"))
	var panel := parent.get_node("Window") as Panel
	assert_eq(panel.get_rect(), UiKit.WINDOW_RECT)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(content.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(parent.get_child(0).name, &"Backdrop", "the backdrop is behind the panel")
	assert_eq(parent.get_child(1).name, &"Window")
