# Wraith store UI theme

`w_store/web/src/store.css` is the visual reference. `store-theme.css` contains reusable `wst-*` primitives using the same texture/font bytes. Source hashes are recorded in `.reports/store-theme-assets.json` at the resources root.

Use semantic classes for panels, headers, titles, buttons, tabs, cards, fields and decorative frames. A frame contains eight spans: `wst-fr-t`, `wst-fr-b`, `wst-fr-l`, `wst-fr-r`, `wst-fr-tl`, `wst-fr-tr`, `wst-fr-bl`, `wst-fr-br`. Keep it decorative and non-interactive. Preserve existing NUI requests, visibility and layout state.

Load the shared stylesheet after the application's generated styles. React resources retain this ordering through their build configuration. Small scoped adapters may map existing state classes to shared primitives. `store-theme-bridge.js` decorates legacy HTML interfaces using the body's `data-store-theme` profile without replacing their event handlers.

Panels, plates and close buttons deliberately do not impose a position. Retain existing absolute/fixed positioning; add `position: relative` locally only for static elements that need to contain their decorative pseudo-element. Never apply a broad positioning reset to HUD elements.

Texture custom properties use `https://cfx-nui-w_lib/nui/assets/store-theme/tex/` URLs so consuming stylesheets cannot resolve them against another resource. Fonts resolve directly from this stylesheet. The loading screen uses a local stylesheet copy and byte-identical assets in `w_loading/html/store-theme/`; after changing this shared file, update that copy and rewrite the texture prefix to `./store-theme/tex/`.

Useful browser checks at the resources root:

- .tools/test_store_theme_root.cjs
- .tools/test_store_theme_asset_panels.cjs
- .tools/verify_store_theme_five.cjs
- .reports/store-theme-shells-final.cjs

These checks simulate NUI messages. They do not replace an in-game RedM check.
