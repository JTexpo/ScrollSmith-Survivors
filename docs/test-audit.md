# Test audit (spring cleaning, 2026-11-24)

Requested by the user: "check on all of the tests ... not sure how much they are testing vs creating bloat". **Nothing was deleted.** This is a report; every removal below is the user's call.

## What was measured (static, by script over `tests/test_*.gd`)

| Measure | Result |
|---|---|
| Files / tests | 206 files, 2471 tests (full run about 170 s headless) |
| Largest files | `test_main_progression` 65, `test_spell_loadout` 47, `test_crafting_screen` 44, `test_boss` 44, `test_enemy_spawner` 42: even spread, no giant file |
| Tests with no direct assertion (the script counts `assert_` calls in the body, so it misses helpers) | 1, a false alarm: `test_aimed_ring_rotates_with_the_aim` asserts through the `_assert_angle` helper (the count only saw direct `assert_` calls) |
| Exact duplicate bodies | 8 groups, 20 tests (below) |
| One-assert tests of 3 lines or fewer | about 280 (about 11%); 69 of them are a lone null/true/false check |
| Tests that only pin a data value from a `.tres` | about 40 (1.6%) |

## Findings

1. **Mostly behaviour tests.** The suite is spread across behaviour (casting, damage, crafting, spawner, boss, screens, saves, input) with guard tests (no cheat keys, no autoloads, no scale or rotate in effects, audio and fx isolation, the new export filter). By these measures there is no large block of redundant tests.
2. **Real duplication is small and is shared code, not shared coverage.** The 8 exact-duplicate groups are:
   - `test_starts_closed_and_hidden` in three screens, `test_it_works_while_the_tree_is_paused` in two (different subjects: keep).
   - Five "map has no problems and every placement is reachable" tests (one per map: keep), and `test_no_gap_is_narrower_than_two_cells`, `test_every_free_cell_is_reachable_from_the_start`, `test_the_same_points_of_interest_as_the_ruins`, `test_spacing_rules` repeated verbatim in `test_forest_map_layout` and `test_maze_map_layout`. These could move into `tests/map_layout_checks.gd` (it already holds shared checks) and be called per map: **same coverage, about 80 fewer lines.**
   - `test_the_summon_uses_swarmers` in the Dragon's and the Minotaur's data tests (keep, one per boss).
3. **The weakest category is "data pins"** (about 40 tests, in `test_boss`, `test_enemy_spawner`, `test_map_data`, `test_fx_touches`, `test_map_preview` ...): they assert today's authored number. When balance is tuned on purpose (the user plans this) they fail for the right reason but protect nothing. Candidates to keep: pins that encode a rule (the always-avoidable boss rules, caps). Candidates to drop: a pin whose only message is "the number is N".
4. **The 69 lone null/true/false tests** are small and cheap; most check "loads" or "exists" and are also covered by larger tests (for example `test_default_rules_loads`). Low value, low cost.
5. **No test without an assertion was found.** The one test the script flagged asserts through a helper, so it can fail (the review caught this).

## What this audit cannot tell

Whether a test would catch a bug is not visible from its text. The honest measure is **mutation testing** (break the production code, see whether any test fails); during this cleanup it was done only by hand on the new guards. Godot has no coverage tool. A sample run (for example 40 hand-picked mutations across the spell, damage, crafting, spawner and boss code) would say how much the suite protects; it costs a few hours of my time and no repo change.

## Recommendation (for the user to choose)

- **A. Do the safe one now:** move the four duplicated map-layout checks into `map_layout_checks.gd`, and leave the rest. No coverage lost.
- **B. A, plus review the 40 data pins together** and remove the ones that only restate a balance number.
- **C. A mutation sample** first, then decide with evidence.

I recommend A now and C before any larger deletion: deleting tests on text alone risks removing the ones that protect something.
