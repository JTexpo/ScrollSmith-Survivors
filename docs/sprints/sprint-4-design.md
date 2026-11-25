# Sprint 4 Design: Elemental Affinities and Enemy Variety

**Status:** Built. Approved by the user after a fresh builder check, then implemented on branch `sprint-4-elemental-enemies`.

Scope comes from `sprint-development.md` (Sprint 4). Architecture follows `technical-design.md` (section 8), `CLAUDE.md`, and `sprint-0/1/2/3-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprint 2 built the elemental table and Sprint 3 built the Areas, but nothing in play uses the table: enemies have no element, and damage is worked out when a spell is cast. Sprint 4 makes the choice of spell matter. Enemies get an element, an attack carries its element to the moment it lands, and the table decides whether the hit is strong, weak or normal. The player sees the result on the screen, in damage numbers and enemy colours, so they can learn which spell to reach for.

**Goals**
- Elemental enemies (Fire, Thunder, Land, Sea) beside the plain one, with different speed, health and contact damage, all in data.
- Hit-time elemental damage: attack element and enemy element meet in one place, through `DamageSystem` and `ElementTable`. The Sprint 2 known limitation (multiplier applied at cast time) is removed.
- Each hit reports whether it was vulnerable, resisted or neutral, so feedback (now) and buffs like Ignore Resistance (Sprint 7) can use it.
- Damage numbers whose look tells the player how the hit went, cheap enough for 300 enemies.
- Enemies visibly show their element.

**Non-goals (later sprints)**
- Enemy behaviours beyond "walk at the player" (exploders, ranged, supports, elites), bosses, waves and difficulty ramp.
- Multi-element spells (still the primary element only), buffs that change vulnerability, XP and drops.
- Final art, effects and audio (Sprint 13), and any in-game legend or tutorial of the element cycle.

**Anti-goals** (a failure even if it technically works)
- Elemental math anywhere except `ElementTable` and `DamageSystem`. No `if enemy is Fire`, and no per-element code in spells, hitboxes or enemies.
- A per-hit node created and freed for each damage number, or per-frame work when nothing is on screen.
- Same-element hits changing damage. The user decided Fire against Fire is normal damage.

## 2. Decisions

| Area | Decision |
|---|---|
| Rules | Unchanged from the table (Fire > Land > Thunder > Sea > Fire). An enemy has one element. It takes the strong multiplier (1.5) from the element that beats it and the weak multiplier (0.5) from the element it beats. Same element is normal damage (user decision). Plain enemies (no element) take normal damage from everything. |
| Where the multiplier applies | At impact. `HitboxComponent` gains `element` (the attacker's), `HurtboxComponent` gains `element` (the defender's). The hurtbox gets the final damage from `DamageSystem.calculate(damage, attacker_element, own_element)`. Areas set raw damage and element on their hitbox, so `AreaEffect._configure_hitbox` no longer multiplies. |
| Hit result | `ElementTable.Effect { NEUTRAL, VULNERABLE, RESISTED }` and `ElementTable.effect(attacker, defender)`. `multiplier()` is defined from it. `HurtboxComponent.hit_received` gains a fourth parameter, the effect. |
| Enemy data | `EnemyData` gains `element` (a dropdown with None and the four elements), `color` (body tint) and `spawn_weight`. Five `.tres` files: the plain enemy plus Fire, Thunder, Land and Sea. All stats stay in data. |
| Starting stats (tune by playing) | Plain 20 health / 10 damage / speed 40. Fire 16 / 12 / 55. Thunder 12 / 8 / 75. Land 50 / 14 / 28. Sea 24 / 10 / 42. |
| Spawning | `SpawnConfig.enemy_data` is replaced by `enemy_pool: Array[EnemyData]`. The spawner picks one by `spawn_weight` using its own `rng`. Weights: plain 1, each element 2 (my call, so most enemies are elemental). Everything else about spawning is unchanged. |
| Enemy colours | Enemies use the same four colours as the spells (Fire orange, Thunder yellow, Land brown, Sea blue). The plain enemy becomes light grey so it is not confused with the orange Fire enemy (my call). |
| Damage numbers | One `DamageNumbers` node in the world draws every number from a fixed pool (64) in a single `_draw`. Neutral: white, normal size. Vulnerable: larger, yellow, with a "!". Resisted: smaller, grey. Numbers rise and fade over about 0.6 s. When the pool is full the oldest number is reused. The node only redraws while numbers are alive. |
| Wiring | `Enemy` emits `damaged(position, amount, effect)`. `EnemySpawner` re-emits it as `enemy_damaged` for every enemy it spawns, and `Main` connects that to `DamageNumbers.show_number`. No group lookups per hit. |
| Player hits | The player's hurtbox has no element, so hits on the player are always neutral and show no damage numbers. |
| Hit flash | Unchanged. Vulnerability and resistance are communicated by the number and its look, not by a new flash (my call). |
| Stress test | The stress scene gets the same `DamageNumbers` wiring, so the 300-enemy measurement includes the real cost, and its enemies come from the new pool. |
| Docs | The README says "a Fire enemy may resist Fire damage but be vulnerable to Sea damage", which disagrees with the table and the user's decision. It is corrected to: a Fire enemy takes extra damage from Sea and reduced damage from Land. `technical-design.md` section 8.2, `sprint-development.md` and `CLAUDE.md` are updated. |

## 3. Approaches considered

**Hit-time elements.** One sensible way: carry the attacker's element on the hitbox and give the defender's element to the hurtbox, because every hit already passes through `HurtboxComponent.receive_hit`. Letting an enemy script work out its own multiplier would break the "elemental math in one place" rule.

**Enemy variety.**
1. **Stat variants (chosen by the user).** Same behaviour, different colour and stats, all data.
2. Distinct behaviours per element. More interesting, but those are the README's later archetypes.

**Damage numbers.**
1. **One shared layer drawing a fixed pool (chosen by the user).** Cheap at 300 enemies.
2. A label node per hit. Simpler, but it creates and frees many nodes in a crowd fight.

## 4. Constraints

- All earlier sprint constraints apply: Godot 4.7.2, typed GDScript, no new autoloads, Input Map actions only, web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Collision layers unchanged. Enemies stay light `Node2D`s moved by position.
- The 60 fps target at 300 enemies must still hold with numbers on screen.

## 5. Design

### ElementTable and DamageSystem
`ElementTable.Effect` and `effect(attacker, defender)`. `DamageSystem.calculate(base, attacker, defender, table)` keeps its signature. `DamageSystem.effect(attacker, defender, table)` returns the effect, so callers never read the table directly.

### Hitbox and hurtbox
`HitboxComponent.element: int = SpellData.NO_ELEMENT`, passed to `receive_hit` as a new optional last argument `attacker_element`. `HurtboxComponent.element: int = SpellData.NO_ELEMENT`. `receive_hit` computes the final damage and the effect, applies the damage and emits `hit_received(damage, source_position, knockback, effect)`. The Player and Enemy handlers take the extra parameter.

### Areas
`AreaEffect._configure_hitbox` sets `hitbox.damage = spell.damage` and `hitbox.element = spell.primary_element()`. No Area changes otherwise.

### Enemies
`Enemy._apply_data` sets the hurtbox element, the body colour, health, contact damage and speed from `EnemyData`. `Enemy` emits `damaged` from its hit handler.

### Spawner
`EnemySpawner` picks from `config.enemy_pool` by weight, and re-emits `enemy_damaged`.

### Damage numbers
`DamageNumbers` (`class_name DamageNumbers extends Node2D`, TEMPORARY look) with `show_number(position: Vector2, amount: float, effect: ElementTable.Effect)`. A fixed array of number records, aged in `_process`, drawn in `_draw`.

## 6. Testing

- GUT unit tests: `ElementTable.effect` for every pair (strong, weak, same element neutral, no element neutral) and `multiplier` agrees with it. A hit lands for strong/weak/neutral damage with the right `effect` in the signal. An Area hit on an enemy applies the multiplier at impact (Fire Missile on a Land enemy deals 15, on a Sea enemy deals 5). The hitbox no longer carries a pre-multiplied damage. Each enemy `.tres` loads with the starting stats and element. The spawner picks every pool entry over many draws and respects weights, including a single-entry pool. `Enemy.damaged` fires with the final amount and effect. `DamageNumbers`: shows a number, ages it out, never exceeds the pool, reuses the oldest when full, reports idle (no redraw) when empty, and styles by effect.
- Update the tests that use `enemy_data`, the three-argument `hit_received`, and the cast-time damage.
- Headless smoke run plus a godot MCP run with no warnings, then the stress test (300 enemies, with numbers) to confirm 60 fps.
- Manual checklist: the four coloured enemies appear mixed with grey ones, the right element hurts each more (larger yellow numbers with "!") and the wrong one hurts less (small grey numbers), same-element hits show normal numbers, Land enemies are slow and tough, Thunder enemies are fast and fragile, and nothing slows down in a big crowd.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Number font size, rise distance, fade timing and colours.
- Exact enemy colours and the grey for the plain enemy.
- Where `DamageNumbers` sits in the scene tree and its draw order relative to enemies.
- How the weighted pick is written.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Elemental math leaks outside `DamageSystem` and `ElementTable` | Spells, hitboxes and enemies only pass elements. A test checks a hit's final damage matches `DamageSystem.calculate` for each pairing. |
| Crowd fights create many numbers and hurt frame time | Fixed pool, one draw call, redraw only while active, and the stress test includes numbers. |
| Zone ticks and fast spells flood the screen with numbers | The pool reuses the oldest, so the cost is capped. Readability is tuned by playing. |
| Nothing in the game teaches the element cycle | Players learn from the numbers and colours. A legend belongs to a later UI sprint. |
| Changing the `hit_received` signature breaks listeners | The Player and Enemy handlers and the tests that assert the signal are updated together, and the suite runs after each task. |
| A pool with all-zero weights or an empty pool | The spawner treats an empty or zero-weight pool as "spawn nothing" without errors, and a test pins it. |
