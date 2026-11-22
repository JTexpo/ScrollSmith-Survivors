# Sprint 12a Design: The World (Map as Data)

**Status:** Proposed.

Scope comes from `sprint-development.md` (Sprint 12, first third) and the README (section 9, "Map Exploration"). Architecture follows `CLAUDE.md`, `technical-design.md` and `sprint-0` to `sprint-11-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

Sprint 12 is split into three sprints, each leaving a playable build (user agreed to split, and to more than two if needed). Labels are 12a, 12b and 12c so later sprint numbers and docs do not shift.

| Sprint | Contents |
|---|---|
| **12a (this doc)** | The world: map as data, a bigger map, boundaries, placement of points of interest (Lecterns only), decorations, map-specific spawn settings, a debug overlay. |
| **12b** | Obstacles: shapes that block the player, enemies, spell shots, enemy shots and blast zones, and a layout that breaks up wide circling. |
| **12c** | Points of interest: treasure chests, Health and Mana Shrines, a merchant, rare scroll locations. |

## 1. Intent

The test arena is 960×540, two screens by two, and three Lecterns sit within a few seconds of each other. The player has no reason to leave the middle, and circling enemies in a wide loop is too strong. Sprint 12a gives the game a real map, four times the area, built from data so that more maps (and one day maps people make themselves) are a new file and not new code. It also builds the placement system 12b and 12c will use. It does **not** fix circling by itself; that is 12b's job (see risks).

**Goals**
- A `MapData` resource describes a map: size, colours, player start, spawn settings, placed points of interest and decoration scatter.
- The first playable map is **1920×1080** (user decision: "medium"), four screens by four. The Lecterns are spread far enough apart that moving between them takes real time.
- Environmental boundaries: the player cannot leave the map, the camera stops at its edge, enemies are clamped to it.
- Points of interest are **placed from data**, not hand-placed in `main.tscn`. In this sprint the only kind is the Lectern, but the mechanism takes any scene.
- Environmental decorations (look is TEMPORARY, final art is Sprint 13).
- Map-specific enemy spawn settings: a map points at its own `SpawnConfig`.
- A debug overlay (F7) draws the map's bounds and placements, so the layout can be seen while tuning, and 12b will add its obstacle shapes to it.

**Non-goals (later sprints)**
- Obstacles, narrow paths and any collision other than the outer wall (12b).
- Chests, shrines, merchant, rare scroll spots (12c).
- A second shipped map, a map editor, loading maps from files players supply, and biomes. The data shape allows them, nothing builds them.
- Tile art, final art, sound (Sprint 13).

**Anti-goals** (a failure even if it technically works)
- Code that branches on a map id or name. Everything a map differs in is data.
- A magic number for the arena size left behind in code: every place that needs the bounds reads them from the map.
- A map that can be loaded with a Lectern or the player start outside its bounds and no complaint.
- A bigger map that quietly changes balance: enemy count, spawn rate and difficulty stay exactly as in Sprint 11.
- Tests that touch the real save (the Sprint 8 rule stays).

## 2. Decisions

| Area | Decision |
|---|---|
| Map as data (user decision) | `MapData` (Resource, `resources/maps/`): `id`, `display_name`, `size` (Vector2), `floor_color`, `border_color`, `player_start`, `spawn_config` (a `SpawnConfig`, null means keep the scene's), `placements` (`Array[MapPlacement]`), `decoration_*` fields. A `bounds()` helper returns `Rect2(Vector2.ZERO, size)`. The first map is `resources/maps/first_map.tres`. |
| Placements | `MapPlacement` (Resource): `scene` (`PackedScene`) and `position`. A `GameMap` instances each one at its position. 12b and 12c add obstacles, chests and shrines as more placements or more data fields, with no change to this mechanism. |
| The map scene | `GameMap` (scene and script, `scenes/world/game_map.tscn`) takes a `MapData`, and builds the floor, the boundary walls (static bodies on the world layer, built from `size`), the placements and the decorations. It replaces `test_arena.tscn` in `main.tscn`. `test_arena.tscn` stays for the stress test. |
| Size (user decision) | 1920×1080. At the base speed of 90 px/s, crossing the map takes about 21 s (faster with speed bonuses), against about 10 s across today's arena. |
| Lecterns (my call) | Three, spread out: for example (300, 260), (1600, 300) and (960, 900), so each pair is far apart (a test enforces a minimum distance, 700 px). The player starts at the centre (960, 540). They are placed from `MapData`, not in `main.tscn`. |
| Who reads the bounds | `Main` reads the map once and gives it out: `EnemySpawner.arena_bounds`, the Player's camera limits and the player start. The spawn ring, boss arena centre and Swarmer clusters already read `arena_bounds`, so nothing else changes. The three `Rect2(0, 0, 960, 540)` defaults in `EnemySpawner`, `Enemy` and `Boss` stay as test defaults only, and `Main` always overrides them. |
| Spawn settings | `Main` assigns `map.spawn_config` to the spawner when it is not null. The first map keeps `default_spawn_config.tres`, so balance is unchanged. A second map can point at its own config. |
| Decorations (TEMPORARY look, my call) | Seeded scatter: `decoration_count`, `decoration_seed`, and a few colour or size variants. The scatter keeps a clear radius around the player start and every placement, and is deterministic for a seed. All of it is drawn by one node in a single `_draw` (like `DamageNumbers`), not hundreds of nodes. Decorations have no collision and ignore the mouse. |
| Debug overlay (my call) | `MapDebugOverlay` draws the bounds, the player start and a labelled marker per placement. F7 toggles it (`debug_toggle_map`, handled in `Main`, DEBUG, deleted when no longer needed). F7 is free: F8, F9, F10 and F12 are taken, and F11 is fullscreen in browsers. |
| Camera | The Player's `Camera2D` keeps its smoothing. Its limits are set from the map's bounds in `Main`, not hand-written in `main.tscn`. |
| Pickups | Nothing changes. The 100-scroll and 150-gem caps already bound how many pickups the larger map can hold. |

## 3. Approaches considered

1. **Map as data (chosen by the user).** A resource describes the map and one thin scene builds it. Enemies and shots will later test obstacle shapes from the same data with simple geometry, not the physics engine (12b), which suits 300 enemies that already have no physics. A new map is a new `.tres`.
2. **A hand-built scene with physics bodies.** Familiar and visible in the editor, but enemies have no physics, so respecting walls would cost about 300 physics queries a frame.
3. **A tile map painted in the editor.** Best fit for the Sprint 13 art, but it cannot be painted from here and still needs the geometry from approach 1 behind it. Tile art can go on top of approach 1 later.

## 4. Direction for 12b and 12c (notes, not decisions)

- **12b.** Obstacles are rectangles and circles in `MapData`. The player keeps physics collision (built from the shapes). Enemies, spell shots, enemy shots and blast zones test the same shapes with geometry. The user wants some open areas where circling still works, but with **smaller circles** than today's, plus narrow paths. Pillar clusters and walls give the small loops, and corridors give a risky shortcut. Enemies have no pathfinding, so the open question is how they get past an obstacle without pinning themselves in a dead end (a lean: slide along its edge, and keep obstacle shapes simple). 12b gets its own stress test, because it is the likeliest to cost frames.
- **12c.** Chests, shrines, the merchant and rare scroll spots are placements of new scenes, using `MapPlacement`.

## 5. Risks for the builder

- **Circling gets easier first.** A bigger map with nothing in it makes wide loops bigger. 12a alone worsens that. 12b should follow immediately, and the user can hold the merge of 12a until 12b is ready if they prefer.
- **Hard-coded size.** The 960 and 540 values appear in `EnemySpawner`, `Enemy`, `Boss`, `main.tscn`, `stress_test.tscn`, `test_arena.tscn` and many tests. Only `Main` and `main.tscn` move to the map. The tests keep their own explicit bounds, and the stress scene stays on its test arena so its numbers stay comparable.
- **Camera and spawn ring.** `spawn_position` already clamps the view into the arena. A test must prove the ring works at the larger bounds and near the corners.
- **Touch.** The map's floor, decorations and the overlay are world nodes and must set `mouse_filter = 2` (the existing `tests/test_world_input.gd` check must cover the new scenes).
- **Walls.** Walls are built from `size` in code, so a map of any size gets correct walls. A test checks that the player cannot pass them.
- **Performance.** The map is four times larger but the enemy count is unchanged. Check the smoke run and a stress run still match Sprint 11, since the decorations are one draw call.

## 6. Docs this sprint updates

`sprint-development.md` (Sprint 12 split into 12a, 12b and 12c with 12a ticked and a Built note), `README.md` (the map size and the placement idea), `technical-design.md` (the map data layout), `CLAUDE.md` (a "World and maps (Sprint 12a)" section and the changed facts about the arena), `development-log.md`, and the memory file.

## 7. Open questions for the user

None blocking. The two boss questions from Sprint 11 (time the next boss from the kill, and Staff boss damage) and the Sprint 7 ring question are still unanswered. They can wait until a sprint touches them.
