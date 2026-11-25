# Sprint 16a: Map Select, Art Sets and the New Layouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three maps (forest, ruins, maze) chosen from a map select screen, a per-map enemy art set lookup, per-map saved bests, and the forest and maze layouts, all on today's art and the Ember Titan.

**Architecture:** One small inherited run scene per map (`main.tscn` stays the ruins); a `MapCatalog` lists `MapEntry`s (map data + scene path); the home screen's Play opens a `MapSelectScreen` that loads the chosen scene, so a death restart reloads the same scene. A map names its enemy art set, which `Enemy._apply_look` tries before today's sprite. Bests move to a per-map dictionary. The forest and maze are authored data (generated once by a scratchpad script, then pinned by layout tests).

**Tech Stack:** Godot 4.7 GDScript, GUT, the game theme, `UiKit`, existing sprites.

**Spec:** `docs/sprints/sprint-16a-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After adding a `class_name`, run `godot --headless --import`. Scratch scripts go in the scratchpad directory, never `/tmp`.
- No autoload; no stat, balance, spawn-config, reward or boss-timer difference between maps; no new enemy or boss art, no new boss, no new sound. The ruins' layout, id (`first_map`) and tests stay as they are (only its display name and the two new fields change).
- Every map is 1920 by 1080. The chosen map lives in the scene path only: no static "current map" variable.
- **Touch rule:** the map select handles its own touches (`TouchBridge`, `get_viewport().push_input(..., true)` while open), takes `get_viewport()` before handling an input that may change scene, runs while paused (process Always) and is checked in a real window by touch and mouse (`Input.parse_input_event` in window coordinates).
- UI uses theme variations and `UiKit`, ASCII text only, text measured to fit, main actions at least `UiKit.ACTION_SIZE` (72 by 28), card buttons at least 22 px tall; sprites 1:1, never scaled or rotated. `tests/test_ui_look.gd` must stay green.
- Tests never touch the real save or real settings: `SaveGame` and `SettingsStore` take paths (use `res://.godot/save_tests/`); every test that builds a run scene sets `save_path = ""` (or a test path) and the pick screen's `pause_tree = false` before `add_child`.
- Save formats: the progress save stays version 1; the settings file stays version 1 with an optional `play` object. Old files load unchanged; nothing is deleted (bad files become `.bak` as today).
- Layout rules (from 12b to 14a, copied here): 16 px nav grid, 8 px body clearance, player is a 12 px box, ring recipe = 7 `tree` circles of radius 18 at radius 62 at angles `gap + 60 + 40k` (neighbouring trees leave a slit under 12 px), ring and clump centres on multiples of 16, every lane to a wall 48 px or more or merged into it, outer 48 px band and 150 px around the start free, no gap narrower than two cells, every free cell reachable from the start, Lecterns at least 700 px apart and 400 px from the start, every point of interest at least 400 px from the next.
- Rulings to ledger where they matter: the order check (Task 10) is reported, never asserted; each map gets the same set of points of interest (3 Lecterns, 2 Rare scroll spots, chest, Mana Shrine, Health Shrine, merchant).

## Review Focus

- **Old saves:** a progress save with the old flat `bests` (`seconds`, `enemies`, `level`) loads as the ruins' bests and ignores `level`; a bad value is still a bad save; a fresh save, New game and `erase` take every map's bests; settings files with no `play` object load the default last map and an unknown saved map id gives the default.
- **Restart and scenes:** dying on the forest and restarting reloads the forest, Home then Play then the ruins loads the ruins, and nothing carries over between maps (bests, spawner art set, camera limits, flow field).
- **Art set:** an empty set, an unknown set and a set with no sprite for an archetype all give today's look (never a coloured square when the old sprite exists); the ruins' enemies look unchanged.
- **Map select:** three cards in catalog order; focus on the last played map; Back, Esc and a tap outside behave; a held press that opened it cannot choose; Play on a missing scene returns an error and changes nothing; works from touch, mouse, keyboard and controller; Settings, Shop and Tutorial still open from the home screen.
- **Layouts:** nothing unreachable, no point of interest trapped, no ring or room with a second opening, the maze solvable from the cleared centre to every point of interest, deterministic from its seed, and its shape count not breaking the performance of the ruins (measured, Task 10).

---

### Task 1: Map fields, `dead_end_cells` and the ruins' data

**Files:**
- Modify: `resources/maps/map_data.gd`, `resources/maps/map_maze.gd`, `resources/maps/first_map.tres`, `tests/test_map_data.gd`, `tests/test_map_maze.gd`
- Test: the same two files

**Interfaces:**
- Produces: `MapData.description: String` and `MapData.enemy_art_set: StringName` (default `&""`), both `@export`; `MapMaze.dead_end_cells() -> Array[Vector2]` returning the world-space centres of every cell with exactly one opening (after generation, extra openings and the cleared centre), in the maze's own cell order, with the same rotation handling as `center_room_center()`. The ruins' `first_map.tres` gets `display_name = "The Ruins"`, `description = "Walls, rooms and a hidden stronghold."`, `enemy_art_set = &"ruins"`.

- [ ] **Step 1: Write the failing tests.** `test_map_data`: `test_a_map_has_a_description_and_an_art_set_with_empty_defaults`, `test_the_ruins_are_named_and_keep_their_id` (`id == &"first_map"`, display name "The Ruins", art set `ruins`, description non-empty and ASCII). `test_map_maze`: `test_dead_end_cells_have_exactly_one_opening` (build a small seeded maze; every returned centre is inside `area`; count of walls around each cell is three), `test_dead_end_cells_are_deterministic_for_a_seed`, `test_dead_end_cells_follow_the_half_turn` (the `rotated` twin of a maze returns the half-turn images of the original's centres), `test_the_cleared_centre_is_never_a_dead_end`. Run. Expected: FAIL (members missing).
- [ ] **Step 2: Implement** the fields and `dead_end_cells()` (count a cell's open sides from the `Layout` that `_generate()` builds), and edit the three lines in `first_map.tres`. Run `godot --headless --import`, both files, then `grep -rn "Lectern Grounds" tests scripts docs *.md` and update any test that names the old display name. Expected: PASS.
- [ ] **Step 3: Commit** `feat: map description, art set and maze dead ends`.

---

### Task 2: Per-map bests and the eight-row death card

**Files:**
- Modify: `scripts/progression/player_profile.gd`, `scripts/progression/run_records.gd`, `scripts/progression/run_stats.gd`, `scripts/ui/run_recap.gd`, `scripts/ui/death_screen.gd` (only if it names the level row), `scripts/main/main.gd`, `scripts/progression/save_game.gd` (only if it names `best_level`), `tests/test_player_profile.gd`, `tests/test_save_game.gd`, `tests/test_run_records.gd`, `tests/test_run_recap.gd`, `tests/test_run_stats.gd`, `tests/test_death_screen.gd`, `tests/test_main_progression.gd`, `tests/test_combinations.gd` (if it writes `best_level`)

**Interfaces:**
- Consumes: `MapData.id`.
- Produces: `PlayerProfile.bests: Dictionary` (map id `String` to `{"seconds": int, "enemies": int}`), `best_seconds(map_id: StringName) -> int`, `best_enemies(map_id: StringName) -> int` (0 when unknown), `set_best(map_id: StringName, seconds: int, enemies: int) -> void`. `best_seconds`, `best_enemies` and `best_level` fields are removed. `to_dict` writes `"bests": {"<map id>": {"seconds": n, "enemies": n}}` only when any value is above 0; `from_dict` reads that shape, and also an old flat `{"seconds","enemies","level"}` (detected by a `seconds`/`enemies`/`level` key whose value is a number) as the `first_map` entry with `level` ignored; every number must be a whole number from 0 to `MAX_VALUE`, a non-dictionary `bests`, a non-dictionary map entry or any bad number returns null like the other optional fields. `RunRecords.update(profile: PlayerProfile, map_id: StringName, enemies: int, seconds: float) -> Dictionary` returns `{"seconds": bool, "enemies": bool}` with the same flag rules, judged on that map's bests only. `RunRecap.rows(stats: RunStats, seconds: float, profile: PlayerProfile, flags: Dictionary, saved: bool, map_id: StringName) -> Array[Dictionary]` returns eight rows (time survived, enemies defeated, bosses defeated, XP earned, Gold earned, scrolls collected, spells crafted, potions drunk) with bests from that map. `RunStats.level` is removed. `Main` needs the run's map id: `Main.map_id() -> StringName` returns `_map.map_data.id` (empty when none).

- [ ] **Step 1: Write the failing tests.** `test_player_profile`: `test_bests_round_trip_per_map`, `test_a_profile_with_no_bests_writes_no_bests_field`, `test_an_old_flat_bests_save_loads_as_the_ruins` (`{"seconds": 90, "enemies": 12, "level": 7}` gives `best_seconds(&"first_map") == 90`, `best_enemies(&"first_map") == 12` and writes back in the new shape with no level), `test_the_old_level_is_ignored_even_when_it_is_bad` is NOT a test (a bad level is a bad number: assert it returns null), `test_a_bad_bests_value_is_a_bad_save` (not a dictionary, a string, a negative, a fractional number, a map entry that is not a dictionary), `test_an_unknown_map_has_zero_bests`. `test_save_game`: `test_per_map_bests_survive_save_and_load`, `test_erase_takes_every_map_s_bests`. `test_run_records`: update the existing tests to the new signature and add `test_a_record_on_one_map_never_touches_another_map`, `test_a_first_run_on_a_new_map_flags_nothing_even_when_another_map_has_bests`. `test_run_recap`: `test_there_are_eight_rows_and_none_is_a_level_row`, `test_bests_come_from_the_given_map`. `test_death_screen`: change the width test's label list to the eight labels and `_rows()` to 8 rows, and the line-count assertion to 8 (the "Stat 8" line goes). `test_main_progression`: `test_dying_records_the_best_on_this_map_only` (a `Main` with the ruins' map: after a death `profile.best_enemies(&"first_map")` is set and another map id stays 0), `test_there_is_no_level_in_the_tally` (`"level" not in run_stats` via `get_property_list`). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the profile shape and migration, `RunRecords`, `RunRecap`, delete `RunStats.level` and its `leveled_up` handling (keep the signal connection removal clean so `bind`'s signature is unchanged for callers), and the `Main._on_player_died` change (no level copy; pass `map_id()`). Update every call site found by `grep -rn "best_seconds\|best_enemies\|best_level\|RunRecap.rows\|RunRecords.update\|run_stats.level" scripts tests`. Shift the death card layout up by one row if the card's constants need it (`test_the_recap_card_fits_the_screen` and `test_the_recap_sits_above_the_buttons` stay green). Run `godot --headless --import`, the touched files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: bests per map and an eight-row death card`.

---

### Task 3: Enemy art sets

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`, `scripts/entities/enemy.gd`, `scripts/main/main.gd`, `tests/test_enemy_look.gd` (or the file that tests `_apply_look`; find with `grep -ln "_apply_look\|enemy_standard\|set_look" tests`), `tests/test_main_map.gd`

**Interfaces:**
- Consumes: `MapData.enemy_art_set`.
- Produces: `EnemySpawner.enemy_art_set: StringName` (default `&""`), assigned to `enemy.art_set` right before `enemy.setup(...)` in `_spawn_enemy` (and for cluster members and summons, wherever an `Enemy` is set up from `EnemyData`; find every `setup(` call). `Enemy.art_set: StringName`; `Enemy.look_sprite() -> StringName` returns `enemy_<set>_<archetype id>` when `art_set` is not empty and `SpriteLibrary.find(that name, variant)` exists, otherwise `enemy_<archetype id>`; `_apply_look` calls `_body.set_look(look_sprite(), ...)` and the look cache key includes the sprite name. `Main._apply_map` sets `_spawner.enemy_art_set = _map.map_data.enemy_art_set` when the map has data.

- [ ] **Step 1: Write the failing tests.** `test_enemy_look`: `test_an_empty_art_set_uses_the_archetype_sprite`, `test_an_art_set_with_no_such_sprite_falls_back_to_the_archetype_sprite` (set `&"forest"`: no `enemy_forest_standard` exists in 16a), `test_an_art_set_with_a_sprite_uses_it` (use a test-only set name whose sprite is one existing sprite renamed by registering a throwaway `SpriteSetData` through whatever seam `SpriteLibrary` offers; if it has none, add a small `SpriteLibrary.register_for_tests(name, variant, set)` seam and a matching clear, ledger it as a ruling), `test_the_look_cache_notices_a_changed_art_set`, `test_the_ruins_enemies_look_exactly_as_before` (compare the `BodyView` look name of every archetype with and without `art_set = &"ruins"`). `test_main_map`: `test_apply_map_hands_the_art_set_to_the_spawner` and `test_every_spawned_enemy_gets_the_spawners_art_set` (spawn through the spawner and check `enemy.art_set`). Run. Expected: FAIL.
- [ ] **Step 2: Implement** as in Interfaces. Run `godot --headless --import`, the touched files and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: enemy art sets with fallback`.

---

### Task 4: The forest layout

**Files:**
- Create: `resources/maps/forest_map.tres`, `tests/test_forest_map_layout.gd`
- Create (scratchpad only, not committed): a generator script in the scratchpad directory, as 14a did
- Reference: `resources/maps/first_map.tres` (ring, yard and placement sub-resource shapes), `tests/test_first_map_layout.gd`, `tests/test_first_map_world_pass.gd`

**Interfaces:**
- Produces: `forest_map.tres` (`MapData`): `id = &"forest"`, `display_name = "The Forest"`, `description = "Open woods. Somewhere, a dragon."`, `enemy_art_set = &"forest"`, size 1920 by 1080, `floor_style = &"grass"`, `border_style = &"border"`, player start (960, 540), the default spawn config, `decoration_count = 0`, no mazes, no zones. Obstacles are only trees and rocks: `material = &"tree"` circles (the ring recipe) and a few `&"rock"` shapes only if `WorldArt` has `post_rock`/`wall_rock`, else `tree` (check `ls assets/sprites | grep -i "post_\|wall_"`; do not add art). Placements: 3 Lecterns (each in a tree ring, one opening), the chest and the merchant (each in a tree ring), 2 Rare scroll spots, the Mana Shrine and the Health Shrine (each in an open clearing: no obstacle within 80 px), at least 400 px apart and Lecterns at least 700 px apart and 400 px from the start. Between 20 and 80 solid shapes, 3% to 15% of grid cells blocked, no obstacle inside the 150 px start area or the outer 48 px band, an open 10 by 10 cell square 400 px from the start, no walls (every shape is a circle or a rock no longer than 64 px), and the open ground leaves no pocket: every free cell reachable from the start and no dead-end pocket deeper than one ring opening.

- [ ] **Step 1: Write the failing tests** in `test_forest_map_layout.gd` (a new file; reuse the ruins' helper methods by copying the few small ones you need, as the ruins' tests do): `test_the_forest_has_no_problems_and_every_placement_is_reachable` (`map.problems()` empty and `ObstacleGrid.reachability_problems(map)` empty), `test_it_has_between_20_and_80_solid_shapes_and_no_walls`, `test_the_outer_band_and_the_start_area_are_free`, `test_most_of_it_is_walkable` (3% to 15% blocked), `test_no_gap_is_narrower_than_two_cells`, `test_an_open_square_exists_away_from_the_start`, `test_every_free_cell_is_reachable_from_the_start`, `test_the_same_points_of_interest_as_the_ruins` (three Lecterns, two Rare spots, chest, both shrines, merchant, counted by scene path), `test_spacing_rules` (400 / 700 / 400), `test_each_lectern_chest_and_merchant_is_guarded_with_exactly_one_opening` (the free-rays run test from `test_first_map_world_pass`), `test_shrines_and_rare_spots_stand_in_clearings`, `test_no_gap_between_ring_trees_lets_the_player_through`, `test_the_forest_has_the_same_spawn_config_as_the_ruins` (same resource path), `test_it_is_1920_by_1080`. Run. Expected: FAIL (file missing).
- [ ] **Step 2: Generate the map.** In the scratchpad, write a generator (venv Python, seeded) that emits the `.tres`: the seven-tree rings at the chosen centres (multiples of 16, 48 px or more lane to the next shape), 12 to 20 two- and three-tree groves scattered with best-candidate spacing away from rings and placements, the placements, and the header fields. Choose the 3 Lectern centres to suit the open field (for example (400, 208), (1520, 880) and (1744, 240), at least 700 px apart and 400 px from (960, 540)), put the Rare spots and shrines in clearings far from them and each other, then iterate the generator (never hand-edit coordinates) until the tests pass. Run `godot --headless --import` and the new test file. Expected: PASS.
- [ ] **Step 3: Check in a real window** (`godot --path . res://scenes/world/stress_test.tscn`-style throwaway scratch scene is not needed): after Task 6 exists the map can be opened; for now run `godot --headless --quit-after 60` and the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: the forest map layout`.

---

### Task 5: The maze layout

**Files:**
- Create: `resources/maps/maze_map.tres`, `tests/test_maze_map_layout.gd`
- Create (scratchpad only): generator script
- Reference: the ruins' mazes in `first_map.tres`, `resources/maps/map_maze.gd`

**Interfaces:**
- Consumes: `MapMaze.dead_end_cells()` (Task 1).
- Produces: `maze_map.tres` (`MapData`): `id = &"maze"`, `display_name = "The Maze"`, `description = "A minotaur's maze. Do not get cornered."`, `enemy_art_set = &"maze"`, size 1920 by 1080, `floor_style = &"ruin"`, `border_style = &"border"`, player start (960, 540), default spawn config, no authored obstacles, one `MapMaze` (`material = &"stone"`, `cell_size = 80`, `wall_thickness = 16`, `area` about `Rect2(60, 60, 1800, 960)` so the cells line up and the outer 48 px band stays free, a seed that passes, `clear_center = true`, 6 to 12 `extra_openings`, entrances only where needed so the maze is closed to the boundary), a floor zone (one `MapZone` in the ruins' lavender floor sized to the maze grown by at least 48 px, as the ruins' maze zones are) so the stone floor shows. Placements: 3 Lecterns in three far apart corner dead ends or rooms (at least 700 px apart, 400 px from the start), 2 Rare spots and the chest in dead ends, the Mana Shrine, Health Shrine and merchant in dead ends or small rooms; every point of interest at least 400 px from the next; all placed at `dead_end_cells()` centres or carved rooms, never in the cleared centre.

- [ ] **Step 1: Write the failing tests** in `test_maze_map_layout.gd`: `test_the_maze_has_no_problems_and_every_placement_is_reachable`, `test_the_maze_is_deterministic_from_its_seed`, `test_it_has_between_150_and_900_solid_shapes` (state the bound as a ruling; measure the real count first), `test_the_outer_band_and_the_start_area_are_free`, `test_no_gap_is_narrower_than_two_cells`, `test_every_free_cell_is_reachable_from_the_start`, `test_every_point_of_interest_is_in_a_dead_end` (each placement within 40 px of a `dead_end_cells()` centre), `test_the_same_points_of_interest_as_the_ruins`, `test_spacing_rules`, `test_the_cleared_centre_is_free_around_the_start`, `test_it_has_at_least_one_dead_end_loop_and_corner_per_lectern` (at least 12 dead ends in total; each Lectern is in a dead end), `test_it_is_1920_by_1080`, `test_it_uses_the_same_spawn_config_as_the_ruins`. Run. Expected: FAIL.
- [ ] **Step 2: Generate and tune.** Scratchpad generator writes the `.tres` for a given seed and picks the point-of-interest cells from the dead ends by farthest-first spacing; a loop in the scratchpad tries seeds (data) until every test passes; keep the first passing seed and record the seed and the shape count in the ledger. Run `godot --headless --import` and the new test file. Expected: PASS.
- [ ] **Step 3: Measure** the grid build time and the shape count against the ruins with a throwaway scratchpad script (`ObstacleGrid.build` time, a whole `FlowField` sweep time): the sweep must stay under 50 ms and the build under 3 times the ruins'; ledger the numbers (Task 10 repeats this in play).
- [ ] **Step 4: Commit** `feat: the maze map layout`.

---

### Task 6: The catalog and the three run scenes

**Files:**
- Create: `resources/maps/map_entry.gd`, `resources/maps/map_catalog.gd`, `resources/maps/map_catalog.tres`, `scenes/main/main_forest.tscn`, `scenes/main/main_maze.tscn`, `tests/test_map_catalog.gd`
- Modify: `scripts/utilities/scenes.gd` (add `FOREST` and `MAZE` constants beside `RUN`), `scripts/ui/death_screen.gd` (only if restart needs more than `current_scene.scene_file_path`)

**Interfaces:**
- Consumes: forest and maze maps (Tasks 4 and 5), `Scenes.RUN`.
- Produces: `MapEntry` (`Resource`): `map: MapData`, `scene_path: String`. `MapCatalog` (`Resource`): `entries: Array[MapEntry]` (order: forest, ruins, maze), `static default_catalog() -> MapCatalog`, `find(id: StringName) -> MapEntry` (null for unknown), `entry_for_scene(path: String) -> MapEntry` (null for unknown), `ids() -> Array[StringName]`, `default_id() -> StringName` (the first entry's id: the forest). `main_forest.tscn` and `main_maze.tscn` are inherited from `main.tscn` and override only the `Map` node's `map_data`; `Scenes.FOREST`, `Scenes.MAZE` name them.

- [ ] **Step 1: Write the failing tests** (`test_map_catalog`): `test_the_catalog_lists_forest_ruins_maze_in_order`, `test_each_entry_scene_exists_and_holds_the_entry_s_map` (instantiate each scene, find the `GameMap`, compare `map_data.id`), `test_the_ruins_entry_is_the_existing_main_scene_and_map` (`scene_path == Scenes.RUN`, map path `first_map.tres`), `test_find_and_entry_for_scene_round_trip`, `test_unknown_ids_and_paths_give_null`, `test_default_id_is_the_forest`, `test_every_map_has_a_name_description_art_set_and_unique_id`, `test_every_map_validates_and_shares_the_default_spawn_config`, `test_each_scene_builds_a_main_that_starts_a_run` (`save_path = ""`, pick screen `pause_tree = false`, `add_child_autofree`, wait two frames: player at the map's start, spawner arena equals the map's size, `enemy_art_set` equals the map's set), `test_restart_reloads_the_same_scene` (the death screen's `restart_scene_path` resolves to the scene's own path for each). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the classes, the catalog `.tres`, and the two inherited scenes (hand-written `.tscn` with `instance` inheritance: `[node name="Main" instance=ExtResource("main")]` then `[node name="Map" parent="." index="..."]` with `map_data = ExtResource(...)`; check the real node name in `main.tscn` with `grep -n "game_map\|GameMap" scenes/main/main.tscn`). Run `godot --headless --import`, the file and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: map catalog and a run scene per map`.

---

### Task 7: The last map setting

**Files:**
- Modify: `scripts/settings/game_settings.gd`, `scripts/settings/settings_store.gd`, `tests/test_game_settings.gd`, `tests/test_settings_store.gd`

**Interfaces:**
- Produces: `GameSettings.last_map: StringName` (default the catalog's `default_id()`; the constant `GameSettings.DEFAULT_MAP := &"forest"` avoids a settings-to-catalog dependency and a test pins it equal to `MapCatalog.default_catalog().default_id()`); `reset()` restores it; `to_dict()` is unchanged; `GameSettings.play_dict() -> Dictionary` (`{"last_map": String}`) and `GameSettings.apply_play(data: Dictionary)` (a non-string or empty value is ignored); `SettingsStore` writes a `play` object and `load_file` applies it when it is a dictionary. An unknown saved id is kept by the store (it cannot know the catalog); the screen treats an id not in the catalog as the default.

- [ ] **Step 1: Write the failing tests.** `test_game_settings`: `test_last_map_defaults_to_the_forest`, `test_default_map_matches_the_catalog`, `test_reset_restores_the_default_map`, `test_apply_play_ignores_bad_values`. `test_settings_store`: `test_last_map_round_trips_through_the_file`, `test_a_file_with_no_play_object_loads_the_default_map`, `test_a_play_object_of_the_wrong_type_is_ignored`, `test_an_old_settings_file_still_loads_audio_and_fx`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.** Run the two files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: remember the last played map in settings`.

---

### Task 8: `MapPreview`

**Files:**
- Create: `scripts/ui/map_preview.gd`, `tests/test_map_preview.gd`

**Interfaces:**
- Consumes: `MapData.floor_color`, `solid_shapes()`, `placements`, `size`.
- Produces: `MapPreview` (`Control`): `const PREVIEW_SIZE := Vector2(128, 72)`, `set_map(map: MapData) -> void`, `scale_factor() -> float` (`PREVIEW_SIZE.x / map.size.x`), `item_count() -> int` (number of shapes plus placement dots it will draw). `custom_minimum_size` is `PREVIEW_SIZE`, `mouse_filter` IGNORE, draws in one `_draw`: a floor-colour rect, a dark outline, each RECT obstacle as a filled rect (at least 1 px wide) and each CIRCLE as a filled 1 px-grained circle, each placement as a 3 by 3 yellow dot, and the start as a white 3 by 3 dot, all in whole pixels. It never changes the map.

- [ ] **Step 1: Write the failing tests:** `test_it_is_128_by_72_and_ignores_the_mouse`, `test_the_scale_comes_from_the_map_size`, `test_item_count_is_shapes_plus_placements`, `test_an_empty_map_still_draws_the_floor` (set a bare `MapData`, `item_count() == 0`, no error), `test_a_null_map_draws_nothing_and_does_not_crash`, `test_it_does_not_mutate_the_map` (compare `solid_shapes().size()` and `placements.size()` before and after), `test_a_forest_preview_counts_its_placements` (nine). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `MapPreview` with whole-pixel drawing (`draw_rect`, `draw_circle`). Run the file and `tests/test_ui_look.gd`. Expected: PASS.
- [ ] **Step 3: Commit** `feat: schematic map preview`.

---

### Task 9: The map select screen and the home wiring

**Files:**
- Create: `scripts/ui/map_select_screen.gd`, `scenes/ui/map_select_screen.tscn`, `tests/test_map_select_screen.gd`
- Modify: `scripts/home/home_screen.gd`, `scenes/home/home.tscn`, `tests/test_home_screen.gd`

**Interfaces:**
- Consumes: `MapCatalog.default_catalog()`, `MapEntry`, `MapPreview`, `PlayerProfile.best_seconds(map_id)`, `RunClockLabel.format(seconds) -> String`, `GameSettings.last_map`, `TouchBridge`, `UiKit`, `SceneSwitcher`.
- Produces: `MapSelectScreen` (`CanvasLayer`, layer 26, process Always, hidden until opened): `signal closed`, `signal map_chosen(entry: MapEntry)`, `open(profile: PlayerProfile, catalog: MapCatalog, last_map: StringName) -> void`, `close() -> void`, `is_open() -> bool`, `card_count() -> int`, `card_text(index: int) -> String` (the card's name, theme line, "Boss: <name>" and best line joined by newlines), `focused_index() -> int`, `choose(index: int) -> void` (emits `map_chosen` once, ignored during a 300 ms guard after opening and for a bad index), `handle_event(event: InputEvent) -> bool`. Each card is a button-like panel (about 140 by 150) holding a `MapPreview`, a `Heading` name, a `Muted` wrapped theme line, "Boss: <the first boss of the entry's spawn config>", and "Best: m:ss" or "No best yet" from the profile; below, Back (red) and Play (green) at least `UiKit.ACTION_SIZE`. A card shows its map's best only. `Esc`, the `ui_cancel` action and a tap outside the cards and buttons close it. Explicit focus neighbours: cards left and right, cards down to Play, Play and Back sideways. `HomeScreen`: a `$MapSelectScreen` child; Play opens it with the profile, the catalog and `GameSettings.last_map` (`play()` is replaced by `open_map_select()`); `play_map(entry: MapEntry) -> Error` sets `GameSettings.last_map = entry.map.id`, saves settings (`SettingsStore.save_file(settings_path)`) and returns `SceneSwitcher.change_to(get_tree(), entry.scene_path)`; `handle_input` also stands down while the select screen is open; `closed` refocuses Play; `HomeScreen.run_scene_path` is removed and tests move to `play_map`.

- [ ] **Step 1: Write the failing tests.** `test_map_select_screen`: `test_it_builds_one_card_per_catalog_entry_in_order`, `test_each_card_shows_name_theme_boss_and_best` (profile with a forest best of 125 s: "Best: 2:05"; the ruins show "No best yet"), `test_focus_starts_on_the_last_played_map` and `test_an_unknown_last_map_focuses_the_first_card`, `test_choosing_a_card_emits_map_chosen_once_with_its_entry`, `test_a_choice_inside_the_input_guard_does_nothing`, `test_back_and_escape_close_it_and_emit_closed`, `test_a_tap_outside_closes_and_a_tap_on_a_card_chooses_it` (events through `handle_event` with positions from `get_global_rect()`), `test_left_and_right_move_focus_between_cards_and_down_reaches_play` (`find_valid_focus_neighbor`), `test_a_bad_index_is_ignored`, `test_card_text_fits_each_card` (measure each label with `UiFont.plain()` against its width, as `test_shop_screen` does), `test_buttons_meet_the_touch_sizes`, `test_it_is_process_always_and_pauses_nothing`. `test_home_screen`: `test_play_opens_the_map_select_and_changes_no_scene`, `test_play_map_remembers_the_map_and_saves_settings` (temp settings path, then `SettingsStore.load_file` gives the id back), `test_play_map_with_a_missing_scene_returns_an_error_and_keeps_the_screen` (an entry whose `scene_path` does not exist), `test_input_is_not_bridged_to_the_home_buttons_while_the_select_is_open`, `test_closing_the_select_refocuses_play`, `test_shop_settings_tutorial_and_new_game_still_open`, and update the existing tests that used `run_scene_path` and `play()`. A guard test `test_the_home_script_still_never_names_the_run_scene` stays green (the home script may name `MapCatalog` but not `main.tscn`, `Scenes.RUN` or a scene path literal). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the screen (modelled on `TutorialScreen`: `UiKit.window`, bridged touches pushed with `get_viewport().push_input(TouchBridge.to_mouse_button(event), true)`, the viewport taken before `choose`) and the home wiring. Run `godot --headless --import`, the two files and the whole suite. Expected: PASS.
- [ ] **Step 3: Real window check** (touch rule): write a throwaway scratchpad script that launches the home scene in a window and sends `Input.parse_input_event` touches and left clicks in window coordinates (position times `root.get_final_transform()`): Play opens the select; each card chosen by touch and by mouse loads its scene (confirm with `get_tree().current_scene.scene_file_path`); Back closes; the saved settings file shows the last map. Take a screenshot of the select screen and read it. Record what was seen in the ledger.
- [ ] **Step 4: Commit** `feat: map select screen`.

---

### Task 10: The stress option, the order check, docs and the full verification

**Files:**
- Modify: `scripts/dev/stress_test.gd` (a `--map=<id>` option), `tests/test_stress_report.gd` only if it parses options, `CLAUDE.md`, `development-log.md`, `sprint-development.md`, `docs/sprints/sprint-16a-design.md` (status line), `README.md` if it lists screens or maps
- Create (scratchpad only): the order-check driver script

**Interfaces:**
- Consumes: `MapCatalog.default_catalog().find(id)`.
- Produces: stress scene option `--map=<id>`: loads that catalog entry's map into the stress scene's map instead of the first map (works with `--obstacles`); an unknown id pushes an error listing the valid ids and keeps the default. Update the option comment at the top of the file.

- [ ] **Step 1: Write the failing test** (in `tests/test_stress_report.gd` or a small `tests/test_stress_options.gd` if the script's argument parsing is already testable; otherwise test the catalog lookup it uses): `test_an_unknown_map_id_is_reported_and_the_default_kept`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** `--map=`. Run `godot --headless --import` and the whole suite. Expected: PASS.
- [ ] **Step 3: Performance.** On a plugged-in laptop (not Low Power Mode), run for each of `forest`, `first_map`, `maze`: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --obstacles --drops --map=<id>` three times; record the median fps against the ruins. Then `godot --headless --fixed-fps 60 -s scripts/dev/soak_test.gd -- --rounds=6 --frames=600` on each map's run scene if the soak driver takes a scene path (else note that it only runs the ruins and ledger it). Expected: forest and maze within about 15% of the ruins; ledger the numbers and, if the maze is lower, the cause (shape count) as a ruling.
- [ ] **Step 4: The order check (reported, not asserted).** A scratchpad headless driver (the soak driver's `Main` setup with a standing player at the start who regenerates health, `fixed-fps 60`, the same seed) runs each map for the same simulated 10 minutes of the run clock, three seeds, and records: seconds until the player first reaches 25% health, how many times they drop under 50%, and the kills per minute. Report the table to the user; if forest is not the easiest and maze the hardest, say so plainly and do not change any number.
- [ ] **Step 5: Real window check of the maps.** Throwaway scratchpad script: launch each run scene in a window, take a whole-map screenshot (zoom the camera out through a scratch script, never committed) and close-ups of each kind of point of interest on forest and maze, play a few seconds with real input events, and read the images; confirm the death card (eight rows) and that Restart returns to the same map. Record what was seen.
- [ ] **Step 6: Docs.** `CLAUDE.md`: a new "Maps and the map select (Sprint 16a)" section (catalog, scenes, art-set lookup, per-map bests and the old-save rule, last map in settings, the forest and maze rules, the death card's eight rows, `--map=`, the order check's result) and update the Project State line, the Onboarding/death-card text that mentions the Level row and the Front door's Play description; `development-log.md` entry with the measurements; `sprint-development.md` marks 16a done; the design doc's status becomes "Implemented".
- [ ] **Step 7: Full suite and smoke run.** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` and `godot --headless --quit-after 60`. Expected: all green, no new warnings.
- [ ] **Step 8: Commit** `feat: stress map option, order check and Sprint 16a docs`.
