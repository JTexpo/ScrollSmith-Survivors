# Sprint 16c: The Ruins' Art Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The ruins show a bandit (standard), a mimic (chaser) and an elemental (ranged) of their own, found by the existing `enemy_<set>_<type>` lookup, with no change to any behaviour.

**Architecture:** Three new ramp sprites `enemy_ruins_standard`, `enemy_ruins_chaser`, `enemy_ruins_ranged` built by the art tool; `Enemy.look_sprite()` (16a) already prefers `enemy_<set>_<type>`, so no code changes. The forest and maze keep the plain `enemy_<type>` sprites through the fallback; nothing is renamed (the user's option A).

**Tech Stack:** Godot 4.7 GDScript, GUT, the art tool (`tools/art/art_builder.gd`).

**Spec:** `sprint-16c-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`); never bare `python3`; scripted edits use `venv/bin/python`; Edit tool first; scratch files in the scratchpad directory, never `/tmp`. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; one file: add `-gselect=<file>` (one file only). After editing a `.sprite`, run `godot --headless -s tools/art/art_builder.gd` and then `godot --headless --import`. **Never run two Godot processes at once**; run the full suite alone, in the background for `task-done`.
- Art only: no change to any script, scene, enemy stat, element, spawn config, reward, boss or sound. The forest and maze keep the goblin, wolf and kobold through the fallback; the slime, armour, imp (mephit) and cultist stay exactly as they are; no existing sprite is renamed or edited.
- Sprite rules: sizes and animations exactly those of the sprite replaced (bandit 14 by 14 with `move` 0-1 6 fps loop and `death` 2-3 12 fps once; mimic 12 by 12 with the same two; elemental 14 by 14 with `move` 0-1 6 fps loop, `death` 2-3 12 fps once and `attack` 4-5 12 fps once); ramp sprites use only slots `1` to `5` and fixed letters from `art/palette.txt` (55 of 64 colours used; add none unless truly needed); a 1 px transparent margin on every frame; no skin colours; one pixel size, never scaled or rotated; bright, simple, cartoon. Built in the five element colourways (the ramp default).
- Method (as 16b): compose each sprite with a scratchpad Python generator (simple shapes plus an automatic 1 px outline, which keeps the margin rule), write the `.sprite` source, build, **look at contact sheets in the five colourways and redraw anything that reads badly** before committing. The committed `.sprite` grids are the source; the generator is scratch.
- Tests never touch the real save or settings and never really change scene.

## Review Focus

- **Lookup:** the ruins resolve the three new sprites and the other four archetypes through `enemy_<type>`; the forest resolves its four 16b sprites and the fallback for standard, chaser and ranged (still the goblin, wolf and kobold); the maze resolves the fallback for all seven; an empty or unknown set is unchanged.
- **Animations:** the new sprites have exactly the animation names, frame counts, fps and loop flags of the plain sprites they stand beside, so the Ranged brain's `attack`, the death animation that frees the enemy and the hit shapes behave as before; elites (outline from the silhouette) work on them.
- **Art:** no stale output, no pixel outside the palette, no frame touching its margin, every colourway loads; none of the three reads as the goblin, wolf or kobold.
- **No behaviour change:** the composed `EnemyData` does not depend on the art set; every older enemy, brain, spawner and map test passes unchanged except the two named below.

---

### Task 1: The three ruins sprites and their lookup tests

**Files:**
- Create: `art/sprites/enemy_ruins_standard.sprite`, `art/sprites/enemy_ruins_chaser.sprite`, `art/sprites/enemy_ruins_ranged.sprite`, their built outputs in `assets/sprites/` (committed), `tests/test_ruins_art.gd`
- Modify: `tests/test_forest_art.gd` (`test_the_ruins_and_maze_sets_are_unchanged`), `tests/test_enemy_art_sets.gd` (`test_the_ruins_enemies_look_exactly_as_before`)
- Reference: `art/sprites/enemy_standard.sprite`, `enemy_chaser.sprite`, `enemy_ranged.sprite` (headers and animation layout), `art/palette.txt`, the 16b forest sprites in `art/sprites/enemy_forest_*.sprite` for the style

**Interfaces:**
- Consumes: the 16a lookup (`Enemy.look_sprite()`, `EnemySpawner.enemy_art_set`).
- Produces: sprites `enemy_ruins_standard` (a bandit: a hooded rogue in a mask, a bandana tail and a dagger, 14 by 14), `enemy_ruins_chaser` (a mimic: a treasure chest with an open toothy lid, a tongue and stubby legs, metal bands in the trim colour, 12 by 12), `enemy_ruins_ranged` (an elemental: a floating spirit with a swirling core and a glow, its `attack` frames flaring bright as it throws, 14 by 14), with the animations in Global Constraints, in the five colourways.

- [ ] **Step 1: Write the failing tests** (`test_ruins_art`; reuse the helper style of `test_forest_art`): `test_the_ruins_resolve_the_three_new_sprites_in_every_colourway` (for standard, chaser, ranged and each of `none fire thunder land sea`, `SpriteLibrary.find(&"enemy_ruins_<type>", element)` is not null with the frame size of the plain sprite, and each has a silhouette), `test_each_new_ruins_sprite_has_the_animations_of_the_sprite_beside_it` (same animation names, frame counts, fps and loop flags as `enemy_<type>`), `test_the_ranged_elemental_has_its_attack_animation` (`attack`, 2 frames, 12 fps, not looping), `test_an_enemy_in_the_ruins_set_uses_the_new_sprite_for_three_archetypes` (build an `Enemy` per archetype with `art_set = &"ruins"`: `look_sprite()` is `enemy_ruins_<type>` for standard, chaser and ranged and `enemy_<type>` for swarmer, tank, exploder and support; `has_art()` is true for all seven), `test_the_forest_and_maze_still_resolve_the_old_sprites_for_these_three` (forest: `enemy_standard`, `enemy_chaser`, `enemy_ranged`; maze: all seven plain; the forest's four 16b sprites still resolve), `test_an_unknown_or_empty_set_is_unchanged`, `test_every_ruins_archetype_and_element_is_drawn_with_art` (35 combinations, never a square), `test_an_elite_ruins_enemy_gets_an_outline_from_the_silhouette` (an elite `Enemy` of each of the three with `art_set = &"ruins"` shows its outline via the existing elite path). Update the two older tests: in `test_forest_art`, `test_the_ruins_and_maze_sets_are_unchanged` keeps the maze and empty set but the ruins now expect the new sprites for the three (rename it `test_the_maze_and_empty_sets_are_unchanged`); in `test_enemy_art_sets`, `test_the_ruins_enemies_look_exactly_as_before` compares the ruins with the plain look only for swarmer, tank, exploder and support. Run. Expected: FAIL (new sprites missing; the updated tests fail on the old data).
- [ ] **Step 2: Compose and write the three `.sprite` sources** with a scratchpad generator (shapes plus an automatic outline; frames in the order the headers name: move A and B, death squash and a pop of sparkles like the others, and for the elemental the two attack frames). Run `godot --headless -s tools/art/art_builder.gd`, `godot --headless --import`.
- [ ] **Step 3: Look at them.** With a throwaway scratchpad GDScript (headless is fine: it loads the built sheets, scales them 5x nearest, composes the five colourways of each sprite on a stone-grey background and saves a PNG) read the images; redraw any frame or sprite that reads badly (the bandit must not read as the goblin, the mimic as a chest not a wolf, the elemental as a spirit not the kobold), rebuild and look again. Record in the ledger what the images showed.
- [ ] **Step 4: Run** `test_ruins_art`, `test_forest_art`, `test_enemy_art_sets`, `test_enemy_art`, `test_art_assets` (stale output, palette, margins, orphans) and then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: ruins enemy sprites (bandit, mimic, elemental)`.

---

### Task 2: Nothing but the look changed, the window check and the docs

**Files:**
- Create: `tests/test_art_set_is_only_a_look.gd`
- Modify: `CLAUDE.md`, `development-log.md`, `sprint-development.md`, `sprint-16c-design.md` (status line)
- Create (scratchpad only): the window screenshot script

**Interfaces:**
- Consumes: Task 1.

- [ ] **Step 1: Write the failing-or-passing safety test** (`test_art_set_is_only_a_look`): `test_the_composed_enemy_data_does_not_depend_on_the_art_set` (for each of the seven archetypes and five elements, an `Enemy` set up with `art_set` `&""`, `&"ruins"`, `&"forest"` and `&"maze"` has the same `data` resource, speed, maximum health, contact damage, element and rewards), `test_the_hit_shapes_do_not_depend_on_the_art_set` (the hurtbox and hitbox shape sizes and the node scale are equal across the four sets), `test_the_ranged_brain_still_plays_attack_on_the_new_elemental` (a ranged `Enemy` with `art_set = &"ruins"` and a player in range calls `show_state(&"attack", ...)` and the body's current animation becomes `attack`). Run. Expected: PASS (this pins behaviour that must not change; if any assertion fails it is a real finding to fix, with a failing test first).
- [ ] **Step 2: Real-window check.** A throwaway scratchpad script (windowed, `HOME` pointed at a scratch folder): launch `main.tscn` (the ruins), set the player's health very high, stop the spawner's own timer, spawn a crowd (`spawn_at`) so every archetype appears, take a screenshot, and read it; do the same on `main_forest.tscn` to confirm the forest still shows the goblin, wolf and kobold. If a sprite reads badly in the game (too dark on the ruins' floor, too like another enemy) redraw it and rebuild.
- [ ] **Step 3: Docs.** `CLAUDE.md`: a short "The ruins' art refresh (Sprint 16c)" section (the three sprites and what each is, that nothing was renamed (option A) and that the plain `enemy_<type>` sprites are now the forest's (goblin, wolf, kobold), the maze's (all seven, until 16d) and the ruins' (slime, armour, imp, cultist) fallback, the follow-up renaming in 16d, how it was checked) and update the Project State line; `development-log.md` entry; `sprint-development.md` marks 16c done and notes the 16d renaming; the design doc's status becomes "Implemented".
- [ ] **Step 4: Full suite and smoke run.** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` and `godot --headless --quit-after 60`. Expected: all green; the only warning is the known home-scene exit leak.
- [ ] **Step 5: Commit** `feat: ruins art checks and Sprint 16c docs`.
