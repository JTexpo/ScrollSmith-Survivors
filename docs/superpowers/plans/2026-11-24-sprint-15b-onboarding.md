# Sprint 15b: Onboarding and Run Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four Tutorial pages with pictures behind the home screen's Tutorial button, and a death-screen run recap (a `RunStats` tally) with three saved bests and a "New best!" mark.

**Architecture:** `RunStats` (a tally created by `Main` each run) only listens to events the game already announces. At death `RunRecords.update` compares the run with `PlayerProfile.bests` (saved in the progress save as one optional field), `Main` saves at once and passes the result to `RunRecap`, which builds the rows `DeathScreen` shows. `TutorialScreen` reads its pages from `TutorialPages` data and takes its key names from `ControlsText`, so it cannot disagree with the Input Map.

**Tech Stack:** Godot 4.7 GDScript, GUT, the game theme, `UiKit` and the existing sprites.

**Spec:** `docs/sprints/sprint-15b-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After adding a `class_name`, run `godot --headless --import`.
- No autoload; no gameplay, balance or run-start change. `RunStats` only connects to existing signals and never calls into gameplay. Gameplay code never references the recap, records or tutorial (extend `test_front_door_guards` if it needs a word added).
- **Touch rule:** every new screen handles its own touches (`TouchBridge`, pushed with `get_viewport().push_input(..., true)` while open) and takes `get_viewport()` before handling an input that could close it. The Tutorial screen is also checked in a real window by touch and mouse (`Input.parse_input_event` in window coordinates). A screen that must work while paused is process Always.
- UI uses theme variations and `UiKit`, ASCII text only, buttons at least 22 px tall and main actions at least `UiKit.ACTION_SIZE`, text measured to fit (as `test_shop_screen` does). Sprites are drawn 1:1, never scaled or rotated. `tests/test_ui_look.gd` must stay green.
- Tests never touch the real save: `SaveGame` takes paths and tests use a folder in `res://.godot/save_tests/`; every test that builds `main.tscn` sets `save_path` and the pick screen's `pause_tree = false`.
- The progress save stays version 1: `bests` is optional, written only when any best is above 0, and an old save without it loads unchanged.
- Decisions of this plan (ledger them as rulings where they matter): an enemy counts as defeated only when it `gives_rewards` (an Exploder that blasted itself is not a defeat); a boss counts only as a boss; "New best!" shows only for a beaten non-zero best and only when the save succeeded.

## Review Focus

- **Counting:** one event is one count (a kill never counts twice, a boss is not also an enemy, a self-blasting Exploder is not a defeat, a stat never counts after death), and two runs never share a tally.
- **Records:** a first run sets the bests without "New best!"; a tie, a worse run and a failed save show no mark; bests survive a restart but not New game; an old save and a save with a bad `bests` value are handled; the save is written once at death.
- **Death card:** it fits 480 by 270, rows never overflow, the Shop and Home buttons and tap-to-restart still behave (a tap on a button never restarts), and nothing from the old one-line summary is left reading a removed method.
- **Tutorial:** pages never overflow, every sprite exists, the key names come from the Input Map, Back, Next and Close work by touch, mouse, keyboard and controller (focus reaches each button), it opens from and closes back to the home screen, and the Tutorial button is no longer dimmed.

---

### Task 1: Saved bests and `RunRecords`

**Files:**
- Create: `scripts/progression/run_records.gd`, `tests/test_run_records.gd`
- Modify: `scripts/progression/player_profile.gd`, `tests/test_player_profile.gd`, `tests/test_save_game.gd`

**Interfaces:**
- Produces: `PlayerProfile.best_seconds`, `best_enemies`, `best_level` (`int`, default 0); `to_dict` writes `"bests": {"seconds": int, "enemies": int, "level": int}` only when any is above 0; `from_dict` reads an optional `bests` dictionary (each present key a whole number from 0 to `MAX_VALUE`, a missing key 0; any other type returns null like the other optional fields); `RunRecords.update(profile: PlayerProfile, enemies: int, level: int, seconds: float) -> Dictionary` (static) sets each best the run beats (seconds floored to whole seconds) and returns `{"seconds": bool, "enemies": bool, "level": bool}` where a flag is true only when the old best was above 0 and the run beat it; ties and worse runs change nothing and flag nothing.

- [ ] **Step 1: Write the failing tests:** `test_run_records`: `test_a_first_run_sets_the_bests_and_flags_nothing`, `test_a_better_run_flags_exactly_the_beaten_stats`, `test_a_tie_flags_nothing_and_keeps_the_best`, `test_a_worse_run_changes_nothing`, `test_seconds_are_floored_to_whole_seconds`, `test_each_stat_is_judged_on_its_own` (a better time with fewer enemies flags only the time); `test_player_profile`: `test_bests_round_trip_through_a_dictionary`, `test_a_profile_with_no_bests_writes_no_bests_field`, `test_an_old_save_without_bests_loads_with_zero_bests`, `test_a_bad_bests_value_is_a_bad_save` (not a dictionary, a string, a negative, a fractional number), `test_a_partial_bests_dictionary_defaults_the_missing_keys`; `test_save_game`: `test_bests_survive_save_and_load`, `test_erase_takes_the_bests_with_the_save` (after `SaveGame.erase` a fresh load has zero bests). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the fields, `to_dict`/`from_dict` changes and `RunRecords`; run `godot --headless --import`, the three files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: saved bests and RunRecords`.

---

### Task 2: The `RunStats` tally

**Files:**
- Create: `scripts/progression/run_stats.gd`, `tests/test_run_stats.gd`
- Modify: `scripts/main/main.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Produces: `RunStats` (`RefCounted`): `enemies`, `bosses`, `scrolls`, `crafts`, `potions`, `xp`, `gold`, `level` (all `int`, level starts at 1); `bind(spawner: EnemySpawner, director: RunDirector, collector: PickupCollector, crafting: CraftingScreen, belt: PotionBelt, progress: RunProgress) -> void` connecting once to `spawner.enemy_died` (counts only when `enemy.gives_rewards`), `director.boss_defeated`, `collector.collected`, `collector.xp_collected(amount)` and `gold_collected(amount)` (add the amounts), `crafting.crafted`, `belt.used`, and `progress.leveled_up(level, reward)` (keeps the highest); `freeze()` stops counting (every handler returns early afterwards); `is_frozen() -> bool`. `Main` creates one per run (`var run_stats: RunStats`), binds it at the end of `_begin_progression`, and calls `freeze()` at the start of `_on_player_died`.

- [ ] **Step 1: Write the failing tests** (`test_run_stats`, with real small stand-ins: an `EnemySpawner`, `RunDirector`, `PickupCollector`, `CraftingScreen`, `PotionBelt` and `RunProgress` the way their own tests build them, or `Object` doubles with the same signals if simpler): `test_each_event_adds_exactly_one_to_the_right_counter`, `test_an_enemy_that_gives_no_rewards_is_not_a_defeat`, `test_a_boss_counts_as_a_boss_and_not_as_an_enemy`, `test_xp_and_gold_add_the_announced_amounts`, `test_level_keeps_the_highest_reached`, `test_nothing_counts_before_bind_and_after_freeze`, `test_binding_twice_does_not_double_count`, `test_two_tallies_never_share_state`; `test_main_progression`: `test_a_run_has_a_tally_that_counts_a_real_kill_and_pickup` (kill an enemy and collect a scroll in a built `Main`: `main.run_stats.enemies == 1`, `.scrolls == 1`), `test_a_new_run_starts_with_an_empty_tally` (a second `Main` after the first counted things), `test_the_tally_is_frozen_when_the_player_dies`. Run. Expected: FAIL.
- [ ] **Step 2: Implement `RunStats`** and the `Main` wiring (create in `_begin_progression` after `run_potions`, bind to the existing nodes, freeze in `_on_player_died` before anything else). Run `godot --headless --import`, the two files and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the RunStats tally`.

---

### Task 3: The run recap on the death screen

**Files:**
- Create: `scripts/ui/run_recap.gd`, `tests/test_run_recap.gd`
- Modify: `scripts/ui/death_screen.gd`, `scenes/ui/death_screen.tscn`, `scripts/main/main.gd`, `tests/test_death_screen.gd`, `tests/test_main_progression.gd`, `tests/test_main.gd` and any test that read `set_run_summary` or `summary_text`

**Interfaces:**
- Consumes: Tasks 1 and 2, `RunClockLabel.format(seconds)`.
- Produces: `RunRecap.rows(stats: RunStats, seconds: float, profile: PlayerProfile, flags: Dictionary, saved: bool) -> Array[Dictionary]` (static): nine rows in this order, each `{"label": String, "value": String, "best": String, "new_best": bool}`: Time survived (`m:ss`; best `"best m:ss"`), Enemies defeated (best `"best N"`), Bosses defeated, Level reached (best `"best N"`), XP earned, Gold earned, Scrolls collected, Spells crafted, Potions drunk (rows with no saved best have `best == ""`); `new_best` is `flags[stat]` and only when `saved` is true; when `new_best` is true `best` is `""` and the card shows the mark instead. `DeathScreen.set_recap(rows: Array[Dictionary]) -> void` replaces `set_run_summary`; `recap_text() -> String` replaces `summary_text` (each row as `"label: value"` plus the best or the mark, joined by newlines, for tests); the card shows the rows in two columns of label and value, the best in `Muted` beside it and "New best!" in the theme's good colour. `Main._on_player_died`: freeze the tally (Task 2), call `RunRecords.update(profile, run_stats.enemies, run_stats.level, RunClock.seconds())`, save with `SaveGame.save_profile`-through `_saver.save_now()` and read whether it succeeded (add `ProfileSaver.save_now() -> bool` if it does not return one; keep every existing caller working), then call `_death_screen.set_recap(RunRecap.rows(...))`.

- [ ] **Step 1: Write the failing tests:** `test_run_recap`: `test_rows_are_the_nine_stats_in_order`, `test_time_is_formatted_as_minutes_and_seconds`, `test_a_saved_best_shows_as_best_text_for_the_three_that_have_one`, `test_a_new_best_shows_the_mark_instead_of_the_best_text`, `test_no_new_best_mark_when_the_save_failed`, `test_a_first_run_shows_its_best_without_the_mark` (bests were zero before: `flags` all false, the best equals the run); `test_death_screen`: replace the old summary tests with `test_set_recap_shows_every_row` (`recap_text()` has nine lines), `test_the_recap_card_fits_the_screen` (the card and every row inside 480 by 270, no label wider than its column, measured with `UiFont.plain()`), `test_the_recap_is_hidden_until_set`, `test_shop_home_and_restart_still_work_with_the_recap` (the existing button and tap tests keep passing); `test_main_progression`: `test_dying_updates_and_saves_the_bests_and_shows_the_recap` (kill the player in a built `Main` with a temp save, the saved file has the bests, `recap_text()` mentions the run), `test_a_second_better_run_shows_new_best_for_the_beaten_stats`, `test_a_failed_save_shows_no_new_best_mark`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** `RunRecap`, the death screen card (enlarge the card to about 400 by 170 and move the buttons and restart hint so nothing overlaps; delete the old `Summary` label and its methods) and the `Main` flow. Update every old test that used the removed methods. Run `godot --headless --import`, the changed files and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the death screen shows a run recap and remembers the bests`.

---

### Task 4: The Tutorial

**Files:**
- Create: `scripts/ui/tutorial_pages.gd`, `scripts/ui/tutorial_screen.gd`, `scenes/ui/tutorial_screen.tscn`, `tests/test_tutorial_pages.gd`, `tests/test_tutorial_screen.gd`
- Modify: `scripts/ui/controls_text.gd` (a public `key_for(action: StringName) -> String`), `scripts/home/home_screen.gd`, `scenes/home/home.tscn`, `tests/test_home_screen.gd`, `tests/test_front_door_guards.gd`, `tests/test_controls_text.gd`

**Interfaces:**
- Produces: `ControlsText.key_for(action) -> String` (the first keyboard key's `as_text_physical_keycode()` for the action, or `""`); `TutorialPage` (`RefCounted`): `title: String`, `lines: Array[String]`, `sprites: Array[StringName]`; `TutorialPages.pages() -> Array[TutorialPage]`: exactly four pages: (1) the goal and moving (survive, collect XP and Gold, move with the move keys or the left stick; sprites `player`, `pickup_xp`, `pickup_gold`), (2) casting and spells (aim and cast with the mouse or right stick, spell slots with 1 to 5, mana never comes back, so each spell is a number of casts; sprites `player`, `reticle`), (3) scrolls and the Lectern (enemies drop scrolls, a Lectern combines a Base, an Area and optional buffs into a spell, one Base and one Area; sprites `scroll_base`, `scroll_area`, `scroll_buff`, `lectern`), (4) potions and the shop (potions come only from the merchant, up to 3 of each, last one run; Gold buys equipment between runs in the shop; sprites `icon_potion`, `poi_merchant`, `icon_coin`); each line is at most about 56 characters and ASCII, built with `ControlsText.key_for` where it names a key; `TutorialScreen` (`CanvasLayer`, process Always, layer above the home screen): `signal closed`, `open()`, `close()`, `is_open()`, `next()`, `back()`, `page_index() -> int`, `page_count() -> int`, `handle_input(event) -> bool` (a bridged touch while open), buttons Back (disabled on page 1), Next (becomes "Done" on the last page and closes), Close, a counter label "1 of 4"; `ui_left`, `ui_right` page, `ui_cancel` and `pause` close (taken in `_input`, viewport captured first); the home screen's Tutorial button text becomes "Tutorial", is enabled, and opens the screen; closing returns focus to Play.

- [ ] **Step 1: Write the failing tests:** `test_tutorial_pages`: `test_there_are_four_pages_with_titles_lines_and_sprites`, `test_every_sprite_exists` (`SpriteLibrary.find`), `test_lines_are_ascii_and_short_enough_to_fit_the_page_width` (measured with `UiFont.plain()` against the text width), `test_key_names_come_from_the_input_map` (the movement or spell line contains the key text for its action), `test_the_pages_say_mana_never_comes_back_and_potions_last_one_run` (pins the two rules the player most needs); `test_tutorial_screen`: `test_it_starts_closed_and_opens_on_the_first_page`, `test_next_and_back_move_and_stop_at_the_ends`, `test_back_is_disabled_on_the_first_page_and_next_says_done_on_the_last`, `test_done_closes_and_emits_closed`, `test_the_counter_shows_the_page`, `test_left_and_right_page_and_escape_closes` (via `_input` with `InputEventAction`), `test_every_button_is_reachable_by_focus` (find_next_valid_focus walks Back, Next, Close without a null), `test_buttons_meet_the_touch_size`, `test_a_touch_while_open_is_bridged_and_one_while_closed_is_not`, `test_it_works_while_the_tree_is_paused`; `test_home_screen`: update the button list to "Tutorial", enabled, and `test_the_tutorial_button_opens_the_tutorial_and_closing_returns_to_play`; `test_controls_text`: `test_key_for_returns_the_first_key_text_and_empty_for_a_missing_action`; `test_front_door_guards`: add `TutorialScreen` to the touch and always lists. Run. Expected: FAIL.
- [ ] **Step 2: Implement** the pages, the screen and scene (the page picture row draws each sprite with `UiKit.icon`, 1:1), the `ControlsText.key_for` helper and the home screen change. Run `godot --headless --import`, the files above, `test_ui_look` and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the Tutorial`.

---

### Task 5: Guards, real-window checks and docs

**Files:**
- Modify: `tests/test_front_door_guards.gd`, `CLAUDE.md` (a "Onboarding and run statistics (Sprint 15b)" section, the Project State line, the death-screen mentions), `README.md`, `sprint-development.md` (15b ticks: run statistics, game-over screen, tutorial/onboarding, and a Built note), `development-log.md`, `docs/sprints/sprint-15b-design.md` (Status: Built, revisions), `technical-design.md` (the `bests` field)

- [ ] **Step 1: Guards.** Extend `test_front_door_guards.gd` with `test_no_gameplay_script_references_the_recap_records_or_tutorial` (allowed: `scripts/ui/run_recap.gd`, `scripts/progression/run_records.gd`, `scripts/progression/run_stats.gd`, `scripts/ui/death_screen.gd`, `scripts/ui/tutorial_*`, `scripts/main/main.gd`, `scripts/home/`) and `test_run_stats_never_calls_into_gameplay` (the script contains no method call on a node other than `connect`). Run. Expected: PASS or fix what it finds.
- [ ] **Step 2: Real window** (a scratchpad script: throwaway save and settings paths, `await process_frame` first, `--resolution 960x540`): screenshots of all four tutorial pages and of the death card (a first run with no mark, then a better run with "New best!" marks, using a throwaway save and a Main whose tally is set by killing enemies and collecting a pickup); by TOUCH and by MOUSE: open the Tutorial from the home screen, tap Next three times and Back once, Done closes, the home Play button has focus; die and read the card, tap Home. Read the screenshots and report what was seen and what was not checked (a real phone).
- [ ] **Step 3: Docs.** State plainly: no phone was tested; the Tutorial never opens by itself; bests are three numbers in the progress save and New game erases them; the card replaced the one-line summary.
- [ ] **Step 4: Run the whole suite, `godot --headless --quit-after 60`, and the soak tool once** (`godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=6 --frames=300 --warmup=2`). Expected: PASS, `SOAK PASS` (each run gains a tally).
- [ ] **Step 5: Commit** `docs: Sprint 15b complete`.
