# Sprint 13f Design: Polish

**Status:** Built (Sprint 13f).

Sprint 13 is six parts: **13a** art foundation, **13b** the world, **13c** spells and equipment, **13d** the interface, **13e** audio (all done), **13f** polish (this doc). Scope comes from the conversation, the Polish and Animation lists in `sprint-development.md`, `CLAUDE.md` and the art and audio pipelines of 13a to 13e. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Two things feel flat in play (the user's words): **how much health is left** ("sometimes it sneaks up on me that I only have 25% left") and **the impact of spells** ("I will cast something with a long cooldown; however, it feels weaker since it affects the screen the same way something with a shorter cooldown does"). 13f fixes those two properly and gives the rest of the polish list light touches. It changes how things look, shake and sound, never how they work.

**Goals (user decisions)**
- **Concentrate on the two** (health awareness and spell weight); the rest of the list as light touches.
- **Approach A:** pixel-art effects from our own pipeline, driven by data: a pooled sprite-particle layer, whole-pixel camera shake, a pixel-art edge frame for low health, and a spell **impact weight** worked out from each spell's own numbers.
- **Health awareness:** an escalating warning that is hard to miss without hiding the fight.
- **Spell weight:** a long-wait or hard-hitting spell must look, shake and sound heavier than a spammed one, and a light one stays light.

**My calls**
- **Health ladder:** from about 50% the heart on the health bar beats slowly; below about 30% a red, dithered frame pulses round the screen edge, the heart beats faster and a quiet heartbeat sound plays, its rate rising as health falls. The thresholds and strengths are numbers in one config resource.
- **Hit feedback on the player:** the wizard flashes red and its body jitters 2 px for 0.2 s (no new sprite frames: five layered sheets would have to be redrawn together), and a short arc at the screen edge points at where the hit came from.
- **Impact weight** (0 to 1) = a blend of the spell's wait (`cast_interval`) and its damage per hit, each normalised between two config numbers. Heavier spells get a bigger burst, a screen shake, a quick soft flash and a deeper, louder impact sound; light ones get a few sparks and nothing else.
- **Where the weight comes from:** the base class every spell area shares (`AreaEffect._configure_hitbox`, the one place all five areas already build their hits through) announces each hit with its weight, so no individual area is edited.
- **Light touches:** a spark burst when a pickup is collected, a pulsing slot fill and a faint blip when a spell is low on mana, a star burst round the wizard on level-up, and a sparkle burst when a Rare scroll drops. Each reuses the same burst layer.
- **Comfort:** shake is small (at most 4 px, whole pixels) and flashes are soft and rare (at most about 3 a second, never full-screen white), with no flicker faster than that. One `FxSettings` pair of numbers (`shake_scale`, `flash_scale`, default 1.0) controls them, so Sprint 15's settings screen only has to set two numbers.
- **Two new sounds** (`heartbeat`, a soft two-beat, and `mana_low`, a faint low double blip), made by the audio pipeline like the rest.

**Non-goals (later sprints)**
- Hit-stop (freezing the game for a moment), slow motion, camera zoom and any change to timing or numbers.
- New enemy or boss animations, redrawing the wizard for a hurt pose, screen transitions, weather or ambient particles.
- The settings screen itself (Sprint 15).
- Rebalancing damage or cooldowns: the weight only reads them.

**Anti-goals** (a failure even if it technically works)
- Effects that hide the fight: a flash or frame that covers the screen or the enemies, or a shake that makes aiming hard.
- A frame-rate or memory cost in a 300-enemy fight: unbounded particles, a node per spark, or a shake and flash on every one of many hits at once.
- Anything that scales or rotates a sprite (the game has one pixel size), or draws sub-pixel positions that shimmer.
- Flashing or pulsing fast enough to bother players: nothing above about 3 flashes a second.
- A warning that cries wolf (the low-health pulse at full health, or left on after a heal) or that is silent on a restart.
- Gameplay code that knows about effects. Systems keep announcing events, and one effects node listens.
- A new autoload, or an effect that changes damage, timing, collision or input.

## 2. Approaches

- **A. Pixel-art effects from our own pipeline, driven by data.** One pooled layer draws every spark in a single `_draw` with a hard cap; the camera shakes in whole pixels; the low-health frame is a dithered pixel sprite; the weight is data. **Chosen by the user.** Cost: I cannot see or feel it, so an effects-test scene lets the user fire light and heavy impacts and set the health, and tune the numbers by feel.
- **B. Godot's built-in particles and a screen-edge shader.** Quicker to write but smooth and soft, heavier on a phone and riskier on the web, and every effect is another node to cap. Not chosen.
- **C. Only screen shake scaled by weight, and a bar flash for health.** Smallest change, but it fixes only part of each complaint. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Config as data | `ImpactConfig` (Resource, `resources/fx/impact_config.tres`): the wait range and damage range the weight is normalised over (my starting numbers: wait 0.3 to 1.5 s, damage 6 to 40, blended 60% wait and 40% damage), the weight where shake and flash start (about 0.35 and 0.5), the shake size at full weight (4 px), the particle counts at weight 0 and 1 (3 and 24), the minimum gap between shakes and flashes (80 ms and 330 ms) and the health thresholds (0.5 and 0.3). `FxSettings` (static) holds `shake_scale` and `flash_scale`, both 1.0. |
| Impact weight | `ImpactWeight` (static, pure): `of(spell: SpellData, config) -> float` from `cast_interval` and `damage` (after the spell's own multipliers), clamped to 0..1, with no side effects. A spell with no data gives 0. |
| Announcing a hit | `ImpactEvents` (a static emitter like `EnemyAttackEvents`, not an autoload) with `hit(position: Vector2, weight: float, element_id: StringName)`. `AreaEffect._configure_hitbox` connects the hitbox's `hit_landed` to emit it (one connection per effect, the weight worked out once per cast). A cone that lands on 20 enemies announces 20 hits; the effects node is what keeps that to a few bursts. |
| The effects node | `FxDirector` (a node in `main.tscn`, not an autoload) listens to `ImpactEvents.bus`, the `EnemyAttackEvents` blast detonation, the player's hurt and level-up, pickups and Rare drops, and owns the burst layer, the shake and the flash. Gameplay never calls it. |
| Particles | `BurstLayer` (a `Node2D` that draws every particle in one `_draw`, a fixed pool of 256, the oldest recycled at the cap). A particle is a whole-pixel square (1 to 3 px) or a 3 by 3 plus-shaped twinkle in a palette colour, with position rounded to whole pixels, a velocity, a life and gravity; styles are `sparks`, `dust`, `stars` and `sparkle`. An element's burst takes its `ElementLook` colours. It processes only while a particle is alive. |
| Shake | `CameraShake` (a node under the player's camera): trauma goes up with each heavy hit (capped at 1) and decays quickly; the camera's `offset` is set to a random whole-pixel offset of `round(max_px * trauma^2 * shake_scale)`. A minimum gap stops 20 simultaneous hits adding up. A blast detonation and a boss slam give a small fixed shake; a hit on the player a tiny one. |
| Flash | A soft white edge-to-edge tint at no more than about 12% opacity for about 80 ms, only above the flash weight and at most every 330 ms, scaled by `flash_scale`. A pooled `ColorRect` on a high CanvasLayer that ignores the mouse. |
| Impact sound | `SoundBoard` plays the existing `hit_<element>` sounds; for a heavy spell it plays them lower and louder (the pitch and volume offsets are `ImpactConfig` numbers, applied through the board's existing pitch argument and a new volume offset). No new impact recipes. |
| Low health | `LowHealthWarning` (a CanvasLayer in the HUD): reads `HealthComponent.health_changed`, and shows `ui_vignette` (a new dithered red edge frame, a sliced sprite that is clear in the middle) with an opacity that pulses at 0.8 Hz at 30% rising to 2 Hz near death, never above about 40% opacity. It is off above the threshold, off when dead and gone at once on a heal. It emits `beat` each pulse and the sound board plays `heartbeat` on it. |
| The heart | The health bar's heart swaps between two drawings (`icon_heart` and a fuller `icon_heart_beat`) on the beat from 50% down, never scaled. |
| Player hurt | The wizard's `BodyView` tint flashes red and its sprite offset jitters 2 px for 0.2 s on a hit (through `BodyView`'s existing tint and a small offset). A pooled `HitIndicator` arc (a pixel sprite) appears at the screen edge in the direction of the hit's source and fades in about 0.4 s; at most 3 at once. |
| Light touches | Pickups: a 4-spark burst in the item's colour where it was collected (a scroll's colour, blue for XP, yellow for Gold). Low mana: when a spell's pool is at or below 25% (and above 0) its slot fill pulses between its colour and red at 2 Hz and the slot gives a faint blip once when it first drops below; empty keeps today's tint and dry flash. Level-up: a burst of stars round the wizard and a soft ring of dust. Rare drop: a sparkle burst where a Rare scroll lands (the Rare sparkle sprite already marks the pickup). |
| Effects test | `scenes/world/fx_test.tscn` (a developer tool like the sound test): buttons for a light, medium and heavy impact over a grass floor, a slider for the player's health (so the warning can be seen at 100%, 50%, 25% and 10%), buttons for a hit on the player from each side, a pickup, a level-up and a Rare drop, and the shake and flash scales. |
| Pause | Effects freeze while the tree is paused (they process with the game), except the low-health frame, which hides behind a pause screen. |

## 4. What is left to the builder
- Every number (weights, thresholds, sizes, counts, gaps, colours, opacities) is a starting value tuned by the user through the effects-test scene, round by round.
- The exact dither pattern and the arc sprite shapes, and the two heart drawings.
- The `heartbeat` recipe's notes and the exact pitch and volume offsets for heavy impacts.
- How the player's hurt jitter is applied to `BodyView`'s layers so they stay in step.

## 5. Verification plan
- **Pure logic tests:** `ImpactWeight` (monotonic in wait and damage, clamped, zero for no data, a slow big hit heavier than a fast small one), the shake trauma and its pixel rounding, the cap and recycling of the burst pool, the shake and flash gap logic, the low-health pulse rate and opacity against health, and `FxSettings` scaling to zero turning shake and flash off.
- **Route tests** (as the sound routes): each announced event produces the expected effect through a recording stub of the director (hit weights, blast, player hurt, pickup colours, level-up, Rare drop, low mana once), and `AreaEffect` announces a hit with the right weight for each of the five areas.
- **Guards:** nothing outside the effects code references the director, the burst layer or the camera shake; no autoload; no effect scales or rotates a node (a scan of the effect scenes for scale and rotation); every particle position is rounded to whole pixels.
- **Real window:** the effects-test scene, then the game with a crowd, a boss and low health. The stress scene with effects on (a `--fx` option) against today's frame rate, and the particle pool never above its cap. Whether it feels right is judged by the user; I cannot feel it, and say so.
- `godot --headless --import` after adding a `class_name`, then the full suite.

## 6. Revisions during the build

- The hit sound comes from the impact event, not from the 13e "element of the last cast" guess: the event carries the exact element and weight, and `_on_enemy_damaged` only plays the strong and resisted accents.
- `ImpactWeight.of` takes the cast's `damage_scale` (equipment) so a boosted spell weighs more; `CameraShake` gained `kick(amount)` for fixed shakes and `trauma()` for the test scene.
- The low-health frame is a code-built dithered image (`VignetteImage`), not a sliced sprite, because the asset test needs a sliced sprite's middle to be one colour.
- Two new sounds, not one: `heartbeat` and `mana_low`.
- Every effect has a switch (`FxSettings`: `particles`, `low_health_frame`, `heart_beat`, `hurt_feedback`, `hit_indicators`, `low_mana_pulse`, with the two scales), a user request during the build.
- The effects-test scene puts impacts and the wizard at the lower left, clear of the buttons; `FxSettings` gained `get_switch` and `set_switch` (Object `get` and `set` cannot reach static variables).
