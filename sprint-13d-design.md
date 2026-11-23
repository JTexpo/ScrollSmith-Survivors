# Sprint 13d Design: The Interface

**Status:** Built (Sprint 13d).

Sprint 13 is six parts: **13a** art foundation, **13b** the world, **13c** spells and equipment (all done), **13d** the interface (this doc), **13e** audio, **13f** polish. Scope comes from the conversation, `sprint-development.md`, `CLAUDE.md` and the art pipeline of 13a to 13c. Decisions below were agreed with the user in conversation, except where marked "my call".

## 1. Intent

The world now has the cartoon look, and the interface still looks like a prototype. Every label uses Godot's default font at 480x270, which blurs and washes out on grass and stone (Gold and the run clock are the worst), the health bar says "TEMP HP BAR", and 19 UI scenes and about 2,400 lines of scripts are marked TEMPORARY. 13d gives every HUD piece and screen **one whimsical, light, cartoony look** and a readable pixel font, and removes the placeholders. It changes how things look and not how they behave.

**Goals (user decisions)**
- **Light, cartoony, whimsical** (user).
- **The look (user, from mockups):** Candy's cream panels with a thick plum outline and rounded stepped corners, pink health and sky-blue XP bars, cream slot frames. The two buttons use Parchment's red (main action: Try again, Buy) and green (second action: Shop, Equip). Candy's sunny yellow stays for Gold, highlights and the selected slot.
- **A slim pixel font (user)**, because the game has a lot of numbers and stats to read (the crafting preview especially).
- **One Theme at the root (approach A, user):** panels, buttons, bars and slot frames are small 9-slice sprites built by the art pipeline, and one Godot `Theme` styles every screen, so a new screen looks right with no extra work.
- Text over the world (Gold, clock, damage numbers, toasts) readable on any background through an outline baked into the glyphs.
- No placeholder text left ("TEMP HP BAR" becomes a heart and a bar).

**Non-goals (later sprints)**
- Layout or flow changes. Bars, slots, toasts, the touch controls and every screen keep their positions and behaviour. Adding a confirm dialog to the shop is not here (it stays on the sprint 9 list).
- Sound (13e), screen transitions, animation polish and a settings or title screen (13f or later).
- Translating or localising text.

**Anti-goals** (a failure even if it technically works)
- Scaled pixels. Everything stays at the game's one pixel size: sprites and glyphs are never stretched, and a panel grows by tiling its slice, not by scaling.
- A restyle that changes input. Mouse, keyboard, controller focus and the touch bridge work exactly as before (the screens handle their own touches because mouse emulation is off, and that stays).
- A glyph missing from the font that draws as a box or nothing. Every character the game can print (letters, digits, punctuation, the symbols already used in text such as `x`, `+`, `%`, `/`, `:`, `!`) has a glyph.
- Text that spills out of its panel. The longest strings (item descriptions, drawbacks, the crafting preview) must fit or wrap inside their panels.
- Text drawn with the default font anywhere. A test fails if a UI scene uses no theme font.
- A look that makes something harder to read, such as a pale bar fill on a cream panel.

## 2. Approaches

- **A. One theme, own pixel font, sprite panels.** The font is drawn as glyph grids in the art pipeline with a baked outline, panels and buttons are 9-slice sprites, and one `Theme` applies everywhere. **Chosen by the user.** Cost: about 95 glyphs to draw (generated from code, then judged by eye).
- **B. A downloaded open-licence pixel font and per-screen styling.** Faster start, but a licence and a look to match, no baked outline, one fixed size, and every scene would carry its own styling. Not chosen.
- **C. Draw every control by hand in `_draw`.** Total control, but it discards Godot's focus, controller and touch handling that the crafting and shop screens depend on. Not chosen.

## 3. Decisions

| Area | Decision |
|---|---|
| Font | `art/fonts/` holds a glyph source (a `.font` text grid: glyph height, one block per character, the baseline and a per-glyph advance), built by the art tool into a PNG and a Godot `FontFile`, committed like every other output. **Slim, about 7 px tall with a 1 px baked outline** (my call: 5 px wide letters, a 1 px gap, descenders on g j p q y, lowercase and uppercase). A second, outline-free build exists for text inside panels, where the plum colour on cream needs no outline (my call: one grid, two builds, so the two never drift apart). The font is replaceable by overwriting its sheet, like a sprite (`hand_drawn`). |
| Palette | The palette limit rises from 64 to **96** colours with a UI section (cream, plum, pink, sky, red, green, yellow and their light and dark shades), as 13b raised it from 40 to 64 (my call: the world already sits at 63). The new colours are the user's chosen ones from the mockup. |
| UI sprites | `art/sprites/ui_*.sprite`, with the existing `tile` and `slice` markers: `ui_panel` (cream with a plum outline, the main panel), `ui_panel_dark` (for text-over-world pills), `ui_button_red`, `ui_button_green`, `ui_button_yellow` (each with `normal`, `hover`, `pressed`, `disabled` frames), `ui_slot` (a spell or potion slot and a selected variant), `ui_bar_back`, `ui_bar_hp`, `ui_bar_xp`, `ui_bar_boss`, and small icons (`icon_heart`, `icon_star`, `icon_coin`, `icon_scroll`, `icon_potion`). Panels and buttons are 9-slice, so a panel grows by tiling and never by stretching. |
| The Theme | One `resources/ui/game_theme.tres` built from those sprites (`StyleBoxTexture` with the slice margins): fonts, colours and styleboxes for `Panel`, `PanelContainer`, `Button` (normal, hover, pressed, disabled, focus), `Label`, `ProgressBar`, `ScrollContainer`, separators. Set once as `gui/theme/custom` in `project.godot`, so every `Control` inherits it. A role is a theme variation (`ButtonRed`, `ButtonGreen`, `Heading`, `Value`, `Muted`, `Warning`), not a per-scene override. |
| Existing UI | Each of the 19 scenes loses its hand-set colours and `font_size` overrides (62 of them) and uses the theme or a variation. Custom-drawn pieces (`SpellSlotWidget`, `PotionSlotWidget`, the bars, `DamageNumbers`, the toasts, the touch controls' buttons) draw with the same sprites and font. The health bar shows `icon_heart` and the bar. Floating text uses the outlined font. |
| Screens | Crafting, shop, merchant, death, buff pick and the inventory panel get panels and buttons from the theme. The longest text (descriptions, drawbacks, the crafting preview) wraps inside its panel. The prompts of Lecterns and points of interest and the interact and inventory buttons use the same look. |
| Rules that do not change | Input handling, pause, `TouchBridge`, `handle_event` taps on the death screen, focus order, the `mouse_filter` rules and every system the UI reads from. The UI still never mutates gameplay data. |

## 4. What is left to the builder
- Exact glyph shapes (judged by eye in a real window, redrawn on feedback), the exact stepped corner shapes and the sprite sizes.
- Which text uses the outlined build and which the plain one (floating text outlined, text inside panels plain).
- The theme variation names beyond those listed.
- Whether a very long string wraps or shortens (wrap first).

## 5. Verification plan
- A font test: every printable ASCII character the game prints has a glyph, the outlined build is the plain one plus an outline, and the committed sheet equals what the tool builds (stale-art test, as for sprites).
- A theme test: the committed theme equals what the tool builds, every `Control` type the game uses has a style, and no UI scene or script sets a font size or colour by hand (a grep-style test over `scenes/ui` and `scripts/ui`).
- Existing UI tests keep passing unchanged (behaviour did not change), plus text-fits tests for the longest strings.
- A real window check at 3x for every HUD piece and screen over grass, stone, a maze and the boss, with mouse and with touch, as in earlier sprints, and the stress scene to confirm the frame rate has not dropped (damage numbers and bars draw every frame).
- `godot --headless --import` after adding a `class_name`, then the full suite.

## 6. Revisions during the build

- The font source is `.pixelfont`, not `.font`: Godot imports every `.font` file as a BMFont.
- The theme tool reads frame sizes and slices from the `.sprite` sources, so the theme can be built before the sheets are imported (run `godot --headless --import` before and after the tool).
- The death screen has no "Try again" button (restart is the R key, a controller button or a tap anywhere else), so the Shop button is the green one.
- Extra sprites and variations: `ui_focus` (the focus ring), `ui_bar_back_thin` and a 2 px XP fill, `PanelSlot`, `PanelSlotSelected`, `HudToast` and a `Label` line spacing of 0.
- Layout nudges to fit the new font: the inventory panel is 260 by 214, merchant buttons are two lines, the crafting buff list is one column and its range column is 112 px wide.
