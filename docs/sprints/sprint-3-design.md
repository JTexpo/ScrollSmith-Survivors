# Sprint 3 Design: Spell Areas and Behaviors

**Status:** Built. Approved by the user after a fresh builder check, then implemented on branch `sprint-3-spell-areas`.

Scope comes from `sprint-development.md` (Sprint 3), with one addition the user asked for in conversation: a fifth Area, **Wave**. Architecture follows `technical-design.md` (sections 5 and 9), `CLAUDE.md`, and `sprint-0/1/2-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprint 2 gave every spell the same delivery: a straight-line projectile. Sprint 3 makes the Area a real, separate part of a spell. A spell is still a Base (element) plus an Area, and now the Area decides **what the spell does in the world**: a thin instant beam, a close-range blast, a lingering zone dropped where the player points, a single missile, or a travelling wall of damage. Each Area has its own job, so the player picks by situation rather than by raw power.

Range is a **property each spell carries**, not something fixed per Area type. Every Area has a default (Cone short, Line long) and a spell can scale it. Sprint 6 crafting will let players trade range against mana (longer Cone, shorter and cheaper Line) by handing the spell a different number. Sprint 3 builds that seam and nothing more.

**Goals**
- Five Areas castable in play: Line, Cone, Area, Missile, Wave. Any Base can use any Area through data.
- Each Area is one scene behind one casting interface, so a new Area (even a teleport or a summon, someday) is a new scene and data, not an edit to existing ones. Sprint 7's Duplicate Area must not require editing individual Areas.
- Range and size are numbers on the spell (default per Area type times a per-spell scale). Mana cost is a number on the spell, set differently per Area.
- Area spells can be aimed with mouse, stick and touch.
- Line, Cone, Wave and Area hit every enemy in their shape, each once per hit. This is the "piercing" Sprint 2 left room for.

**Non-goals (later sprints)**
- Crafting, scrolls, and the rule "longer range costs more mana" (Spell Builder, Sprint 6).
- Buffs and Duplicate Area (Sprint 7). Additional Base rules.
- Enemy elemental affinities and resistances (Sprint 4). Final art, effects and audio (Sprint 13).

**Anti-goals** (a failure even if it technically works)
- `match area` or `if area == ...` branches in `SpellLoadout`, `Player` or `DamageSystem`. The loadout asks an Area scene to launch, nothing more.
- Range, width or angle hardcoded inside an Area script instead of coming from data.
- Elemental math or mana-cost formulas inside an Area scene.
- An Area spell that can't be aimed on a phone or controller.

## 2. Decisions

| Area | Decision |
|---|---|
| Area set | Five Areas: Line, Cone, Area, Missile, **Wave**. Wave is new scope the user asked for. `SpellData.AreaType` gains `WAVE` **appended at the end** so the existing `area = 3` (Missile) in `.tres` files keeps its meaning. |
| Wave | One wide crescent that travels outward like a Missile, shaped like a cone's front edge. Hits every enemy it passes through, each once. Widens a little as it travels. Disappears at max range. Not a fan of small missiles (that overlaps Sprint 7's Duplicate Area). |
| Roles | Missile: one target, long range. Wave: moving wall of damage, mid range. Cone: instant, close range. Line: instant, long and thin. Area: lingering zone at a chosen spot. |
| Structure | **One scene per Area, plus an `AreaData` resource per type** (user chose this from three approaches, section 3). Each Area scene's root script extends one base class and implements one call: `launch(spell, origin, direction, target)`. `SpellLoadout.try_cast` instantiates the spell's Area scene and calls it. |
| `AreaData` | Per-type defaults and the scene: `scene`, `default_range`, plus the default shape numbers that type needs (Line width, Cone angle, Area radius and duration and tick interval, Wave width and widening, Missile size). |
| Spell scaling | `SpellData` gets `area_data`, `range_scale` (default 1.0) and `size_scale` (default 1.0). Effective range = `default_range * range_scale`. `size_scale` multiplies the type's main size (Line width, Cone angle, Area radius, Wave width, Missile size). Sprint 6 crafting writes these two numbers. |
| One range concept | The same range number is Line length, Cone reach, Wave travel distance, Missile range, and **how far from the player an Area can land** (the clamp for targeting). Missile's lifetime becomes range / speed. |
| Mana cost | Stays an authored number on each spell `.tres`, different per Area (user: "different mana costs for different Areas"). The rule linking range and cost is Sprint 6's Spell Builder (my call, because `CLAUDE.md` says the builder is separate from the Areas). A test shows one Area working at two ranges. |
| Damage | Every Area gets its damage from `DamageSystem.calculate` through one shared helper on the base class, so Sprint 4 moves the elemental multiplier to hit time in one place (the same known limitation as Sprint 2). |
| Hits | Line, Cone and Wave hit each enemy in their shape **once per cast**. Area hits each enemy inside **once per tick** (tick interval is data). Missile keeps `max_hits` (1 on all spells). |
| Instant shapes | Line and Cone are a hitbox that exists for a short window (about 0.1 s, my call) and then frees itself, with a visible flash of the shape. |
| Area targeting | Mouse: the cursor, clamped to the spell's range. Stick and touch: the spell's **full range** in the aim direction (my call; this is the user's "set distance"). A small reticle shows the clamped landing spot while an Area spell is selected. One function computes the clamped target and is used by both the cast and the reticle. |
| Aim input | `AimComponent` exposes an aim point alongside the direction. For the mouse it is the cursor, for a stick it is a point far out along the direction, and the Area does the clamp. |
| Starting slots | Slots 1–5 hold the five example spells: Fire Missile, Thunder Cone, Land Area, Sea Line, Sea Wave (my call, so every Area is playable). Spell `.tres` files are renamed by element plus Area. Two Sea spells share a colour but not a shape. |
| Holding fire | Unchanged: hold repeats casts gated by cast interval and mana. Overlapping Area zones from repeated casts both tick (a cost the player chooses, paid in mana). |
| Docs | The README, `technical-design.md`, `sprint-development.md` and `CLAUDE.md` currently say four Areas. They are updated to five, including a Wave entry, as part of the sprint. |
| One source of truth for the Area | `AreaData` is authoritative and carries its own `type` (the `AreaType` enum stays, now including `WAVE`). The exported `SpellData.area` field is removed, and `SpellData.area_type()` reads it from `area_data`, so a spell can never say Line while holding a Missile (my call, from the builder check). |
| No type branching for targeting | `AreaData` has a `needs_ground_target` flag. The aim point and the reticle read that flag, never the type (my call). |
| Hit-once and ticks | Reuse `HitboxComponent` unchanged. "Once per cast" is `hit_cooldown` longer than the effect's life, as Missile does today. Area's tick is `hit_cooldown = tick_interval`. Tests drive it through `try_hit(target, now_msec)`, which already takes a time (my call). The wall-clock limit stays a known limit. |
| Stick not held | Casting uses the stored aim direction, as Missile does today. The reticle shows whenever an Area spell is selected, at the clamped aim point. With the mouse on top of the player it sits on the player (my call). |
| Origin | Every Area starts at the player's centre, like Missile now. Instant shapes are fixed where cast and don't follow the player during their short window (my call). |
| Speed field | `projectile_speed` stays on `SpellData` and only Missile and Wave read it. `projectile_lifetime` is removed (my call). |
| Knockback | Uses the existing `SpellData.knockback`, pushing enemies away from the hitbox's position: the player for Line and Cone, the zone centre for Area, the wave's current position for Wave (my call). |

## 3. Approaches considered

1. **One scene per Area plus `AreaData` (chosen by the user).** Each Area is a self-contained scene and script behind one call. New and unusual effects (even teleportation or summoning) are new scenes. Extends the pattern Missile already uses.
2. **One generic effect scene with a shape switch.** Least code at first, but every new Area edits one big script. Breaks the "interchangeable behaviours" rule in `technical-design.md` section 9.
3. **Plain script objects with no scenes.** Easiest to unit-test, but hitboxes and visuals must be built in code, which makes placeholder art and Sprint 13's effects harder.

## 4. Constraints

- All earlier sprint constraints apply: Godot 4.7.2, typed GDScript, no new autoloads, Input Map actions only (device -1), web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Collision layers stay as in Sprint 1. Area effects are player-side hitboxes that detect enemy hurtboxes, as projectiles do.
- The Player holds no spell logic. `SpellData` and `AreaData` hold gameplay numbers, not scripts.
- Frame time must stay above the 60 fps target at 300 enemies with the new Areas firing.

## 5. Design

### Base class and interface
A small base class (for example `AreaEffect`, a `Node2D`) with `launch(spell: SpellData, origin: Vector2, direction: Vector2, target: Vector2)`, shared damage-setup helper (calls `DamageSystem.calculate`), and the effective range and size read from `SpellData`. Each Area scene's script extends it. Missile's existing `SpellProjectile` becomes the Missile Area.

### Areas
- **Line:** a rectangle from the player, length = range, width = size. Instant window, hits all inside once.
- **Cone:** a sector from the player, reach = range, angle = size. Instant window, hits all inside once.
- **Area:** a circle centred on the clamped target, radius = size, lasting `duration`, damaging each enemy inside once per `tick_interval`.
- **Missile:** the existing projectile, now with range, size and speed.
- **Wave:** a crescent hitbox moving at speed, widening by `widen_rate`, freeing itself at range, each enemy hit once.

### SpellData and SpellInstance
`SpellData` gains `area_data: AreaData`, `range_scale`, `size_scale`, with helpers for effective range and size, and `area_type()` read from `area_data`. The exported `area` field is removed. `projectile_scene` is replaced by `area_data.scene`. `projectile_lifetime` is replaced by range / speed. `projectile_speed` stays (Missile and Wave use it). `SpellInstance` is unchanged: it still owns mana and cooldown.

### SpellLoadout
`try_cast(origin, direction, target)`: same mana and cooldown gate, then instantiate the spell's Area scene, add it to the root, call `launch`. This is the seam Sprint 2 left; no per-Area branching.

### Aim and reticle
`AimComponent` exposes the aim point. A temporary `TargetReticle` shows the clamped landing spot only while an Area-type spell is selected, and hides otherwise. It reads from the loadout and the aim; it changes nothing.

### Data
Five `AreaData` `.tres` files and five spell `.tres` files under `resources/spells/` (names by element plus Area). The stress spell stays a Missile so the Sprint 2 baseline remains comparable.

## 6. Testing

- GUT unit tests: `AreaData` defaults load (Cone short, Line long); effective range and size follow the scales; one Area at two ranges; each Area hits every enemy in its shape once and misses enemies outside it; Line, Cone and Wave hit several enemies in one cast; Area ticks on its interval and ends after its duration; Wave widens and ends at range; Missile still dies on its first hit; `try_cast` launches the spell's own Area with no per-type branching; depleted spell still does nothing; Area target is clamped to range for the mouse and is at full range for a stick; reticle shows only for Area spells.
- Update the Sprint 2 tests that use the old projectile fields and starting spells.
- Headless smoke run plus a godot MCP run with no warnings, then the stress test with each Area firing at a high rate (not only Missile) to confirm 60 fps at 300 enemies.
- Manual checklist: cast each of the five spells (keys 1–5), confirm each shape and each enemy hit once, drop an Area with the mouse and confirm the clamp, aim an Area with a stick or touch and confirm the full-range landing, watch mana fall at different rates, deplete a spell and confirm nothing fires or switches.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Starting numbers per Area and per spell: default range, widths, angle, radius, duration, tick interval, wave widening, damage, cast interval, mana cost and pool.
- The instant-window length for Line and Cone.
- Placeholder visuals for each shape, and the reticle look.
- How the Area scenes build their hit shapes (for example a polygon for Cone and Wave).
- Whether the Area base class and `AreaData` live under `scripts/spells/` and `resources/spells/` or in a new folder.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Per-Area branching creeps into `SpellLoadout` | A test launches a spell whose `AreaData` scene is a test stub and checks the stub's `launch` ran. |
| Changing `AreaType` order breaks saved `.tres` values | `WAVE` is appended after `MISSILE`. A resource test pins each `AreaData`'s type and each spell's `area_type()`. |
| Instant hitboxes miss enemies because an `Area2D` needs a physics frame to see overlaps | The window is long enough for at least one physics frame, and tests assert enemies inside are hit. |
| Many overlapping Area zones or waves hurt frame time | Stress test each Area at a high fire rate before calling the sprint done. |
| The once-per-target guarantee uses real time (`hit_cooldown` is wall-clock) | Same known limit as Sprint 2. Still safe with no pause yet. Revisit when pause exists. |
| Stick-aimed Areas land at full range and may feel far | Range is data. Short-range crafted spells land nearer. Tune by playing. |
