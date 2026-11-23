# Technical Design Document

## 1. Overview

This document defines the technical architecture and development conventions for the ScrollSmith Survivors project.

The purpose of this document is to establish a consistent approach to implementing the game's systems, ensuring that features remain modular, reusable, and easy to expand.

### Technology Stack

| Component | Technology |
|---|---|
| Game Engine | Godot 4.x |
| Programming Language | GDScript |
| Rendering | 2D |
| Perspective | Top-down |
| Art Style | Cartoon / Comedy Pixel Art |
| Version Control | Git |
| AI Development Assistant | Claude Code |

### Technical Goals

- Build modular and reusable gameplay systems.
- Separate game data from gameplay logic.
- Avoid hardcoding individual spell combinations.
- Make gameplay values configurable.
- Keep systems independent wherever practical.
- Design systems to support future expansion.
- Maintain readable and manageable code.

---

# 2. Project Architecture

The project should use Godot's scene-based architecture alongside reusable scripts and custom Resources.

### Architecture Principles

**Scenes**

Scenes represent physical game objects and user interfaces.

Examples:
- Player
- Enemy
- Projectile
- Scroll Pickup
- Arcane Lectern
- HUD
- Crafting Interface

**Scripts**

Scripts contain the logic that controls scenes and game systems.

Examples:
- Player movement
- Enemy behavior
- Spell casting
- Damage calculations
- Inventory management

**Resources**

Resources contain reusable data definitions.

Examples:
- Spell definitions
- Scroll definitions
- Enemy statistics
- Equipment definitions
- Potion definitions

**Autoloads**

Autoloads are reserved for systems that genuinely need global access or persistent state.

Examples:
- Game Manager
- Run Manager
- Save Manager

Avoid creating unnecessary global managers.

---

# 3. Proposed Directory Structure

```text
wizard-survivor/
│
├── README.md
├── sprint-development.md
├── technical-design.md
├── CLAUDE.md
├── development-log.md
│
├── project.godot
│
├── assets/
│   ├── sprites/
│   ├── animations/
│   ├── audio/
│   ├── fonts/
│   └── ui/
│
├── scenes/
│   ├── main/
│   │   └── main.tscn
│   │
│   ├── player/
│   │   └── player.tscn
│   │
│   ├── enemies/
│   │   ├── base_enemy.tscn
│   │   └── enemy_spawner.tscn
│   │
│   ├── spells/
│   │   ├── projectiles/
│   │   └── effects/
│   │
│   ├── scrolls/
│   │   └── scroll_pickup.tscn
│   │
│   ├── interactables/
│   │   └── lectern.tscn
│   │
│   ├── world/
│   │   ├── game_map.tscn
│   │   └── test_arena.tscn
│   │
│   └── ui/
│       ├── hud.tscn
│       └── crafting_menu.tscn
│
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── run_manager.gd
│   │   └── save_manager.gd
│   │
│   ├── systems/
│   │   ├── spell_system.gd
│   │   ├── crafting_system.gd
│   │   ├── inventory_system.gd
│   │   ├── damage_system.gd
│   │   └── progression_system.gd
│   │
│   ├── world/
│   │   ├── game_map.gd
│   │   ├── map_decor.gd
│   │   ├── obstacle_grid.gd
│   │   ├── flow_field.gd
│   │   ├── obstacle_map.gd
│   │   ├── obstacle_layer.gd
│   │   └── map_debug_overlay.gd
│   │
│   └── utilities/
│
├── resources/
│   ├── spells/
│   ├── scrolls/
│   ├── enemies/
│   ├── maps/
│   │   ├── map_data.gd
│   │   ├── map_placement.gd
│   │   ├── map_maze.gd
│   │   ├── maze_entrance.gd
│   │   ├── map_zone.gd
│   ├── map_maze.gd
│   ├── maze_entrance.gd
│   ├── map_zone.gd
│   │   ├── map_obstacle.gd
│   │   └── first_map.tres
│   ├── equipment/
│   └── potions/
│
└── tests/
    ├── test_spells.gd
    ├── test_crafting.gd
    └── test_elemental_damage.gd
```

This structure is a starting point, not a requirement to create every directory immediately.

Directories should be introduced as their respective systems are developed.

---

# 4. Core Gameplay Architecture

## 4.1 Player

The Player is responsible for:

- Movement.
- Health.
- Taking damage.
- Death.
- Equipped spells.
- Equipment bonuses.
- Interacting with world objects.

The Player should not directly implement spell behavior, enemy behavior, or crafting logic.

These responsibilities should be delegated to their respective systems.

### Player Components

Potential components include:

- Health Component
- Movement Component
- Spell Loadout
- Equipment Loadout
- Interaction Component

Components should be separate where doing so meaningfully improves reuse and maintainability.

## 4.2 Enemy

Enemies should share a common base architecture.

The base enemy should handle:

- Health.
- Damage reception.
- Movement.
- Player detection.
- Death.
- XP drops.
- Gold drops.
- Scroll drops.
- Elemental affinity.

Individual enemy types should extend or configure this functionality rather than duplicating it.

### Enemy Configuration

Enemy properties should be configurable through Resources.

Example:

```gdscript
class_name EnemyData
extends Resource

@export var enemy_name: String
@export var max_health: float = 100.0
@export var movement_speed: float = 50.0
@export var contact_damage: float = 10.0
@export var elemental_affinity: String = "fire"
@export var xp_reward: int = 5
@export var gold_reward: int = 1
```

This allows different enemies to share the same behavior while using different statistics.

Since Sprint 11 an enemy is composed from two resources instead of being written out by hand: an `EnemyArchetype` (the role: every stat, size, behaviour kind and numbers, unlock time, cluster size, drop scale) and an `EnemyElement` (affinity, colour, themed drops). An `EnemyComposer` builds one cached `EnemyData` per pair, so any element can combine with any role and an element never changes a stat. Difficulty scales and the elite modifier are applied to the spawned `Enemy` instance, never to the shared data.

---

# 5. Spell System Architecture

The spell system is the most important system in the game.

It must support dynamically constructed spells using different combinations of Base, Area, and Buff components.

Individual spells should never need their own hardcoded implementation simply because their combinations differ.

## 5.1 Spell Components

Every spell consists of:

- Base: Determines elemental damage.
- Area: Determines targeting and attack behavior.
- Buffs: Provides additional modifiers.

The system should be able to combine these components at runtime.

## 5.2 Spell Definition

A Spell Definition represents the configuration of a spell.

It should contain:

- Spell name.
- Base types.
- Area type.
- Buffs.
- Base damage.
- Maximum mana.
- Mana consumption.
- Casting interval.
- Additional configurable properties.

Spell Definitions should be implemented using custom Godot Resources.

Example:

```gdscript
class_name SpellData
extends Resource

@export var spell_name: String

@export var base_types: Array[String]

@export var area_type: String

@export var buffs: Array[String]

@export var base_damage: float = 10.0

@export var max_mana: float = 100.0

@export var mana_cost: float = 10.0

@export var cast_interval: float = 0.5
```

This represents the spell's configuration rather than its current runtime state.

## 5.3 Spell Instance

A Spell Instance represents an equipped spell during gameplay.

Unlike a Spell Definition, it maintains mutable runtime properties.

It should contain:

- Reference to its Spell Definition.
- Current mana.
- Calculated damage.
- Calculated maximum mana.
- Calculated mana consumption.
- Current casting state.

Each equipped spell must have its own independent mana pool.

Two instances of the same Spell Definition should not share mana.

## 5.4 Spell Casting

The spell system should be responsible for:

1. Receiving a casting request.
2. Checking whether the spell has sufficient mana.
3. Validating the casting interval.
4. Calculating the spell's effective properties.
5. Executing the appropriate Area behavior.
6. Applying damage.
7. Consuming mana.

Spells must not cast if their mana is insufficient.

### Mana Rules

- Spells have individual mana pools.
- Mana is consumed when a spell is successfully cast.
- Mana does not naturally regenerate.
- Depleted spells cannot be cast.
- Mana can only be restored through explicitly implemented mechanics.
- Mana restoration should never happen automatically unless a specific effect allows it.

---

# 6. Scroll System Architecture

Scrolls are collectible items used to construct and modify spells.

Scrolls should be implemented as reusable Resources.

## 6.1 Scroll Categories

Three categories exist:

### Base Scrolls

- Fire
- Thunder
- Land
- Sea

### Area Scrolls

- Line
- Cone
- Area
- Missile
- Wave

### Buff Scrolls

- Increased Max Mana
- Increased Damage
- Double Vulnerability Damage
- Ignore Resistance
- Duplicate Area
- Additional Base

## 6.2 Scroll Definition

Each scroll should contain:

- Unique identifier.
- Display name.
- Description.
- Category.
- Rarity.
- Associated effect or component data.
- Icon reference.

Scrolls should be data-driven so that additional scroll types can be introduced without rewriting the inventory or crafting systems.

Built in Sprint 5: one `ScrollData` class with a category and optional category fields (`element` for Base, `area_data` for Area, `buff_id` for Buff). The inventory and drop tables only ever hold `ScrollData`.

## 6.3 Scroll Inventory

The inventory should store collected scrolls.

It should support:

- Adding scrolls.
- Removing scrolls.
- Checking available scrolls.
- Grouping scrolls by category.
- Checking scroll quantities.

The inventory should be independent of the crafting interface.

---

# 7. Crafting System Architecture

The Crafting System is responsible for combining scrolls into Spell Instances.

The Arcane Lectern acts as the interaction point, while the crafting logic should exist independently of the Lectern scene.

## 7.1 Crafting Process

1. Player interacts with an Arcane Lectern.
2. Crafting interface opens.
3. Player selects a Base scroll.
4. Player selects an Area scroll.
5. Player optionally selects Buff scrolls.
6. Crafting System validates the combination.
7. Spell Builder calculates the resulting properties.
8. Player confirms the combination.
9. Required scrolls are removed from inventory.
10. The resulting spell is created or equipped.

## 7.2 Spell Builder

The Spell Builder is responsible for calculating the final properties of a spell.

It should calculate:

- Final damage.
- Final maximum mana.
- Final mana consumption.
- Casting interval.
- Area dimensions.
- Projectile properties.
- Elemental interactions.
- Buff effects.

The Spell Builder should be reusable and independent of the crafting interface.

## 7.3 Validation

The Crafting System must validate:

- A Base scroll is present.
- An Area scroll is present.
- All selected Buffs are valid.
- The player has the required scroll quantities.
- The resulting spell can be equipped.
- The spell combination follows all crafting restrictions.

Invalid combinations must not consume scrolls.

Built in Sprint 6: `SpellBuilder` (static) builds the spell from a Base scroll, an Area scroll and a range option, using baselines on each Area (`AreaStats`) and multipliers on each Base scroll (`BaseModifiers`). `CraftingSystem` (static) validates a `CraftingRequest`, consumes the scrolls all-or-nothing and equips the spell through `SpellLoadout.equip`. `CraftingSession` holds the screen's choices with no UI, and `CraftingScreen` is a thin pausing layer over it. The rule linking range to mana cost lives in `SpellBuilder` and the range options live in `CraftingRules`. Buffs are not craftable yet (Sprint 7).

---

# 8. Elemental Damage System

Elemental damage calculations should be centralized.

Individual spells and enemies should not implement their own elemental calculations.

## 8.1 Elemental Relationships

| Element | Strong Against | Weak Against |
|---|---|---|
| Fire | Land | Sea |
| Thunder | Sea | Land |
| Land | Thunder | Fire |
| Sea | Fire | Thunder |

## 8.2 Damage Calculation

The Damage System should calculate final damage using:

- Spell base damage.
- Spell damage modifiers.
- Enemy elemental affinity.
- Enemy resistances.
- Enemy vulnerabilities.
- Active Buffs.

Built in Sprint 4: each enemy has one element, and its vulnerability (the element that beats it) and resistance (the element it beats) come from the element table. The multiplier is applied when a hit lands. Per-enemy overrides of vulnerability and resistance, and giving the player an element through equipment, are left for later sprints.

A centralized damage calculation prevents inconsistent behavior across different spell types.

Elemental multipliers should be configurable rather than hardcoded throughout the project.

## 8.3 Multiple Base Types

Spells can support additional Base types through Buffs.

The Damage System should be designed to support multiple elemental damage components.

**Settled and built in Sprint 7:** a hit uses the best match. `DamageSystem.resolve` compares each of the spell's elements with the defender's element and keeps the one with the highest multiplier (the first element wins a tie). Strong beats neutral beats weak. `vulnerability_scale` scales only a strong multiplier's bonus, and `ignores_resistance` turns a weak multiplier into a neutral one. A spell carries an `AttackProfile` (elements and these two flags) and the hitbox passes it to the hurtbox, which is still the only place the math runs. `SpellBuilder` averages the Bases' numbers for a hybrid.

---

# 9. Area System Architecture

Area types should be implemented as separate, interchangeable behaviors.

The Spell System should not need to know the internal implementation of every Area type.

Each Area implementation should expose a consistent interface for casting.

## 9.1 Line

- Originates from the player.
- Uses the player's aiming direction.
- Applies damage along a configurable path.

## 9.2 Cone

- Originates from the player.
- Uses the player's aiming direction.
- Applies damage within a configurable angle.

## 9.3 Area

- Targets a location selected by the player.
- Creates an area-of-effect attack.
- Supports configurable radius and duration.

## 9.4 Missile

- Originates from the player.
- Travels in the selected direction.
- Supports configurable speed and range.
- Applies damage on collision.

## 9.5 Wave

- Originates from the player.
- Travels in the selected direction as a wide crescent that widens as it moves.
- Hits every enemy it passes through once.
- Supports configurable width, speed and range.

Each Area is its own scene behind one `launch(spell, origin, direction, target)` call, with its default range and size in an `AreaData` resource. A spell points at an `AreaData` and scales its range and size, so crafting only has to change those two numbers.

Each Area implementation should support additional modifiers where appropriate.

For example, Duplicate Area should not require rewriting the individual Area implementations.

---

# 10. Progression Architecture

Progression should be separated into two distinct systems.

## 10.1 Run Progression

Run Progression handles temporary improvements during an adventure.

Responsibilities include:

- XP collection.
- Current level.
- XP thresholds.
- Level-up rewards.
- Temporary stat improvements.
- Spell slot unlocks.
- Starting spell modifications.

The wizard's XP and level persist between runs (the user's decision, Sprint 8), so they live in the saved profile described in 10.2. What resets each run is the run's own state: health, mana, scrolls and the spells equipped after the starting ones.

## 10.2 Permanent Progression

Permanent Progression handles improvements retained between adventures.

Responsibilities include:

- XP and level (Sprint 8), with the buff chosen for each starting-spell buff reward.
- Persistent Gold.
- Equipment ownership.
- Equipment selection.
- Purchased upgrades.
- Persistent unlocks.
- Save data.

Permanent progression should be independent of temporary run state.

### Save format (Sprint 8)

The profile is one JSON file, `user://save.json`, written to a temporary file and renamed over the old one:

```json
{"version": 1, "total_xp": 5321, "gold": 113, "owned": ["robe_tide", "staff_elder"], "equipped": {"0": "robe_tide", "1": "staff_elder"}, "potions": {"potion_health": 3, "potion_luck": 1}}
```

`version` is checked on load. The level is computed from `total_xp` and never stored. `gold`, `owned` and `equipped` are optional and default to 0, empty and empty, so an older file loads (an old `buff_picks` field is ignored, because starting-spell buffs are picked or re-rolled every run and never saved). `equipped` maps a slot (0 Robe, 1 Weapon, 2 Headwear) to an item id, and an entry whose item is not owned is dropped on load. `total_xp` and `gold` must be whole numbers from 0 to 2^53. A file that cannot be used is renamed to `save.json.bak` and a fresh profile starts. `potions` is also optional (potion id to a whole count from 1 to 99, zero counts are not written, and a count that is not a whole number from 0 to 99 makes the file unusable).

The exact persistence rules should follow the game design document.

---

# 11. Equipment Architecture

Equipment should use reusable Resource definitions.

Equipment categories:

- Robes
- Wands
- Staffs
- Hats
- Hoods

Each equipment definition should contain:

- Unique identifier.
- Display name.
- Description.
- Equipment category.
- Purchase price.
- Passive modifiers.
- Special effects.
- Icon or sprite reference.

Equipment effects should be applied through a centralized modifier system rather than directly modifying player statistics in multiple locations.

Hats and Hoods share the same equipment behavior and differ only in appearance.

Wands and Staffs should have distinct gameplay characteristics.

---

# 12. Potion Architecture

Potions are consumable items that provide temporary effects.

Potion definitions should contain:

- Unique identifier.
- Display name.
- Description.
- Purchase price.
- Effect type.
- Effect magnitude.
- Effect duration.
- Usage restrictions.

Potion behavior should be handled through reusable effect logic.

Mana Potions must be able to explicitly restore depleted spell mana.

---

# 13. Input Architecture

Input should be managed through Godot's Input Map.

Required actions should include:

| Action | Default Input |
|---|---|
| Move Up | W |
| Move Down | S |
| Move Left | A |
| Move Right | D |
| Interact | E |
| Pause | Escape |
| Spell Slot 1 | 1 |
| Spell Slot 2 | 2 |
| Spell Slot 3 | 3 |
| Spell Slot 4 | 4 |
| Spell Slot 5 | 5 |
| Aim | Mouse Position |
| Cast | Left Mouse Button |

Controller support should be implemented using the same logical actions.

Keyboard and controller inputs should not require separate gameplay implementations.

---

# 14. User Interface Architecture

The UI should be separated into reusable scenes.

Important interfaces include:

- Main Menu.
- HUD.
- Health Display.
- XP Display.
- Spell Loadout.
- Spell Mana Indicators.
- Scroll Inventory.
- Crafting Interface.
- Equipment Shop.
- Potion Inventory.
- Pause Menu.
- Game Over Screen.

UI elements should receive information from their respective systems rather than directly modifying gameplay data.

---

# 15. Data and Configuration Standards

Whenever possible, gameplay values should be configurable through Resources or exported properties.

Avoid scattering balancing values throughout scripts.

Examples of configurable values:

- Player health.
- Player movement speed.
- Enemy health.
- Enemy movement speed.
- Spell damage.
- Spell mana capacity.
- Spell mana cost.
- Casting interval.
- Elemental damage multipliers.
- Scroll drop chances.
- XP rewards.
- Gold rewards.

This makes balancing significantly easier.

---

# 16. Coding Standards

All code should follow consistent conventions.

### Naming

- Classes: PascalCase.
- Variables: snake_case.
- Functions: snake_case.
- Constants: UPPER_SNAKE_CASE.
- Signals: snake_case.

### Code Organization

- One primary responsibility per script.
- Prefer composition over unnecessary inheritance.
- Use typed GDScript where practical.
- Use descriptive variable and function names.
- Avoid unnecessarily large scripts.
- Avoid circular dependencies.
- Avoid unnecessary autoloads.
- Use signals for communication between independent systems where appropriate.

### Reusability

Before implementing a feature, consider whether it should be:

- A reusable scene.
- A reusable Resource.
- A reusable component.
- A centralized system.
- A specific implementation of an existing interface.

Avoid duplicating functionality.

---

# 17. Testing Strategy

Testing should happen throughout development rather than being postponed until the end.

Important systems should have automated tests where practical.

Priority testing areas:

- Spell construction.
- Mana consumption.
- Mana restoration.
- Elemental damage calculations.
- Buff calculations.
- Area duplication.
- Scroll inventory.
- Crafting validation.
- Spell replacement.
- XP progression.
- Equipment modifiers.
- Save/load functionality.

Every sprint should include testing of the new functionality and regression testing of affected existing systems.

---

# 18. Performance Considerations

The game will potentially contain large numbers of enemies, projectiles, and spell effects simultaneously.

Performance should be considered early.

Potential optimizations include:

- Object pooling for frequently spawned projectiles.
- Efficient enemy spawning.
- Avoiding unnecessary physics calculations.
- Avoiding excessive per-frame processing.
- Limiting unnecessary scene instantiation.
- Reusing resources and textures.
- Profiling before introducing complex optimizations.

Do not prematurely optimize systems without identifying actual performance problems.

---

# 19. Development Guidelines

The technical architecture should evolve alongside the project.

These guidelines should be followed throughout development:

1. Build only what is required for the current sprint.
2. Do not implement future features prematurely.
3. Keep gameplay systems modular.
4. Prefer reusable data definitions.
5. Keep balancing values configurable.
6. Avoid hardcoding individual spell combinations.
7. Keep UI logic separate from gameplay logic.
8. Test new systems before expanding them.
9. Document significant architectural decisions.
10. Ask for clarification before making changes that affect established game mechanics.

Any significant architectural change should be documented and reviewed before implementation.

---

# 20. Future Technical Considerations

The architecture should leave room for future additions without requiring them during initial development.

Potential expansions:

- Spell evolution.
- Rare scrolls.
- Additional elemental types.
- Additional Area types.
- New Buff categories.
- Multiple playable characters.
- Multiple biomes.
- Additional enemy archetypes.
- Additional bosses.
- Challenge modes.
- Endless mode.
- Achievements.
- Steam integration.

These features should only be implemented when their respective development priorities are established.

---

# Final Technical Philosophy

The goal is not to build the most complicated architecture possible.

The goal is to build a system that is simple enough to develop quickly but flexible enough to support the game's defining mechanic: dynamically creating spells from interchangeable components.

Prioritize modularity where it provides real value, avoid unnecessary abstraction, and keep the project easy to understand and maintain.