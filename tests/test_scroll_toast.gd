extends GutTest

var _toast: ScrollToast


func _scroll(display_name: String, color: Color) -> ScrollData:
	var scroll := ScrollData.new()
	scroll.display_name = display_name
	scroll.color = color
	return scroll


func before_each() -> void:
	_toast = load("res://scenes/ui/scroll_toast.tscn").instantiate() as ScrollToast
	add_child_autofree(_toast)


func test_toast_starts_hidden_and_idle() -> void:
	assert_false(_toast.is_showing())
	assert_false(_toast.is_processing())


func test_toast_shows_text_and_colour() -> void:
	_toast.show_scroll(_scroll("Fire", Color(1, 0.45, 0.1)))
	assert_true(_toast.is_showing())
	assert_eq(_toast.text, "+ Fire Scroll")
	assert_eq(_toast.get_theme_color("font_color"), Color(1, 0.45, 0.1))
	assert_eq(_toast.modulate.a, 1.0)


func test_toast_fades_and_hides_and_stops_processing() -> void:
	_toast.show_scroll(_scroll("Fire", Color.WHITE))
	_toast._process(ScrollToast.DURATION - 0.2)
	assert_true(_toast.is_showing())
	assert_lt(_toast.modulate.a, 1.0)
	_toast._process(0.3)
	assert_false(_toast.is_showing())
	assert_false(_toast.is_processing())


func test_a_new_pickup_replaces_the_text_and_restarts_the_timer() -> void:
	_toast.show_scroll(_scroll("Fire", Color.WHITE))
	_toast._process(ScrollToast.DURATION - 0.1)
	_toast.show_scroll(_scroll("Sea", Color(0.2, 0.55, 1)))
	assert_eq(_toast.text, "+ Sea Scroll")
	assert_eq(_toast.modulate.a, 1.0)
	_toast._process(0.5)
	assert_true(_toast.is_showing())


func test_the_scroll_toast_is_a_dark_pill_and_keeps_the_scrolls_colour() -> void:
	_toast.show_scroll(_scroll("Fire", Color(1, 0.45, 0.1)))
	assert_eq(_toast.theme_type_variation, &"HudToast")
	assert_eq(_toast.get_theme_color("font_color"), Color(1, 0.45, 0.1))
