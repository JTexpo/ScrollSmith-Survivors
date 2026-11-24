class_name SoakRun
extends RefCounted
## The maths of the soak test. A soak run plays the game for many rounds and takes a `take` sample of the engine's node, object, orphan
## and memory counts after each one; `verdict` says whether the run stayed flat (no leak). Pure and independent of time and frame rate.

## How far a count may drift from its first post-warm-up value (a fraction), unless the caller says otherwise.
const DEFAULT_BAND := 0.1
## A steady climb of more than this fraction of the base per round over the second half of the run is a leak even inside the band.
const SLOPE_LIMIT := 0.005
## Orphan nodes (never added to the tree) may wobble by this many before it counts as growth.
const ORPHAN_TOLERANCE := 2.0
## The post-warm-up samples needed for a meaningful verdict.
const MIN_SAMPLES_AFTER_WARMUP := 4
const KEYS := ["nodes", "objects", "static_mb"]


## One sample of the engine's counters for round `round_number`.
static func take(round_number: int) -> Dictionary:
	return {
		"round": round_number,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}


## The least-squares slope of the values against their position (units per round). Zero for fewer than two values.
static func trend_slope(values: Array[float]) -> float:
	var n := values.size()
	if n < 2:
		return 0.0
	var mean_x := (n - 1) / 2.0
	var mean_y := 0.0
	for v in values:
		mean_y += v
	mean_y /= n
	var top := 0.0
	var bottom := 0.0
	for i in n:
		top += (i - mean_x) * (values[i] - mean_y)
		bottom += (i - mean_x) * (i - mean_x)
	return top / bottom if bottom > 0.0 else 0.0


## `{"ok": bool, "problems": PackedStringArray}`. After `warmup` rounds every count must stay within `band` of the first post-warm-up
## value, orphans must not grow, and no count may climb steadily over the second half of the run.
static func verdict(samples: Array[Dictionary], warmup: int, band: float = DEFAULT_BAND) -> Dictionary:
	var problems := PackedStringArray()
	if samples.size() < warmup + MIN_SAMPLES_AFTER_WARMUP:
		problems.append("too few samples: %d (need %d)" % [samples.size(), warmup + MIN_SAMPLES_AFTER_WARMUP])
		return {"ok": false, "problems": problems}
	var after := samples.slice(warmup)
	var base: Dictionary = after[0]
	for key in KEYS:
		var start := float(base[key])
		var series: Array[float] = []
		for sample in after:
			var value := float(sample[key])
			series.append(value)
			if start > 0.0 and absf(value - start) / start > band:
				problems.append("%s left its band: %.1f against %.1f at round %d" % [key, value, start, int(sample["round"])])
				break
		var half := series.slice(series.size() / 2)
		if start > 0.0 and trend_slope(half) / start > SLOPE_LIMIT:
			problems.append("%s keeps climbing (%.2f per round)" % [key, trend_slope(half)])
	for sample in after:
		if float(sample["orphans"]) > float(base["orphans"]) + ORPHAN_TOLERANCE:
			problems.append("orphan nodes grew to %d at round %d" % [int(sample["orphans"]), int(sample["round"])])
			break
	return {"ok": problems.is_empty(), "problems": problems}
