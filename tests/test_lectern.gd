extends GutTest

const SCENE := "res://scenes/interactables/lectern.tscn"


func _lectern() -> Lectern:
	var lectern := (load(SCENE) as PackedScene).instantiate() as Lectern
	add_child_autofree(lectern)
	return lectern


func test_lectern_is_passive_on_the_interactable_layer() -> void:
	var lectern := _lectern()
	assert_false(lectern.monitoring)
	assert_eq(lectern.collision_layer, PhysicsLayers.INTERACTABLE)
	assert_eq(lectern.collision_mask, 0)


func test_interact_emits_with_the_actor() -> void:
	var lectern := _lectern()
	var actor := Node.new()
	add_child_autofree(actor)
	watch_signals(lectern)
	lectern.interact(actor)
	assert_signal_emit_count(lectern, "interacted", 1)
	assert_signal_emitted_with_parameters(lectern, "interacted", [actor])


func test_prompt_starts_hidden_and_toggles() -> void:
	var lectern := _lectern()
	var prompt := lectern.get_node("Prompt") as Label
	assert_false(prompt.visible)
	lectern.set_prompt_visible(true)
	assert_true(prompt.visible)
	lectern.set_prompt_visible(false)
	assert_false(prompt.visible)


func test_lectern_joins_the_group() -> void:
	assert_true(_lectern().is_in_group(&"lecterns"))


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"


func test_the_lectern_has_art_and_a_glow() -> void:
	var body := _lectern().get_node("Body") as BodyView
	assert_true(body.has_art())
	assert_true(body.has_animation(&"idle"))
	assert_eq(body.current_animation(), &"idle")


func test_the_lectern_without_art_shows_the_fallback_square() -> void:
	SpriteLibrary.root = "res://.godot/art_tests/no_such_folder"
	var body := _lectern().get_node("Body") as BodyView
	assert_false(body.has_art())
	assert_true((body.get_node("Fallback") as ColorRect).visible)


func test_the_prompt_uses_the_outlined_hud_label() -> void:
	var prompt := _lectern().get_node("Prompt") as Label
	assert_eq(prompt.theme_type_variation, &"HudLabel")
