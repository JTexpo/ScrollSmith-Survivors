# Combat and spells

The component-based combat, the spell data and loadout, the five Areas and the elemental rules. Moved word for word from `CLAUDE.md`, one `##` section per sprint. Sections name each other (for example "see Obstacles"); find them in this folder (the index is in `CLAUDE.md`, "Where the detail lives").

## Combat architecture (Sprint 1)

- Combat is built from small components on an entity: `HealthComponent`, `HurtboxComponent` (receives hits, optional player-wide invulnerability window), `HitboxComponent` (deals damage, per-target cooldown, optional one-shot), `KnockbackComponent`, `HitFlashComponent`. All damage goes through `DamageSystem.calculate`, the single place elemental rules will live.
- Collision layers (named in `project.godot`, bit constants in `PhysicsLayers`): world, player_hurtbox, enemy_hurtbox, enemy_hitbox, player_projectile. Enemy hurtboxes and hitboxes are passive (`monitoring = false`), so only the player's hurtbox and projectiles do any overlap work. Enemies never detect each other.
- Enemies are light `Node2D`s moved by position (no `move_and_slide()`), clamped to the arena bounds. Since Sprint 12b they also stay out of obstacles and route around them (see Obstacles). Stats come from `EnemyData` and spawning from `SpawnConfig`. The health bar and spell bar got the Sprint 13d look (see Interface).
- Aim and fire go through `AimComponent` (mouse, right stick, or the touch aim stick) and `cast`. The Player forwards both to `SpellLoadout`. `emulate_mouse_from_touch` is off on purpose, so touching the move stick never fires.
- Hand-written `.tscn` files need `node_paths=PackedStringArray("prop")` on the `[node]` line for any exported Node-typed property set with a NodePath, or it stays null silently.
- `TouchJoystick` is ours. Godot 4.7 has a native `VirtualJoystick`, so don't reuse that name.

## Spell architecture (Sprint 2)

- `SpellData` (Resource) is static configuration: elements, damage, mana, cast interval, projectile stats, `max_hits`. `SpellInstance` (`RefCounted`) is the equipped runtime object and owns current mana and the cooldown. Never put mutable state on `SpellData`, because resources are shared and two copies of a spell must never share mana.
- `SpellLoadout` (component on the Player) holds five slots and the selected index, selects and cycles, and casts through `try_cast`. A depleted spell stays selected and does nothing (no auto-switch). Slot keys, controller shoulder buttons (`spell_prev`/`spell_next`) and the touch `SpellBar` all end in `select` or `cycle`. `try_cast` instantiates the spell's Area scene (see Sprint 3 below).
- `MissileArea` takes everything from the `SpellData` it is launched with. `HitboxComponent.max_hits` and `SpellData.max_hits` make piercing a data change.
- Elemental math lives only in `ElementTable` (configurable multipliers, Fire > Land > Thunder > Sea > Fire) and `DamageSystem.calculate(base, attacker_element, defender_element, table)`. Since Sprint 4 the multiplier is applied at impact (see Elemental enemies below).
- `SpellBar` and `SpellSlotWidget` are the spell bar. Slot widgets read the loadout and handle touch taps themselves (`emulate_mouse_from_touch` is off) and ignore mouse clicks.

## Area architecture (Sprint 3)

- Five Areas: Line, Cone, Area (ground zone), Missile, Wave. Each is its own scene under `scenes/spells/areas/`, whose root script extends `AreaEffect` and implements `launch(spell, origin, direction, target)`. `SpellLoadout.try_cast` instantiates `spell.area_data.scene` and calls it. Never branch on the Area type in the loadout, player or damage code.
- `AreaData` (Resource, `resources/spells/areas/`) holds one Area type's scene and defaults: `default_range`, `default_size`, `duration`, `tick_interval`, `widen_rate`, `needs_ground_target`. A `SpellData` points at one and carries `range_scale` and `size_scale`. `effective_range()` and `effective_size()` are the numbers every Area reads, and Sprint 6 crafting only has to write the two scales. Mana cost stays an authored number per spell. The rule "longer range costs more" belongs to the Spell Builder (Sprint 6), not the Areas.
- Ground-targeted Areas land at `SpellData.clamp_target(origin, target)`. The mouse's target is the cursor and a stick's is a far point along the aim, so a stick lands at full range. Targeting and the `TargetReticle` read `AreaData.needs_ground_target`.
- All Areas build their hit damage through `AreaEffect._configure_hitbox`, so Sprint 4 moves the elemental multiplier to hit time in one place. Line, Cone and Wave hit each enemy once per cast and Area hits once per tick, through `HitboxComponent.hit_cooldown`.
- Enemies are clamped to the arena bounds (no negative coordinates), so Area tests cast from an offset origin.

## Elemental enemies (Sprint 4)

- The elemental multiplier is applied when a hit lands. `HitboxComponent.element` is the attacker's element (set from the spell in `AreaEffect._configure_hitbox`, which carries raw damage) and `HurtboxComponent.element` is the defender's. `HurtboxComponent.receive_hit(damage, source_position, knockback, attacker_element)` gets the final damage from `DamageSystem.calculate` and an `ElementTable.Effect` (NEUTRAL, VULNERABLE, RESISTED) from `DamageSystem.effect`, then emits `hit_received(damage, source_position, knockback, effect)`. No other code does elemental math.
- Rules: an enemy has one element. It takes the strong multiplier from the element that beats it and the weak one from the element it beats. Same element, no element, or an unknown value is normal damage.
- The player's hurtbox has no element by default and enemy contact hitboxes carry none, so hits on the player are neutral. This is today's default, not a rule: equipment (robes, hats) may later give the player an element through `HurtboxComponent.element`, so never hardcode "the player is neutral".
- `EnemyData` is the composed shape an enemy runs on (element, colour, stats, rewards, behaviour). Since Sprint 11 it is built from an archetype and an element (see Enemies and bosses below), not hand-written per enemy. There is still one enemy scene. The five old enemy files live on only as test fixtures in `tests/fixtures/enemies/` (enemies with a known element and health).
- `Enemy.damaged(position, amount, effect)` is re-emitted by `EnemySpawner.enemy_damaged`, and `Main` routes it to `DamageNumbers`, a pooled node that draws every number in one `_draw`. Vulnerable hits are yellow and end in "!", resisted hits grey; all use the one font size (Sprint 13d).
