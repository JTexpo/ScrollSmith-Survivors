# Sprint 13f: Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make remaining health and spell impact impossible to miss: an escalating low-health warning (a beating heart, a pulsing dithered red edge frame, a quiet heartbeat, hurt flashes and hit arcs) and an **impact weight** per spell that scales a pixel-particle burst, a whole-pixel screen shake, a soft flash and the hit sound, plus light touches (pickup sparks, low-mana pulse, level-up stars, Rare-drop sparkle).

**Architecture:** `ImpactConfig` (data) and `FxSettings` (two scale numbers) drive everything. `ImpactWeight` (pure) turns a spell's wait and damage into 0..1. The shared `AreaEffect._configure_hitbox` announces each hit through the static `ImpactEvents` emitter. One `FxDirector` node in `main.tscn` listens (impacts, blasts, the player's hurt, level-ups, pickups, drops, low mana) and owns the pooled `BurstLayer` (one `_draw`, a fixed pool), `CameraShake` (whole-pixel offsets) and the flash. `LowHealthWarning` reads health and shows a procedurally built dithered edge frame. `SoundBoard` plays the existing hit sounds lower and louder for heavy impacts. Gameplay code only announces; nothing it does changes.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, the 13a to 13e art and audio pipelines.

**Spec:** `sprint-13f-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`, never Perl, and never a bare `python3 -` that waits on stdin). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file; GUT matches ONE file name per run). Run `godot --headless --import` after adding or renaming a `class_name` script and BEFORE and AFTER running the art tool (`godot --headless -s tools/art/art_builder.gd`). On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, zsh does not word-split unquoted variables, and `rm` takes the full literal path (delete only what you created). Wrap test and tool runs in `timeout`.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`.
- **One pixel size everywhere (user rule): never scale or rotate a sprite or node for an effect.** Particles are whole-pixel squares and twinkles at rounded positions, the camera shakes in whole pixels, arcs are flipped (never rotated), the frame is a 480 by 270 pixel image shown at scale 1, and the heart swaps between two drawings.
- **Comfort limits (pinned by tests):** shake at most 4 px at full weight, flash at most 12% opacity for about 80 ms and at most every 330 ms (about 3 a second), the low-health pulse never above 40% opacity and never faster than 2 Hz. `FxSettings.shake_scale` and `flash_scale` (default 1.0) scale them; 0 turns them off.
- **I can neither see nor feel.** Verify with tests, real-window screenshots and numbers, and say in every report that the feel was not judged. The user tunes through the effects-test scene (Task 7).
- **Gameplay does not change and gameplay code does not call effects.** Only `FxDirector` and its parts act; they react to signals. The few new announcements (`ImpactEvents.hit`, `ScrollDropper.placed`, `SpellSlotWidget.went_low` if needed) change nothing. No new autoload.
- Tests never touch the real save (`save_path = ""`). Tests that instantiate `main.tscn` also set the pick screen's `pause_tree` to false, and must not leave `get_tree().paused`, the camera offset, the AudioServer or `FxSettings` changed (restore in `after_each`).
- Do not name a local or parameter after a `CanvasItem` or `Node` property (`name`, `scale`, `position`, `offset`, `modulate`...): the MCP run flags it. Do not name a test helper `_set`. Run `mcp__godot__run_project` once per task that changes the running game, read `get_debug_output`, then `stop_project`.
- The stress scene: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles` (about 105 to 120 fps now, noisy).

## Review Focus

- Effects never hide the fight or bother a player: shake, flash and pulse stay inside their pinned limits at any weight and at the busiest hit rates, nothing is scaled or rotated, particle positions are whole pixels, and `FxSettings` at 0 really turns shake and flash off (Tasks 2, 3 and 5).
- A 300-enemy fight stays cheap: the burst pool never exceeds its cap, a cone landing on 20 enemies makes a few bursts and one shake, nothing allocates a node per spark, and the stress scene with effects is within about 10% of today (Tasks 2, 3, 6 and 8).
- The low-health warning is honest: silent at full health and above the thresholds, gone at once on a heal, on death and on a restart, the rate and opacity follow health, the heartbeat plays only on the strongest level, and nothing pulses behind a pause screen (Tasks 4 and 5).
- Gameplay stays unaware and unchanged: `AreaEffect` only gains one connection per hit effect, nothing outside the effects code references the director, the burst layer, the shake or the flash, no autoload was added, and damage, timing and collision are untouched (Tasks 3, 6 and 8).
- The weight means what the user asked: a slow big hit is heavier than a fast small one, a spell with no data is 0, the number comes from the config, and all five spell areas announce hits with it (Tasks 1 and 3).

---

## File Structure

- Data and pure logic: new `resources/fx/{impact_config}.gd`, `resources/fx/impact_config.tres`, `scripts/fx/{fx_settings,impact_weight,impact_events,shake_trauma,particle_pool,vignette_image}.gd`, `tests/test_impact_config.gd`, `test_impact_weight.gd`, `test_shake_trauma.gd`, `test_particle_pool.gd`, `test_vignette_image.gd`.
- Effect nodes: new `scripts/fx/{burst_layer,camera_shake,screen_flash,fx_director,low_health_warning,hit_indicator}.gd`, `scenes/fx/{low_health_warning,hit_indicator}.tscn`, `scenes/main/main.tscn` (adds the director and the warning), `tests/test_burst_layer.gd`, `test_camera_shake.gd`, `test_fx_director.gd`, `test_low_health_warning.gd`, `test_hit_indicator.gd`.
- Touched by one-line additions: `scripts/spells/area_effect.gd` (announce hits), `scripts/systems/scroll_dropper.gd` (`placed` signal), `scripts/ui/health_bar.gd` (heart beat), `scripts/ui/spell_slot_widget.gd` (low-mana pulse), `scripts/audio/sound_board.gd` (volume offset and weight), `scripts/entities/body_view.gd` (a small jitter offset), `tests/test_health_bar.gd`, `test_spell_slot_widget` (inside `test_spell_bar.gd`), `test_sound_board.gd`, `test_scroll_dropper.gd`, `test_body_view.gd`, the five area tests.
- Art and sound: `art/sprites/icon_heart_beat.sprite`, `fx_hit_edge_h.sprite`, `fx_hit_edge_v.sprite` (and built files); `audio/sounds/heartbeat.sfx`, `audio/sounds/mana_low.sfx`, `assets/audio/*.wav`, `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`.
- Dev tool and docs: `scenes/world/fx_test.tscn`, `scripts/world/fx_test.gd`, `scripts/dev/stress_test.gd` (`--fx`), `CLAUDE.md`, `README.md`, `technical-design.md`, `sprint-development.md`, `development-log.md`, `sprint-13f-design.md`.

---

### Task 1: Config, settings and the impact weight

**Files:**
- Create: `resources/fx/impact_config.gd`, `resources/fx/impact_config.tres`, `scripts/fx/fx_settings.gd`, `scripts/fx/impact_weight.gd`, `scripts/fx/impact_events.gd`, `tests/test_impact_config.gd`, `tests/test_impact_weight.gd`

**Interfaces:**
- Produces: `ImpactConfig` (Resource) with `@export` fields and these starting values: `wait_min 0.3`, `wait_max 1.5`, `damage_min 6.0`, `damage_max 40.0`, `wait_share 0.6` (the damage share is 1 minus it), `shake_from 0.35` and `flash_from 0.5` (the weights where each starts), `shake_max_px 4`, `flash_max_alpha 0.12`, `flash_seconds 0.08`, `shake_gap_msec 80`, `flash_gap_msec 330`, `particles_light 3`, `particles_heavy 24`, `sound_pitch_drop 0.25` (the pitch multiplier falls by this at weight 1), `sound_volume_up_db 4.0`, `health_beat_from 0.5`, `health_warn_from 0.3`, `warn_max_alpha 0.4`, `warn_rate_low 0.8` and `warn_rate_high 2.0` (Hz), `beat_rate_slow 0.5`. Static `default_config() -> ImpactConfig` loads `res://resources/fx/impact_config.tres`.
- `FxSettings` (static class): `static var shake_scale: float = 1.0`, `static var flash_scale: float = 1.0`, `static func reset() -> void`.
- `ImpactWeight.of(spell: SpellData, config: ImpactConfig = null) -> float` (0..1): `wait_share * norm(spell.cast_interval, wait_min, wait_max) + (1 - wait_share) * norm(spell.damage, damage_min, damage_max)`, where `norm` clamps `(x - lo) / (hi - lo)` to 0..1; null spell gives 0; a null config uses the default.
- `ImpactEvents` (RefCounted with `static var bus := ImpactEvents.new()`): `signal hit(position: Vector2, weight: float, element_id: StringName)` (with `@warning_ignore("unused_signal")`).

- [ ] **Step 1: Write the failing tests.** `test_impact_config`: `test_the_default_config_loads_with_the_pinned_numbers` (every value above), `test_the_comfort_limits_hold` (`shake_max_px <= 4`, `flash_max_alpha <= 0.12`, `warn_max_alpha <= 0.4`, `warn_rate_high <= 2.0`, `flash_gap_msec >= 330`). `test_impact_weight`: `test_a_missing_spell_is_zero`, `test_the_weight_is_between_zero_and_one`, `test_a_longer_wait_is_heavier`, `test_a_bigger_hit_is_heavier`, `test_a_slow_big_hit_is_heavier_than_a_fast_small_one`, `test_the_starting_spells_spread_out` (fire missile < sea wave < land area, loaded from `resources/spells/`), `test_a_custom_config_changes_the_weight`, `test_fx_settings_default_to_one_and_reset`. Run both. Expected: FAIL (classes missing).
- [ ] **Step 2: Implement** the classes, the `.tres` and `ImpactEvents`; run `godot --headless --import`, both files, then the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the impact config, settings and weight`.

---

### Task 2: The burst layer

**Files:**
- Create: `scripts/fx/particle_pool.gd`, `scripts/fx/burst_layer.gd`, `tests/test_particle_pool.gd`, `tests/test_burst_layer.gd`

**Interfaces:**
- Consumes: `ImpactConfig`.
- Produces: `ParticlePool` (RefCounted, pure): `ParticlePool.new(capacity: int)`; `emit(position: Vector2, velocity: Vector2, life: float, color: Color, size: int, gravity: float, kind: int) -> void` (kinds `SQUARE` and `TWINKLE`; at the cap the oldest particle is recycled); `step(delta: float) -> void` (moves each by its velocity, applies gravity, removes the dead); `count() -> int`; `particles() -> Array[Dictionary]` (`position`, `color`, `size`, `kind`, `age_ratio`); positions in `particles()` are rounded to whole pixels. `BurstLayer` (Node2D, `z_index` 9 so it draws over the world and under the HUD): `burst(position: Vector2, style: StringName, colors: Array[Color], count: int) -> void` with styles `sparks` (fast, short, a little gravity), `dust` (slow, soft, rising), `stars` (twinkles drifting up), `sparkle` (twinkles in place); `CAPACITY := 256`; `active_count() -> int`. It draws every live particle in one `_draw`, processes only while any are alive, never creates a node per particle, and uses a seeded `RandomNumberGenerator`.

- [ ] **Step 1: Write the failing tests.** `test_particle_pool`: `test_emit_adds_a_particle_and_step_ages_and_removes_it`, `test_the_pool_never_exceeds_its_capacity_and_recycles_the_oldest`, `test_velocity_and_gravity_move_a_particle`, `test_reported_positions_are_whole_pixels`, `test_age_ratio_goes_from_zero_to_one`, `test_a_thousand_emits_stay_at_the_cap`. `test_burst_layer`: `test_a_burst_adds_up_to_the_requested_count_and_it_is_capped`, `test_each_style_makes_its_particles` (sparks and dust are squares, stars and sparkle twinkles), `test_the_layer_only_processes_while_particles_live`, `test_particles_expire`, `test_no_child_nodes_are_made_for_particles`, `test_a_burst_uses_the_colours_it_is_given`, `test_the_layer_is_never_scaled_or_rotated` (its transform stays identity after bursts). Run. Expected: FAIL.
- [ ] **Step 2: Implement** both; run `godot --headless --import`, both files and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: the pooled pixel burst layer`.

---

### Task 3: Shake, flash and announcing hits

**Files:**
- Create: `scripts/fx/shake_trauma.gd`, `scripts/fx/camera_shake.gd`, `scripts/fx/screen_flash.gd`, `scripts/fx/fx_director.gd`, `tests/test_shake_trauma.gd`, `tests/test_camera_shake.gd`, `tests/test_fx_director.gd`
- Modify: `scripts/spells/area_effect.gd`, `scripts/audio/sound_board.gd`, `scenes/main/main.tscn` (adds `FxDirector`), `tests/test_sound_board.gd`, the five area tests (`tests/test_missile_area.gd`, `test_cone_area.gd`, `test_zone_area.gd`, `test_line_area.gd`, `test_wave_area.gd`)

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `ShakeTrauma` (RefCounted, pure): `add(amount: float, now_msec: int, gap_msec: int) -> bool` (adds trauma capped at 1, refused inside the gap), `decay(delta: float)` (falls about 3 per second), `value() -> float`, `offset_px(max_px: float, scale: float, rng) -> Vector2` (a random whole-pixel vector of length at most `round(max_px * value^2 * scale)`). `CameraShake` (Node): `CameraShake.bind(camera: Camera2D)`, `shake(weight: float)`, `process` sets `camera.offset`, restoring `Vector2.ZERO` when trauma is gone. `ScreenFlash` (CanvasLayer, layer 50): `flash(weight: float)` sets a full-rect `ColorRect` (white, `mouse_filter` IGNORE) to `flash_max_alpha * flash_scale` for `flash_seconds` then clears it, refusing inside `flash_gap_msec`. `FxDirector` (Node): `bind(main: Node)` connects `ImpactEvents.bus.hit` (burst at the hit with `lerp(particles_light, particles_heavy, weight)` sparks in the element's `ElementLook` colours, plus dust above weight 0.5; `shake(weight)` and `flash(weight)` only from their thresholds), `EnemyAttackEvents.bus.blast_detonated` (a small fixed shake and a dust burst) and `Boss.attack_started` for slams; gameplay never calls it; `bind` is idempotent. `AreaEffect._configure_hitbox` connects `hitbox.hit_landed` once (guard with a meta flag) to emit `ImpactEvents.bus.hit(target.global_position, ImpactWeight.of(spell), ElementLooks.id_of(spell.primary_element()))`. `SoundBoard` gains `play(id, pitch = 1.0, volume_offset_db = 0.0)` and listens to `ImpactEvents.bus.hit` to remember the hit's weight and element (replacing the last-cast element guess when present); `_on_enemy_damaged` plays the hit sound with pitch `1 - sound_pitch_drop * weight` and `+ sound_volume_up_db * weight` dB.

- [ ] **Step 1: Write the failing tests.** `test_shake_trauma`: `test_add_caps_at_one`, `test_the_gap_refuses_a_second_add_too_soon`, `test_decay_falls_to_zero`, `test_the_offset_is_whole_pixels_and_never_above_the_cap` (many random draws at weights 0, 0.5, 1), `test_scale_zero_gives_no_offset`. `test_camera_shake`: `test_a_heavy_hit_moves_the_camera_offset_and_it_settles_to_zero`, `test_a_light_hit_below_the_threshold_does_not_shake`, `test_twenty_hits_in_one_frame_shake_once` (the gap), `test_shake_scale_zero_never_moves_the_camera`, `test_the_offset_never_exceeds_four_pixels`. `test_fx_director`: `test_a_heavy_hit_makes_a_big_burst_a_shake_and_a_flash_and_a_light_one_only_sparks`, `test_the_burst_uses_the_elements_colours`, `test_a_blast_detonation_gives_a_small_shake`, `test_a_boss_slam_gives_a_small_shake`, `test_twenty_simultaneous_hits_make_at_most_a_few_bursts_and_one_shake_and_one_flash`, `test_the_burst_layer_stays_under_its_cap_in_a_flood`, `test_bind_twice_does_not_double_the_effects`, `test_flash_is_soft_and_never_above_the_cap` (`ColorRect` alpha at most 0.12). The five area tests: `test_the_area_announces_a_hit_with_the_spells_weight` (cast the area at a target dummy, record `ImpactEvents.bus.hit`, expect one event with `ImpactWeight.of(spell)` and the element id; disconnect the recorder in the test). `test_sound_board`: `test_a_heavy_impact_plays_the_hit_lower_and_louder` (stub clock, `ImpactEvents.bus.hit.emit` at weight 1 then `_on_enemy_damaged`; the last pitch is below 1 and the volume offset positive), `test_the_hit_event_sets_the_element_of_the_hit_sound` (a thunder hit event then a damaged signal asks for `hit_thunder`). Run. Expected: FAIL.
- [ ] **Step 2: Implement** the classes, the `AreaEffect` connection, the board change and the director in `main.tscn`. Run `godot --headless --import`, the files, one MCP run (no errors) and the whole suite. Expected: PASS.
- [ ] **Step 3: Commit** `feat: spell impact weight drives bursts, shake, flash and sound`.

---

### Task 4: The low-health warning

**Files:**
- Create: `scripts/fx/vignette_image.gd`, `scripts/fx/low_health_warning.gd`, `scenes/fx/low_health_warning.tscn`, `art/sprites/icon_heart_beat.sprite`, `audio/sounds/heartbeat.sfx`, `tests/test_vignette_image.gd`, `tests/test_low_health_warning.gd`
- Modify: `scripts/ui/health_bar.gd`, `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/sound_board.gd`, `scenes/main/main.tscn`, `tests/test_health_bar.gd`, `tests/test_sound_catalog.gd`, `tests/test_sound_board.gd`

**Interfaces:**
- Consumes: `ImpactConfig`, `HealthComponent.health_changed`, the HUD `HealthBar`.
- Produces: `VignetteImage.build(size: Vector2i = Vector2i(480, 270), depth: int = 22) -> Image` (pure, deterministic): transparent in the middle, red (the palette's `U`, `#e0483c`) pixels only within `depth` pixels of an edge, dithered (a checkerboard whose density falls with distance from the edge: solid at the edge, a quarter filled at the inner rim) so it reads as a gradient in pixel art; corners are denser. `LowHealthWarning` (CanvasLayer, layer 40, ignores the mouse): `bind(health: HealthComponent)`; `level() -> int` (0 above `health_beat_from`, 1 from there down to `health_warn_from`, 2 below it and alive); `signal beat(level: int)` emitted at the pulse rate (level 1 at `beat_rate_slow` Hz, level 2 at `lerp(warn_rate_high, warn_rate_low, ratio / health_warn_from)` Hz); a `TextureRect` showing the vignette (built once, nearest filter, scale 1) whose `modulate.a` pulses from 0 to `warn_max_alpha * intensity` where intensity is 0.5 at the threshold rising to 1 at 0 health; at level 0, at death and while the tree is paused the alpha is 0. `HealthBar` gains `beat()` that shows `icon_heart_beat` for 0.15 s and then `icon_heart`, called on the warning's `beat`. New sound `heartbeat` (`audio/sounds/heartbeat.sfx`: two low soft triangle thumps 0.18 s apart, about 0.45 s, quiet) with `SoundId.HEARTBEAT` and a catalog entry (`volume_db -12`, `max_voices 1`, `min_gap_msec 250`, `priority NORMAL`, `pausable true`); `SoundBoard.bind` plays it on `beat` when the level is 2.

- [ ] **Step 1: Write the failing tests.** `test_vignette_image`: `test_the_image_is_480_by_270`, `test_the_middle_is_fully_transparent`, `test_only_the_palette_red_is_used`, `test_the_edge_is_solid_and_density_falls_inward` (count filled pixels per ring: monotonically non-increasing), `test_the_pattern_is_a_dither` (neighbouring pixels in the inner rings alternate), `test_it_is_deterministic`. `test_low_health_warning`: `test_the_level_follows_health` (1.0 is 0, 0.5 is 1, 0.31 is 1, 0.3 is 2, 0.05 is 2), `test_a_heal_clears_the_warning_at_once`, `test_death_clears_it`, `test_the_alpha_never_exceeds_the_cap_and_is_zero_at_level_zero`, `test_the_rate_rises_as_health_falls_and_never_exceeds_two_hertz`, `test_beats_are_emitted_at_the_rate` (drive `_process` with fixed deltas), `test_the_warning_is_silent_while_paused`, `test_the_frame_is_never_scaled_or_rotated`, `test_it_ignores_the_mouse`. `test_health_bar`: `test_beat_shows_the_beat_heart_briefly_then_the_normal_one`. `test_sound_catalog`: `heartbeat` joins the design list and is NORMAL, capped and quiet. `test_sound_board`: `test_a_level_two_beat_plays_the_heartbeat_and_level_one_does_not`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.** Draw `icon_heart_beat.sprite` in the 13d icon pipeline (11 by 10, the heart a little fuller and brighter with a bolder outline) and write `heartbeat.sfx` with the other sound recipes (a throwaway scratchpad generator may produce them, the committed sources are the files); update `SoundId` and the catalog; run `godot --headless --import`, the art tool, `--import`, the files, the whole suite and one MCP run. Take a real-window screenshot at 100%, 45%, 25% and 8% health.
- [ ] **Step 3: Commit** `feat: the low-health warning, heartbeat and beating heart`.

---

### Task 5: The player's hurt feedback

**Files:**
- Create: `scripts/fx/hit_indicator.gd`, `scenes/fx/hit_indicator.tscn`, `art/sprites/fx_hit_edge_h.sprite`, `art/sprites/fx_hit_edge_v.sprite`, `tests/test_hit_indicator.gd`
- Modify: `scripts/fx/fx_director.gd`, `scripts/entities/body_view.gd`, `tests/test_fx_director.gd`, `tests/test_body_view.gd`

**Interfaces:**
- Consumes: `Player.hurtbox.hit_received(damage, source_position, knockback, effect)`, `BodyView.set_tint`, Tasks 3 and 4.
- Produces: `BodyView.set_jitter(offset: Vector2)` (moves the sprite, layers and outline by a whole-pixel offset, `Vector2.ZERO` restores; the shadow stays). `HitIndicator` (CanvasLayer, layer 45): `show_hit(direction: Vector2)` (direction from the player towards where the hit came from) places one of at most 3 pooled arc sprites at the screen edge on that side (`fx_hit_edge_h` flipped for top or bottom, `fx_hit_edge_v` flipped for left or right, offset along the edge by the direction's other component, never rotated), opaque for 0.1 s and then fading to nothing over about 0.4 s; the oldest is reused at the cap. `FxDirector` handles the player's hit: the wizard tints red `Color(1, 0.55, 0.55)` and jitters 2 px (alternating whole-pixel offsets) for 0.2 s then restores both, a tiny shake (`ShakeTrauma` 0.25 through `CameraShake`), a few red sparks at the player and the indicator; a second hit inside the 0.2 s restarts the timer rather than stacking.
- Art: `fx_hit_edge_h` is 48 by 6 and `fx_hit_edge_v` 6 by 48 (a red crescent with a plum outline, palette colours only, one frame, the usual 1 px margin).

- [ ] **Step 1: Write the failing tests.** `test_hit_indicator`: `test_a_hit_from_the_left_shows_an_arc_at_the_left_edge_flipped_the_right_way` (and right, top, bottom), `test_the_arc_fades_out_and_hides`, `test_at_most_three_arcs_at_once_and_the_oldest_is_reused`, `test_arcs_are_never_scaled_or_rotated`, `test_the_indicator_ignores_the_mouse`. `test_body_view`: `test_a_jitter_moves_the_sprite_and_its_layers_together_and_zero_restores_them`, `test_the_jitter_is_whole_pixels`. `test_fx_director`: `test_a_player_hit_tints_jitters_and_restores_after_the_timer`, `test_a_second_hit_restarts_the_timer`, `test_a_player_hit_shows_an_arc_towards_the_source`, `test_the_player_hit_shake_is_tiny`. Run. Expected: FAIL.
- [ ] **Step 2: Draw the two arcs, implement** the indicator, the jitter and the director's hurt handling; run the art tool and the import, the files, the whole suite and one MCP run. Take a real-window screenshot of a hit from the left with the wizard tinted.
- [ ] **Step 3: Commit** `feat: the player's hurt flash, jitter and hit arcs`.

---

### Task 6: Light touches

**Files:**
- Create: `audio/sounds/mana_low.sfx`, `tests/test_fx_touches.gd`
- Modify: `scripts/fx/fx_director.gd`, `scripts/systems/scroll_dropper.gd`, `scripts/ui/spell_slot_widget.gd`, `scripts/audio/sound_id.gd`, `resources/audio/sound_catalog.tres`, `scripts/audio/sound_board.gd`, `tests/test_scroll_dropper.gd`, `tests/test_spell_bar.gd`, `tests/test_sound_catalog.gd`, `tests/test_sound_board.gd`, `sprint-13f-design.md` (the "one new sound" line becomes two)

**Interfaces:**
- Consumes: Tasks 2 and 3, `PickupCollector.collected(scroll)` and `xp_collected` and `gold_collected`, `RunProgress.leveled_up`, `SpellInstance.mana_changed`.
- Produces: `ScrollDropper` gains `signal placed(pickup: ScrollPickup)` emitted at the end of `place` (a one-line announcement, nothing else changes). `FxDirector` adds: a pickup burst (4 `sparks` at the player's position in the scroll's colour, blue for XP, yellow for Gold, capped by the pool), a level-up burst (about 14 `stars` round the wizard plus a ring of `dust`), and a Rare-drop `sparkle` burst (10 twinkles) where a Rare scroll is placed (`placed` with `scroll.rarity == ScrollData.Rarity.RARE`). `SpellSlotWidget` low mana: when `ratio` is above 0 and at or below 0.25 its mana fill alternates between its colour and red at 2 Hz (a `Timer`-free `_process` that runs only while low), and it emits `signal went_low(index: int)` once each time the ratio first drops to or below 0.25 from above; empty keeps today's tint and dry flash. New sound `mana_low` (`audio/sounds/mana_low.sfx`: one soft low double blip, about 0.18 s) with `SoundId.MANA_LOW` and a catalog entry (`volume_db -14`, `max_voices 1`, `min_gap_msec 400`, `priority LOW`, `pausable true`); `SoundBoard.bind` plays it on `SpellBar` widgets' `went_low` (found through the `Hud/SpellBar` node's `widgets`).

- [ ] **Step 1: Write the failing tests.** `test_fx_touches` (with the director and a recording stub of the burst layer): `test_collecting_a_scroll_sparks_in_its_colour`, `test_xp_sparks_are_blue_and_gold_sparks_are_yellow`, `test_a_level_up_bursts_stars_round_the_player`, `test_a_rare_scroll_drop_sparkles_where_it_lands_and_a_common_one_does_not`, `test_many_pickups_in_a_frame_stay_under_the_pool_cap`. `test_scroll_dropper`: `test_placed_is_emitted_with_the_pickup`. `test_spell_bar`: `test_a_slot_pulses_when_low_but_not_empty_and_stops_when_refilled` (colour alternates at about 2 Hz; none when the ratio is 0 or above 0.25), `test_went_low_fires_once_per_drop_below_the_threshold`. `test_sound_catalog`: `mana_low` is in the list, LOW and capped. `test_sound_board`: `test_a_low_mana_slot_plays_the_blip_once`. Run. Expected: FAIL.
- [ ] **Step 2: Implement**, write `mana_low.sfx` with the other recipes, update `SoundId`, the catalog and the design doc's sound line; run the art and audio tool, `--import`, the files, the whole suite and one MCP run.
- [ ] **Step 3: Commit** `feat: pickup sparks, low-mana pulse, level-up stars and rare sparkle`.

---

### Task 7: The effects-test scene and the stress option

**Files:**
- Create: `scenes/world/fx_test.tscn`, `scripts/world/fx_test.gd`, `tests/test_fx_test.gd`
- Modify: `scripts/dev/stress_test.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: `FxTest` (a developer tool, not part of the game; `godot --path . res://scenes/world/fx_test.tscn`): a grass-floor scene with a camera, a `BurstLayer`, a `CameraShake`, a `ScreenFlash`, a `LowHealthWarning` bound to a stand-in `HealthComponent`, a `HitIndicator`, a `FxDirector` and a real `HealthBar`; buttons (themed, at least 22 px tall) for Light, Medium and Heavy impact in each element (emitting `ImpactEvents.bus.hit` at the centre with weights 0.1, 0.5 and 1.0), a health slider (0 to 100%) and "Hit me from: left, right, top, bottom" (calls the director's hurt handling), Pickup, Level-up, Rare drop, Blast, Shake scale and Flash scale sliders (set `FxSettings`), and the current weight, trauma, particle count and warning level on screen. It restores `FxSettings` on exit. The stress scene gains `--fx`: it adds the director and the burst layer, wires `ImpactEvents` through the casting `AreaEffect`s as in the game, and prints `FX particles_max=… shakes=… flashes=…` after the STRESS line.

- [ ] **Step 1: Write the failing tests.** `test_fx_test`: `test_the_scene_loads_and_builds_its_buttons`, `test_a_heavy_impact_button_makes_particles_and_shakes`, `test_the_health_slider_drives_the_warning_level`, `test_a_hit_button_shows_an_arc`, `test_the_scale_sliders_set_fx_settings_and_exit_restores_them`. Run. Expected: FAIL.
- [ ] **Step 2: Build the scene and the option**; run `godot --headless --import`, the file, a clean MCP run of the effects-test scene, then the whole suite. Take real-window screenshots of the scene (a heavy impact mid-burst, and 25% health).
- [ ] **Step 3: Commit** `feat: the effects-test scene and the stress --fx option`.

---

### Task 8: Guards, performance, real-window checks and docs

**Files:**
- Create: `tests/test_fx_guards.gd`
- Modify: `CLAUDE.md` (a new "Polish (Sprint 13f)" section and the Project State line), `README.md`, `technical-design.md`, `sprint-development.md` (13f ticks and a Built note), `development-log.md`, `sprint-13f-design.md` (Status: Built, plus a "Revisions during the build" note per change)

**Interfaces:**
- Consumes: everything above. Produces nothing later tasks need.

- [ ] **Step 1: Write the failing guard tests** in `tests/test_fx_guards.gd`: `test_no_script_outside_the_effects_code_references_the_director_burst_layer_shake_or_flash` (scan `scripts/` except `scripts/fx/`, `scripts/main/main.gd`, `scripts/audio/sound_board.gd`, `scripts/world/fx_test.gd`, `scripts/dev/stress_test.gd`, `scripts/spells/area_effect.gd` for `FxDirector`, `BurstLayer`, `CameraShake`, `ScreenFlash`, `LowHealthWarning`, `HitIndicator`; only `ImpactEvents` may appear elsewhere), `test_the_project_has_no_autoload`, `test_no_effect_scene_scales_or_rotates_a_node` (scan `scenes/fx/*.tscn` for `scale =` and `rotation`), `test_no_effect_script_sets_scale_or_rotation` (scan `scripts/fx/` for `.scale =`, `.rotation =`, `rotate(`), `test_every_effect_is_pausable_or_hides_when_paused` (the burst layer, shake and flash use the default process mode; the warning checks the tree's pause), `test_the_comfort_limits_are_in_the_config`, `test_the_stress_rate_of_hits_keeps_the_pool_flat` (feed the director 300 hits a second for 5 simulated seconds at random weights and positions: `BurstLayer.active_count()` never above 256, shakes at most one per 80 ms, flashes at most one per 330 ms). Run. Expected: FAIL only on what Tasks 1 to 7 missed; fix and ledger each.
- [ ] **Step 2: Performance.** Run the stress scene three times without and three times with `--fx` (and once with `--boss --fx`): expected within about 10% of today, particles never above the cap, and the `FX` line's shakes and flashes within their gaps (flashes at most about 3 a second, so at most about 24 in 8 s). If slower, profile the burst layer's `_draw` first.
- [ ] **Step 3: Real-window checks** in a scratchpad script (`save_path` empty): the game for a minute with a heavy and a light spell, a crowd and the Ember Titan, confirming no warning, the caps held, light spells shake nothing and heavy ones do; take health to 45%, 25% and 8% with screenshots (the heart, the frame, the arcs); heal and confirm the warning clears at once; die and confirm it clears; open the crafting screen at low health and confirm nothing pulses behind it; level up, collect a pickup, drop a Rare scroll and run a spell low on mana. State clearly that the feel was not judged.
- [ ] **Step 4: Update the docs** and run the whole suite and `godot --headless --quit-after 60`. Expected: PASS and no new warnings.
- [ ] **Step 5: Commit** `docs: Sprint 13f complete`.
