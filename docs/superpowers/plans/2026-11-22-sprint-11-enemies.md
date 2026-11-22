# Sprint 11 Enemy Variety, Bosses and Difficulty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seven enemy archetypes that mix and match with elements, a difficulty curve that rises with run time, enemy projectiles and telegraphed blasts, and an Ember Titan boss that arrives every 5 minutes with two phases, rewards and a completed encounter, while the run continues until the player dies.

**Architecture:** An `EnemyArchetype` (the role and every stat) and an `EnemyElement` (affinity, colour, drops) are composed by an `EnemyComposer` into one cached, shared `EnemyData` per pair. Per-spawn scales (difficulty, elite) live on the `Enemy` instance, never on shared resources. `Enemy` delegates movement and special actions to a small `EnemyBrain` chosen by the archetype's behaviour kind (Chase, KeepDistance, Explode, Support). Enemy projectiles and blast zones are built once and shared by Ranged enemies, Exploders and the boss. A `DifficultyCurve` resource maps run minutes to scales, spawn rate and elite chance, and a `RunDirector` reads the pausable game clock to spawn bosses. A `Boss` scene reuses the health and hit components and runs a state machine driven by `BossData`, `BossPhase` and `BossAttack` resources.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT 9.7.1, Compatibility renderer. Existing code in `scripts/`, `scenes/`, `resources/`, `tests/`.

**Spec:** `sprint-11-design.md` (approved, with the Staff boss-damage question left at its default: not built). Also `sprint-10-design.md`, `CLAUDE.md` and `technical-design.md`.

## Global Constraints

- Commands run with the venv active. Any Python is `venv/bin/python` (never bare `python3`). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, and zsh does not word-split unquoted variables.
- Work on branch `sprint-11-enemies` (already cut from `main`, design committed). Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. New files get their `.uid` committed (`git add -A`). Use `git mv` for moves and renames.
- Delete files only by literal full path. Scratch files go in the session scratchpad (never `/tmp`). Generate `.tres` files with a throwaway `venv/bin/python` script kept in the scratchpad, not the repo.
- Typed GDScript, snake_case/PascalCase/UPPER_SNAKE_CASE, one responsibility per script, **no new autoloads**, Input Map actions only. Don't name a parameter `position` in a `Node2D` subclass, a local `owner`, or a parameter after a method of its own class. Every HUD or world `Control` that is not a button keeps `mouse_filter` IGNORE (`tests/test_world_input.gd`). In headless GUT runs pointer events never reach `_unhandled_input`, so touch behaviour is proven with a real-window script, not a headless test. There is no new interactive control this sprint.
- **No code branches on an enemy name or an element to choose behaviour, and an element never changes a stat.** Behaviour comes from `EnemyBehaviorData.kind` and its numbers. Per-spawn scales and the elite flag live on the `Enemy` instance: shared `EnemyData`, `EnemyArchetype` and `EnemyElement` resources are never edited after load.
- **Tests never touch the real save** (`user://save.json`, the user plays with it). Every test that instantiates `main.tscn` sets `main.save_path` (an empty string means "do not load or save") and the pick screen's `pause_tree` before `add_child`. Every random roll a test depends on uses a seeded generator or a forced extreme. Report any change to the real save's checksum around a full suite run and check whether it was the user's own play.
- A telegraphed attack (a blast zone, a boss slam, a charge, a burst, a summon, an Exploder's fuse) must be harmless until its warning ends, must not follow the player once placed, and must freeze while the game is paused (use `_process` and `_physics_process` deltas, never real time).
- Existing behaviour must not change where this sprint does not touch it: spells, crafting, XP, Gold, potions, equipment, saving. `DropTable.roll` at luck 0 and chance scale 1 is exactly the old roll.
- **Archetypes** (`resources/enemies/archetypes/<id>.tres`; health, speed, contact damage, scale, XP, Gold, spawn weight, unlock seconds, cluster size, drop-chance scale, shade; "shade" lightens (+) or darkens (-) the element colour so roles are told apart):

  | id | name | health | speed | damage | scale | XP | Gold | weight | unlock | cluster | drop x | shade | behaviour |
  |---|---|---|---|---|---|---|---|---|---|---|---|---|---|
  | standard | Standard | 20 | 40 | 10 | 1.0 | 5 | 1 | 4.0 | 0 | 1 | 1.0 | 0.00 | CHASE |
  | swarmer | Swarmer | 8 | 46 | 5 | 0.7 | 2 | 1 | 2.0 | 30 | 5 | 1.0 | 0.00 | CHASE |
  | chaser | Chaser | 14 | 80 | 9 | 0.9 | 5 | 1 | 2.0 | 60 | 1 | 1.0 | +0.30 | CHASE |
  | tank | Tank | 80 | 26 | 16 | 1.5 | 12 | 3 | 1.0 | 120 | 1 | 1.5 | -0.30 | CHASE |
  | ranged | Ranged | 14 | 34 | 6 | 1.0 | 7 | 2 | 1.5 | 180 | 1 | 1.0 | -0.15 | KEEP_DISTANCE |
  | exploder | Exploder | 12 | 58 | 4 | 1.0 | 6 | 1 | 1.5 | 240 | 1 | 1.0 | +0.15 | EXPLODE |
  | support | Support | 22 | 30 | 4 | 1.0 | 8 | 2 | 1.0 | 300 | 1 | 1.5 | -0.05 | SUPPORT |

  Every archetype also has `speed_variation` 0.15, `offset_radius` 24, `contact_cooldown` 1.0 and `contact_knockback` 80 (the old values), carried into the composed `EnemyData`.
- **Behaviour numbers** (`EnemyBehaviorData`): KEEP_DISTANCE `preferred_distance` 90, `shoot_interval` 2.0, `projectile_speed` 110, `projectile_damage` 8, `projectile_range` 220. EXPLODE `trigger_distance` 28, `fuse_time` 0.8, `blast_radius` 36, `blast_damage` 24. SUPPORT `support_radius` 70, `heal_per_second` 6. An Exploder that blasts dies and gives no XP, Gold or drops.
- **Elements** (`resources/enemies/elements/<id>.tres`, reusing the existing drop tables and colours):

  | id | display name | element | colour | drop table | weight |
  |---|---|---|---|---|---|
  | none | (empty) | -1 | Color(0.75, 0.75, 0.75) | `resources/drops/basic_drops.tres` | 1.0 |
  | fire | Fire | 0 | Color(1, 0.45, 0.1) | `fire_drops.tres` | 2.0 |
  | thunder | Thunder | 1 | Color(1, 0.9, 0.2) | `thunder_drops.tres` | 2.0 |
  | land | Land | 2 | Color(0.6, 0.4, 0.2) | `land_drops.tres` | 2.0 |
  | sea | Sea | 3 | Color(0.2, 0.55, 1) | `sea_drops.tres` | 2.0 |

  A composed enemy's display name is "<element> <archetype>" with no leading space for the none element, its spawn weight is the archetype's times the element's, and its colour is the element colour shaded by the archetype.
- **Elite modifier** (`resources/enemies/elite_modifier.tres`): health x3, damage x1.5, speed x1.15, size x1.4, XP and Gold x3, drop chance x2, outline colour yellow.
- **Difficulty curve** (`resources/enemies/difficulty_curve.tres`, `m` is run minutes): health x(1 + 0.12 m), damage x(1 + 0.06 m), speed x(1 + 0.02 m) capped at +25%, spawn interval 0.5 / (1 + 0.15 m) never below 0.12, max alive 150 + 20 m never above 300, elite chance 0 before 120 s then +2% a minute up to 20%, boss interval 300 s, boss health x(1 + 0.5 (n - 1)), boss damage x(1 + 0.2 (n - 1)). All are exported numbers on the resource.
- **Ember Titan** (`resources/bosses/ember_titan.tres`): Fire element, 1500 health, contact damage 20, speed 30, scale 3, colour dark red. Phase 1 (starts at health ratio 1.0): attacks SLAM, CHARGE, SUMMON in that order, interval 2.5 s, speed x1. Phase 2 (starts at ratio 0.5): SLAM, CHARGE, BURST, SUMMON, interval 1.8 s, speed x1.3. SLAM telegraph 1.0 s, radius 48, damage 30. CHARGE telegraph 0.8 s, dash speed 260 for 0.6 s, damage 25, then a 2.0 s vulnerability window of +50% damage. BURST telegraph 0.6 s, 12 projectiles, speed 100, damage 12, range 260. SUMMON telegraph 0.8 s, 4 Swarmers. Rewards: XP 300, Gold 150 (both x boss number), 2 scrolls rolled from `resources/bosses/boss_scrolls.tres` (a DropTable with chance 1.0 and the four Rare scrolls at equal weight). The first boss spawns at 300 s, each next one 300 s after the previous one spawned (it waits while one is alive), and while a boss is alive normal spawning runs at half rate.
- Caps: at most 60 live enemy projectiles and 40 live blast zones (a new one frees the oldest).
- Perf gate: `stress_test.tscn --enemies=300 --seconds=8 --drops` stays at or above 60 fps, now with every archetype unlocked and elites in the mix (the stress scene sets the clock far ahead). The Sprint 10 medians were Missile 475.1, Wave 103.6 and Zone 175.9 fps. Report the new medians.

## Review Focus

- A telegraphed attack (blast zone, slam, charge, burst, summon, Exploder fuse) is harmless until its warning ends, does not follow the player once placed, is cancelled if its owner dies during the warning, and freezes while paused. Pinned in Tasks 6, 7 and 9.
- Shared resources are never edited: two enemies of one archetype and element pair never share a scale, an elite flag or health, and the composer returns the same unchanged `EnemyData` each time. Pinned in Tasks 1, 3 and 4.
- Difficulty, unlocks and the boss timer use the pausable clock, there is never more than one boss alive, boss numbers and intervals are right, and spawning (including Swarmer clusters) never exceeds the maximum alive. Pinned in Tasks 4 and 10.
- The boss and its summons stay inside the arena, the boss ignores knockback, its vulnerability window ends on time, and phase thresholds hold even for a hit that skips a phase. Pinned in Task 9.
- Rewards: an Exploder's blast gives nothing, an elite gives x3, boss rewards scale with the boss number and drop once, and the droppers read each enemy's own values. Pinned in Tasks 3, 7 and 10.

---

### Task 1: Archetypes, elements and the composer

**Files:**
- Create: `resources/enemies/enemy_behavior_data.gd`, `resources/enemies/enemy_archetype.gd`, `resources/enemies/enemy_element.gd`, `scripts/systems/enemy_composer.gd`, the seven `resources/enemies/archetypes/*.tres`, the five `resources/enemies/elements/*.tres`, `tests/test_enemy_archetypes.gd`, `tests/test_enemy_composer.gd`
- Modify: `resources/enemies/enemy_data.gd`

**Interfaces:**
- Produces `EnemyBehaviorData` (`class_name EnemyBehaviorData extends Resource`): `enum Kind { CHASE, KEEP_DISTANCE, EXPLODE, SUPPORT }`, `@export var kind: Kind`, and the numbers from the Global Constraints as `preferred_distance`, `shoot_interval`, `projectile_speed`, `projectile_damage`, `projectile_range`, `trigger_distance`, `fuse_time`, `blast_radius`, `blast_damage`, `support_radius`, `heal_per_second` (floats, defaults as in the table).
- Produces `EnemyArchetype` (`class_name EnemyArchetype extends Resource`): `id: StringName`, `display_name: String`, `max_health`, `speed`, `contact_damage`, `body_scale`, `speed_variation`, `offset_radius`, `contact_cooldown`, `contact_knockback` (floats), `xp_reward: int`, `gold_reward: int`, `spawn_weight: float`, `unlock_seconds: float`, `cluster_size: int`, `drop_chance_scale: float`, `shade: float`, `behavior: EnemyBehaviorData`.
- Produces `EnemyElement` (`class_name EnemyElement extends Resource`): `id: StringName`, `display_name: String`, `element: int` (the `EnemyData.element` values, -1 for none), `color: Color`, `drop_table: DropTable`, `spawn_weight: float`.
- `EnemyData` gains `display_name: String = ""`, `body_scale: float = 1.0`, `drop_chance_scale: float = 1.0`, `behavior: EnemyBehaviorData` (null means chase) and `archetype_id: StringName`. Nothing else about it changes.
- Produces `EnemyComposer` (`class_name EnemyComposer extends RefCounted`, an instance with its own cache): `compose(archetype: EnemyArchetype, element: EnemyElement) -> EnemyData` returns the same `EnemyData` instance for the same pair every time, built per the Global Constraints; it never edits its inputs.

- [ ] **Step 1: Write the failing tests.** `test_enemy_archetypes.gd`: `test_archetype_table_matches_the_spec` (all seven files, every column of the table and the behaviour numbers), `test_unlock_times_and_weights`, `test_only_ranged_exploder_and_support_have_special_behaviour`, `test_ids_are_unique`. `test_enemy_archetypes.gd` also: `test_element_table_matches_the_spec` (five files, display names, element values, colours, the existing drop tables, weights), `test_every_element_has_a_drop_table`. `test_enemy_composer.gd`: `test_compose_builds_the_archetypes_stats` (health, speed, damage, scale, XP, Gold, drop scale, behaviour, cooldowns and knockback come from the archetype), `test_the_element_supplies_only_affinity_colour_and_drops` (a Thunder Tank and a Land Tank are equal in every stat and differ only in element, colour, drop table and name), `test_display_names` ("Thunder Tank", "Tank" for the none element, "Fire Swarmer"), `test_weight_is_the_product_of_both_weights`, `test_colour_is_the_element_colour_shaded_by_the_archetype` (Tank darker than Standard, Chaser lighter), `test_compose_returns_the_same_instance_for_a_pair`, `test_different_pairs_are_different_instances`, `test_compose_never_edits_its_inputs` (the archetype and element compare equal before and after), `test_all_thirty_five_pairs_compose_with_distinct_names`, `test_a_composed_enemy_can_be_set_up_on_the_enemy_scene` (instantiate `base_enemy.tscn`, `setup`, health and colour as composed).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the two files. Expected: parse errors for the missing classes.
- [ ] **Step 3: Implement** the classes and fields, then generate the twelve resources with a scratchpad script (inline sub-resources for the behaviours).
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: enemy archetypes, elements and the composer` with the trailer.

---

### Task 2: The difficulty curve and the run clock

**Files:**
- Create: `resources/enemies/difficulty_curve.gd`, `resources/enemies/difficulty_curve.tres`, `scripts/utilities/run_clock.gd`, `tests/test_difficulty_curve.gd`

**Interfaces:**
- Produces `DifficultyCurve` (`class_name DifficultyCurve extends Resource`) with the exported numbers of the Global Constraints (`health_per_minute`, `damage_per_minute`, `speed_per_minute`, `speed_cap`, `base_interval`, `interval_rate`, `min_interval`, `base_max_alive`, `max_alive_per_minute`, `max_alive_cap`, `elite_start_seconds`, `elite_per_minute`, `elite_cap`, `boss_interval_seconds`, `boss_health_per_extra`, `boss_damage_per_extra`) and, all taking run **seconds** (negative treated as 0): `health_scale(seconds) -> float`, `damage_scale(seconds)`, `speed_scale(seconds)`, `spawn_interval(seconds)`, `max_alive(seconds) -> int`, `elite_chance(seconds)`; and `boss_health_scale(boss_number: int)`, `boss_damage_scale(boss_number: int)` (number 1 gives 1.0, numbers below 1 are treated as 1); `static func default_curve() -> DifficultyCurve`.
- Produces `RunClock` (`class_name RunClock extends RefCounted`, static): `seconds() -> float` is `GameTime.now_msec() / 1000.0`, so it stands still while the game is paused and `Main` already resets `GameTime`.

- [ ] **Step 1: Write the failing tests** in `test_difficulty_curve.gd`: `test_scales_at_time_zero_are_one`, `test_health_damage_and_speed_scale_with_minutes` (at 600 s health 2.2, damage 1.6, speed 1.2), `test_speed_scale_is_capped_at_plus_25_percent` (at 3600 s it is 1.25), `test_spawn_interval_shrinks_and_has_a_floor` (0.5 at 0, 0.5 / 1.15 at 60 s, 0.12 at a huge time), `test_max_alive_grows_and_is_capped` (150 at 0, 170 at 60 s, 300 at 3600 s), `test_elite_chance_is_zero_until_120_seconds_then_rises_and_is_capped` (0 at 119, 0 at 120, 0.02 at 180, 0.2 at 3600), `test_negative_time_is_treated_as_zero`, `test_boss_scales` (number 1 gives 1.0 and 1.0, number 3 gives 2.0 and 1.4, number 0 and negatives give 1.0), `test_default_curve_loads_with_the_spec_numbers`, `test_boss_interval_is_300_seconds`. `RunClock`: `test_run_clock_follows_game_time_and_freezes_with_it` (freeze, wait a frame or two, the value stays, unfreeze, reset to zero).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_difficulty_curve`.
- [ ] **Step 3: Implement** the resource, the `.tres` and `RunClock`.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: difficulty curve and run clock` with the trailer.

---

### Task 3: Per-enemy scales, elites and rewards

**Files:**
- Create: `resources/enemies/elite_modifier.gd`, `resources/enemies/elite_modifier.tres`, `tests/test_enemy_scaling.gd`
- Modify: `scripts/entities/enemy.gd`, `scripts/systems/scroll_dropper.gd`, `scripts/progression/value_dropper.gd` (the file is `scripts/systems/value_dropper.gd`), `resources/scrolls/drop_table.gd`, `tests/test_drop_table.gd`, `tests/test_scroll_dropper.gd`, `tests/test_value_dropper.gd`

**Interfaces:**
- Produces `EliteModifier` (`class_name EliteModifier extends Resource`): `health_multiplier`, `damage_multiplier`, `speed_multiplier`, `size_multiplier`, `reward_multiplier`, `drop_chance_multiplier` (floats) and `outline_color: Color`; `static func default_modifier() -> EliteModifier` loads the `.tres` (values in the Global Constraints).
- `Enemy` gains: `var is_elite: bool`, `var gives_rewards: bool = true`, `apply_scales(health_scale: float, damage_scale: float, speed_scale: float)` (health set from `data.max_health * health_scale` and refilled, contact damage `data.contact_damage * damage_scale`, speed multiplied; callable after `setup` and once in the tree), `make_elite(modifier: EliteModifier)` (multiplies health, damage and speed again, enlarges the body by `size_multiplier`, shows an outline, remembers the reward and drop multipliers), `xp_reward() -> int`, `gold_reward() -> int`, `drop_chance_scale() -> float` (the data's own values times the elite multipliers, rounded for the integers), `display_name() -> String` ("Elite " prefix when elite). Size is applied through the enemy node's `scale` (multiplied by `data.body_scale`), so the collision shapes follow and the death shrink still works.
- `DropTable.roll(rng, luck := 0.0, chance_scale := 1.0)`: the effective drop chance is `clampf(drop_chance * chance_scale, 0.0, 1.0)`. At scale 1.0 the roll is exactly the old one.
- `ScrollDropper.on_enemy_died` rolls with `enemy.drop_chance_scale()` and does nothing when `gives_rewards` is false. `ValueDropper.on_enemy_died` uses `enemy.xp_reward()` or `enemy.gold_reward()` (by kind) and does nothing when `gives_rewards` is false.

- [ ] **Step 1: Write the failing tests.** `test_enemy_scaling.gd` (enemies composed from the Task 1 resources): `test_apply_scales_changes_health_damage_and_speed_of_that_enemy_only`, `test_two_enemies_of_one_pair_never_share_scale_health_or_elite_flag`, `test_the_shared_enemy_data_is_never_edited` (data numbers equal before and after scaling and eliting), `test_scales_of_one_change_nothing`, `test_make_elite_multiplies_stats_size_and_rewards` (a Standard elite: health 60, damage 15, speed x1.15, scale 1.4, XP 15, Gold 3, drop scale 2.0), `test_an_elite_keeps_its_archetypes_behaviour_data`, `test_elite_after_difficulty_scales_stack`, `test_body_scale_comes_from_the_archetype` (a Tank is 1.5, a Swarmer 0.7), `test_the_death_shrink_still_frees_a_scaled_enemy`, `test_display_name_of_an_elite`, `test_rewards_round_to_whole_numbers_and_never_below_one_for_a_rewarding_enemy`. `test_drop_table.gd`: `test_chance_scale_one_gives_exactly_the_old_rolls` (seeded, 200 rolls against the pre-change algorithm copy already in the file), `test_chance_scale_raises_and_lowers_the_drop_chance` (statistical with a seed), `test_chance_scale_is_clamped` (a scale of 100 on a 0.1 chance always drops, a scale of 0 or negative never does), `test_chance_scale_and_luck_work_together`. `test_scroll_dropper.gd`: `test_an_elite_uses_its_drop_chance_scale`, `test_an_enemy_that_gives_no_rewards_drops_no_scroll`. `test_value_dropper.gd`: `test_an_elite_drops_triple_xp_and_gold`, `test_an_enemy_that_gives_no_rewards_drops_nothing`, `test_the_dropper_reads_the_enemys_own_reward_not_the_datas` (existing tests keep passing).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the modifier, the `Enemy` additions, the `DropTable` and dropper changes.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: per-enemy scales, elites and rewards` with the trailer.

---

### Task 4: Spawning composed enemies over time

**Files:**
- Modify: `resources/spawning/spawn_config.gd`, `scripts/systems/enemy_spawner.gd`, `tests/test_enemy_spawner.gd`

**Interfaces:**
- Consumes: `EnemyArchetype`, `EnemyElement`, `EnemyComposer` (Task 1), `DifficultyCurve`, `RunClock` (Task 2), `EliteModifier`, `Enemy.apply_scales`/`make_elite` (Task 3).
- `SpawnConfig` gains `@export var archetypes: Array[EnemyArchetype]`, `elements: Array[EnemyElement]`, `difficulty: DifficultyCurve`, `elite_modifier: EliteModifier`. `enemy_pool` stays for now (Task 5 removes it) as a fallback: with no archetypes, spawning works exactly as before.
- `EnemySpawner` gains: `var composer := EnemyComposer.new()`; `var elapsed_override: float = -1.0` (when 0 or more it replaces the run clock, for tests and the stress scene); `var spawn_rate_scale: float = 1.0` (the interval is divided by it, so 0.5 doubles it); `elapsed_seconds() -> float`; `pick_archetype(seconds: float) -> EnemyArchetype` (only archetypes with `unlock_seconds <= seconds` and weight above 0, picked by weight, null when none); `pick_element() -> EnemyElement` (by weight, null when none); `roll_elite(seconds: float) -> bool` (never without a curve and modifier); `current_interval() -> float` and `current_max_alive() -> int` (from the curve, else the config's own); `spawn_at(position)` composes a pair, spawns `cluster_size` enemies (the first at `position`, the others within 24 px, all clamped to the arena and never past `current_max_alive()`), applies the difficulty scales for `elapsed_seconds()`, rolls elite for each, and returns the first enemy.

- [ ] **Step 1: Write the failing tests** (keep every existing spawner test passing with the pool fallback): `test_pick_archetype_only_offers_unlocked_ones` (at 0 s only Standard, at 30 s Standard and Swarmer, at 300 s all seven), `test_pick_archetype_follows_the_weights` (seeded, 4000 picks at 300 s within 10% of the weights), `test_pick_archetype_ignores_zero_weights_and_empty_slots`, `test_pick_element_follows_the_weights` (none 1 to 2 for each element), `test_pick_returns_null_without_a_pool`, `test_roll_elite_is_never_before_120_seconds` (4000 rolls at 119 s give none), `test_roll_elite_chance_rises_and_is_capped` (seeded, 4000 rolls at 3600 s near 20%), `test_a_spawned_enemy_is_a_composed_pair` (display name "<element> <archetype>" and its element and colour), `test_spawned_enemies_get_the_difficulty_scales` (at 600 s a Standard has health 44, damage 16 and speed x1.2 of its data), `test_an_elite_roll_makes_an_elite_with_its_multipliers` (force the chance with a curve whose elite cap is 1.0 and a late time), `test_a_swarmer_spawns_a_cluster_of_five_within_24_px`, `test_clusters_never_exceed_max_alive` (max alive 7 with a cluster of 5 over several spawns: never above 7), `test_alive_counts_every_cluster_member_and_falls_when_they_die`, `test_the_interval_shrinks_with_time_and_the_rate_scale_halves_it` (the tick spawns more at 600 s than at 0, and a scale of 0.5 halves the spawns over the same time), `test_max_alive_follows_the_curve`, `test_two_spawns_of_one_pair_do_not_share_state` (health and elite of one never leak into the other or into the shared data), `test_elapsed_override_replaces_the_run_clock`, `test_the_run_clock_is_used_without_an_override` (set `GameTime` through a freeze: the value stays put), `test_the_pool_fallback_still_works_without_archetypes`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_enemy_spawner`.
- [ ] **Step 3: Implement** the config fields and the spawner changes.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: the spawner composes enemies over time` with the trailer.

---

### Task 5: Switch the game to composed enemies and migrate the old files

**Files:**
- Modify: `resources/spawning/default_spawn_config.tres`, `resources/spawning/spawn_config.gd`, `scripts/systems/enemy_spawner.gd`, `scenes/enemies/base_enemy.tscn`, `scripts/dev/stress_test.gd`, `scenes/world/stress_test.tscn` (only if needed), and the tests that name the old enemy files: `tests/test_enemy.gd`, `tests/test_enemy_elements.gd`, `tests/test_enemy_spawner.gd`, `tests/test_drop_table.gd`, `tests/test_level_track.gd`, `tests/test_scroll_dropper.gd`, `tests/test_value_dropper.gd`
- Move: the five `resources/enemies/{basic,fire,thunder,land,sea}_enemy.tres` to `tests/fixtures/enemies/` with `git mv` (they stay as test fixtures: enemies with a known element and health).

**Interfaces:**
- `default_spawn_config.tres` holds the seven archetypes, the five elements, the default curve and the default elite modifier, and no `enemy_pool`.
- `SpawnConfig.enemy_pool` and the pool fallback in `EnemySpawner` (`pick_enemy_data`, the pool branch of `spawn_at`) are removed.
- `base_enemy.tscn` no longer points at an enemy file as its default data (`data` is left empty, and `Enemy` already tolerates that).
- The stress test reads its drop entries from `_spawner.config.elements[0].drop_table`, sets `_spawner.elapsed_override` to a large time so every archetype and elites appear, and keeps its options.

- [ ] **Step 1: Write the failing tests / migrate.** Move the five files first (keep the suite from loading missing paths: update each test's path to `res://tests/fixtures/enemies/<name>_enemy.tres`). In `test_enemy.gd` replace the five-enemy stats table test (it checked the old files' numbers) with nothing (Task 1 pins the new numbers) and keep the rest on the fixtures. In `test_level_track.gd` replace the XP and Gold per enemy file tests with `test_every_archetype_has_xp_and_gold_rewards` (reading the archetype files). In `test_drop_table.gd` keep the themed-drop tests on the fixtures and add `test_every_element_resource_uses_its_themed_drop_table` (the same checks through `EnemyElement`). In `test_enemy_spawner.gd` rewrite `_make_spawner` and the pool tests for archetypes and elements (Task 4's tests already cover picking, so delete the pool tests, and keep the placement, interval, max-alive and ring tests on a single Standard archetype and the none element). Add `test_the_default_spawn_config_composes_every_pair` (35 pairs), `test_the_default_config_has_no_legacy_pool`, `test_a_default_run_spawns_standard_enemies_first` (at 0 s only Standard), and `test_the_main_scene_spawns_composed_enemies` (`Main` with an empty save path: spawn one, its display name is a composed name).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files (the new tests fail, and the old paths are updated so nothing else breaks).
- [ ] **Step 3: Implement** the config switch, the removals, the scene change and the stress script change.
- [ ] **Step 4: Run to verify they pass**, then the full suite, a smoke run, and one stress run (`--enemies=300 --seconds=8 --drops`).
- [ ] **Step 5: MCP run** (`run_project`, `get_debug_output`, `stop_project`). Expected: no errors or warnings.
- [ ] **Step 6: Commit** `feat: the game spawns composed enemies` with the trailer.

---

### Task 6: Enemy projectiles and blast zones

**Files:**
- Create: `scripts/enemies/enemy_projectile.gd`, `scenes/enemies/enemy_projectile.tscn`, `scripts/enemies/blast_zone.gd`, `scenes/enemies/blast_zone.tscn`, `tests/test_enemy_projectile.gd`, `tests/test_blast_zone.gd`

**Interfaces:**
- Produces `EnemyProjectile` (`class_name EnemyProjectile extends Node2D`, group `enemy_projectiles`, TEMPORARY look): a child `HitboxComponent` named `Hitbox` on the enemy hitbox layer (one shot, no element), moved by the root. `const MAX_ALIVE := 60`; `launch(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float)`; `static func fire(parent: Node, scene: PackedScene, origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float) -> EnemyProjectile` (frees the oldest live projectile first when 60 are alive). It frees itself after travelling `max_range`, or after its hitbox has landed a hit, and a hit on the player's hurtbox works through the normal hitbox and hurtbox path. It moves in `_physics_process(delta)`.
- Produces `BlastZone` (`class_name BlastZone extends Node2D`, group `blast_zones`, TEMPORARY look): `const MAX_ALIVE := 40`; `signal detonated`; `static func place(parent: Node, scene: PackedScene, world_position: Vector2, radius: float, damage: float, fuse_time: float) -> BlastZone` (frees the oldest first at the cap); `cancel()` (frees it without detonating); `is_detonated() -> bool`. For `fuse_time` seconds (counted from `_process(delta)`) it only draws a growing warning circle. At the end it checks the player once: if the player is alive and within `radius` of the zone it calls the player's hurtbox `receive_hit(damage, global_position)`, then it flashes for 0.15 s and frees itself. It never moves, and a `fuse_time` of 0 detonates on its first process.

- [ ] **Step 1: Write the failing tests.** `test_enemy_projectile.gd`: `test_it_moves_straight_at_its_speed`, `test_it_frees_itself_after_its_range`, `test_it_hurts_the_player_once_and_frees_itself` (a Player in the tree, the real hitbox and hurtbox path, damage applied once), `test_it_passes_through_enemies_and_spells` (no collision with enemy hurtboxes), `test_a_hit_on_an_invulnerable_player_does_nothing_and_it_keeps_flying` (the hit is refused so the projectile is not spent... or documented as freed: pin whichever the hitbox does and keep it consistent with `HitboxComponent`), `test_the_cap_frees_the_oldest` (61 fired, 60 alive, the first one gone), `test_fire_adds_it_to_the_given_parent_at_the_origin`, `test_it_has_no_element`. `test_blast_zone.gd`: `test_it_is_harmless_before_the_fuse_ends` (a player inside, `_process` up to just under the fuse: no damage), `test_it_damages_a_player_inside_once_when_the_fuse_ends`, `test_it_does_not_damage_a_player_outside_the_radius`, `test_it_does_not_follow_the_player` (the player moves out during the fuse: no damage, the zone's position unchanged), `test_a_player_who_moves_in_just_before_the_end_is_hit_and_one_who_moves_out_is_not`, `test_it_never_hits_twice`, `test_a_fuse_of_zero_detonates_on_the_first_process`, `test_cancel_frees_it_without_damage_or_the_signal`, `test_detonated_is_emitted_once`, `test_a_dead_player_is_not_hit`, `test_an_invulnerable_player_takes_nothing`, `test_the_zone_frees_itself_shortly_after_detonating`, `test_the_cap_frees_the_oldest_zone`, `test_it_uses_process_deltas_not_real_time` (no damage however long the test waits in real time without stepping `_process`).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the two files.
- [ ] **Step 3: Implement** the two scripts and scenes. Hand-written `.tscn` rules from CLAUDE.md apply (`node_paths` for exported Node properties).
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: enemy projectiles and blast zones` with the trailer.

---

### Task 7: Enemy behaviours (Ranged, Exploder, Support)

**Files:**
- Create: `scripts/enemies/enemy_brain.gd`, `scripts/enemies/brain_chase.gd`, `scripts/enemies/brain_keep_distance.gd`, `scripts/enemies/brain_explode.gd`, `scripts/enemies/brain_support.gd`, `tests/test_enemy_brains.gd`
- Modify: `scripts/entities/enemy.gd`, `scenes/enemies/base_enemy.tscn` (only if a node is needed), `tests/test_enemy.gd`

**Interfaces:**
- Consumes: `EnemyBehaviorData` (Task 1), `EnemyProjectile`, `BlastZone` (Task 6), `Enemy.gives_rewards` (Task 3).
- Produces `EnemyBrain` (`class_name EnemyBrain extends RefCounted`): `step(enemy: Enemy, delta: float) -> Vector2` returns the velocity in pixels per second before knockback; `static func for_data(data: EnemyData) -> EnemyBrain` (CHASE and null data give `BrainChase`, KEEP_DISTANCE `BrainKeepDistance`, EXPLODE `BrainExplode`, SUPPORT `BrainSupport`).
- `Enemy._physics_process` becomes `velocity = brain.step(self, delta) + knockback`, the brain is created whenever data is applied, and `Enemy` joins the group `enemies` in `_ready`. New on `Enemy`: `heal(amount: float)` (the health component's heal), `is_dead() -> bool`, `explode_and_die()` (sets `gives_rewards` false and kills it through its health, emitting `died` once).
- `BrainChase`: `enemy.direction_to_target() * enemy.speed` (exactly the old movement).
- `BrainKeepDistance`: moves toward the player when farther than `preferred_distance + 8`, away when closer than `preferred_distance - 8`, otherwise stands still; every `shoot_interval` seconds (the first after half an interval) it fires an `EnemyProjectile` at the player from its position when the player is within `projectile_range`.
- `BrainExplode`: chases; when within `trigger_distance` it stops, starts a fuse (a flashing tint) and places a `BlastZone` at its position with `fuse_time`, `blast_radius` and `blast_damage` (scaled by the enemy's damage scale); when the zone detonates the enemy calls `explode_and_die()`; if the enemy dies earlier (a player's hit) the zone is cancelled and it gives its normal rewards.
- `BrainSupport`: chases, and every 0.25 s heals every other living enemy within `support_radius` by `heal_per_second * 0.25`.

- [ ] **Step 1: Write the failing tests.** `test_enemy_brains.gd` (an Enemy composed from the real archetypes, a Player in the tree, steps by calling `_physics_process`/`step` with explicit deltas): `test_chase_brain_matches_the_old_movement` (same direction and speed as before), `test_for_data_picks_the_brain_by_kind_and_defaults_to_chase`, `test_ranged_approaches_until_its_preferred_distance_and_holds`, `test_ranged_backs_away_when_the_player_is_too_close`, `test_ranged_fires_every_interval_with_the_first_after_half`, `test_ranged_does_not_fire_out_of_range`, `test_a_ranged_projectile_has_the_archetypes_speed_damage_and_range`, `test_ranged_damage_scales_with_the_difficulty_scale`, `test_exploder_chases_until_in_range_then_stops_and_fuses`, `test_exploder_is_harmless_until_the_fuse_ends` (the player within the radius takes nothing before the fuse), `test_exploder_blasts_a_player_inside_and_dies_with_no_rewards`, `test_exploder_blast_misses_a_player_who_moved_away`, `test_killing_an_exploder_during_its_fuse_cancels_the_blast_and_pays_rewards`, `test_an_exploder_never_blasts_twice`, `test_support_heals_other_enemies_in_range_over_time` (an injured enemy gains 6 a second, never above its maximum), `test_support_does_not_heal_itself_or_dead_enemies_or_far_ones`, `test_support_heals_in_quarter_second_steps`, `test_enemies_join_the_enemies_group`, `test_explode_and_die_emits_died_once`, `test_a_ranged_elite_keeps_its_behaviour`. `test_enemy.gd`: the existing behaviour tests keep passing on the fixtures.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the brains and the `Enemy` changes.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Stress** (`--enemies=300 --seconds=8`): confirm the per-enemy brain step costs nothing measurable. Expected: no worse than the Task 5 figure.
- [ ] **Step 6: Commit** `feat: Ranged, Exploder and Support enemy behaviours` with the trailer.

---

### Task 8: Boss data

**Files:**
- Create: `resources/bosses/boss_attack.gd`, `resources/bosses/boss_phase.gd`, `resources/bosses/boss_data.gd`, `resources/bosses/ember_titan.tres`, `resources/bosses/boss_scrolls.tres`, `tests/test_boss_data.gd`

**Interfaces:**
- Produces `BossAttack` (`class_name BossAttack extends Resource`): `enum Kind { SLAM, CHARGE, BURST, SUMMON }`, `kind`, `telegraph_time`, `radius`, `damage`, `dash_speed`, `dash_time`, `recover_time`, `vulnerability_bonus`, `projectile_speed`, `projectile_range` (floats), `count: int`, `summon_archetype: EnemyArchetype`.
- Produces `BossPhase` (`class_name BossPhase extends Resource`): `health_threshold: float` (the phase starts when the health ratio is at or below it), `attacks: Array[BossAttack]`, `attack_interval: float`, `speed_multiplier: float`.
- Produces `BossData` (`class_name BossData extends Resource`): `id`, `display_name`, `element: int`, `max_health`, `contact_damage`, `speed`, `body_scale`, `color`, `phases: Array[BossPhase]` (ordered from the first phase to the last, thresholds falling), `reward_xp: int`, `reward_gold: int`, `reward_scroll_count: int`, `reward_drop_table: DropTable`; `phase_index(health_ratio: float) -> int` (the last phase whose threshold is at or above the ratio; a ratio above 1 is the first phase and a ratio at or below 0 the last).
- `ember_titan.tres` holds the numbers in the Global Constraints, with the Summon attack pointing at `resources/enemies/archetypes/swarmer.tres`. `boss_scrolls.tres` is a DropTable (chance 1.0) over the four Rare scrolls at equal weight (the scrolls whose rarity is Rare).

- [ ] **Step 1: Write the failing tests** in `test_boss_data.gd`: `test_ember_titan_matches_the_spec` (every number, both phases, every attack with its numbers and order), `test_phase_thresholds_fall`, `test_phase_index_at_the_edges` (1.0 and 0.51 are phase 0, 0.5 and 0.01 are phase 1, 0.0 and negatives the last, above 1.0 phase 0), `test_a_hit_that_skips_a_phase_lands_in_the_last_one` (a boss with three phases at 1.0, 0.6 and 0.3: ratio 0.2 gives index 2), `test_phase_two_is_faster_and_attacks_sooner`, `test_every_phase_has_attacks`, `test_summon_uses_swarmers`, `test_boss_scroll_table_holds_only_rare_scrolls_and_always_drops`, `test_boss_is_fire_element`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_boss_data`.
- [ ] **Step 3: Implement** the three classes, then generate the two `.tres` files with a scratchpad script.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: boss data` with the trailer.

---

### Task 9: The boss scene and its state machine

**Files:**
- Create: `scripts/enemies/boss.gd`, `scenes/enemies/boss.tscn`, `tests/test_boss.gd`
- Modify: `resources/enemies/..` (nothing), `scripts/components/hurtbox_component.gd` (only if a hook is needed)

**Interfaces:**
- Consumes: `BossData`, `BossPhase`, `BossAttack` (Task 8), `BlastZone`, `EnemyProjectile` (Task 6), `EnemyData`/`Enemy` components.
- Produces `Boss` (`class_name Boss extends Node2D`, scene `boss.tscn` with a `Body` ColorRect, `HealthComponent`, `HurtboxComponent` (enemy hurtbox layer), `ContactHitbox` (enemy hitbox layer) and `HitFlashComponent`, and no knockback): `signal damaged(position: Vector2, amount: float, effect: int)`, `signal died(boss: Boss)`, `signal phase_changed(index: int)`, `signal summon_requested(archetype: EnemyArchetype, count: int)`; `setup(boss_data: BossData, boss_number: int, curve: DifficultyCurve, arena_bounds: Rect2, rng: RandomNumberGenerator)` (health `max_health * curve.boss_health_scale(n)`, contact damage and attack damage `* curve.boss_damage_scale(n)`, element, colour and size from the data); `enum State { IDLE, TELEGRAPH, ACT, RECOVER }`; `var state`, `var phase: int`, `var vulnerable: bool`; `is_dead() -> bool`.
- Behaviour, all in `_physics_process(delta)` (nothing runs while dead, while the tree is paused, or when no living player exists): IDLE chases the player at `speed * phase multiplier` and counts down the phase's `attack_interval`, then takes the next attack of the phase in order (round robin, restarting from the phase's first attack when the phase changes). TELEGRAPH: SLAM places a `BlastZone` at the player's position at that moment (fuse `telegraph_time`, the attack's radius and damage); CHARGE fixes the dash direction toward the player at that moment and draws a line for `telegraph_time`; BURST glows for `telegraph_time`; SUMMON flashes for `telegraph_time`. ACT: SLAM waits for its zone to detonate; CHARGE dashes along the fixed direction at `dash_speed` for `dash_time` with its contact hit raised to the attack's damage; BURST fires `count` `EnemyProjectile`s evenly around the boss (speed, range and damage from the attack); SUMMON emits `summon_requested(archetype, count)`. RECOVER lasts 0.3 s, except after a CHARGE where it lasts `recover_time` and the boss is `vulnerable` (tinted) so a hit deals its damage plus `damage * vulnerability_bonus` more, applied once through its health. The phase follows `BossData.phase_index(health ratio)` after every hit and emits `phase_changed` on a change (a hit may skip a phase). The boss is clamped to the arena bounds, ignores knockback, `damaged` reports the total damage, and on death it emits `died` once, cancels any pending blast zone, and shrinks away.

- [ ] **Step 1: Write the failing tests** (explicit `_physics_process` steps, a Player in the tree, a seeded generator; the boss data comes from `ember_titan.tres` and from small test bosses built in the test): `test_setup_scales_health_and_damage_by_boss_number`, `test_it_chases_the_player_in_idle`, `test_it_attacks_in_the_phase_order_and_repeats` (Slam, Charge, Summon, Slam...), `test_a_slam_places_a_zone_at_the_players_position_at_telegraph_start_and_it_does_not_follow` (the player walks away: the zone stays and misses), `test_the_slam_is_harmless_until_its_fuse_ends`, `test_a_charge_dashes_toward_where_the_player_was_not_where_they_are`, `test_the_charge_telegraph_is_harmless_and_the_dash_only_hurts_during_the_dash`, `test_a_charge_leaves_a_vulnerability_window_that_ends_on_time` (damage x1.5 inside, x1.0 just after 2.0 s), `test_vulnerability_applies_once_per_hit_and_is_reported_in_damaged`, `test_a_burst_fires_twelve_projectiles_evenly_around_the_boss`, `test_a_summon_emits_the_request_with_the_archetype_and_count`, `test_phase_two_starts_at_half_health_with_its_speed_and_interval_and_burst`, `test_a_hit_that_skips_a_phase_goes_to_the_last_phase_and_emits_once`, `test_the_boss_stays_inside_the_arena_even_when_charging_at_a_wall`, `test_the_boss_ignores_knockback`, `test_the_boss_does_nothing_while_the_player_is_dead_or_missing`, `test_the_boss_does_nothing_when_dead`, `test_death_emits_died_once_and_cancels_a_pending_slam`, `test_the_damage_numbers_signal_reports_position_amount_and_effect`, `test_the_boss_takes_the_element_multiplier_like_any_enemy` (Sea hits a Fire boss for 1.5x), `test_nothing_advances_without_stepping` (no real-time dependence).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then `-gselect=test_boss`.
- [ ] **Step 3: Implement** the script and the scene.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: the boss and its state machine` with the trailer.

---

### Task 10: The run director, boss spawning and rewards

**Files:**
- Create: `scripts/systems/run_director.gd`, `tests/test_run_director.gd`
- Modify: `scripts/systems/enemy_spawner.gd`, `resources/spawning/spawn_config.gd`, `resources/spawning/default_spawn_config.tres`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_enemy_spawner.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Consumes: `Boss` (Task 9), `BossData`, `DifficultyCurve`, `RunClock`, `ValueDropper.place`, `ScrollDropper.place`.
- `SpawnConfig` gains `@export var boss_scene: PackedScene` and `@export var bosses: Array[BossData]`; the default config points at `boss.tscn` and the Ember Titan.
- `EnemySpawner` gains: `signal boss_spawned(boss: Boss, number: int)`, `signal boss_died(boss: Boss, number: int)`; `var boss: Boss` (null when none); `spawn_boss(data: BossData, number: int) -> Boss` (instantiates the boss scene, sets it up with the difficulty curve and a spawn position outside the view, adds it, forwards its `damaged` to `enemy_damaged`, handles its `summon_requested` by spawning that many composed enemies of the archetype (a random element) around the boss inside the arena, and emits `boss_spawned` and later `boss_died`); a living boss does not count toward `alive`.
- Produces `RunDirector` (`class_name RunDirector extends Node`): `@export var spawner: EnemySpawner`, `var xp_dropper: ValueDropper`, `var gold_dropper: ValueDropper`, `var scroll_dropper: ScrollDropper`, `var rng`; `signal boss_spawned(boss: Boss, number: int)`, `signal boss_defeated(number: int)`; `var boss_number: int` (bosses spawned so far); `tick(seconds: float)` (called from `_process` with `RunClock.seconds()`): when no boss is alive and the clock has reached the next boss time (300 s for the first, then 300 s after the previous boss spawned) it spawns the next boss of the roster (cycling through `config.bosses`) and sets `spawner.spawn_rate_scale = 0.5`; while a boss lives nothing else spawns it; when it dies it places its rewards at the boss's position, sets `spawn_rate_scale` back to 1.0 and emits `boss_defeated`. Rewards: `reward_xp * number` and `reward_gold * number` through the XP and Gold droppers, and `reward_scroll_count` scrolls rolled from the boss's reward table placed in a small spread. `Main` adds the node, assigns the droppers and routes `boss_defeated`.

- [ ] **Step 1: Write the failing tests.** `test_run_director.gd` (`tick` called directly with explicit seconds, real droppers, a spawner on a test config): `test_no_boss_before_300_seconds`, `test_the_first_boss_spawns_at_300_seconds`, `test_only_one_boss_is_alive_at_a_time` (ticks past the interval while the first lives spawn nothing), `test_the_next_boss_is_300_seconds_after_the_previous_spawned` (kill the first at 400, the second spawns at 600, not 700), `test_a_late_kill_spawns_the_next_one_at_once` (kill at 700 when due at 600), `test_boss_numbers_increment_and_scale_health` (boss 2 has 1.5x health), `test_the_roster_cycles`, `test_normal_spawning_runs_at_half_rate_while_a_boss_lives_and_returns_to_full`, `test_rewards_are_placed_where_the_boss_died` (XP 300 and Gold 150 for boss 1, 600 and 300 for boss 2, two scrolls, all Rare), `test_rewards_drop_once` (a second `died` signal or tick adds nothing), `test_boss_defeated_is_emitted_with_the_number`, `test_the_clock_freezes_with_the_game_pause` (a frozen `GameTime` stops the boss timer through `_process`), `test_summoned_enemies_are_composed_and_inside_the_arena`, `test_summons_do_not_exceed_max_alive_but_a_summon_still_happens` (decided and pinned: summons ignore the cap but never exceed twice it), `test_a_player_death_stops_the_director_from_spawning_more`. `test_enemy_spawner.gd`: `test_spawn_boss_adds_it_outside_the_view_and_forwards_damage`, `test_a_boss_does_not_count_toward_alive`. `test_main_progression.gd`: `test_main_has_a_run_director_wired_to_the_droppers`, `test_a_boss_defeat_in_main_drops_rewards_and_keeps_the_run_going` (force `tick` at 300 s, kill it, rewards exist, the player still lives).
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the spawner additions, the director and the `Main` wiring.
- [ ] **Step 4: Run to verify they pass**, then the full suite and a smoke run.
- [ ] **Step 5: Commit** `feat: the run director spawns bosses and pays rewards` with the trailer.

---

### Task 11: Boss bar, run clock and announcements

**Files:**
- Create: `scripts/ui/boss_bar.gd`, `scenes/ui/boss_bar.tscn`, `scripts/ui/run_clock_label.gd`, `scenes/ui/run_clock_label.tscn`, `tests/test_boss_bar.gd`, `tests/test_run_clock_label.gd`
- Modify: `scripts/ui/death_screen.gd`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_death_screen.gd`, `tests/test_main_progression.gd`

**Interfaces:**
- Produces `BossBar` (`class_name BossBar extends Control`, TEMPORARY look, every control `mouse_filter` IGNORE, hidden until a boss lives): `bind(director: RunDirector)`; `show_boss(boss: Boss)` (name label and a bar that follows the boss's `health_changed`, shown at the top centre); `hide_boss()`; `ratio() -> float`; `title_text() -> String`.
- Produces `RunClockLabel` (`class_name RunClockLabel extends Label`, TEMPORARY, `mouse_filter` IGNORE): shows "M:SS" of `RunClock.seconds()`, updated about four times a second from `_process` (so it stops while paused); `clock_text() -> String`; static `format(seconds: float) -> String` ("0:00", "5:07", "12:30"; hours roll into minutes).
- `DeathScreen.set_run_summary(run_xp: int, level: int, run_gold: int = 0, seconds: float = -1.0)` adds "Survived M:SS." to the summary when `seconds` is 0 or more (the existing text is unchanged without it).
- `Main`: binds the bar to the director, shows a toast ("The Ember Titan approaches!" through `LevelToast.show_message`) on `boss_spawned`, "Boss defeated!" on `boss_defeated`, places the clock label under the Gold counter, and passes `RunClock.seconds()` to the death summary.

- [ ] **Step 1: Write the failing tests.** `test_boss_bar.gd`: `test_hidden_until_a_boss_is_shown`, `test_show_boss_names_it_and_fills_the_bar`, `test_the_bar_follows_the_bosses_health`, `test_hide_boss_hides_it`, `test_a_new_boss_replaces_the_old_binding_and_never_double_connects`, `test_every_control_ignores_the_mouse`, `test_the_bar_follows_a_boss_that_dies`. `test_run_clock_label.gd`: `test_format` (0 gives "0:00", 59 "0:59", 60 "1:00", 307 "5:07", 3600 "60:00"), `test_the_label_shows_the_run_clock`, `test_the_label_stops_while_the_clock_is_frozen`, `test_ignores_the_mouse`. `test_death_screen.gd`: `test_summary_includes_time_survived`, `test_summary_without_seconds_is_unchanged`. `test_main_progression.gd`: `test_the_boss_toast_and_bar_appear_when_a_boss_spawns`, `test_defeating_the_boss_hides_the_bar_and_shows_the_defeat_toast`, `test_the_death_summary_shows_time_survived`.
- [ ] **Step 2: Run to verify they fail.** `godot --headless --import`, then the changed files.
- [ ] **Step 3: Implement** the widgets and the wiring.
- [ ] **Step 4: Run to verify they pass**, then the full suite and `tests/test_world_input.gd`.
- [ ] **Step 5: Real-window check.** With a throwaway script in the scratchpad run in a real window (a throwaway profile, never the real save): start `Main`, force the first boss with the director, wait for its telegraphs, take a screenshot into the scratchpad and read it (the boss bar, the clock, the blast warning circle, the Ember Titan on screen), then confirm the player can die and the death summary shows the time. Delete the script afterwards and record what you saw in the ledger. If a real window cannot be driven, say so in the final message.
- [ ] **Step 6: MCP run** and a smoke run. Expected: no errors or warnings.
- [ ] **Step 7: Commit** `feat: boss bar, run clock and boss announcements` with the trailer.

---

### Task 12: Stress gate, docs and the manual check

**Files:**
- Modify: `scripts/dev/stress_test.gd`, `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `sprint-11-design.md` (Status: Built), the memory file `sprint-0-decisions.md`

- [ ] **Step 1: Stress tooling.** The stress test sets `elapsed_override` far ahead so every archetype and elites are in the mix, and gains `--boss` (spawns an Ember Titan at the start so its telegraphs, projectiles and summons are in the measurement). Measure `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --area=<missile|wave|zone>` three times each and take the median, plus a `--boss` run for Missile. Expected: at or above 60 fps. If a median is more than 10% below the Sprint 10 figure, profile before changing anything and record the finding as a ruling.
- [ ] **Step 2: Docs.** `sprint-development.md`: tick the Sprint 11 boxes (note the one boss, no Staff boss damage) and add a Built note. `README.md`: the archetype and element mixing rule, the archetype table, elites, the difficulty and unlock numbers, the Ember Titan and its attacks, boss timing and rewards. `technical-design.md`: enemy composition (archetype plus element, `EnemyComposer`, per-spawn scales on the instance). `CLAUDE.md`: an "Enemies and bosses (Sprint 11)" section (composition, no stat from elements, `EnemyBrain`, shared projectiles and blast zones and their caps, `DifficultyCurve` and `RunClock`, `RunDirector`, the boss architecture, the telegraph rules, the old five enemy files now living in `tests/fixtures/enemies/`) and fix the Sprint 4 enemy facts that no longer hold (one enemy scene is still true, but the five enemies are no longer data variants of one file each). `development-log.md`: "Sprint 11" with decisions, rulings, migration notes, limitations (one boss only, TEMPORARY looks, no art differences between archetypes beyond size and shade, balance untested in play, the Staff boss-damage question left open) and the stress table. Mark `sprint-11-design.md` Status: Built.
- [ ] **Step 3: Manual test notes** for the final message: play past 30 s, 1, 2, 3, 4 and 5 minutes and watch new archetypes appear (clusters of small Swarmers, fast Chasers, big Tanks, Rangers keeping their distance, Exploders flashing before they blast, Supports healing others), look for elites with an outline, reach 5:00 for the Ember Titan (the boss bar, its warnings, the vulnerability window after a charge, phase 2 at half health), kill it for the rewards, and confirm the next one comes 5 minutes after the first appeared.
- [ ] **Step 4: Full suite and smoke run.** Expected: all pass, no errors.
- [ ] **Step 5: Commit** `docs: Sprint 11 complete` with the trailer.
