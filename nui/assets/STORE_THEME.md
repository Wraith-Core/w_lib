# Wraith store UI theme (wst-*)

`store-theme.css` provides the reusable `wst-*` primitives. They began as a copy of `w_store/web/src/store.css` and are now drawn in the Wraith theme: black and white (neutral ink and paper, r = g = b, the Wraith launcher's values; never a cream or warm tint), one red. The theme package in `../theme/` is described in `../theme/THEME.md`.

The file starts with `@import`s of `../theme/tokens.css` and `../theme/fonts.css`, and every colour in it is a `--w-*` token. So the 21 resources that link this sheet take the theme with no markup change and no rebuild. Asset hashes are recorded in `.reports/store-theme-assets.json` at the resources root.

## Classes

Use semantic classes for panels, headers, titles, buttons, tabs, cards, rows, plates, fields and decorative frames.

- A frame contains eight spans: `wst-fr-t`, `wst-fr-b`, `wst-fr-l`, `wst-fr-r`, `wst-fr-tl`, `wst-fr-tr`, `wst-fr-bl`, `wst-fr-br`. Keep it decorative and non-interactive.
- Preserve existing NUI requests, visibility and layout state.

## States

The cursor is the paper brushed band with ink text. That covers hover, `:focus-visible`, the active tab, and a selected card or row. There is no gold focus ring any more.

| Element | Rest | Under the cursor |
|---|---|---|
| Secondary button, tab, close | Paper-dim on an ink plate | The band, ink text |
| `.primary` button | The band | `--w-paper-lit` |
| `.danger` button | Paper text with a red underline | Red plate |

- `.wst-row.clickable` and a `.selected` row take the band.
- A plain row only lifts to `--w-ink-4`.
- A focused field gets a paper underline.

## Fonts

| Token | Latin | Arabic | Used by |
|---|---|---|---|
| `--wst-f-title` | EB Garamond 600 | Lalezar 400 | `.wst-title`, never Tajawal and never tracked in Arabic |
| `--wst-f-display` | RDR Lino | Lalezar | Wordmarks, and headings a resource set in the display face |
| `--wst-f-body` | Hapna Slab | Tajawal | The label face, for everything else. Latin controls are set in caps. |
| `--wst-f-num` | RDR Catalogue | RDR Catalogue | Numbers |

Arabic tokens for adapters that key on `lang` rather than `dir`:
- `--wst-f-ar`: the label face (unchanged meaning).
- `--wst-f-ar-label`, `--wst-f-ar-title`, `--wst-f-ar-display`, `--wst-f-ar-text`, `--wst-f-ar-action`.

A local adapter that forces `--wst-f-ar` onto a heading should switch it to `--wst-f-ar-title`.

## Load order and positioning

Load the shared stylesheet after the application's generated styles. React resources keep this order through their build configuration.

- Small scoped adapters may map existing state classes to shared primitives.
- `store-theme-bridge.js` decorates legacy HTML interfaces through the body's `data-store-theme` profile, without replacing their event handlers.

Panels, plates and close buttons deliberately do not impose a position. Keep existing absolute or fixed positioning. Add `position: relative` locally only to static elements that need to contain their decorative pseudo-element. Without it, a plate's `::before` covers its nearest positioned ancestor. Never apply a broad positioning reset to HUD elements.

## URLs

Texture custom properties use absolute `https://cfx-nui-w_lib/nui/theme/tex/` URLs, so consuming stylesheets cannot resolve them against another resource. Fonts resolve relative to `theme/fonts.css`.

The loading screen keeps its own local copy of the faces (byte-identical files in `w_loading/html/fonts`), because it runs before w_lib is downloaded. It does not use this sheet.

The old `nui/assets/store-theme/{fonts,tex}` folder is no longer referenced. Its files are byte-identical copies of those in `../theme/`.

## Checks

Run these at the resources root:

- `.tools/theme_shots.cjs`: screenshots and audit (see `../theme/THEME.md`).
- `.tools/test_store_theme_root.cjs`
- `.tools/test_store_theme_asset_panels.cjs`
- `.tools/verify_store_theme_five.cjs`
- `.tools/test_store_checkbox.cjs`
- `.tools/test_library_dialog_surfaces.cjs`
- `.tools/test_inventory_store_details.cjs`

These checks simulate NUI messages. They do not replace an in-game RedM check.
