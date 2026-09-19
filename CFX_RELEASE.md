# Cfx release preparation

## Current status

The English developer guide is `README.md`. Credits and the free-use statement are in `CREDITS.md`.

The production interface has been rebuilt in `web/build/`. Minification is explicitly enabled, source maps are disabled, and bundled license comments are preserved. The development sources remain in the workspace.

The sibling resources now contain the following exact Asset Escrow exemptions:

| Resource | Lua file left editable |
| --- | --- |
| w_map | shared/config.lua |
| w_baloot | config.lua |

These settings are instructions to Cfx. Editing a manifest does not encrypt local files; encryption happens when Cfx processes the uploaded resource. Download and test that processed version before distributing it.

**w_lib is not ready for an upload with every Lua file encrypted. Its manifest has not been changed to claim full protection.** Its current loading mechanism needs readable source files. The compatible-exemption option and a loader redesign are different release choices; neither has been silently applied to the library.

## Frontend files to distribute

For the unified interface, include `web/build/` and all of its contents. Keep the directory name and the resource name `w_lib` unchanged: the manifest and consumers reference `nui://w_lib/web/build/index.html`.

Do not put `web/src/`, `web/node_modules/`, development configuration, lockfiles, backups, or source maps into the runtime upload. Keep these in the private development workspace. Do not delete required license notices. Frontend source required by a third-party license must still be made available through a suitable source distribution; omitting it from the runtime ZIP does not remove that requirement.

The resource also declares assets under `html/dist/`. Preserve them when making a complete resource package. The old `nui/` tree is not declared by the current manifest and is not the unified interface build.

The `release/w_lib-ui-build.zip` archive contains the built frontend, integration guide, release instructions, credits, and license copies. It is an interface handoff archive, not a complete resource or a Cfx upload package.

Cfx currently does not protect NUI. The delivered HTML, CSS, JavaScript and browser assets remain accessible, including when minified. A production build reduces exposed development material; it is not encryption.

## Why full Lua encryption needs more work

The current library imports source dynamically:

- `init.lua` reads `imports/<module>/shared.lua` and client or server files, combines their source, then calls `load()` in each consuming resource.
- `init.lua` also reads and executes `w_init.lua`.
- `resource/init.lua` performs the same source-based import inside the library.
- `w_init.lua` reads scoped and global scripts under `modules/`.
- The file and require helpers read additional Lua data and adapters at runtime, including framework detectors and component data.
- Client settings are loaded through `require 'resource.settings'`.

An encrypted file cannot be treated as ordinary Lua source by these loaders. Encrypting these dynamically loaded files would therefore risk breaking both the library startup and scripts importing `@w_lib/init.lua`.

A compatibility release would need readable dynamically loaded files, including `w_init.lua`, `imports/**/*.lua`, `modules/**/*.lua`, and `resource/settings.lua`. The public `init.lua` adapter is included through resource manifests; its protection needs a separate test with a Cfx-processed resource and an assessment of its upstream license. Leaving the dynamic implementation readable would not satisfy a request to hide all library implementation. These paths are a compatibility assessment, not an applied or Cfx-tested release profile.

Protecting more of the implementation requires moving it behind functions executed by the native resource runtime and redesigning the consumer adapters. Resource ownership, per-resource state, callbacks, NUI routing, lazy dependencies, and module data loading all need validation. Simply replacing the source loader with an export is not equivalent.

## Credits and licensing

The checked-in code declares LGPL-3.0-or-later for ox_lib-derived files. The current jo_libs and ox_lib upstream repositories both publish LGPL-3.0 license texts. Preserve the applicable source notices, license texts, and corresponding-source requirements when distributing modified upstream work. The acknowledgements are not a replacement for those terms. A fully closed distribution of all derived code must not be assumed permissible merely because the resource is free.

The files in `LICENSES/` preserve the fetched upstream texts and the GPL text incorporated by LGPL. This is not a complete audit of every font, image, or frontend dependency, and does not change the existing manifest license.

## Validation before distributing a processed Cfx resource

1. Choose and implement a w_lib loading/protection strategy before submitting the full library.
2. Start the Cfx-processed version with oxmysql and the installed framework, followed by w_lib and its consumers.
3. Verify both client and server initialization with `@w_lib/init.lua`.
4. Exercise notifications, context menus, dialogs, progress, both callback families, and framework/database access.
5. Exercise a consumer using the library UI page and another using its own UI page. Check prompt, menu, gizmo and minigame routing where used.
6. Verify that only the intended config Lua file is readable in each processed sibling resource.

Production frontend compilation and static manifest checks were completed locally. Cfx encryption and an in-game RedM test were not performed in this preparation step.

## References

- [Cfx Asset Escrow: supported files, NUI limitations, upload steps, and escrow_ignore](https://docs.fivem.net/docs/server-manual/asset-escrow/)
- [ox_lib license](https://github.com/overextended/ox_lib/blob/main/LICENSE)
- [jo_libs license](https://github.com/Jump-On-Studios/RedM-jo_libs/blob/main/LICENSE)
- [GNU LGPL version 3](https://www.gnu.org/licenses/lgpl-3.0.html)
