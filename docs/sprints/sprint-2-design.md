# Sprint 2 Design: Base Spell System

**Status:** Built. Approved by the user after a fresh builder check, then implemented on branch `sprint-2-base-spells`.

Scope comes from `sprint-development.md` (Sprint 2). Architecture follows `technical-design.md` (section 5), `CLAUDE.md`, `sprint-0-design.md` and `sprint-1-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprint 1 gave the player a stand-in attack. Sprint 2 replaces it with real spells, built from data: each spell has an element, damage, its own mana pool and a cast interval. Mana never regenerates, so every cast is a decision. The player holds up to five spells in slots, picks one at a time, and a spell that runs dry simply stops working until the player chooses another on purpose. The mana pool, the slot loadout and the damage path built here are what crafting (Sprint 6) and buffs (Sprint 7) will plug into.

**Goals**
- Four elemental spells (Fire, Thunder, Land, Sea) castable in play, each with its own damage, mana capacity, mana cost and cast interval.
- Per-instance mana: two instances of the same definition never share mana.
- A resource-limited feel: a depleted spell never casts, never auto-switches, and never wastes the player's other spells.
- Slot selection that works on keyboard (1–5), controller-free for now, and on phones (on-screen slot buttons).
- All spell numbers live in `SpellData` `.tres` files, not in scripts.

**Non-goals (later sprints)**
- Areas (Line, Cone, Area), which are Sprint 3. Every Sprint 2 spell is delivered by a straight-line projectile.
- Enemy elemental affinities, resistances and visible vulnerability feedback (Sprint 4).
- Scrolls, crafting, the Lectern, buffs, multi-Base rules, slot unlocks, potions, final art and audio.

**Anti-goals** (a failure even if it technically works)
- A mana model where two copies of one spell drain each other.
- A depleted spell that fires anyway, or that swaps itself out so the player burns another spell by accident.
- Spell logic hardcoded per element, so Sprint 3's Areas or Sprint 7's buffs force a rewrite.
- Elemental math anywhere except `DamageSystem`.

## 2. Decisions

| Area | Decision |
|---|---|
| Definition vs instance | `SpellData` (Resource) is static configuration. `SpellInstance` (plain `RefCounted`) is built from it and owns current mana and the cast cooldown. Chosen by the user from three approaches (section 3). |
| Loadout | A `SpellLoadout` component on the player holds five slots and the selected index. The player delegates to it and holds no spell logic. |
| Slot selection | `spell_slot_1`–`spell_slot_5` select a slot directly. Phones get an on-screen button row. No auto-switch, ever (user decision). Selecting an empty slot is ignored and the selection stays (my call). |
| Starting slots | Slots 1–4 hold Fire, Thunder, Land, Sea. Slot 5 is empty. Slot unlocks belong to Sprint 8 (my call, agreed). |
| Mana | Each instance has `max_mana` and `current_mana`. A cast needs `current_mana >= mana_cost` and spends `mana_cost`. Never regenerates. Only an explicit `restore_mana` call refills it (user decision, from `CLAUDE.md`). |
| Depleted spell | Fire input does nothing, with a small "dry" cue so the player knows why (greyed slot, no projectile). The player must select another slot themselves (user decision). |
| Casting | The loadout casts the selected instance in the aim direction while firing, gated by the instance's cast interval and mana. The projectile carries damage, element and speed from the spell. |
| Elements | Fire, Thunder, Land, Sea differ by colour, damage, cast interval and mana numbers, all in `.tres` (my call, agreed). |
| Elemental multipliers | A configurable table in a Resource: strong, weak and neutral multipliers, applied by `DamageSystem` given an attacker element and an optional defender element. Fire > Land > Thunder > Sea > Fire. Enemies have no element yet, so the table is unit-tested but not yet in play (agreed). |
| Debug restore | A debug key refills every slot's mana. It is a dev tool, easy to delete (agreed). |
| HUD | A temporary row of slot widgets showing each spell's element colour, mana bar and selected highlight, doubling as the touch buttons. It reads from the loadout and never mutates it, except that touch taps call the same select action as the keys (my call). |
| Pool sizing | Starting target (my call): a full pool is about 40 casts at the starting cost, so roughly 20 kills at 2 hits per enemy (enemy health 20, spell damage 10). That is enough to play with and small enough that depletion happens in a normal session. Numbers stay in `.tres` and get tuned by playing. |
| No in-game refill | Sprint 2 has no way to regain mana in play except the debug key (my call). `CLAUDE.md` says only explicit effects restore mana, and those arrive with potions and drops in later sprints. |
| Holding fire | Holding fire repeats casts, gated by the cast interval. A dry cue plays once per press, not every frame (my call). |
| Per-run reset | The loadout builds fresh instances at full mana every time the arena loads, so death and restart reset mana (my call). Persistence between runs is a later sprint's problem. |
| Projectile impact | No piercing in Sprint 2: every spell dies on its first hit, as in Sprint 1. But impact is data-driven, not hardcoded (user request, so Sprint 3's pierce spells need no rewrite): `SpellData.max_hits` (enemies one projectile can hit before it is freed) is `1` on all four spells, and the projectile counts hits against it. Each enemy can still be hit only once per projectile, so a piercing shot never double-hits the same target. A test pins both behaviours (max_hits 1 dies on first hit, max_hits 3 survives two hits). Area spells in Sprint 3 may use their own delivery, but they read the same field where it applies. |
| Stress test | The stress test's attacker uses its own spell `.tres` with a huge `max_mana` and the same projectile, so the real casting path is measured without running dry (my call). |
| Controller | Controllers cycle spells with the shoulder buttons through new `spell_prev` / `spell_next` actions, skipping empty slots, so all three input types can change spells as `CLAUDE.md` requires (my call). Keys 1–5 still select directly. |
| Replaces | `AttackComponent`, `AttackData`, `basic_attack.tres` and the stand-in `Projectile` are removed. Their hit and damage plumbing (hitbox, hurtbox, `DamageSystem`) stays. |

## 3. Approaches considered

1. **`SpellInstance` plain object plus a `SpellLoadout` component (chosen).** Definition stays pure data, the instance owns mutable mana and cooldown, the loadout owns slots and selection. Testable without the scene tree, and crafting can build instances directly later.
2. **Each instance as a `Node` child of the player.** Visible in the scene tree, but heavier to test and ties spells to scenes with no Sprint 2 benefit.
3. **Mana stored on the `SpellData` resource.** Least code, but Godot shares resources, so two copies of a spell would share mana. Rejected: it breaks a hard design rule.

## 4. Constraints

- Everything from earlier sprint docs still applies: Godot 4.7.2, typed GDScript, no new autoloads, Input Map actions only (device -1), web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Elemental rules for multiple Base types are undecided, so `SpellData.elements` may hold several entries but Sprint 2 spells use exactly one, and the damage path takes one element.
- The Player holds no spell rules, and UI never mutates gameplay data.

## 5. Design

### SpellData (Resource, exists as a stub)
Gains: `max_mana`, `mana_cost`, `damage`, `cast_interval`, `projectile_speed`, `projectile_lifetime`, `knockback`, `color`. Keeps `id`, `display_name`, `elements`, `area`. `area` stays `MISSILE` for all four, so Sprint 3 can branch on it. Four `.tres` files under `resources/spells/`.

### SpellInstance (`scripts/spells/spell_instance.gd`, `RefCounted`)
Constructed from a `SpellData`. Holds `current_mana`, a cooldown. Exposes `can_cast() -> bool` (mana and cooldown), `cast() -> bool` (spends mana, starts cooldown, returns whether it cast), `tick(delta)`, `restore_mana(amount := -1)` (full refill by default), and a `mana_changed(current, max)` signal. A depleted instance returns false from `cast()` and changes nothing.

### SpellLoadout (`scripts/components/spell_loadout.gd`)
Five slots of `SpellInstance` or null, `selected_index`, `select(index) -> bool` (ignores empty or out-of-range), `selected() -> SpellInstance`, `try_cast(origin, direction) -> bool`, and signals `selection_changed`, `cast_fired`, `cast_failed_dry`. It ticks its instances and spawns the projectile. `restore_all_mana()` serves the debug key.

### Projectile
The stand-in projectile scene is rewritten as a spell projectile: it takes damage, element, speed, lifetime, knockback and colour from the spell, and is tinted by it. Its `HitboxComponent` sends damage through `DamageSystem.calculate(base_damage, attacker_element, defender_element)`.

### DamageSystem and the elemental table
`DamageSystem.calculate` gains optional attacker and defender elements and reads multipliers from an `ElementTable` Resource (`resources/spells/element_table.tres`: strong, weak, neutral). With no defender element it returns the base amount, so every existing Sprint 1 call and test keeps working.

### Input
Existing `spell_slot_1`–`spell_slot_5` select. New `spell_prev` / `spell_next` on the controller shoulder buttons cycle through non-empty slots. A new `debug_restore_mana` action (a key, for example F5) refills mana. `cast` and the aim actions are unchanged.

### HUD
A `SpellBar` of five slot widgets in the existing `Hud`: element colour, mana bar, selected highlight, greyed when empty-of-mana. Each widget is tappable on touch and calls `select`. It binds to the loadout and reads signals, like the health bar.

### Player
`Player` swaps `AttackComponent` for `SpellLoadout`, reads the number-key actions, and calls `try_cast` while firing. No spell logic moves into it.

### Feedback
Cast: the projectile is tinted by element. Impact: the existing hit flash and knockback. Dry cast: the selected slot widget flashes. Real effects and sound are Sprint 13's job.

## 6. Testing

- GUT unit tests: `SpellInstance` (casts spend mana, depleted never casts and spends nothing, cooldown gates, `restore_mana`), two instances from one definition do not share mana, `SpellLoadout` (select, empty slot ignored, no auto-switch on depletion, casts only the selected spell), `DamageSystem` with the element table (strong, weak, neutral, no defender), `SpellData` `.tres` files load with valid values, `SpellBar` reflects mana and selection.
- Delete the Sprint 1 attack tests with the code they cover.
- A headless smoke run plus a godot MCP run with no warnings, then the Sprint 1 stress test, to confirm no frame-time regression.
- Manual checklist for the user: cast each element, watch mana fall, deplete a spell and confirm nothing fires or switches, pick another slot, refill with the debug key, try the slot buttons with touch emulation.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Starting numbers for each spell's damage, mana, cost and interval (keep them in `.tres`; tune by playing).
- The four element colours.
- The debug key.
- Slot widget size and placement, and the dry-cast cue.
- Whether `ElementTable` multipliers start at 1.5 and 0.5 (my suggestion).

## 8. Risks

| Risk | Mitigation |
|---|---|
| Mana state leaks between spells | Mana lives on the instance only, and a test builds two instances from one definition. |
| Sprint 3 Areas force a rewrite of casting | `area` stays on `SpellData`, and casting sits behind `SpellLoadout.try_cast`, the single seam Areas will replace. |
| Removing the stand-in attack breaks Sprint 1 tests and the stress test | Update the stress test's attacker to use a spell, and keep the plumbing tests. |
| Accidental mana waste on touch | Slot buttons are separate from the aim stick, and there is no auto-switch. |
| Touch tap on a slot also counts as a cast | The slot widgets consume their own touch, and a test or MCP check covers it. |
