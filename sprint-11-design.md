# Sprint 11 Design: Enemy Variety, Bosses and Difficulty

**Status:** Built (Sprint 11).

Scope comes from `sprint-development.md` (Sprint 11) and the README (sections 7, 8 and 9). Architecture follows `CLAUDE.md`, `technical-design.md` and `sprint-0` to `sprint-10-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Until now every enemy walks at the player and touches them. The five enemies differ only in numbers, and the run never changes: the 10th minute is the same as the first. Sprint 11 makes combat a real fight. Different enemy roles force different answers (shoot the Ranged one first, dodge the Exploder, kill the Support before the Tank), elements mix with roles so any combination can show up, bosses demand movement, and everything gets harder the longer the player survives. The run still ends only by dying, so the pressure has to keep climbing.

**Goals**
- Seven archetypes that behave differently: Swarmer, Chaser, Ranged, Tank, Exploder, Support and Elite (a modifier on any of them), plus the plain Standard enemy.
- **Elements and archetypes mix and match (user decision):** a Thunder Tank, a Sea Swarmer or a Fire Exploder come from the same pieces. An archetype supplies the role and all stats, an element supplies only the affinity, the colour and the themed scroll drops.
- At least one fully working boss encounter: a boss architecture, boss health, telegraphed attacks, attack patterns, two phases, spawning, rewards, death and encounter completion. After a boss dies the run continues and bosses keep coming (user decision), each tougher than the last.
- Difficulty rises with run time: enemy health, damage and speed scale up, spawns get denser, new archetypes unlock over time, elites become more common, and a boss arrives at fixed intervals.
- Everything is data: archetypes, elements, the difficulty curve and bosses are resources, and a new enemy of an existing behaviour is a new `.tres`.

**Non-goals (later sprints)**
- More than one boss design (the architecture takes more, only one ships), final art, sound and animation (Sprint 13), map obstacles and map-specific spawn tables (Sprint 12), rebalancing equipment for bosses.
- Boss-only damage on Staffs ("increased damage against bosses" in the README). It is left out on purpose because it would change an established item, and it is a question for the user (see section 6).
- Unique equipment and special crafting materials as boss rewards (README). This sprint pays XP, Gold and Rare scrolls.

**Anti-goals** (a failure even if it technically works)
- Code that branches on an enemy name or an element when choosing behaviour, or an element that quietly changes stats. Behaviour comes from the archetype's `kind` and numbers.
- A telegraphed attack that hurts before its warning ends, or one that cannot be dodged by moving.
- Difficulty or boss timers that keep running while the game is paused.
- A boss or enemy that can leave the arena, or enemy projectiles and blasts that live forever or pile up without a cap.
- Per-enemy shared state: scaling a spawned enemy must never edit the shared `EnemyData` or archetype resources.
- Tests that touch the real save, or that depend on a random roll without a seed.

## 2. Decisions

| Area | Decision |
|---|---|
| Composition (user: mix and match, "A") | An enemy is built from an `EnemyArchetype` (the role) and an `EnemyElement` (affinity, colour, drops), picked independently by weight. **An element has no stat flavour:** a Thunder Tank is exactly as tough as a Land Tank and differs only in what hurts it and what it drops (user decision, option A). The old five enemies were element-and-stat bundles, so their stat personalities move into archetypes (Land's toughness becomes Tank, Thunder's speed becomes Chaser, the plain enemy becomes Standard), and the five enemy files and the tests that name them are migrated. |
| Runtime shape | `EnemyComposer` builds one shared, cached `EnemyData` for each archetype and element pair (display name "Thunder Tank", stats, colour, drop table, rewards, behaviour). Per-spawn values live on the `Enemy` instance instead (health, damage and speed scale from difficulty, the elite flag), so shared resources are never edited. |
| Archetype data | `EnemyArchetype` (Resource): id, display name, health, speed, contact damage, body scale, XP and Gold reward, spawn weight, `unlock_seconds`, `cluster_size`, a drop-chance scale, a behaviour `kind` (CHASE, KEEP_DISTANCE, EXPLODE, SUPPORT) and the behaviour numbers. |
| Element data | `EnemyElement` (Resource): id, element (none, Fire, Thunder, Land, Sea), colour, drop table, spawn weight. Five of them: none and the four elements (weights none 1, each element 2, as before). Colour tints the archetype's body, so the pair is readable at a glance. |
| Archetypes (my calls, tune by playing) | **Standard:** 20 health, speed 40, contact damage 10, scale 1.0, 5 XP, 1 Gold, weight 4, from 0 s. **Swarmer:** 8 health, speed 46, damage 5, scale 0.7, 2 XP, 1 Gold, spawns in clusters of 5, weight 2, from 30 s. **Chaser:** 14 health, speed 80, damage 9, scale 0.9, 5 XP, 1 Gold, weight 2, from 60 s. **Tank:** 80 health, speed 26, damage 16, scale 1.5, 12 XP, 3 Gold, drop chance x1.5, weight 1, from 120 s. **Ranged:** 14 health, speed 34, damage 6, keeps about 90 px away and fires a projectile every 2 s (speed 110, damage 8), 7 XP, 2 Gold, weight 1.5, from 180 s. **Exploder:** 12 health, speed 58, damage 4, runs in, flashes for 0.8 s when within 28 px, then blasts a radius of 36 for 24 damage and dies, 6 XP, 1 Gold, weight 1.5, from 240 s. **Support:** 22 health, speed 30, damage 4, heals every other enemy within 70 px for 6 health a second, 8 XP, 2 Gold, drop chance x1.5, weight 1, from 300 s. |
| Elites (my call) | An elite is a modifier on any archetype and element: x3 health, x1.5 damage, x1.15 speed, x1.4 size, x3 XP and Gold, drop chance x2, and a bright outline. The chance is 0 before 120 s, then rises 2% a minute up to 20%. It keeps its archetype's behaviour. |
| Shared dangers | `EnemyProjectile` (a passive-until-hit `Area2D` on the enemy hitbox layer, moves straight, hits the player's hurtbox once, frees itself at its range) and `BlastZone` (a ground circle that shows a warning for its fuse time and only then damages the player if they are still inside). Ranged enemies, Exploders and the boss all use them. A cap on live enemy projectiles (60) frees the oldest. |
| Difficulty curve (my call) | A `DifficultyCurve` resource turns run minutes `m` into: health x(1 + 0.12 m), damage x(1 + 0.06 m), speed x(1 + 0.02 m) up to +25%, a spawn interval of 0.5 s / (1 + 0.15 m) down to 0.12 s, a maximum alive of 150 + 20 m up to 300, the elite chance above, and the boss interval (300 s). Archetypes unlock at their `unlock_seconds`. |
| Run clock | The pausable `GameTime` already exists. A `RunDirector` node reads it, so the difficulty, unlocks and boss timer all freeze while the game is paused (crafting, the pick screen). |
| Spawning | `EnemySpawner` takes the elapsed time and the curve: it picks an unlocked archetype and an element by weight, rolls elite, spawns a cluster for a Swarmer, and applies the scales to each spawned `Enemy` instance. |
| Boss architecture | `BossData` (Resource): id, name, element, health, contact damage, speed, body scale, a list of `BossPhase`s, and the rewards. A `BossPhase` has a health threshold (the fraction of health at which it starts), an attack list, an attack interval and a speed multiplier. A `BossAttack` has a `kind` (SLAM, CHARGE, BURST, SUMMON) and its numbers (telegraph time, size, damage, count). `Boss` is a scene that reuses the health, hurtbox, hit flash and contact hitbox components and runs a small state machine: wait, choose an attack, telegraph, act, recover. It is knockback-immune and clamped to the arena. |
| The first boss, Ember Titan (my call) | Fire element, 1500 health, contact damage 20, speed 30, scale 3. **Phase 1** (down to 50% health): Slam, Charge and Summon every 2.5 s. **Phase 2** (below 50%): adds Burst, attacks every 1.8 s and moves 30% faster. **Slam:** marks the player's spot, a 1 s warning, then 30 damage in a radius of 48. **Charge:** a 0.8 s warning along a line toward the player, then a dash at 260 for 0.6 s for 25 damage, then a **vulnerability window** of 2 s in which it takes +50% damage and is tinted. **Burst:** a ring of 12 projectiles (speed 100, damage 12). **Summon:** 4 Swarmers around the boss. Everything is telegraphed and avoidable by moving. |
| Boss timing and scaling | The first boss arrives at 300 s, and each next one 300 s after the previous one spawned (it waits if one is still alive). Boss number n has health x(1 + 0.5 (n - 1)) and damage x(1 + 0.2 (n - 1)). While a boss is alive normal spawning runs at half rate. A toast announces it. |
| Boss rewards | XP 300 and Gold 150 (both x n), plus 2 scrolls rolled from a Rare-only drop table. They drop where the boss died, through the existing droppers. Defeating the boss completes the encounter (a signal) and starts the next boss timer. |
| HUD (TEMPORARY looks) | A boss health bar with its name at the top centre while a boss lives, a small run clock, and the boss toast. The death screen also shows the time survived. |
| Rewards from elites and archetypes | `Enemy` reports its own XP, Gold and drop-chance scale (archetype values times the elite multiplier), and the droppers read those instead of reading the data directly. `DropTable.roll` gets an optional chance scale (default 1.0, so every existing roll is unchanged). |

## 3. Approaches considered

1. **Mostly data, behaviour only where needed (chosen, with the user's mix and match).** Four archetypes are data (Standard, Swarmer, Chaser, Tank) plus the Elite modifier, three need small behaviours (Ranged, Exploder, Support), and the bosses are data driving one state machine. Shared projectile and blast pieces are built once.
2. **A scene and script per archetype.** Simple to read, but it duplicates the health and hit setup many times and makes every element a copy.
3. **A general behaviour tree.** Flexible, but far more than seven enemies and one boss need.

## 4. Risks for the builder

- **Migration.** `EnemyData`, `SpawnConfig`, `EnemySpawner`, the droppers and several tests assume the old five enemy files. The plan must keep the suite green at every step and migrate the tests that name those files (spawner tests, element tests, reward and drop-table tests).
- **Performance.** More enemies (up to 300 alive), projectiles, blasts and a boss. The stress test target (60 fps at 300 enemies) must still hold with the new archetypes in the pool, and enemy projectiles and blasts are capped.
- **Shared resources.** Scaling and the elite flag live on the `Enemy` instance. A test must prove two enemies of one pair never share scale.
- **Telegraph honesty.** A blast or slam must be harmless until its warning ends, must not follow the player once placed, and must respect the pause. The tests use the game clock or explicit `_process` steps.
- **Arena bounds.** Enemies are clamped to the arena rectangle. Boss attacks and summons must stay inside it, and a boss slam near a wall must still be avoidable.
- **Boss while dead or paused.** The boss stops when the player dies, and nothing advances while paused.
- **Touch.** The boss bar and clock are not touchable, so they ignore the mouse. No new interactive control is added.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 11 boxes and a Built note), `README.md` (the archetype and element mixing rules, the difficulty and boss numbers), `technical-design.md` (enemy composition), `CLAUDE.md` (an "Enemies and bosses (Sprint 11)" section and the changed enemy facts from Sprint 4), `development-log.md`, and the memory file.

## 6. Open question for the user

Should the Staffs get "increased damage against bosses" in this sprint? It would add a stat and a modifier on the Oak and Elder Staffs (changing items you may already own). The default in this design is no, leaving it for a later sprint.
