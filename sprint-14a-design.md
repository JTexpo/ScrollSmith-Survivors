# Sprint 14a Design: The world pass

**Status:** Built (Sprint 14a).

Sprint 14 is three parts, split at the user's request: **14a** the world pass (this doc), **14b** balance, **14c** optimization. Scope comes from the user's play-test notes after Sprint 13, `CLAUDE.md` (World and maps, Obstacles, Map regions, Points of interest) and `sprint-development.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

After playing the finished first map, the user found two things wrong: **the points of interest are close together and could be placed more thoughtfully** (the Rare scroll spots excepted), and **the bottom-left of the map is bare**. Their model is the map's best spots: the Rare scrolls in the maze centres, the Health Shrine in the long corridor and the Mana Shrine behind the island's gates. In the user's words, points of interest "are most interesting when there's some struggle to get to them", and players "should be incentivized to discover the map and feel challenged when going to a point of interest". The Lecterns are also "very close to one another and exposed in the open".

14a moves things on the first map only. It changes where things are and what stands round them, never how they work.

**Goals (user decisions)**
- **Spread the points of interest evenly** across the map, one per region, so every direction is worth walking.
- **Every point of interest and every Lectern has something to get through**, the way the corridor, the island and the mazes already do. This includes the merchant.
- **Fill the bare bottom-left** (with trees and a chest).
- **Keep the Rare scroll spots, the Health Shrine and the Mana Shrine where they are.**

**My calls**
- The new guards are **rings** (trees or a hedge round a clearing with one gap), built from the obstacle shapes the map format already has. No new generator.
- The chest moves out of the island (the Mana Shrine stays there alone), and the merchant leaves the Health Shrine's side.
- Gaps are 80 px (a 16 px wall and the 8 px body clearance still leave a path two cells wide), the same as the island's gates.

**Non-goals**
- Any change to how a point of interest, the Lectern, the merchant or an obstacle behaves, to the spawner, or to the balance of any reward (14b).
- New maps and bosses (a later sprint: an open field with the Tempest Dragon and a full maze with the Dire Minotaur).
- New art. Rings use the tree, hedge and stone sprites that exist.
- Optimization (14c).

**Anti-goals** (a failure even if it technically works)
- A point of interest or Lectern that can't be reached, or one a ring traps the player inside.
- A ring so tight that a crowd jams in its gap, or so open that it guards nothing.
- Scattering trees as noise (the user dropped scattered decoration after play-testing): each group has a job.
- A look that clashes with the map: the same trees and stone, no new textures.
- Moving a Lectern so near the start that the first craft is free.

## 2. Approaches

- **A. Move the placements and add rings as map data.** `first_map.tres` already holds placements and obstacle shapes, and the layout tests check reachability, clearance and spacing. Fast, and every fault is caught by tests that exist. **Chosen (the only sensible way).** Cost: each ring is hand-placed, so its position is judged by eye and screenshots.
- **B. A ring generator** (a `MapRing` resource like `MapMaze`). Reusable for the later maps, but we'd build a tool for five uses and it risks over-design. Not chosen; if the later maps need rings it can be extracted then.
- **C. Only move the positions, no rings.** Smallest change, but it spreads the points without guarding them, which is the user's main ask. Not chosen.

## 3. Decisions

The map is 1920 by 1080, the start is (960, 540). The two mazes are north-west (60, 60, 720, 480) and south-east (1140, 540, 720, 480); the island is north-east, entered by gates south and west.

| Thing | Now | Proposed | What stands in the way |
|---|---|---|---|
| Rare scroll spots (2) | maze centres | **unchanged** | the mazes |
| Health Shrine | (760, 970), corridor | **unchanged** | the corridor |
| Mana Shrine | (1660, 150), island | **unchanged** | the island's two gates |
| Chest | (1480, 150), island | **(200, 940), bottom-left** | a ring of trees and hedge with one 80 px gap |
| Merchant | (620, 860), south-west | **(1250, 430), north of the plaza** | a small hedge yard with one gate |
| Lectern, north | (960, 330), open plaza | **(900, 130)**, top of the plaza | a ring with one gap |
| Lectern, east | (1700, 444), open | **same spot** | a ring with one gap |
| Lectern, west | (440, 840), south-west | **(170, 650)**, west edge | a ring with one gap |

- The six points of interest end up in six regions, each at least about 450 px from the next. The tightest pair left is the west Lectern and the bottom-left chest, about 320 px apart, in separate rings (a Lectern is not a point of interest). If it reads too close, the chest can move toward the bottom edge.
- The three Lecterns stay at least 700 px apart (the existing rule) and the nearest is about 410 px from the start.
- Ring size: a clearing about 96 px across, sized so the prompt and the object fit, built from 6 to 10 tree circles (radius 18 to 22, as the existing groves) or hedge rectangles, one gap of 80 px facing away from the nearest map edge so the player enters from open ground. The merchant's yard is a hedge rectangle about 140 by 110 with a gate in one side, because players queue to buy.
- The old south-west tree groves stay unless a ring needs their room.
- The bottom-left also gets one extra group of trees away from the chest ring, so the corner reads as a place and not as one ring in empty ground. Count and positions are the builder's, kept inside the layout tests' limits.
- `first_map.tres` is the only data file edited (plus the tests that pin old positions).

## 4. What is left to the builder
- The exact tree and hedge coordinates, kept off the 16 px grid (the layout notes in `CLAUDE.md` explain why) and clear of every wall, placement and gap by the existing margins.
- The gap direction of each ring, and whether the chest's ring is trees, hedge or both.
- Whether the merchant's yard needs a small tree or two at its gate to match the rest.
- Updating the tests that pinned the old places (`test_first_map_points_of_interest.gd`: the island points, "merchant in the open south-west and not near a Lectern", and the Lectern distance checks in `test_first_map_layout.gd`).

## 5. Verification plan
- **Layout tests** (existing, updated where they pinned old positions): the map has no problems, every free cell is reachable from the start, every point of interest and Lectern is reachable, shapes count within 50 to 220, 3 to 40% of cells blocked, no gap narrower than two cells, the outer band and the start's 150 px free.
- **New tests:** each of the nine placements is inside a ring (or its structure) whose only opening leads to open ground; the Lecterns are at least 700 px apart and each at least 400 px from the start; the six points of interest are at least 400 px apart; the chest is no longer in the island and the Mana Shrine is its only point; nothing scattered (decoration counts stay 0).
- **Real window:** a screenshot of every ring, the bottom-left corner and the whole map (`F7` overlay), and a walk with a crowd to each ring to check the gap doesn't jam enemies or the player. Whether the layout feels better is the user's call, and I say so.
- `godot --headless --import` if needed, then the full suite and a smoke run.

## 6. Revisions during the build

- The east Lectern is a hedge room (walls at x 1640 and x 1852 between the island's south wall and the maze's top wall), not a tree ring: the strip is 184 px tall and a ring left one-cell slivers.
- The north Lectern is at (1024, 144) and the merchant yard at (1210, 384) with its gate on the west side, for the same reason (lanes under 48 px). Chest and west Lectern moved by 8 px and 6 px onto cell corners.
- Four old hedge walls were removed (not two tree circles): (200, 740), (280, 740), (990, 180) and (990, 260).
- The grove is two clumps of three trees, not five single trees.
