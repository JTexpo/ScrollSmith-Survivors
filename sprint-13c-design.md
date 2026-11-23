# Sprint 13c Design: Spells and Equipment

**Status:** Built.

Sprint 13 is split into six sprints, each leaving a playable build (user decision): 13a the art foundation (built), 13b the world's art (built), **13c spells and equipment (this doc)**, 13d the interface (a font and one look for every HUD piece and screen), 13e audio, 13f polish (screen shake, particles, damage indicators, low-mana and level-up feedback). Scope comes from the conversation, `sprint-development.md` (Sprint 13), the README (section 10) and the code as of Sprint 13b. Decisions below were agreed with the user in conversation, except where marked "my call". The art rules from earlier sprints apply: bright, simple, cartoon, few colours per object, **one pixel size everywhere (nothing is ever scaled)**, a missing sprite falls back to today's look, and every sprite is replaceable by overwriting a PNG.

## 1. Intent

The player's own spells and the enemies' attacks are still flat coloured shapes, and the wizard looks the same whatever they wear. Sprint 13c gives combat the cartoon look and makes equipment visible, so casting a Fire Cone feels different from a Sea Wave and the wizard's robe, hat or hood and weapon show what they bought.

**Goals**
- Every spell Area looks like its element: **Fire and Land rise from the ground, Thunder and Sea fall from the sky** (user vision), as effect sprites scattered over the exact hit area. Missiles and Waves are one object per element flying through the air.
- Enemy shots and blast zones, the boss's warnings and the target reticle use the same pixel look.
- The wizard visibly wears the equipped robe, headwear and weapon, in families (one shape, different colours; user decision).
- Gameplay does not change: hit shapes, timing, damage and every number stay as they are. The effect is only a skin on the exact polygon.

**Non-goals (later sprints)**
- The HUD, menus, shop icons and fonts (13d). The shop and inventory keep their colour swatches for now.
- Audio (13e). Screen shake, extra particles, damage numbers' look and low-mana or level-up feedback (13f).
- New spells, new elements, new equipment or changes to any bonus.

**Anti-goals** (a failure even if it technically works)
- A visible effect that disagrees with the hit area (damage outside what is drawn, or a drawn zone that does nothing).
- Effect sprites that hide enemies, the player or drops, or a screen so busy that enemy shots cannot be read. Enemy attacks must always stand out from the player's.
- Any sprite scaled to a non-1:1 size, so pixels differ in size.
- A frame-rate drop that makes a Duplicate Area cone at the casting rate unplayable (stress scene `--area=... --copies=...` is the check).
- Equipment layers that drift off the wizard in some frame, or a wizard with no equipment who looks different from today's.

## 2. Decisions

| Area | Decision |
|---|---|
| Area effects (user: option 2) | The exact hit polygon stays as a faint tint with a bright 1 px edge in the element's colours. On top, **effect sprites** play in a quick staggered sequence across it. Fire: flame bursts rise. Land: rock spikes push up. Thunder: bolts strike down. Sea: water splashes crash down. They come from the 13a pipeline (`.sprite` sources, committed PNGs, replaceable). |
| Placement (my call) | Spots are chosen inside the polygon by the same best-candidate spread as decorations (even, seeded, never clumped). The count follows the area (about one sprite per 600 px²) with a minimum of 3 and a cap of 24 per effect, and a global cap on live effect sprites, so big Duplicate casts stay cheap. |
| Timing (my call) | Rising effects (Fire, Land) start nearest the caster and move outward, over the first 40% of the effect's life. Falling effects (Thunder, Sea) land in a random order over the same span. Each sprite plays once and fades with the effect. A Zone (it lasts and ticks) plays a fresh set at each damage tick. Damage timing is untouched. |
| Hybrid spells (my call) | A spell with several Bases cycles through its elements sprite by sprite, so the effect looks mixed. A Missile or Wave uses the first element. |
| Missiles and Waves (user) | One object per element, the same for both: a fireball, a stone, a lightning orb, a water ball, 2 frames with a short trail. A Wave draws a row of these objects along its widening front. |
| Missile sizes (my call) | The missile's hit size comes from `effective_size()` and was a scaled square. Sprites are never scaled, so the object is drawn in three size classes (12, 16 and 24 px) picked by the size, and the hit shape alone follows the exact size. |
| Enemy attacks | `EnemyProjectile` takes the shooter's element (a Fire Kobold throws a fire orb; no element gets a plain grey one), a small orb in the element's colours with a dark outline so it reads against the player's bright spells. Blast zones draw as pixel warning marks around the circle that grow and flash as the fuse burns down, then a burst sprite at detonation. The boss's Charge warning line becomes the same pixel dashes. |
| Reticle | A small pixel crosshair sprite (2 frames) replaces the circle and dot. |
| Wizard equipment (user: families) | Layers on the wizard, drawn over a bare body, all with the same 8 frames (idle 2, move 4, cast 2) and anchored to it. Robes: one shape in 5 colourways (Ember, Stone, Storm, Tide, Warded). Headwear: a pointed hat and a hood, each in 3 trim colours (Hardy, Mana, Swift). Weapons: a wand and a staff in 2 looks each, held in the hand. The player's base sprite is split into a body and starter layers; **with nothing equipped the wizard looks exactly as today** (a starter purple robe and hat). Equipping a slot replaces that slot's starter layer. |
| Equipment data | `EquipmentData` gains `sprite_name` and `sprite_variant` (the sprite and its colourway); no code branches on an item id. The layers follow the wizard's animation and facing (they flip with it) and are set at run start from the equipped items, as the bonuses are. |
| Colourways (my call) | Robes use the element variants already in the palette (Ember is fire, Stone land, Storm thunder, Tide sea, Warded the neutral one). Hardy, Mana and Swift trims need new variants, so the builder gets a `variants` header line that limits which variants a sprite is built in (so enemies are not built eight times over). |
| Depth (my call) | Effects draw above enemies (they are on top of the fight) and below the HUD. No shadows on effects. |
| Tests (my call) | A missing effect sprite or element falls back to today's flat polygon and square; effect counts and caps; effects sit inside the hit polygon; the exact polygon and hitboxes are unchanged by the skin; the three missile size classes; enemy shots take the shooter's element; layers stay on the wizard in every frame and flip with it; no equipment looks like today's wizard; the 13a asset test covers every new sprite. |

### Revision during the build (user feedback after seeing the equipment)

The wizard's head looked too big for its hat and hood, it lacked the iconic white beard, and the user asked for a design that **hides as much skin tone as possible** so no one feels left out, using the beard and the shadow of the hat or hood. So the bare wizard is redrawn with **no skin at all**: a shadowed face (the hat's shadow) with only the two eyes showing, a **white beard layer** over the robe, a wider hat (a 12 px band and a 14 px brim) and a wider hood with drapes to match, so the head reads smaller under them. The beard is a fourth layer (robe, beard, headwear, weapon), always worn, and the starter wizard is still pixel-for-pixel its own composite.

## 3. Approaches considered

1. **Shader patterns on the polygon.** Cheap and always fits, but the art lives in code (not replaceable) and rising or falling motion is hard.
2. **Effect sprites scattered over the shape (chosen by the user).** Replaceable, pixel-consistent, matches the rising and falling vision, scales with crafted size through the count.
3. **A tiled texture filling the shape.** Replaceable and cheap, but it can only flicker in place.

For the wizard: layered sprites (chosen, so any robe goes with any hat and weapon, with 15 items drawn as a few shapes) against pre-composed full-wizard sprites for every combination (hundreds of images, rejected).

## 4. Risks for the builder

- **The one-pixel-size rule.** Missiles were scaled squares and the polygons scale freely. Only the hit shapes may follow the exact numbers; every drawn sprite stays 1:1.
- **Frame rate.** A Cone cast every 0.4 s with Duplicate copies can put hundreds of one-shot sprites on screen. The caps above, one shared sprite sheet per element and a measured stress run (`--area=cone --copies=5`) are the guard; bake or pool if it is slow.
- **Readability.** The player's effects are bright, large and in the middle of the fight, so enemy shots need dark outlines and a different silhouette to stay readable. Check screenshots with both at once.
- **Layer alignment.** Each layer needs its anchor right in all 8 frames (the head bobs, the hand moves during the cast) and when the sprite flips. Build a test that every layer's frames line up on the body's.
- **Palette and variants.** New variants add colours (the limit is 64, with room for a few) and the `variants` header must not break the 13a builder or its tests.
- **Starter look.** The split body and layers must compose to exactly today's wizard when nothing is equipped (a pixel-equality test).
- **Taste.** Tests cannot judge charm; check real-window screenshots of each element and of several equipment combinations, and expect rounds of feedback.

## 5. Docs this sprint updates

`sprint-development.md` (13c's items ticked, a Built note), `README.md` (the spell and equipment look, how to replace it), `technical-design.md` (new directories), `CLAUDE.md` (a "Spell and equipment art (Sprint 13c)" section), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The effect and equipment designs, counts, timings, size classes and caps are my calls above, so they can be tuned after play.
