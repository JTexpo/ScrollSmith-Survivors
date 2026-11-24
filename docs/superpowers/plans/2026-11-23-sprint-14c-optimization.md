# Sprint 14c: Optimization, Soak and a Testing Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The game can report its own speed (an overlay testers open on a phone), a soak test proves a long run does not grow, the Sprint 14 test list is checked for gaps, the cheap deferred minors are fixed, and anything the measurements show slow is optimized.

**Architecture:** `PerfOverlay` (a `CanvasLayer` in `main.tscn`) reads engine counters and shows one line; a new `FxSettings.perf_overlay` switch is its single source of truth, flipped by F3 or by a long press on `MuteButton` (which gains hold detection). `SoakRun` holds the pure sampling and trend maths, `scripts/dev/soak_test.gd` drives a long simulated run, and a short version runs in the suite. Optimization is driven by the numbers.

**Tech Stack:** Godot 4.7 GDScript, GUT, the existing stress scene.

**Spec:** `sprint-14c-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After adding a `class_name`, run `godot --headless --import`.
- No balance, feature or gameplay change. The overlay, the soak tool and the optimizations must not change how anything plays. Only the dev tools and the overlay are new.
- The overlay reads engine counters only and is off by default; `FxSettings.perf_overlay` (default **false**, unlike every other switch) is its one source of truth. Gameplay never calls it, and `test_fx_guards` must stay green (add `PerfOverlay` to its allowed list only if that test scans for it).
- The mute button must still mute on a tap and must not mute on a long press. Touch checks must also be made in a real window (the project's touch rule), not only headless.
- Tests never touch the real save (`save_path = ""`, the pick screen's `pause_tree = false`). Soak and stress runs never depend on wall-clock time for their verdict.
- Every optimization needs a before and after number from the stress scene (`--enemies=300 --seconds=8`, three runs each, with `--obstacles --drops`, with `--boss --fx`, and `--area=missile`); a change that is not shown faster is reverted.
- UI text is ASCII and uses the theme (`tests/test_ui_look.gd` fails on a font override).

## Review Focus

- An overlay that costs frames or leaks: it must do no per-frame allocation and no work while hidden, refresh at a fixed rate, and ignore touches (`mouse_filter` ignore, so it never swallows a tap).
- The mute button's new tap-on-release behaviour: a tap still mutes exactly once (touch and left click), a long press never also mutes, a finger drifting off the button before release does not mute and does not leave the hold running, a second finger or a pause in the middle does not break it, and Main still blocks casting until the press is released.
- A soak test that cannot fail: it must be shown to fail on a deliberate leak, must sample after the warm-up, and must not depend on frame rate or wall-clock time. A restart must return the counts near a fresh start.
- Anything pooled or cached by an optimization that survives a restart or a death with stale state.
- The minors: the burst spawns only into a still-valid parent and `burst_spawned` fires with the burst already in the tree; `SpellAudit.rows()` skips a missing scroll instead of crashing; the merchant prompt fits its label; the old-save cash-in toast shows once.

---

### Task 1: The deferred minors

**Files:**
- Modify: `scripts/spells/areas/missile_area.gd`, `scripts/systems/spell_audit.gd`, `scenes/interactables/point_of_interest.tscn`, `scripts/main/main.gd`, `CLAUDE.md`, `technical-design.md`, `sprint-development.md`
- Test: `tests/test_missile_burst.gd`, `tests/test_spell_audit.gd`, `tests/test_point_of_interest.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Produces: `MissileArea._end` spawns the burst only if its parent is still valid and in the tree (else frees the burst), and emits `burst_spawned(burst)` after `add_child` and `launch`; `SpellAudit.rows()` skips a scroll that fails to load (no crash) and finds the Normal range option by label `"Normal"`; the `Prompt` label of `point_of_interest.tscn` is 120 px wide; `Main` shows a toast `"Your old potions were sold for N Gold."` when `ShopSystem.cash_in_legacy_potions` returned more than 0.

- [ ] **Step 1: Write the failing tests:** `test_missile_burst`: `test_a_burst_is_not_added_when_the_parent_is_freed_first` (free the parent before the deferred call runs; no error, no orphan burst) and `test_burst_spawned_fires_with_the_burst_already_in_the_tree` (in the signal handler `burst.is_inside_tree()` is true and `burst.get_node("Hitbox")` is valid); `test_spell_audit`: `test_a_missing_scroll_is_skipped_not_a_crash` (call a new `SpellAudit.row_for_scroll_paths`-style seam, or temporarily point `BASES` at a missing name through a parameter, as the builder chooses, and assert the other rows still come back) and `test_the_normal_option_is_found_by_its_label`; `test_point_of_interest`: `test_the_merchant_prompt_fits_its_label` (`UiFont.plain()` width of "Merchant (E) 5:00" and "Treasure Chest 5:00" is at most the Prompt label's width minus 4); `test_main_progression`: `test_cashing_in_old_potions_shows_a_toast_once` (an old-format save with `potions` makes the level toast show "sold for N Gold" at start; a second start shows none). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the four fixes as listed under Interfaces. `SpellAudit` finds Normal with a loop over `range_options` comparing `label`.
- [ ] **Step 3: Docs.** `CLAUDE.md` (the impact-weight sentence: the Fire Missile weighs about 0.20 at 0.6 s), `technical-design.md` (the profile no longer saves potions; potions are `RunPotions`), `sprint-development.md` (the "up to 99 of each" line now says 3 per type, one run).
- [ ] **Step 4: Run** the four test files and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `fix: the deferred minors from the 13d to 14b reviews`.

---

### Task 2: The performance overlay

**Files:**
- Create: `scripts/ui/perf_overlay.gd`, `scenes/ui/perf_overlay.tscn`, `tests/test_perf_overlay.gd`
- Modify: `scripts/fx/fx_settings.gd`, `scenes/main/main.tscn` (a `PerfOverlay` node under `Hud` or its own layer), `scripts/main/main.gd` (F3), `project.godot` (`debug_perf_overlay`, key F3, physical keycode 4194334), `tests/test_fx_settings.gd`, `tests/test_input_map.gd`, `tests/test_fx_test.gd`

**Interfaces:**
- Produces: `FxSettings.perf_overlay: bool = false`, added to `SWITCH_KEYS`, `reset()`, `to_dict()`, `apply()`; `PerfOverlay` (`class_name`, `extends CanvasLayer`): `line_text() -> String` (`"fps 98  7.2 ms  enemies 300  nodes 1423"`, ASCII), `refresh_now()`, `REFRESH_SECONDS := 0.25`; it shows when `FxSettings.perf_overlay` is true and hides otherwise; `Main` toggles `FxSettings.set_switch("perf_overlay", not FxSettings.perf_overlay)` on `debug_perf_overlay`.
- Consumes: `EnemySpawner.alive`, `Engine.get_frames_per_second()`, `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)`, `Performance.get_monitor(Performance.TIME_PROCESS)` or the last frame's delta for ms.

- [ ] **Step 1: Write the failing tests:** `test_perf_overlay`: `test_it_is_hidden_by_default`, `test_the_switch_shows_and_hides_it`, `test_line_text_has_fps_ms_enemies_and_nodes_and_is_ascii`, `test_it_refreshes_four_times_a_second_not_every_frame` (advance 0.1 s: text unchanged; 0.15 s more: changed), `test_it_ignores_touches` (every Control under it has `mouse_filter` ignore), `test_it_does_no_work_while_hidden` (`is_processing()` false when hidden), `test_f3_flips_the_switch` (an `InputEventAction debug_perf_overlay` on a Main flips `FxSettings.perf_overlay`; `save_path = ""`); `test_fx_settings`: update the defaults and dictionary tests for the new key (`perf_overlay` false) and `test_a_switch_can_be_read_and_set_by_its_key` covers it; `test_input_map`: `debug_perf_overlay` is a key; `test_fx_test`: the switch count follows `SWITCH_KEYS` (it already does). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `FxSettings.perf_overlay`, `PerfOverlay` and its scene (one `Label` with `HudLabel`, top centre, `mouse_filter` ignore, `layer` above the HUD, `process_mode` Always so it also measures behind pause screens), the `main.tscn` node, the F3 action and Main's handler. Keep `reduce_motion()` untouched.
- [ ] **Step 3: Run** `godot --headless --import`, the files above, `test_fx_guards`, `test_ui_look`, and the whole suite. Expected: PASS.
- [ ] **Step 4: Real window:** a scratchpad script (as in Sprint 13f) that starts the game, flips the switch and saves a screenshot of the overlay (`--resolution 960x540`); read it and check it is small, legible and clear of the HUD.
- [ ] **Step 5: Commit** `feat: the performance overlay (F3)`.

---

### Task 3: A long press on the mute button opens the overlay

**Files:**
- Modify: `scripts/ui/mute_button.gd`, `scripts/main/main.gd`, `tests/test_mute_button.gd`, `tests/test_sound_routes.gd` (and any test that pressed the button and expected mute on press)

**Interfaces:**
- Produces: `MuteButton.pressed` now fires when a press **inside** the button is released (touch release, or left mouse release) after less than `HOLD_SECONDS := 1.0`; `long_pressed` fires once when a press has been held `HOLD_SECONDS`, and the release that follows emits nothing. `handle_touch(screen_position)` still returns true for a press inside (it starts the hold) and `handle_release(screen_position) -> bool` ends it; a release outside the button after a press inside cancels without `pressed`. A `clock: Callable` returns milliseconds so tests drive time. `Main` connects `long_pressed` to flip `FxSettings.perf_overlay` and calls `_player.require_cast_release()` as for a tap.

- [ ] **Step 1: Write the failing tests** in `test_mute_button.gd` (update the old ones: a press alone no longer emits `pressed`; a press then a release does): `test_a_tap_emits_pressed_on_release`, `test_a_left_click_press_then_release_emits_pressed`, `test_a_press_held_for_a_second_emits_long_pressed_and_not_pressed` (drive the injected clock), `test_a_release_after_a_long_press_emits_nothing`, `test_a_release_outside_the_button_cancels_the_press`, `test_a_second_press_while_holding_does_not_double_fire`, `test_a_short_press_then_a_hold_each_act_once`; in `test_sound_routes`: the mute test presses and releases; in `test_main_progression` or a new test: `test_a_long_press_on_the_mute_button_toggles_the_overlay_and_leaves_mute_alone` and `test_a_tap_still_toggles_mute_and_leaves_the_overlay_alone`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the hold detection in `MuteButton` (a press inside records the clock time and `_holding`; `_process` only runs while holding and emits `long_pressed` once at 1 s; `_input` also handles `InputEventScreenTouch` release and left `InputEventMouseButton` release anywhere; the face stays input-ignoring). Update `Main`: `_mute_button.long_pressed.connect(_on_mute_button_long_pressed)`.
- [ ] **Step 3: Run** `test_mute_button`, `test_sound_routes`, the Main tests and the whole suite. Expected: PASS.
- [ ] **Step 4: Real window** (the touch rule): a scratchpad script that sends `Input.parse_input_event` touches in window coordinates (multiply the game position by `root.get_final_transform()`): a tap mutes once, a 1.2 s hold opens the overlay and does not mute, and the same with a left mouse click. Report what was seen.
- [ ] **Step 5: Commit** `feat: a long press on the mute button toggles the overlay`.

---

### Task 4: The soak test

**Files:**
- Create: `scripts/systems/soak_run.gd` (`class_name SoakRun`, pure), `scripts/dev/soak_test.gd`, `tests/test_soak_run.gd`, `tests/test_soak.gd`

**Interfaces:**
- Produces: `SoakRun.Sample` (a `Dictionary` with `round`, `nodes`, `objects`, `orphans`, `static_mb`); `SoakRun.take(round: int) -> Dictionary` (reads `Performance` monitors `OBJECT_NODE_COUNT`, `OBJECT_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, `MEMORY_STATIC`); `SoakRun.trend_slope(values: Array[float]) -> float` (least-squares slope per round); `SoakRun.verdict(samples: Array[Dictionary], warmup: int, band: float) -> Dictionary` (`{"ok": bool, "problems": PackedStringArray}`): after `warmup` rounds every count stays within `band` (a fraction, 0.10 starting) of the first post-warm-up value, orphans never grow, and the slope over the last half is not above a small positive threshold relative to the value.

- [ ] **Step 1: Write the failing tests** in `test_soak_run`: `test_slope_of_a_flat_series_is_zero`, `test_slope_of_a_rising_series_is_positive`, `test_slope_ignores_noise_around_a_flat_line`, `test_verdict_passes_a_flat_run`, `test_verdict_fails_a_growing_run` (nodes rise 5% a round), `test_verdict_fails_when_orphans_grow`, `test_verdict_ignores_the_warmup_rounds`, `test_verdict_needs_enough_samples` (too few samples is a failure, not a pass), `test_take_reads_real_monitors` (all keys present, numbers above 0). In `test_soak`: `test_a_short_run_stays_flat` (the harness below for 6 rounds of 120 frames; verdict ok with a coarse band 0.5) and `test_a_deliberate_leak_fails_the_verdict` (the same harness plus a test-only node added every frame; verdict not ok). Run. Expected: FAIL.
- [ ] **Step 2: Implement `SoakRun`** and the harness in `scripts/dev/soak_test.gd` (`extends SceneTree`, run `godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`): load `main.tscn` with `save_path = ""` and the pick screen's `pause_tree = false`; each round runs the given number of frames and, on fixed frame counts inside it, sets `spawner.elapsed_override` to the round's simulated minute, tops the crowd up with `spawn_at`, fires a spell of every Area through `SpellLoadout.try_cast` (equip the five Area spells from `SpellAudit.STARTING` and crafted ones), kills a share of the enemies, collects pickups, adds XP (`progress.add_xp`), buys and drinks a potion through the merchant rules, spawns a boss and defeats it, and every third round kills the player and restarts by instantiating a fresh `Main` (freeing the old one). Print `SOAK round=N nodes=.. objects=.. orphans=.. static_mb=..` per round and `SOAK PASS` or `SOAK FAIL <problems>`. Put the harness body in a reusable `SoakDriver` helper only if the suite test needs it (the suite test may call the same functions on `Main` instances it adds).
- [ ] **Step 3: Run** the two test files (expected PASS, and the leak test failing the verdict is its pass), then `godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=12 --frames=600`, and record the printed lines in the ledger. If the real run shows growth, find the cause (systematic debugging), fix it test-first, and record it.
- [ ] **Step 4: Commit** `feat: the soak test`.

---

### Task 5: The testing pass

**Files:**
- Create: `tests/test_combinations.gd` (and others the gaps need); the coverage table goes in the ledger and `development-log.md`

**Interfaces:**
- Consumes: `SpellBuilder.build`, `CraftingSystem`, `SpellLoadout.try_cast`, `SaveGame`, `Main`, the potion and equipment systems.

- [ ] **Step 1: Write the coverage table.** For each item of the Sprint 14 test list (every Base and Area combination, every buff combination, multiple equipped spells, depleted mana, equipment combinations, potion interactions, level progression, player death, run completion, save and load), name the existing test file(s) that cover it (`grep` the tests) and mark each COVERED or GAP. Write it to the ledger.
- [ ] **Step 2: Write tests for the GAPS only.** Likely gaps (confirm against the table): every Base times Area builds and casts one spell without error and spends exactly its cost (`test_every_base_and_area_pair_builds_and_casts`); every buff at its maximum stack count builds, never goes below zero cost, and `can_cast` agrees with the pool (`test_every_buff_at_its_stack_limit_builds`); two and five equipped spells keep separate mana (`test_equipped_spells_never_share_mana`); a full run path (a boss spawns, dies, rewards pay, the player dies, restarts with fresh run state: spells, potions, buffs, clock) as one test; the save round trip with every field (`test_save_round_trips_every_field`). Run them. A gap test that passes straight away is kept (it pins behaviour); one that fails is a bug: fix it test-first and record it.
- [ ] **Step 3: Run the whole suite.** Expected: PASS.
- [ ] **Step 4: Commit** `test: close the gaps in the Sprint 14 test list`.

---

### Task 6: Measure, optimize where it pays, docs and wrap-up

**Files:**
- Modify: whatever the numbers justify; `CLAUDE.md`, `README.md` only if player-facing text changes, `sprint-development.md` (14c ticks and a Built note), `development-log.md`, `sprint-14c-design.md` (Status: Built, revisions)

- [ ] **Step 1: Baseline.** Run the stress scene (`--enemies=300 --seconds=8`) three times each with `--obstacles --drops`, with `--boss --fx --obstacles --drops`, and `--area=missile`, and record frames per second, average and p99 frame time, physics and process milliseconds. Run the soak tool and record its verdict.
- [ ] **Step 2: Profile the biggest cost** (physics at about 20 ms in the full scene is the largest line): find where it goes (enemy movement and flow-field lookups, hitbox overlap work, the spawner, pickups), using the engine's profiler monitors in a scratchpad script. Pick candidates in order of cost. For each: write a test of the behaviour it must keep, change it, re-measure three runs, keep it only if it is clearly faster (outside the run-to-run noise of about 10%), otherwise revert and note it. Never change gameplay results.
- [ ] **Step 3: If the numbers show nothing worth changing, say so** and make no optimization; 14c then ships the overlay, the soak, the tests and the minors.
- [ ] **Step 4: Update the docs** (the overlay and F3, the long press, the soak tool and its verdict, the coverage table, the before and after numbers, the minors fixed). State clearly that no phone was measured and the first phone numbers must come from testers using the overlay.
- [ ] **Step 5: Run the whole suite and `godot --headless --quit-after 60`.** Expected: PASS, no new warnings.
- [ ] **Step 6: Commit** `docs: Sprint 14c complete`.
