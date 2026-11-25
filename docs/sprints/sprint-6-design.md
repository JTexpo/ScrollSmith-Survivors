# Sprint 6 Design: Arcane Lectern and Spell Crafting

**Status:** Built. Approved by the user after a fresh builder check, then implemented on branch `sprint-6-crafting`.

Scope comes from `sprint-development.md` (Sprint 6). Architecture follows `technical-design.md` (sections 5 and 7), `CLAUDE.md`, and `sprint-0` to `sprint-5-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

This is the game's defining mechanic. The player starts with one spell and a few slots locked behind later levels. Scrolls dropped by enemies are the ingredients, and Arcane Lecterns around the arena are where the player turns them into new spells. Mana never regenerates, so crafting is also how a run keeps going: when a spell runs dry, the player finds scrolls, reaches a Lectern, and builds a replacement. Crafting is deliberate, so the world pauses while the crafting screen is open, and the player can compare options without being rushed.

**Goals**
- A **Spell Builder** that turns a Base scroll, an Area scroll and a range choice into a working spell, with every number in data. It is independent of any UI or Lectern.
- A **Crafting System** that validates a recipe, consumes the scrolls all-or-nothing, and equips the new spell. An invalid recipe never touches the player's scrolls.
- A **range choice** at crafting: longer range costs more mana per cast, shorter costs less (user request, Sprint 3).
- A **Lectern** the player must walk up to, plus a **one-screen crafting workbench** with a live preview that also shows the current spell for comparison.
- **Slots**: the player starts with one unlocked slot holding Fire Missile. The loadout supports locked slots and replacing a spell. Sprint 8's levels will unlock more.
- **Pause**: the whole world stops while crafting, with a pause-aware clock so timed effects stay correct afterwards.

**Non-goals (later sprints)**
- Buff effects and selecting buffs (Sprint 7), Additional Base and multi-element spells, Duplicate Area.
- Levels, XP and the real slot unlocks (Sprint 8). Sprint 6 only builds the unlock mechanism and a debug key.
- A general pause menu, settings, discovering Lecterns across a larger map, final art and audio.
- Choosing an Area's size (width, angle, radius) at crafting. Only range is chosen.

**Anti-goals** (a failure even if it technically works)
- Crafting or stat rules inside the Lectern, the screen or `Player`. The UI only calls the Crafting System.
- A scroll consumed by a craft that then fails, or a half-consumed recipe.
- Hardcoded stats for any Base and Area combination. Every combination comes from the same rule and the same data.
- Spending mana or firing a spell because the click that confirmed a craft is still held when the game resumes.
- A hit cooldown that expires during a pause and lets an effect hit the same enemy twice.

## 2. Decisions

| Area | Decision |
|---|---|
| Recipe | Exactly one Base scroll, exactly one Area scroll, and a range option. Each scroll used costs one of that scroll. Buff scrolls are shown but **locked** until Sprint 7 (user agreed), so none are wasted. |
| Stats rule | Each Area carries baseline numbers (`AreaStats`: damage, cast interval, mana cost, mana pool, projectile speed, knockback). Each Base scroll carries multipliers (`BaseModifiers`, 1.0 is neutral) that keep today's personalities (Thunder fast and light, Land slow and heavy, Sea in between). Final damage, interval, speed and knockback are baseline times multiplier. Final mana cost is baseline times the Base's cost multiplier times the range option's cost multiplier. The mana pool is baseline times the Base's pool multiplier, so a longer range gives fewer casts from the same pool. Fire plus Missile at Normal range must reproduce the starting Fire Missile in every number except the pool (10 damage, 0.35 s, cost 1, speed 220, knockback 120). The starting spell has a pool of 1000 (user decision below) and a crafted spell uses the Area baseline of 100. Speed only matters for Missile and Wave, `max_hits` only for Missile (the other four Areas hit every enemy in their shape once), and damage and knockback apply to all five. Only Fire plus Missile is pinned. Every other pair comes from the same rule, and the hand-made Thunder Cone, Land Area, Sea Line and Sea Wave files stay as examples with their own numbers (my call). |
| Opening ease | User decision: the player starts with one spell, mana never regenerates, and Lecterns are off-screen, so the opening is made forgiving through data only. The starting Fire Missile pool goes from 40 to **1000 casts** (the user raised it from 100 so the player has more time to find resources; crafted spells keep the Area baseline pool of 100) and the scroll `drop_chance` goes from 0.06 to **0.10** in every drop table. No starter scrolls and no guaranteed drops. Tune by playing, and the dev log flags it. |
| Lecterns | Reusable, unlimited and free. The scrolls are the only cost, and nothing about a Lectern is consumed (my call). |
| Replacing a spell | The preview shows what the craft replaces, for example "Replaces Fire Missile (12 / 100 mana left)", and warns when the old spell still has mana. Confirm is the confirmation step, and the old spell's remaining mana is lost (my call). |
| Pause scope | `HitboxComponent.try_hit` is the only gameplay code on the real-time clock. Spawn timing, Area zone ticks and the player's invulnerability already advance with frames and stop with the pause. The death screen's input delay stays real-time on purpose, since the player cannot die while paused (my call, checked in the code). |
| Range options | A data table (`CraftingRules`): Short (range x0.6, cost x0.7), Normal (1.0, 1.0), Long (1.5, 1.4), Very long (2.0, 1.8). Size scale stays 1.0. Starting numbers, tune by playing (my call). |
| Generated spell | `SpellBuilder.build(...)` returns a fresh `SpellData` (not saved to disk): elements from the Base, `area_data` from the Area scroll, `range_scale` from the option, colour from the Base scroll, name "<Base> <Area>" with the range word added unless Normal, an id from the parts, `max_hits` 1. |
| Crafting System | `CraftingSystem.validate(request, inventory, loadout)` returns a result with `ok` and a reason string. `craft(request, inventory, loadout)` validates, builds, removes all scrolls (all-or-nothing), equips, and returns the result. It reads and changes only the inventory and loadout it is given, and emits nothing UI-specific. |
| Validation | A Base is present and is a Base scroll. An Area is present and is an Area scroll. The range option exists. The target slot is unlocked. The inventory holds each scroll. A buff list, if given, must be empty in Sprint 6 (locked). |
| Slots | `SpellLoadout` gains `unlocked_slots` (default 5 so existing loadouts behave as before, set to 1 on the player), `is_unlocked(index)`, `unlock_next()`, `equip(index, spell_data) -> SpellInstance` (fresh instance with a full pool, refuses locked, out-of-range or null), and signals `slot_changed(index)` and `slot_unlocked(index)`. `select` and `cycle` skip locked slots. Locked slots hold no spell. |
| Starting loadout | Fire Missile only, in slot 1. The other four hand-made spell files stay as examples and for the stress test. |
| Spell bar | Locked slots show dimmed with a lock mark and ignore taps and keys. The bar rebinds a slot when `slot_changed` fires (a new instance has a new mana signal). |
| Debug | F11 (`debug_unlock_slot`, handled in `Main`, DEBUG like F9 and F10) unlocks the next slot, so multi-slot play can be tested before levels exist. |
| Lectern | A static scene enemies ignore. It sits on a new collision layer `interactable` (bit 64). Three Lecterns at fixed spots around the arena, spread so the player has to travel (my call). Placeholder look. It has no crafting logic: it only says "I was interacted with". |
| Interaction | The Player carries an `InteractionComponent` (an `Area2D` watching the `interactable` layer) that tracks the nearest interactable in range. The `interact` action (E, controller A) calls it. A prompt appears only when one is in range. On touch an on-screen Interact button appears in range and calls the same code. A dead player cannot interact. |
| Pause | Opening the crafting screen pauses the scene tree (`process_mode` Always on the screen only). A small `GameTime` helper provides a clock that stops while paused, and `HitboxComponent.try_hit` uses it instead of the real-time clock, so once-per-target guarantees survive a pause. |
| Resume | After the screen closes, casting stays off until the cast input has been released, so the confirming click cannot fire a spell. |
| Crafting screen | One screen (user choice). Top: the five spell slots (name, colour, mana, locked state) to pick the target slot. Middle: lists of owned Base scrolls, owned Area scrolls, and the range options, with a locked Buff row. Right: a live preview (damage, interval, mana per cast, mana pool, casts per pool, range) beside the target slot's current spell, a validation message, and Confirm and Cancel. It works with mouse, touch (the project turns mouse emulation off, so touches are bridged for this screen) and keyboard or controller focus. Cancel is Esc, controller B, or the button. |
| Per run | Crafted spells and unlocked slots reset with a restart, like everything else. |
| Docs | The README (one starting spell, crafting), `technical-design.md` section 7, `sprint-development.md` and `CLAUDE.md` are updated. |

## 3. Approaches considered

**Crafting screen layout.**
1. **One workbench screen (chosen by the user).** Everything visible at once, with a live preview and the current spell beside it, so comparing is easy and nothing is rushed.
2. A step-by-step wizard. Tidier on a small screen, but you can't see everything or compare freely.

**Spell Builder data.** One sensible way: baselines on the Area, multipliers on the Base scroll, range options in a rules resource, so no combination is hand-written and balance is a data edit.

**Pause.** One sensible way: pause the scene tree and give hit cooldowns a clock that stops with it. The alternative, running the world during crafting, was rejected by the user.

## 4. Constraints

- All earlier sprint constraints apply: Godot 4.7.2, typed GDScript, no new autoloads (so `GameTime` is a static helper), Input Map actions only (device -1 on every event), web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Collision layers 1 to 6 are unchanged. One new layer, `interactable`, is added.
- Gameplay numbers live in resources. The UI reads and calls systems and never edits gameplay data directly.
- Frame time must stay above the 60 fps target at 300 enemies, with the pause helper in place.

## 5. Design

### Data
`AreaStats` and `BaseModifiers` resources. `AreaData` gains `base_stats`. `ScrollData` gains `modifiers` (Base scrolls only). `CraftingRules` holds the range options (label, `range_scale`, `cost_multiplier`). One `.tres` per Area baseline and per Base modifier, plus the rules file.

### Builder and crafting
`SpellBuilder` (static, no state) and `CraftingSystem` (static or a small `RefCounted`) in `scripts/crafting/`. A `CraftingRequest` (base, area, range option index, buffs, target slot) and a result with `ok`, `reason` and the built spell.

### Loadout and bar
The loadout changes above, and `SpellBar` and `SpellSlotWidget` learn the locked state and `slot_changed`.

### Lectern and interaction
`Lectern` scene and script, `InteractionComponent` on the Player, an Interact button for touch, and three Lecterns in `main.tscn`. Layer `interactable` in `PhysicsLayers` and `project.godot`.

### Pause and clock
`GameTime` (static `now_msec()`, `freeze()`, `unfreeze()`, `reset()`), used by `HitboxComponent`. A small helper opens and closes the pause together with the clock. `Main` resets the clock on load.

### Crafting screen
`CraftingScreen` (a `CanvasLayer`, TEMPORARY look) bound to the inventory, the loadout and the rules. It builds a request from the player's choices, asks the builder for the preview and the Crafting System to validate and craft. Touch bridging lives inside the screen.

## 6. Testing

- GUT unit tests: `SpellBuilder` (Fire plus Missile at Normal reproduces the current Fire Missile exactly; every Base and Area pair builds; longer range raises cost and lowers casts; shorter lowers cost; Land is slower and heavier than Thunder; the name and id are right). `CraftingSystem` (a valid craft consumes exactly one of each scroll and equips; each invalid case leaves the inventory and loadout unchanged: no Base, no Area, wrong category, missing scroll, locked slot, bad range option, buffs given; a failed craft never consumes). `SpellLoadout` (unlocked slots, `equip` into empty, replace, locked and out-of-range refused, fresh full mana, `slot_changed` and `slot_unlocked` signals, select and cycle skip locked slots, selection survives a replace). `SpellBar` (locked slots dimmed and inert, a replaced slot follows the new instance's mana). `Lectern` and `InteractionComponent` (nearest wins, out of range does nothing, `interact` opens, a dead player cannot). `GameTime` (frozen clock does not advance, resumes without a jump, reset). `HitboxComponent` (cooldown survives a simulated pause: no second hit when the frozen clock has not advanced). Resume guard (no cast until release). `CraftingScreen` (preview matches the builder, Confirm disabled with a reason when invalid, Cancel changes nothing, confirm crafts and closes, the target slot's current spell is shown, the Buff row is locked).
- Update tests that assume five starting spells (the player's and the spell bar's), Fire Missile's old pool of 40, and the 6% drop chance (now 10%).
- Headless smoke run plus a godot MCP run with no warnings, then the stress test to confirm no regression.
- Manual checklist: the player starts with only Fire Missile and four locked slots, find a Lectern (they are off-screen at the start), the prompt appears only when near, E (or the touch button) opens the screen and the world stops, build a spell and compare it against the current one, longer range shows higher cost and fewer casts, confirm consumes exactly the scrolls used, the new spell works and the bar updates, Cancel changes nothing, the confirm click does not fire a spell, resume and effects behave, F10 gives scrolls and F11 unlocks slots, restart resets everything.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Starting numbers: every Area baseline, every Base modifier, and the range options.
- Lectern spots and look, the interaction radius, prompt and Interact button placement.
- The crafting screen's exact layout and how touch is bridged.
- How the resume guard is implemented.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Crafting math or rules leak into the UI or the Lectern | The screen only builds a request and calls `SpellBuilder` and `CraftingSystem`, and tests exercise the logic with no UI. |
| A failed craft eats scrolls | `craft` validates everything before changing anything and removes all scrolls as one step, with a test for every invalid case. |
| Fire Missile changes feel | A test pins Fire plus Missile at Normal to today's numbers, and the other pairs derive from the same data. |
| Pause breaks timed effects | `GameTime` freezes with the pause and `HitboxComponent` uses it, with a test for a simulated pause. |
| The confirming click fires a spell on resume | Casting waits for the cast input to be released after the screen closes, with a test. |
| Touch does not work on a paused modal screen (mouse emulation is off) | The screen bridges touches itself, with a test of the bridge and a manual touch-emulation check. |
| A one-spell start can dead-end a run | The starting pool is 1000 casts and the drop chance is 10% (user decision). Both, and the Lectern count, are data, and the dev log flags the opening for play-testing. |
| Many things at once | The sprint is built in layers (builder and rules, loadout, pause, Lectern, screen), each tested before the next. |
