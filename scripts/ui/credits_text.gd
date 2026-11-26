class_name CreditsText
extends RefCounted
## The Credits page. Edit the lines here. Page room is about 20 lines of ASCII (the font has no other characters).


static func lines() -> Array[String]:
	var result: Array[String] = [
		"ScrollSmith Survivors",
		"Version %s" % GameVersion.current(),
		"",
		"Made by JTexpo",
		"Copyright 2026 JTexpo. All rights reserved.",
		"Art, music and sound: made with the game's own tools",
		"Made with Godot 4 (MIT licence) and GUT",
		"Full licences: licences.txt, next to the game",
		"",
		"Thank you for playing!",
	]
	return result
