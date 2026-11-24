# Sprint 16c Design: The ruins' art refresh

**Status:** Proposed, awaiting approval.

Sprint 16 is four parts (see `sprint-development.md`): 16a the map select, the art sets and the layouts (done), 16b the forest's art and the Tempest Dragon (done), **16c the ruins' art refresh (this doc)**, 16d the maze's art and the Dire Minotaur. This is a small change (three sprites, their tests and the docs), so the design is short. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The ruins are "the ruins of a city" and should show their own column of enemies: **bandit** (standard), slime (swarmer), **mimic** (chaser), animated armour (tank), **elemental** (ranged), mephit (exploder, the current imp) and cultist (support). Today the ruins reach the goblin, wolf and kobold through the 16a fallback; 16c gives them three sprites of their own. It changes how enemies look, never how they behave.

**Goals (user decisions)**
- Three new ruins sprites: `enemy_ruins_standard` (a bandit), `enemy_ruins_chaser` (a mimic) and `enemy_ruins_ranged` (an elemental), found by the existing `enemy_<set>_<type>` lookup. The slime, animated armour, mephit (the current imp) and cultist stay as they are (the user's plan: "the mephit stays the current imp").
- **Option A (the user's pick): leave every existing sprite where it is.** No sprite is renamed now; the plain `enemy_<type>` sprites (goblin, wolf, kobold, slime, armour, imp, cultist) stay the shared fallback. The renaming of every sprite into its set is left for 16d, when all three sets are complete and the fallback is no longer relied on.
- Everything but the art stays the same on every map: stats, elements, spawn config, rewards, bosses.

**My calls**
- **Sprites keep the size and animations of the ones they replace**, so the hit shapes, the state animations and the stale-output tests behave the same: bandit 14 by 14 (`move` 0-1 6 fps loop, `death` 2-3 12 fps once); mimic 12 by 12 (the same two animations); elemental 14 by 14 (`move`, `death`, and `attack` 4-5 12 fps once, which the Ranged brain plays when it fires). Each is a ramp sprite built in the five element colourways like the others (the ramp slots 1 to 5 plus the fixed letters of `art/palette.txt`; no new palette letters are expected, the palette sits at 55 of 64).
- **The three designs** (bright, simple, cartoon, one pixel size, no skin colours): a **bandit**, a hooded rogue in a mask with a bandana tail and a dagger; a **mimic**, a treasure chest with a toothy open lid, a tongue and stubby legs, bands in the trim colour; an **elemental**, a floating spirit with a swirling core and a glow, its `attack` frames flaring bright as it throws.
- **Same method as 16b:** compose each from simple shapes with an automatic outline in a scratchpad script, build with the art tool, and look at contact sheets in every colourway before committing; the committed `.sprite` grids are the source.
- **No code change is expected.** If one turns out to be needed (a state animation the Ranged brain does not find), it is a bug to fix with a test first.

**Non-goals**
- Renaming existing sprites (16d), maze art (16d), new bosses, new sounds, new world art, any stat, balance or behaviour change.

**Anti-goals** (a failure even if it technically works)
- The forest or the maze showing a ruins sprite, or the ruins still showing the goblin, wolf or kobold; the seven ruins archetypes not all resolving to art.
- A sprite whose animations differ from the one it replaces (the Ranged `attack`, the death animation that frees the enemy).
- Stale art output, a frame touching its margin, a colour outside the palette.
- Any gameplay difference on the ruins.

## 2. Approaches

- **A. Add the three ruins sprites, rename nothing (chosen).** Smallest change; the fallback keeps carrying the rest.
- **B. Rename every existing sprite into its set now.** Explicit, but touches many assets and tests and the maze would still need a fallback.
- **C. Rename in 16d.** The same end state as B, done once when nothing depends on the fallback. This is the follow-up for 16d.

## 3. Decisions

| Area | Decision |
|---|---|
| Sources | `art/sprites/enemy_ruins_standard.sprite`, `enemy_ruins_chaser.sprite`, `enemy_ruins_ranged.sprite`, built by `tools/art/art_builder.gd` into `assets/sprites/` (committed). |
| Lookup | Unchanged (`Enemy.look_sprite`): the ruins' set is `ruins`, so standard, chaser and ranged resolve to the new sprites and the other four archetypes to `enemy_<type>`. |
| Forest and maze | Unchanged: the forest still resolves the goblin, wolf and kobold through the fallback, the maze all seven through it. |

## 4. What is left to the builder
- The exact pixel grids of the three sprites within the sizes, animations and palette rules above.

## 5. Verification plan
- **Art tests (existing machinery):** the stale-output test, palette colours, margins, animation names, ranges, fps and loop flags, silhouettes and orphan checks pass with the new sources.
- **Set lookup (a new test file like `test_forest_art`):** the ruins resolve the three new sprites in every colourway at the replaced sprites' sizes with the same animations; the ruins resolve `enemy_<type>` for swarmer, tank, exploder and support; the forest and maze are unchanged (forest: the four 16b sprites and the fallback for the rest; maze: the fallback for all seven); every ruins archetype and element is drawn with art, never a square.
- **No behaviour change:** a test that the composed `EnemyData` of every archetype and element is the same whatever the map's art set (the set only changes the look), and the existing enemy, brain and spawner tests stay green.
- **Real window:** contact sheets of the three sprites in the five colourways (looked at, and redrawn if they read badly), and a ruins fight screenshot with the new sprites among the old; read the images.
- `godot --headless --import` after adding sources, then the full suite and a smoke run.
