# Spring Cleaning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the debug cheat keys, unused art, never-shown silhouette sheets and dead code, tighten the web export filter and the `.gitignore`, with no change to how the game plays or looks.

**Architecture:** Six independent cleanup items, each its own commit and each green on its own. Item 3 adds one optional `.sprite` header line (`outline`) so the art tool builds silhouette sheets only for sprites that show an outline (the enemies).

**Tech Stack:** Godot 4.7 GDScript, GUT, the art tool (`tools/art/art_builder.gd`).

**Spec:** `docs/spring-cleaning-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>`. After adding or removing a `class_name`, run `godot --headless --import`; after editing a `.sprite`, run `godot --headless -s tools/art/art_builder.gd` and then `godot --headless --import`. **Never run two Godot processes at once**; run the full suite alone, in the background for `task-done`.
- **Delete only by exact path, and only what the design names** (item 3's list is generated and recorded in the ledger before deleting). Never touch `.superpowers/`, the Superpowers plugin, `docs/superpowers/plans/*` or `sprint-*-design.md` (historical records), the test-only accessors, duplicated test helpers, the decoration scatter system (`MapDecor`, `MapDecorLayer`, the maps' `decoration_*` fields, the `flowers`, `mushrooms`, `pebbles` and `cracks` decor sprites) or the root design docs. Use the literal paths in `git rm` (or `rm` with literal paths for untracked files), never wildcards or variables.
- A removal that a test pins removes that test (named in the task); a test that only used a removed thing as a tool is rewritten to keep what it proves. No test is weakened to pass.
- Each task ends with the whole suite green (2466 tests before this plan; the count moves only by the removed and added tests named here) and a smoke run (`godot --headless --quit-after 60`) showing only the known `ObjectDB instances were leaked at exit` and `resources still in use at exit` lines. Each task is one commit.
- Before every deletion commit, run `git status --short` and read the list: only the named paths may appear.
- Rulings to ledger where they matter: the web package size cannot be measured here (no export templates); any test removed or rewritten; the item-3 file list (count and total size).

## Review Focus

- **Nothing the game uses was removed:** every sprite, scene, resource and script the game loads at runtime still exists (a smoke run and the suite show it; the export-filter guard test checks the shipped set).
- **Cheat keys are really gone:** no `debug_` input action but `debug_perf_overlay`, no `debug_scrolls`, and F3 still toggles the performance overlay in a real window; the tests that used the keys as tools still prove what they proved.
- **Silhouettes:** every enemy sprite still has its outline sheet (elites outline in a real window), no non-enemy sprite has one, and no orphan or missing file remains; the hand-drawn path of the art tool still works with the new flag.
- **Export filter:** nothing that ships names a path the filter excludes; the main scene, run scenes and catalogs are not excluded.
- **`.gitignore`:** no tracked file becomes ignored and no ignored file becomes tracked.

---

### Task 1: The debug cheat keys

**Files:**
- Modify: `scripts/main/main.gd`, `scenes/main/main.tscn`, `project.godot`, `scripts/world/game_map.gd`, `tests/test_input_map.gd`, `tests/test_main_map.gd`, `tests/test_main.gd`, `tests/test_main_progression.gd`, `CLAUDE.md`, `README.md` and `technical-design.md` (only where they name the keys)
- Delete: `scripts/world/map_debug_overlay.gd`, `scripts/world/map_debug_overlay.gd.uid`, `tests/test_map_debug_overlay.gd`, `tests/test_map_debug_overlay.gd.uid`
- Create: `tests/test_no_cheat_keys.gd`

**Interfaces:**
- Produces: `Main` without `debug_scrolls` and with `_unhandled_input` keeping only `toggle_inventory` and `debug_perf_overlay`; `GameMap` without `toggle_debug()` and the `Debug` node; `project.godot` input actions without `debug_restore_mana`, `debug_give_scrolls`, `debug_give_xp`, `debug_give_potions` and `debug_toggle_map`.

- [ ] **Step 1: Write the failing guard** (`tests/test_no_cheat_keys.gd`): `test_the_input_map_has_no_debug_action_but_the_performance_overlay` (every action name starting `debug_` is exactly `debug_perf_overlay`), `test_main_has_no_cheat_export` (a `Main` instance has no property `debug_scrolls`), `test_a_cheat_key_press_changes_nothing` (build `main.tscn` with `save_path = ""` and the pick screen's `pause_tree = false`; send F8, F9, F10 and F12 as `InputEventKey` events through `_unhandled_input`: the player's scroll inventory total, XP and the potion stock stay 0 and mana is unchanged), `test_the_performance_overlay_key_still_works` (the `debug_perf_overlay` action still toggles `FxSettings.perf_overlay`, restoring it after). Run. Expected: FAIL (the actions and export still exist).
- [ ] **Step 2: Remove** the five branches and the export from `main.gd`, the `debug_scrolls` line and the 15 scroll `ext_resource` lines (ids `20` to `34`, paths `res://resources/scrolls/...`) from `main.tscn` (lower `load_steps` by 15; keep the `scroll_data.gd` script resource only if something else in the scene uses it, else remove it and lower again), the five actions from `project.godot`, the overlay creation and `toggle_debug()` from `game_map.gd`, and `git rm` the two overlay files and two test files. Run `godot --headless --import`.
- [ ] **Step 3: Update the tests that used the keys:** in `tests/test_input_map.gd` remove the five actions from the expected-actions list and delete `test_debug_restore_mana_is_a_key`, `test_debug_give_scrolls_is_a_key`, `test_debug_give_xp_is_a_key`, `test_debug_give_potions_is_f8` and `test_debug_toggle_map_is_f7`; in `tests/test_main_map.gd` delete the F7 test (around line 72); in `tests/test_main.gd` delete `test_debug_key_refills_drained_mana` and `test_debug_key_gives_three_of_every_scroll`, and rewrite the two tests around lines 248 and 269 that send `debug_give_scrolls` to hand the player scrolls so they call `player.inventory.add(<scroll>, 3)` for the scrolls they need (load them from `res://resources/scrolls/...`), keeping every other assertion; in `tests/test_main_progression.gd` replace the `debug_give_xp` use (around line 202) with `player.progress.add_xp(100)` and the `debug_give_potions` use (around line 487) with `run_potions.add_potion(<id>, RunPotions.MAX_POTIONS)` plus `player.belt.refresh()`. Run each changed file and `test_no_cheat_keys`. Expected: PASS.
- [ ] **Step 4: Docs.** In `CLAUDE.md` correct the bullets that name F7, F8, F9, F10 and F12 (the Crafting, Obstacles ("F7 also draws..."), World and maps, and Web build bullets) to say the debug keys were removed in the spring cleaning and only the F3 performance overlay remains; do the same in `README.md` and `technical-design.md` if they name them.
- [ ] **Step 5: Real-window check** (throwaway scratchpad script, windowed, `HOME` pointed at a scratch folder): load `main.tscn`, send F8, F9, F10, F12 and F7 as key events, confirm nothing changes (read the player's inventory, XP and a screenshot), then send F3 and confirm the overlay shows. Record in the ledger.
- [ ] **Step 6: Whole suite and smoke run** (`task-done` for this task). Expected: PASS.
- [ ] **Step 7: Commit** `chore: remove the debug cheat keys and the map debug overlay`.

---

### Task 2: Unused art

**Files:**
- Delete (sources): `art/sprites/tile_hall.sprite`, `art/sprites/tile_path.sprite`, `art/sprites/wall_brick.sprite`, `art/sprites/post_marble.sprite`, `art/sprites/icon_scroll.sprite`, `art/sprites/decor_grass.sprite`, `art/sprites/decor_moss.sprite`
- Delete (built outputs): every file matching `assets/sprites/<name>_*` for those seven names (list them with `git ls-files assets/sprites | grep -E '^assets/sprites/(tile_hall|tile_path|wall_brick|post_marble|icon_scroll|decor_grass|decor_moss)_'` and delete each listed path with `git rm`)
- Modify: `tests/test_game_map.gd`, `tests/test_world_art.gd`, `CLAUDE.md`

**Interfaces:**
- Produces: an art set of 108 sprites (115 minus seven); nothing names the removed ones.

- [ ] **Step 1: Prove they are unused.** Run `grep -rn "tile_hall\|tile_path\|wall_brick\|post_marble\|icon_scroll\|decor_grass\|decor_moss" scripts resources scenes project.godot tools` and confirm no hit; the style names in the maps (`grass`, `ruin`, `border`, `stone`, `hedge`, `tree`, `flowers`, `mushrooms`, `pebbles`, `cracks`) must not map to any removed sprite (`WorldArt` builds `tile_<style>`, `wall_<material>`, `post_<material>` and `decor_<style>`: confirm `path`, `hall`, `brick`, `marble`, `grass` (decor) and `moss` are named by no `.tres`). Record the output in the ledger.
- [ ] **Step 2: Update the tests that used the art as fixtures** (they are fixtures, not pins of the art): in `tests/test_game_map.gd` replace `tile_path_base.tres` with `tile_ruin_base.tres` where a second tile is needed (lines around 305, 335, 448, 461; use `tile_grass_base.tres` where a different one is needed) and `decor_moss_base.tres` with `decor_pebbles_base.tres` (around 431); in `tests/test_world_art.gd` replace `post_marble_base.tres` with `post_tree_base.tres` and `decor_moss_base.tres` with `decor_pebbles_base.tres` (around 41 and 42). The assertions stay as they are (check each still means the same thing; if a test needed the unused sprite to differ from another, pick sprites that differ). Run both files. Expected: PASS.
- [ ] **Step 3: Delete** the seven sources and their built outputs by exact path (`git rm`), run `godot --headless --import`, `godot --headless -s tools/art/art_builder.gd` (it must report no changes needed for the rest) and `test_art_assets`. Expected: PASS (the orphan check proves no output remains without a source).
- [ ] **Step 4: Docs.** `CLAUDE.md`: remove the lines saying the brick wall, the `path` and `hall` floors and the marble post are drawn but unused, and the sprite counts if they appear.
- [ ] **Step 5: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 6: Commit** `chore: remove unused art (seven sprites)`.

---

### Task 3: Silhouette sheets only where an outline is shown

**Files:**
- Modify: `scripts/art/sprite_source.gd`, `scripts/art/art_builder.gd`, `tests/test_art_assets.gd`, `tests/test_sprite_source.gd` (or the file that tests the parser: find with `grep -ln "hand_drawn" tests`), the 21 sources `art/sprites/enemy_*.sprite` (`enemy_standard`, `enemy_swarmer`, `enemy_chaser`, `enemy_tank`, `enemy_ranged`, `enemy_exploder`, `enemy_support`, `enemy_forest_swarmer`, `enemy_forest_tank`, `enemy_forest_exploder`, `enemy_forest_support`, `enemy_ruins_standard`, `enemy_ruins_chaser`, `enemy_ruins_ranged`, `enemy_maze_standard`, `enemy_maze_swarmer`, `enemy_maze_chaser`, `enemy_maze_tank`, `enemy_maze_ranged`, `enemy_maze_exploder`, `enemy_maze_support`), `CLAUDE.md`
- Delete: every `assets/sprites/*_silhouette.png`, `*_silhouette.png.import` and `*_silhouette.tres` whose sprite name does not start with `enemy_` (the exact list is generated in Step 4)

**Interfaces:**
- Produces: `SpriteSource.outline: bool` (set by a header line `outline`; ignored on a surface); `ArtBuilder` writes a silhouette sheet only when `source.outline` (for hand-drawn sprites too); `SpriteLibrary.find_silhouette` is unchanged (null when there is none).

- [ ] **Step 1: Write the failing tests.** In the parser's test file: `test_an_outline_line_sets_outline`, `test_a_source_without_the_line_has_no_outline`, `test_outline_on_a_tile_is_ignored` (a tile with the line builds no silhouette and reports no error). In `tests/test_art_assets.gd`: change `_variants_for` to add `"silhouette"` only when `source.outline`; add `test_every_enemy_sprite_declares_an_outline` (every `art/sprites/enemy_*.sprite` has `outline`), `test_only_sprites_that_declare_an_outline_have_a_silhouette_sheet` (no `assets/sprites/<name>_silhouette.png` exists for a source without `outline`), and `test_an_outline_sprite_builds_its_silhouette` (a throwaway source with `outline` in a temp folder produces one). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `outline` parsing in `SpriteSource` and make `ArtBuilder.build_all` and `_build_hand_drawn` write the silhouette only when `source.outline` (keep `build_silhouette` and `silhouette_of` as they are). Add a line `outline` under the header of each of the 21 enemy sources (after the `size` line, as the other optional lines sit). Run `godot --headless --import`, `godot --headless -s tools/art/art_builder.gd`; the tests from Step 1 that need the new data now pass, but `test_art_assets` also fails on the old silhouette files (orphans) until Step 4.
- [ ] **Step 3: Generate the list.** With a scratchpad script (venv Python), list every `assets/sprites/*_silhouette.*` file (png, `.png.import`, `.tres`) tracked by git whose basename does not start with `enemy_`: write the paths to a scratchpad file and print the count and total size (`du -ck`). Record the count and size in the ledger and read the list: it must contain no `enemy_` file and every non-enemy sprite family named in the design (fx, icon, decor, shadow, poi, scroll, robe, hat, hood, wand, staff, post, player, pickup, reticle, lectern, boss).
- [ ] **Step 4: Delete** exactly those files with `git rm` (feed the list file to `git rm` through `xargs -a` equivalent that uses the literal paths in the list; do not use a shell glob). Run `godot --headless --import`, `godot --headless -s tools/art/art_builder.gd` (no change expected) and `test_art_assets`, `test_enemy_art`, `test_body_view`, `test_forest_art`, `test_ruins_art`, `test_maze_art`, `test_player_look`. Expected: PASS.
- [ ] **Step 5: Real-window check** (scratchpad script, windowed, scratch `HOME`): spawn an elite enemy (`make_elite`) of each archetype on a run scene and take a screenshot; read it: the outline still shows; also take a screenshot of the player, a pickup and the Lectern to confirm nothing else changed. Record in the ledger.
- [ ] **Step 6: Docs.** `CLAUDE.md` Art pipeline section: a sprite gets a white silhouette sheet only if its source has an `outline` line (the enemies, for the elite outline); update the "every sprite also gets" sentence and the `SpriteLibrary` notes.
- [ ] **Step 7: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 8: Commit** `chore: build silhouette sheets only for enemy sprites`.

---

### Task 4: The export filter and its guard

**Files:**
- Modify: `export_presets.cfg`
- Create: `tests/test_export_filter.gd`

**Interfaces:**
- Produces: `exclude_filter` = the current value plus `, art/*, audio/*, tools/*, scenes/world/fx_test.tscn, scenes/world/sound_test.tscn, scenes/world/stress_test.tscn, scenes/world/test_arena.tscn`.

- [ ] **Step 1: Write the failing test** (`test_export_filter`): parse `exclude_filter` from `export_presets.cfg` (split on commas, trim; each pattern is a path prefix when it ends in `/*`, else an exact path). Tests: `test_the_filter_excludes_sources_and_dev_scenes` (the eight new patterns are present), `test_nothing_that_ships_names_an_excluded_path` (walk every file under `scripts/`, `scenes/`, `resources/`, `assets/` and `project.godot` that is not itself excluded; read it as text; none contains `res://` followed by an excluded prefix or an excluded exact path), `test_the_entry_points_are_not_excluded` (`res://scenes/home/home.tscn`, `res://scenes/main/main.tscn`, `main_forest.tscn`, `main_maze.tscn`, `res://scenes/world/game_map.tscn` and every `.tres` under `resources/` are not matched by any pattern). Run. Expected: FAIL (the patterns are not there yet).
- [ ] **Step 2: Edit** `exclude_filter` as above. Run `test_export_filter`. Expected: PASS. If `test_nothing_that_ships_names_an_excluded_path` reports a reference (for example a shipped script reading `res://art/palette.txt`), do not exclude that path: remove its pattern and ledger it as a ruling.
- [ ] **Step 3: Ledger the limit:** record that the package size could not be measured locally (no export templates) and that the next GitHub Actions web build shows it.
- [ ] **Step 4: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 5: Commit** `chore: keep sources and developer tools out of the web package`.

---

### Task 5: Dead code and stale text

**Files:**
- Modify: `scripts/ui/merchant_screen.gd`, `scripts/art/theme_builder.gd`, `scripts/world/map_decor_layer.gd`, `scripts/enemies/boss.gd`, `scripts/progression/value_gem.gd`, `scripts/enemies/enemy_projectile.gd`, `CLAUDE.md`, `art/sprites/enemy_maze_tank.sprite`

**Interfaces:**
- Produces: no `MerchantScreen.potion_button_center`, no `ThemeBuilder.RED_DARK`, no "TEMPORARY" marker in game code.

- [ ] **Step 1: Prove they are dead.** `grep -rn "potion_button_center\|RED_DARK" scripts tests tools resources scenes` shows only the definitions; record it.
- [ ] **Step 2: Remove** `potion_button_center` (the function and its doc comment) and `RED_DARK`. Rewrite the four TEMPORARY comments so they describe what the code is now (`map_decor_layer.gd`: "Draws every decoration, in chunks so the ones off screen cost nothing."; `boss.gd`: drop "TEMPORARY look:" and say the boss draws through `BodyView`; `value_gem.gd`: "Placeholder colours used when there is no art."; `enemy_projectile.gd`: drop "TEMPORARY look:" and say the shot is drawn by its sprite). Run `tests/test_ui_look.gd` and `tests/test_merchant_screen.gd`.
- [ ] **Step 3: Stale text.** In `CLAUDE.md` correct the 16b section sentence "the ruins and maze still send the Ember Titan until 16d" (now only the ruins send the Titan, and the maze sends the Dire Minotaur); change the first comment line of `art/sprites/enemy_maze_tank.sprite` so it describes the redrawn troll ("A troll: a hulking tusked brute with moss patches, a bone necklace and thick darker arms.") (a comment: the built outputs do not change; run the art tool and confirm `git status` shows no `assets/` change).
- [ ] **Step 3b: A guard for the marker.** Extend `tests/test_ui_look.gd`'s idea to game code with a new small test `tests/test_no_temporary_markers.gd`: no file under `scripts/` or `resources/` contains the word `TEMPORARY`. Run. Expected: PASS.
- [ ] **Step 4: Whole suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 5: Commit** `chore: remove dead code and stale comments`.

---

### Task 6: `.gitignore`, the final check and the review

**Files:**
- Modify: `.gitignore`
- Modify (ledger/docs only): `docs/spring-cleaning-design.md` (status line), `development-log.md`

**Interfaces:**
- Produces: a `.gitignore` holding only the Godot, scratch and system entries below.

- [ ] **Step 1: Rewrite `.gitignore`** to exactly these entries (with a one-line comment above each group): `.godot/`, `.import/`, `*.translation`, `export_credentials.cfg`, `export/`, `.mono/`, `data_*/` (Godot), `.superpowers/` (the executing-plans scratch folder), `venv/` (the Node environment), `__pycache__/` and `*.py[cod]` (Python caches), `.env`, `.DS_Store`.
- [ ] **Step 2: Check what changes.** Before overwriting, save the old file in the scratchpad. After: run `git status --short --ignored | head -40` before and after (use `git stash`-free methods: compare the output of `git ls-files -ci --exclude-standard` (tracked files that the new rules would ignore: must print nothing) and `git status --short` (no newly untracked files appear that were ignored before, apart from none)). Record both outputs in the ledger. If any tracked file would become ignored or any previously ignored file would become visible, restore the missing entry.
- [ ] **Step 3: Docs.** `development-log.md`: a "Spring cleaning" entry listing exactly what was removed (counts and sizes: the five actions and the overlay, seven sprites, the silhouette count and size, the eight filter patterns, the dead code) and the limits (package size not measurable locally; the 92 test-only accessors, the duplicated test helpers, the decoration system and the root design docs left for the user to decide). The design doc's status becomes "Implemented".
- [ ] **Step 4: Full suite and smoke run** (`task-done`). Expected: PASS.
- [ ] **Step 5: Commit** `chore: trim the .gitignore and record the spring cleaning`.
