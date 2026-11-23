# Sprint 14b Design: Balance

**Status:** Approved, in progress.

Sprint 14 is three parts: **14a** the world pass (done), **14b** balance (this doc), **14c** optimization. Scope comes from the user's play-test notes after Sprint 13, `CLAUDE.md` and the numbers in the data files. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Play-testing showed three things (the user's words, shortened): **the Missile "is good, however useless compared to other spells"** (an area spell earned the most XP), **enemy pacing "felt perfect"** (even at level 20 resources were needed to reach the end boss), but **"I could always throw money at my problem"**, so potions are too easy to stock. Level 20 in about four games stays as it is ("I like this pacing", other testers learn more slowly).

14b gives the Missile a job, makes potions a decision during a run, and measures every Base and Area combination so any other outlier is found by numbers. It does not touch enemy, spawn, XP or boss numbers.

**Goals (user decisions)**
- **The Missile explodes** where it ends, a small burst of area damage, with a slower cast. It stays a data change on the Area, not a new Area type.
- **Potions are run-only.** They are not sold between runs (the shop screen's Potions row goes), the in-run merchant is the only source, unused potions are **lost when the run ends**, and a player holds **at most 3 of each type**.
- **XP and enemy pacing stay.**

**My calls**
- **Burst numbers (starting values, all data):** radius about 18 px, damage share 50% of the spell's damage, and the Missile's cast interval 0.35 s to about 0.6 s. The burst happens at the Missile's first enemy hit or at its maximum range, whichever comes first, and damages every enemy in the radius (including the one it hit), using the same elemental rules.
- **Run-only potions live in a new in-memory `RunPotions`** (like the run's starting buffs), never in the saved profile. The potion belt and merchant screen take it where they took the profile's potions.
- **Old saves:** a save that holds potions loads, and its potions are cashed in for Gold at their list price once, so nobody loses what they paid for. After that the save no longer writes potions.
- **A spell audit tool** (`scripts/dev/spell_audit.gd`, run like the stress scene) prints damage per full mana pool for every Base, Area and buff combination at one target and at eight, and flags anything beyond 3 times the median. I only change a flagged combination if it is a clear outlier, and show the table first.

**Non-goals**
- Enemy health, damage, speed, spawn rate, XP curve, Gold rewards and boss numbers (the user is happy with them; revisit only on feedback).
- A new Area type, new spells, or changes to elemental multipliers unless the audit shows a clear outlier and the user agrees.
- Optimization (14c).

**Anti-goals** (a failure even if it technically works)
- The Missile becoming the best spell instead of a useful one, or its burst hitting through walls or the player.
- Any Area or damage code branching on "is this a Missile": the burst is data (`AreaData`), read by one shared code path.
- A potion that can still be stockpiled across runs, bought at the wrong place, or lost without the player knowing why (the merchant screen says potions last one run).
- Changing the starting spells' identity by accident: a crafted Fire plus Missile at Normal range must still equal `fire_missile.tres` in every number except the pool (a test pins this), so both change together.
- A save that fails to load, or a player who loses Gold's worth of potions with no refund.

## 2. Approaches

- **Potions: A.** Keep them in the saved profile and clear them at run start. Smallest change but mixes run state into the permanent save. **B (chosen by the user).** A new `RunPotions`, never saved, same shape as the profile's potion API with a cap of 3. A few more edits (belt, merchant screen, `ShopSystem.buy_potion`, tests) for a clean run-versus-permanent split.
- **Missile: A (chosen by the user).** Burst radius and damage share are fields on `AreaData` (zero for every other Area) and the Missile spawns a second hitbox where it ends. Duplicate Area, damage scaling and elemental rules need no change. **B.** A new Area type (rejected: duplicates the Missile, and crafting assumes five Areas). **C.** Stats only (rejected: gives the Missile no job in a crowd).

## 3. Decisions

| Area | Decision |
|---|---|
| Burst data | `AreaData.burst_radius` (px, 0 means none) and `burst_damage_share` (0 to 1), set on `missile_area.tres` (18 and 0.5) and zero elsewhere. `SpellData` reads them through its `area_data`. |
| Burst behaviour | `MissileArea` ends on its first hit, on max range, or on an obstacle, and then (if `burst_radius > 0`) spawns one burst effect at that point: a passive hitbox of that radius that hits every enemy once with `damage * burst_damage_share`, through `AreaEffect._configure_hitbox` so the damage scale, element, attack profile and impact announcement are the shared ones. A short ring of element-coloured effect sprites marks it (existing `SpellSkin`/`EffectSprite` pieces, no new art). Duplicate Area bursts per copy. |
| Missile numbers | `missile.tres` area stats `cast_interval` 0.35 to 0.6 (about); `fire_missile.tres` changes the same way so the crafted-equals-starting test holds. Damage per hit stays 10. |
| Run potions | `RunPotions` (RefCounted): `count`, `add`, `use`, `changed`, cap `MAX_POTIONS = 3` per type. Created at run start by `Main`, bound to the belt and merchant screen. `PlayerProfile` loses `potions` (loader cashes old ones in for Gold once; `to_dict` writes none). |
| Buying | `ShopSystem.buy_potion` takes a `RunPotions` and refuses at 3 of a type (all-or-nothing, as now). The merchant's stock stays 2 of each, refilled after the first sale. The merchant screen shows "own n/3" and a line that potions last one run. |
| Shop screen | The Potions row is removed. The equipment rules and layout are otherwise unchanged. |
| Debug | `F8` (`debug_give_potions`) gives 3 of each into `RunPotions` (never saved). |
| Saving | A drink no longer saves. A merchant sale still saves at once (it spends permanent Gold). |
| Spell audit | `SpellAudit` (pure) computes damage per pool at 1 and 8 targets from `SpellBuilder` and `CastMath`; `scripts/dev/spell_audit.gd` prints the table and the flagged outliers. Tests pin the maths on known spells. |

## 4. What is left to the builder
- The burst's exact look (radius ring colours, number of sprites) from existing effect pieces, and its timing (instant on the end of flight).
- Which combinations the audit flags and what to do about each (shown to the user first).
- The wording of the merchant screen's "lasts one run" line and the Gold cash-in message.
- Whether the save version number changes when `potions` leaves the format.

## 5. Verification plan
- **Burst tests:** a Missile with a burst bursts once at a hit, at max range and at an obstacle; hits several enemies in radius once each; applies the damage share, the damage scale and the element; Duplicate Area bursts per copy; a spell with `burst_radius` 0 (every other Area) makes no burst; `fire_missile.tres` still equals Fire plus Missile at Normal range in every number except the pool.
- **Potion tests:** `RunPotions` caps at 3, uses and refuses correctly; the belt and merchant use it; `buy_potion` refuses at the cap and spends no Gold; the shop screen has no Potions row; old saves cash in their potions once and never write them again; a drink does not save; `F8` fills three of each; nothing from a run carries into the next (a fresh `Main` has empty `RunPotions`).
- **Audit tests:** the maths on known spells; the table includes every Base, Area and buff.
- **Real window:** a screenshot of a burst on a crowd and at max range, the merchant screen and the shop screen, and a stress run (`--area=missile`) to check the burst's cost. Whether the Missile now feels right is the user's call.
- `godot --headless --import` after adding a `class_name`, then the full suite and a smoke run.

## 6. Revisions during the build

- **User feedback after trying the Missile burst (mid-build):** the burst was "massive" and "almost steals the Area's role", so its radius is halved to **18 px** (was 36).
- **The Cone was impractical at Short range** (enemies are fast), so its Normal range grows from 56 to **94 px** (Short becomes about 56, what Normal was; Long 141, Very long 188), and it was "the strongest spell", so its baseline cast interval grows from 0.55 s to **0.8 s**. The starting Sea Cone follows (0.4675 s to 0.68 s) because it matches the builder. Both are starting values for the user to tune. This goes beyond the original scope (the audit was to report outliers, not change them): the user asked for these directly.
