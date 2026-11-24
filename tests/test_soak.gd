extends GutTest
## A short soak: a few rounds of the whole game running (crowd, every Area, pickups, level-ups, potions, a boss, a death and a restart),
## sampled each round. A healthy run stays flat; a deliberate leak must fail the same verdict, which proves the check can fail.

const ROUNDS := 8
const FRAMES := 90
## Looser than the tool's default (0.5% of the base per round): over only four samples one straggling node looks like a climb. The test's
## deliberate leak adds hundreds of nodes a round, far above this.
const SLOPE_LIMIT := 0.02


func _run(leak: bool) -> Array[Dictionary]:
	var driver := SoakDriver.new()
	driver.leak_a_node_per_frame = leak
	add_child_autofree(driver)
	return await driver.run(ROUNDS, FRAMES)


func test_a_short_run_stays_flat() -> void:
	var samples := await _run(false)
	assert_eq(samples.size(), ROUNDS)
	var verdict := SoakRun.verdict(samples, 3, 0.5, SLOPE_LIMIT)
	assert_true(verdict["ok"], "%s %s" % [str(verdict["problems"]), str(samples)])


func test_a_deliberate_leak_fails_the_verdict() -> void:
	var samples := await _run(true)
	var verdict := SoakRun.verdict(samples, 3, 0.5, SLOPE_LIMIT)
	assert_false(verdict["ok"], "the check must catch a node added every frame")
