# Sprint 13b Design: The World's Art

**Status:** Proposed.

Sprint 13 is split into six sprints, each leaving a playable build (user decision): **13a** the art foundation (built), **13b** the world's art (this doc), **13c** spells and equipment (spell and projectile art for all five Areas in four elements, enemy projectiles and blast zones, the target reticle, and the wizard visibly wearing the equipped robe, headwear and weapon), **13d** the interface (a font and one look for every HUD piece and screen), **13e** audio, **13f** polish (screen shake, particles, damage indicators, low-mana and level-up feedback). Scope comes from the conversation, `sprint-development.md` (Sprint 13), the README (section 10) and the code as of Sprint 13a. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The characters now look like a cartoon fantasy game, but everything they stand in front of is flat rectangles. Sprint 13b gives the world the same look: a map whose regions each feel like a place, walls you can read at a glance as "blocks enemies", an interactable Lectern and points of interest that look like what they do, and pickups that look like loot. The art keeps the 13a pipeline (text pixel grids, one palette, a tool, committed PNGs), so every piece stays replaceable.

**Goals**
- Each region of the first map looks like its place (user-agreed vision, section 2).
- Walls and obstacles of any length and size look right, and a player can tell a hedge, a brick wall and a marble column from each other.
- The Lectern, the five points of interest, scroll pickups and XP and Gold gems have sprites, with a clear "ready" and "refreshing" difference for points of interest.
- The map stays data: a new map or zone picks its look by naming it, and no code branches on a map, zone or material id.
- Gameplay does not change: collision, pathfinding, spawning, layout tests and every number stay as they are.

**Non-goals (later sprints)**
- Spell, projectile, blast zone, reticle and equipment-on-the-wizard art (13c); fonts, HUD and screen looks (13d); audio (13e); particles, shake and damage numbers (13f).
- New map layouts, new obstacles or new points of interest. This is a re-skin.
- Animated water, lighting, day and night, or weather.

**Anti-goals** (a failure even if it technically works)
- A wall whose look disagrees with its collision (a hedge that looks open, or a floor decoration that looks solid and is not).
- Decorations or tiles that hide an enemy, a pickup or a projectile, or a floor so busy that sprites stop being readable.
- A frame-rate drop that makes the 300-enemy stress run worse than 13a's by more than the cost already ruled in 13a (about 139 fps median with `--obstacles --drops`).
- A seam or visible repeat in walls and floors that makes the map look like a spreadsheet.
- Art that cannot be replaced by overwriting a PNG.

## 2. Decisions

| Area | Decision |
|---|---|
| Regions (user: "I agree with this vision") | **Plaza:** grassy courtyard, flowers, mushrooms, small stones. **Mazes:** hedge walls on a stone-path floor (a garden labyrinth). **Island:** a ruined stone tower platform, brick walls, a darker floor. **Corridor:** a torch-lit stone hall. **Pillar groves:** broken marble columns and trees. |
| How it is drawn (user: option 2) | Texture fills on the existing shapes, not a tilemap and not one big image. Each zone fills its area with a tiled floor texture. Each wall rectangle is a 9-slice of its material texture (a 16 px wall is a cap, a tiled middle and a cap; a thicker block uses all nine parts). Each circle is a round sprite (a column or a tree). Decorations are scattered sprites. All stay drawn in chunks, so off-screen ones cost nothing. |
| Data | `MapObstacle` gains `material` (a name such as `hedge`, `brick`, `marble`, `tree`). `MapZone` gains `floor_style` (a name such as `grass`, `path`, `ruin`, `hall`) and `decoration_styles` (names, in place of or beside `decoration_colors`). The names resolve to sprites by the 13a naming rule (`tile_<name>`, `wall_<name>`, `decor_<name>`), through `SpriteLibrary`. A material or style with no art falls back to today's flat colour, so a gap never hides or breaks anything. |
| Mazes | `MapMaze` gets a `material` (hedge) that it stamps on every wall it generates. The merged wall rectangles stay as they are. |
| Pipeline additions (my call) | A `tile` line in a `.sprite` marks a full-bleed repeating tile or 9-slice: it skips the 1 px margin rule and the silhouette, and its edges must match for tiling (a test checks that a tile's left and right columns, and top and bottom rows, can sit side by side). Everything else (palette, `hand_drawn`, tests, committed PNGs) is as in 13a. |
| Lectern and points of interest | Sprites replace the `ColorRect` stacks. A Lectern has a gentle two-frame glow. Each point of interest has a ready look and a refreshing look (dimmed, with its existing ring), and keeps its prompt and behaviour. Health Shrine red and gold, Mana Shrine blue, Chest brown with a gold latch, Rare scroll spot a pedestal with a floating scroll, Merchant a small stall with a striped awning. |
| Pickups | Scrolls keep their shapes by category (round Base, square Area, diamond Buff) and rarity colours, now as small sprites with a one-frame sparkle for Rare. XP gems and Gold coins get two or three frame sparkle animations. The 100 and 150 pickup caps and merging rules do not change. |
| Floor decorations (my call) | Replace the flat 2 to 5 px squares with 4 to 8 px sprites: flowers, mushrooms, pebbles, cracked flagstones, grass tufts, per zone. Still seeded and deterministic, still clear of the player start, placements and every solid shape. |
| Performance (my call) | Few textures, many uses: one texture per material and floor style, so draw batches stay large (13a found that 300 sprites from about 35 sheets cost about 30% of the frame rate). Measure the stress run with `--obstacles` before and after, and if walls cost much, merge each zone's floor and each material's walls into a baked texture at load. |
| Tests (my call) | The 13a asset test covers every new source. New tests: a tile and 9-slice tile seamlessly, every material and style named in `first_map.tres` has art, a missing one falls back to a flat colour without error, an obstacle's look never changes its shape or the layout tests, and the drawn layers still skip off-screen chunks. |

### Revision during the build (user feedback after seeing the floors)

The first floors and decorations were low-contrast and detailed. The user asked for a **simpler, brighter, more cartoon** look and for **natural transitions** between regions instead of hard rectangle edges. So: floor tiles use few big shapes and bright, saturated colours (the "low-contrast mid-tone" rule is dropped for floors, and readability is now kept by the tiles being flat and simple instead); decorations are fewer, bigger-shaped and bolder; and a zone's floor draws with a **ragged, organic edge** (the outer 16 px is drawn cell by cell with some cells left out, so the floor below shows through), with the flat tint under a zone hidden whenever the zone has art. The map-level floor and border stay hard-edged.

A second round of feedback (the first soft edge still read as one long straight line along the left maze, and the hedges looked like emeralds) changed three things: the soft edge is now **32 px deep and wavy** (how far the gap reaches in follows smooth noise along the edge, with jitter, so there are bays and points and no straight stretch); the hedge is a **leafy bush with no bevel** (and darker, less saturated greens); and the two **mazes are now brick** (more familiar to players), with the plaza's small walls still hedge, the island brick and the corridor stone. The brick uses a dark brown mortar.

## 3. Approaches considered

1. **A tilemap (`TileMapLayer`) with auto-tiling.** The engine's standard way, but this map is data made of arbitrary rectangles and circles, so every shape would need converting to grid tiles and keeping in sync, and circles would look blocky.
2. **Texture fills on the existing shapes (chosen by the user).** Reuses the Sprint 12 obstacle and decoration drawing, so physics, pathfinding and the layout tests do not change, and any wall length looks right.
3. **One large composed background image.** Best looking, but it breaks "map as data", cannot be replaced piece by piece, and is heavy on the web build.

## 4. Risks for the builder

- **The 13a pipeline assumes characters.** Its test demands a 1 px transparent margin and every sprite gets a silhouette. Tiles need the `tile` marker (section 2), and the margin and silhouette rules must skip them without weakening them for everything else.
- **Seams.** A 9-slice or tiled texture shows seams if its edges do not match, and a 16 px wall leaves almost no middle. Design the wall pieces for a 16 px thickness first, and test the tiling.
- **Frame rate.** About 130 walls plus the floor plus decorations on screen is more draw work than rectangles. Measure; the baked-texture fallback is described above.
- **Readability.** A busy floor hides pickups and projectiles. Keep floors low-contrast and mid-tone, decorations small and sparse, and check screenshots with enemies, pickups and spell effects on the floor.
- **Fallback colours.** The fallback must still mean what it meant: walls solid, floor not.
- **Taste.** Tests cannot judge charm. The builder checks screenshots in a real window, and the user tunes the look in play.

## 5. Docs this sprint updates

`sprint-development.md` (13b's art items ticked, a Built note), `README.md` (the world's look and how to replace tiles), `technical-design.md` (new directories), `CLAUDE.md` (a "World art (Sprint 13b)" section), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The materials, tile sizes, decoration lists and exact sprite designs are my calls and can be tuned after play.
