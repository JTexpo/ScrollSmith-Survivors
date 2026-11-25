# Sprint 13b: The World's Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the world the 13a look: tiled floors, 9-slice walls, round posts, decoration sprites, a Lectern and five points of interest with sprites, and sprite pickups, all chosen by name from the map data and all replaceable.

**Architecture:** The map stays data. `MapObstacle.material`, `MapZone.floor_style` and `decoration_styles` (and `MapData` equivalents) name art that `WorldArt` resolves through the 13a `SpriteLibrary`; a missing name keeps today's flat colour. `GameMap`, `DrawChunk` and the existing chunked layers draw texture fills on the same shapes, so collision, pathfinding, spawning and the layout tests do not change. New sprite kinds use a `tile` (and optional `slice`) marker in the `.sprite` header.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, the 13a art pipeline (`art/`, `tools/art/art_builder.gd`).

**Spec:** `docs/sprints/sprint-13b-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`, never Perl). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script and after the art tool. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, zsh does not word-split unquoted variables, and `rm` takes the full literal path (delete only what you created).
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`.
- Gameplay does not change: collision, pathfinding, spawning, `test_first_map_layout`, `test_first_map_regions` and every number stay as they are. Sprites are drawn 1:1 and never decide collision. A missing art name falls back to today's flat colour and never crashes or hides anything.
- Tests never touch the real save (`save_path = ""`). Tests that instantiate `main.tscn` also set the pick screen's `pause_tree` to false.
- Replaceability: every sprite comes from a `.sprite` source and committed PNGs, the 13a asset test covers it, and `hand_drawn` still works.
- Hand-written `.tscn` files need `node_paths=PackedStringArray("prop")` for exported Node-typed properties set by NodePath.
- World decorations and scenes must not add a `Control` that stops touches (`tests/test_world_input.gd`); use `mouse_filter = 2` on any `ColorRect`.
- Real-window and MCP checks: run `mcp__godot__run_project` once per task that changes visuals, read `get_debug_output` for warnings, then `stop_project`. Throwaway real-window scripts live in the scratchpad, set `save_path` empty, and are deleted by exact path afterwards.

## Review Focus

- A missing material, style or sprite falls back to today's flat colour for floors, walls, circles, decorations, pickups and points of interest, never crashes, and never hides a solid wall or a pickup (Tasks 2 to 7).
- The art never changes collision: no obstacle shape, grid cell, physics body or layout test result differs from before, and a circle's drawing stays inside about 4 px of its collision radius (Tasks 4 and 8).
- Tiles and 9-slices show no seam or visible edge at the tile boundary, a 16 px wall looks like one piece, and walls end cleanly at their ends (Tasks 3, 4 and 8, by test and screenshot).
- The art does not hide gameplay: pickups, enemies and spell effects stay readable on every floor style, and decorations never sit on a wall, the player start or a placement (Tasks 5 and 8).
- Frame rate stays within the 13a ruling: the 300-enemy `--obstacles --drops` stress run is measured before and after, and the chunked layers still skip off-screen chunks (Tasks 3, 4, 5 and 8).

---

## File Structure

- Pipeline: `scripts/art/sprite_source.gd` (`tile`, `slice`), `scripts/art/art_builder.gd` (no silhouette for a tile, `slice` and `tile` in the set text), `resources/art/sprite_set_data.gd` (`tile`, `slice`), `art/palette.txt` (a world colour section), `tests/test_art_assets.gd`.
- Data: `resources/maps/{map_obstacle,map_zone,map_data,map_maze}.gd`, `resources/maps/first_map.tres`.
- Drawing: new `scripts/world/world_art.gd` (name to set lookup, static), new `scripts/world/floor_patch.gd` (a Node2D that tiles a floor texture over a rect), `scripts/world/draw_chunk.gd` (art for obstacles and decorations), `scripts/world/game_map.gd`, `scripts/world/map_decor.gd`, `scripts/world/obstacle_layer.gd` and `map_decor_layer.gd` (unchanged API).
- Scenes: `scenes/interactables/lectern.tscn`, `scenes/interactables/point_of_interest.tscn` (a `Body` BodyView), `scenes/scrolls/scroll_pickup.tscn`, `scenes/progression/{xp_gem,gold_coin}.tscn`; scripts `lectern.gd`, `point_of_interest.gd`, `scroll_pickup.gd`, `value_gem.gd`; `scripts/entities/body_view.gd` (`set_sprite_material`).
- Art sources: `art/sprites/tile_*.sprite`, `wall_*.sprite`, `post_*.sprite`, `decor_*.sprite`, `lectern.sprite`, `poi_*.sprite`, `scroll_*.sprite`, `pickup_*.sprite`.
- Tests: `tests/test_art_sources.gd`, `test_art_builder.gd`, `test_art_assets.gd`, `test_world_art.gd` (new), `test_game_map.gd`, `test_map_decor.gd`, `test_map_maze.gd`, `test_lectern.gd`, point of interest and pickup tests.

---

### Task 1: The `tile` marker, `slice`, and a bigger palette

**Files:**
- Modify: `scripts/art/sprite_source.gd`, `scripts/art/art_builder.gd`, `resources/art/sprite_set_data.gd`, `art/palette.txt`, `tests/test_art_sources.gd`, `tests/test_art_builder.gd`, `tests/test_art_assets.gd`

**Interfaces:**
- Produces: `SpriteSource.tile: bool` (set by a `tile` line) and `SpriteSource.slice: Vector4i` (set by `slice <left> <top> <right> <bottom>`, zero when absent, meaning the margins in pixels of a 9-slice). `SpriteSetData.tile: bool` and `SpriteSetData.slice: Vector4i`. A tile source: no `.` letter allowed (full bleed), exempt from the 1 px margin rule, gets no silhouette, and is built once as `base` when it uses no ramp slot. `ArtBuilder.set_text` writes `tile` and `slice` into the `.tres` only when set. `ArtBuilder.build_all` writes no silhouette for a tile.
- Produces: palette limit 64 (was 40), with a "world" section of at most 24 new colours (greens for grass and hedge, path and stone greys and browns, brick reds, marble whites, wood browns, flower pinks and yellows), each with an unused letter.

- [ ] **Step 1: Write the failing tests.** `test_art_sources`: `test_a_tile_line_marks_a_full_bleed_source` (a `tile` source with a `.` pixel reports an error mentioning transparent; one without parses with `tile == true`), `test_a_slice_line_reads_four_margins_and_rejects_bad_ones` (`slice 4 4 4 4` on a 16x16 tile gives `Vector4i(4,4,4,4)`; margins that add up to the full width, negative or missing numbers, or `slice` without `tile` are errors). `test_art_builder`: `test_a_tile_gets_no_silhouette_and_its_set_records_tile_and_slice` (`build_all` of a tile source writes `x_base.png` and `x_base.tres` and no `x_silhouette.*`; the `.tres` text contains `tile = true` and `slice = Vector4i(...)`), `test_a_plain_set_text_has_no_tile_line`. `test_art_assets`: raise `MAX_COLORS` to 64; one helper `_variants_for(source, palette)` that lists `silhouette` only for non-tile sources, used by the existing exists, set-text, orphan and set-loads tests; `test_every_source_keeps_a_one_pixel_margin` skips tile sources and a new `test_every_tile_is_full_bleed_and_its_slice_fits` checks each tile source has no `.` and that `slice` left + right < width and top + bottom < height.
- [ ] **Step 2: Run** `-gselect=test_art_sources`, `test_art_builder`, `test_art_assets`. Expected: the new tests FAIL (`tile` and `slice` unknown).
- [ ] **Step 3: Implement** the `SpriteSource` lines and validation, the `SpriteSetData` exports, the `set_text` lines, the silhouette skip in `build_all` (and in `_build_hand_drawn` for a source that is both), and the world colour section in `art/palette.txt` (a comment header, one `color <letter> <hex>` line each; no letter may repeat an existing one; the 13a palette tests must still pass).
- [ ] **Step 4: Run** the three files and the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the tile marker, 9-slice margins and a world palette`.

### Task 2: Map data fields and the art lookup

**Files:**
- Create: `scripts/world/world_art.gd`, `tests/test_world_art.gd`
- Modify: `resources/maps/map_obstacle.gd`, `resources/maps/map_zone.gd`, `resources/maps/map_data.gd`, `resources/maps/map_maze.gd`, `tests/test_map_maze.gd`, `tests/test_map_obstacle.gd`

**Interfaces:**
- Produces: `MapObstacle.material: StringName` (empty means flat colour). `MapZone.floor_style: StringName` and `MapZone.decoration_styles: PackedStringArray`. `MapData.floor_style: StringName`, `MapData.border_style: StringName` and `MapData.decoration_styles: PackedStringArray`. `MapMaze.material: StringName`, stamped on every obstacle `MapMaze.shapes()` returns.
- Produces: `WorldArt` (RefCounted, static): `floor_set(style: StringName) -> SpriteSetData`, `wall_set(material: StringName) -> SpriteSetData`, `post_set(material: StringName) -> SpriteSetData`, `decor_set(style: StringName) -> SpriteSetData`. Each returns `SpriteLibrary.find(&"tile_<style>")`, `&"wall_<m>"`, `&"post_<m>"`, `&"decor_<style>"` (base variant), and null for an empty name or missing art.

- [ ] **Step 1: Write the failing tests.** `test_world_art`: `test_an_empty_or_unknown_name_gives_null_for_every_kind`, `test_a_name_finds_its_set_by_the_naming_rule` (point `SpriteLibrary.root` at a temp folder with a tile set, as `test_art_builder` does, and restore it in `after_each`). `test_map_obstacle`: `test_material_defaults_to_empty`. `test_map_maze`: `test_every_wall_carries_the_mazes_material` and `test_a_maze_without_a_material_gives_empty_materials`.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement** the exports and `WorldArt` (run `godot --headless --import` for the new `class_name`).
- [ ] **Step 4: Run** the three files and the whole suite. Expected: PASS (nothing draws differently yet).
- [ ] **Step 5: Commit** `feat: map data names its art, and the WorldArt lookup`.

### Task 3: Floors and the border

**Files:**
- Create: `scripts/world/floor_patch.gd`, `art/sprites/tile_grass.sprite`, `tile_path.sprite`, `tile_ruin.sprite`, `tile_hall.sprite`, `tile_border.sprite` (and their built files)
- Modify: `scripts/world/game_map.gd`, `resources/maps/first_map.tres`, `tests/test_game_map.gd`, `tests/test_world_art.gd`

**Interfaces:**
- Consumes: Task 1 (`tile`), Task 2 (`WorldArt.floor_set`, the style fields).
- Produces: `FloorPatch` (Node2D): `setup(rect: Rect2, set_data: SpriteSetData)` draws `set_data.sheet` tiled over `rect` with `draw_texture_rect(..., true)` and never catches input. `GameMap` keeps its `Border`, `Floor` and `Zone_*` `ColorRect`s (the fallback colours, and what the existing tests read) and adds one `FloorArt` Node2D after `Zones`, holding a `FloorPatch` for the border (`border_style`, over the border rect), the whole map (`floor_style`) and each zone (`floor_style`) that has art, in that order. Tiles are 16x16 full-bleed, low-contrast, mid-tone (grass, stone path, ruin flagstones, hall flagstones, a dark border brick).

- [ ] **Step 1: Write the failing tests.** `test_game_map`: `test_a_map_with_floor_styles_adds_floor_patches_in_order` (use a temp `SpriteLibrary.root` with a tiny tile set; expect `FloorArt` children for border, map and zone, in that order, with the same rectangles as the `ColorRect`s), `test_a_missing_style_adds_no_patch_and_keeps_the_colour`, `test_floor_patches_never_catch_touches` (no Control children, `FloorPatch` is a Node2D). `test_world_art`: `test_every_floor_style_in_first_map_has_art` (loads `first_map.tres`; `floor_style`, `border_style` and every zone's `floor_style` resolves through `WorldArt.floor_set`).
- [ ] **Step 2: Run** `-gselect=test_game_map`, `test_world_art`. Expected: FAIL.
- [ ] **Step 3: Author the five tile grids** (16x16, `tile`, fixed palette letters from the world section, edges that wrap: draw each row and column so the first and last continue into each other), run `godot --headless -s tools/art/art_builder.gd` and `--import`, implement `FloorPatch` and the `GameMap` change, and set the styles in `first_map.tres`: `floor_style = grass` and `border_style = border` on the map, `path` on both mazes' zones, `ruin` on the island, `hall` on the corridor, `grass` on the plaza. View a real-window screenshot (and one 3x3 tiling sheet of each tile, to look for seams).
- [ ] **Step 4: Run** the two test files, `test_art_assets`, `test_first_map_regions`, the whole suite, then one MCP run. Expected: PASS and no warnings.
- [ ] **Step 5: Commit** `feat: tiled floors and a border for the first map`.

### Task 4: Walls and posts

**Files:**
- Create: `art/sprites/wall_hedge.sprite`, `wall_brick.sprite`, `wall_stone.sprite`, `post_marble.sprite`, `post_tree.sprite` (and built files)
- Modify: `scripts/world/draw_chunk.gd`, `resources/maps/first_map.tres` (the two mazes' `material`, the authored obstacles' `material`), `tests/test_world_art.gd`, `tests/test_game_map.gd`

**Interfaces:**
- Consumes: `MapObstacle.material`, `WorldArt.wall_set`, `WorldArt.post_set`, `SpriteSetData.slice`.
- Produces: `DrawChunk._draw` draws a RECT obstacle with a `wall_set` as a 9-slice of the set's sheet: corners 1:1, the four edges tiled along their length, the centre tiled; with `slice` margins from the set. A CIRCLE obstacle with a `post_set` draws that sprite (one size, about 44 px wide, drawn centred on the shape at 1:1). With no art it draws today's grey fill and outline. Draw order is unchanged. The sprites are 16 px tall walls (corner and cap margins of 4), and the post sprites are about 44x44.
- Materials in `first_map.tres`: both mazes `hedge`; the island's four wall pieces `brick`; the corridor's two walls `stone`; the circles `marble` (the first two groves) and `tree` (the other groves), chosen by eye.

- [ ] **Step 1: Write the failing tests.** `test_world_art`: `test_every_obstacle_and_maze_material_in_first_map_has_art` (each obstacle's `material` and each maze's `material` resolves, rectangles through `wall_set`, circles through `post_set`), `test_a_nine_slice_wall_set_has_slice_margins_that_fit_a_16_pixel_wall` (each `wall_*` set has `tile`, a `slice` whose left + right and top + bottom are each less than 16). `test_game_map`: `test_obstacle_art_never_changes_the_shapes_or_bodies` (build a map with a temp art root and materials, then check `ObstacleLayer.item_count()`, the number and shapes of `ObstacleBodies`, and `ObstacleMap.is_blocked` equal a build without art), `test_draw_chunks_with_art_still_skip_off_screen_chunks` (`chunk_count()` stays as before).
- [ ] **Step 2: Run** the two files. Expected: FAIL.
- [ ] **Step 3: Author the five sprites** (a hedge, a brick wall and a flagstone wall as 16x16 `tile` + `slice 4 4 4 4`, tiling along their length; a marble column and a tree as `post_*` sprites about 44x44 with a 1:1 round base the size of a collision circle of radius about 21), build, import, implement the `DrawChunk` drawing, and set the materials in `first_map.tres`. Look at screenshots of a maze, the island, the corridor and a grove with enemies near the walls.
- [ ] **Step 4: Run** the two files, `test_art_assets`, `test_first_map_layout`, `test_first_map_regions`, `test_obstacle_map`, the whole suite, then one MCP run and the stress run (`godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles`, four runs, median, compared with about 139 fps). Expected: PASS, no warnings, no more than about 15% below that median (if lower, merge each material's walls per chunk into one baked texture and re-run; ledger it).
- [ ] **Step 5: Commit** `feat: hedge, brick and stone walls, and column and tree posts`.

### Task 5: Decorations

**Files:**
- Create: `art/sprites/decor_grass.sprite`, `decor_flowers.sprite`, `decor_mushrooms.sprite`, `decor_pebbles.sprite`, `decor_cracks.sprite`, `decor_moss.sprite` (and built files)
- Modify: `scripts/world/map_decor.gd`, `scripts/world/draw_chunk.gd`, `resources/maps/first_map.tres`, `tests/test_map_decor.gd`, `tests/test_game_map.gd`

**Interfaces:**
- Consumes: `MapData.decoration_styles`, `MapZone.decoration_styles`, `WorldArt.decor_set`.
- Produces: `MapDecor` items become `{"rect": Rect2, "color": Color, "style": StringName, "frame": int}`; `style` is empty when the map or zone has no `decoration_styles`, and otherwise one name chosen from the list by the seeded generator. `frame` is a seeded non-negative integer that `DrawChunk` reduces modulo the set's frame count at draw time, so `MapDecor` loads no art and stays deterministic. A zone with `decoration_styles` uses them instead of its colours. `DrawChunk` draws an item with art as the sprite frame (a sheet frame is a variant: a different flower), centred on the item's rect centre, 1:1; an item without art keeps its coloured rectangle. Decoration sprites are 8x8 or smaller with a 1 px margin (ordinary sprites, not tiles). The scatter rules (clear of the start, placements and every solid shape) are unchanged.
- Style lists in `first_map.tres`: the map and the plaza `grass, flowers, mushrooms, pebbles`; the mazes `moss, pebbles, grass`; the island `cracks, pebbles`; the corridor `cracks, pebbles`.

- [ ] **Step 1: Write the failing tests.** `test_map_decor`: `test_items_carry_a_style_from_the_list_and_a_frame`, `test_a_map_without_styles_gives_empty_styles_and_the_same_positions_as_before` (positions and colours equal the previous scatter for the same seed), `test_the_same_seed_gives_the_same_styles`, `test_art_decorations_still_keep_clear_of_walls_the_start_and_placements`. `test_game_map`: `test_decor_item_count_is_unchanged_by_styles`. `test_world_art`: `test_every_decoration_style_in_first_map_has_art`.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Author the six decoration sprites** (2 to 4 frames each, 8x8 or smaller, low contrast so pickups and enemies still read), build, import, implement, set the styles in `first_map.tres`, and look at screenshots of each region with a scroll pickup and enemies on the floor.
- [ ] **Step 4: Run** the three files, `test_art_assets`, `test_first_map_layout`, the whole suite, one MCP run, and the stress run. Expected: PASS, no warnings, within the Task 4 rule.
- [ ] **Step 5: Commit** `feat: decoration sprites for every region`.

### Task 5b: Brighter, simpler floors and decorations, and soft zone edges (user feedback)

**Files:**
- Modify: `scripts/world/floor_patch.gd`, `scripts/world/game_map.gd`, `art/palette.txt` (the floor colours only), `art/sprites/tile_*.sprite`, `art/sprites/decor_*.sprite`, `resources/maps/first_map.tres` (fewer decorations), `tests/test_game_map.gd`, `tests/test_floor_patch.gd` (new)

**Interfaces:**
- Produces: `FloorPatch.setup(covered: Rect2, set_data: SpriteSetData, soft: bool = false, seed_value: int = 0)`. When `soft`, the interior (`interior_rect()`, the area shrunk by 16 px) is one tiled rectangle and the outer 16 px is drawn in 8 px cells of the same tile (same phase), with how deep the gap reaches in (up to 32 px, `BAND_CELLS` 4) following smooth noise along the edge plus jitter, seeded by `seed_value`; `omitted_cells() -> Array[Rect2]` lists them. A hard patch (the default, used for the border and the map) draws one tiled rectangle and omits nothing. `GameMap` draws each zone's patch soft, seeded from the zone's area, and sets the zone's flat tint `ColorRect` to `visible = false` when the zone has floor art (it stays, with its colour, otherwise).
- Art: the floor colours become bright and saturated (vivid grass greens, warm cream cobbles, lavender ruin stone, sandy hall flags); each tile uses few large shapes (a handful of simple tufts, four big flagstones, a tidy square grid); decorations are simpler and bolder with a dark outline where it helps; the first map's decoration counts drop to about half.

- [ ] **Step 1: Write the failing tests.** `test_floor_patch`: `test_a_hard_patch_omits_nothing_and_draws_the_whole_area`, `test_a_soft_patch_leaves_gaps_only_in_the_outer_16_pixels`, `test_the_outer_row_has_more_gaps_than_the_second_row`, `test_the_same_seed_gives_the_same_gaps_and_another_seed_differs`, `test_the_interior_is_the_area_shrunk_by_16`, `test_a_tiny_area_never_fails`. `test_game_map`: `test_a_zone_with_floor_art_hides_its_flat_tint_and_one_without_keeps_it`, `test_zone_patches_are_soft_and_the_base_patches_are_hard`.
- [ ] **Step 2: Run** `-gselect=test_floor_patch` and `test_game_map`. Expected: FAIL.
- [ ] **Step 3: Implement** the patch and `GameMap` change; redraw the five tiles and six decoration sprites in the new style, brighten the floor colours in `art/palette.txt`, lower the decoration counts in `first_map.tres`, build, import. Look at screenshots of every region (including each zone boundary and a boundary with enemies and pickups nearby).
- [ ] **Step 4: Run** the touched tests, `test_art_assets`, `test_first_map_layout`, `test_first_map_regions`, the whole suite, one MCP run and the stress run. Expected: PASS, no warnings, within the Task 4 rule.
- [ ] **Step 5: Commit** `feat: brighter cartoon floors, simpler decorations and soft zone edges`.

### Task 6: The Lectern and the points of interest

**Files:**
- Create: `art/sprites/lectern.sprite`, `poi_health_shrine.sprite`, `poi_mana_shrine.sprite`, `poi_chest.sprite`, `poi_rare_spot.sprite`, `poi_merchant.sprite` (and built files)
- Modify: `scenes/interactables/lectern.tscn`, `scenes/interactables/point_of_interest.tscn`, `scripts/interactables/lectern.gd`, `scripts/points_of_interest/point_of_interest.gd`, `resources/points_of_interest/*.tres` (a `sprite_name`), `resources/points_of_interest/point_of_interest_data.gd`, `tests/test_lectern.gd`, the point of interest tests

**Interfaces:**
- Consumes: `BodyView` (13a).
- Produces: the Lectern scene's three `ColorRect`s are replaced by one `Body` (`BodyView`, fallback colour the old purple, `set_look(&"lectern")` in `_ready`, plays `idle`, a two-frame glow at 3 fps). `PointOfInterestData.sprite_name: StringName`. `point_of_interest.tscn` gains a `Body` BodyView; `PointOfInterest._ready` calls `set_look(data.sprite_name)` and plays `ready`; while refreshing (`cooldown_left > 0`, or a merchant restocking) it plays `used` (the dimmed look) and returns to `ready` when ready; `_draw` keeps only the ring and its progress arc when the body has art, and the old rectangles when it has none. The prompt, ring, timer, `used` signal and every rule are unchanged. Each point's sprite is 24x24 or smaller with two animations, `ready` (2 frames, a glint) and `used` (1 frame, dimmed).

- [ ] **Step 1: Write the failing tests.** `test_lectern`: `test_the_lectern_has_art_and_a_glow`, `test_the_lectern_without_art_shows_the_fallback_square`. Point of interest tests: `test_each_shipped_point_has_a_sprite_with_ready_and_used`, `test_a_point_shows_used_while_refreshing_and_ready_after`, `test_a_merchant_always_shows_ready` (a merchant is never refreshing under the existing rule, so it never plays `used`, even while it restocks), `test_a_point_without_art_still_draws_its_fallback_shape_and_ring`, `test_the_prompt_and_the_used_signal_are_unchanged`.
- [ ] **Step 2: Run** the new tests. Expected: FAIL.
- [ ] **Step 3: Author the six sprites and make the changes**, set `sprite_name` on the five data resources, build, import, and look at screenshots of the Lectern and every point, ready and refreshing.
- [ ] **Step 4: Run** the touched test files, `test_first_map_points_of_interest`, `test_world_input`, the whole suite, and one MCP run. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: sprites for the Lectern and the points of interest`.

### Task 7: Pickups

**Files:**
- Create: `art/sprites/scroll_base.sprite`, `scroll_area.sprite`, `scroll_buff.sprite`, `pickup_xp.sprite`, `pickup_gold.sprite` (and built files)
- Modify: `scripts/scrolls/scroll_pickup.gd`, `scripts/progression/value_gem.gd`, `scripts/entities/body_view.gd`, `scenes/scrolls/scroll_pickup.tscn`, `scenes/progression/xp_gem.tscn`, `scenes/progression/gold_coin.tscn`, `tests/test_scroll_pickup.gd`, `tests/test_value_gem.gd`, `tests/test_body_view.gd`

**Interfaces:**
- Produces: `BodyView.set_sprite_material(material: Material)` sets the sprite's (and outline's) `material`. Each pickup scene gains a `Body` (`BodyView`). `ScrollPickup.setup` shows the sprite `scroll_<category>` (base, area, buff) tinted by the scroll's colour (`set_tint`), playing `idle`; the Polygon2D `Shape` stays as the fallback and is hidden when there is art, keeping its polygon and colour so existing behaviour and tests stay true. A Rare scroll plays `sparkle` (a second animation). `ValueGem` shows `pickup_xp` or `pickup_gold` with a looping 3-frame sparkle. The bob shader moves to the `Body` sprite through `set_sprite_material`. Caps, merging, collection and values are unchanged. Pickup sprites are 12x12 or smaller.

- [ ] **Step 1: Write the failing tests.** `test_body_view`: `test_set_sprite_material_applies_to_the_sprite`. `test_scroll_pickup`: `test_each_category_shows_its_sprite_tinted_by_the_scroll_colour`, `test_a_rare_scroll_sparkles`, `test_a_pickup_without_art_keeps_its_polygon_shape_visible`, `test_the_bob_shader_is_on_the_sprite_when_there_is_art`. `test_value_gem`: `test_xp_and_gold_show_different_sprites`, `test_a_gem_without_art_keeps_its_polygon`.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Author the five sprites and make the changes**, build, import, and look at screenshots of each pickup on each floor style (a scroll of every category and rarity, an XP gem and a Gold coin, on grass, path and ruin) to check they stay readable.
- [ ] **Step 4: Run** the three files, `test_scroll_dropper`, `test_value_dropper`, `test_pickup_collector`, `test_world_input`, the whole suite, and one MCP run. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: sprites for scrolls, XP gems and Gold coins`.

### Task 8: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-13b-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project`, read `get_debug_output`, then `stop_project`.
- [ ] **Step 2: Stress.** Four runs of the Task 4 command, median against the 13a number (about 139 fps) and against `main` measured in the same session in a throwaway worktree. Record both in the log.
- [ ] **Step 3: Real-window check.** A throwaway script (`save_path` empty): a run in progress in each region (a maze, the island, the corridor, the plaza, a grove) with enemies, a scroll of each category, an XP gem and a Gold coin on the floor, the Lectern and every point of interest in view, a spell cast, and a point refreshing. Confirm the walls look solid and the floors are not, nothing is hidden, and the border reads as the world's edge. Prove replaceability in a throwaway copy of the project: overwrite one floor or wall PNG with a recoloured copy and confirm the game shows it, then delete the copy by its exact path.
- [ ] **Step 4: Docs.** `sprint-development.md`: tick the environmental tiles, scroll sprites, Lectern sprites and pickup items 13b covers, and add a Built note. `README.md`: the world's look and how to replace a tile (the `hand_drawn` rule applies). `technical-design.md`: the new files. `CLAUDE.md`: a "World art (Sprint 13b)" section (the `tile` and `slice` markers, the naming rule `tile_`, `wall_`, `post_`, `decor_`, the data fields, `WorldArt`, `FloorPatch`, the draw rules and fallbacks, the 4 px circle rule, the palette limit of 64, the stress numbers). `development-log.md`: the 13b entry. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit** `docs: Sprint 13b complete`.
