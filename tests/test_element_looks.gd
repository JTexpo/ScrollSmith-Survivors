extends GutTest


func test_each_element_has_a_look_with_its_sprites_and_direction() -> void:
	var expected := {
		SpellData.Element.FIRE: true,
		SpellData.Element.LAND: true,
		SpellData.Element.THUNDER: false,
		SpellData.Element.SEA: false,
	}
	for element in expected:
		var look := ElementLooks.for_element(element)
		assert_not_null(look, "element %d has a look" % element)
		assert_eq(look.element, element)
		assert_eq(look.rises, expected[element], "Fire and Land rise, Thunder and Sea fall")
		assert_true(String(look.effect_sprite).begins_with("fx_"))
		assert_true(String(look.orb_sprite).begins_with("fx_"))
		assert_gt(look.tint.a, 0.0)
		assert_lt(look.tint.a, 0.5, "the tint is faint, the sprites carry the look")
		assert_eq(look.edge.a, 1.0)


func test_the_four_looks_differ() -> void:
	var seen := {}
	for element in [SpellData.Element.FIRE, SpellData.Element.THUNDER, SpellData.Element.LAND, SpellData.Element.SEA]:
		var look := ElementLooks.for_element(element)
		seen[look.effect_sprite] = true
		seen[look.orb_sprite] = true
	assert_eq(seen.size(), 8, "every element has its own effect and its own orb")


func test_no_element_and_unknown_values_have_no_look() -> void:
	assert_null(ElementLooks.for_element(SpellData.NO_ELEMENT))
	assert_null(ElementLooks.for_element(99))
	assert_null(ElementLooks.for_element(-7))


func test_the_looks_are_cached() -> void:
	assert_same(ElementLooks.for_element(SpellData.Element.FIRE), ElementLooks.for_element(SpellData.Element.FIRE))
