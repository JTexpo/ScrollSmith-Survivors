# Sprint 10 Design: Potions and Consumables

**Status:** Proposed (awaiting approval).

Scope comes from `sprint-development.md` (Sprint 10), the README (section 6.2, Potions) and `technical-design.md` (section 12). Architecture follows `CLAUDE.md` and `sprint-0` to `sprint-9-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

Sprints 8 and 9 made the wizard stronger between runs. Potions are the opposite kind of power: a consumable you spend inside a run to survive a bad moment or squeeze out a big one. You buy them with Gold in the death-screen shop, carry what you own into every run, and drink them from a potion bar when it counts. Each is a small resource-management choice, "do I save this for later?", and that is the point.

**Goals**
- Six potions work: Health, Mana, Speed, Damage, Invulnerability and Luck.
- Potions are data (`PotionData` in a `PotionCatalog`): a new potion of an existing kind is a new `.tres`.
- The player buys potions in the shop, and the stock persists in the save. Using a potion consumes one.
- A potion bar in the HUD shows each potion type with its count, its cooldown and its remaining effect time, and works with keyboard, mouse, controller and touch.
- Timed effects expire correctly, cooldowns and usage restrictions work, and a refused potion is never consumed.
- Level, equipment and potion bonuses feed the player's stats through one function, so none can be dropped or applied twice.

**Non-goals (later sprints)**
- More potion kinds, potions dropped by enemies, selling potions, potion rarity, effects that stack across different potions, sound and final art, bosses (Sprint 11).

**Anti-goals** (a failure even if it technically works)
- Code that branches on a potion id. Behaviour comes from the potion's kind and numbers.
- A potion that is consumed and does nothing (refused at full health, still running, on cooldown). A potion whose effect outlives the run, or whose timer keeps running while the game is paused.
- A bonus from a potion that is lost when a level-up or run start recomputes the stats, or counted twice.
- A stock change that is not saved, so a crash or quit refunds a potion that was drunk.
- Tests that touch the real save.

## 2. Decisions

| Area | Decision |
|---|---|
| Carrying (user, "A") | **Carry everything you own, with a potion bar.** The shop sells potions one at a time and the stock persists in the save. In a run the bar shows each potion type with its count, and using one is a key press or a tap. Unused potions stay for the next run, and dying does not lose them. |
| Potion data | `PotionData` (Resource): id, display name, description, price, `kind` (HEAL, RESTORE_MANA, TIMED_BONUS, INVULNERABILITY), `magnitude`, `duration`, `cooldown`, `modifiers` (the timed stat bonuses, as `EquipmentModifier`s), a placeholder colour. `PotionCatalog` (Resource) lists them in bar order and has `find(id)`. Behaviour comes from `kind`, never from the id. |
| The six potions (my call, tune by playing) | **Health:** heals 40% of maximum health, price 40, cooldown 10 s. **Mana:** restores 50% of every spell's pool, price 60, cooldown 15 s. **Speed:** +40% movement speed for 15 s, price 30, cooldown 30 s. **Damage:** +50% spell damage for 15 s, price 50, cooldown 30 s. **Invulnerability:** no damage for 5 s, price 100, cooldown 60 s. **Luck:** +100% luck for 60 s, price 40, cooldown 90 s. Mana restores only part of a pool on purpose: mana is scarce by design, and a potion is the one thing that gives it back. |
| Using a potion | `PotionSystem` (static rules, like `CraftingSystem` and `ShopSystem`) validates and applies it and returns why it was refused. A potion is consumed only when its effect really happens. Refused (and kept): none left, the potion type is on cooldown, the shared cooldown is running, a timed potion's own effect is still active, Health at full health, Mana with every spell already full, or the player is dead. |
| Cooldowns (my call) | Each potion type has its own cooldown, starting when it is drunk. A short shared cooldown of 1 s also stops mashing from burning a stack. A timed potion can't be drunk again while its own effect is running (its cooldown is longer than its duration anyway). Cooldowns and effect timers use the game's process time, so they freeze while the game is paused (crafting, the pick screen). |
| Timed effects | `ActiveEffects` (a Player component) keeps the running effects with their time left and builds one temporary `StatBonuses` from them. It emits `changed` when an effect starts or ends. Invulnerability is a timed window on the player's hurtbox (the hurtbox gains `grant_invulnerability(seconds)`). Effects end when the run ends because the Player is rebuilt. |
| One function for stats | The Player holds three bonus layers (level, equipment, temporary) and `refresh_bonuses(heal_difference)` adds them and pushes speed, health and the loadout's bonuses. `RunStart`, `RunProgress` and `ActiveEffects` set their own layer and call it, replacing the places that combine level and equipment by hand today. The Player emits `bonuses_changed(total)` for the things that need the total (the scroll dropper's luck). |
| Luck (my call) | A new stat, LUCK, in `StatBonuses`. `DropTable.roll(rng, luck := 0.0)` multiplies an entry's weight by its scroll's rarity: Common x1, Uncommon x(1 + luck), Rare x(1 + 2 x luck). The drop chance itself is unchanged, only which scroll drops. With luck 0 the roll is exactly as before. `ScrollDropper` reads the player's current luck. |
| Potion stock and the save | `PlayerProfile.potions` (potion id to count). Missing means empty, so old saves load. Counts are whole numbers from 0 to 99 (a hold limit, my call, so a stack can't be hoarded without end). A potion id that is not in the catalog is skipped when used. A wrongly typed field makes the file unusable, as for the other fields. Drinking saves at once. |
| Shop | The shop screen gets a Potions row (six buttons, "Health 40g (x2)"). Pressing one buys one potion if the player can afford it and holds fewer than 99. Buying does not use it. Every buy saves at once, and the same input guard as the equipment items applies. |
| Potion bar (TEMPORARY look) | Six fixed slots in the HUD (fixed so keys and taps stay where the player expects). Each shows the potion's colour, its count (dimmed at 0), a cooldown overlay and, while a timed effect runs, a shrinking timer bar. A refusal shows its reason in the level toast's message line. Slots handle their own touches, as the spell slots do. |
| Inputs (my call) | Keyboard: Z, X, C, V, B, N use the six potions directly (new actions `potion_1` to `potion_6`). Controller: D-pad left and right select a potion and D-pad up uses the selected one (`potion_prev`, `potion_next`, `potion_use`; the shoulder buttons stay on spells). Touch and mouse: tap or click a slot. All go through the Input Map. |
| Debug | F9 (refill mana) stays. A new DEBUG key, F8, gives 3 of every potion (like F10 for scrolls), to delete when potions are found another way. |

## 3. Approaches considered

1. **Potions as data on the existing paths (chosen).** `PotionData` plus `PotionSystem`, timed bonuses on `StatBonuses`, and the Player's three bonus layers. Reuses the modifier path and removes the double combination of level and equipment before a third source makes it worse.
2. **One script per potion.** Quick, but it hardcodes each potion and breaks the "reusable effect logic" rule in the technical design.
3. **A general effect system with an event bus and stacking rules.** Flexible, but far more than six potions need.

For carrying, a loadout chosen before each run (limited potion slots) and a fixed number per run were considered and dropped: carrying everything (option A) is the simplest and needs no extra screen.

## 4. Risks for the builder

- **Stat layers.** The refactor touches `Player.apply_stat_bonuses`, `RunStart`, `RunProgress` and their tests. After it, nothing but `refresh_bonuses` may push bonuses to the player and loadout, and a level-up, run start or potion must give the same result in any order.
- **Invulnerability.** The hurtbox already has a per-hit invulnerability window (`invulnerability_time`). The potion's window is separate and must not be shortened or cleared by it, and a hit during it must do nothing and not start the normal window.
- **Pause.** Effect timers and cooldowns must stop while the tree is paused, and drinking must be impossible while paused or dead.
- **Touch and input.** Potion slots sit over the world, so they must handle their own taps (mouse emulation is off) and must not also cast a spell. Check on a real window as in Sprint 9.
- **Mana potion.** Restoring a percentage must raise current mana by a share of the bonus-aware pool and never above it (`SpellInstance.max_mana()`).
- **Luck.** Weights must never go negative or all zero, and the drop roll must stay exactly as before at luck 0.

## 5. Docs this sprint updates

`sprint-development.md` (Sprint 10 boxes and a Built note), `README.md` (the potion table and rules), `technical-design.md` (the save fields), `CLAUDE.md` (a Potions section, the stat layers, the new inputs, F8), `development-log.md`, and the memory file.
