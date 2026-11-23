# Sprint 14a: The World Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spread the first map's points of interest and Lecterns evenly and put something to get through round each one, and fill the bare bottom-left.

**Architecture:** Pure map data. `resources/maps/first_map.tres` gets moved placements and new `MapObstacle` shapes (rings of tree circles and one hedge yard). No script, scene or art changes. Tests pin the new layout; the existing layout tests (reachability, clearance, gap width, shape counts) must stay green.

**Tech Stack:** Godot 4.7 `.tres` data, GDScript tests (GUT), `venv/bin/python` for the one scripted data edit.

**Spec:** `sprint-14a-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; the Edit tool first. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file without .gd>`.
- Only `resources/maps/first_map.tres` and tests change (plus docs in Task 3). No behaviour, balance, art, scene or script change. Mana, potions, spawning untouched.
- One pixel size: trees and hedge use the existing `tree` and `hedge` obstacle materials, never scaled.
- Keep Rare scroll spots, the Health Shrine, the Mana Shrine, both mazes, the island, the corridor, the plaza and all zones exactly as they are.
- Coordinates stay off the 16 px grid on purpose (CLAUDE.md, Map regions): a bad alignment turns a 48 px corridor into one free cell.
- Decoration counts stay 0 (`test_first_map_has_no_scattered_decoration`).
- Existing layout limits stay: 50 to 220 solid shapes, 3% to 40% blocked cells, no gap narrower than two cells, outer 48 px band and 150 px round the start free, every free cell reachable, an open 10 by 10 cell square 400 px from the start, every Lectern at least 700 px from the others.
- Tests never touch the real save.

## Review Focus

- A ring that traps something: the player, a spawned enemy or a point of interest inside a closed shape (no opening, or an opening the 8 px body clearance closes). Expected: every one of the five new guards is reachable from the start and its opening is at least two grid cells wide.
- A ring that guards nothing or jams: gap wider than about 100 px reads as open ground; narrower than 64 px jams a crowd. Expected: gap about 80 px, and 11 or more of 16 rays from the centre blocked.
- Enemies spawned inside a guard. `EnemySpawner` rejects blocked ring points and pushes enemies out of obstacles, so a spawn near a ring must not end inside it unreachable. Expected: no enemy ever stands in a clearing it cannot leave.
- A moved point of interest left stale somewhere: the chest must no longer be in the island (the island's test list), the merchant must not sit near the Health Shrine, and no old tree group may overlap a new ring.
- Nearest Lectern to the start: a ring moved too close makes the first craft free. Expected: every Lectern at least 400 px from the start.

---

### Task 1: Pin the new layout in tests (RED)

**Files:**
- Create: `tests/test_first_map_world_pass.gd`
- Modify: `tests/test_first_map_points_of_interest.gd`, `tests/test_map_data.gd`

**Interfaces:**
- Consumes: `MapData` (`placements`, `solid_shapes()`, `player_start`, `problems()`), `MapObstacle.blocks_segment(from, to, grow)`, `ObstacleGrid.reachability_problems(map)`.
- Produces: the layout the data must meet. The placement positions below are the contract Task 2 builds.

Contract positions (proposed; Task 2 may shift a ring by up to 40 px if a layout test needs it, ledgered as a ruling, keeping every constraint below):

| Thing | Position |
|---|---|
| Chest | (200, 940) |
| Merchant | (1250, 430) |
| Lectern north | (900, 130) |
| Lectern east | (1700, 444) |
| Lectern west | (170, 650) |

- [ ] **Step 1: Update `tests/test_first_map_points_of_interest.gd`.** `test_the_island_points_are_inside_the_island_and_clear_of_both_gates`: iterate only `_positions("mana_shrine")` (the chest leaves the island). Replace `test_the_merchant_is_in_the_open_south_west_and_not_near_a_lectern` with `test_the_merchant_is_north_of_the_plaza_and_far_from_the_health_shrine`: `merchant.y < _map.player_start.y`, `merchant.distance_to(health_shrine) >= 450.0`, and at least 250 px from every Lectern. Keep `test_no_two_points_of_interest_are_closer_than_80_px` and `test_every_kind_appears_on_the_first_map` unchanged.
- [ ] **Step 2: Add to `tests/test_map_data.gd`** `test_first_map_lecterns_are_at_least_400_from_the_start`: every Lectern placement is at least 400 px from `map.player_start` (the existing 700 px test stays).
- [ ] **Step 3: Write `tests/test_first_map_world_pass.gd`** with a helper `_rays_blocked(point: Vector2, length: float) -> int` (16 directions at 22.5 degree steps; a ray is blocked when any shape in `_map.solid_shapes()` has `blocks_segment(point, point + dir * length, 0.0)`) and a helper `_free_ray_length(point) -> float` (the longest of 200 px that some ray reaches unblocked, tried in steps), and these tests:
  - `test_the_chest_is_in_the_bottom_left` (x < 400 and y > 800).
  - `test_the_six_points_of_interest_are_spread_out`: the six non-Rare... all points of interest (health, mana, chest, merchant, both Rare spots) at least 400 px from each other.
  - `test_the_lecterns_are_spread_and_away_from_the_start` (at least 700 apart, at least 400 from the start).
  - `test_each_new_guard_is_closed_on_all_but_one_side` for the chest, merchant and three Lecterns: `_rays_blocked(position, 100.0) >= 10` and `_rays_blocked(position, 100.0) <= 14` (it has an opening), and some ray is free to 200 px (the opening leads to open ground).
  - `test_the_map_is_still_valid_and_reachable` (`problems()` and `reachability_problems` empty).
  - `test_the_bottom_left_has_trees_beyond_the_chest_ring`: at least 4 `tree` circle obstacles with x < 600 and y > 700 that are more than 100 px from the chest, the west Lectern and every other placement.
  - `test_no_old_grove_tree_overlaps_a_new_guard`: no two obstacles' circles/rects overlap (`overlaps` through `MapObstacle.overlaps_rect(other.bounds())` for any pair that are not both maze walls), except pieces of the same guard that touch by design (the yard's walls); implement as: no CIRCLE overlaps another CIRCLE's centre-to-centre distance below `r1 + r2 - 1` unless they belong to the same ring (rings are listed by the helper `_ring_of(obstacle)` = the placement within 80 px of the obstacle centre, or none).
- [ ] **Step 4: Run** `-gselect=test_first_map_world_pass`, `-gselect=test_first_map_points_of_interest`, `-gselect=test_map_data`. Expected: the new and changed tests FAIL (positions are still the old ones); the others pass.
- [ ] **Step 5: Commit** `test: pin the Sprint 14a world pass layout`.

---

### Task 2: Move the placements and build the guards

**Files:**
- Modify: `resources/maps/first_map.tres`

**Interfaces:**
- Consumes: the Task 1 tests.
- Produces: the final first-map data.

**Geometry (exact):**

- **Tree ring** for a placement at centre `C` and gap angle `g` (degrees, Godot angles, y points down): six `tree` CIRCLE obstacles, radius 17, at `C + 62 * (cos a, sin a)` for `a = g + 67.5 + 45 * k`, `k = 0..5`. The opening faces `g` and is about 80 px wide; the clearing is about 90 px across. Gap angles (toward open ground, away from the nearest map edge): chest (200, 940): `g = -45`; west Lectern (170, 650): `g = 0`; north Lectern (900, 130): `g = 90`; east Lectern (1700, 444): `g = 180`.
- **Merchant yard** at `C = (1250, 430)`, five `hedge` RECT obstacles (centre, size): north (1250, 378) 160 by 16; west (1178, 430) 16 by 88; east (1322, 430) 16 by 88; south-left (1190, 482) 40 by 16; south-right (1310, 482) 40 by 16. The 80 px gate is in the south wall between x 1210 and x 1290.
- **Bottom-left grove:** 5 more `tree` circles (radius 18 to 22) in x 300 to 560, y 700 to 860 (the old west Lectern's area), none within 100 px of another placement or ring, kept off the 16 px grid.
- **Remove** the two old tree circles at (200, 740) and (280, 740) (they overlap the west ring).
- **Move** placements: chest to (200, 940), merchant to (1250, 430), north Lectern (id `south` in the file) to (900, 130), west Lectern (id `west`) to (170, 650). The east Lectern keeps (1700, 444). The Rare spots, Health Shrine and Mana Shrine do not change.

- [ ] **Step 1: Write a one-off script in the scratchpad** (`build_world_pass.py`, run with `venv/bin/python`, not committed) that edits `first_map.tres` as text: change the five placement positions, delete the two old grove sub-resources (find by position) and their ids in the `obstacles` array, append the new `MapObstacle` sub-resources (ids `ring_<name>_<k>`, `yard_<n>`, `grove_<n>`; `script = ExtResource("5")`, `material`, `kind`, `position`, `radius` or `size`) before the `[resource]` block, and append their `SubResource` ids to the `obstacles` array line. It computes ring positions from the formula above and prints every shape it adds. It must be idempotent (running twice changes nothing).
- [ ] **Step 2: Run it**, then `godot --headless --import`, then `-gselect=test_first_map_world_pass`, `test_first_map_points_of_interest`, `test_map_data`, `test_first_map_layout`, `test_first_map_regions`, `test_world_art`. Expected: PASS. If a layout test fails (a gap narrower than two cells, an obstacle too near a placement, reachability), nudge the offending ring by at most 40 px (or the grove trees freely), keep the constraints, re-run, and ledger the nudge as `Ruling: <ring> moved <dx,dy> — <test that failed> — <cost>`.
- [ ] **Step 3: Real-window check** with a scratchpad script (as in Sprint 13f: `save_path` empty, the pick screen's `pause_tree` false, `await process_frame` first) that opens the first map and saves screenshots of: each ring and the yard, the bottom-left corner, and the whole map with the F7 overlay (`--resolution 960x540`; the camera follows the player, so place the player at each spot). Look at them: trees match the map's, gaps read as gaps, nothing floats or overlaps. Also walk the player (and a crowd through the stress scene's `--obstacles`) into each guard through its gap and out again to confirm nothing jams.
- [ ] **Step 4: Commit** `feat: spread the points of interest and Lecterns and guard them`.

---

### Task 3: Docs and wrap-up

**Files:**
- Modify: `CLAUDE.md` (the Points of interest "Placement on the first map" line and the Map regions first-map paragraph), `sprint-development.md` (a 14a note under Sprint 14), `development-log.md`, `sprint-14a-design.md` (Status: Built, plus "Revisions during the build" for any nudge), `README.md` only if it names old positions.

- [ ] **Step 1: Update the docs** to the new layout (placement table, the ring formula, the yard, the grove, the tests that pin it) and state clearly that whether it feels better is the user's call.
- [ ] **Step 2: Run the whole suite and `godot --headless --quit-after 60`.** Expected: PASS, no new warnings; stress `--enemies=300 --seconds=8 --obstacles --drops` once, expected within noise of about 105 to 120 fps (about 30 more shapes).
- [ ] **Step 3: Commit** `docs: Sprint 14a complete`.
