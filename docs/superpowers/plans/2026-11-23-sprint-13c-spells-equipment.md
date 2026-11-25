# Sprint 13c: Spells and Equipment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give combat the cartoon look: every spell Area skinned by element effect sprites over its exact hit area (Fire and Land rise, Thunder and Sea fall), one flying object per element for Missiles and Waves, element-coloured enemy shots, pixel warning marks and a pixel reticle, and a wizard who visibly wears the equipped robe, headwear and weapon.

**Architecture:** Spell and equipment looks are data (`ElementLook` resources, `EquipmentData.sprite_name` and `sprite_variant`), resolved through the 13a `SpriteLibrary`; a missing sprite keeps today's flat look. `EffectPlan` (pure) places and times effect sprites, `SpellSkin` dresses an Area, `EffectSprite` is the capped one-shot node. The wizard's base sprite is split into body and starter layers, and `BodyView` gains synced layers that `PlayerLook` fills from the equipped items. The exact hit polygons, timing and numbers never change.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, the 13a/13b art pipeline (`art/`, `tools/art/art_builder.gd`).

**Spec:** `docs/sprints/sprint-13c-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`, never Perl). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script and after the art tool. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, zsh does not word-split unquoted variables, and `rm` takes the full literal path (delete only what you created).
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`.
- **One pixel size everywhere (user rule): never scale or pixel-double a sprite.** Hit shapes may follow the exact numbers; every drawn sprite is 1:1 (`global_transform.get_scale()` is 1 for it, and an owner that is scaled must counter-scale as `BodyView.counter_scale` does). If something is too small, redraw it with more pixels.
- Art rules from the user: bright, simple, cartoon, few colours per object, a dark outline where it helps, and enemy attacks must stand out from the player's. A missing sprite, element or look falls back to today's flat look and never crashes or hides an attack.
- Gameplay does not change: hit shapes, damage, timing, `SpellData` and every number stay as they are. The skin is only a skin on the exact polygon.
- Tests never touch the real save (`save_path = ""`). Tests that instantiate `main.tscn` also set the pick screen's `pause_tree` to false.
- Replaceability: every sprite comes from a `.sprite` source and committed PNGs, the 13a asset test covers it, and `hand_drawn` still works.
- Hand-written `.tscn` files need `node_paths=PackedStringArray("prop")` for exported Node-typed properties set by NodePath. World and effect scenes must not add a `Control` that stops touches (`tests/test_world_input.gd`); use `mouse_filter = 2` on any `ColorRect`.
- Do not name a local or parameter after a `CanvasItem`/`Node` property (`material`, `name`, `scale`...): the MCP run flags it. Do not name a test helper `_set`.
- Real-window and MCP checks: run `mcp__godot__run_project` once per task that changes visuals, read `get_debug_output` for warnings, then `stop_project`. Throwaway real-window scripts live in the scratchpad, set `save_path` empty, and are deleted by exact path afterwards. Check screenshots with enemies, pickups and several effects on screen at once.
- The stress scene: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles` (about 115 fps median now), with `--area=missile|cone|zone|line|wave`, `--copies=N` and `--interval=SECONDS` to stress one spell.

## Review Focus

- A missing effect sprite, orb, element look, equipment sprite or layer set falls back to today's flat polygon, square, shot and wizard, never crashes and never hides a hit area or an enemy attack (Tasks 2 to 7).
- The skin is honest: effect sprites sit inside the exact hit polygon, the polygons, hitboxes, hit counts and timing are unchanged, a Zone repeats its sprites only at its damage ticks, and a Missile's hit size still follows `effective_size()` exactly while its drawing is one of three fixed classes (Tasks 3, 4 and 8).
- One pixel size: no effect, orb, mark, reticle or equipment-layer sprite is drawn at a scale other than 1, including inside the scaled missile node and the scaled wave (Tasks 3 to 7).
- Frame rate and caps: effect sprites per effect, live effect sprites and enemy shots are capped, a Duplicate Area cone at the casting rate stays playable, and every sprite is freed (Tasks 3, 4 and 8, measured with the stress scene).
- The wizard's layers: with nothing equipped the wizard is pixel-for-pixel today's, every layer follows the body's animation frame and flip in all 8 frames, equipping one slot never disturbs another, and enemy shots stay readable next to the player's bright effects (Tasks 5 to 8).

---

## File Structure

- Pipeline: `scripts/art/art_palette.gd` (`ELEMENT_VARIANTS`), `scripts/art/sprite_source.gd` (`variants`), `art/palette.txt` (item variants), `tests/test_art_sources.gd`, `tests/test_art_builder.gd`, `tests/test_art_assets.gd`.
- Spells: new `resources/spells/element_look.gd`, `resources/spells/element_looks/{fire,thunder,land,sea}.tres`, `scripts/spells/element_looks.gd` (static lookup), `scripts/spells/effect_plan.gd` (pure placement and timing), `scripts/spells/effect_sprite.gd` (the capped one-shot node), `scripts/spells/spell_skin.gd` (dresses an Area); modify `scripts/spells/areas/{cone,line,zone,missile,wave}_area.gd` and their scenes.
- Enemy attacks: `scripts/enemies/enemy_projectile.gd`, `scenes/enemies/enemy_projectile.tscn`, `scripts/enemies/blast_zone.gd`, `scripts/enemies/boss.gd`, `scripts/enemies/brain_keep_distance.gd`, `scripts/ui/target_reticle.gd`.
- Wizard: `scripts/entities/body_view.gd` (layers), new `scripts/entities/player_look.gd`, `scripts/entities/player.gd`, `scenes/player/player.tscn`, `scripts/progression/run_start.gd`, `resources/equipment/equipment_data.gd`, `resources/equipment/items/*.tres`.
- Art sources: `art/sprites/fx_*.sprite`, `reticle.sprite`, `player_body.sprite`, `robe_starter.sprite`, `hat_starter.sprite`, `robe_wizard.sprite`, `hat_pointed.sprite`, `hood_soft.sprite`, `wand_short.sprite`, `staff_tall.sprite` and their built files.
- Tests: new `tests/test_effect_plan.gd`, `test_effect_sprite.gd`, `test_spell_skin.gd`, `test_element_looks.gd`, `test_player_look.gd`; modify the area, projectile, blast zone, reticle, body view and art tests.

---

### Task 1: Palette variants for items and a `variants` line

**Files:**
- Modify: `scripts/art/art_palette.gd`, `scripts/art/sprite_source.gd`, `art/palette.txt`, `tests/test_art_sources.gd`, `tests/test_art_builder.gd`, `tests/test_art_assets.gd`

**Interfaces:**
- Produces: `ArtPalette.ELEMENT_VARIANTS: Array[StringName] = [&"none", &"fire", &"thunder", &"land", &"sea"]`. `SpriteSource.variants: Array[StringName]` (empty unless a `variants <id> <id> ...` line is present). `SpriteSource.variants_needed(palette)`: for a ramp sprite, the explicit `variants` when given, otherwise the element variants that exist in the palette; `[&"base"]` for a sprite with no ramp slot (unchanged). A `variants` line naming a variant the palette lacks is an error. Palette variants (five slots each, body dark, mid, light, trim dark, trim light): `hardy`, `mana`, `swift` (hat and hood trims), `flicker`, `quick` (wands), `oak`, `elder` (staffs).
- Result: the existing enemy sprites are built exactly as before (the element variants only), so no committed enemy file changes.

- [ ] **Step 1: Write the failing tests.** `test_art_sources`: `test_a_variants_line_limits_a_ramp_sprite_to_those_variants` (a source with ramp slot and `variants fire sea` gives `[&"fire", &"sea"]`), `test_without_a_variants_line_only_the_element_variants_are_built` (a palette with `none, fire, hardy` and a ramp sprite gives `[&"none", &"fire"]`), `test_a_variants_line_naming_an_unknown_variant_is_an_error`, `test_a_sprite_without_ramp_slots_is_still_built_once_as_base`. `test_art_builder`: `test_build_all_builds_only_the_named_variants` (a source with `variants hardy` and a palette holding `hardy` and `fire` writes `x_hardy.png` and no `x_fire.png`). `test_art_assets`: the palette test also asserts the seven item variants exist.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement** the constant, the `variants` line parsing and validation, `variants_needed`, and add the seven `variant` lines to `art/palette.txt` (bright, simple colours: hat and hood trims hardy a sturdy brown, mana a blue, swift a green; wands flicker an orange and quick a cyan; staffs oak a warm brown and elder a darker, redder brown). Keep the palette at 64 colours or fewer (the test checks).
- [ ] **Step 4: Run** the three files, run the art tool (`godot --headless -s tools/art/art_builder.gd`) and confirm `git status` shows no changed committed art, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: item colour variants and a variants line for sprites`.

### Task 2: Element looks and the effect plan

**Files:**
- Create: `resources/spells/element_look.gd`, `resources/spells/element_looks/{fire,thunder,land,sea}.tres`, `scripts/spells/element_looks.gd`, `scripts/spells/effect_plan.gd`, `tests/test_element_looks.gd`, `tests/test_effect_plan.gd`

**Interfaces:**
- Produces: `ElementLook` (Resource): `element: int` (`SpellData.Element`), `tint: Color` (the faint hit-area tint, alpha 0.25), `edge: Color` (the bright 1 px edge), `effect_sprite: StringName` (`fx_fire_burst`, `fx_land_spike`, `fx_thunder_bolt`, `fx_sea_splash`), `orb_sprite: StringName` (a prefix: `fx_fire_orb`, `fx_land_orb`, `fx_thunder_orb`, `fx_sea_orb`, with `_12`, `_16` and `_24` size suffixes), `rises: bool` (true for Fire and Land, false for Thunder and Sea). `ElementLooks.for_element(element: int) -> ElementLook` (loads and caches the four resources; null for `SpellData.NO_ELEMENT` or any unknown value).
- Produces `EffectPlan` (RefCounted, static, pure): `AREA_PER_SPRITE := 600.0`, `MIN_SPRITES := 3`, `MAX_SPRITES := 24`; `count_for(area: float) -> int` (area / 600 rounded, clamped 3 to 24); `spots(polygon: PackedVector2Array, count: int, rng: RandomNumberGenerator) -> Array[Vector2]` (points inside the polygon, spread by a best-candidate rule with 10 candidates each, deterministic for a seed; fewer than `count` only when the polygon has no room; a degenerate polygon gives an empty array); `delays(spots: Array[Vector2], rises: bool, origin: Vector2, window: float, rng: RandomNumberGenerator) -> Array[float]` (one delay per spot in `[0, window]`; rising sorts by distance from `origin` so the nearest starts first, falling uses a seeded random order).

- [ ] **Step 1: Write the failing tests.** `test_element_looks`: `test_each_element_has_a_look_with_its_sprites_and_direction` (Fire and Land rise, Thunder and Sea fall; every sprite name starts with `fx_`), `test_no_element_and_unknown_values_have_no_look`, `test_the_looks_are_cached`. `test_effect_plan`: `test_count_follows_the_area_within_the_limits` (0 gives 3, 6000 gives 10, 1e9 gives 24), `test_spots_are_inside_the_polygon_and_deterministic`, `test_spots_are_spread_out_not_clumped` (for a 200x120 rectangle and 12 spots the closest pair is farther apart than for the same spots chosen uniformly at random with the same seed would typically be, assert a minimum distance of 15), `test_a_degenerate_polygon_gives_no_spots`, `test_rising_delays_start_nearest_the_origin_first` (delays are non-decreasing with distance), `test_falling_delays_are_in_range_and_not_distance_ordered_for_a_fixed_seed`, `test_every_delay_is_within_the_window`.
- [ ] **Step 2: Run** the two files. Expected: FAIL.
- [ ] **Step 3: Implement** the resource, the four `.tres` (tints and edges from the element colours in the README: Fire orange red and yellow, Thunder yellow and electric blue, Land brown and green, Sea blue and cyan), the lookup and `EffectPlan`; run `godot --headless --import`.
- [ ] **Step 4: Run** the two files and the whole suite. Expected: PASS (nothing is drawn differently yet).
- [ ] **Step 5: Commit** `feat: element looks and the effect plan`.

### Task 3: Effect sprites on the Cone, Line and Zone

**Files:**
- Create: `art/sprites/fx_fire_burst.sprite`, `fx_land_spike.sprite`, `fx_thunder_bolt.sprite`, `fx_sea_splash.sprite` (and built files), `scripts/spells/effect_sprite.gd`, `scripts/spells/spell_skin.gd`, `tests/test_effect_sprite.gd`, `tests/test_spell_skin.gd`
- Modify: `scripts/spells/areas/cone_area.gd`, `line_area.gd`, `zone_area.gd`, `tests/test_cone_area.gd`, `test_line_area.gd`, `test_zone_area.gd`

**Interfaces:**
- Consumes: `ElementLooks`, `EffectPlan` (Task 2), `SpriteLibrary`.
- Produces: effect sprites, each one animation `play` once (about 6 frames at 12 fps): `fx_fire_burst` a flame bursting up (16x24), `fx_land_spike` rock spikes pushing up (16x24), `fx_thunder_bolt` a bolt striking down (12x32 including its flash), `fx_sea_splash` water crashing down and splashing (16x24); drawn bright, simple, with a dark outline.
- Produces `EffectSprite` (extends `AnimatedSprite2D`): `static spawn(parent: Node, sprite_name: StringName, at: Vector2, delay: float, fade_time: float) -> EffectSprite` (null with no art; hidden for `delay` seconds, then plays `play` once, then fades over `fade_time` and frees itself; group `effect_sprites`, `MAX_LIVE := 160` with the oldest freed first when a new one would exceed it; never scaled).
- Produces `SpellSkin` (RefCounted, static): `dress(area: Node2D, visual: Polygon2D, polygon: PackedVector2Array, spell: SpellData, origin: Vector2, life: float, rng: RandomNumberGenerator) -> void`. With an `ElementLook` for each of the spell's elements (cycled sprite by sprite) it sets `visual.color` to the look's tint, adds a `Line2D` named `Edge` along the polygon in the look's edge colour (1 px wide, `visual`'s child so it fades with it), and spawns `EffectPlan.count_for(area)` effect sprites at `EffectPlan.spots(...)` under `area` with `EffectPlan.delays(...)` over the first 40% of `life` and a fade over the last 30%. With no look or no art it changes nothing (the flat polygon with `spell.color` stays) and spawns nothing. `SpellSkin.pulse(area, polygon, spell, origin, life, rng)` spawns a fresh set only (no tint, no edge) for a Zone's damage ticks.
- Cone, Line and Zone call `SpellSkin.dress` in `launch` with their exact polygon (a Zone's circle outline), and the Zone calls `SpellSkin.pulse` at each damage tick (using its existing tick timer). The polygons, shapes, hitboxes, durations and ticks do not change.

- [ ] **Step 1: Write the failing tests.** `test_effect_sprite`: `test_it_waits_plays_once_fades_and_frees`, `test_it_is_never_scaled` (global scale 1 under a scaled parent chain only if the caller does not scale it; assert its own `scale == Vector2.ONE`), `test_a_missing_sprite_spawns_nothing`, `test_the_live_cap_frees_the_oldest`. `test_spell_skin`: `test_a_fire_cone_gets_a_tint_an_edge_and_sprites_inside_the_polygon`, `test_every_sprite_spot_is_inside_the_exact_polygon`, `test_rising_effects_start_near_the_caster_first_and_falling_ones_do_not` (compare the delays), `test_a_hybrid_spell_uses_each_of_its_elements`, `test_no_element_look_leaves_the_flat_polygon_and_spawns_nothing`, `test_a_missing_sprite_leaves_the_tint_but_spawns_nothing_and_never_fails`, `test_the_count_follows_the_area_within_the_caps`. Area tests: `test_the_cone_polygon_and_hitbox_are_unchanged_by_the_skin` (the hitbox polygon equals `ConeArea._sector(...)`), the same for Line (rectangle) and Zone (radius), `test_a_zone_spawns_a_fresh_set_at_each_tick_and_not_between`, `test_the_skin_never_changes_what_a_cast_hits` (one enemy inside and one outside, the same hits as before).
- [ ] **Step 2: Run** the new and area test files. Expected: FAIL.
- [ ] **Step 3: Author the four effect sprites** (`play` once), build with the art tool and `--import`, implement `EffectSprite`, `SpellSkin`, the three Area changes, and update the existing area tests only where they read the old flat colour, deliberately. Look at real-window screenshots of each element's Cone, Line and Zone, with enemies inside them and on the floor of two regions.
- [ ] **Step 4: Run** the new tests, `test_cone_area`, `test_line_area`, `test_zone_area`, `test_art_assets`, `test_world_input`, the whole suite, one MCP run and the stress run `--area=cone --copies=5 --interval=0.4` before and after (record both). Expected: PASS, no warnings, the stress median within about 15% of before.
- [ ] **Step 5: Commit** `feat: element effect sprites over the cone, line and zone`.

### Task 4: Missiles and Waves as flying objects

**Files:**
- Create: `art/sprites/fx_fire_orb_12.sprite`, `fx_fire_orb_16.sprite`, `fx_fire_orb_24.sprite` and the same for `land`, `thunder` and `sea` (12 sprites, 2 frames each, `fly` loop at 8 fps, and built files)
- Modify: `scripts/spells/areas/missile_area.gd`, `scenes/spells/areas/missile_area.tscn`, `scripts/spells/areas/wave_area.gd`, `scenes/spells/areas/wave_area.tscn`, `tests/test_missile_area.gd`, `tests/test_wave_area.gd`

**Interfaces:**
- Consumes: `ElementLooks`, `BodyView` (13a).
- Produces: orb sprites (a fireball, a rock, a lightning orb, a water ball; bright, simple, dark outline, a short trail drawn into the frames), three size classes. `MissileArea.orb_class(size: float) -> int` (static: 12 up to a size scale of 1.2, 16 up to 2.0, otherwise 24). The Missile's hit size must keep following `effective_size()` exactly: the old code scaled the whole node, so the drawn square scaled with it. The node stays unscaled now, the hitbox shape is scaled instead (`_hitbox.scale`), and the visual is a `Body` `BodyView` playing `fly` with the sprite of the spell's first element in the right class. With no look or no art the old `ColorRect` square is shown, scaled as before.
- Produces: the Wave's visual is a row of orb sprites (`Body` `BodyView`s, class 12 or 16 by the same rule) spaced about 10 px apart along the crescent's front, re-spaced as the wave widens (their positions follow `current_width()`; the sprites are never scaled), and the flat crescent stays as the fallback and as the faint tint of the exact hit area. The Wave's hitbox scale stays as it is.

- [ ] **Step 1: Write the failing tests.** `test_missile_area`: `test_orb_class_follows_the_size_in_three_steps`, `test_the_missile_shows_its_elements_orb_one_to_one_whatever_its_size` (the sprite's global scale is 1 at a large size), `test_the_hit_shape_still_follows_the_exact_size` (the hitbox's world extent equals the old one for a size of 1.0, 1.5 and 3.0), `test_a_missile_without_art_keeps_the_scaled_square`, update `test_..._tint` that read `Body.color` deliberately. `test_wave_area`: `test_the_wave_is_a_row_of_orbs_along_its_front`, `test_the_orbs_follow_the_widening_front_and_stay_one_to_one`, `test_the_wave_hitbox_and_crescent_are_unchanged`, `test_a_wave_without_art_keeps_the_flat_crescent`.
- [ ] **Step 2: Run** the two files. Expected: FAIL.
- [ ] **Step 3: Author the 12 orb sprites**, build, `--import`, implement the Missile and Wave changes, and look at real-window screenshots of each element's Missile (at three sizes) and Wave.
- [ ] **Step 4: Run** the two area test files, `test_spell_loadout` and every other test that reads the missile or wave (`-gselect` each, then the whole suite), one MCP run and the stress runs `--area=missile` and `--area=wave`. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: one flying object per element for missiles and waves`.

### Task 5: Enemy shots, blast zones, the boss warning and the reticle

**Files:**
- Create: `art/sprites/fx_enemy_orb.sprite` (a ramp sprite, 8x8, `fly` loop, element colours through the element variants), `fx_warning_mark.sprite` (8x8, two frames), `fx_blast_burst.sprite` (32x32, `play` once), `reticle.sprite` (12x12, 2 frames) and built files
- Modify: `scripts/enemies/enemy_projectile.gd`, `scenes/enemies/enemy_projectile.tscn`, `scripts/enemies/blast_zone.gd`, `scenes/enemies/blast_zone.tscn`, `scripts/enemies/boss.gd`, `scripts/enemies/brain_keep_distance.gd`, `scripts/ui/target_reticle.gd`, `tests/test_enemy_projectile.gd`, `tests/test_blast_zone.gd`, `tests/test_target_reticle.gd`

**Interfaces:**
- Produces: `EnemyProjectile.fire(parent, scene, origin, direction, speed, damage, max_range, element_id: StringName = &"")` (a new last parameter with a default, so every existing call still works). The scene's `Body` becomes a `BodyView` showing `fx_enemy_orb` in the colours of `element_id` (`none` for an empty id), playing `fly`; with no art it keeps the coloured square. `BrainKeepDistance` passes `enemy.data.element_id` and the boss passes its element's id (from `BossData.element`, mapped the same way `EnemyComposer` names elements: fire, thunder, land, sea, none). The shot's size, hitbox, speed, range, cap and hit rules do not change.
- Produces: `BlastZone` draws its warning with sprites: a faint flat tint (as now, translucent), an outer ring of `fx_warning_mark` sprites on the circle (count `max(8, round(TAU * radius / 10))`, dim) and an inner ring at `radius * progress` (bright, flashing with the second frame) while the fuse burns, then `fx_blast_burst` (counter-scaled, never scaled) at detonation. The radius, damage, fuse, one-shot check and cancel rule do not change; with no art the old circles are drawn.
- Produces: the boss's Charge warning line is drawn with the same `fx_warning_mark` sprites along the dash line instead of `draw_line`.
- Produces: `TargetReticle` shows `reticle` (a `BodyView`-free `AnimatedSprite2D` or a `BodyView`) instead of the arc and dot; with no art the old drawing stays.

- [ ] **Step 1: Write the failing tests.** `test_enemy_projectile`: `test_a_shot_takes_the_shooters_element_colours` (a fire id and a sea id give different sprite frames; an empty id gives the `none` colours), `test_a_shot_without_art_keeps_its_square`, `test_every_existing_fire_call_still_works_with_no_element`, `test_the_shot_hit_rules_and_cap_are_unchanged` (the existing cap and one-hit tests still pass). `test_blast_zone`: `test_the_warning_has_two_rings_of_marks_that_scale_with_the_radius`, `test_the_inner_ring_grows_with_the_fuse`, `test_detonation_shows_the_burst_and_the_zone_still_hits_once`, `test_a_cancelled_zone_shows_no_burst`, `test_a_zone_without_art_still_draws_its_circles`. Boss: `test_the_charge_warning_uses_marks_along_the_dash_line`. Reticle: `test_the_reticle_uses_its_sprite_and_falls_back_to_the_drawn_circle`. Every sprite here has global scale 1.
- [ ] **Step 2: Run** the touched test files. Expected: FAIL.
- [ ] **Step 3: Author the four sprites** (an outlined round orb, a bold warning mark, a burst of flame with a flash, a small crosshair), build, `--import`, implement the changes, and look at real-window screenshots of a Ranged enemy's shots next to the player's spells, a blast zone through its fuse and detonation, the boss's slam and charge warnings and the reticle.
- [ ] **Step 4: Run** the touched files, `test_enemy_brains`, `test_boss`, `test_enemy_spawner`, `test_world_input`, the whole suite, one MCP run and the stress run with `--boss`. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: element shots, pixel warnings and a pixel reticle`.

### Task 6: The wizard in layers

**Files:**
- Create: `art/sprites/player_body.sprite`, `robe_starter.sprite`, `hat_starter.sprite` (and built files), `scripts/entities/player_look.gd`, `tests/test_player_look.gd`
- Modify: `scripts/entities/body_view.gd`, `scripts/entities/player.gd`, `scenes/player/player.tscn`, `tests/test_body_view.gd`, `tests/test_player_art.gd`

**Interfaces:**
- Consumes: `BodyView`, the 13a player sprite (`art/sprites/player.sprite`, 16x16, 8 frames: `idle` 0-1, `move` 2-5, `cast` 6-7), which stays in the repo unchanged as the composite reference and the fallback.
- Produces the three layer sources from the existing grid (a throwaway splitter script classifies pixels by letter and row: the body keeps skin, face, hands, boots and their outline; the starter robe takes the purple robe rows and shoulders; the starter hat takes the hat, band and brim), each 16x16 with the same 8 frames and animations as `player.sprite`.
- Produces `BodyView` layers: `add_layer(layer_name: StringName) -> void` (a layer is an `AnimatedSprite2D` child drawn above the body sprite and above earlier layers, in the order added), `set_layer(layer_name: StringName, sprite_name: StringName, variant: StringName = &"base") -> bool` (false and the layer hidden when there is no art), `clear_layer(layer_name: StringName) -> void`, `layer_names() -> Array[StringName]`. While any layer is shown it copies the body sprite's animation, frame and flip every frame (`_process` is enabled only then, so plain enemies still run nothing). Layers are never scaled (`counter_scale` applies to them too).
- Produces `PlayerLook` (RefCounted, static): `apply(body: BodyView, profile: PlayerProfile, catalog: EquipmentCatalog) -> void` sets the layers `robe`, `headwear` and `weapon` in that order from `profile.equipped` using the same ownership and slot rules as `ShopSystem.bonuses` (an unknown, unowned or misplaced id is ignored); with nothing equipped in a slot, `robe` and `headwear` show `robe_starter` and `hat_starter` and `weapon` shows nothing. Equipped items use `EquipmentData.sprite_name` and `sprite_variant` (added in Task 7; this task uses only the starters).
- `Player._ready` shows `player_body` with `add_layer` for the three layers and `PlayerLook`'s starters when `player_body` has art, and otherwise falls back to `set_look(&"player")` with no layers; the cast, move and idle animation logic and the flip do not change.

- [ ] **Step 1: Write the failing tests.** `test_body_view`: `test_a_layer_follows_the_bodys_animation_frame_and_flip`, `test_layers_draw_above_the_body_in_the_order_added`, `test_a_layer_is_never_scaled_under_a_scaled_owner`, `test_a_layer_with_no_art_is_hidden_and_never_fails`, `test_clear_layer_hides_it`, `test_only_a_shown_layer_turns_processing_on`. `test_player_look`: `test_the_starter_layers_compose_to_exactly_todays_wizard` (alpha-blend `player_body`, then `robe_starter`, then `hat_starter`, frame by frame, and assert every pixel equals `player_base.png`'s, with eight frames), `test_every_layer_set_has_the_players_animations_and_frame_count`, `test_with_nothing_equipped_the_starters_show_and_the_weapon_does_not`, `test_an_unowned_or_misplaced_item_is_ignored`, `test_applying_twice_changes_nothing`. `test_player_art`: update only what reads the single player sprite, deliberately.
- [ ] **Step 2: Run** the touched files. Expected: FAIL.
- [ ] **Step 3: Split the sprite** with a throwaway splitter, build, `--import`, implement the `BodyView` layers, `PlayerLook`'s starters and the `Player` change, and compare a real-window screenshot of the wizard (idle, walking, casting, facing both ways) with a pre-change screenshot: they must be identical.
- [ ] **Step 4: Run** the touched files, `test_player`, `test_player_art`, `test_main`, the whole suite, one MCP run and a stress run (the layers run for one body only). Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: the wizard drawn in layers`.

### Task 7: Equipment art and data

**Files:**
- Create: `art/sprites/robe_wizard.sprite` (variants `fire land thunder sea none`), `hat_pointed.sprite` and `hood_soft.sprite` (variants `hardy mana swift`), `wand_short.sprite` (variants `flicker quick`), `staff_tall.sprite` (variants `oak elder`), and built files
- Modify: `resources/equipment/equipment_data.gd`, `resources/equipment/items/*.tres` (15 files), `scripts/entities/player_look.gd`, `scripts/progression/run_start.gd`, `tests/test_player_look.gd`, `tests/test_equipment_data.gd`, `tests/test_run_start.gd`

**Interfaces:**
- Consumes: Task 1 (`variants`), Task 6 (`BodyView` layers, `PlayerLook`).
- Produces: `EquipmentData.sprite_name: StringName` and `sprite_variant: StringName` (empty means no sprite). The 15 items: Ember robe `robe_wizard` fire, Stone land, Storm thunder, Tide sea, Warded none; every Hat `hat_pointed` and every Hood `hood_soft` with variants `hardy`, `mana`, `swift` matching the item's name; Wands `wand_short` with `flicker` and `quick`; Staffs `staff_tall` with `oak` and `elder`. Each sprite has the wizard's 8 frames and animations and is anchored to the body (the robe over the robe area, the headwear over the head and replacing the starter hat, the weapon in the hand in every frame including the cast).
- `PlayerLook.apply` uses an equipped item's `sprite_name` and `sprite_variant` when set and the starter (robe, headwear) or nothing (weapon) when not. `RunStart.prepare` calls it with the player's `Body`, the profile and the catalog, after the stats. Equipping in the shop takes effect at the next run start, like the bonuses.

- [ ] **Step 1: Write the failing tests.** `test_equipment_data`: `test_every_shipped_item_names_a_sprite_and_a_variant_that_exist` (loads the catalog; each item's `WorldArt`-style lookup through `SpriteLibrary.find(sprite_name, sprite_variant)` is not null and is not the `base` fallback). `test_player_look`: `test_each_equipped_robe_headwear_and_weapon_replaces_its_slot_only`, `test_a_hood_replaces_the_starter_hat_so_no_hat_shows_through`, `test_every_equipment_layer_set_matches_the_players_animations_and_frames`, `test_layers_are_anchored_in_every_frame` (for each of the 8 frames, a layer's drawn pixels lie inside the 16x16 body area and a weapon's lowest-left pixel is within 2 px of the body's hand pixel for that frame, measured from the sources). `test_run_start`: `test_run_start_puts_the_equipped_items_on_the_wizard`, `test_running_it_twice_changes_nothing`.
- [ ] **Step 2: Run** the touched files. Expected: FAIL.
- [ ] **Step 3: Author the five equipment sprites** (one robe shape, a pointed hat, a soft hood, a short wand, a tall staff: bright, simple, ramp slots so the variants recolour them; the headwear covers the starter hat, the robe covers the starter robe), build, `--import`, add the two fields and set them on all 15 items, extend `PlayerLook` and `RunStart`, then look at real-window screenshots of the wizard in several combinations (all five robes, a hat and a hood in each trim, each wand and staff, idle, moving and casting, facing both ways).
- [ ] **Step 4: Run** the touched files, `test_art_assets`, `test_shop_system`, `test_equipment_catalog`, the whole suite and one MCP run. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: the wizard wears its equipment`.

### Task 8: Verify and document

**Files:**
- Modify: `sprint-development.md`, `README.md`, `technical-design.md`, `CLAUDE.md`, `development-log.md`, `docs/sprints/sprint-13c-design.md` (Status: Built)

- [ ] **Step 1: Smoke and MCP run.** `godot --headless --quit-after 60` is clean. Run the project with `mcp__godot__run_project`, read `get_debug_output`, then `stop_project`.
- [ ] **Step 2: Stress.** Four runs each of the full scene and of `--area=cone --copies=5 --interval=0.4`, `--area=zone`, `--area=wave` and `--boss`, medians, compared with `main` measured in the same session in a throwaway worktree. Record all in the log.
- [ ] **Step 3: Real-window check.** A throwaway script (`save_path` empty): a run in progress with enemies and drops, a crafted spell of each element and each Area cast (including a hybrid and a Duplicate Area), a Ranged enemy and the boss attacking at the same time, the reticle, and the wizard in several equipment combinations; confirm effects sit inside their hit areas, enemy attacks stand out from the player's, nothing hides drops, and pixels are the same size everywhere. Prove replaceability in a throwaway copy of the project: overwrite one effect or orb PNG and one equipment PNG with recoloured copies and confirm the game shows them, then delete the copy by its exact path.
- [ ] **Step 4: Docs.** `sprint-development.md`: tick the elemental spell sprites, equipment sprites and spell projectile and impact animation items 13c covers, and add a Built note. `README.md`: the spell and equipment look and how to replace it. `technical-design.md`: the new files. `CLAUDE.md`: a "Spell and equipment art (Sprint 13c)" section (`ElementLook`, `EffectPlan`, `EffectSprite`, `SpellSkin`, the caps, the missile size classes and the unscaled node, enemy shot elements, warning marks, `BodyView` layers, `PlayerLook`, the starter layers and the pixel-equality test, `EquipmentData.sprite_name` and `sprite_variant`, the `variants` line and `ELEMENT_VARIANTS`, the stress numbers). `development-log.md`: the 13c entry. Set the design doc's status to Built.
- [ ] **Step 5: Full suite and commit** `docs: Sprint 13c complete`.
