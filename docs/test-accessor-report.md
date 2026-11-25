# Test-only accessor report (spring cleaning 2)

Requested by the user (item 5 of the follow-up list). **No code was changed.** The user decides what to remove.

**Method.** A script listed every public function in `scripts/` and `resources/` whose name appears nowhere else in production code (`scripts/`, `resources/`, `scenes/`, `tools/`) but does in `tests/`, plus every function whose doc comment says it is for tests. That gave **96** functions (the earlier estimate was 92). I read each one and its test callers. The scan counts a name anywhere in production text as a use, so a name shared with an unrelated function could hide a test-only one; it errs towards missing some, not inventing any.

## Decisions

| Decision | Count | Meaning |
|---|---|---|
| Keep: observer seam | 73 | Reads private state of a widget, the sound board or the effects, so a test can see what the player would see. The only alternative is making that state public. |
| Keep: documented contract or tool API | 7 | Named in the architecture docs or used by developer tools, or encodes a design rule. |
| Make real | 2 | A real concept the game computes inline somewhere; use the method there so it has a production caller. |
| Move to a test helper | 2 | Loaders only tests call. |
| Remove | 7 | Dead in the game; tests can reach the fact another way. |
| Delegating wrappers | 5 | Thin pass-throughs; low value either way. |

## Remove (recommended)

- `target_reticle.draws_circle` (2 test uses): `return not has_art()`: a second name for `has_art`; tests can assert `has_art()`.
- `potion_slot_widget.highlight_visible` (1 test uses): derived from `frame_variation() == &"PanelSlotSelected"`; tests can assert `frame_variation()`.
- `map_catalog.default_id` (2 test uses): unused: the first entry of `ids()`; tests use `ids()[0]`.
- `map_catalog.entry_for_scene` (3 test uses): unused by the game (a run is started from the entry's scene path, never looked up by it); tests would use a loop over `entries`.
- `potion_catalog.index_of` (3 test uses): unused: potion buttons already know their index; tests could use `potions.find`/array order.
- `level_track.xp_to_next` (2 test uses): unused: the XP bar computes its own fill; tests use `level_for_xp` and `xp_for_level` directly.
- `sprite_set_data.frame_count` (6 test uses): became dead when the decoration system was removed in this cleanup (it counted a decoration sheet's variants); tests can compute `sheet.get_width() / frame_size.x`, or the 6 uses move to a test helper.

## Make real

- `spell_instance.mana_ratio` (3 test uses): only tests call it; `SpellSlotWidget` receives `set_mana(current, maximum)` and derives its own ratio. Either pass `mana_ratio()` along with those two numbers, or drop the method.
- `point_of_interest.is_ready` (12 test uses): the prompt and the use path both test `cooldown_left <= 0.0` inline; call `is_ready()` there.

## Move to a test helper

- `difficulty_curve.default_curve` (8 test uses): `load(DEFAULT_PATH)`; the game gets these through its scene or config. Move to `tests/helpers/` and update the callers.
- `elite_modifier.default_modifier` (20 test uses): `load(DEFAULT_PATH)`; the game gets these through its scene or config. Move to `tests/helpers/` and update the callers.

## Delegating wrappers on `CraftingScreen` (your call)

`choose_base`, `choose_area`, `choose_range`, `choose_slot` and `confirm_enabled` only forward to `session`. Tests use them 45 times. Removing them means the tests call `screen.session.select_base(...)` instead; same coverage, a smaller screen. I would leave them: they are the screen's test-facing API and the screen is the harder thing to drive.

## Keep: documented contract or tool API

- `damage_system.calculate` (11 test uses): the Sprint 1 contract named in the architecture docs ("all damage goes through `DamageSystem.calculate`"); production uses `resolve`. Keep unless the contract text is rewritten.
- `spell_audit.rows` (115 test uses): used by `scripts/dev/spell_audit.gd`, a developer tool.
- `run_potions.counts` (56 test uses): documented "for tests and tools"; used by the potion bar.
- `body_view.set_set` (18 test uses): used by `set_look`; the "for tests" note is also true.
- `map_maze.center_room_center` (8 test uses): map-authoring helper in the architecture docs (where the middle room is).
- `map_maze.dead_end_cells` (9 test uses): map-authoring helper in the architecture docs (where placements go in a maze).
- `boss_attack.escape_margin` (4 test uses): the formula of the always-avoidable boss rule; tests pin it for every attack.

## Keep: observer seams (73)

Grouped by owner; each reads one private value: a label's text, a button count, the focus, a pool, a playing state.

- **art**: `distinct_color_count`
- **audio**: `has_warned`, `reset_warnings`, `plays_started`, `last_pitch_scale`, `last_volume_offset_db`, `music_state`, `music_starts`, `music_volume_db`, `music_playing`, `music_bus_db`, `music_stream_paused`
- **components**: `is_finished`, `time_left`
- **enemies**: `outer_marks`, `inner_marks`, `charge_marks`
- **entities**: `current_animation`, `shadow_width`
- **fx**: `frame_alpha`, `live_particles`, `visible_arcs`, `is_bound`, `bursts_made`, `camera_shake`, `hurt_active`
- **progression**: `is_dirty`
- **spells**: `start_delay`, `orbs`
- **systems**: `gem_count`
- **ui**: `is_muted`, `option_count`, `first_button_has_focus`, `number_variation`, `mana_fill_width`, `recap_text`, `toggle_button`, `fullscreen_button`, `item_button_count`, `item_button_variation`, `potion_button_count`, `card_count`, `card_button`, `card_text`, `focused_index`, `has_floor`, `shown_text`, `active_texts`, `preview_height`, `buff_button_count`, `base_button_count`, `area_button_count`, `range_button_count`, `heart_texture`, `page_index`, `page_count`, `counter_text`, `lines_text`, `picture_count`, `cooldown_overlay_height`, `effect_bar_visible`, `effect_bar_width`, `text_variation`, `label_text`, `fill_ratio`
- **world**: `chunk_count`, `distance_at`, `art_obstacle_count`, `sound_count`, `omitted_cells`, `drawn_edge_cells`, `impact_button_count`, `last_weight`

## Recommendation

Do the seven removals, the two loader moves and the two "make real" changes (about 11 small edits, no behaviour change, tests adjusted) and leave the observer seams: making a label's text or a pool's size public to avoid a one-line reader would not be an improvement. I would not touch the `CraftingScreen` wrappers.
