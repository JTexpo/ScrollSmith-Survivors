# Sprint 13a: The Art Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the coloured rectangles of the player, the seven enemy archetypes (in all five elements) and the Ember Titan with animated pixel-art sprites, made by a pipeline of text pixel grids and a GDScript tool so that any single sprite can be replaced by overwriting its PNG.

**Architecture:** Sprite grids (`art/sprites/*.sprite`) and a palette (`art/palette.txt`) are parsed by `ArtPalette` and `SpriteSource`. `ArtBuilder` builds PNG sheets (one per element variant, plus a silhouette) and `SpriteSetData` resources, written by the command-line tool `tools/art/art_builder.gd` and committed. A `BodyView` node replaces the `Body` colour rectangle: it loads a `SpriteSetData` through `SpriteLibrary`, plays animations, flips by facing, tints, outlines, and falls back to the old square when there is no art.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `docs/sprints/sprint-13a-design.md` (repo root). Read it first. Tiles, the Lectern, points of interest, pickups, spell art and the HUD (13b), audio (13c) and polish effects (13d) are NOT built here.

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`), and **scripted edits use Python, never Perl** (the user's preference). Prefer the Edit tool for multi-line changes. Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit </dev/null` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script **and after the tool writes new PNGs**. On macOS use `sed -i ''`, and zsh does not word-split unquoted variables (and `path` is a special zsh variable: never use it as a shell variable name).
- Gameplay does not change: hit shapes (12×12 hurtbox and contact boxes), speeds, damage, drops, difficulty and every existing number stay as they are. The sprite never decides collision.
- Look (my calls, in the design): the game stays 480×270 with whole-number scaling and crisp filtering. Sprites are drawn at 1:1: the player on a 16×16 grid, enemies 8 to 24 px by archetype (Swarmer 10, Chaser 12, Standard 14, Support 14, Ranged 14, Exploder 14, Tank 24), the boss 32×32. Every sprite keeps a 1 px transparent margin (the outline silhouette needs it). One palette of at most **40 distinct colours** in total: an outline colour, a neutral ramp, a skin tone, a few fixed accents, and five variants (`none`, `fire`, `thunder`, `land`, `sea`) of five ramp slots, anchored on the README's element families (Fire orange, red, yellow; Thunder yellow, white, electric blue; Land brown, green; Sea blue, cyan, turquoise).
- Source format. `art/palette.txt`: `color <letter> <hex>` lines (one-character letters, never `.`, `1` to `5`, or a space) and `variant <id> <hex1> <hex2> <hex3> <hex4> <hex5>` lines (the colours for ramp slots `1` to `5`: body dark, mid, light, then trim dark and light); `#` starts a comment. `art/sprites/<name>.sprite`: `size <w> <h>`, then `anim <name> <first_frame> <last_frame> <fps> <loop|once>` lines, then each frame as the line `frame` followed by `<h>` rows of exactly `<w>` letters, where `.` is transparent, a palette letter is that colour and `1` to `5` are ramp slots. A sprite that uses a ramp slot is built for all five variants, one that does not is built once as `base`.
- Output naming: `assets/sprites/<name>_<variant>.png` (frames side by side, left to right) and `.tres` (a `SpriteSetData`), plus `assets/sprites/<name>_silhouette.png` and `.tres` (every pixel within 1 px of the sprite, white, for outlines). The tool writes text `.tres` files (so it works before the PNGs are imported), and outputs are committed.
- Every entity shows its old coloured square when it has no art, so a missing sprite never crashes or hides anything, and every existing test that builds an enemy from a hand-made fixture keeps working.
- Performance: the stress scene (`--obstacles`) must stay at least 60 fps and within about 15% of Sprint 12d's about 192 fps. If 300 animated sprites cost too much, drive their frames from one shared clock instead of per-node animation.
- World nodes must not stop touches: `mouse_filter = 2` on any Control. Tests that instantiate `main.tscn` set `save_path = ""` and the pick screen's `pause_tree = false` before `add_child`, and never touch the real save. No test depends on an unseeded random roll.
- Conventions: PascalCase classes, snake_case members, UPPER_SNAKE constants, typed GDScript, `##` doc comments, gameplay values in Resources or `@export`s. Match surrounding code's comment density.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`, never `;`. Commit generated `.uid` files and imported-asset `.import` files with their sources.

## Review Focus

- The committed PNGs always equal what the tool builds from the sources (no stale art), every pixel is a palette colour or transparent, and every animation range is inside its sheet (Tasks 2, 4, 5, 6).
- An entity with no art (a hand-made enemy fixture, an archetype without a sprite, the boss without art) shows the fallback square and never crashes or hides (Tasks 3, 5, 6).
- The hit flash and a state tint do not fight: the flash returns to the current tint, never to a stale white (Task 3).
- Sprites stay 1:1 whatever the enemy's body scale or elite size, and the hurtbox, hitbox and every gameplay number are unchanged (Task 5).
- Death and special-state animations always end: an enemy is freed exactly once even if its death animation is missing or interrupted, a state timer cannot leave the wrong animation playing, and the Exploder still blasts (Task 5).

---

### Task 1: The palette and the sprite source parsers

**Files:**
- Create: `scripts/art/art_palette.gd`, `scripts/art/sprite_source.gd`
- Test: `tests/test_art_sources.gd`

**Interfaces:**
- Produces:
  - `ArtPalette` (`RefCounted`): `static func parse(text: String) -> ArtPalette`, `var errors: PackedStringArray`, `var colors: Dictionary` (letter to `Color`), `var variants: Dictionary` (id to `Array[Color]` of 5), `func color_for(letter: String, variant: StringName) -> Color` (a ramp slot `1` to `5` uses the variant, any other letter its fixed colour, `.` is `Color(0, 0, 0, 0)`), `func has_letter(letter: String) -> bool` (fixed letters, `.` and `1` to `5`), `func distinct_color_count() -> int` (fixed colours plus every variant colour, de-duplicated).
  - `SpriteSource` (`RefCounted`): `static func parse(text: String, palette: ArtPalette) -> SpriteSource`, `var errors: PackedStringArray`, `var frame_size: Vector2i`, `var animations: Array[Dictionary]` (`name`, `first`, `last`, `fps`, `loop`), `var frames: Array[PackedStringArray]` (rows per frame), `func uses_ramp() -> bool` (any `1` to `5` in any frame), `func variants_needed(palette) -> Array[StringName]` (the palette's variant ids when it uses a ramp, otherwise `[&"base"]`).
  - Parse errors (never an exception): a missing or non-positive `size`, a frame with the wrong number of rows, a row of the wrong width, a letter the palette does not know, an animation naming a frame that does not exist, a duplicate animation name, no frames.

- [ ] **Step 1: Write the failing tests** (`tests/test_art_sources.gd`, small palette and sprite texts as constants):
  - `test_a_palette_parses_colors_and_variants` (letters, hex with and without alpha, five variants of five colours), `test_palette_color_for_uses_the_variant_for_ramp_slots_and_the_fixed_color_otherwise`, `test_a_dot_is_transparent`.
  - `test_the_palette_reports_bad_lines` (a letter longer than one character, a reserved letter, a bad hex, a variant with four colours, a duplicate letter: each an error line), `test_distinct_color_count_removes_duplicates`.
  - `test_a_sprite_parses_size_animations_and_frames`, `test_uses_ramp_decides_the_variants_needed` (a sprite with `2` gives the five variant ids, one without gives `[&"base"]`).
  - `test_a_sprite_reports_each_kind_of_error` (one case per error listed above, each producing at least one line and no crash).
  - `test_animation_ranges_must_exist` (last frame beyond the frames, first after last).
- [ ] **Step 2: Run** `-gselect=test_art_sources`. Expected: FAIL (classes not defined).
- [ ] **Step 3: Implement** both parsers as specified. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_art_sources`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the art palette and sprite source parsers`.

### Task 2: The sheet builder, the set resources and the tool

**Files:**
- Create: `scripts/art/art_builder.gd`, `resources/art/sprite_animation_data.gd`, `resources/art/sprite_set_data.gd`, `scripts/art/sprite_library.gd`, `tools/art/art_builder.gd`
- Test: `tests/test_art_builder.gd`

**Interfaces:**
- Consumes: `ArtPalette`, `SpriteSource` (Task 1).
- Produces:
  - `SpriteAnimationData` (`Resource`): `name: StringName`, `first_frame: int`, `last_frame: int`, `fps: float`, `loop: bool`.
  - `SpriteSetData` (`Resource`): `sheet: Texture2D`, `frame_size: Vector2i`, `animations: Array[SpriteAnimationData]`, `frame_count() -> int` (sheet width over frame width), `has_animation(name: StringName) -> bool`, `frames() -> SpriteFrames` (built once per resource from `AtlasTexture` regions, with each animation's speed and loop, cached).
  - `ArtBuilder` (`RefCounted`, static): `build_sheet(source: SpriteSource, palette: ArtPalette, variant: StringName) -> Image` (width `frames * w`, height `h`, RGBA), `build_silhouette(source: SpriteSource) -> Image` (every pixel within one pixel of any non-transparent pixel, white, same layout), `set_text(png_path: String, source: SpriteSource) -> String` (the `.tres` text for a `SpriteSetData`), `build_all(source_dir: String, palette_path: String, out_dir: String) -> PackedStringArray` (writes every sheet, silhouette and `.tres`, returns the list of problems, empty when all well; a source with errors writes nothing for itself).
  - `SpriteLibrary` (`RefCounted`, static): `find(sprite_name: StringName, variant: StringName = &"base") -> SpriteSetData` (`res://assets/sprites/<name>_<variant>.tres`, falling back to `<name>_base.tres`, null when neither exists), `find_silhouette(sprite_name: StringName) -> SpriteSetData`.
  - `tools/art/art_builder.gd` (`extends SceneTree`): runs `ArtBuilder.build_all("res://art/sprites", "res://art/palette.txt", "res://assets/sprites")`, prints each problem as `ART ERROR: ...` and the count of files written as `ART OK: N files`, and quits with a non-zero exit code on any problem.

- [ ] **Step 1: Write the failing tests** (`tests/test_art_builder.gd`; a tiny palette and a 4×4 two-frame source built in code, and a temp output folder inside `res://.godot/art_tests/` created and removed by the test):
  - `test_a_sheet_has_the_frames_side_by_side_with_the_right_colors` (size `2 * 4` by 4, a known pixel in each frame), `test_a_ramp_slot_takes_the_variants_color` (the same source built for `fire` and `sea` differs exactly at the ramp pixels), `test_transparent_pixels_stay_transparent`.
  - `test_the_silhouette_grows_the_shape_by_one_pixel_in_white` (an inner pixel and a pixel just outside it are white, a pixel two away is transparent).
  - `test_set_text_names_the_sheet_the_frame_size_and_every_animation`.
  - `test_build_all_writes_a_sheet_per_variant_a_silhouette_and_a_tres_for_each` (a ramp source gives 5 variant sheets and 1 silhouette, with a matching `.tres` for each, a non-ramp source gives `base` and 1 silhouette), `test_a_bad_source_writes_nothing_and_reports` (returns at least one problem, no files for it).
  - `test_a_set_resource_builds_sprite_frames_with_the_animations` (an in-memory `ImageTexture` sheet, a `SpriteSetData` with two animations: frame counts, `fps`, loop flag, and the cache returns the same object twice), `test_has_animation_and_frame_count`.
  - `test_the_library_finds_a_variant_falls_back_to_base_and_returns_null_when_missing` (uses the player art once Task 4 has committed it; until then this test builds a throwaway `.tres` in the temp folder and a library lookup path argument, so give `SpriteLibrary` a `static var root: String = "res://assets/sprites"` that the test points at the temp folder and restores).
- [ ] **Step 2: Run** `-gselect=test_art_builder`. Expected: FAIL.
- [ ] **Step 3: Implement** all of it. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_art_builder`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the sprite sheet builder, set resources and the art tool`.

### Task 3: BodyView

**Files:**
- Create: `scripts/entities/body_view.gd`
- Test: `tests/test_body_view.gd`

**Interfaces:**
- Consumes: `SpriteSetData`, `SpriteLibrary` (Task 2).
- Produces: `BodyView` (`Node2D`) that builds its own children in `_ready` (an outline `AnimatedSprite2D`, the main `AnimatedSprite2D`, and a 12×12 centred `ColorRect` fallback with `mouse_filter = 2`), so a scene only needs a `Node2D` with the script. API: `signal animation_done(animation: StringName)`; `var fallback_color: Color` (sets the fallback square's colour); `set_look(sprite_name: StringName, variant: StringName = &"base") -> bool` (true and shows the sprite when art exists, false and shows the fallback square otherwise); `set_set(set_data: SpriteSetData) -> void` (for tests and direct use); `has_art() -> bool`; `has_animation(name: StringName) -> bool`; `play(animation: StringName) -> void` (a no-op when the animation is missing or already playing, never restarts); `current_animation() -> StringName`; `set_facing(direction_x: float) -> void` (flips horizontally when negative, a zero keeps the last facing); `set_tint(color: Color) -> void` (a tint on the sprite that is separate from the flash, which uses the node's `modulate`, so the two multiply); `set_outline(color: Color, enabled: bool) -> void` (the silhouette set behind the sprite, in that colour, hidden when disabled or when there is no silhouette); `counter_scale(parent_scale: Vector2) -> void` (sets the sprite and outline scale to `1 / parent_scale` so the pixels stay 1:1 whatever the owner's scale, and leaves the fallback square scaling with its owner as before). A non-looping animation emits `animation_done` once when it ends.

- [ ] **Step 1: Write the failing tests** (an in-memory `SpriteSetData` from an `ImageTexture`, as in Task 2's test):
  - `test_without_art_it_shows_the_fallback_square_and_never_fails` (`set_look` of an unknown name returns false, the square is visible and has `fallback_color`, `play`, `set_outline` and `set_facing` do nothing harmful).
  - `test_set_set_shows_the_sprite_and_hides_the_fallback`, `test_play_switches_animation_and_does_not_restart_the_same_one`, `test_playing_a_missing_animation_keeps_the_current_one`.
  - `test_facing_flips_by_the_sign_and_zero_keeps_it`.
  - `test_the_tint_and_the_flash_do_not_fight` (set a tint, flash through the node's `modulate` as `HitFlashComponent` does, restore `modulate` to white: the sprite still shows the tint; the effective colour during the flash is the flash colour times the tint).
  - `test_a_once_animation_emits_done_exactly_once` (await frames), `test_a_looping_animation_never_emits_done`.
  - `test_the_outline_uses_the_silhouette_in_its_color_and_hides_when_disabled`.
  - `test_counter_scale_keeps_the_sprite_one_to_one_but_not_the_fallback` (parent scale 1.5: sprite scale is 1/1.5, the fallback's own scale is untouched).
  - `test_it_ignores_the_mouse` (every Control child has `mouse_filter == MOUSE_FILTER_IGNORE`).
- [ ] **Step 2: Run** `-gselect=test_body_view`. Expected: FAIL.
- [ ] **Step 3: Implement** `BodyView`. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_body_view`, `-gselect=test_world_input`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: BodyView, the sprite body with a coloured-square fallback`.

### Task 4: The palette, the player art and the player

**Files:**
- Create: `art/palette.txt`, `art/sprites/player.sprite`, the built `assets/sprites/player_base.png` and `.tres` and `player_silhouette.png` and `.tres` (and their `.import` files)
- Modify: `scenes/player/player.tscn` (the `Body` node becomes a `Node2D` with `body_view.gd`), `scripts/entities/player.gd`
- Test: `tests/test_art_assets.gd`, `tests/test_player_art.gd`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:
  - `art/palette.txt`: the palette with at most 40 distinct colours (Global Constraints), including the dark outline colour and the five element variants.
  - `art/sprites/player.sprite`: a 16×16 wizard (a big pointy hat, big eyes, a robe; the builder designs it, original, readable at 1:1 against the dark floor) using fixed palette letters (no ramps, so a single `base` variant), with animations `idle` (2 frames, 3 fps, loop), `move` (4 frames, 10 fps, loop) and `cast` (2 frames, 12 fps, once). Frames are numbered idle 0 to 1, move 2 to 5, cast 6 to 7.
  - `Player`: its `Body` is a `BodyView` (still named `Body`, still the hit flash's target) with `set_look(&"player")` in `_ready`; each physics frame it plays `move` while the velocity is above 5 px/s and `idle` otherwise, faces the aim direction's x while casting and the move direction's x otherwise, and plays `cast` for 0.25 s after `loadout.cast_fired`. Nothing else about the player changes (still a `CharacterBody2D` with the same 12×12 shape).
  - `tests/test_art_assets.gd` (reused by Tasks 5 and 6): for every `art/sprites/*.sprite`: it parses with no errors; the committed sheets exist for every variant it needs plus the silhouette; **each committed PNG equals what `ArtBuilder` builds from the source** (a stale PNG fails); every non-transparent pixel of every PNG is a palette colour (or, for the silhouette, white); each `.tres` loads, its sheet's width is `frames * w` and every animation's frame range is inside it; the palette has at most 40 distinct colours; every sprite keeps a 1 px transparent margin on all four sides of every frame.

- [ ] **Step 1: Write the failing tests:**
  - `test_art_assets.gd` as above (it loops over the source folder, so it covers every later sprite; it fails now because the palette and player sprite do not exist).
  - `test_player_art.gd`: `test_the_player_has_a_body_view_with_art_and_the_idle_animation`, `test_it_plays_move_when_moving_and_idle_when_still` (set velocity on the body and step `_physics_process`), `test_it_faces_where_it_moves_and_where_it_aims_while_casting`, `test_casting_plays_the_cast_animation_for_a_moment_then_returns` (emit `loadout.cast_fired`, advance time), `test_the_hit_flash_still_works_on_the_body` (`HitFlashComponent` target is the `Body`), `test_the_hurtbox_is_still_12_by_12`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Author the art** (the palette and the player grid), then run `godot --headless -s tools/art/art_builder.gd`, then `godot --headless --import`. Implement the player changes. Take a real-window screenshot of the player at idle, moving and casting and look at it (read the PNG). Redraw until it reads clearly.
- [ ] **Step 4: Run** both files, `-gselect=test_player`, `-gselect=test_main_map`. Expected: PASS (update any existing test that read the player's `Body.color`, deliberately).
- [ ] **Step 5: Commit** `feat: the palette and the player's sprite`.

### Task 5: The enemy sprites and the enemy

**Files:**
- Create: `art/sprites/enemy_standard.sprite`, `enemy_swarmer.sprite`, `enemy_chaser.sprite`, `enemy_tank.sprite`, `enemy_ranged.sprite`, `enemy_exploder.sprite`, `enemy_support.sprite`, and every built sheet, silhouette and `.tres` (with `.import` files)
- Modify: `scenes/enemies/base_enemy.tscn`, `scripts/entities/enemy.gd`, `resources/enemies/enemy_data.gd` (a new `element_id: StringName`), `scripts/systems/enemy_composer.gd`, `scripts/enemies/brain_keep_distance.gd`, `brain_explode.gd`, `brain_support.gd`
- Test: `tests/test_enemy_art.gd`, plus deliberate updates to the existing tests that read an enemy's `Body.color`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces:
  - Seven sources named `enemy_<archetype id>` on the grids in Global Constraints (each an original, comedic, readable character with big eyes and a dark outline, using ramp slots `1` to `5` so one grid gives all five elements, with a Tank clearly bigger and slower-looking, a Swarmer small and fast-looking, a Ranged enemy that holds something, an Exploder with a fuse, a Support with a healing mark). Animations: `move` (2 frames, 6 fps, loop), `death` (2 frames, 12 fps, once), and one state animation: Ranged `attack` (2 frames, 12 fps, once), Exploder `fuse` (2 frames, 10 fps, loop), Support `pulse` (2 frames, 12 fps, once). Frame numbers follow that order.
  - `EnemyData.element_id: StringName`, set by `EnemyComposer` from `element.id` (empty for hand-made data).
  - `Enemy`: its `Body` is a `BodyView`. In `_apply_data` it sets `fallback_color = data.color`, `set_look(&"enemy_" + data.archetype_id, data.element_id)` when `archetype_id` is not empty, calls `counter_scale(scale)` (so the sprite stays 1:1 while the node's scale keeps sizing the hit shapes), and plays `move`. It faces its velocity's x. An elite shows `set_outline(_elite.outline_color, true)` (the silhouette) when there is art, and the old `ColorRect` outline when there is not. `show_state(state: StringName, seconds: float = 0.0)` plays a state animation and returns to `move` after `seconds` (when `seconds > 0`, interruptible and never leaving a stale state: a new state or the death replaces it). On death, if the set has a `death` animation, the enemy plays it and is freed when it ends (still exactly one `died` signal, hurtbox and hitbox disabled at once); without one it keeps the old shrink tween. The Ranged brain calls `show_state(&"attack", 0.3)` when it fires, the Exploder brain `show_state(&"fuse")` when it starts its fuse (its existing tint and blast are unchanged), the Support brain `show_state(&"pulse", 0.25)` on each heal step that heals anyone.

- [ ] **Step 1: Write the failing tests** (`tests/test_enemy_art.gd`, enemies from the real composer and `base_enemy.tscn`, set up like `test_enemy_brains.gd`):
  - `test_every_archetype_and_element_resolves_to_art` (7 archetypes by 5 elements: each composed enemy's body `has_art()`), `test_a_hand_made_enemy_without_an_archetype_shows_the_fallback_square` (a fixture from `tests/fixtures/enemies/`: `has_art()` false, the square has the data's colour, nothing crashes).
  - `test_the_element_changes_the_variant_not_the_stats` (a Thunder Tank and a Land Tank share health and speed, and their sheets differ).
  - `test_the_sprite_is_one_to_one_whatever_the_body_scale` (a Tank at scale 1.5 and an elite at 1.4 times that: the body's effective on-screen size equals the sprite's pixel size), `test_the_hit_shapes_are_unchanged` (hurtbox and contact box sizes equal the pre-sprite values times the node scale).
  - `test_an_enemy_faces_its_velocity` and `test_an_elite_shows_the_silhouette_outline_with_art_and_the_square_without`.
  - `test_a_ranged_enemy_plays_attack_when_it_fires_then_returns_to_move`, `test_an_exploder_plays_fuse_and_still_blasts_and_dies_with_no_rewards`, `test_a_support_plays_pulse_when_it_heals`, `test_a_new_state_replaces_the_old_one_and_a_timer_never_leaves_it_stuck`.
  - `test_death_plays_the_death_animation_then_frees_the_enemy_exactly_once` (one `died` signal, freed after the animation), `test_death_without_a_death_animation_still_shrinks_and_frees` (a set with no `death`), `test_killing_an_enemy_twice_in_the_animation_changes_nothing`.
  - The existing tests that read an enemy's `Body.color` (about five, in `test_enemy.gd`, `test_enemy_composer.gd`, `test_enemy_spawner.gd` and `test_boss.gd`) are changed to read `fallback_color` or to check the look, deliberately.
- [ ] **Step 2: Run** `-gselect=test_enemy_art` and `-gselect=test_art_assets`. Expected: FAIL.
- [ ] **Step 3: Author the seven sources**, run the tool and `--import`, implement the code changes. Take a real-window contact sheet (all seven archetypes in all five elements in a grid, from a throwaway scratchpad script) and look at it: the element must be readable at a glance and each archetype distinct in silhouette. Redraw until they are.
- [ ] **Step 4: Run** `-gselect=test_enemy_art`, `-gselect=test_art_assets`, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the enemy sprites in every element`.

### Task 6: The boss sprite and the boss

**Files:**
- Create: `art/sprites/boss_ember_titan.sprite` and its built sheet, silhouette and `.tres` (with `.import` files)
- Modify: `scenes/enemies/boss.tscn`, `scripts/enemies/boss.gd`
- Test: `tests/test_boss_art.gd`, plus the existing boss tests' `Body.color` reads, deliberately

**Interfaces:**
- Consumes: Tasks 1 to 5.
- Produces: `boss_ember_titan.sprite`: a 32×32 fiery giant (original, using fixed palette letters from the Fire family, so one `base` variant), with animations `idle` (2 frames, 4 fps, loop), `telegraph` (2 frames, 8 fps, loop), `attack` (2 frames, 10 fps, once) and `vulnerable` (2 frames, 6 fps, loop). `Boss`: its `Body` is a `BodyView` with `set_look(&"boss_" + data.id)` (so `ember_titan` finds `boss_ember_titan`), `counter_scale(scale)`, `fallback_color = data.color`, and it plays `idle` while idle or recovering, `telegraph` during a warning (replacing the old lightened tint), `attack` during a charge or burst, and `vulnerable` while the damage window is open (replacing the old lightened tint). A boss without art keeps today's tints on the fallback square.

- [ ] **Step 1: Write the failing tests** (`tests/test_boss_art.gd`, a boss from `boss.tscn` with `ember_titan.tres`, as `test_boss.gd` sets up): `test_the_boss_has_art_and_idles`, `test_a_warning_plays_telegraph_and_returns_to_idle`, `test_a_charge_or_burst_plays_attack`, `test_the_vulnerability_window_plays_vulnerable_then_ends`, `test_the_sprite_is_one_to_one_at_boss_scale_three_and_the_hurtbox_is_unchanged`, `test_a_boss_without_art_keeps_the_tinted_square` (a `BossData` with another id: the fallback square is lightened on a warning and during vulnerability as before), `test_the_hit_flash_still_works`.
- [ ] **Step 2: Run** `-gselect=test_boss_art` and `-gselect=test_art_assets`. Expected: FAIL.
- [ ] **Step 3: Author the boss grid**, run the tool and `--import`, implement the boss changes. Look at a real-window screenshot of each boss animation.
- [ ] **Step 4: Run** `-gselect=test_boss_art`, `-gselect=test_boss`, `-gselect=test_art_assets`, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the Ember Titan's sprite`.

### Task 7: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-13a-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project`, read `get_debug_output` for warnings (load with `ToolSearch select:`), then `stop_project`.
- [ ] **Step 2: Stress.** `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles`, four runs, median. Expected: at least 60 fps and within about 15% of about 192 fps. If it is lower, apply the shared-clock fallback (a measured, ledgered change) and re-run.
- [ ] **Step 3: Real-window check.** A throwaway scratchpad script (`save_path` empty, set up on the first frame, deleted afterwards): screenshot a run in progress with several archetypes and an elite and the boss on screen, the player moving and casting; confirm the hit flash and an Exploder fuse are visible; confirm replaceability by overwriting one built sheet with a differently coloured copy in a temp copy of the project (or in memory) and checking the game shows it, then restoring it. Look at the screenshots.
- [ ] **Step 4: Docs.** `sprint-development.md`: tick the pipeline, palette, player, enemy and boss sprite and animation items 13a covers and add a Built note. `README.md`: the art direction, the palette and how to replace art (overwrite the sheet PNG, or edit the `.sprite` source and run the tool). `technical-design.md`: the new directories. `CLAUDE.md`: an "Art pipeline (Sprint 13a)" section (formats, the tool command, naming, `BodyView`, the fallback, 1:1 rule, the committed-outputs test). `development-log.md`: the 13a entry with the stress numbers. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit.** Run the whole suite, then commit `docs: Sprint 13a complete`.
