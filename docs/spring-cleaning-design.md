# Spring cleaning: design and plan

**Status:** Implemented (spring cleaning). Branch `chore/spring-cleaning`.

**Scope (the user's): unused assets and code smells in the repo, items 1 to 6 of the proposal.** Nothing outside this list is touched: not the `.superpowers/` scratch folder, not the Superpowers plugin, not the sprint design and plan documents, not the 92 test-only accessors, not the duplicated test helpers, not the decoration scatter system (a bigger decision left for the user), not the root design docs. Anything deleted is deleted by exact path, listed below or (for item 3) in a list this plan produces and records before deleting.

**Rules for the whole cleanup**
- The full test suite is green before the first change (it is: 2466) and after every item, and a smoke run (`godot --headless --quit-after 60`) shows only the known exit-leak warning.
- Each item is its own commit, so any one can be reverted alone.
- A removal that a test pins is a removal of that test too (never a weakened test): each such test is named below.
- Commands run in the venv; never bare `python3`; one Godot process at a time.

## 1. The debug cheat keys

**Why:** F8, F9, F10 and F12 work on the live web build (F12 gives 100 XP that is saved to the player's profile), and their own comments say "delete later". The real systems (potions, crafting, levels) exist.

**Remove**
- `scripts/main/main.gd`: the `debug_toggle_map`, `debug_restore_mana`, `debug_give_scrolls`, `debug_give_potions` and `debug_give_xp` branches of `_unhandled_input`, and the `debug_scrolls` export with its comment. **Keep** the F3 `debug_perf_overlay` branch (testers use it).
- `scenes/main/main.tscn`: the `debug_scrolls = [...]` line and the 15 scroll `ext_resource` lines only it uses (`load_steps` lowered to match).
- `project.godot`: the five input actions `debug_restore_mana`, `debug_give_scrolls`, `debug_give_xp`, `debug_give_potions` and `debug_toggle_map` (keep `debug_perf_overlay`).
- `scripts/world/map_debug_overlay.gd` (+ `.uid`) and its use in `scripts/world/game_map.gd` (the hidden `Debug` node and `toggle_debug()`), because with F7 gone nothing can show it.
- Tests: `tests/test_map_debug_overlay.gd` (+ `.uid`) is deleted; in `tests/test_input_map.gd` the five actions leave the expected list and their tests (`test_debug_restore_mana_is_a_key`, `test_debug_give_scrolls_is_a_key`, `test_debug_give_xp_is_a_key`, `test_debug_give_potions_is_f8`, `test_debug_toggle_map_is_f7`) go; in `tests/test_main_map.gd` the F7 test goes; in `tests/test_main.gd` the tests that exercise the cheat keys go (`test_debug_key_refills_drained_mana`, `test_debug_key_gives_three_of_every_scroll`) and the two tests that only use `debug_give_scrolls` as a way to hand scrolls to the player (around lines 248 and 269) now call `player.inventory.add(...)` directly; in `tests/test_main_progression.gd` the two uses of `debug_give_xp` and `debug_give_potions` as test tools become direct calls (`player.progress.add_xp(100)`, `run_potions.add_potion(...)`), keeping what each test proves.
- New guard `tests/test_no_cheat_keys.gd`: the Input Map has no action starting `debug_` except `debug_perf_overlay`, and `Main` has no `debug_scrolls` property.
- Docs: `CLAUDE.md` lines about F7, F8, F9, F10 and F12 (the Crafting, World and maps, Obstacles ("F7 also draws...") and Web build bullets) are corrected; `README.md` and `technical-design.md` if they name these keys. Historical sprint design and plan documents are not edited.

## 2. Unused art

**Remove (sources and every built output `assets/sprites/<name>_*`: the sheets, their `.import` files, the `.tres` and the silhouette):**
`tile_hall`, `tile_path`, `wall_brick`, `post_marble`, `icon_scroll`, `decor_grass`, `decor_moss` (about 25 KB). Each is never named in any script, scene or resource, and no map names its floor or wall style.
- Tests that name them are updated, not weakened: `tests/test_world_art.gd` (the `tile_path`, `post_marble` and `decor_moss` cases become cases on the sprites that remain, or are removed where they only pinned the unused art), plus whichever file `grep` finds when the work starts.
- The decoration styles in use by the maps (`flowers`, `mushrooms`, `pebbles`, `cracks`) **stay**: the maps still name them, even though every `decoration_count` is 0.
- Docs: `CLAUDE.md` lines saying the brick wall, the path and hall floors and the marble post are drawn but unused.

## 3. Silhouette sheets nothing shows

**Why:** the art tool builds a white outline sheet for every sprite, but only `Enemy` (an elite's outline, `enemy.gd`) ever shows one. About 70 sprites (effects, icons, shadows, pickups, scrolls, the player, equipment, the bosses) carry sheets that are never displayed (an estimated 840 KB of tracked files).

**Change:** a new optional `.sprite` header line `outline` (parsed into `SpriteSource.outline: bool`) means "build a silhouette sheet". `ArtBuilder` builds (and for hand-drawn sprites derives) the silhouette only when the source says `outline`. The 21 enemy sources (`enemy_*.sprite`: 7 plain, 4 forest, 3 ruins and 7 maze) get the line; nothing else does. `SpriteLibrary.find_silhouette` already returns null for a sprite without one and `BodyView` copes with that.
- **Delete** every `assets/sprites/*_silhouette.*` (png, `.import`, `.tres`) that does not belong to an `enemy_*` sprite. The exact list (count and total size) is generated by running the changed tool and diffing, recorded in the ledger and shown to the user in the final message before it is committed.
- Tests: `tests/test_art_assets.gd`'s expected-variants helper adds the silhouette only for a source with `outline`; new `test_every_enemy_sprite_declares_an_outline` and `test_only_sprites_that_declare_an_outline_have_a_silhouette`; the orphan check keeps catching stray files. `tests/test_enemy_art.gd` (elite outline) stays green unchanged.
- Docs: the Art pipeline section of `CLAUDE.md` ("every sprite also gets a white `_silhouette` sheet") and the `.sprite` format notes.

## 4. A smaller web package

**Change:** `export_presets.cfg`'s `exclude_filter` gains `art/*, audio/*, tools/*, scenes/world/fx_test.tscn, scenes/world/sound_test.tscn, scenes/world/stress_test.tscn, scenes/world/test_arena.tscn`: sources and developer tools the game never loads at runtime. **The dev scripts stay in the package** (`scripts/dev/*`, `scripts/world/fx_test.gd`, `scripts/world/sound_test.gd`): they define `class_name`s that the project's class list names, and excluding a script that a class list points at is a risk I cannot test here.
- **Limit, stated plainly:** this machine has no Godot web export templates (installing them is a large download into the home folder, which the user's rules forbid), so the package size change cannot be measured locally. Godot's "all resources" mode may not even pack the non-resource text sources, in which case the filter changes nothing but is harmless. The next GitHub Actions web build will show the real size.
- **Guard:** new `tests/test_export_filter.gd` reads `export_presets.cfg` and fails if any script, scene or resource that ships (anything not under an excluded folder or file) names a `res://` path inside an excluded folder or an excluded file. It also fails if the main scene, `home.tscn`, `main.tscn`, the three run scenes or any catalog's files would be excluded.

## 5. Dead code and stale text

- Delete `MerchantScreen.potion_button_center` (never called, even by tests) and `ThemeBuilder.RED_DARK` (never used).
- Rewrite the four "TEMPORARY look" or "TEMPORARY colours" comments that no longer apply (`scripts/world/map_decor_layer.gd`, `scripts/enemies/boss.gd`, `scripts/progression/value_gem.gd`, `scripts/enemies/enemy_projectile.gd`): they now describe the real art or are removed. `tests/test_ui_look.gd` (which fails on a leftover TEMPORARY marker in the UI) stays green.
- Stale text: the 16b section of `CLAUDE.md` ("the ruins and maze still send the Ember Titan until 16d"), and the first comment line of `art/sprites/enemy_maze_tank.sprite` (a comment, no rebuild effect).

## 6. `.gitignore`

Replace the generic Python template (about 150 lines of Python, Django, Jupyter and similar entries) with only what this repo needs: `.godot/`, `.import/`, `*.translation`, `export_credentials.cfg`, `export/`, `.mono/`, `data_*/`, `.superpowers/`, `.DS_Store`, `venv/` (the Node environment lives there), `__pycache__/` and `*.py[cod]` (the art helper scripts are Python-free but the venv may create caches), and `.env`. Check with `git status` that no tracked file becomes ignored and no ignored file becomes tracked.

## Verification
- After each item: the whole suite (2466 before; the count changes only by the removed and added tests named above) and a smoke run.
- Item 3: run the art tool and `godot --headless --import`; `test_art_assets` green; the elite outline test green; a real-window look at an elite enemy (a screenshot) to confirm its outline still shows.
- Item 1: a real-window check that F8, F9, F10, F12 and F7 do nothing and F3 still toggles the overlay.
- Final: a fresh independent review of the whole branch, a final full suite, the ledger's findings and a list of exactly what was deleted (counts and sizes) in the final message.
