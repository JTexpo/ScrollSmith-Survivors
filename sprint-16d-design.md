# Sprint 16d Design: The maze's art and the Dire Minotaur

**Status:** Proposed, awaiting approval.

Sprint 16 is four parts (see `sprint-development.md`): 16a the map select, the art sets and the layouts (done), 16b the forest's art and the Tempest Dragon (done), 16c the ruins' art refresh (done), **16d the maze's art and the Dire Minotaur (this doc)**. Scope comes from the Sprint 16 plan, `CLAUDE.md` (Enemies and bosses, Art pipeline, Maps and the map select, the 16b and 16c sections) and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The maze is "a minotaur's maze or dungeon", but today it shows the other maps' enemies and the Ember Titan. 16d gives it its own look and boss: **seven maze enemy sprites** (zombie, snakes, ghost, troll, skeletons, warforge, beholder), the **Dire Minotaur** (a Land boss) with a fight built around charges in corridors, and the small code change that makes a charge chain. This finishes Sprint 16: every map has its own enemies and boss.

**Goals (user decisions)**
- The maze column is complete: zombie (standard), snakes (swarmer), ghost (chaser), troll (tank), skeletons (ranged), warforge (exploder, robot-like), beholder (support), as `enemy_maze_<type>` sprites found by the 16a lookup.
- The **Dire Minotaur** is the maze's boss, Land, arriving on the same 300-second timer as every boss, with no lair, through the 16b roster (`MapData.bosses`).
- **Option B for the fight (the user's pick): charges that chain.** `CHARGE` gains a `repeats` field: a stampede of up to three re-aimed dashes, each with its own warning. In corridors a charge ends at the first wall and leaves the boss open (the existing rule), so the maze itself punishes a missed stampede.
- Everything but the art and the boss stays the same on every map (enemy types, elements, stats, spawn config, rewards, the 300 s timer).

**My calls**
- **No renaming of the plain sprites (a change from the 16c note).** The 16c plan left "rename every plain sprite into its set" for 16d, but the user approved only option A (add sprites, rename nothing). Renaming would delete the plain `enemy_<type>` sprites that the empty art set, the stress scene and many tests rely on, and that guarantee "a missing sprite never leaves a coloured square", for no player-visible gain. So the plain sprites stay as the default and the fallback, the maze gets its own seven sprites, and the docs say the rename was dropped.
- **Chain rules (data, in `BossAttack`):** `repeats: int` (extra dashes after the first, default 0) and `chain_warning: float` (seconds of warning before each chained dash, default 0.6). Every dash re-aims at where the player is when its own warning starts and shows the same dash-line marks. **A dash that hits an obstacle ends the whole chain at once** (the boss crashes into the wall) and the recovery and vulnerability window follow; otherwise the window follows the last dash. Each dash does the attack's `damage`. The charge's existing numbers (`dash_speed`, `dash_time`, `recover_time`, `vulnerability_bonus`) apply to every dash; the recovery is taken once, at the end.
- **Always avoidable (a rule pinned by a test):** the chained warning must leave time to sidestep the dash line: `(chain_warning - 0.25 s of reaction) x the player's base speed (90)` is at least the boss's hit half-width plus the player's half-width. The Dragon's reaction allowance (0.25 s) applies here too.
- **Dire Minotaur numbers match the Titan's and Dragon's weight, not their pattern:** 1500 health, 20 contact damage, `body_scale` 3, 300 XP, 150 Gold, 2 Rare scrolls from the same table; speed 32 (the Titan 30, the Dragon 36). Land element. Starting values for the user to tune. Three phases (100%, 60%, 25%): phase 1 (interval 2.6): slam, a charge with `repeats` 1, a Swarmer summon; phase 2 (1.8, speed x1.2): slam, a charge with `repeats` 2, a burst of 10 rock shards, a summon; phase 3 (1.2, speed x1.4): a faster charge with `repeats` 2, a slam, a burst of 12. All of it is `BossData`, no code branches on the boss.
- **Art, in the existing pipeline and the 16b/16c method** (composed with a scratchpad generator: simple shapes and an automatic 1 px outline, the committed `.sprite` grids as the source, contact sheets looked at in every colourway). Sizes and animations match the plain sprites they stand beside (zombie 14 by 14, snakes 10 by 10, ghost 12 by 12, troll 24 by 24, skeletons 14 by 14 with `attack`, warforge 14 by 14 with `fuse`, beholder 14 by 14 with `pulse`; each with `move` and `death`), built in the five element colourways. The Minotaur is `boss_dire_minotaur`, 40 by 32, fixed colours from the existing palette (earth browns, a stone grey, horn cream, a dark outline; no new letters expected), `idle`, `telegraph`, `attack`, `vulnerable`: a hulking bull-headed brute with wide horns, pawing and snorting on the warning, a lunge on the dash, dazed with stars when open.
- **Lesson from 16c, built in:** a new test requires at least 8 differing pixels between the two frames of every move, death and attack/fuse/pulse animation of the seven maze sprites, **and the same audit is run over the forest's four sprites, the ruins' three and the Dragon, the Titan and the Minotaur** (reported; an animation whose frames are identical is a bug and is fixed).
- **No new maze world art by default.** The maze already has stone walls and the ruin floor, and its screenshots read well; if the real-window check shows it bare, I will say so and propose something small.
- **Sound reused:** the boss stinger, boss music and blast sounds. No new sound.
- **The card shows the boss:** the maze's card reads "Boss: Dire Minotaur" (from its roster).
- **Balance is checked, not guessed:** a bot fights the Minotaur (and the Titan and Dragon for comparison) and reports time to defeat and damage; a headless run checks that the Minotaur crosses the maze to the player through the flow field (it must not get stuck in corridors). Numbers go to the user; nothing is asserted about difficulty.

**Non-goals**
- Renaming existing sprites, new sounds, new maps, boss flight, any change to the other bosses, the spawn config, the difficulty curve or rewards, achievements (Sprint 17).

**Anti-goals** (a failure even if it technically works)
- A chain of charges that cannot be sidestepped, or a stampede with no warning between dashes; a chain that keeps going after hitting a wall; a boss left stuck in a corridor.
- The ruins or forest showing a maze sprite or the Minotaur; the maze showing a coloured square; any plain sprite deleted or renamed.
- A boss that bypasses the existing rules (it must telegraph, ignore knockback, stay in the arena, pay out once).
- Stale art output, a frame touching its margin, a colour outside the palette, an animation whose frames are identical.
- Any test that touches the real save or really changes scene.

## 2. Approaches

- **A. Existing attacks only, tuned.** No new code; risks feeling like another reskin.
- **B. Charges that chain (chosen by the user).** `repeats` on CHARGE: small code, suits corridors, and the maze's walls interact with it.
- **C. B plus a new ground attack (a line of rubble blasts).** Most distinct, most code and tests. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Chain data | `BossAttack.repeats: int = 0` and `BossAttack.chain_warning: float = 0.6`, both documented as CHARGE only. A helper `BossAttack.dash_count() -> int` (1 + max(repeats, 0)). |
| Boss | `Boss` counts `_dashes_left`; when a dash ends without hitting an obstacle and dashes remain, it re-aims (`_dash_direction` from the player's position now), goes back to TELEGRAPH for `chain_warning` showing the charge marks, then dashes again; an obstacle ends the chain at once (`_finish_attack`); the recovery and vulnerability follow the last dash. The charge marks, the `attack` and `telegraph` poses and `attack_started` (emitted once per attack, not per dash) keep working; a boss that dies mid-chain clears its marks. |
| Dragon and Titan | Unchanged: their charges have `repeats` 0 and behave exactly as before. |
| Dire Minotaur data | `resources/bosses/dire_minotaur.tres`: id `dire_minotaur`, "Dire Minotaur", element Land (2), the numbers and three phases in my calls. `maze_map.tres` gets `bosses = [dire_minotaur]`. |
| Maze art | Seven `.sprite` sources `enemy_maze_standard`, `_swarmer`, `_chaser`, `_tank`, `_ranged`, `_exploder`, `_support`, and `boss_dire_minotaur.sprite`; built by `tools/art/art_builder.gd`, covered by the existing stale-output tests. |
| Look | `Enemy.look_sprite()` already resolves `enemy_maze_<type>`; tests pin the maze set for all seven, that the ruins, forest and the empty set are unchanged, and that every maze archetype and element is drawn with art. |
| Docs | `CLAUDE.md` "The maze's art and the Dire Minotaur (Sprint 16d)" and a correction of the 16c note (the rename was dropped); `development-log.md`; `sprint-development.md` marks 16d done and Sprint 16 complete. |

## 4. What is left to the builder
- The exact pixel grids of the seven enemies and the Minotaur within the sizes, animations and palette rules.
- The Minotaur's final numbers inside the "always avoidable" rule, and the exact boss hit half-width used by that rule (read from the boss scene's contact shape).
- How the chained re-aim is tested deterministically (stepping the boss by hand with a stand-in obstacle map).

## 5. Verification plan
- **Chain:** a charge with `repeats` N dashes N + 1 times; each dash after the first is preceded by a warning of `chain_warning` with the dash-line marks and re-aims at the player's new position (not the old one); contact damage applies only during a dash; an obstacle ends the chain at once and the vulnerability window starts then; without an obstacle the window starts after the last dash only, and lasts `recover_time`; `attack_started` fires once per attack; a boss killed mid-chain clears its marks and stops; a charge with `repeats` 0 (the Titan and Dragon) is exactly as before (their existing tests stay green); paused game freezes it.
- **Minotaur data:** it validates like the Dragon's (three phases in order, every attack has a warning of at least 0.6 s, speeds rising, intervals falling), has the Titan's health, rewards and table, is Land, and **every chained charge in every phase satisfies the always-avoidable rule**; a hit that skips a phase lands in the last one.
- **Roster:** the maze sends the Minotaur at 300 s, the forest the Dragon, the ruins the Titan; the maze card reads "Boss: Dire Minotaur" and still fits.
- **Art tests:** the stale-output test, palette, margins, animation headers (names, frame ranges, fps, loop flags equal to the plain sprites'), silhouettes; **every animation's two frames differ by at least 8 pixels** for the maze sprites, with the audit over the earlier new sprites and bosses reported.
- **Lookup:** the maze resolves its seven sprites in every colourway at the right sizes; the ruins, forest and empty set are unchanged; every maze archetype and element is drawn with art; elites get their outline.
- **No behaviour change:** the composed enemy data, hit shapes and scale are the same whatever the art set (the 16c test extended to the maze set).
- **Boss in the maze:** a headless run spawns the Minotaur far from the player on `main_maze.tscn` and steps it until it is within a short distance of the player (it must get there through the flow field in a bounded time); a fight run uses every attack once, never breaks the blast zone cap and dies once.
- **Real window:** contact sheets of every new sprite in the five colourways (frames of each animation compared, not just the first), the Minotaur's four poses next to the Titan and Dragon, a stampede warning with its dash lines in a corridor, a maze crowd; read the images.
- **Balance and performance reports (not asserted):** the bot fight against the three bosses; the stress scene `--boss --map=maze` against the ruins', recorded.
- `godot --headless --import` after adding sources, then the full suite and a smoke run.
