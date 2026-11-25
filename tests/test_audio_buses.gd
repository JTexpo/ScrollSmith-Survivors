extends GutTest
## The Music and Sfx buses come from a layout the project loads at start, never from `AudioServer.add_bus()` at run time.
## Why: in Godot 4.7.2 a web export plays sounds as samples through its own bus graph, and a bus added at run time (always
## position -1) is moved to the wrong place by the engine's script, which reverses the bus order. The first sends then form a
## loop, and a loop in Web Audio is muted, so the whole web build was silent (measured in a browser: output level exactly 0);
## with the layout the graph is correct and mute, volumes and sound all work.

const LAYOUT_SETTING := "audio/buses/default_bus_layout"


func _layout() -> AudioBusLayout:
	var path := String(ProjectSettings.get_setting(LAYOUT_SETTING, ""))
	assert_ne(path, "", "the project must name a default bus layout")
	return load(path) as AudioBusLayout if path != "" else null


func test_the_project_declares_a_layout_with_music_and_sfx_sending_to_master() -> void:
	var layout := _layout()
	assert_not_null(layout)
	if layout == null:
		return
	assert_eq(layout.get("bus/1/name"), &"Music")
	assert_eq(layout.get("bus/1/send"), &"Master")
	assert_eq(layout.get("bus/2/name"), &"Sfx")
	assert_eq(layout.get("bus/2/send"), &"Master")


func test_the_buses_exist_in_the_engine_in_master_music_sfx_order() -> void:
	assert_eq(AudioServer.get_bus_index("Master"), 0)
	assert_eq(AudioServer.get_bus_index("Music"), 1)
	assert_eq(AudioServer.get_bus_index("Sfx"), 2)
	assert_eq(AudioServer.get_bus_send(1), &"Master")
	assert_eq(AudioServer.get_bus_send(2), &"Master")


func test_the_sound_board_never_adds_buses_or_changes_sends_at_run_time() -> void:
	var lines := FileAccess.get_file_as_string("res://scripts/audio/sound_board.gd").split("\n")
	for line in lines:
		var code := String(line).strip_edges()
		if code.begins_with("#"):
			continue
		assert_false(code.contains("add_bus("), "a bus added at run time reverses the bus order on the web: put it in default_bus_layout.tres")
		assert_false(code.contains("set_bus_send("), "set_bus_send at run time loops the buses on the web: put it in default_bus_layout.tres")
