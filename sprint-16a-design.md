# Sprint 16a Design: The map select, the art sets and the new layouts

**Status:** Proposed, awaiting approval.

Sprint 16 is four parts (see `sprint-development.md`): **16a** the map select, the per-map art sets and the new layouts (this doc), **16b** the forest's art and the Tempest Dragon, **16c** the ruins' art refresh, **16d** the maze's art and the Dire Minotaur. Scope comes from the Sprint 16 plan, `CLAUDE.md` (World and maps, Obstacles, Map regions, Points of interest, World pass, Front door) and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The game has one map. 16a lets the player **choose from three maps**: an **open forest** (about finding a dragon), the **ruins** of a city (today's map, unchanged) and a **minotaur's maze**. It builds the machinery (a map names its enemy art set, the map select, per-map bests) and the **forest and maze layouts**, all playable with today's art and the Ember Titan. The art and the two new bosses come in 16b to 16d.

**Goals (user decisions)**
- **Three maps, all open from the start** (unlocking by boss belongs to the achievements sprint), each **1920 by 1080** like the ruins.
- **Everything is the same on every map**: enemy types, elements, stats, spawn config, rewards, and the bosses arriving on the **300-second timer** (no lair). **The challenge is the layout**: the open forest has few places to be trapped (easiest), the ruins have walls and rooms (medium), the maze has dead ends and corridors where a player is cornered or flanked (hardest).
- **Bests are kept per map**, and the death card's **"Level reached" row and the saved best level are removed** (the level is permanent, so it always says the same thing).
- **Approach B (the user's pick): one small scene per map.** The ruins stay `main.tscn`; the forest and maze are tiny inherited scenes that differ only in the map they hold. The map select loads a different scene path, and a death restart reloads the same scene, so the same map replays with no stored state.
- **Both picks:** the map cards show the name, a one-line theme, the boss, the player's best survival on that map and a **schematic preview drawn from the map's own data**; and **Play remembers the last map** (the select screen focuses it), saved in the settings file, not the progress save.

**My calls**
- **Art sets need no renaming.** A map names its set (`forest`, `ruins`, `maze`); an enemy looks for `enemy_<set>_<type>` first and falls back to today's `enemy_<type>`. In 16a no set-specific sprite exists, so every map shows today's art; 16b to 16d add sprites that override the fallback. A missing sprite can never leave a coloured square.
- **The same points of interest on every map** (three Lecterns, two Rare scroll spots, a chest, a Mana Shrine, a Health Shrine, a merchant), placed to suit each layout, with the same spacing rules (Lecterns at least 700 px apart and 400 px from the start, points of interest at least 400 px apart).
- **Forest layout:** one open grass floor; groves of trees and a few rock clusters as light obstacles (a handful of shapes, never walls); each Lectern, the chest and the merchant inside a tree ring with one opening (the 14a ring recipe), the shrines and Rare spots in open clearings; no zones with their own floor.
- **Maze layout:** one `MapMaze` over almost the whole map (a closed boundary, `clear_center` around the start, a few extra openings so it has loops), floor and walls in the ruins' stone look; points of interest in dead ends and rooms far from the start, Lecterns in three far-apart corners; the maze is seeded, so the same walls every time.
- **The map select is a screen in `home.tscn`** like the Shop and Settings screens: three cards in a row, keyboard, controller, mouse and touch.
- **The preview is schematic**: the floor colour with solid shapes and points of interest as small rectangles and dots, drawn at 1/15 scale (128 by 72 px). It is a diagram, not art.

**Non-goals**
- Any new enemy or boss art, new bosses, new sounds (16b to 16d); per-map difficulty or reward numbers; unlocking maps; a lair; a map editor.
- Changing how the ruins play or look (the ruins' layout, id and tests are untouched).

**Anti-goals** (a failure even if it technically works)
- A map where something is unreachable, a point of interest is trapped or too close, the start is blocked, or the maze is unsolvable.
- Hidden state: the chosen map must live in the scene path, not in a static variable; a restart must never change map.
- A forest that turns out as hard as the maze or a maze that is unfair: the order is checked with a simulated run of each (reported, not fixed with per-map numbers).
- A save that loses the player's ruins records or fails to load an old save.
- A missing art set breaking an enemy.
- Performance on any map falling well below the ruins' (the maze has many wall shapes).
- A map select that cannot be used by touch, keyboard or controller.

## 2. Approaches

- **A. A static "run setup" holder.** `GameMap` builds itself before `Main` can change its map, so it would have to read the holder; hidden state; restart and tests need care. Not chosen.
- **B. One small scene per map (chosen by the user).** Inherited scenes, the scene path carries the choice, restart is free, no existing test changes.
- **C. Load the generic scene and assign the map afterwards.** Custom switch code that restart must repeat. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Map data | `MapData` gains `description` (the theme line) and `enemy_art_set` (a `StringName`, empty means none). The boss shown on a card is the first of the map's `spawn_config.bosses` (all maps share the default spawn config in 16a, so every card shows the Ember Titan until 16b and 16d), looked up by the catalog entry's map. New maps: `resources/maps/forest_map.tres` (id `forest`) and `maze_map.tres` (id `maze`); the ruins keep `first_map.tres` (id `first_map` stays, display name "The Ruins"). |
| Catalog | `MapCatalog` (`resources/maps/map_catalog.tres`) lists `MapEntry`s in order (forest, ruins, maze): the `MapData` and the run scene path (`scenes/main/main_forest.tscn`, `main.tscn`, `main_maze.tscn`). `MapCatalog.default_catalog()`, `find(id)`, `entry_for_scene(path)`. No code branches on an id. |
| Scenes | `main_forest.tscn` and `main_maze.tscn` are inherited from `main.tscn` and override only `GameMap.map_data`. Tests build `main.tscn` as before. |
| Art sets | `EnemySpawner.enemy_art_set` is set by `Main._apply_map` from the map and handed to each enemy before `setup`; `Enemy._apply_look` tries `enemy_<set>_<type>` (when the set is not empty and the sprite exists) before `enemy_<type>`. Bosses are unchanged (`boss_<id>`). No stats change. |
| Bests per map | `PlayerProfile.bests` becomes a dictionary from map id to `{"seconds": int, "enemies": int}` (helpers `best_seconds(map_id)`, `best_enemies(map_id)`); `best_level` is removed. `to_dict` writes `bests` only when any is above 0; an old save's flat `{"seconds", "enemies", "level"}` loads as the ruins' (`first_map`) bests and its `level` is ignored; each value must be a whole number from 0 to `MAX_VALUE` like any field. `RunRecords.update(profile, map_id, enemies, seconds)` compares with that map's bests (same rules: a "new best" only for a beaten non-zero best). |
| Death card | `RunRecap.rows` has eight rows (time survived, enemies defeated, bosses defeated, XP earned, Gold earned, scrolls collected, spells crafted, potions drunk) and takes the map's bests; `RunStats.level` and the level copy in `Main._on_player_died` are removed. The card's layout moves up by one row. |
| Map select | `MapSelectScreen` (a `CanvasLayer` in `home.tscn`, process Always): a card per catalog entry (a `MapPreview` control, the name as a heading, the theme line, "Boss: <name>", "Best: m:ss" or "No best yet"), Back and Play buttons; the home screen's **Play now opens it** and `HomeScreen.play_map(entry)` loads the entry's scene through `SceneSwitcher`. Touches are bridged and the viewport is captured before handling (a scene change removes the node); focus starts on the **last played map**. |
| Last map | `GameSettings.last_map` (a map id string, default the forest) is saved in `settings.json` (under a `play` object, an unknown or missing id means the default) and written when a map is chosen. |
| Preview | `MapPreview` (a `Control`, `scripts/ui/map_preview.gd`) draws the map's floor colour, every solid shape from `MapData.solid_shapes()` as a filled rectangle or circle and each placement as a dot, scaled to the card; it holds no art and never changes the map. |
| Layout data | The forest and maze are authored data like the ruins: generated once by a scratchpad script (as 14a did) into the `.tres`, then tested. The maze needs a helper on `MapMaze`: `dead_end_cells() -> Array[Vector2]` (the centres of cells with one opening, for placing points of interest). |
| Stress and tools | The stress scene takes `--map=<id>` (from the catalog) and a `--simulate` run option is not added: the order check uses the soak driver's crowd on each map and a recorded survival time of a standing player (see verification). |

## 4. What is left to the builder
- Every coordinate of the forest and maze (obstacles, points of interest, Lecterns), within the spacing and shape rules; how many trees and rocks the forest needs to feel like a forest without becoming a maze.
- The cards' exact layout and the schematic's colours; the theme lines' wording (short, in the game's tone).
- The forest's floor colour and decorations from existing styles (`grass`, `flowers`, `mushrooms`, `pebbles`); the maze's floor and walls from the ruins' (`ruin`, `stone`).
- Whether the maze needs its own seed tries until the layout tests pass (a seed is data).

## 5. Verification plan
- **Layout tests** per new map (as `test_first_map_layout`, `_regions` and `_world_pass` do for the ruins): no map problems; every free cell reachable from the start; every placement reachable and clear of shapes; outer 48 px band and 150 px around the start free; no gap narrower than two cells; spacing (points of interest 400 px apart, Lecterns 700 apart and 400 from the start); shape-count and blocked-cell limits per map (the maze allows more shapes than the ruins' 220); an open 10 by 10 cell square away from the start in the forest; for the maze, every point of interest in a dead end or room and the maze solvable from the centre to each.
- **Catalog and scenes:** each entry's scene loads and holds the entry's map; the ruins' entry is `main.tscn` and its map is unchanged; `entry_for_scene` round trips; the three scenes build a `Main` that starts a run (`save_path = ""`).
- **Art set:** an enemy with an art set that has a sprite uses it, one whose set has none falls back to `enemy_<type>`, an empty set is today's behaviour, and the look is unchanged for the ruins.
- **Bests:** per-map records, an old flat save loads as the ruins', a bad value is a bad save, a record on the forest never touches the ruins' bests, and the card shows and compares the current map's bests.
- **Death card:** eight rows fit 480 by 270; no level row anywhere (`RunStats.level` gone, tests updated).
- **Map select:** builds three cards from the catalog; focus starts on the last map; Play on a card loads its scene (a missing path returns the error); Back closes; the last map is saved and an unknown saved id gives the default; touch, mouse, keyboard and controller (focus neighbours between cards); it works from the home screen and Settings and the Tutorial still open.
- **Order check:** a headless driver (the soak driver with a standing, regenerating player and a fixed seed) runs each map for the same simulated minutes and records how long the player survives and how often they are cornered; the forest should outlast the ruins and the ruins the maze. This is reported, not asserted in the suite (it depends on timing), and if the order is wrong it is reported to the user.
- **Real window (touch rule):** screenshots of the select screen and both new maps (whole-map views and close-ups of each kind of point of interest), by touch and by mouse choose each map and play a few seconds; stress and soak on each map (`--map=`), performance recorded against the ruins'.
- `godot --headless --import` after adding a `class_name`, then the full suite and a smoke run.
