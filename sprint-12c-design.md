# Sprint 12c Design: The Map's Regions (a Maze, an Island, a Corridor)

**Status:** Proposed.

Sprint 12 is now four sprints (the user agreed to split further): **12a** the world (done), **12b** obstacles (done), **12c** the map's regions (this doc) and **12d** points of interest (chests, Health and Mana Shrines, the merchant, rare scroll spots, with refresh timers). Scope comes from the conversation, `sprint-12a-design.md`, `sprint-12b-design.md`, `sprint-development.md` and the README (section 9). Architecture follows `CLAUDE.md` and `technical-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

After 12b the first map has obstacles but still feels bare: an open field with scattered pillars and walls. The user asked for places with a character of their own: **a maze, an island (a walled-off zone), and a corridor**, and said to add suggestions. Each region gets a purpose that 12d will fill in, so the points of interest can be placed on purpose and not squeezed in afterwards:
- **The maze:** slow, tight, risky. Its centre will hold a Rare scroll spot (12d). Enemies come through its corridors one behind another, which makes Line and Cone spells strong, and it has loops so a player cannot be trapped for good.
- **The island:** a walled-off stronghold with one or two narrow gates. It will hold a chest and a Mana Shrine (12d). The gates make a bottleneck: enemies funnel in, a well-built loadout can hold them, and a player with a bad one can be trapped.
- **The corridor:** a long straight shortcut between two parts of the map. It is fast, but a horde behind you stays in a line and one ahead blocks you.
- **The open plaza and the pillar groves** stay as they are, for small-loop circling.
- Each region reads at a glance through its own floor tint and decorations.

**Goals**
- `MapMaze`: a maze generated from data (area, corridor pitch, a seed, entrances, extra openings). Same data gives the same maze every time.
- `MapZone`: a floor tint and decoration set for a region of the map.
- A re-laid first map (still 1920×1080, the user chose to keep it): a maze, an island and a corridor placed in the 3×3 grid of regions (each about 640×360), with the three Lecterns spread across other regions.
- Everything downstream keeps working with no change in behaviour: the flow field, enemy routing, projectiles, spawning, the overlay. The new walls are ordinary obstacles.
- Frame rate holds.

**Non-goals (later sprints)**
- Chests, shrines, the merchant and rare scroll spots (12d). 12c leaves the maze centre and the island interior empty and free for them.
- Zones that change enemy spawning (a Fire zone with more Fire enemies): a future biome feature.
- A bigger map (the user chose to work with 1920×1080 and revisit if a zone feels cramped), doors that open, destructible walls, a minimap, final art (Sprint 13).

**Anti-goals** (a failure even if it technically works)
- A region or a pocket of free space that cannot be reached, or a gap only one grid cell wide (it traps bigger enemies, as the 12b layout test already forbids).
- A maze that is different on every load, or a generator that uses unseeded randomness.
- A maze with no loops that a player can be trapped in, with the flow field sending the whole horde in after them.
- Code that branches on a zone name or a map id. Everything a zone or maze does is data.
- The new shapes slowing the game noticeably, or any 12b behaviour changing.

## 2. Decisions

| Area | Decision |
|---|---|
| Hybrid build (user decision, "3") | A **maze generator** (the tedious part by hand), **hand-authored** walls for the island and the corridor (a handful of rectangles each), and zone floors and decorations as data. |
| `MapMaze` (Resource, `resources/maps/`) | `area: Rect2` (where the maze sits), `cell_size: float = 80.0` (the pitch between wall centres, so a 16 px wall leaves a 64 px gap), `wall_thickness: float = 16.0`, `seed: int`, `entrances: Array[MazeEntrance]` (`MazeEntrance`, a small Resource: a boundary `cell: Vector2i` and a `side`), `extra_openings: int` (walls removed after generating, to make loops) and `clear_center: bool` (open the middle 2 by 2 cells into one room, for 12d). `shapes() -> Array[MapObstacle]` returns its walls as RECT obstacles. `MapData.mazes: Array[MapMaze]`. |
| Generation (my call) | A recursive backtracker (an iterative depth-first search) on `floor(area.size / cell_size)` cells, seeded from `seed` with a local `RandomNumberGenerator` (deterministic across platforms), then `extra_openings` more walls removed at random, then the entrances opened in the boundary. Walls are rectangles of `wall_thickness` along cell edges, long enough to meet at the corners. Connectivity is guaranteed by construction (a spanning tree plus openings). |
| `MapData.solid_shapes()` | Returns `obstacles` plus every maze's shapes, as one list. It builds fresh each call and is cheap, so callers keep the result. **All five readers of `map.obstacles` switch to it:** `MapData.problems()`, `ObstacleGrid.build`, `GameMap` (the drawn layer and the physics bodies), `ObstacleMap` (it stores the list at `setup`, so projectile tests never rebuild it) and `MapDebugOverlay`. Nothing else knows mazes exist. |
| The island (hand-authored) | A walled rectangle of about 360×280 with one or two gates, each at least 64 px wide (48 px free once the grid is grown), a free interior and nothing inside it yet. |
| The corridor (hand-authored) | Two long walls 80 px apart centre to centre (a 64 px gap), at least 400 px long, open at both ends, joining two regions. |
| `MapZone` (Resource) | `area: Rect2`, `display_name`, `floor_color: Color`, `decoration_colors`, `decoration_count`. `MapData.zones: Array[MapZone]`. `GameMap` draws each zone's floor over the base floor (under the decorations) and scatters its decorations inside it. The scatter also avoids every solid shape from now on. A zone has no gameplay effect in this sprint. |
| Region placement (my call, tuned by play) | The map is a 3×3 grid of regions of about 640×360. The maze fills most of the north-west one, the island the north-east one, the corridor runs along the bottom across the south-west and south-centre ones, the open plaza stays in the centre, and the remaining regions keep pillar groves. The three Lecterns move out of the maze and the island and stay at least 700 px apart. Exact coordinates, the maze seed and the extra openings are the builder's, judged by the F7 overlay and the tests, then tuned by the user in play. |
| Layout rules (tests) | Updated from 12b: the obstacle count limit becomes a limit on solid shapes (a larger range, since the maze adds many), the outer 48 px band and the 150 px open centre stay free, the blocked fraction range widens (the maze blocks a lot of cells in one place), no gap narrower than two cells, and **every free cell is reachable from the start** (no sealed pockets, which also proves the island's gates and the maze work). The maze's area is offset off the 16 px grid so its corridors never quantize to one cell. |
| Debug overlay | Draws solid shapes (the maze included) and zone outlines. |
| Stress | `--obstacles` already uses the first map, so it measures the new layout. |

## 3. Approaches considered

1. **Everything hand-authored.** No new code, but a 6×4 maze alone is about 35 segments, a change means re-deriving coordinates by hand, and the three regions would be 80 or more shapes.
2. **Generators for every region.** Compact and reusable, but the island and corridor are simple enough that a generator barely saves any typing, and it is the most new code.
3. **The hybrid (chosen by the user).** A maze generator, hand-authored island and corridor, and zone tints and decorations as data. New code only where hand-authoring is tedious, and the maze is what the user will want to tune (size, seed, openings).

## 4. Risks for the builder

- **Grid quantization.** With 16 px cells and an 8 px clearance, a 64 px gap can quantize to one free cell when the walls sit on a bad alignment. The maze area, the island gates and the corridor must be offset so the layout test's "no gap narrower than two cells" holds.
- **Same maze on every load.** The generator must use only its own seeded `RandomNumberGenerator` and iterate in a fixed order. A test generates the same maze twice and compares every shape, and a test confirms a different seed gives a different maze.
- **Entrances.** A maze whose entrance is on a wall that is also a map edge, or a cell outside the maze, must be reported by `MapData.problems()` (for example `area` outside the map, fewer than 3 cells either way, an invalid entrance).
- **Readers of obstacles.** Missing one of the five readers would make the maze draw but not block (or block but not draw). A test builds a map with only a maze and checks the layer, the physics bodies, the grid and the shape tests all see it.
- **Shape count.** `blocks_segment` tests every solid shape for any segment that fails the quick all-cells-free check, and a maze adds dozens. Re-run the stress test with `--obstacles` and compare with 12b (about 275 fps).
- **Reachability of the island.** Its gates must be wide enough for the grown grid to open them. The reachability check and the new "every free cell is reachable" test cover it.
- **Maze size.** A maze of about 6×4 cells is small. The user may want it bigger, which may need a bigger map later.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 12 split into 12a to 12d, 12c's items ticked, a Built note), `README.md` (the regions), `technical-design.md` (the new files), `CLAUDE.md` (a "Map regions (Sprint 12c)" section and the changed obstacle readers), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The region placement, the maze seed and the number of extra openings are my calls above, so they can be tuned after play. The two boss questions from Sprint 11 and the Sprint 7 ring question are still unanswered.
