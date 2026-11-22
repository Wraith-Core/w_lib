# w_lib

Unified UI, utility, and bridge library for **Wraith Framework RedM**.

`w_lib` powers every Wraith resource with one shared Red Dead paper-and-ink NUI frame, server/client callbacks, walk-up prompts, particle glow markers, object placer, database helpers, framework/inventory bridges, and live localization (`en` / `ar`).

## Key Features

- **Unified Interface:** Context menus (`lib.registerContext` / `lib.showContext`), input dialogs (`lib.inputDialog`), alert dialogs (`lib.alertDialog`), notifications (`lib.notify`), progress bars, radial menus, skill checks, text UI, and clipboard.
- **Callbacks & Hooks:** Async server/client callbacks (`w.callback.register` / `w.callback.await`).
- **World Helpers:** Native prompt groups (`w.prompt`, standardized on `J`), particle glow markers (`w.glow`), blips (`w.blip`), navigation (`w.navigation`), and 3D object placer (`w.placer`).
- **Database Exports:** Consistent `oxmysql` wrappers (`DbQuery`, `DbSingle`, `DbScalar`, `DbInsert`, `DbUpdate`, `DbTransaction`).
- **Framework & Inventory Bridges:** `Fw*`, `Inv*`, `Citizen*`, and `Door*` exports plus `w.framework` compatibility.
- **Quiet Console & Locales:** One clean startup banner per resource and built-in bilingual localization (`setr w_lib:locale "en"` or `"ar"`).

## Quick Start

Add `@w_lib/init.lua` as the first shared script in your resource's `fxmanifest.lua`:

```lua
lua54 'yes'
dependency 'w_lib'

shared_scripts {
    '@w_lib/init.lua',
}
```

## Requirements

- FXServer `14901+` (`rdr3`, OneSync enabled)
- `oxmysql`

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/core/w_lib
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe
- **Credits & Upstream Licenses:** See [CREDITS.md](CREDITS.md) and `LICENSES/`

## License

LGPL-3.0-or-later — see [CREDITS.md](CREDITS.md) for upstream attributions (`ox_lib`, `jo_libs`).
