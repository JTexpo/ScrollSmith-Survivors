# Sprint 12c: The Map's Regions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the first map a maze, a walled island and a corridor, each region with its own floor tint and decorations, by adding a seeded maze generator and zone data to `MapData` that feed the existing obstacle systems unchanged.

**Architecture:** `MapMaze` generates wall rectangles from a seed. `MapData.solid_shapes()` returns the authored obstacles plus every maze's walls, and the five places that read `map.obstacles` switch to it, so the grid, flow field, routing, projectiles, physics walls and overlay need no other change. `MapZone` data adds floor tints and decorations. The island and corridor are hand-authored rectangles.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1.

**Spec:** `docs/sprints/sprint-12c-design.md` (repo root). Read it first. Sprint 12d (chests, shrines, merchant, rare scroll spots) is NOT built here.

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit </dev/null` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- The map stays **1920×1080** (user decision). Maze corridor pitch 80 px with 16 px walls (a 64 px gap, 48 px free once grown by the 8 px clearance). The grid stays 16 px cells.
- The maze is deterministic: only its own seeded `RandomNumberGenerator`, a fixed iteration order, no `randomize()`, no dictionaries iterated in an unspecified order. No test depends on an unseeded random roll.
- Sprint 12b behaviour does not change: no edit to the flow field, `Enemy`, `Boss`, `EnemyProjectile` or `EnemySpawner`. The new walls are ordinary `MapObstacle`s.
- Layout limits (tested): the outer 48 px band free, a 150 px open area around the start, every free cell reachable from the start, no gap narrower than two cells, the three Lecterns at least 700 px apart and not inside the maze or island areas, every placement 24 px from any shape. The maze centre and the island interior stay empty (12d fills them).
- World nodes (zone floors, layers, overlay) must not stop touches: `mouse_filter = 2` on any Control. Hand-written `.tscn`/`.tres` need `node_paths=PackedStringArray("prop")` on the `[node]` line for any Node-typed export set by NodePath.
- Tests that instantiate `main.tscn` set `save_path = ""` and the pick screen's `pause_tree = false` before `add_child`, and never touch the real save.
- Conventions: PascalCase classes, snake_case members, UPPER_SNAKE constants, typed GDScript, `##` doc comments, gameplay values in Resources or `@export`s. Match surrounding code's comment density.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`, never `;`, so a failing test stops the commit. Commit generated `.uid` files with their scripts.

## Review Focus

- The same `MapMaze` data gives identical shapes on every call, a different seed gives a different maze, and every cell is connected, with extra openings, a cleared centre and entrances on all four sides (Task 1).
- An invalid maze (area outside the map, fewer than 3 cells either way, a bad entrance) or zone (area outside the map, empty) is reported by `MapData.problems()` (Task 2).
- A map with only a maze (no hand-authored obstacles) is seen by the drawn layer, the physics bodies, the grid, the segment tests and the overlay (Task 3).
- Decorations never sit on a solid shape, and zone floors draw under the decorations and never block a touch (Task 4).
- On the first map every free cell is reachable (the island's gates and the maze work), no gap is narrower than two cells, and the Lecterns are outside the maze and island (Task 5).

---

### Task 1: MazeEntrance and MapMaze

**Files:**
- Create: `resources/maps/maze_entrance.gd`, `resources/maps/map_maze.gd`
- Test: `tests/test_map_maze.gd`

**Interfaces:**
- Consumes: `MapObstacle` (RECT kind).
- Produces:
  - `MazeEntrance` (`Resource`): `enum Side { NORTH, EAST, SOUTH, WEST }`, `@export var cell: Vector2i`, `@export var side: Side`. A boundary cell's wall on `side` is opened.
  - `MapMaze` (`Resource`): `@export var area: Rect2`, `cell_size: float = 80.0`, `wall_thickness: float = 16.0`, `seed: int`, `entrances: Array[MazeEntrance]`, `extra_openings: int = 0`, `clear_center: bool = false`. `columns() -> int` and `rows() -> int` (`floori(area.size / cell_size)`), `shapes() -> Array[MapObstacle]` (RECT walls, centred on cell edges, each `wall_thickness` thick and `cell_size + wall_thickness` long so corners meet), `problems(bounds: Rect2) -> PackedStringArray` (empty when valid: the area inside `bounds`, at least 3 columns and 3 rows, every entrance on the boundary with its side facing out).
  - Generation: an iterative recursive backtracker over the cell grid with a local `RandomNumberGenerator` seeded from `seed`, then `extra_openings` more internal walls removed at random (never more than remain), then `clear_center` (the walls among the middle 2 by 2 cells removed), then each entrance's boundary wall removed. Same data, same shapes, in the same order.

- [ ] **Step 1: Write the failing tests** (`tests/test_map_maze.gd`; a helper `_maze(seed, extras := 0, center := false)` builds a 480×320 maze at (100, 52): 6 columns, 4 rows; a helper `_open(maze, a: Vector2i, b: Vector2i) -> bool` is true when no shape of `maze.shapes()` contains the midpoint of the edge between two adjacent cells; a helper `_passages(maze) -> int` counts open edges between adjacent cells):
  - `test_columns_and_rows_come_from_the_area` (6 and 4), `test_every_shape_is_a_rect_inside_the_area_grown_by_a_wall`.
  - `test_the_same_data_gives_the_same_shapes` (compare position, size and kind of every shape, in order) and `test_a_different_seed_gives_a_different_maze`.
  - `test_every_cell_is_connected` (flood fill over open edges reaches all 24 cells), also with `extra_openings` 3 and `clear_center` true.
  - `test_a_plain_maze_has_one_fewer_passage_than_cells` (23) and `test_extra_openings_add_loops` (26 for 3; capped when fewer walls remain).
  - `test_clear_center_opens_the_middle_cells` (the four centre cells are mutually open).
  - `test_the_boundary_is_closed_except_at_entrances`: with no entrances the midpoint of every boundary edge is inside a shape; with entrances on each of the four sides (one per side) exactly those four boundary edges are open.
  - `test_problems_name_a_bad_maze`: an area outside the bounds, a 2-column area, an entrance on an interior cell, and an entrance whose side faces inward (each a problem), and a valid maze reports none.
- [ ] **Step 2: Run** `-gselect=test_map_maze`. Expected: FAIL (classes not defined).
- [ ] **Step 3: Implement** both scripts as specified. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_map_maze`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: MapMaze, a seeded maze generator`.

### Task 2: MapZone, MapData.solid_shapes and the new checks

**Files:**
- Create: `resources/maps/map_zone.gd`
- Modify: `resources/maps/map_data.gd`
- Test: `tests/test_map_data.gd`

**Interfaces:**
- Consumes: `MapMaze` (Task 1).
- Produces:
  - `MapZone` (`Resource`): `@export var area: Rect2`, `display_name: String`, `floor_color: Color`, `decoration_colors: PackedColorArray`, `decoration_count: int`.
  - `MapData`: `@export var mazes: Array[MapMaze]`, `@export var zones: Array[MapZone]`, `solid_shapes() -> Array[MapObstacle]` (authored `obstacles` first, then each maze's `shapes()` in order; a fresh array each call). `problems()` now checks the shapes in `solid_shapes()` (so a maze wall on the start is reported), adds each maze's `problems(bounds())` prefixed with its index, and reports a zone whose area is empty or not inside the map.

- [ ] **Step 1: Write the failing tests** (`test_map_data.gd` additions):
  - `test_solid_shapes_are_the_obstacles_then_every_maze` (counts and order: one authored rect, one maze: the first shape is the authored one, the rest equal `maze.shapes()`).
  - `test_a_maze_wall_on_the_player_start_is_reported` (a maze whose generated walls pass within 24 px of the start gives at least one problem).
  - `test_problems_name_a_bad_maze_and_a_bad_zone` (a maze area outside the map and a zone with a zero-size area: two problems).
  - `test_a_valid_maze_and_zone_are_fine`.
- [ ] **Step 2: Run** `-gselect=test_map_data`. Expected: FAIL.
- [ ] **Step 3: Implement** `map_zone.gd` and the `MapData` changes. Run `godot --headless --import`.
- [ ] **Step 4: Run** `-gselect=test_map_data` and `-gselect=test_map_maze`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: MapZone and MapData.solid_shapes`.

### Task 3: Everything reads the solid shapes

**Files:**
- Modify: `scripts/world/game_map.gd`, `scripts/world/obstacle_grid.gd`, `scripts/world/obstacle_map.gd`, `scripts/world/map_debug_overlay.gd`
- Test: `tests/test_game_map.gd`, `tests/test_obstacle_grid.gd`, `tests/test_obstacle_map.gd`

**Interfaces:**
- Consumes: `MapData.solid_shapes()` (Task 2).
- Produces: `GameMap` (the `Obstacles` layer and the `ObstacleBodies`), `ObstacleGrid.build`, `ObstacleMap` (stores the list at `setup`; `blocks_segment` iterates it) and `MapDebugOverlay` all use `solid_shapes()` instead of `obstacles`. `MapMaze` walls are therefore drawn, collide, block the grid and stop shots like any obstacle.

- [ ] **Step 1: Write the failing tests** (a map with a `MapMaze` and no authored obstacles):
  - `test_game_map.gd`: `test_a_maze_is_drawn_and_has_wall_bodies` (`Obstacles.item_count()` and the `ObstacleBodies` child count equal `maze.shapes().size()`).
  - `test_obstacle_grid.gd`: `test_a_maze_blocks_cells` (cells blocked at a wall's centre and none at a corridor's centre).
  - `test_obstacle_map.gd`: `test_a_maze_wall_blocks_points_and_segments` (`is_blocked` and `blocks_segment` true across a wall, false along a corridor), and `test_the_flow_field_leads_through_a_maze` (a player inside, a point outside with an entrance: following `direction_from` in 4 px steps reaches the player's cell).
- [ ] **Step 2: Run** `-gselect=test_game_map`, `-gselect=test_obstacle_grid`, `-gselect=test_obstacle_map`. Expected: FAIL.
- [ ] **Step 3: Implement** the four switches (search the repo for any other `.obstacles` read in `scripts/`).
- [ ] **Step 4: Run** the three files, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: every system reads the maze's walls too`.

### Task 4: Zone floors and decorations

**Files:**
- Modify: `scripts/world/game_map.gd`, `scripts/world/map_decor.gd`, `scripts/world/map_debug_overlay.gd`
- Test: `tests/test_game_map.gd`, `tests/test_map_decor.gd`

**Interfaces:**
- Consumes: `MapZone`, `MapData.solid_shapes()` (Task 2).
- Produces: `MapDecor.scatter(map)` now rejects a decoration whose centre is inside any solid shape (grown 2 px). `static func scatter_zone(map: MapData, zone_index: int) -> Array[Dictionary]` (items inside the zone's area, seeded `map.decoration_seed + 1 + zone_index`, the same clear-of-start-and-placements and clear-of-shapes rules, the zone's colours and count). `GameMap` builds a `Zones` node (one `ColorRect` per zone in its `floor_color`, `mouse_filter = IGNORE`, above `Floor`, below `Decor`) and the `Decor` layer gets the global items plus every zone's. The overlay outlines each zone's area.

- [ ] **Step 1: Write the failing tests:**
  - `test_map_decor.gd`: `test_scatter_never_puts_a_decoration_on_a_solid_shape` (a map with an obstacle and a maze: no item centre inside any `solid_shapes()` grown 2 px) and the existing determinism tests still pass; `test_zone_decorations_stay_inside_their_zone_and_are_deterministic`, `test_zone_decorations_use_the_zone_colors_and_count`, `test_a_zone_with_no_colors_or_count_gives_nothing`.
  - `test_game_map.gd`: `test_each_zone_has_a_floor_under_the_decorations` (the `Zones` children have the zones' rects and colours, `mouse_filter == Control.MOUSE_FILTER_IGNORE`, and come before `Decor` in child order) and `test_the_decor_layer_holds_global_and_zone_items` (item count equals the sum of the scatters).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** the changes. `tests/test_world_input.gd` already loads `game_map.tscn`, so it covers the new Controls.
- [ ] **Step 4: Run** both files, `-gselect=test_world_input` and `-gselect=test_main_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: zone floors and decorations`.

### Task 5: The first map's regions

**Files:**
- Modify: `resources/maps/first_map.tres`, `tests/test_first_map_layout.gd`
- Test: `tests/test_first_map_layout.gd`, `tests/test_first_map_regions.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: `first_map.tres` re-laid out. A `MapMaze` in the north-west region (about 480×320, 6 by 4 cells, an entrance on at least two sides, `extra_openings` 2 to 4, `clear_center` true, a chosen seed), a walled island in the north-east region (about 360×280, one or two gates at least 64 px wide, a free interior), a corridor along the bottom (two walls 80 px apart centre to centre, at least 400 px long, open at both ends), pillar groves and short walls kept from 12b where they do not collide with the new regions, the three Lecterns outside the maze and island and at least 700 px apart, and `MapZone`s: at least one per region (a distinct floor tint and decoration colours each: for example a darker green maze, a stone-grey island, a path-brown corridor, the existing green for the rest). Coordinates are the builder's, judged by the F7 overlay and tuned by the user in play. The maze area, the island gates and the corridor are offset so no gap quantizes to one cell.

- [ ] **Step 1: Write the failing tests.**
  - Update `test_first_map_layout.gd` to the new limits, reading `solid_shapes()`: `test_the_first_map_has_between_60_and_160_solid_shapes`, the outer 48 px band free (over `solid_shapes()`), the central 150 px free, blocked share between 3% and 30%, no gap narrower than two cells, the open 10 by 10 square 400 px from the start, and `test_every_free_cell_is_reachable_from_the_start` (a flood fill from the start's cell reaches every free cell of the grid).
  - New `test_first_map_regions.gd`: `test_the_first_map_has_a_maze_an_island_zone_and_corridor_zone_tints` (one `MapMaze`, at least 3 zones with different floor colours); `test_the_lecterns_are_outside_the_maze_and_the_walled_island` (each Lectern position outside the maze's `area` grown 24 px and outside the island's area, which the test reads from the `MapZone` named "Island"); `test_the_maze_and_island_are_deterministic` (loading the map twice gives identical `solid_shapes()`); `test_the_maze_centre_and_the_island_interior_are_free_for_12d` (the grid is free at the maze's centre and at the island zone's centre); `test_the_map_has_many_narrow_runs` (at least 60 grid lines have a 2 to 3 cell wide bounded run, which only a maze and corridor give).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Author the layout** in `first_map.tres`. Run the project, press F7, and look at the overlay with a real-window screenshot (the whole map by zooming the camera out) to adjust coordinates, the maze seed and the openings until the tests pass and it reads as: a maze, a walled island with gates, a long corridor, and an open centre.
- [ ] **Step 4: Run** both files, `-gselect=test_map_data`, `-gselect=test_main_map`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the first map's maze, island, corridor and zones`.

### Task 6: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-12c-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project`, read `get_debug_output` for warnings (load with `ToolSearch select:`), then `stop_project`.
- [ ] **Step 2: Stress.** `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles`, three runs, median. Expected: at least 60 fps and within about 15% of Sprint 12b (about 275 fps). Also time one full flow-field rebuild and the incremental slice on the new map (a throwaway scratchpad script, deleted afterwards). Expected: a slice of about 2 ms or less.
- [ ] **Step 3: Real-window check.** A throwaway scratchpad script (extends `SceneTree`, `save_path` empty so the real save is untouched, set up on the first frame, deleted afterwards): screenshot the whole map zoomed out with F7 on, and let enemies placed outside the maze reach a player standing in its centre room, and enemies outside the island reach a player inside it, printing the nearest distance over time and counting any enemy ever inside a blocked cell. Look at the screenshots.
- [ ] **Step 4: Docs.** `sprint-development.md`: split Sprint 12 into 12a to 12d, tick 12c's items, add a Built note. `README.md`: the regions. `technical-design.md`: the new files. `CLAUDE.md`: a "Map regions (Sprint 12c)" section (`MapMaze` and its determinism, `solid_shapes()` as the one list every reader uses, `MapZone`, the layout limits, the grid alignment note) and update the obstacle readers mentioned in the 12b section. `development-log.md`: the 12c entry with stress numbers. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit.** Run the whole suite, then commit `docs: Sprint 12c complete`.
