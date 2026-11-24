# Sprint 16b Design: The forest's art and the Tempest Dragon

**Status:** Proposed, awaiting approval.

Sprint 16 is four parts (see `sprint-development.md`): 16a the map select, the art sets and the new layouts (done), **16b the forest's art and the Tempest Dragon (this doc)**, 16c the ruins' art refresh, 16d the maze's art and the Dire Minotaur. Scope comes from the Sprint 16 plan, `CLAUDE.md` (Enemies and bosses, Art pipeline, Maps and the map select) and the user's answers in conversation. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The forest is a map "about finding a dragon", but today it shows the ruins' mix of enemies and the Ember Titan. 16b gives it its own look and its own boss: **four new forest enemy sprites** (rats, ent, creepers, shaman), the **Tempest Dragon** (a Thunder boss) with a fight that plays differently from the Ember Titan's, and the small piece of data that lets a map name its own boss roster. The ruins and the maze are unchanged.

**Goals (user decisions)**
- The forest column is complete: goblin (standard), **rats** (swarmer), wolves (chaser), **ent** (tank), kobolds (ranged), **creepers** (exploder), **shaman** (support). The goblin, wolves and kobolds already exist and keep showing through the 16a fallback.
- The **Tempest Dragon** is the forest's boss, Thunder, arriving on the same 300-second timer as every boss, with no lair.
- **Approach B for the fight (the user's pick): the existing four attack kinds plus one new one, "lightning strikes"**: several warned circles land around the player and each blasts a moment later. It reuses the blast zone's warning rule. This gives a storm feel and avoids the Titan's stand-and-slam rhythm.
- Everything but the art and the boss stays the same on every map (enemy types, elements, stats, spawn config, rewards, the 300 s timer).

**My calls**
- **The roster is data on the map.** `MapData.bosses` (an array, empty by default) names the map's bosses; empty means the shared spawn config's roster. The spawn config stays one shared resource, so "the same on every map" stays true. `EnemySpawner` gets the roster from `Main._apply_map` (`boss_roster`, and a `bosses()` accessor that returns it or `config.bosses`); `RunDirector`, the stress scene, the soak driver and the map card's boss line read `bosses()` or the map's own list. The ruins and maze name none for now (the Ember Titan stays their boss until 16d).
- **Dragon numbers match the Titan's weight, not its pattern.** Same health (1500), contact damage (20), rewards (300 XP, 150 Gold, 2 scrolls, the same Rare-scroll table) and body size (`body_scale` 3); speed a little higher (36 against 30) because a dragon is quick. Starting values for the user to tune.
- **Three phases, not two** (100%, 60%, 25%): phase 1 lightning (3 strikes), charge, summon; phase 2 lightning (5), a burst ring, charge, summon; phase 3 "the storm": lightning (7), burst, a faster charge, shorter intervals. All of it is `BossData`, no code branches on the boss.
- **The new attack, `BossAttack.Kind.LIGHTNING`.** Fields it uses: `count` (strikes), `radius` (each strike), `damage`, `telegraph_time`, and one new field, `spread` (how far from the player the other strikes land; the first strike lands on the player's spot when the warning starts, the rest at seeded random points within `spread`, clamped to the arena). Each strike is an ordinary `BlastZone` (so the telegraph rule, the pooling cap and the sounds already exist). The boss cancels every undetonated strike when it dies, as it does for a slam today.
- **Always avoidable (a rule, pinned by a test):** `spread + radius` is less than the distance the player covers at base speed during `telegraph_time`, so a player who runs straight away from the strikes can always leave all of them before they land. The Dragon's numbers are chosen inside that rule.
- **Walks, does not fly.** The Dragon uses the Titan's movement (the flow field, obstacles stop it), so the forest's trees matter. A flying boss would need new movement rules.
- **Art, in the existing pipeline.** The four enemies are ramp sprites with the current sizes and animations (rats 10 by 10; ent 24 by 24; creepers 14 by 14 with `fuse`; shaman 14 by 14 with `pulse`; each with `move` and `death`) built in the five element colourways like the others, named `enemy_forest_swarmer`, `enemy_forest_tank`, `enemy_forest_exploder`, `enemy_forest_support` (the 16a lookup). The Dragon is `boss_tempest_dragon`, 40 by 32 (wings make it wider than the Titan), fixed colours (thunder yellow, storm blue, cream, plum outline), animations `idle`, `telegraph`, `attack`, `vulnerable`. Bright, simple, cartoon, one pixel size, no scaling, no skin colours; new fixed colours must fit the palette (55 of 64 used).
- **No new forest world art by default.** The forest already has grass and trees; the user asked for no scattered decoration in the ruins, and the forest's screenshots read well. If the real-window check shows it bare, I will say so and propose something small instead of adding it silently.
- **Sound reused:** the boss stinger, the boss music and the blast zone's warning and boom already play for every boss and blast. No new sound.
- **The card shows the boss:** the forest's card reads "Boss: Tempest Dragon" (from the map's roster).
- **Balance is checked, not tuned by guess:** a throwaway bot fights each boss and reports time to defeat and damage taken, compared with the Titan; the numbers go to the user, nothing is asserted.

**Non-goals**
- Ruins (16c) and maze (16d) art, the Dire Minotaur, new sounds, new maps, boss flight, any change to the Ember Titan, the spawn config, the difficulty curve or rewards.
- Achievements (a boss defeat granting a starting spell) belong to Sprint 17.

**Anti-goals** (a failure even if it technically works)
- A lightning strike that cannot be dodged, or a warning too short to read.
- The ruins or maze showing a forest sprite or the Dragon; the forest showing a coloured square or a wrong enemy; the goblin, wolf or kobold disappearing.
- A boss that bypasses the existing rules (it must telegraph, ignore knockback, stay in the arena, pay out once).
- Stale art output (a committed PNG that differs from its grid), a sprite touching its margin, a colour outside the palette.
- Any test that touches the real save or really changes scene.

## 2. Approaches

- **A. Same four attacks, different numbers.** No new code; risks feeling like a reskin of the Titan.
- **B. Add "lightning strikes" (chosen by the user).** One new attack kind built on the blast zone; a distinct storm feel at small cost.
- **C. Lightning plus a breath line or cone.** Most distinct, most new code and tests. Not chosen.

For the roster: **(i) a second `SpawnConfig` for the forest** would copy every number and could drift from the shared one; **(ii) `MapData.bosses` override (chosen, my call)** keeps one config.

## 3. Decisions

| Area | Decision |
|---|---|
| Roster | `MapData.bosses: Array[BossData]`, empty by default. `EnemySpawner.boss_roster` set by `Main._apply_map` from the map; `EnemySpawner.bosses()` returns the roster when not empty, else `config.bosses`. `RunDirector._spawn_boss` picks `bosses()[(n - 1) % size]`; stress and soak use `bosses()[0]`; `MapEntry.boss_name()` uses the map's `bosses` first, then the spawn config's. The forest's `forest_map.tres` lists the Dragon. |
| New attack | `BossAttack.Kind.LIGHTNING` (appended to the enum, so saved data stays valid) and `BossAttack.spread` (default 80). `Boss._begin_attack` places `count` zones (a list, `_zones`), the first on the player, the rest seeded within `spread` and clamped to the arena; `_start_action` for LIGHTNING finishes the attack (the zones detonate by themselves, as a slam's does); `_on_died` cancels every undetonated zone. The telegraph pose is the boss's `telegraph` animation, the strike a short `attack` pose. |
| Dragon data | `resources/bosses/tempest_dragon.tres`: id `tempest_dragon`, "Tempest Dragon", element Thunder (1), 1500 health, 20 contact, speed 36, `body_scale` 3, the Titan's rewards; three phases as in my calls; the Swarmer summon (rats in the forest). |
| Enemy art | Four `.sprite` sources `enemy_forest_swarmer`, `_tank`, `_exploder`, `_support` (ramp sprites, the element colourways); `art/sprites/boss_tempest_dragon.sprite`; palette additions only if needed. Built by `tools/art/art_builder.gd`, covered by the existing stale-output tests. |
| Look | `Enemy.look_sprite()` already resolves `enemy_forest_<type>`; nothing to change but tests pinning that the forest uses the new sprites for four archetypes and the fallback for the other three, and that the ruins and maze are unchanged. |
| Boss art | `Boss` already loads `boss_<id>` (`boss_tempest_dragon`); with art missing it keeps the coloured square. |
| Tests | See the verification plan. |

## 4. What is left to the builder
- The exact pixel grids of the four enemies and the Dragon (within the sizes, animations and palette rules above), and any new palette letters.
- The Dragon's final numbers inside the "always avoidable" rule (strike counts, radius, spread, intervals, charge speed), and how the strikes are spread (random within `spread` with a minimum distance between strikes so they do not stack on one spot).
- The wording of nothing new in the UI beyond the card's boss line.

## 5. Verification plan
- **Art tests (existing machinery):** the stale-output test passes with the new sources, every pixel is a palette colour, no frame touches its margin, animations and frame counts match the plan (move, death, fuse or pulse, and the boss's four), the silhouettes exist.
- **Set lookup:** the forest resolves the four new sprites and falls back for standard, chaser and ranged; the ruins and the maze still resolve `enemy_<type>` exactly as before; every element colourway of each new sprite loads.
- **Roster:** `MapData.bosses` defaults empty; `EnemySpawner.bosses()` returns the map's list or the config's; `RunDirector` spawns the Dragon on the forest and the Titan on the ruins and maze at 300 s and cycles; `MapEntry.boss_name()` gives "Tempest Dragon" for the forest and "Ember Titan" otherwise; the shared spawn-config test still holds.
- **Lightning:** `count` zones are placed, the first on the player, the others within `spread` and inside the arena, none closer than a minimum to another; every zone has the attack's telegraph, radius and damage (times the boss's damage scale); the attack ends in recover; undetonated zones are cancelled when the boss dies and none outlives it; the blast zone cap is respected; the **always avoidable** rule holds for every lightning attack in the Dragon's data; a paused game freezes the zones (they count `_process` deltas).
- **Dragon data:** it validates like the Titan's (phases descending, every phase has attacks, intervals positive), has the Titan's health, rewards and table, is Thunder, is skipped-phase safe (a hit that skips a phase lands in the last one), ignores knockback, takes the charge's vulnerability bonus, and pays out once.
- **Boss fight run:** a headless run spawns the Dragon, lets it use every attack, and checks it never errors, every attack telegraphs, and it dies once.
- **Real window (touch rule where a screen is involved):** a screenshot sheet of every new enemy in the five colourways and each animation, the Dragon's four poses, a lightning warning, and a forest fight; read the images. The map select shows the forest card with the Dragon.
- **Balance report (not asserted):** a bot fights the Dragon and the Titan, reporting time to defeat and damage taken, and the forest's order check from 16a is repeated; numbers go to the user.
- **Performance:** the stress scene with `--boss --map=forest` against the ruins' `--boss`, recorded.
- `godot --headless --import` after adding a `class_name`, then the full suite and a smoke run.
