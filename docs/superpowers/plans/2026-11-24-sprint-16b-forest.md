# Sprint 16b: The Forest's Art and the Tempest Dragon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The forest shows four new enemy sprites (rats, ent, creepers, shaman), and its boss is the Tempest Dragon (Thunder) with a new "lightning strikes" attack, chosen through a per-map boss roster.

**Architecture:** `MapData.bosses` overrides the shared spawn config's roster (the spawner exposes `bosses()`); `BossAttack.Kind.LIGHTNING` places several `BlastZone`s around the player through a pure `LightningPlan`; the Dragon is `BossData`; the art is text pixel grids built by the existing art pipeline and found by the 16a `enemy_<set>_<type>` lookup.

**Tech Stack:** Godot 4.7 GDScript, GUT, the art tool (`tools/art/art_builder.gd`).

**Spec:** `sprint-16b-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After adding a `class_name`, run `godot --headless --import`; after editing a `.sprite`, run `godot --headless -s tools/art/art_builder.gd` and then `godot --headless --import`. **Never run two Godot processes at once** (a parallel run caused false failures in 16a); run the full suite alone, in the background for `task-done`.
- Everything but the art and the boss is the same on every map: no change to the spawn config, the difficulty curve, enemy stats or rewards, the Ember Titan, the ruins or the maze (the ruins and maze keep showing today's sprites through the fallback and keep the Titan). No new sound; the boss stinger, boss music and blast zone sounds are reused. No autoload.
- Art rules: one pixel size (sprites 1:1, never scaled or rotated), bright, simple, cartoon; the sizes and animations of the existing sprites (rats 10 by 10 `move` 0-1 6 fps loop, `death` 2-3 12 fps once; ent 24 by 24 `move`, `death`; creepers 14 by 14 `move`, `death`, `fuse` 4-5 10 fps loop; shaman 14 by 14 `move`, `death`, `pulse` 4-5 12 fps once; Dragon 40 by 32 `idle` 0-1 4 fps loop, `telegraph` 2-3 8 fps loop, `attack` 4-5 10 fps once, `vulnerable` 6-7 6 fps loop); ramp sprites use only ramp slots `1` to `5` and fixed letters from `art/palette.txt`; the palette limit is 64 colours (55 used); a 1 px transparent margin on every frame; no skin colours; the Dragon is fixed colours (thunder yellow, storm blue, cream, a dark plum outline), one `base` variant.
- Touch rule and UI: this sprint adds no screen; the map select's boss line must still fit its card (`test_map_select_screen` stays green).
- Tests never touch the real save or settings, and never really change scene; every test that builds a run scene sets `save_path = ""` and the pick screen's `pause_tree = false` before `add_child`.
- Rulings to ledger where they matter: Dragon numbers are starting values (the user tunes by play); the balance and order reports are reported, never asserted.

## Review Focus

- **Rosters:** a map with no `bosses` still uses the config's roster (ruins, maze, the stress scene's default, the soak driver); the forest cycles the Dragon alone; an empty roster never crashes the director; `MapEntry.boss_name()` for each map.
- **Lightning:** every strike inside the arena, the first on the player and the rest within `spread`, strikes not stacked on one spot; a warning on every strike; harmless until the fuse ends; all undetonated strikes cancelled when the boss dies or is freed; the blast zone cap (40) respected when several zones are placed; a paused game freezes them; **always avoidable** (`spread + radius < 90 * telegraph_time`, the player's base speed 90) for every lightning attack in the Dragon's data.
- **Boss rules:** the Dragon telegraphs every attack, ignores knockback, stays in the arena, takes the charge's vulnerability bonus, pays out once, and a hit that skips a phase lands in the last one reached.
- **Art:** no stale output, no pixel outside the palette, no frame touching its margin, every animation range matches the header, every colourway loads; the forest uses the new sprites for four archetypes and falls back for standard, chaser and ranged; the ruins and maze are exactly as before; no coloured square anywhere.
- **Regression:** the 16a catalog, map select and per-map tests still pass; `StressTest` and the soak driver still work.

---

### Task 1: The map's boss roster

**Files:**
- Modify: `resources/maps/map_data.gd`, `resources/maps/map_entry.gd`, `scripts/systems/enemy_spawner.gd`, `scripts/systems/run_director.gd`, `scripts/main/main.gd`, `scripts/dev/stress_test.gd`, `scripts/dev/soak_driver.gd`
- Test: `tests/test_enemy_spawner.gd`, `tests/test_run_director.gd`, `tests/test_main_map.gd`, `tests/test_map_catalog.gd`, `tests/test_map_data.gd`

**Interfaces:**
- Produces: `MapData.bosses: Array[BossData]` (`@export`, default empty); `EnemySpawner.boss_roster: Array[BossData]` (plain var, default empty) and `EnemySpawner.bosses() -> Array[BossData]` (the roster when it is not empty, else `config.bosses`, else empty); `MapEntry.boss_name() -> String` (the display name of `map.bosses[0]` when the map names any, else of `map.spawn_config.bosses[0]`, else `""`). `Main._apply_map` sets `_spawner.boss_roster = _map.map_data.bosses` whenever the map has data.

- [ ] **Step 1: Write the failing tests.** `test_map_data`: `test_a_map_names_no_bosses_by_default`. `test_enemy_spawner`: `test_bosses_is_the_configs_roster_when_the_map_names_none`, `test_bosses_is_the_maps_roster_when_it_names_some`, `test_bosses_is_empty_with_no_config_and_no_roster` (a spawner whose `config` is null must not crash). `test_run_director`: `test_the_director_spawns_from_the_spawners_roster_not_the_config` (give the spawner a `boss_roster` of one distinct `BossData` and check the spawned boss's `data`), `test_a_roster_overrides_but_the_clock_and_interval_are_unchanged` (first boss still at 300 s), `test_an_empty_roster_and_empty_config_spawn_nothing`, `test_the_map_roster_cycles` (two bosses cycle 1, 2, 1). `test_main_map`: `test_apply_map_hands_the_roster_to_the_spawner` (a duplicated map with `bosses = [x]` gives `spawner.boss_roster == [x]`; the ruins give `[]`) and `test_the_ruins_still_use_the_config_roster` (`spawner.bosses()` has the Ember Titan). `test_map_catalog`: replace `test_the_boss_name_comes_from_the_maps_spawn_config` with `test_the_boss_name_comes_from_the_maps_roster_then_the_config` (an entry with a roster shows its first boss; every shipped entry still shows "Ember Titan" at this point). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the fields and accessors; make `RunDirector.tick` read `spawner.bosses()` (keep its other guards); make `StressTest._ready` and `SoakDriver._play_round` use `bosses()`; make `Main._apply_map` set the roster. Run `godot --headless --import`, the five files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: a map can name its boss roster`.

---

### Task 2: The lightning strikes attack

**Files:**
- Create: `scripts/enemies/lightning_plan.gd`, `tests/test_lightning_plan.gd`
- Modify: `resources/bosses/boss_attack.gd`, `scripts/enemies/boss.gd`, `tests/test_boss.gd`, `tests/test_boss_data.gd`

**Interfaces:**
- Produces: `BossAttack.Kind.LIGHTNING` (appended after `SUMMON`, so saved numbers stay valid); `BossAttack.spread: float` (`@export`, default 80.0, "LIGHTNING: how far from the player the extra strikes land"); `BossAttack.escape_margin(player_speed: float) -> float` = `player_speed * telegraph_time - (spread + radius)` (positive means a player can run clear before the strikes land; meaningful for LIGHTNING). `LightningPlan` (`RefCounted`): `static func points(center: Vector2, count: int, spread: float, min_gap: float, bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]` returns `count` points: the first is `center` clamped into `bounds`; each other is the best of 20 seeded random candidates inside `bounds` and within `spread` of `center` (the one farthest from the strikes already chosen, with candidates closer than `min_gap` to any chosen strike rejected when any better one exists); a count of 0 or less gives an empty array. `Boss` keeps `_zones: Array[BlastZone]`, `lightning_zones() -> Array[BlastZone]` (the valid, undetonated ones, for tests); for a LIGHTNING attack `_begin_attack` places one zone per point (`BlastZone.place` with the attack's radius, `damage * _damage_scale` and `telegraph_time`), `_start_action` plays `attack` and calls `_finish_attack()` (the zones detonate by themselves), and `_on_died` cancels every undetonated zone.

- [ ] **Step 1: Write the failing tests.** `test_lightning_plan`: `test_the_first_point_is_the_centre`, `test_the_first_point_is_clamped_into_the_bounds`, `test_every_point_is_inside_the_bounds_and_within_the_spread` (many seeds, centres near the corners), `test_points_are_deterministic_for_a_seed`, `test_points_do_not_stack_on_one_spot` (with spread 70 and min_gap 28, 5 points have every pair at least 28 px apart in at least 95% of 200 seeds; state the exact bound you measure), `test_a_count_of_zero_or_less_gives_no_points`, `test_a_count_of_one_gives_only_the_centre`. `test_boss_data`: `test_lightning_is_a_new_attack_kind_after_summon` (`Kind.LIGHTNING == Kind.SUMMON + 1`), `test_escape_margin_is_the_distance_run_minus_the_danger` (speed 90, telegraph 1.0, spread 60, radius 28 gives 2.0). `test_boss`: `test_a_lightning_attack_places_count_zones_with_the_attacks_numbers_and_the_first_on_the_player`, `test_lightning_zones_are_harmless_until_their_fuse_ends`, `test_lightning_zones_stay_where_they_were_placed_and_do_not_follow`, `test_every_lightning_zone_is_inside_the_arena`, `test_a_lightning_attack_ends_in_recover_and_the_next_attack_follows`, `test_a_boss_that_dies_cancels_every_pending_lightning_zone`, `test_lightning_respects_the_blast_zone_cap` (fill to 38 zones first, then a 7-strike attack: the group never exceeds 40), `test_lightning_scales_damage_by_the_boss_number` (a boss with damage scale 2 places zones with double damage), `test_lightning_zones_freeze_while_paused` (the tree paused: their elapsed time does not advance), `test_a_boss_can_use_lightning_in_every_phase` (an attack list with only lightning runs two phases without error). Use the existing `test_boss.gd` helpers (`_boss`, a player in the group `player`). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `LightningPlan`, the enum value and the two members of `BossAttack`, and the `Boss` changes (the Slam code path and `_zone` stay as they are). Run `godot --headless --import`, the three files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the boss lightning strikes attack`.

---

### Task 3: The Tempest Dragon's data and the forest's roster

**Files:**
- Create: `resources/bosses/tempest_dragon.tres`, `tests/test_tempest_dragon_data.gd`
- Modify: `resources/maps/forest_map.tres`, `tests/test_map_catalog.gd`, `tests/test_forest_map_layout.gd`

**Interfaces:**
- Consumes: Task 1 (`MapData.bosses`), Task 2 (`Kind.LIGHTNING`, `spread`, `escape_margin`).
- Produces: `tempest_dragon.tres` (`BossData`): `id = &"tempest_dragon"`, `display_name = "Tempest Dragon"`, `element = 1` (Thunder), `max_health = 1500.0`, `contact_damage = 20.0`, `speed = 36.0`, `body_scale = 3.0`, a thunder `color` for the no-art fallback, the Titan's `reward_xp = 300`, `reward_gold = 150`, `reward_scroll_count = 2` and the same `reward_drop_table` (`boss_scrolls.tres`). Three phases (starting values, all `BossAttack`s with `telegraph_time` of at least 0.6): phase 1 (`health_threshold` 1.0, `attack_interval` 2.4, `speed_multiplier` 1.0): lightning (count 3, spread 60, radius 28, damage 22, telegraph 1.3), charge (telegraph 0.8, damage 25, dash_speed 280, dash_time 0.6, recover 1.8, vulnerability 0.5), summon (4 Swarmers, telegraph 0.8). Phase 2 (0.6, 1.6, 1.2): lightning (5, spread 70, radius 28, damage 22, telegraph 1.2), burst (count 8, damage 12, speed 120, range 260, telegraph 0.6), charge as phase 1, summon as phase 1. Phase 3 (0.25, 1.1, 1.4): lightning (7, spread 76, radius 26, damage 22, telegraph 1.2), burst (count 12, otherwise phase 2's), charge (dash_speed 320, recover 1.5, otherwise phase 1's). `forest_map.tres` gets `bosses = [tempest_dragon]`.

- [ ] **Step 1: Write the failing tests** (`test_tempest_dragon_data`): `test_the_dragon_matches_the_spec` (the identity and numbers above), `test_it_has_the_titans_health_rewards_and_table` (compare against `ember_titan.tres`), `test_it_is_thunder`, `test_three_phases_fall_in_threshold_order_and_speed_up` (thresholds 1.0, 0.6, 0.25; intervals strictly falling; speed multipliers rising), `test_every_phase_has_attacks_and_every_attack_has_a_warning`, `test_each_phase_has_a_lightning_attack_and_the_strikes_grow` (counts 3, 5, 7), **`test_every_lightning_attack_can_be_outrun_at_the_players_base_speed`** (read the speed from `res://scenes/player/player.tscn`'s `MoveComponent` `speed`, 90; `escape_margin(speed) > 0` for every lightning attack in every phase), `test_the_summon_uses_swarmers`, `test_a_hit_that_skips_a_phase_lands_in_the_last_one` (the Titan's test applied to the Dragon). `test_map_catalog`: `test_the_forest_names_the_dragon_and_the_others_keep_the_titan` (boss names per entry: "Tempest Dragon", "Ember Titan", "Ember Titan") and keep the shared spawn config test unchanged. `test_forest_map_layout`: `test_the_forest_lists_the_dragon_as_its_boss`. Run. Expected: FAIL.
- [ ] **Step 2: Create the `.tres`** (hand-written like `ember_titan.tres`, ids for the sub-resources) and add `bosses` to `forest_map.tres` (a new ext_resource and the array line). Run `godot --headless --import`, the three files, then `test_map_select_screen` (the card still fits) and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the Tempest Dragon and the forest's boss roster`.

---

### Task 4: The four forest enemy sprites

**Files:**
- Create: `art/sprites/enemy_forest_swarmer.sprite`, `art/sprites/enemy_forest_tank.sprite`, `art/sprites/enemy_forest_exploder.sprite`, `art/sprites/enemy_forest_support.sprite`, their built `assets/sprites/*` outputs (committed), `tests/test_forest_art.gd`
- Reference: `art/sprites/enemy_swarmer.sprite`, `enemy_tank.sprite`, `enemy_exploder.sprite`, `enemy_support.sprite` (format, ramp slots, headers), `art/palette.txt`

**Interfaces:**
- Consumes: the 16a lookup (`Enemy.look_sprite()`, `EnemySpawner.enemy_art_set`).
- Produces: sprites named `enemy_forest_swarmer` (a rat, 10 by 10), `enemy_forest_tank` (an ent, a walking tree-stump, 24 by 24), `enemy_forest_exploder` (a creeper, a walking vine bomb with a lit pod, 14 by 14), `enemy_forest_support` (a shaman, a hooded leaf-and-staff healer, 14 by 14), each with the animations and frame counts in Global Constraints and one outline letter, built in the five element colourways (the ramp default).

- [ ] **Step 1: Write the failing test** (`test_forest_art`): `test_the_forest_resolves_the_four_new_sprites_in_every_colourway` (for swarmer, tank, exploder, support and each of `none fire thunder land sea`, `SpriteLibrary.find` of `enemy_forest_<type>` is not null and its frame size is the archetype's), `test_each_new_sprite_has_the_animations_of_the_sprite_it_replaces` (same animation names and frame counts as `enemy_<type>`, fps and loop flags equal), `test_the_forest_falls_back_for_standard_chaser_and_ranged` (an `Enemy` with `art_set = &"forest"` resolves `enemy_standard`, `enemy_chaser`, `enemy_ranged`), `test_an_enemy_in_the_forest_set_uses_the_new_sprite_for_four_archetypes` (build an `Enemy` of each archetype with `art_set = &"forest"`: `look_sprite()` is `enemy_forest_<type>` for the four and the plain one for the others, and `has_art()` is true), `test_the_ruins_and_maze_sets_are_unchanged` (`art_set = &"ruins"` and `&"maze"` resolve `enemy_<type>` for all seven). Run. Expected: FAIL.
- [ ] **Step 2: Author the four `.sprite` files** (grids of letters, ramp slots `1` to `5` for the colourway, `K` or the existing outline letter for the outline, a transparent 1 px margin, frames for each animation in the order the header names; move frames must differ so it walks, the creeper's `fuse` frames show the pod flashing, the shaman's `pulse` frames a leaf burst, death frames shrink or scatter). Match the look of `enemy_*.sprite`: bright, simple, cartoon. Run `godot --headless -s tools/art/art_builder.gd`, `godot --headless --import`, then `test_forest_art`, `test_art_assets` (stale output, palette, margins, orphans) and `test_enemy_art`. Expected: PASS.
- [ ] **Step 3: Look at them.** In a throwaway scratchpad script (windowed, `HOME` pointed at a scratch folder) draw each new sprite's frames in all five colourways at 4x on a grass-coloured background, save a PNG to the scratchpad and read it; redraw any frame that reads badly (ent should read as a tree-stump creature, creeper as a vine bomb, shaman as a hooded healer, rat as a rat), then rebuild and re-run the tests. Record in the ledger what the image showed.
- [ ] **Step 4: Run the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: forest enemy sprites (rats, ent, creepers, shaman)`.

---

### Task 5: The Tempest Dragon's art

**Files:**
- Create: `art/sprites/boss_tempest_dragon.sprite`, its built outputs (committed)
- Modify: `art/palette.txt` (only if a new fixed colour is needed), `tests/test_boss_art.gd`
- Reference: `art/sprites/boss_ember_titan.sprite`

**Interfaces:**
- Produces: `boss_tempest_dragon` (40 by 32, fixed colours, one `base` variant, built from its text source by the tool) with `idle` 0-1 (4 fps, loop), `telegraph` 2-3 (8, loop), `attack` 4-5 (10, once), `vulnerable` 6-7 (6, loop): a stocky cartoon thunder dragon, yellow belly and lightning-bolt spikes on storm blue, cream teeth and eyes, a dark plum outline, wings out wide; `telegraph` shows it rearing with crackling bolts, `attack` a flash, `vulnerable` dazed with stars.

- [ ] **Step 1: Write the failing tests** (`test_boss_art`): `test_the_dragon_has_art_and_idles` (a `Boss` set up with `tempest_dragon.tres` shows a sprite, not the square, and plays `idle`), `test_the_dragons_animations_exist_with_the_planned_frames` (the four names and ranges above), `test_the_dragon_is_one_to_one_at_boss_scale_three` (the sprite's effective scale is 1), `test_a_lightning_warning_plays_telegraph_and_returns_to_idle` (a Dragon whose attack list is only lightning), `test_the_dragon_uses_only_palette_colours` (covered by `test_art_assets`; assert here that the palette still has at most 64 colours). Run. Expected: FAIL.
- [ ] **Step 2: Author the sprite** (plus any new palette letters, kept within 64 colours), run `godot --headless -s tools/art/art_builder.gd`, `godot --headless --import`, then `test_boss_art`, `test_art_assets`. Expected: PASS.
- [ ] **Step 3: Look at it** as in Task 4 (all eight frames at 4x on the forest's grass colour, and in a window next to the Ember Titan to compare size and silhouette); redraw what reads badly and rebuild. Record what the image showed.
- [ ] **Step 4: Run the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: Tempest Dragon art`.

---

### Task 6: The fight, the checks and the docs

**Files:**
- Modify: `CLAUDE.md`, `development-log.md`, `sprint-development.md`, `sprint-16b-design.md` (status line), `docs/release-planning/future-roadmap.md` only if something new is found
- Create (scratchpad only): the boss-fight bot, the screenshot scripts

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: A boss fight run (test).** `tests/test_tempest_dragon_fight.gd`: `test_the_dragon_fight_runs_every_attack_and_dies_once` (a `Main` on `main_forest.tscn` with `save_path = ""`; spawn the Dragon through the spawner, step it through all three phases by damaging it, check that `attack_started` fired for lightning, charge, burst and summon, no error was raised, the blast zone group never exceeded 40, and `boss_died` came once), `test_the_director_spawns_the_dragon_on_the_forest_and_the_titan_elsewhere` (`RunDirector.tick(300)` on `main_forest.tscn` and `main.tscn`), `test_the_dragons_rewards_drop_once_where_it_died`. Run. Expected: FAIL first only if a step is missing; then PASS.
- [ ] **Step 2: Real-window check.** Throwaway scratchpad scripts (windowed, a scratch `HOME`): an enemy sheet of the four new sprites in a forest fight (a real run on `main_forest.tscn` with a crowd), the Dragon's four poses, a lightning warning with its strike circles, and the map select with the forest card reading "Boss: Tempest Dragon"; read each image, fix what looks wrong with a test first where it is a bug. If the forest looks bare, say so in the final message (do not add art).
- [ ] **Step 3: Balance report (not asserted).** A scratchpad bot (kiting: casts at the nearest enemy, flees within 150 px, as in the 16a order check, adapted to spawn the boss first and run to its death or 120 simulated seconds) fights the Ember Titan on the ruins and the Dragon on the forest over two seeds each; report time to defeat (or survival), damage taken and kills in the ledger and the dev log. Repeat the 16a order check for the three maps with the Dragon now on the forest. No number is changed.
- [ ] **Step 4: Performance.** Plugged in if possible, otherwise interleaved and noted: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --obstacles --drops --boss --map=forest` against `--map=first_map`, three runs each; ledger the medians and the Low Power Mode caveat.
- [ ] **Step 5: Docs.** `CLAUDE.md`: a new "The forest's art and the Tempest Dragon (Sprint 16b)" section (the roster override and `bosses()`, the lightning attack and its avoidable rule, `LightningPlan`, the Dragon's numbers and phases, the four sprites and the fallback for the other three, the findings of the checks) and update the Project State line and the Enemies and bosses bullet that says the roster comes from the spawn config; `development-log.md` entry with the measurements; `sprint-development.md` marks 16b done; the design doc's status becomes "Implemented" with any deviations named.
- [ ] **Step 6: Full suite and smoke run.** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` and `godot --headless --quit-after 60`. Expected: all green; the only warning is the known home-scene exit leak.
- [ ] **Step 7: Commit** `feat: Tempest Dragon fight checks and Sprint 16b docs`.
