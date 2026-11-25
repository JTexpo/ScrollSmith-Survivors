# Test mutation report (spring cleaning 2)

A sample of deliberate breaks of production code, to see whether the tests notice. **Nothing was changed or deleted because of it**; it is evidence for a later decision.

**Method.** 37 one-line mutations across damage and elements, spells and casting, crafting and buffs, combat components, drops, the shop, potions, progression, saving, the spawner and the bosses. For each: apply it, run the (up to 3) test files that mention the mutated class most, record the first failing test, then restore the file with `git checkout` (the tree was clean afterwards). A mutation that survived those files was then run against the **whole suite** before being called uncaught.

**Result.** 37 mutations: 35 caught by at least one test, **2 survived the whole suite**.

| # | Area | Mutation | Result |
|---|---|---|---|
| 1 | damage | `damage_system.gd`: `if multiplier > best_multiplier:` → `if multiplier < best_multiplier:` | caught by `test_damage_system` (`test_passes_damage_through`) |
| 2 | damage | `damage_system.gd`: `maxf(base_damage * best_multiplier, 0.0)` → `maxf(base_damage, 0.0)` | caught by `test_damage_system` (`test_strong_element_multiplies_damage`) |
| 3 | damage | `element_table.gd`: `return Effect.VULNERABLE` → `return Effect.NEUTRAL` | caught by `test_element_table` (`test_strong_pairs`) |
| 4 | spell | `spell_instance.gd`: `return current_mana >= data.mana_cost` → `return current_mana > data.mana_cost` | caught by `test_spell_instance` (`test_depleted_spell_never_casts_and_never_regenerates`) |
| 5 | spell | `spell_instance.gd`: `current_mana -= data.mana_cost` → `current_mana -= 0.0` | caught by `test_spell_instance` (`test_cast_spends_exactly_the_mana_cost`) |
| 6 | spell | `spell_instance.gd`: `cooldown_left = maxf(cooldown_left - delta, 0.0)` → `cooldown_left = 0.0` | **SURVIVED the whole suite** |
| 7 | spell | `cast_math.gd`: `var result := base / maxf(1.0 + cast_speed, MIN_SPEED_FACTOR)` → `var result := base * (1.0 + cast_speed)` | caught by `test_cast_math` (`test_interval_divides_by_one_plus_cast_speed`) |
| 8 | spell | `cast_math.gd`: `return maxf(scale, MIN_DAMAGE_SCALE)` → `return scale` | caught by `test_cast_math` (`test_scale_is_floored_at_a_tenth`) |
| 9 | spell | `cast_pattern.gd`: `var copies := maxi(spell.copies, 1)` → `var copies := 1` | caught by `test_cast_pattern` (`test_aimed_ring_directions`) (a script error also appeared in the run; not separated from the assertion failure) |
| 10 | spell | `spell_loadout.gd`: `if not spell.has_mana():` → `if false:` | caught by `test_spell_loadout` (`test_depleted_spell_never_fires_never_switches_and_cues_once`) |
| 11 | crafting | `crafting_system.gd`: `if not inventory.has(scroll, needed[scroll]):` → `if not inventory.has(scroll, 1):` | caught by `test_crafting_system` (`test_every_invalid_buff_case_changes_nothing`) |
| 12 | crafting | `crafting_system.gd`: `return REASON_TOO_COSTLY` → `return ""` | caught by `test_crafting_system` (`test_a_spell_that_could_never_cast_is_refused`) |
| 13 | crafting | `spell_builder.gd`: `spell.mana_cost = stats.mana_cost * cost * option.cost_multiplier` → `spell.mana_cost = stats.mana_cost * cost` | caught by `test_spell_builder` (`test_longer_range_costs_more_and_gives_fewer_casts`) |
| 14 | crafting | `spell_builder.gd`: `spell.damage *= effect.damage_multiplier` → `spell.damage *= 1.0` | caught by `test_spell_builder` (`test_each_buff_folds_alone`) |
| 15 | crafting | `spell_builder.gd`: `spell.mana_cost *= effect.cost_multiplier` → `spell.mana_cost *= 1.0` | caught by `test_spell_builder` (`test_each_buff_folds_alone`) |
| 16 | crafting | `scroll_inventory.gd`: `if scroll == null or amount <= 0 or not has(scroll, amount):` → `if scroll == null or amount <= 0:` | caught by `test_scroll_inventory` (`test_remove_is_all_or_nothing`) (a script error also appeared in the run; not separated from the assertion failure) |
| 17 | combat | `health_component.gd`: `current_health = maxf(current_health - amount, 0.0)` → `current_health = current_health - amount` | caught by the full suite (5 tests, first: `test_a_dead_player_is_not_hit`) |
| 18 | combat | `health_component.gd`: `current_health = minf(current_health + amount, max_health)` → `current_health = current_health + amount` | caught by the full suite (4 tests, first: `test_heal_clamps_at_max`) |
| 19 | combat | `hitbox_component.gd`: `if now_msec - int(_last_hit_msec[id]) < int(hit_cooldown * 1000.0):` → `if now_msec - int(_last_hit_msec[id]) > int(hit_cooldown * 1000.0):` | caught by `test_hurtbox_hitbox` (`test_cooldown_blocks_repeat_hits`) |
| 20 | combat | `hitbox_component.gd`: `if _finished: return false` → `if false: return false` | **SURVIVED the whole suite** |
| 21 | combat | `hurtbox_component.gd`: `_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)` → `_invulnerable_left = 0.0` | caught by the full suite (`test_a_grant_does_not_cancel_a_running_per_hit_window_early`) |
| 22 | drops | `drop_table.gd`: `if last_pickable == null: return null` → `if false: return null` | caught by `test_drop_table` (`test_empty_and_all_unpickable_tables_return_null`) (a script error also appeared in the run; not separated from the assertion failure) |
| 23 | drops | `drop_table.gd`: `if chance < 1.0 and rng.randf() >= chance:` → `if chance < 1.0 and rng.randf() <= chance:` | caught by `test_drop_table` (`test_luck_zero_gives_exactly_the_old_rolls`) |
| 24 | shop | `shop_system.gd`: `elif profile.owns(id):` → `elif false:` | caught by `test_shop_system` (`test_buying_twice_fails_and_charges_nothing_more`) |
| 25 | shop | `shop_system.gd`: `profile.spend_gold(item.price)` → `pass` | caught by `test_shop_system` (`test_buy_with_exactly_enough_gold_succeeds`) |
| 26 | potion | `potion_system.gd`: `if player.health.is_dead():` → `if false:` | caught by `test_potion_system` (`test_refuses_when_dead`) |
| 27 | potion | `potion_system.gd`: `if potions.potion_count(potion.id) <= 0:` → `if potions.potion_count(potion.id) < 0:` | caught by `test_potion_system` (`test_refuses_when_none_left`) |
| 28 | potion | `potion_belt.gd`: `const SHARED_COOLDOWN := 1.0` → `const SHARED_COOLDOWN := 0.0` | caught by `test_potion_belt` (`test_shared_cooldown_blocks_a_different_potion_for_one_second`) |
| 29 | progress | `level_track.gd`: `while level < max_level() and xp >= xp_for_level(level + 1):` → `while level < max_level() and xp > xp_for_level(level + 1):` | caught by `test_xp_bar` (`test_level_twenty_shows_max_and_full_bar`) |
| 30 | progress | `run_progress.gd`: `for reached in range(before + 1, level() + 1):` → `for reached in range(before + 1, level()):` | caught by `test_run_progress` (`test_crossing_a_threshold_emits_leveled_up_with_its_reward`) (a script error also appeared in the run; not separated from the assertion failure) |
| 31 | progress | `stat_bonuses.gd`: `total.add_all(second) ` → `(removed)` | caught by `test_player` (`test_refresh_bonuses_adds_the_three_layers`) |
| 32 | save | `save_game.gd`: `DirAccess.rename_absolute(ProjectSettings.globalize_path(path), backup` → `pass` | caught by `test_save_game` (`test_garbage_text_is_moved_to_bak_and_gives_fresh`) |
| 33 | save | `player_profile.gd`: `if not _is_whole_in_range(data.get("total_xp")):` → `if false:` | caught by `test_player_profile` (`test_from_dict_rejects_bad_shapes`) (a script error also appeared in the run; not separated from the assertion failure) |
| 34 | spawn | `enemy_spawner.gd`: `return config.difficulty.max_alive(elapsed_seconds())` → `return 100000` | caught by `test_enemy_spawner` (`test_clusters_never_exceed_max_alive`) |
| 35 | boss | `boss.gd`: `data.phases[clampi(phase, 0, data.phases.size() - 1)]` → `data.phases[0]` | caught by `test_boss` (`test_phase_two_starts_at_half_health_with_its_speed_and_interval_and_burst`) |
| 36 | boss | `run_director.gd`: `_next_boss_at = config.difficulty.boss_interval_seconds` → `_next_boss_at = config.difficulty.boss_interval_seconds + 1000.0` | caught by `test_main_progression` (`test_a_boss_defeat_in_main_drops_rewards_and_keeps_the_run_going`) (a script error also appeared in the run; not separated from the assertion failure) |
| 37 | boss | `lightning_plan.gd`: `candidate = candidate.clamp(bounds.position, bounds.end)` → `candidate = candidate` | caught by `test_lightning_plan` (`test_every_point_is_inside_the_bounds_and_within_the_spread`) |

## Survivors and my reading

- **#6, `SpellInstance.tick` sets `cooldown_left = 0.0` instead of counting it down.** No test checks that a cast interval is still running after part of it has elapsed (tests tick a full interval or none). A cast could then be re-allowed one frame after a cast and nothing would fail. Worth one test: cast, tick half the interval, `can_cast()` is false; tick the rest, true.
- **#20, `HitboxComponent.try_hit` without its `_finished` guard.** A finished hitbox is also switched off by `monitoring = false`, so in play it still stops; but a direct `try_hit` after the last allowed hit returns true. No test calls it that way. Low risk, one cheap test (a one-shot hitbox refuses a second `try_hit`).

## Reading the whole sample

- 35 of 37 caught, and the survivors are narrow boundary behaviours, not whole features: the suite protects the rules that matter most (elements, mana, crafting cost, saves, shop, potions, bosses). It does not look bloated by this measure.
- Three mutations (#17, #18, #21) were not caught by the test file named after their class but by tests of the systems that use it: the class's own test file leaves clamp and decay behaviour to its users.
- Six runs show a script error beside the assertion failure (#9, #16, #22, #30, #33, #36). The first failing test is still a real assertion in each, but the report does not separate the two.
- Limits: 37 hand-picked single-line mutations is a sample, not a score, and equivalent mutations (changes that cannot alter behaviour) were not weeded out beforehand.

## Recommendation

Add the two small tests above if you want them (about 20 lines). A larger deletion of tests is not supported by this sample: no group of tests looked redundant.
