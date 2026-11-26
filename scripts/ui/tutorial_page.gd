class_name TutorialPage
extends RefCounted
## One page of the Tutorial: a title, a few short lines and a looping vignette (a `StageScript`). A page with no vignette shows the row of
## sprites instead.

var title: String = ""
var lines: Array[String] = []
var sprites: Array[StringName] = []
var vignette: StageScript


static func make(page_title: String, page_lines: Array[String], page_sprites: Array[StringName], page_vignette: StageScript = null) -> TutorialPage:
	var page := TutorialPage.new()
	page.title = page_title
	page.lines = page_lines
	page.sprites = page_sprites
	page.vignette = page_vignette
	return page
