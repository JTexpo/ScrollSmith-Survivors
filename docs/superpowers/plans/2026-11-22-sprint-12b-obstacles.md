# Sprint 12b: Obstacles and a Flow Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add obstacles to the first map that block movement (the player's and every enemy's) and enemy projectiles, with enemies routing around them by a flow field, so wide circling is weaker, small loops and narrow paths exist, and nobody gets stuck.

**Architecture:** `MapObstacle` resources in `MapData` describe rectangles and circles. An `ObstacleGrid` (coarse blocked cells) and a `FlowField` (a breadth-first sweep from the player) are owned by an `ObstacleMap` node under `GameMap`. Enemies, the boss, enemy projectiles and the spawner find it through the `obstacle_map` group and fall back to today's behaviour when none exists. The player collides through physics bodies built from the same shapes. All player spells pass over obstacles, so no Area or damage code changes.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `docs/sprints/sprint-12b-design.md` (repo root). Read it first. Sprint 12c (chests, shrines, merchant, rare scroll spots) is NOT built here.

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit </dev/null` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- Obstacles block **movement and enemy projectiles only**. Every player spell, every Area and `DamageSystem` stay untouched. Ground effects (blast zones, boss slams) ignore obstacles.
- Grid cell size 16 px and body clearance 8 px are `MapData` exports (`nav_cell_size`, `body_clearance`), not constants in code. The flow field rebuilds when the player enters a new cell and at most every 0.2 s.
- First-map layout limits: about 25 to 35 obstacles, the outer 48 px band free, an open central area around the start, corridors at least 48 px wide, every placement (Lecterns) and the start free of obstacles by at least 24 px and reachable.
- With no `ObstacleMap` in the tree, every caller behaves exactly as in Sprint 12a (so existing tests keep passing).
- No code branches on an enemy name, a map id or an obstacle kind to choose behaviour. Nothing here edits shared resources.
- World nodes (the obstacle layer, the overlay) must not stop touches: `mouse_filter = 2` on any Control. Hand-written `.tscn` needs `node_paths=PackedStringArray("prop")` on the `[node]` line for any Node-typed export set by NodePath.
- Tests that instantiate `main.tscn` set `save_path = ""` and the pick screen's `pause_tree = false` before `add_child`, and never touch the real save. No test depends on an unseeded random roll for its pass or fail.
- Conventions: PascalCase classes, snake_case members, UPPER_SNAKE constants, typed GDScript, `##` doc comments, gameplay values in Resources or `@export`s. Match surrounding code's comment density.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`, never `;`, so a failing test stops the commit. Commit generated `.uid` files with their scripts.

**Plan note (a deviation from the design, ruled here):** `MapData.problems()` covers the shape checks only. Reachability needs the grid, and `ObstacleGrid` is built from `MapData`, so `problems()` must not call it (a circular dependency). `ObstacleGrid.reachability_problems(map)` reports unreachable placements, and `GameMap` reports both lists.

## Review Focus

- A U-shaped dead end with the player inside and an enemy outside: the enemy reaches the player (the parking exploit does not work) (Task 6).
- An enemy knocked into, spawned beside, or pushed toward a wall never ends inside an obstacle (Tasks 6, 7).
- A map whose start or Lectern is inside an obstacle, too close to one, or unreachable is reported (Tasks 1, 2, 8).
- The field's player-cell timer and rebuild freeze while the tree is paused, and the field does not rebuild on frames the player stays in one cell (Task 4).
- A Ranged enemy retreating into a wall, an enemy projectile crossing an obstacle, and a boss Charge into an obstacle all stop at it, and the Charge still opens the vulnerability window (Task 7).

---

### Task 1: MapObstacle and the shape checks

**Files:**
- Create: `resources/maps/map_obstacle.gd`
- Modify: `resources/maps/map_data.gd`
- Test: `tests/test_map_obstacle.gd`, `tests/test_map_data.gd`

**Interfaces:**
- Produces:
  - `MapObstacle` (`Resource`): `enum Kind { RECT, CIRCLE }`, `@export var kind: Kind`, `@export var position: Vector2` (the centre), `@export var size: Vector2` (full width and height, RECT), `@export var radius: float` (CIRCLE). `contains(point: Vector2, grow: float = 0.0) -> bool`, `overlaps_rect(rect: Rect2, grow: float = 0.0) -> bool`, `blocks_segment(from: Vector2, to: Vector2) -> bool` (exact: the segment touches the shape), `bounds() -> Rect2`, `is_valid() -> bool` (RECT needs both size parts above 0, CIRCLE a radius above 0).
  - `MapData`: `@export var obstacles: Array[MapObstacle]`, `@export var nav_cell_size: float = 16.0`, `@export var body_clearance: float = 8.0`, `const OBSTACLE_CLEARANCE := 24.0`. `problems()` also reports an invalid obstacle, an obstacle not fully inside the map, and an obstacle within `OBSTACLE_CLEARANCE` of the player start or any placement (one line each).

- [ ] **Step 1: Write the failing tests.**
  - `test_map_obstacle.gd` (rect at (100, 100) of size (40, 20), circle at (200, 100) of radius 10): `test_a_rect_contains_its_inside_and_not_its_outside`, `test_grow_widens_a_rect_and_a_circle` (a point 5 px outside is inside at grow 6), `test_a_circle_contains_by_radius`, `test_overlaps_rect_for_both_kinds`, `test_a_segment_through_a_shape_is_blocked_and_one_beside_it_is_not` (both kinds), `test_a_segment_ending_inside_a_shape_is_blocked`, `test_a_segment_entirely_inside_is_blocked`, `test_bounds_cover_the_shape`, `test_is_valid_rejects_zero_sizes`.
  - `test_map_data.gd` additions: `test_problems_name_an_invalid_or_outside_obstacle` (a zero-size rect, and a circle poking past the edge: two problems), `test_problems_name_an_obstacle_on_or_near_the_start_or_a_placement` (one on the start, one 10 px from the placement: two problems), `test_a_clear_obstacle_is_fine`.
- [ ] **Step 2: Run** `-gselect=test_map_obstacle` and `-gselect=test_map_data`. Expected: FAIL.
- [ ] **Step 3: Implement** both as specified (segment against rect by slab clipping, against circle by closest point on the segment). Run `godot --headless --import`.
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Commit** `feat: MapObstacle and obstacle checks in MapData`.

### Task 2: The obstacle grid

**Files:**
- Create: `scripts/world/obstacle_grid.gd`
- Test: `tests/test_obstacle_grid.gd`

**Interfaces:**
- Consumes: `MapData`, `MapObstacle` (Task 1).
- Produces: `ObstacleGrid` (`RefCounted`): `static func build(map: MapData) -> ObstacleGrid` (cell size from `nav_cell_size`, a cell is blocked when any obstacle grown by `body_clearance` overlaps it), fields `cell_size: float`, `columns: int`, `rows: int`, `blocked: PackedByteArray`; `cell_of(point: Vector2) -> Vector2i` (clamped into the grid), `cell_center(cell: Vector2i) -> Vector2`, `is_blocked_cell(cell: Vector2i) -> bool` (out of range counts as blocked), `is_blocked(point: Vector2) -> bool`, `nearest_free(point: Vector2) -> Vector2` (the centre of the nearest free cell by ring search, the point itself when already free), `static func reachability_problems(map: MapData) -> PackedStringArray` (one line per placement not reachable from the player start through free cells, plus one when the start's own cell is blocked).

- [ ] **Step 1: Write the failing tests** (a 160×160 map with `nav_cell_size` 16 and `body_clearance` 0 unless stated):
  - `test_no_obstacles_means_no_blocked_cells`, `test_a_rect_blocks_the_cells_it_overlaps_and_no_others`, `test_a_circle_blocks_by_its_radius`, `test_body_clearance_blocks_cells_around_an_obstacle` (clearance 8 blocks one more ring).
  - `test_cell_of_and_cell_center_round_trip` and `test_cell_of_clamps_outside_points`.
  - `test_out_of_range_cells_are_blocked`.
  - `test_nearest_free_returns_a_free_point_and_leaves_a_free_point_alone`.
  - `test_reachability_flags_a_placement_walled_in` (a ring of rects around a placement) and `test_reachability_passes_an_open_map`, `test_reachability_flags_a_blocked_start`.
- [ ] **Step 2: Run** `-gselect=test_obstacle_grid`. Expected: FAIL.
- [ ] **Step 3: Implement** as specified. `reachability_problems` uses a simple 4-connected flood fill over `blocked`. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_obstacle_grid`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the obstacle grid and reachability check`.

### Task 3: The flow field

**Files:**
- Create: `scripts/world/flow_field.gd`
- Test: `tests/test_flow_field.gd`

**Interfaces:**
- Consumes: `ObstacleGrid` (Task 2).
- Produces: `FlowField` (`RefCounted`): `rebuild(grid: ObstacleGrid, target: Vector2) -> void` (a breadth-first sweep over free cells outward from the target's cell, using packed arrays, 8-neighbour moves that never cut across a blocked corner), `distance_at(point: Vector2) -> int` (`-1` when unreached or blocked), `direction_at(point: Vector2) -> Vector2` (a unit vector toward the target along the field, or `Vector2.ZERO` when the cell is blocked or unreached or is the target's cell). In open ground the direction is the distance field's gradient, not the best neighbour's step, so it is within 15 degrees of the straight line to the target.

- [ ] **Step 1: Write the failing tests** (grids built from small `MapData`s, a target at a known point):
  - `test_the_target_cell_has_distance_zero_and_distances_grow_away_from_it`.
  - `test_in_open_ground_the_direction_is_within_15_degrees_of_the_straight_line` (a grid of sample points, none within 2 cells of the target).
  - `test_a_wall_between_makes_the_direction_go_around_it` (a vertical wall with a gap at one end: a point behind the wall gets a direction with a component toward the gap, and following the field step by step for up to 200 steps of 8 px reaches the target's cell).
  - `test_a_u_shaped_dead_end_is_escaped` (player inside a U open to the south, a point north of the U: following the field reaches the target).
  - `test_blocked_and_sealed_cells_have_no_direction` (a sealed pocket has distance `-1` and direction `Vector2.ZERO`).
  - `test_the_sweep_never_crosses_a_blocked_corner` (a diagonal gap between two blocked cells is not a route).
  - `test_rebuilding_for_a_new_target_replaces_the_old_field`.
- [ ] **Step 2: Run** `-gselect=test_flow_field`. Expected: FAIL.
- [ ] **Step 3: Implement** as specified, with `PackedInt32Array` for distances and a `PackedInt32Array` ring queue, so no per-cell `Vector2i` allocation. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_flow_field`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the flow field`.

### Task 4: The ObstacleMap node

**Files:**
- Create: `scripts/world/obstacle_map.gd`
- Test: `tests/test_obstacle_map.gd`

**Interfaces:**
- Consumes: `MapData`, `MapObstacle` (Task 1), `ObstacleGrid` (Task 2), `FlowField` (Task 3).
- Produces: `ObstacleMap` (`Node`, adds itself to the group `obstacle_map`): `setup(map: MapData) -> void` (builds the grid, builds the field once if a `player` group node exists); `const REBUILD_INTERVAL := 0.2`; `rebuild_count: int` (how many times the field was rebuilt, for tests); `direction_from(point: Vector2) -> Vector2` (the field's direction, or `Vector2.ZERO` for none); `is_blocked(point: Vector2) -> bool`; `blocks_segment(from: Vector2, to: Vector2) -> bool` (exact, against `MapObstacle.blocks_segment`); `push_out(point: Vector2) -> Vector2` (the grid's `nearest_free`); `resolve_move(from: Vector2, to: Vector2) -> Vector2` (returns `to` when its cell is free, else tries the x then y components alone and returns the first free result, else `from`, and `push_out(from)` when `from` itself is blocked). In `_physics_process(delta)` it rebuilds the field toward the first node in the `player` group when that node's cell changed and at least `REBUILD_INTERVAL` of physics time has passed since the last rebuild. It does nothing without a player.

- [ ] **Step 1: Write the failing tests:**
  - `test_it_joins_the_obstacle_map_group`.
  - `test_blocks_segment_and_is_blocked_follow_the_shapes`.
  - `test_push_out_returns_a_free_point`.
  - `test_resolve_move_allows_free_moves_slides_along_a_wall_and_never_enters_a_blocked_cell` (moving diagonally into a wall keeps the along-wall component).
  - `test_direction_from_leads_around_a_wall_toward_the_player` (add a `Node2D` player to the group `player` behind a wall, call `_physics_process` repeatedly: a point behind the wall gets a direction with a component toward the gap).
  - `test_the_field_rebuilds_only_when_the_player_changes_cell_and_the_interval_has_passed` (player stays: `rebuild_count` stays; player moves one cell but less than the interval has passed: unchanged; after the interval: +1).
  - `test_nothing_rebuilds_while_the_tree_is_paused` (async: `get_tree().paused = true`, move the player, `await wait_physics_frames(5)`, `rebuild_count` unchanged; unpause in the test's end).
  - `test_without_a_player_nothing_breaks`.
- [ ] **Step 2: Run** `-gselect=test_obstacle_map`. Expected: FAIL.
- [ ] **Step 3: Implement** as specified. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_obstacle_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: ObstacleMap owns the grid and the flow field`.

### Task 5: GameMap builds the obstacles

**Files:**
- Create: `scripts/world/obstacle_layer.gd`
- Modify: `scripts/world/game_map.gd`, `scripts/world/map_debug_overlay.gd`, `tests/test_world_input.gd` (nothing new if no Control is added, but confirm)
- Test: `tests/test_game_map.gd`, `tests/test_map_debug_overlay.gd`

**Interfaces:**
- Consumes: `ObstacleMap` (Task 4), `MapData.obstacles` (Task 1).
- Produces: `ObstacleLayer` (`Node2D`): `set_obstacles(obstacles: Array[MapObstacle]) -> void`, `item_count() -> int`, one `_draw` (grey fill, darker outline, TEMPORARY). `GameMap._ready` additionally builds `Obstacles` (an `ObstacleLayer`, above `Floor` and `Decor`), a `StaticBody2D` per obstacle under a node `ObstacleBodies` (layer `PhysicsLayers.WORLD`, mask 0, a `RectangleShape2D` or `CircleShape2D` of the obstacle's exact size), and an `ObstacleMap` child named `ObstacleMap` set up from the map data. It reports `ObstacleGrid.reachability_problems(map_data)` with `push_error`, like `problems()`. The overlay also draws each obstacle's outline, the blocked cells (a faint fill) and the field's direction as short arrows on every second cell within 160 px of the player, redrawn about every 0.2 s while visible.

- [ ] **Step 1: Write the failing tests.**
  - `test_game_map.gd`: `test_each_obstacle_is_drawn_and_has_a_wall_body` (a map with one rect and one circle: `Obstacles.item_count() == 2`, `ObstacleBodies` has 2 `StaticBody2D`s on the world layer with shapes of the right size and radius), `test_it_builds_an_obstacle_map` (the child exists, is in the group `obstacle_map`, and blocks a point inside the rect), `test_a_body_pushed_at_an_obstacle_is_stopped` (async, as the wall test in this file), `test_an_unreachable_placement_is_reported_when_it_loads` (a placement ringed by rects: `assert_push_error("not reachable")` or the wording the implementation uses, one call per reported problem).
  - `test_map_debug_overlay.gd`: `test_it_counts_obstacles_among_its_markers` is NOT needed. Instead `test_the_overlay_still_toggles_with_obstacles_present` (a map with obstacles: toggle on and off).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** the layer, the `GameMap` additions and the overlay drawing. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_game_map`, `-gselect=test_map_debug_overlay`, `-gselect=test_world_input`, `-gselect=test_main_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: GameMap builds obstacle bodies, layer and the ObstacleMap`.

### Task 6: Enemies route around obstacles

**Files:**
- Modify: `scripts/entities/enemy.gd`
- Test: `tests/test_enemy_obstacles.gd`

**Interfaces:**
- Consumes: `ObstacleMap.direction_from`, `resolve_move`, `push_out` (Task 4).
- Produces: `Enemy` finds the `obstacle_map` group node once in `_ready` (cached, null when none). `direction_to_target()` returns, when the map gives a direction for the enemy's position, `(field_direction + (offset_direction - straight_direction)).normalized()` (so the horde-spreading offset survives and open ground behaves as before), otherwise exactly today's result. `_physics_process` moves through `resolve_move(position, new_position)` when a map exists, before the arena clamp, so knockback into a wall is stopped too. A spawned enemy's position is pushed out of a blocked cell by `setup`.

- [ ] **Step 1: Write the failing tests** (an `ObstacleMap` set up from a small `MapData`, a `Node2D` in the group `player`, an `Enemy` from `res://scenes/enemies/base_enemy.tscn` set up with a fixture enemy and large bounds, stepped by calling `enemy._physics_process(1.0 / 60.0)` in a loop, with the field rebuilt by calling the map's `_physics_process` too):
  - `test_without_an_obstacle_map_the_direction_is_the_old_one` (equal to the straight direction).
  - `test_in_open_ground_the_direction_is_close_to_the_old_one` (within 15 degrees).
  - `test_an_enemy_goes_around_a_wall_to_reach_the_player` (within 900 steps it ends within 20 px of the player and never inside a blocked cell).
  - `test_an_enemy_outside_a_u_shaped_dead_end_reaches_a_player_inside_it` (within 1500 steps).
  - `test_knockback_into_a_wall_never_ends_inside_an_obstacle` (apply knockback toward a wall through the enemy's knockback component, step 60 times, assert `is_blocked(position)` is false at every step).
  - `test_a_retreating_ranged_enemy_stops_at_a_wall` (a `BrainKeepDistance` enemy with the player closer than its preferred distance and a wall behind it: after 120 steps its position is not blocked).
  - `test_an_enemy_set_up_inside_an_obstacle_is_moved_out`.
- [ ] **Step 2: Run** `-gselect=test_enemy_obstacles`. Expected: FAIL.
- [ ] **Step 3: Implement** in `enemy.gd`. No brain is edited.
- [ ] **Step 4: Run** `-gselect=test_enemy_obstacles`, then the whole suite. Expected: PASS (the Sprint 11 enemy, spawner and brain tests prove the fallback).
- [ ] **Step 5: Commit** `feat: enemies route around obstacles by the flow field`.

### Task 7: Boss, projectiles and spawning

**Files:**
- Modify: `scripts/enemies/boss.gd`, `scripts/enemies/enemy_projectile.gd`, `scripts/systems/enemy_spawner.gd`
- Test: `tests/test_obstacle_dangers.gd`

**Interfaces:**
- Consumes: `ObstacleMap` (Task 4).
- Produces:
  - `Boss`: walks toward the player along `direction_from` (straight when none), moves through `resolve_move`, and a Charge dash that has been stopped by an obstacle ends at once through `_finish_attack` (the vulnerability window still opens).
  - `EnemyProjectile`: `_physics_process` frees the shot when the segment from its old to its new position `blocks_segment`, before any hit.
  - `EnemySpawner.spawn_position` rejects a blocked point (it already retries angles). Swarmer cluster members and boss summon positions are passed through `push_out` when a map exists.

- [ ] **Step 1: Write the failing tests:**
  - `test_a_projectile_is_freed_when_it_crosses_an_obstacle_and_one_beside_it_flies_on` (step `_physics_process` directly, `is_queued_for_deletion()`).
  - `test_a_projectile_without_an_obstacle_map_is_unchanged`.
  - `test_the_boss_walks_around_a_wall_to_the_player` (within 1500 steps, never in a blocked cell).
  - `test_a_boss_charge_stops_at_an_obstacle_and_the_vulnerability_window_opens` (build a `BossData` with one CHARGE attack and a wall in its path; step until it ends; `state == RECOVER`, `vulnerable` is true, and the boss never entered the wall).
  - `test_spawn_position_never_returns_a_blocked_point` (200 calls with a seeded `rng`, a map with obstacles near the ring).
  - `test_cluster_members_and_summons_are_moved_out_of_obstacles` (an obstacle on the spot a cluster would use).
- [ ] **Step 2: Run** `-gselect=test_obstacle_dangers`. Expected: FAIL.
- [ ] **Step 3: Implement** the three changes. The boss and the spawner find the map through the `obstacle_map` group.
- [ ] **Step 4: Run** `-gselect=test_obstacle_dangers`, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the boss, enemy shots and spawning respect obstacles`.

### Task 8: The first-map layout

**Files:**
- Modify: `resources/maps/first_map.tres`
- Test: `tests/test_first_map_layout.gd`

**Interfaces:**
- Consumes: `MapObstacle` (Task 1), `ObstacleGrid` (Task 2), `MapData.problems()`.
- Produces: `first_map.tres` with obstacles (RECT and CIRCLE `sub_resource`s using `map_obstacle.gd`, typed array syntax as in the existing placements). The layout, to be judged with the F7 overlay and tuned by the user in play: an open central area around the start (no obstacle within 150 px of (960, 540)); four to six solid pillar clusters (several overlapping circles, each about 60 to 100 px across) placed so a loop around one is a small circle; three or four wall runs (RECTs, 16 to 24 px thick) forming corridors at least 48 px wide between a wall and its neighbour or a cluster; every Lectern reachable by at least two distinct routes (judged by eye on the overlay, not tested); obstacles kept 48 px from the map edge; none within 24 px of the start or a Lectern.

- [ ] **Step 1: Write the failing tests** (`test_first_map_layout.gd`, loading `first_map.tres`):
  - `test_the_first_map_has_between_25_and_35_obstacles`.
  - `test_the_first_map_has_no_problems_and_every_placement_is_reachable` (`problems()` and `ObstacleGrid.reachability_problems` both empty).
  - `test_the_outer_48px_band_has_no_obstacles`.
  - `test_the_central_area_is_open` (no obstacle within 150 px of the start).
  - `test_most_of_the_map_is_still_walkable` (blocked cells are between 3% and 25% of all cells).
  - `test_the_map_has_narrow_paths_and_open_ground` (using the grid at `body_clearance` 8: at least one run of free cells exactly 3 to 4 cells wide, found by scanning rows and columns between blocked cells, and at least one 12 by 12 cell fully free square away from the start).
- [ ] **Step 2: Run** `-gselect=test_first_map_layout`. Expected: FAIL (no obstacles yet).
- [ ] **Step 3: Author the layout** in `first_map.tres`. Run the project, press F7, and look at the overlay (a real-window screenshot, as in Sprint 12a) to adjust coordinates until the tests pass and the layout reads as: open centre, small loops, a few corridors.
- [ ] **Step 4: Run** `-gselect=test_first_map_layout`, `-gselect=test_map_data`, `-gselect=test_main_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the first map's obstacle layout`.

### Task 9: Stress, verify and document

**Files:**
- Modify: `scripts/dev/stress_test.gd`, `scenes/world/stress_test.tscn` only as needed, `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-12b-design.md` (Status: Built)

- [ ] **Step 1: The stress option.** `--obstacles` makes the stress scene use the first map instead of `test_arena.tscn` (a `GameMap` with its `ObstacleMap`, the spawner's bounds, the camera limits and the player start taken from it, as `Main` does). Without it nothing changes. Add the option to the header comment and the argument parser.
- [ ] **Step 2: Measure.** Run `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops` with and without `--obstacles`, three runs each, medians. Expected: with obstacles at least 60 fps and within about 15% of without. Separately measure the time of one field rebuild on the first map (a throwaway scratchpad script, deleted afterwards). Expected: under 8 ms, and if above, spread the sweep over several frames before going on.
- [ ] **Step 3: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project` and read `get_debug_output` for warnings (load with `ToolSearch select:`), then `stop_project`.
- [ ] **Step 4: Real-window check.** A throwaway scratchpad script (extends `SceneTree`, `save_path` empty so the real save is untouched, deleted afterwards): press F7 with a real key event, screenshot the overlay near an obstacle cluster, walk the player into an obstacle and confirm it stops, and let enemies chase the player behind a wall for a few seconds and confirm they find a way round. Look at the screenshots.
- [ ] **Step 5: Docs.** `sprint-development.md`: tick Sprint 12b's item (obstacles) and add a Built note. `README.md`: obstacles and how enemies route. `technical-design.md`: the new files. `CLAUDE.md`: an "Obstacles (Sprint 12b)" section (what blocks what, the grid and field, the `obstacle_map` group and fallback, the plan note about `problems()` and reachability, the 0.2 s rebuild, the layout limits, `--obstacles`) and update the enemy movement facts. `development-log.md`: the 12b entry with the stress and rebuild numbers. Set the design doc's status to Built.
- [ ] **Step 6: Full suite and commit.** Run the whole suite, then commit `docs: Sprint 12b complete`.
