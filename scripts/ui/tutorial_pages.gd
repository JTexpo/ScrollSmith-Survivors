class_name TutorialPages
extends RefCounted
## The four Tutorial pages. The key names are read from the Input Map (`ControlsText`), so the pages can never disagree with the real
## bindings. Edit the wording here.


static func pages() -> Array[TutorialPage]:
	var move := ControlsText.keys_for([&"move_up", &"move_left", &"move_down", &"move_right"])
	var cast := ControlsText.key_for(&"cast")
	var interact := ControlsText.key_for(&"interact")
	return [
		TutorialPage.make("Survive!", [
			"Stay alive as long as you can while enemies close in.",
			"Move with %s, or the left stick." % move,
			"Walk over XP and Gold to collect them.",
		], [&"player", &"pickup_xp", &"pickup_gold"]),
		TutorialPage.make("Cast spells", [
			"Aim with the mouse or the right stick, cast with %s." % cast,
			"Pick a spell with 1 to 5, or tap its slot.",
			"Mana never comes back: a spell is a number of casts.",
		], [&"player", &"reticle"]),
		TutorialPage.make("Scrolls and the Lectern", [
			"Enemies drop scrolls: a Base (element), an Area, a Buff.",
			"At a Lectern press %s to craft one Base and one Area." % interact,
			"Buffs are optional, but every one costs more mana.",
		], [&"scroll_base", &"scroll_area", &"scroll_buff", &"lectern"]),
		TutorialPage.make("Potions and the shop", [
			"Merchants sell potions for Gold: 3 of each, for one run.",
			"Drink them with Z X C V B N, or tap a slot.",
			"Spend Gold on equipment in the Shop on the home screen.",
		], [&"icon_potion", &"poi_merchant", &"icon_coin"]),
	]
