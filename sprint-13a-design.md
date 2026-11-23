# Sprint 13a Design: The Art Foundation

**Status:** Proposed.

Sprint 13 (art, animation, audio and polish, about 45 roadmap items) is split into four sprints, each leaving a playable build: **13a** the art foundation (this doc), **13b** the world's art (tiles, Lectern, points of interest, pickups, spell visuals, UI look, font), **13c** audio, **13d** polish effects (screen shake, particles, damage indicators, low-mana and level-up feedback). Scope comes from the conversation, `sprint-development.md` (Sprint 13) and the README (section 10). Architecture follows `CLAUDE.md` and `technical-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Every visual in the game is a coloured rectangle. Sprint 13a gives it a recognizable look: comedic, colourful, cartoon-inspired pixel art. The art comes from a **pipeline that makes any single sprite replaceable** (user decision: "the mix"): original pixel art written as text grids and turned into PNG sprite sheets by a small GDScript tool, so there is a complete game now and the user can drop in better art piece by piece later, from any editor, with no code change.

**Goals**
- One pixel-art resolution and one limited palette, written down and enforced by tests.
- The pipeline: text pixel grids and a palette file, a tool that builds PNG sheets and animation data, and entities that play the animations through the usual Godot nodes.
- The player, all seven enemy archetypes in all five elements, and the Ember Titan boss, with idle, move, hit and death, plus the special-state animations their behaviours already have (the Ranged shot, the Exploder's fuse, the Support's pulse, the boss's warnings).
- Gameplay does not change: hit shapes, speeds, rules and every existing number stay as they are.

**Non-goals (later sprints)**
- Tiles, obstacles, the Lectern, points of interest, pickups, spell and projectile art, equipment sprites, the HUD and menus (13b), audio (13c), screen shake, particles and damage indicators (13d).
- Hand-drawn art. The pipeline accepts it, the sprint does not make it.

**Anti-goals** (a failure even if it technically works)
- A sprite that cannot be replaced by overwriting a PNG, or an animation whose timing lives in code instead of data.
- Art that changes what a hit does: the 12 px hurtboxes and contact boxes stay as they are, and the sprite never decides collision.
- A palette that drifts: a pixel that is not a palette colour.
- A frame-rate drop: 300 animated sprites must hold the 60 fps target.
- The element no longer readable at a glance (Fire, Thunder, Land and Sea each keep their colour family).

## 2. Decisions

| Area | Decision |
|---|---|
| Pipeline (user: approach 1) | Pixel grids in text files and a GDScript tool that builds PNG sheets, imported by Godot like any art. |
| Resolution (my call) | The game stays 480×270 with whole-number scaling and crisp filtering (already set). Sprites are drawn on a **16×16 grid** for the player, 8 to 24 px for enemies by archetype, and the boss on a 48×48 grid. Everything is drawn at 1:1, never scaled by a non-integer. |
| Palette (my call) | One palette file of about 32 named colours with roles. It is built around the four element families (Fire orange, red, yellow; Thunder yellow, white, electric blue; Land brown, green; Sea blue, cyan, turquoise), a neutral ramp, a skin tone, and one dark outline colour. The README's element colours are the anchors. |
| Source format | `art/palette.txt` (a name, a letter and a hex colour per line) and one `art/sprites/<name>.sprite` per sprite: a header (frame size, the animations with their frame ranges, frames per second and loop flag) and the frames as rows of letters (`.` transparent). Elements are not drawn four times: a grid uses **ramp letters** (for example a dark, mid and light "body" ramp and a "trim" ramp) that the tool fills from each element's ramp, so one grid yields all five element variants (none, Fire, Thunder, Land, Sea). |
| The tool | `tools/art/art_builder.gd` (run as `godot --headless -s tools/art/art_builder.gd`) reads the palette and sources, and writes `assets/sprites/<name>.png` (one sheet per sprite and element variant, frames in a row) and `assets/sprites/<name>.tres` (a `SpriteSetData`: the sheet, the frame size and the animations). Outputs are committed so the game never needs the tool to run. Overwriting a sheet PNG replaces that art. |
| Runtime | `SpriteSetData` (Resource) builds a Godot `SpriteFrames` once (cached) with `AtlasTexture` frames. A `BodyView` (a script on an `AnimatedSprite2D`, replacing the `Body` `ColorRect` of the player, enemies and boss) plays an animation by name, flips by facing, and exposes `set_tint(color)` for state tints. The hit flash keeps working (it sets `modulate`). `EnemyComposer` and `Enemy` choose the sprite set from the archetype's id and the variant from the element, so no code branches on an enemy name. |
| Animations (my call) | Player: idle (2 frames), move (4), cast (2), hurt (the existing flash), death is the death screen. Enemies: idle (2), move (4), death (3, then the existing shrink is dropped), plus one two-frame state animation for the Ranged shot, the Exploder fuse, and the Support pulse. Boss: idle, move, telegraph, attack, vulnerable, death. Casting plays when the player casts. Frame rates are data in each `.sprite` file. |
| Elites | The outline stays an outline: a tool-generated yellow silhouette of the sprite behind it, instead of the square. |
| What stays | The `ColorRect` fallback: a sprite set that is missing (a new archetype with no art yet) shows the old coloured square, so a gap never crashes or hides an enemy. |
| Tests (my call) | The tool's outputs are checked: every pixel is a palette colour, sheet sizes match the header, every archetype has all five element variants, every animation named in the data exists, and the `.tres` files load. Entities are checked: the right set for each archetype and element, flipping, tint and flash, the fallback. |

## 3. Approaches considered

1. **Text pixel grids and a GDScript tool (chosen by the user).** Replaceable PNGs, animations as data, testable, one toolchain.
2. **Sprites drawn in code at runtime.** No files to import, but nothing is replaceable by dropping in a file, and every sprite is code.
3. **The same tool in Python.** It does the job, but adds a second toolchain and an image library, and tests cannot call it.

## 4. Risks for the builder

- **Frame rate.** Up to 300 `AnimatedSprite2D` nodes each advance their own animation every frame. The stress scene (`--obstacles`, about 190 fps today) must be re-run. If it drops noticeably, drive all frames from one shared clock (a `Sprite2D` whose `frame` is set from a single timer) instead of per-node animation. Measure first.
- **What reads `Body.color` today.** The player, `Enemy`, `Boss` (the telegraph, vulnerability and fuse tints) and the missile area set the rectangle's `color`, and about five tests read it. These become `set_tint` and a look choice, and the tests are updated deliberately, not left to fail.
- **Hit flash and tint.** The flash sets `modulate` to a bright white. A state tint also uses `modulate`, so the two must not fight: a flash returns to the current tint, not to white.
- **Size versus hit shapes.** A 16×16 sprite is larger than the 12×12 hit shapes. That is intended (the sprite is a little bigger than its box), but the boss and big enemies must still look like what they hit.
- **Palette discipline.** One wrong letter makes an off-palette pixel. The tool rejects an unknown letter, and a test rejects an off-palette pixel in the committed PNGs.
- **Import step.** New PNGs need `godot --headless --import` before tests that load them, as `class_name` scripts do.
- **Taste.** Tests cannot judge charm. The builder checks the look in a real window (screenshots), and the user tunes it in play.

## 5. Docs this sprint updates

`sprint-development.md` (13a's art and animation items ticked, a Built note), `README.md` (the art direction and how to replace art), `technical-design.md` (the new directories), `CLAUDE.md` (an "Art pipeline (Sprint 13a)" section), `development-log.md`, and the memory file.

## 6. Open questions for the user

None blocking. The resolution, the palette, the frame counts and the character designs are my calls above, so they can be tuned after play. A reference for the look (a game or an artist) would help the character design but is not required.
