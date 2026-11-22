# Sprint 12a: The World (Map as Data) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 960×540 test arena in the main scene with a 1920×1080 map built from a `MapData` resource, with boundaries, data-placed Lecterns, decorations, per-map spawn settings and an F7 debug overlay.

**Architecture:** `MapData` (Resource) describes a map and `MapPlacement` (Resource) puts a scene at a position. A thin `GameMap` scene reads a `MapData` and builds the floor, boundary walls, decorations and placements. `Main` reads the map once and hands its bounds to the spawner and camera and its start to the player. Nothing branches on a map id.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `sprint-12a-design.md` (repo root). Read it first. Sprint 12b (obstacles) and 12c (points of interest) are NOT built here.

## Global Constraints

- Run everything with the venv active: `source venv/bin/activate`. Tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit </dev/null` (add `-gselect=<file without .gd>`). After adding a `class_name` script run `godot --headless --import` once. Commit the generated `.uid` files with their scripts.
- First map is exactly **1920×1080**, player start (960, 540). Three Lecterns, at least **700 px** apart pairwise.
- Balance does not change: enemy count, spawn rate, difficulty and the spawn config are exactly Sprint 11's.
- No code branches on a map id or name. No arena-size number is left in `Main` or `main.tscn`. The `Rect2(0, 0, 960, 540)` defaults in `EnemySpawner`, `Enemy` and `Boss`, the tests' own bounds, and the stress scene on `test_arena.tscn` are left alone.
- World nodes (floor, border, decorations, overlay) must not stop touches: `mouse_filter = 2` on every Control. Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` on the `[node]` line for any Node-typed export set by NodePath.
- Tests that instantiate `main.tscn` set `save_path = ""` (or a folder in `res://.godot/save_tests/`) and the pick screen's `pause_tree = false` before `add_child`, and never touch the real save.
- Conventions: PascalCase classes, snake_case members, UPPER_SNAKE constants, typed GDScript, `##` doc comments, gameplay values in Resources or `@export`s. Match surrounding code's comment density.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`, never `;`, so a failing test stops the commit.

## Review Focus

- A map whose size, player start or a placement is invalid is reported by `MapData.problems()`, and a `GameMap` with no `map_data` builds nothing and does not crash (Tasks 1, 3).
- Decoration scatter on an impossible map (tiny, huge count) ends and returns fewer items instead of hanging, and never puts decor on a placement or the player start (Task 2).
- The player at any map corner still gets a valid spawn-ring point outside the view and inside the bounds, and the camera limits match the map (Task 5).
- The walls fully enclose the map including the corners, and a body pushed at one is stopped (Task 3).
- A map with a null `spawn_config` keeps the scene's config, and one with a config replaces it (Task 5).

---

### Task 1: MapPlacement, MapData and the first map

**Files:**
- Create: `resources/maps/map_placement.gd`, `resources/maps/map_data.gd`, `resources/maps/first_map.tres`
- Test: `tests/test_map_data.gd`

**Interfaces:**
- Produces:
  - `MapPlacement` (`Resource`): `@export var scene: PackedScene`, `@export var position: Vector2`.
  - `MapData` (`Resource`): `id: StringName`, `display_name: String`, `size: Vector2 = Vector2(1920, 1080)`, `floor_color: Color`, `border_color: Color`, `player_start: Vector2`, `spawn_config: SpawnConfig` (null keeps the scene's), `placements: Array[MapPlacement]`, `decoration_count: int`, `decoration_seed: int`, `decoration_colors: PackedColorArray`, `decoration_size: Vector2` (min and max side in px). `bounds() -> Rect2` is `Rect2(Vector2.ZERO, size)`. `problems() -> PackedStringArray` is empty when valid, otherwise one line per fault (empty id, non-positive size, player start outside, a placement with no scene, a placement outside).

- [ ] **Step 1: Write the failing tests** in `tests/test_map_data.gd` (helper `_map()` returns a valid 400×300 map with id `&"test"` and start (200, 150); `_placement(scene, position)` builds a `MapPlacement`):
  - `test_bounds_start_at_the_origin` asserts `_map().bounds() == Rect2(0, 0, 400, 300)`.
  - `test_a_valid_map_has_no_problems` asserts `problems().is_empty()`.
  - `test_problems_name_an_empty_id`, `test_problems_name_a_non_positive_size` (size `Vector2(0, 300)`), `test_problems_name_a_start_outside_the_map` (start `Vector2(500, 150)`) each assert exactly one problem.
  - `test_problems_name_a_placement_without_a_scene_or_outside_the_map` adds two bad placements (null scene; lectern scene at `Vector2(-5, 10)`) and asserts two problems.
  - `test_first_map_is_1920_by_1080_and_valid` loads `res://resources/maps/first_map.tres` as `MapData`: size `Vector2(1920, 1080)`, `player_start == Vector2(960, 540)`, `problems().is_empty()`, `spawn_config != null`.
  - `test_first_map_places_three_lecterns_at_least_700_apart` collects placements whose `scene.resource_path == "res://scenes/interactables/lectern.tscn"`, asserts three, and every pair is `>= 700.0` apart.
- [ ] **Step 2: Run** `-gselect=test_map_data`. Expected: FAIL (classes not defined).
- [ ] **Step 3: Implement** both scripts as specified. Run `godot --headless --import`. Hand-write `first_map.tres` (typed array syntax as in `main.tscn`'s `debug_scrolls`): id `&"first_map"`, display name "The Lectern Grounds", floor `Color(0.16, 0.2, 0.17, 1)`, border `Color(0.08, 0.1, 0.09, 1)`, start (960, 540), spawn config `res://resources/spawning/default_spawn_config.tres`, Lectern placements at (300, 260), (1600, 300), (960, 900), `decoration_count` 160, `decoration_seed` 12, three muted green colours (for example `Color(0.2, 0.26, 0.2)`, `Color(0.14, 0.18, 0.15)`, `Color(0.24, 0.3, 0.22)`), `decoration_size` `Vector2(2, 5)`.
- [ ] **Step 4: Run** `-gselect=test_map_data`. Expected: all PASS.
- [ ] **Step 5: Commit** `feat: MapData, MapPlacement and the first map`.

### Task 2: Decoration scatter and layer

**Files:**
- Create: `scripts/world/map_decor.gd`, `scripts/world/map_decor_layer.gd`
- Test: `tests/test_map_decor.gd`

**Interfaces:**
- Consumes: `MapData` (Task 1).
- Produces:
  - `MapDecor` (`RefCounted`, static): `const CLEAR_RADIUS := 40.0`; `static func scatter(map: MapData) -> Array[Dictionary]`, each item `{"rect": Rect2, "color": Color}`. Deterministic for a seed. Every rect lies inside `map.bounds()`. Its centre is at least `CLEAR_RADIUS` from `player_start` and every placement position. Colours come from `decoration_colors`, side lengths from `decoration_size`. At most `decoration_count` items, from a bounded number of attempts (10 per wanted item). Returns `[]` for a count of 0 or no colours.
  - `MapDecorLayer` (`Node2D`): `set_decor(items: Array[Dictionary]) -> void`, `item_count() -> int`; draws every rect in one `_draw` (`queue_redraw` on set).

- [ ] **Step 1: Write the failing tests** (`test_map_decor.gd`, a 400×300 map, start (200, 150), one lectern placement at (50, 50), count 50, seed 3, two colours, size `Vector2(2, 4)`):
  - `test_the_same_seed_gives_the_same_scatter` and `test_a_different_seed_gives_a_different_scatter`.
  - `test_it_returns_items_but_never_more_than_the_count`: `size() > 0` and `<= 50`.
  - `test_every_rect_is_inside_the_map`, `test_nothing_sits_near_the_player_start_or_a_placement` (centre distance `>= MapDecor.CLEAR_RADIUS`), `test_colors_come_from_the_map`.
  - `test_zero_count_or_no_colors_gives_nothing`.
  - `test_an_impossible_map_ends_with_fewer_items` (size `Vector2(30, 30)`, count 1000: it returns, and `size() < 1000`).
  - `test_layer_holds_the_items_it_is_given` (`set_decor` of 3 items, `item_count() == 3`, added with `add_child_autofree`).
- [ ] **Step 2: Run** `-gselect=test_map_decor`. Expected: FAIL.
- [ ] **Step 3: Implement** as specified, using a local `RandomNumberGenerator` seeded with `decoration_seed`. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_map_decor`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: seeded decoration scatter and its one-draw layer`.

### Task 3: The GameMap scene

**Files:**
- Create: `scripts/world/game_map.gd`, `scenes/world/game_map.tscn`
- Modify: `tests/test_world_input.gd` (add `res://scenes/world/game_map.tscn` to `SCENES`)
- Test: `tests/test_game_map.gd`

**Interfaces:**
- Consumes: `MapData`, `MapPlacement` (Task 1), `MapDecor`, `MapDecorLayer` (Task 2), `PhysicsLayers.WORLD`.
- Produces: `GameMap` (`Node2D`): `const WALL_THICKNESS := 20.0`; `@export var map_data: MapData` (the scene defaults it to `first_map.tres`); `bounds() -> Rect2` (`Rect2()` when no data); `player_start() -> Vector2` (`Vector2.ZERO` when no data). In `_ready` it builds children named `Border` (a `ColorRect` in `border_color`, 32 px larger than the bounds on every side), `Floor` (a `ColorRect` over exactly the bounds in `floor_color`), `Decor` (a `MapDecorLayer` filled from `MapDecor.scatter`), `Walls` (four `StaticBody2D` on layer `PhysicsLayers.WORLD`, mask 0, `RectangleShape2D`s of thickness `WALL_THICKNESS` just outside each edge, long enough to overlap at the corners) and `Placements` (a `Node2D` holding each placement's scene instance at its position). With null `map_data` it builds nothing.

- [ ] **Step 1: Write the failing tests** (`test_game_map.gd`, a small 400×300 `MapData` with one lectern placement at (100, 100), count 20 decorations; helper `_map_node(data)` sets `map_data` before `add_child_autofree`, from `load("res://scenes/world/game_map.tscn")`):
  - `test_floor_covers_exactly_the_bounds`: `Floor` rect equals the bounds, `mouse_filter == Control.MOUSE_FILTER_IGNORE`, `Border` too, and both colours come from the data.
  - `test_four_walls_on_the_world_layer`: `Walls` has 4 `StaticBody2D`, each `collision_layer == PhysicsLayers.WORLD` and `collision_mask == 0`.
  - `test_walls_enclose_the_map_including_the_corners`: for each of the four points one pixel outside each corner (for example `(-1, -1)`) and the midpoint just outside each edge, some wall's rect (body position plus shape size) contains it.
  - `test_a_body_pushed_at_a_wall_is_stopped` (async): a `CharacterBody2D` with a 4 px circle shape, `collision_mask = PhysicsLayers.WORLD`, placed at (6, 150); `await wait_physics_frames(3)`; `move_and_collide(Vector2(-50, 0))`; assert its `position.x >= 3.9`.
  - `test_each_placement_is_instanced_at_its_position`: `Placements` has one child at (100, 100) in group `lecterns`.
  - `test_decorations_are_scattered_from_the_data`: `Decor.item_count() == MapDecor.scatter(data).size()`.
  - `test_bounds_and_player_start_come_from_the_data`.
  - `test_without_map_data_it_builds_nothing`: node with `map_data = null` has no `Floor`, `bounds() == Rect2()`, no error.
- [ ] **Step 2: Run** `-gselect=test_game_map`. Expected: FAIL.
- [ ] **Step 3: Implement** `game_map.gd` and write `game_map.tscn` (root `GameMap` with the script and `map_data = first_map.tres`). Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_game_map`, then `-gselect=test_world_input`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: GameMap builds floor, walls, decor and placements from MapData`.

### Task 4: The debug overlay and F7

**Files:**
- Create: `scripts/world/map_debug_overlay.gd`
- Modify: `scripts/world/game_map.gd`, `project.godot` (input action `debug_toggle_map`, key F7: `physical_keycode` 4194338, written like `debug_give_xp`), `tests/test_input_map.gd`
- Test: `tests/test_map_debug_overlay.gd`

**Interfaces:**
- Consumes: `GameMap` (Task 3).
- Produces: `MapDebugOverlay` (`Node2D`, hidden by default): `setup(data: MapData) -> void`, `marker_count() -> int` (the player start plus one per placement), draws the bounds outline, a cross at the start and a labelled marker per placement. `GameMap` adds it as a child named `Debug` and gets `toggle_debug() -> void` that flips its `visible`.

- [ ] **Step 1: Write the failing tests.**
  - `test_map_debug_overlay.gd`: `test_it_is_hidden_until_toggled` (build a `GameMap` from a small map, `Debug.visible == false`, `toggle_debug()` makes it true, again false); `test_it_has_a_marker_per_placement_and_one_for_the_start` (one placement gives `marker_count() == 2`).
  - `tests/test_input_map.gd`: add `&"debug_toggle_map"` to the required action list and `test_debug_toggle_map_is_f7` asserting a key event whose `physical_keycode == KEY_F7`.
- [ ] **Step 2: Run** both. Expected: FAIL.
- [ ] **Step 3: Implement** the overlay (draw with `ThemeDB.fallback_font`), the `GameMap` wiring and the input action.
- [ ] **Step 4: Run** `-gselect=test_map_debug_overlay`, `-gselect=test_input_map`. Expected: PASS (the test fails if `debug_toggle_map` shares a key with another action).
- [ ] **Step 5: Commit** `feat: F7 map debug overlay`.

### Task 5: Main uses the map

**Files:**
- Modify: `scenes/main/main.tscn` (remove `TestArena`, the three Lectern nodes and the `Camera2D` limit overrides; instance `res://scenes/world/game_map.tscn` as `GameMap` first child; the Player position is overwritten by `Main`), `scripts/main/main.gd`
- Test: `tests/test_main_map.gd`

**Interfaces:**
- Consumes: `GameMap.bounds()`, `player_start()`, `toggle_debug()`, `MapData.spawn_config`, `debug_toggle_map` (Tasks 3 and 4).
- Produces: in `Main._ready`, before the rest of the wiring, an `_apply_map()` that sets `_spawner.arena_bounds = _map.bounds()`; `_spawner.config = map_data.spawn_config` when not null; `_player.global_position = _map.player_start()`; and the player camera's `limit_left/top/right/bottom` from the bounds (`@onready var _camera: Camera2D = $Player/Camera2D`). F7 (`debug_toggle_map` in `_unhandled_input`, marked DEBUG like its neighbours) calls `_map.toggle_debug()`.

- [ ] **Step 1: Write the failing tests** (`test_main_map.gd`, helper `_new_main()` like `test_main_progression.gd`'s: `save_path = ""`, pick screen `pause_tree = false`, then `add_child_autofree`):
  - `test_the_spawner_and_camera_use_the_map_bounds`: `spawner.arena_bounds == Rect2(0, 0, 1920, 1080)`; camera limits are `0, 0, 1920, 1080`.
  - `test_the_player_starts_at_the_map_start`: `(960, 540)`.
  - `test_the_three_lecterns_come_from_the_map`: group `lecterns` has 3 members, all descendants of `GameMap/Placements`, and opening one still reaches the crafting screen (`interacted` is connected: `get_signal_connection_list(&"interacted")` is not empty).
  - `test_a_map_config_replaces_the_scene_config_and_a_null_one_keeps_it`: swap `GameMap.map_data` to a duplicate with a fresh `SpawnConfig` before `add_child` and assert the spawner uses it; with `spawn_config = null` assert it keeps the scene's.
  - `test_the_spawn_ring_works_at_every_corner`: for `player.global_position` at the four corners of the map, `spawner.spawn_position(...)` is not `Vector2.INF`, lies inside the bounds, and is outside the view rect (the player-centred view pushed back inside the bounds).
  - `test_f7_toggles_the_overlay`: feed an `InputEventAction` `debug_toggle_map` (pressed) to `main._unhandled_input`; `GameMap/Debug.visible` flips.
- [ ] **Step 2: Run** `-gselect=test_main_map`. Expected: FAIL.
- [ ] **Step 3: Implement** the scene and `_apply_map()` as specified. Search the repo for any other use of the removed node names (`TestArena`, `LecternWest`, `LecternEast`, `LecternSouth`) and fix any it finds.
- [ ] **Step 4: Run the whole suite.** Expected: all PASS, no new warnings. A previously passing test that fails because it assumed the 960×540 arena is a finding: fix the test's assumption only if the old assumption was incidental, and ledger a ruling.
- [ ] **Step 5: Commit** `feat: Main builds the world from the first map`.

### Task 6: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `sprint-12a-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project` once and read `get_debug_output` for warnings (load them with `ToolSearch select:`), then `stop_project`.
- [ ] **Step 2: Stress.** Run `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops` once and `--minutes=0` once. Expected: within noise of Sprint 11 (Standard-only Missile about 481 fps, default about 402). The stress scene still uses `test_arena.tscn`, so a drop means the shared code changed: investigate.
- [ ] **Step 3: Real-window check.** A throwaway script in the scratchpad (extends `SceneTree`, throwaway save path in `res://.godot/save_tests/`, deleted afterwards) loads `main.tscn`, presses F7, screenshots, and checks the player can walk to a wall and stop and that the camera stops at the edge. Confirm the real save file is untouched. Look at the screenshot.
- [ ] **Step 4: Docs.** `sprint-development.md`: split Sprint 12 into 12a, 12b and 12c, tick 12a's items (map, boundaries, Lectern placement, decorations, map-specific spawn config) with a Built note. `README.md`: the 1920×1080 map and the placement idea. `technical-design.md`: the `resources/maps/` and `scripts/world/` layout. `CLAUDE.md`: a "World and maps (Sprint 12a)" section (map as data, `GameMap`, placements, F7, `Main` reads the bounds) and update the facts that say the arena is 960×540. `development-log.md`: the 12a entry with the stress numbers. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit.** Run the whole suite, then commit `docs: Sprint 12a complete`.
