class_name TutorialPage
extends RefCounted
## One page of the Tutorial: a title, a few short lines and the sprites drawn on it.

var title: String = ""
var lines: Array[String] = []
var sprites: Array[StringName] = []


static func make(page_title: String, page_lines: Array[String], page_sprites: Array[StringName]) -> TutorialPage:
	var page := TutorialPage.new()
	page.title = page_title
	page.lines = page_lines
	page.sprites = page_sprites
	return page
