# Sprint 13d: The Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every HUD piece and screen one whimsical, light, cartoony look: a slim pixel font with a baked outline for text over the world, cream-and-plum 9-slice panels, red, green and yellow buttons, pink and sky bars and slot frames, all from one committed Godot theme, with no placeholder text left.

**Architecture:** The art pipeline grows three things: a `.font` glyph-grid source built into BMFont sheets (a plain and an outlined build with identical metrics), 9-slice UI sprites (`slice` without `tile`, so corners may be transparent), and a deterministic `ThemeBuilder` that writes `resources/ui/game_theme.tres` as text, like `SpriteSetData`. `gui/theme/custom` points at it, so every `Control` inherits it. A small static `UiKit` replaces the per-screen `_label` and `_button` helpers. Behaviour, layout, input and every system the UI reads stay exactly as they are.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, the 13a to 13c art pipeline (`art/`, `tools/art/art_builder.gd`).

**Spec:** `sprint-13d-design.md`

## Global Constraints

- Commands run with the venv active (`source venv/bin/activate`). Any Python is `venv/bin/python` (never bare `python3`, never Perl). Test command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (add `-gselect=<file without .gd>` for one file). Run `godot --headless --import` after adding or renaming a `class_name` script and after the art tool. On macOS use `sed -i ''`, prefer the Edit tool for multi-line edits, zsh does not word-split unquoted variables (use `${=var}`), and `rm` takes the full literal path (delete only what you created).
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Chain commands with `&&`.
- **One pixel size everywhere (user rule): never scale or pixel-double art.** Panels and buttons grow by tiling their slice (`AXIS_STRETCH_MODE_TILE`, never `TILE_FIT` or `STRETCH`), glyphs are drawn at the font's one fixed size, and no UI sprite is drawn at a scale other than 1. If something is too small, redraw it with more pixels.
- **The look (user, from the mockups):** cream panels with a thick plum outline and stepped rounded corners; pink health and sky-blue XP bars; cream slot frames; **red** main buttons (Try again, Buy), **green** second buttons (Shop, Equip), **yellow** for Gold, highlights and the selected slot. Light, bright, simple, cartoon, few colours at once. **The font is slim** (the game has many stats to read).
- Palette: the limit rises from 64 to **96** colours (a UI section); every UI pixel is a palette colour (the 13a asset test checks it).
- **Behaviour does not change.** Layouts, positions, input handling (mouse, keyboard, controller focus, the touch bridge and each screen's own `handle_input` or `handle_event` taps), pause, focus order, `mouse_filter` rules, `TouchJoystick` (its translucent rings stay) and every system the UI reads from. The UI never mutates gameplay data. Existing UI tests keep passing unchanged; if a deliberate API change forces a test edit, ledger it as a ruling.
- A missing font, sheet or sprite never crashes and never hides text: `UiFont` falls back to `ThemeDB.fallback_font`, and the theme builder leaves out a style whose sprite is missing.
- All text the game prints is ASCII (one glyph per character, codes 32 to 126).
- Tests never touch the real save (`save_path = ""`). Tests that instantiate `main.tscn` also set the pick screen's `pause_tree` to false.
- Hand-written `.tscn` files need `node_paths=PackedStringArray("prop")` for exported Node-typed properties set by NodePath. A world scene must not add a `Control` that stops touches (`tests/test_world_input.gd`); HUD `Control`s that must not eat touches use `mouse_filter = 2`.
- Do not name a local or parameter after a `CanvasItem` or `Node` property (`material`, `name`, `scale`, `theme`...): the MCP run flags it. Do not name a test helper `_set`.
- Real-window and MCP checks: run `mcp__godot__run_project` once per task that changes visuals, read `get_debug_output` for warnings, then `stop_project`. Throwaway real-window scripts live in the scratchpad, set `save_path` empty, and are deleted by exact path afterwards. Check screenshots over grass, stone, a maze and the boss.
- The stress scene: `godot --path . res://scenes/world/stress_test.tscn -- --enemies=300 --seconds=8 --drops --obstacles` (about 115 fps median now; damage numbers and bars draw every frame, so compare before and after).

## Review Focus

- Every character the game can print has a glyph in both builds: the longest and strangest strings (item and potion descriptions, drawbacks, the crafting preview, boss and scroll names) contain only ASCII 32 to 126, and a missing glyph is caught by a test, not by a box on screen (Tasks 2 and 9).
- Text fits: the longest strings fit or wrap inside their panel and button at the font's real measured width, on the shop, merchant, crafting, buff pick, death and inventory screens (Tasks 6, 7, 8 and 9).
- Input is exactly as before: focus order, controller and keyboard activation, the bridged touch taps, the death screen's Shop-button tap, and the input guards on the shop and merchant still pass their old tests; a real window with mouse and touch confirms (Tasks 6 to 9).
- Missing art degrades gracefully: with no font sheet, no theme sprites or an empty sprite library, the theme and `UiFont` still load and every label still shows (Tasks 2, 4 and 5).
- Frame rate: damage numbers, bars and slots draw every frame with the new font and sprites, and the stress scene at 300 enemies stays within about 10% of today (Tasks 5, 6 and 9).

---

## File Structure

- Pipeline: `scripts/art/art_palette.gd` (limit comment), `art/palette.txt` (UI section), `scripts/art/sprite_source.gd` (`slice` without `tile`), `scripts/art/art_builder.gd` (skip silhouette for sliced sprites, build fonts and the theme), `tools/art/art_builder.gd` (unchanged call), `tests/test_art_sources.gd`, `test_art_builder.gd`, `test_art_assets.gd`.
- Font: new `scripts/art/font_source.gd` (parse a `.font`), `scripts/art/font_builder.gd` (plain and outlined BMFont text and sheets), `scripts/ui/ui_font.gd` (`UiFont`, static lookup), `art/fonts/ui.font`, `assets/fonts/ui_plain.{fnt,png}` and `ui_outlined.{fnt,png}`, `tests/test_font_source.gd`, `tests/test_font_builder.gd`, `tests/test_ui_font.gd`.
- UI sprites: `art/sprites/ui_*.sprite`, `art/sprites/icon_*.sprite` and their built files.
- Theme: new `scripts/art/theme_builder.gd`, `resources/ui/game_theme.tres` (generated), `project.godot` (`gui/theme/custom`), `tests/test_theme_builder.gd`.
- Kit: new `scripts/ui/ui_kit.gd`, `tests/test_ui_kit.gd`.
- HUD: `scripts/ui/{health_bar,xp_bar,gold_counter,run_clock_label,boss_bar,level_toast,scroll_toast,damage_numbers,interact_button,inventory_button}.gd` and `scenes/ui/*.tscn` of the same names, plus the prompts of `scripts/entities/lectern.gd` and `scripts/world/point_of_interest.gd` (find their prompt labels with grep).
- Slots: `scripts/ui/{spell_slot_widget,potion_slot_widget,spell_bar,potion_bar}.gd`.
- Screens: `scripts/ui/{death_screen,buff_pick_screen,inventory_panel,merchant_screen,shop_screen,crafting_screen}.gd` and `scenes/ui/{death_screen,...}.tscn`.
- Guards and docs: new `tests/test_ui_look.gd`, `CLAUDE.md`, `README.md`, `technical-design.md`, `sprint-development.md`, `development-log.md`.

---

### Task 1: The UI palette and a 96-colour limit

**Files:**
- Modify: `art/palette.txt`, `scripts/art/art_palette.gd` (header comment), `tests/test_art_assets.gd`

**Interfaces:**
- Produces: palette letters for the UI (unused single characters that are not `.`, `#` or `1` to `5`; the builder picks them): cream, cream shade, plum, plum light, pink, pink dark, sky, sky dark, red, red dark, green, green dark, yellow, yellow dark. Hex values to use: cream `#fff6e8`, cream shade `#e9dcf2`, plum `#3b2a5c`, plum light `#6b5a8c`, pink `#ff6f8f`, pink dark `#c9446a`, sky `#6fd3ff`, sky dark `#3a9fd6`, red `#e0483c`, red dark `#9e2a22`, green `#5fbf5a`, green dark `#348a3a`, yellow `#ffd24a`, yellow dark `#d99a1a`. Colours the palette already has are reused, not duplicated.

- [ ] **Step 1: Write the failing test.** In `test_art_assets`, change `MAX_COLORS` to 96 and add `test_the_palette_has_the_ui_colours` asserting the 14 hex values above are all in `_allowed_colors()`. Run `-gselect=test_art_assets`. Expected: FAIL (colours missing).
- [ ] **Step 2: Implement.** Add a "UI (Sprint 13d)" section to `art/palette.txt` with comments naming each colour, skipping any hex already present, and update the "At most 40" comment at the top of the file and the one in `art_palette.gd` to 96.
- [ ] **Step 3: Run** `test_art_assets`, the art tool (`godot --headless -s tools/art/art_builder.gd`, `git status` shows no changed committed art), then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: the UI palette`.

---

### Task 2: The pixel font

**Files:**
- Create: `scripts/art/font_source.gd`, `scripts/art/font_builder.gd`, `scripts/ui/ui_font.gd`, `art/fonts/ui.font`, `assets/fonts/ui_plain.{fnt,png}`, `assets/fonts/ui_outlined.{fnt,png}`, `tests/test_font_source.gd`, `tests/test_font_builder.gd`, `tests/test_ui_font.gd`
- Modify: `scripts/art/art_builder.gd` (`build_all` also builds `art/fonts/*.font` into `assets/fonts/`), `tests/test_art_assets.gd` (stale-font test)

**Interfaces:**
- Produces: `FontSource.parse(text) -> FontSource` with `errors`, `ascent: int`, `descent: int`, `glyphs: Dictionary` (code `int` to `{"advance": int, "rows": PackedStringArray}`). Source format: `ascent <n>`, `descent <n>`, `glyph <code> <advance>` then `ascent + descent` rows of `#` (ink) and `.`; `#` starts a comment line only at the start of a line before a row. `FontBuilder.build_sheet(source, outlined: bool) -> Image` (glyphs side by side, ink white, outline the palette's dark `K`, transparent elsewhere), `FontBuilder.fnt_text(source, png_name, outlined) -> String` (BMFont text format: `info`, `common` with `lineHeight`, `base`, one `char` line per glyph). `UiFont.SIZE: int` (the font's fixed size, equal to its line height), `UiFont.plain() -> Font`, `UiFont.outlined() -> Font` (the imported `FontFile`, or `ThemeDB.fallback_font` when the file is missing).
- **Metrics pin:** the plain and outlined builds have identical advances and line height. The 1 px outline sits in the 1 px gap between letters and the 1 px above and below, so text never reflows between the two. The font is slim: letters 5 px wide with a 1 px gap (advance 6, narrower for `i l ! . , : ;` and a space), about 7 px of ascent (capitals and ascenders) and 2 of descent (g j p q y), lowercase and uppercase.

- [ ] **Step 1: Write the failing tests.** `test_font_source`: `test_a_glyph_block_parses_its_rows_and_advance`, `test_a_glyph_with_the_wrong_row_count_is_an_error`, `test_a_row_with_a_character_other_than_hash_or_dot_is_an_error`, `test_a_duplicate_glyph_code_is_an_error`. `test_font_builder`: `test_the_outlined_sheet_is_the_plain_ink_plus_a_one_pixel_outline` (every plain ink pixel is white in the outlined sheet, and every outline pixel touches ink within one pixel on all eight sides), `test_both_builds_have_the_same_advances_and_line_height` (parse both `fnt_text` outputs), `test_fnt_text_lists_one_char_line_per_glyph`. `test_ui_font`: `test_every_printable_ascii_character_has_a_glyph_in_both_builds` (`font.has_char(c)` for 32 to 126), `test_a_string_measures_advance_times_length` (a fixed-pitch string such as `"HHHH"` measures four advances at `UiFont.SIZE`), `test_the_font_falls_back_when_the_file_is_missing` (point the loader at a missing path and expect `ThemeDB.fallback_font`, no error). `test_art_assets`: `test_each_committed_font_equals_what_the_tool_builds` (both builds, sheet and `fnt`). Run those files. Expected: FAIL.
- [ ] **Step 2: Implement** `FontSource`, `FontBuilder`, `UiFont` (a `static var` path for tests, as `SpriteLibrary.root`), and the `build_all` hook. Godot imports `assets/fonts/*.fnt` as a `FontFile` natively; run `godot --headless --import` to create the import files and commit them, as for the sprite PNGs. If the import does not give a fixed-size bitmap font that measures as pinned, rule on the smallest fix (writing a `FontFile` resource instead) and ledger it.
- [ ] **Step 3: Draw `art/fonts/ui.font`** (all 95 printable ASCII glyphs) with a throwaway generator in the scratchpad (a 5x7-style slim face, hand-tuned shapes for the letters that read badly: `a e g k m n r s 0 1 2 3 5 6 8 9 % $ & @`). Run the art tool and the import, then check the sheet with a real-window screenshot at 3x of "The quick brown fox jumps over the lazy dog 0123456789 +-x/%:!?" in both builds over green and cream backgrounds. Iterate on shapes until it reads cleanly.
- [ ] **Step 4: Run** the new files, `test_art_assets`, then the whole suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: a slim pixel font with a baked-outline build`.

---

### Task 3: Sliced UI sprites and icons

**Files:**
- Modify: `scripts/art/sprite_source.gd`, `scripts/art/art_builder.gd`, `tests/test_art_sources.gd`, `tests/test_art_builder.gd`, `tests/test_art_assets.gd`
- Create: `art/sprites/ui_panel.sprite`, `ui_panel_dark`, `ui_button_cream`, `ui_button_red`, `ui_button_green`, `ui_button_yellow` (each four frames in this order: normal, hover, pressed, disabled), `ui_slot` (two frames: normal, selected), `ui_bar_back`, `ui_bar_hp`, `ui_bar_xp`, `ui_bar_boss`, `icon_heart`, `icon_star`, `icon_coin`, `icon_scroll`, `icon_potion` (`.sprite` files and their built outputs)

**Interfaces:**
- Produces: `slice` is valid without `tile`: such a sprite is a **sliced sprite** (corners may be transparent). `SpriteSource.is_surface() -> bool` is true for a tile or any sprite with a slice. A surface skips the 1 px margin rule and gets no silhouette (the builder and the three asset tests use `is_surface()` where they used `tile`). Sprite names are pinned for Task 4: `ui_panel`, `ui_panel_dark`, `ui_button_{cream,red,green,yellow}`, `ui_slot`, `ui_bar_{back,hp,xp,boss}`, `icon_{heart,star,coin,scroll,potion}`. Slice margins are 3 px for panels and buttons (stepped corners of 2 to 3 px), 2 px left and right for bars, and the sheets use only the Task 1 colours.

- [ ] **Step 1: Write the failing tests.** `test_art_sources`: `test_slice_is_valid_without_a_tile_line` (no error), `test_is_surface_is_true_for_a_tile_and_for_a_sliced_sprite_only`, `test_a_slice_that_leaves_no_middle_is_still_an_error`. `test_art_builder`: `test_a_sliced_sprite_gets_no_silhouette`. `test_art_assets`: the margin test skips surfaces, and `test_every_sliced_sprite_has_a_middle_that_tiles` (for each sliced sprite and frame, the middle region is one repeating row and column pattern, so a tiled middle shows no seam: all pixels of the middle band in a row equal the first of that row). Run. Expected: FAIL.
- [ ] **Step 2: Implement** `is_surface`, relax the `slice needs tile` error, use `is_surface()` in the builder and tests.
- [ ] **Step 3: Draw the sprites** with a throwaway generator in the scratchpad: stepped rounded corners, a plum outline one to two pixels thick, a cream body for panels and cream buttons, red, green and yellow buttons with a darker bottom edge (the pressed frame one pixel lower, the disabled frame desaturated greys already in the palette), the slot a cream frame with a plum outline and a yellow selected frame, bars as rounded troughs with pink, sky and plum-and-red fills, icons 9 to 11 px with a plum outline.
- [ ] **Step 4: Run** the art tool, the import and the whole suite. Expected: PASS (the asset tests prove every pixel is a palette colour and no output is stale).
- [ ] **Step 5: Commit** `feat: sliced UI sprites and icons`.

---

### Task 4: The game theme

**Files:**
- Create: `scripts/art/theme_builder.gd`, `resources/ui/game_theme.tres` (generated by the art tool), `tests/test_theme_builder.gd`
- Modify: `scripts/art/art_builder.gd` (`build_all` also writes the theme), `project.godot` (`gui/theme/custom="res://resources/ui/game_theme.tres"`), `tests/test_art_assets.gd` (stale-theme test)

**Interfaces:**
- Consumes: `UiFont` files and the Task 3 sprite names; `SpriteLibrary.find(name)` for the sheet, frame size and slice.
- Produces: `ThemeBuilder.theme_text() -> String`, a deterministic `.tres` written by hand like `ArtBuilder.set_text` (discover the exact property names by saving a throwaway `Theme` with `ResourceSaver` in the scratchpad and copying its text format; never rely on `ResourceSaver` output for the committed file, because its sub-resource ids are random). Contents: default font `ui_plain` and default font size `UiFont.SIZE`; `StyleBoxTexture`s with `texture` the sheet, `region_rect` the frame, `texture_margin_*` the slice, and `axis_stretch_horizontal` and `axis_stretch_vertical` set to tile. Types: `Panel` and `PanelContainer` (`ui_panel`), `Button` (`ui_button_cream`: normal, hover, pressed, disabled, focus), `Label` (plum text, plain font), `ProgressBar` (back and fill, plain), `TooltipPanel`, `HSeparator`, `ScrollContainer` (no style). **Pinned variation names:** `PanelDark`; `ButtonRed`, `ButtonGreen`, `ButtonYellow`; `HudLabel` (outlined font, white text), `HudGold` (outlined, yellow), `Heading` (plain font, red-dark text, so a heading stands out from the plum body text at the one font size), `Muted` (plum light), `Warning` (red); `BarHp`, `BarXp`, `BarBoss` (a `ProgressBar` with that back and fill sprite, no percentage text).
- A style whose sprite is missing from the library is left out of the text (the control falls back to Godot's default), never an error.

- [ ] **Step 1: Write the failing tests.** `test_theme_builder`: `test_every_pinned_variation_exists` (load the committed theme, `has_type_variation`... for each name, or check the base type via `get_type_variation_base`), `test_every_stylebox_tiles_and_never_stretches` (every `StyleBoxTexture` has both axis modes TILE), `test_every_region_is_inside_its_sheet`, `test_the_default_font_and_size_are_the_ui_fonts`, `test_text_with_an_empty_library_has_no_styleboxes_and_no_error` (point `SpriteLibrary.root` at an empty temp folder and restore it in `after_each`), `test_theme_text_is_deterministic` (twice equal). `test_art_assets`: `test_the_committed_theme_equals_what_the_tool_writes`. Run. Expected: FAIL.
- [ ] **Step 2: Implement** `ThemeBuilder`, the `build_all` hook and the project setting. Run the tool, the import and a smoke run (`godot --headless --quit-after 60`, no new errors).
- [ ] **Step 3: Run** the new tests, `test_art_assets`, then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: the game theme`.

---

### Task 5: `UiKit`, the health bar, XP bar, Gold, clock and damage numbers

**Files:**
- Create: `scripts/ui/ui_kit.gd`, `tests/test_ui_kit.gd`
- Modify: `scripts/ui/{health_bar,xp_bar,gold_counter,run_clock_label,damage_numbers}.gd`, `scenes/ui/{health_bar,gold_counter,run_clock_label,xp_bar}.tscn`, `tests/test_health_bar.gd`, `tests/test_damage_numbers.gd` (only if forced, ledger it)

**Interfaces:**
- Produces: `UiKit.label(text: String, variation: StringName = &"") -> Label` and `UiKit.button(text: String, variation: StringName = &"") -> Button` (set `theme_type_variation`, `mouse_filter` IGNORE for labels, `focus_mode` ALL for buttons, nothing else), `UiKit.bar(variation: StringName) -> ProgressBar` (`show_percentage = false`, `mouse_filter` IGNORE, `max_value` 1, `step` 0). Screens call these instead of their own `_label` and `_button` (Tasks 6 to 8).
- Existing public surface is kept: `HealthBar.ratio`, `XpBar.fill_ratio()` and `level_text()`, `GoldCounter.gold_text()`, `RunClockLabel.format()` and `clock_text()`, `DamageNumbers.show_number`, `active_texts`, `style_for` and its `color` keys.

- [ ] **Step 1: Write the failing tests.** `test_ui_kit`: `test_a_label_ignores_the_mouse_and_takes_the_variation`, `test_a_button_can_take_focus_and_takes_the_variation`, `test_a_bar_hides_its_percentage_and_ignores_the_mouse`. `test_health_bar`: `test_the_bar_shows_a_heart_and_no_placeholder_text` (the scene has no `TempLabel`, no Label whose text contains "TEMP", and a node showing `icon_heart`), `test_the_health_bar_is_a_themed_progress_bar_whose_value_follows_health` (value equals `ratio`). `test_damage_numbers`: `test_numbers_draw_with_the_outlined_font` (a `font` getter or constant equals `UiFont.outlined()`) and `test_one_font_size_is_used_for_every_style` (the style dictionaries no longer carry a size; vulnerable and resisted differ by colour and the "!" suffix only, per the one-pixel-size rule). Add: the gold label uses variation `HudGold`, the clock and level text `HudLabel`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.** The health bar becomes an `icon_heart` `TextureRect` (nearest filter, 1:1, from the icon's `SpriteSetData` sheet) beside a `BarHp` `ProgressBar` 80 by 8 at its current position; the XP bar becomes a `BarXp` `ProgressBar` along the top with the level label (`HudLabel`) kept where it was; Gold and the clock become `HudGold` and `HudLabel`, with the overrides removed from their scripts and scenes. `DamageNumbers._draw` uses `UiFont.outlined()` at `UiFont.SIZE`.
- [ ] **Step 3: Run** the files above, an MCP run (HUD over grass), then the whole suite. Expected: PASS and no new debug warnings.
- [ ] **Step 4: Commit** `feat: themed health, XP, Gold, clock and damage numbers`.

---

### Task 6: Toasts, prompts, boss bar, buttons, spell and potion slots

**Files:**
- Modify: `scripts/ui/{boss_bar,level_toast,scroll_toast,interact_button,inventory_button,spell_slot_widget,potion_slot_widget,spell_bar,potion_bar}.gd`, `scenes/ui/{boss_bar,level_toast,scroll_toast,interact_button,inventory_button,spell_bar,potion_bar}.tscn`, the Lectern and point-of-interest prompt labels (grep `Label` in their scripts and scenes), `tests/test_scroll_toast.gd` (it asserts the font colour: keep the toast's colour behaviour, ledger any change)

**Interfaces:**
- Consumes: Task 4 variations and Task 5 `UiKit`.
- Produces: the same public surface on every widget (`SpellSlotWidget.element_color`, `ratio`, `selected`, `locked`, `depleted`, `is_flashing()`, `handle_touch`; `PotionSlotWidget.swatch_color`; `BossBar.show_boss`; the toasts' `show_*` and `lines`).

- [ ] **Step 1: Write the failing tests.** `test_spell_bar`/`test_potion_slot_widget`/`test_boss_bar`/`test_level_toast` stay as they are, plus new assertions in each: `test_a_slot_draws_the_slot_sprite_with_a_selected_frame` (selected switches the frame, locked and empty dim), `test_the_mana_fill_still_follows_the_ratio` (the fill width equals the inner width times `ratio`), `test_the_boss_bar_is_a_themed_bar_with_an_outlined_name`, `test_toasts_use_a_panel_and_the_plain_font_or_the_outlined_font_over_the_world` (the level toast sits on a `PanelDark` pill with `HudLabel` text; the scroll toast keeps the scroll's colour as its font colour), `test_the_touch_buttons_use_the_theme_buttons` (`ButtonYellow` for Interact, `ButtonGreen` for Inventory). Run. Expected: FAIL.
- [ ] **Step 2: Implement.** Slot frames draw `ui_slot` (the element swatch and mana fill sit inside it, unchanged numbers and colours), the selected frame is yellow; the number labels use `HudLabel`; the potion count likewise. The spell and potion bars keep their layout. The boss bar uses `BarBoss` and an outlined name. The level toast gets a `PanelDark` background, the scroll toast an outlined label. Every `add_theme_font_size_override` and hand-set stylebox in these files is removed.
- [ ] **Step 3: Run** the files above, an MCP run (spell bar, potion bar, a toast, a boss over stone), the touch behaviour tests, then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: themed toasts, prompts, boss bar, buttons and slots`.

---

### Task 7: The death, buff pick, inventory and merchant screens

**Files:**
- Modify: `scripts/ui/{death_screen,buff_pick_screen,inventory_panel,merchant_screen}.gd`, `scenes/ui/{death_screen,buff_pick_screen,inventory_panel,merchant_screen}.tscn`, their existing tests only if forced (ledger it)

**Interfaces:**
- Consumes: `UiKit`, the Task 4 variations. Roles: the death screen's "Try again" button is `ButtonRed` and "Shop" is `ButtonGreen`; the merchant's buy buttons are `ButtonRed` and its Close `ButtonGreen`; buff pick options are cream `Button`s.
- Produces: unchanged public surfaces (`DeathScreen.handle_event`, `set_shop_open`, `MerchantScreen.input_guard_msec`, `buy`, `BuffPickScreen` and `InventoryPanel` public methods). The death screen's tap-anywhere restart and its Shop-button tap are exactly as before.

- [ ] **Step 1: Write the failing tests.** In each screen's existing test file add `test_the_screen_sits_on_a_panel` and `test_the_longest_text_fits_inside_its_panel`: for the death screen the summary line, for the merchant the longest potion description and price line, for buff pick the longest buff name and description, for the inventory every scroll name with a count of 99 (measure with `UiFont.plain().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE)` against the control's width, or assert `autowrap_mode` is on and the wrapped height fits). `test_death_screen`: `test_the_death_screen_buttons_use_the_red_and_green_roles` and `test_the_death_message_has_no_font_size_override`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.** A dim overlay stays; the content moves onto a centred `Panel`; headings use `Heading`; messages use `Warning` or `Muted` where they are refusals or hints; buttons use the roles above; item text wraps (`autowrap_mode` word smart) inside the panel instead of overflowing. All `font_size` and stylebox overrides are removed. The `touch` and `handle_input` code is not touched.
- [ ] **Step 3: Run** the four screens' tests, an MCP run of each screen, then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: themed death, buff pick, inventory and merchant screens`.

---

### Task 8: The shop and crafting screens

**Files:**
- Modify: `scripts/ui/{shop_screen,crafting_screen}.gd`, `scenes/ui/{shop_screen,crafting_screen}.tscn`, their existing tests only if forced (ledger it)

**Interfaces:**
- Consumes: `UiKit`, the Task 4 variations. Roles: crafting's "Craft" is `ButtonRed` and its Close `ButtonGreen`; the shop's Close is `ButtonGreen`; item and slot buttons are cream `Button`s (the equipped one `ButtonYellow`); the Gold label is `HudGold` on its panel's plain text colour, the selected tint stays `SELECTED_TINT`.
- Produces: unchanged public surfaces (`ShopScreen.activate`, `buy`, `equip`, `unequip`, `button_text`, `gold_text`, `message_text`, `input_guard_msec`; `CraftingScreen` public methods, `CraftingSession` untouched).

- [ ] **Step 1: Write the failing tests.** `test_shop_screen`: `test_the_longest_item_name_fits_its_button_without_clipping` (every catalog item's button text measured at `UiFont.SIZE` is no wider than the button minus its margins), `test_the_longest_description_wraps_inside_the_detail_area`, `test_the_close_button_is_green_and_the_equipped_item_is_yellow`. `test_crafting_screen`: `test_the_preview_and_drawbacks_fit_the_preview_panel` (craft the most buffed spell the test data allows and check the wrapped label height is within the panel), `test_the_craft_button_is_red_and_close_is_green`, `test_no_crafting_widget_sets_a_font_size`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.** Both screens move onto themed panels and replace their `_label`, `_button` and `_style` helpers with `UiKit`; `FONT_SIZE` constants and every `add_theme_*_override` are removed (focus is shown by the theme's `focus` stylebox). Long strings wrap. Buttons that clip text keep `clip_text` only where the test above proves the longest name fits.
- [ ] **Step 3: Run** both screens' tests, an MCP run of each screen with the longest items, then the whole suite. Expected: PASS.
- [ ] **Step 4: Commit** `feat: themed shop and crafting screens`.

---

### Task 9: Guards, performance, real-window checks and docs

**Files:**
- Create: `tests/test_ui_look.gd`
- Modify: `CLAUDE.md` (new section "Interface (Sprint 13d)", the Project State line, and the TEMPORARY mentions it removes), `README.md`, `technical-design.md`, `sprint-development.md` (13d ticks and a Built note, "Create UI elements" ticked), `development-log.md`, `sprint-13d-design.md` (Status: Built, plus a "Revision during the build" note per change of course)

**Interfaces:**
- Consumes: everything above. Produces nothing later tasks need.

- [ ] **Step 1: Write the failing guard tests in `tests/test_ui_look.gd`.** `test_no_ui_script_or_scene_sets_a_font_size` (scan `scripts/ui/*.gd` and `scenes/ui/*.tscn` for `font_size`), `test_no_ui_script_draws_with_the_fallback_font` (no `ThemeDB.fallback_font` use outside `UiFont`), `test_every_text_the_game_shows_is_ascii` (scan the `display_name`, `description` and message strings of `resources/**/*.tres`, and the string literals of `scripts/ui/*.gd`, for characters outside 32 to 126), `test_every_ui_scene_has_no_hand_set_stylebox` (no `theme_override_styles` in `scenes/ui`), `test_the_project_theme_is_the_game_theme` (`ProjectSettings.get_setting("gui/theme/custom")` equals the committed path), and `test_the_word_temp_appears_in_no_ui_text` (no `TEMP` label text in `scenes/ui` or `scripts/ui` strings). Run. Expected: FAIL only on what Tasks 5 to 8 missed; fix those and ledger each as a finding of the guard.
- [ ] **Step 2: Run the stress comparison** (`--enemies=300 --seconds=8 --drops --obstacles`, three runs, median) against the number on `main` (`git stash` is not needed: the number in Global Constraints is the baseline; also run once with `--boss`). Expected: within about 10%. If slower, profile damage numbers and bars first (the likely cost) and fix before continuing.
- [ ] **Step 3: Real-window checks** (scratchpad script, `save_path` empty, 3x scale): every HUD piece over grass, stone, a maze and a boss fight; each screen (death, shop, merchant, crafting with the biggest recipe, buff pick, inventory); a mouse click and a touch on a slot, a button and the shop item all act exactly once; a controller or keyboard focus walk through the shop and crafting. Save the screenshots in the scratchpad and describe them in the ledger. Delete the throwaway script by its exact path.
- [ ] **Step 4: Update the docs** and delete every "TEMPORARY" marker in `scripts/ui` that this sprint replaced (the markers on code that is still temporary, such as the debug keys, stay).
- [ ] **Step 5: Run** the whole suite and `godot --headless --quit-after 60`. Expected: PASS and no new warnings.
- [ ] **Step 6: Commit** `docs: Sprint 13d complete`.
