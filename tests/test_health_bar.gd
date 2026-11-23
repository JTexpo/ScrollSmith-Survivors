extends GutTest


func test_ratio_follows_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	add_child_autofree(health)
	var bar := load("res://scenes/ui/health_bar.tscn").instantiate() as HealthBar
	add_child_autofree(bar)
	bar.bind(health)
	assert_eq(bar.ratio, 1.0)
	health.take_damage(25.0)
	assert_eq(bar.ratio, 0.75)
	health.take_damage(1000.0)
	assert_eq(bar.ratio, 0.0)


func _bar_node() -> HealthBar:
	var bar := load("res://scenes/ui/health_bar.tscn").instantiate() as HealthBar
	add_child_autofree(bar)
	return bar


func test_the_bar_shows_a_heart_and_no_placeholder_text() -> void:
	var bar := _bar_node()
	for label in bar.find_children("*", "Label", true, false):
		assert_false((label as Label).text.to_upper().contains("TEMP"), "placeholder text %s" % (label as Label).text)
	assert_false(bar.has_node("TempLabel"))
	assert_eq((bar.get_node("Icon") as TextureRect).texture, SpriteLibrary.find(&"icon_heart").sheet)


func test_the_health_bar_is_a_themed_progress_bar_whose_value_follows_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	add_child_autofree(health)
	var bar := _bar_node()
	bar.bind(health)
	var themed := bar.get_node("Bar") as ProgressBar
	assert_eq(themed.theme_type_variation, &"BarHp")
	assert_eq(themed.value, 1.0)
	health.take_damage(25.0)
	assert_eq(themed.value, 0.75)
	assert_eq(bar.ratio, 0.75)


func test_beat_shows_the_beat_heart_briefly_then_the_normal_one() -> void:
	var bar := _bar_node()
	var normal := SpriteLibrary.find(&"icon_heart").sheet
	var beating := SpriteLibrary.find(&"icon_heart_beat").sheet
	assert_eq(bar.heart_texture(), normal)
	bar.beat()
	assert_eq(bar.heart_texture(), beating)
	bar._process(0.05)
	assert_eq(bar.heart_texture(), beating)
	bar._process(0.2)
	assert_eq(bar.heart_texture(), normal)
	assert_false(bar.is_processing(), "it only processes while the beat shows")
