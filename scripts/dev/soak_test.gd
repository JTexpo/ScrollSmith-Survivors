extends SceneTree
## Developer tool: plays the game for many rounds and prints the engine's node, object, orphan and memory counts after each, then a
## verdict on whether the run stayed flat. Run with a fixed frame rate so the simulated time is steady:
##   godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600
## Options: --rounds=N (default 12), --frames=N per round (default 600), --warmup=N (default 3), --band=F (default 0.1).


func _init() -> void:
	var rounds := 12
	var frames := 600
	var warmup := 3
	var band := SoakRun.DEFAULT_BAND
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rounds="):
			rounds = int(argument.get_slice("=", 1))
		elif argument.begins_with("--frames="):
			frames = int(argument.get_slice("=", 1))
		elif argument.begins_with("--warmup="):
			warmup = int(argument.get_slice("=", 1))
		elif argument.begins_with("--band="):
			band = float(argument.get_slice("=", 1))
	# The tree is not running inside _init yet, so wait one frame before adding nodes that use it.
	await process_frame
	var driver := SoakDriver.new()
	root.add_child(driver)
	var samples := await driver.run(rounds, frames)
	for sample in samples:
		print("SOAK round=%d nodes=%d objects=%d orphans=%d static_mb=%.1f" % [sample["round"], sample["nodes"], sample["objects"], sample["orphans"], sample["static_mb"]])
	var verdict := SoakRun.verdict(samples, warmup, band)
	if verdict["ok"]:
		print("SOAK PASS")
	else:
		print("SOAK FAIL %s" % ", ".join(verdict["problems"]))
	quit(0 if verdict["ok"] else 1)
