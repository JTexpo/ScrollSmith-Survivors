extends GutTest
## The light touches: pickup sparks, the level-up stars and the Rare-drop sparkle, all from the director and the one burst layer.

var _burst: BurstLayer
var _director: FxDirector
var _world: Node2D


func before_each() -> void:
	FxSettings.reset()
	_burst = BurstLayer.new()
	add_child_autofree(_burst)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	var shake := CameraShake.new()
	add_child_autofree(shake)
	shake.bind(camera)
	var flash := ScreenFlash.new()
	add_child_autofree(flash)
	_world = Node2D.new()
	_world.position = Vector2(200, 150)
	add_child_autofree(_world)
	_director = FxDirector.new()
	add_child_autofree(_director)
	_director.setup(_burst, shake, flash)
	_director.setup_world(_world)


func after_each() -> void:
	FxSettings.reset()


func _colors() -> Array[Color]:
	var found: Array[Color] = []
	for particle in _burst.live_particles():
		found.append(particle["color"])
	return found


func test_collecting_a_scroll_sparks_in_its_colour() -> void:
	var scroll := load("res://resources/scrolls/base/fire.tres") as ScrollData
	_director.on_scroll_collected(scroll)
	assert_eq(_burst.active_count(), FxDirector.PICKUP_SPARKS)
	for color in _colors():
		assert_true(color.is_equal_approx(scroll.color) or color.is_equal_approx(scroll.color.lightened(0.4)), "the scroll's own colour and a lighter one")


func test_xp_sparks_are_blue_and_gold_sparks_are_yellow() -> void:
	_director.on_xp_collected()
	for color in _colors():
		assert_gt(color.b, color.r, "XP is blue")
	_burst.burst(Vector2.ZERO, &"sparkle", [Color.WHITE], 0)
	var gold_burst := BurstLayer.new()
	add_child_autofree(gold_burst)
	var other := FxDirector.new()
	add_child_autofree(other)
	other.setup(gold_burst, null, null)
	other.setup_world(_world)
	other.on_gold_collected()
	for particle in gold_burst.live_particles():
		var color: Color = particle["color"]
		assert_gt(color.r, color.b, "Gold is yellow")
		assert_gt(color.g, color.b)


func test_the_sparks_appear_where_the_player_is() -> void:
	_director.on_xp_collected()
	for particle in _burst.live_particles():
		assert_lt(particle["position"].distance_to(_world.global_position), 8.0)


func test_a_level_up_bursts_stars_round_the_player() -> void:
	_director.on_level_up()
	var twinkles := 0
	for particle in _burst.live_particles():
		if particle["kind"] == ParticlePool.TWINKLE:
			twinkles += 1
	assert_gte(twinkles, FxDirector.LEVEL_STARS)
	assert_gt(_burst.active_count(), FxDirector.LEVEL_STARS, "plus a ring of dust")


func test_a_rare_scroll_drop_sparkles_where_it_lands_and_a_common_one_does_not() -> void:
	var rare := load("res://resources/scrolls/buff/additional_base.tres") as ScrollData
	assert_eq(rare.rarity, ScrollData.Rarity.RARE)
	_director.on_scroll_placed(rare, Vector2(300, 80))
	assert_eq(_burst.active_count(), FxDirector.RARE_SPARKLES)
	for particle in _burst.live_particles():
		assert_eq(particle["kind"], ParticlePool.TWINKLE)
		assert_lt(particle["position"].distance_to(Vector2(300, 80)), 10.0)
	_director.begin_frame()
	var before := _burst.active_count()
	var common := load("res://resources/scrolls/base/fire.tres") as ScrollData
	assert_eq(common.rarity, ScrollData.Rarity.COMMON)
	_director.on_scroll_placed(common, Vector2(300, 80))
	assert_eq(_burst.active_count(), before)


func test_many_pickups_in_a_frame_stay_under_the_pool_cap_and_the_frame_budget() -> void:
	var scroll := load("res://resources/scrolls/base/fire.tres") as ScrollData
	for i in 400:
		_director.on_scroll_collected(scroll)
		_director.on_xp_collected()
		_director.on_level_up()
	assert_lte(_burst.active_count(), BurstLayer.CAPACITY)
	assert_lte(_director.bursts_made(), FxDirector.MAX_BURSTS_PER_FRAME)


func test_particles_off_turns_every_light_touch_off() -> void:
	FxSettings.particles = false
	var scroll := load("res://resources/scrolls/buff/additional_base.tres") as ScrollData
	_director.on_scroll_collected(scroll)
	_director.on_xp_collected()
	_director.on_gold_collected()
	_director.on_level_up()
	_director.on_scroll_placed(scroll, Vector2.ZERO)
	assert_eq(_burst.active_count(), 0)


func test_real_signals_reach_the_director_through_main() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = ""
	for screen in ["BuffPickScreen", "CraftingScreen", "MerchantScreen"]:
		main.get_node(screen).pause_tree = false
	add_child_autofree(main)
	var layer := main.get_node("BurstLayer") as BurstLayer
	var player := main.get_node("Player") as Player
	player.collector.xp_collected.emit(3)
	assert_gt(layer.active_count(), 0)
	main.get_node("FxDirector").begin_frame()
	var before := layer.active_count()
	player.progress.leveled_up.emit(2, LevelTrack.default_track().reward_for_level(2))
	assert_gt(layer.active_count(), before)
	main.get_node("FxDirector").begin_frame()
	before = layer.active_count()
	var dropper := main.get_node("ScrollDropper") as ScrollDropper
	dropper.place(load("res://resources/scrolls/buff/additional_base.tres") as ScrollData, Vector2(120, 120))
	assert_gt(layer.active_count(), before, "a Rare drop sparkles")
