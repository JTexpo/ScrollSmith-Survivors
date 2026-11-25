# Sprint 7 Design: Buff System

**Status:** Built (Sprint 7).

Scope comes from `sprint-development.md` (Sprint 7). Architecture follows `technical-design.md` (sections 5, 7 and 8), `CLAUDE.md`, and `sprint-0` to `sprint-6-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprint 6 let the player craft a spell from one Base and one Area. Sprint 7 makes the third part real: the six buff scrolls the player has been collecting now change a spell. A buff is a trade. Each one makes the spell stronger in some way and always makes every cast cost more mana, and because mana never regenerates, a spell piled high with buffs burns through its pool faster. The player decides how far to push.

**Goals**
- All six buffs work: Increased Max Mana, Increased Damage, Double Vulnerability Damage, Ignore Resistance, Duplicate Area and Additional Base.
- Buffs are data: each buff scroll carries an effect resource, so balancing a buff is a data edit and a new buff of the same kind is a new file.
- Buffs stack, each stack raises the mana cost per cast, and the crafting screen shows the result and its drawbacks before the player confirms.
- A spell can have several elements. A hit uses the best match (the user's vision), and the damage system stays the only place elemental rules live.
- Duplicate Area makes one cast launch a ring of copies without any Area scene being edited.

**Non-goals (later sprints)**
- XP, levels and slot unlocks (Sprint 8), new buffs beyond the six, choosing an Area's size at crafting, enemies with more than one element, final art and effects.
- Per-element visuals for hybrid spells (a hybrid is tinted with its first element for now).

**Anti-goals** (a failure even if it technically works)
- Code that branches on a buff id anywhere in the builder, the loadout, the hit code or the screen. Effects come from the effect resource.
- A craft that consumes some scrolls and then fails, or a spell that can never cast.
- A buff that raises a spell's output per cast (damage, or the number of copies) while costing less than that output. Its cost multiplier must be at least what it multiplies, so stacking damage or copies is a burst-versus-endurance choice and never free value. Increased Max Mana is the deliberate exception: it trades a small cost increase for a bigger pool and nets a modest gain in casts, because it is the endurance buff. Double Vulnerability, Ignore Resistance and Additional Base are situational and carry modest premiums.
- Elemental math outside `ElementTable` and `DamageSystem`, or Duplicate Area needing edits to individual Areas.

## 2. Decisions

| Area | Decision |
|---|---|
| Buff data | A `BuffEffect` resource on each Buff scroll (user choice, like the Base scrolls' multipliers). Per stack it holds: `damage_multiplier`, `max_mana_multiplier`, `cost_multiplier`, `vulnerability_bonus`, `ignores_resistance`, `extra_copies`, `extra_bases` and `max_stacks` (0 means unlimited). `ScrollData.buff` points at it, and `buff_id` stays as the scroll's name. |
| Folding buffs | The Spell Builder folds the chosen buffs into the spell. Multipliers multiply once per stack. `vulnerability_bonus`, `extra_copies` and `extra_bases` add up per stack. `ignores_resistance` is true if any stack sets it. |
| Starting numbers (tune by playing, my call) | Increased Damage: damage x1.5 and cost x1.5 per stack. Increased Max Mana: pool x1.5 and cost x1.25 per stack. Double Vulnerability: vulnerability bonus +1.0 and cost x1.25 per stack. Ignore Resistance: flag, cost x1.25, `max_stacks` 1. Duplicate Area: +1 copy and cost x2.0 per stack, `max_stacks` 4 (so the cost for c shots is 2 to the power c minus 1, never less than c, and copies are never a bargain). Additional Base: +1 element slot and cost x1.8 per stack, `max_stacks` 3. A test pins the rule: Increased Damage's cost multiplier is at least its damage multiplier, and for 1 to 4 Duplicate Area stacks the cost is at least the number of shots. |
| Caps (user and README) | Damage, pool and vulnerability stacks have no cap (user decision, because cost keeps them honest). Duplicate Area stops at 4 stacks (5 shots, README). Additional Base stops at 3 stacks (4 elements, one per element). Ignore Resistance stops at 1. |
| Multiple elements | **Best match** (user decision): when a hit lands, each of the spell's elements is compared with the enemy's, and the hit uses the one that does best. A hybrid is therefore never resisted when another element is neutral or better, and it gets the vulnerable bonus whenever any element has it. The cost premium (x1.8 per extra element) pays for that. Enemies still have one element. The damage number's style follows the winning element's effect. |
| Choosing the extra elements | Each Additional Base stack opens one more Base slot on the workbench. The Base column becomes multi-select: the allowed number of elements is 1 plus the Additional Base stacks. Each extra element needs its own Base scroll, and a spell can't use the same element twice. Averaging: a hybrid's stats use the mean of its Base scrolls' multipliers (my call). Its tint and name come from the Base scrolls in the order chosen ("Fire+Sea Missile"). |
| Double Vulnerability | It scales the vulnerable bonus: a strong hit's bonus (1.5x is +0.5) is multiplied by 1 plus the bonus stacks. One stack makes it 2.0x, two make 2.5x (user: "doubles bonus damage"). It applies to the winning element's hit only, the bonus is worked out from the table's multiplier (the table is unchanged), and a table multiplier at or below neutral has no bonus to scale (a guard, so a misconfigured table can't make it negative). |
| Ignore Resistance | A resisted multiplier is replaced by the neutral one for that spell, and the hit counts as neutral for the damage number. |
| Mana cost | The cost per cast is the Area baseline times the Base multiplier mean, times the range option, times every buff stack's cost multiplier. Copies do not cost extra on their own: the Duplicate Area stack's multiplier already pays for them. A spell whose cost is more than its pool could never cast, so crafting refuses it ("too costly to cast"). |
| Duplicate Area | A new `copies` number on the spell (1 plus the extra copies). The loadout asks a small cast-pattern helper for the list of shots and launches each one through the same `launch` call, so no Area is edited. **Ring** (user decision): aimed Areas fire copies evenly around the player with one on the aim (copies 2 means opposite sides, 3 means 120 degrees apart, 5 means 72 degrees apart). Ground-targeted Areas keep the first zone at the chosen spot and place the others in a ring around it (my call: ring radius is 1.5 times the zone radius). "Ground-targeted" means the Area's `needs_ground_target` flag, never its type, and each zone is held within the spell's range from the player by the existing clamp (the arena edge is not a limit). Every copy starts at the player's centre. One cast spends mana once. Each copy is a full, independent Area, so overlapping copies each damage the same enemy: that is what copies are for, and the x2 cost per stack pays for it. |
| Hit data | The hitbox carries the spell's elements plus a vulnerability scale and an ignore-resistance flag, and the hurtbox gives them to `DamageSystem`, which does the best-match, vulnerable and resistance maths. The existing single-element calls keep working (my call, so enemies' contact hits and tests stay as they are). |
| Crafting rules | A request now holds a list of Base scrolls and a list of buff scrolls (repeats are stacks). It is valid only if: the Base count is **exactly** 1 plus the Additional Base stacks (so an Additional Base scroll can never be spent on nothing, and the screen says "Pick N more Base scrolls for your Additional Base"), no element repeats, every scroll is owned in the quantity used, the stack caps hold, and the spell could cast at least once. The screen only offers scrolls the player owns, as in Sprint 6, so Confirm is disabled with a reason until the choices are complete. A craft removes every scroll used all-or-nothing, and a failed craft changes nothing. |
| Crafting screen | Still one screen (user decision). The Base column becomes multi-select. A buff row has a minus and a plus for each buff scroll the player owns, limited by what they own and by the caps. The preview adds the elements, copies, vulnerability, ignore-resistance, cost per cast and casts per pool, and states the drawback in plain words (for example "Costs 5.1x per cast: 100 casts become 29"). It also shows the current spell's casts for comparison. |
| Docs | The README, `technical-design.md` section 8.3 and `CLAUDE.md` currently say the multi-Base rules are undecided. They are updated to "best match", with the stacking and cost rules. |

## 3. Approaches considered

**How buff effects are described.**
1. **A data resource per buff scroll (chosen by the user).** Balance is a data edit and it tests easily.
2. A small script per buff. More flexible for exotic future buffs, but the logic scatters and is harder to balance and test.

**Where Duplicate Area lives.** One sensible way: the cast layer, so the rule "modifiers must not require editing individual Areas" holds.

**Where the best-match logic lives.** One sensible way: inside `DamageSystem`, the single place elemental rules live.

## 4. Constraints

- All earlier sprint constraints apply: Godot 4.7.2, typed GDScript, no new autoloads, Input Map actions only (device -1 on every event), web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Gameplay numbers live in resources. The UI reads and calls systems and never edits gameplay data directly.
- Frame time must stay above 60 fps. Copies multiply the number of live Area effects, so the stress test covers a five-copy spell.

## 5. Design

### Data
`BuffEffect` resource (`resources/crafting/buff_effect.gd`) and `ScrollData.buff`. Six `.tres` effect files, one per buff scroll, referenced from the scroll files.

### Spell and builder
`SpellData` gains `copies` (default 1), `vulnerability_scale` (default 1.0), `ignores_resistance` (default false) and a record of its buff stacks for display. `SpellBuilder.build` takes a list of Base scrolls, an Area scroll, a range option and a list of buff scrolls, and folds them as above. `SpellBuilder.describe` reports the new numbers.

### Hit and damage
`DamageSystem` gains a best-match calculation over a list of attacker elements with a vulnerability scale and an ignore-resistance flag, returning the amount and the effect. `HitboxComponent` and `AreaEffect._configure_hitbox` pass the spell's elements and flags. `HurtboxComponent.receive_hit` uses the new calculation and keeps its single-element behaviour for existing callers.

### Cast pattern
A static helper turns a spell, an origin, an aim direction and a target into the list of shots (direction and target). `SpellLoadout.try_cast` launches each shot through the existing `launch` call.

### Crafting
`CraftingRequest` holds `bases` and `buffs`. `CraftingSystem` validates and consumes as described. `CraftingSession` gains multi-select Base choices and buff stacks, and the drawback lines.

### Screen
The workbench gets a buff row with steppers, multi-select Base buttons, and the extended preview. It keeps the 480x270 layout.

## 6. Testing

- GUT unit tests: each `BuffEffect` file loads with the starting numbers and is referenced by its scroll. The builder folds each buff alone and in combinations (multipliers multiply, adds add, flags or), keeps single-Base spells identical to Sprint 6 results when no buffs are used, averages multiple Base scrolls, refuses recipes beyond the caps, and a hybrid's name and tint follow the Base order. The damage system picks the best element for every attacker and defender pair, doubles only the vulnerable bonus, bypasses resistance, handles an empty list and the `NO_ELEMENT` value, and reports the winning effect. The cast pattern gives the expected directions for 1 to 5 copies and the ring of zones for ground-targeted Areas. The loadout launches one effect per shot and spends mana once. `CraftingSystem` and `CraftingSession`: every invalid case leaves the inventory and loadout unchanged (too many Bases, a repeated element, a missing or insufficient scroll, a stack over its cap, a spell that could never cast), and a valid craft removes every scroll used. The screen: buff steppers respect ownership and caps, the Base column limit follows Additional Base stacks, the preview and drawback text match the builder, and Confirm explains why it is disabled.
- Update the Sprint 6 tests that assume one Base scroll or that buffs are locked.
- Headless smoke run plus a godot MCP run with no warnings, then the stress test, including a five-copy spell for each Area, to confirm 60 fps.
- Manual checklist: craft each buff alone and see its numbers in the preview, stack Increased Damage a few times and watch the cost and casts per pool fall in step, craft a Fire+Sea hybrid and see yellow "!" numbers against both Fire and Land enemies, craft Duplicate Area and see a ring of shots, craft with Ignore Resistance and see no grey numbers, confirm a refused recipe keeps every scroll, and try the screen with touch.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Exact starting numbers for each buff.
- The ring radius for ground-targeted Areas and how a hybrid's tint is chosen.
- The workbench layout for the buff row and the multi-select Base column.
- How the hit API is extended while keeping existing callers working.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Copies multiply live effects and hurt frame rate | A five-copy stress test for every Area, and the numbers go in the dev log. If it falls below 60 fps at the stress test's very fast interval, the log also gives the numbers at each Area's real interval. |
| The workbench runs out of room | The buff row reuses the band that now says "locked", and multi-select reuses the Base column. The screen is checked in real screenshots. |
| Uncapped stacking creates a spell that can never cast | Crafting refuses a spell whose cost exceeds its pool, with a plain reason. |
| Changing the hit data breaks existing callers and tests | The single-element calls keep working, and the suite runs after every task. |
| Best-match changes how every damage number looks | The number style follows the winning element's effect, and a test pins each case. |
| Balance: stacking feels dull or broken | Every number is data, and the dev log flags buff balance for play-testing. |
