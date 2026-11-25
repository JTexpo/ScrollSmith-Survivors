# Sprint 5 Design: Spell Scroll Collection

**Status:** Built. Approved by the user after a fresh builder check, then implemented on branch `sprint-5-scroll-collection`.

Scope comes from `sprint-development.md` (Sprint 5). Architecture follows `technical-design.md` (sections 6 and 7), `CLAUDE.md`, and `sprint-0/1/2/3/4-design.md`. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The core loop in the README is: fight, find scrolls, combine them at a Lectern. Sprint 5 builds the first half of "find scrolls". Enemies drop scrolls, the player picks them up by walking over them, and the scrolls are stored for the run and can be looked at. Nothing is crafted yet (Sprint 6), so this sprint is about the supply: scrolls as data, themed drops that give a reason to fight particular enemies, and a store the crafting system can later read and consume.

**Goals**
- Scrolls as data: 15 scrolls (4 Base, 5 Area, 6 Buff) with a category, rarity and the data crafting will need, all in `.tres` files. Adding a scroll is a new file plus a drop-table entry, with no code change.
- Themed drops: each enemy has its own drop table. An elemental enemy heavily favours its own element's Base scroll, but it is never guaranteed.
- Automatic pickup by walking over a scroll, cheap even with many scrolls on the ground.
- A per-run scroll inventory that stacks identical scrolls and is independent of any UI, so the Lectern can use it in Sprint 6.
- Feedback and display: pickups you can tell apart by category, a short "+ Fire Scroll" message on collection, and a panel you toggle to see everything collected.

**Non-goals (later sprints)**
- Crafting, the Lectern, consuming scrolls in play, buff effects, and Additional Base rules.
- Scroll art and effects (Sprint 13), XP and Gold drops, scrolls found in the world such as chests, inventory limits, and keeping scrolls between runs.

**Anti-goals** (a failure even if it technically works)
- Drop or inventory logic inside `Player` or `Enemy`. The player delegates, and enemies only carry data.
- A hardcoded scroll list in a script, or per-scroll code.
- A dead player collecting scrolls, or scrolls that can't be collected on a phone.
- Per-frame work for pickups that nothing is near.

## 2. Decisions

| Area | Decision |
|---|---|
| Scroll data | One `ScrollData` class (user choice) with `id`, `display_name`, `description`, `category`, `rarity` (COMMON, UNCOMMON, RARE), `color` (placeholder look until art), and optional category-specific fields: `element` (Base), `area_data` (Area, the Sprint 3 `AreaData`), `buff_id` (Buff, resolved in Sprint 7). The inventory and drop tables only ever hold `ScrollData`. |
| Catalog | 15 scrolls in `resources/scrolls/`: Base Fire, Thunder, Land, Sea. Area Line, Cone, Area, Missile, Wave. Buff Increased Max Mana, Increased Damage, Double Vulnerability Damage, Ignore Resistance, Duplicate Area, Additional Base. Wave is included because the user added it (the tech design lists only four Areas). Buff scrolls only exist as collectibles this sprint. |
| Rarity | Base, Line, Cone and Missile are common. Area and Wave are uncommon. Increased Max Mana and Increased Damage are uncommon. Double Vulnerability, Ignore Resistance, Duplicate Area and Additional Base are rare (my call). Rarity is shown in the panel. Drop weights are authored per table, so rarity does not change them by itself. |
| Drop tables | `DropTable` (`drop_chance`, and a list of entries each holding a scroll and a weight). `EnemyData` gains `drop_table`. A roll first checks `drop_chance`, then picks one entry by weight. Empty slots and zero weights are never picked (the Sprint 4 lesson). |
| Themed weights | User decision: the enemy's own Base scroll is heavily preferred but never guaranteed. Starting rule (my call): in an elemental enemy's table its own Base scroll has weight 12 and each other Base scroll 1, so among Base drops it is 80%, and it is about 40% of all drops. Area scrolls weigh 2 (Line, Cone, Missile) or 1 (Area, Wave). Buff scrolls weigh 1 (Max Mana, Damage), 0.5 (Double Vulnerability, Ignore Resistance, Duplicate Area) or 0.25 (Additional Base). The plain enemy's table weighs every Base scroll 3. `drop_chance` is 0.06 for every enemy. All tuned by playing. |
| Who rolls the drop | Enemies carry data only. `EnemySpawner` re-emits `enemy_died`, `Main` connects it to a `ScrollDropper` node, and the dropper rolls the enemy's table and places a pickup where the enemy died. The stress test scene has no dropper, so it is unaffected. |
| Pickup | `ScrollPickup` is a passive `Area2D` on a new collision layer `pickup` (bit 32, added to `PhysicsLayers` and `project.godot`). It shows the scroll's colour, in a different shape per category (round for Base, square for Area, diamond for Buff, my call) so categories are distinguishable without colour. A gentle bob. It stays until collected (no despawn). |
| Collecting | The player carries one `PickupCollector` (an `Area2D`, mask = pickup, radius about 14 px) that is the only active detector. Collection is automatic on overlap, adds the scroll to the inventory, frees the pickup, and a pickup can only be collected once. A dead player collects nothing. |
| Pickup cap | At most 100 pickups on the ground. When a new drop would exceed it, the oldest pickup is removed so a fresh drop always appears (my call, because scrolls are scarce and the player should never see a kill that should have dropped nothing). |
| Inventory | `ScrollInventory` is a component `Node` on the Player, like `SpellLoadout`. It stores counts keyed by scroll id, and supports `add`, `remove` (all-or-nothing), `count`, `has`, `by_category`, `total_count`, and a `changed` signal. Identical scrolls stack. No limit this sprint. It lives for the run only, since a death or restart reloads the scene. |
| Feedback | A short toast near the top of the screen, "+ Fire Scroll", in the scroll's colour, replaced by the latest pickup and faded out after about 1.2 s (TEMPORARY). The inventory button also reflects the total count. |
| Display | A toggleable panel (TEMPORARY): scrolls grouped under Base, Area and Buff headings, each row showing a colour swatch, name, rarity and the count. New action `toggle_inventory` (key `I`, controller button Y). A small button in the HUD toggles it on touch, handled like the spell slot widgets (`emulate_mouse_from_touch` stays off). The panel does not pause the game (no pause system yet) and hides when the player dies. |
| Debug | F10 (`debug_give_scrolls`, handled in `Main`, marked DEBUG) adds 3 of every scroll, so Sprint 6 and the panel can be tried without grinding. Delete it later. |
| Docs | The README, `technical-design.md` (Area scroll list and the scroll and inventory notes), `sprint-development.md` and `CLAUDE.md` are updated, including the Wave scroll. |

## 3. Approaches considered

**Scroll data shape.**
1. **One class with optional category fields (chosen by the user).** The inventory and drop tables hold one type, and later sprints can add fields.
2. One class per category. A tidier inspector, but more classes for the same job.

**Inventory display.**
1. **A toggleable panel (chosen by the user).** It doesn't use the small 480x270 screen when closed.
2. An always-visible strip of counters. More visible, but it crowds the screen, and the Lectern will be the real place to see scrolls.

**Drops.** One sensible way: a drop system fed by the spawner's re-emitted death signal, with all the numbers in per-enemy tables, so adding or retuning drops is a data change and enemies stay simple.

## 4. Constraints

- All earlier sprint constraints apply: Godot 4.7.2, typed GDScript, no new autoloads, Input Map actions only (device -1 on every event), web-safe settings, GUT tests, all commands via the venv.
- Don't build future-sprint features. The sprint must leave a playable build.
- Collision layers 1-5 are unchanged. One new layer, `pickup`, is added.
- The Player holds no scroll or drop logic beyond owning the components. UI reads from systems and never mutates gameplay data (the debug key and toggle are the only exceptions, and they go through the inventory's own methods).
- Frame time must stay above the 60 fps target at 300 enemies.

## 5. Design

### Data
`ScrollData` (extends the existing stub), `DropEntry` (scroll, weight) and `DropTable` (`drop_chance`, `entries`, `roll(rng) -> ScrollData` returning null for no drop) as resources. 15 scroll files under `resources/scrolls/` (`base/`, `area/`, `buff/`) and one drop table per enemy under `resources/drops/`.

### Inventory
`ScrollInventory` as above. Rows are kept in the order scrolls were first collected, so the panel is stable.

### Drops and pickups
`EnemySpawner.enemy_died(enemy)` relay. `ScrollDropper` with `on_enemy_died(enemy: Enemy)`, a pickup scene, an `rng`, a cap, and a root to add pickups to. `ScrollPickup` with `setup(scroll)` and `collect() -> ScrollData` (returns null if already collected). `PickupCollector` on the Player, `collected(scroll)` signal.

### UI
`ScrollToast` (HUD label) and `InventoryPanel` (HUD) plus a touch-capable `InventoryButton`. All TEMPORARY and reading from the inventory.

## 6. Testing

- GUT unit tests: `ScrollData` files load and match the catalog (category, rarity, element or `area_data` or `buff_id` by category). `DropTable.roll` respects `drop_chance` (0 never drops, 1 always drops a scroll), weights (heavier is picked more over many draws), skips empty and zero-weight entries, and returns null for an empty table. Each enemy's table makes its own Base scroll about 80% of Base drops over many draws, never 100%. `ScrollInventory`: add stacks, remove is all-or-nothing, count and has, by_category order and grouping, `changed` emits. `ScrollDropper`: a death with a drop places one pickup at the enemy's position with the rolled scroll, a death with no drop places none, the cap removes the oldest, and an enemy with no table drops nothing. `ScrollPickup`: collected once only, passive (not monitoring), shape differs by category. `PickupCollector`: walking over a pickup adds it and frees it, several pickups in one frame are all collected once, and a dead player collects nothing. `InventoryPanel` lists by category with counts and updates on `changed`. `ScrollToast` shows and fades. Input map test for `toggle_inventory` and `debug_give_scrolls` (device -1). `Main` wiring: killing an enemy can produce a pickup, and F10 fills the inventory.
- Update tests touching `EnemyData` or the spawner as needed.
- Headless smoke run plus a godot MCP run with no warnings, then the stress test to confirm no regression, and a check with 100 pickups on the ground.
- Manual checklist: kill enemies and find scrolls dropping, check Fire enemies mostly drop Fire scrolls and others sometimes, walk over a scroll to collect it with a toast, open the panel with `I` (and the button on touch emulation) and see counts by category, die and confirm the panel hides, restart and confirm the inventory is empty, press F10 to fill it.

## 7. Open items for the builder

Record each call in `development-log.md`:
- Scroll colours and the pickup shapes and size, the bob, the toast and panel layout.
- Where the dropper, toast, panel and button sit in the scene tree.
- The exact collector radius and the cap's implementation.
- Starting drop numbers, if play suggests changes.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Drop and inventory logic leaks into `Player` or `Enemy` | The dropper, inventory and collector are separate components, and tests check enemies only carry data. |
| Many pickups hurt frame time | Pickups are passive, one collector detects them, and the cap is 100. The stress check includes 100 pickups. |
| The panel is awkward on a phone | A touch button and tap handling like the spell bar, with a manual check. |
| The panel stays open while enemies attack | It does not pause the game. It is small and TEMPORARY, and the Lectern in Sprint 6 gets the real crafting UI. |
| Drop numbers feel too generous or too stingy | Every number is data in `.tres`, so tuning needs no code. |
| An empty or malformed drop table breaks a kill | `roll` returns null for empty, zero-weight and null entries, and a test pins it. |
