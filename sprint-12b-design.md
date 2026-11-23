# Sprint 12b Design: Obstacles

**Status:** Proposed.

Scope comes from `sprint-12a-design.md` (the 12b notes), `sprint-development.md` (Sprint 12) and the README (section 9). Architecture follows `CLAUDE.md`, `technical-design.md` and `sprint-0` to `sprint-12a-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The first map (12a) is four times larger and empty, so wide circling around the horde is easier than ever. This sprint adds **obstacles and narrow paths**: the player gets some open areas where circling still works, but with smaller circles than today's, plus corridors that are risky shortcuts. The goal is a map where positioning matters, not a maze.

The hard part is the enemies. Today they walk in a straight line at the player with no sense of the world. Walls would pin a whole horde against them, and a player standing behind one would be safe while shooting. So enemies must route around obstacles reliably, including into corridors and out of dead ends.

**Goals**
- Obstacles are data: rectangles and circles in `MapData`, placed by the first map's layout.
- **What obstacles block (user decision):** movement (the player's and every enemy's) and **enemy projectiles**. **Every player spell passes over them**, so no Area, no spell and no damage code changes. Ground effects (blast zones, boss slams) are unaffected.
- Enemies route around obstacles with a **flow field** (user decision, "option 2"): a coarse grid built from the obstacle shapes, swept outward from the player, which every enemy reads. No enemy gets stuck while a path to the player exists, in open ground, around pillars, through corridors and out of dead ends.
- A first-map layout with an open central area, small-loop pillar clusters and a few narrow paths, drawn with a TEMPORARY look.
- The F7 overlay also draws the obstacle shapes, the blocked cells and the flow field around the player, so the layout and the routing can be seen while tuning.
- Frame rate holds: 60 fps at 300 enemies with the obstacles in, measured by the stress scene.

**Non-goals (later sprints)**
- Blocking the player's spells, including the Missile (the user decided against it; revisit only if asked), and cover from player spells.
- Moving, destructible or timed obstacles, one-way gaps, and per-enemy-size fields (see risks).
- Chests, shrines, the merchant and rare scroll spots (12c), final obstacle art (Sprint 13), and more than one shipped map.

**Anti-goals** (a failure even if it technically works)
- An enemy that stands pushing against a wall while a route to the player exists (the "park behind a wall" exploit), or an enemy inside an obstacle.
- Code that branches on an enemy name, a map id or an obstacle kind to decide behaviour. The Areas and `DamageSystem` stay untouched.
- A Lectern, the player start or a spawn point that is inside an obstacle or cannot be reached.
- A field rebuild that causes a visible frame spike, or per-enemy checks against every obstacle every frame.
- Tests that touch the real save, or depend on an unseeded random roll.

## 2. Decisions

| Area | Decision |
|---|---|
| Obstacle data | `MapObstacle` (Resource): `kind` (RECT or CIRCLE), `position` (the centre), `size` (`Vector2`, the full width and height, used by RECT) and `radius` (used by CIRCLE). `MapData` gains `obstacles: Array[MapObstacle]`. `MapData.problems()` also reports an obstacle with a non-positive size, an obstacle outside the map, an obstacle that overlaps the player start or a placement (with a clearance margin), and a placement that cannot be reached from the player start. |
| Obstacle map | `ObstacleMap` (a node, child of `GameMap`, in the group `obstacle_map`) is built from the `MapData`. It owns the blocked-cell grid and the flow field, and answers: `direction_from(point)` (the way toward the player), `is_blocked(point)`, `blocks_segment(from, to)` (exact against the shapes, for projectiles) and `push_out(point)` (the nearest free point). With no `ObstacleMap` in the tree every caller falls back to today's behaviour, so tests that don't build a map keep working. |
| Grid (my call, tune by measuring) | 16 px cells (about 120 by 68 on the first map). A cell is blocked if an obstacle, grown by a body clearance of 8 px (half of the 12 px body plus 2), touches it. Both numbers are `MapData` exports, not constants in code. |
| Flow field | `FlowField` (`RefCounted`): a breadth-first sweep outward from the player's cell over the free cells, storing for each cell the direction to its best neighbour (no cutting across blocked corners). Rebuilt when the player enters a new cell and at most every 0.2 s (my call), using packed arrays. Cells the sweep cannot reach have no direction, and enemies there fall back to a straight line. Enemies in open ground must not move in visible grid steps (the builder picks interpolation or a blend, and a test proves it). |
| Enemy movement | `Enemy.direction_to_target()` asks the cached `ObstacleMap` for the direction (still aiming at the player plus the horde-spreading offset). Every brain that uses it (Chase, Ranged's approach, Exploder's rush, Support) gets the routing with no brain edited. After moving, an enemy whose new position is in a blocked cell is moved out of it (axes tried separately first, then `push_out`), which also handles knockback into a wall. |
| Ranged retreat (my call) | A Ranged enemy backing away stops at an obstacle instead of routing around it. It still fires. |
| Boss (my call) | The boss walks with the same field. Its Charge dash stops at the first obstacle in its path, with no extra stun, and its vulnerability window still opens. The boss is bigger than the grid's clearance assumes (about 36 px), so it can graze walls in narrow corridors, which is cosmetic. The layout keeps its corridors at least 48 px wide. |
| Enemy projectiles | `EnemyProjectile` frees itself when the step it just took crosses an obstacle (`blocks_segment`), before its hit can land. Its cap, range and one-hit rules are unchanged. |
| Player collision | `GameMap` builds a `StaticBody2D` on the world layer for each obstacle (a `RectangleShape2D` or `CircleShape2D`), so the player's existing `CharacterBody2D` collides with the same shapes the grid is built from. |
| Spawning | `EnemySpawner.spawn_position` rejects a point in a blocked cell (it already retries angles). Swarmer cluster members and boss summons are moved out of a blocked cell. The layout keeps the outer 48 px band free of obstacles so the ring always has room. |
| Visuals (TEMPORARY, my call) | One `ObstacleLayer` node draws every obstacle in a single `_draw` (grey fill, darker outline), above the floor and below entities, with `mouse_filter` ignoring touches. |
| First-map layout (my call, tuned by play) | About 25 to 35 obstacles: an open central area around the start, large enough for loops but not for map-wide ones; four to six solid pillar clusters (small loops); three or four wall runs forming corridors at least 48 px wide; each Lectern reachable by at least two routes. Exact coordinates are the builder's, judged by the F7 overlay and the tests below, then tuned by the user in play. |
| Stress | The stress scene gets `--obstacles`, which builds the first map's `ObstacleMap` into it, so the 60 fps target is measured with 300 enemies routing around obstacles. |

## 3. Approaches considered

1. **Slide along the edge.** The least code, but enemies get stuck in any concave shape and behind long walls, which is the exploit, and corridors would not work. It would limit the map to small convex obstacles.
2. **A flow field (chosen by the user).** One sweep per player move, one array read per enemy. It handles corridors, dead ends and pillar clusters correctly and is built from the same map data. The cost is the grid's resolution (big enemies can squeeze through gaps they would not fit) and a sweep that must be fast.
3. **Godot's `NavigationAgent2D`.** Built in, but meant for tens of agents and not 300, needs a baked mesh, and does not suit the light `Node2D` enemies.

## 4. Risks for the builder

- **Sweep cost.** A breadth-first sweep over about 8,000 cells in GDScript runs in a few milliseconds, so it must use packed arrays and run at most every 0.2 s, and it must not cause a frame spike. Measure it. Spreading one sweep over several frames is an acceptable fix if it spikes.
- **Open-ground movement.** A grid field gives eight directions. Enemies far from any obstacle must still move toward the player naturally, with no oscillation at the edge of any blend.
- **The exploit.** A test builds a U-shaped dead end with the player inside it and an enemy outside, and proves the enemy reaches the player.
- **Reachability.** A map must be rejected (reported by `problems()`) when a Lectern or the start is unreachable or inside an obstacle. The first map is tested for it.
- **Everything that moves an enemy.** Knockback, the horde offset, Swarmer clusters, the Exploder rush and the Support's slow walk all go through the same position update, so the blocked-cell rule goes there once.
- **Pickups.** Drops land where an enemy died, which is never inside an obstacle, so the player's pickup radius reaches them. A test or a check must confirm that nothing can land unreachable.
- **Size.** Tanks, elites and the boss are bigger than the grid's body clearance, so they may overlap a wall slightly in a corridor. The layout's 48 px minimum keeps that small. A per-size field is a later sprint if it looks bad.
- **Pause.** The field and the player-cell timer must freeze while the game is paused (the existing `GameTime` rules).
- **Touch.** The obstacle layer and overlay are world nodes and must ignore the mouse. `tests/test_world_input.gd` must cover them.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 12b ticked, a Built note), `README.md` (obstacles and how enemies route), `technical-design.md` (the obstacle files), `CLAUDE.md` (an "Obstacles (Sprint 12b)" section and the changed enemy movement facts), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The Charge rule (stop at an obstacle with no stun) and the Ranged retreat rule are my calls above, so they can be changed after play. The two boss questions from Sprint 11 and the Sprint 7 ring question are still unanswered.
