# w_lib Developer Documentation

Version 3.38.0. Wraith Studio.

w_lib is the shared library every Wraith resource is built on. It bundles a NUI interface layer (context menus, dialogs, notifications, text UI, menus, panels, progress bars, skill checks, radial menus, NUI prompts, gizmo, minigames), a framework bridge that hides the differences between VORP, RSG, QBR, RedEM and other cores, an inventory bridge that does the same for inventories, a callback system, localisation, and a large set of utility modules for Lua on both the client and the server.

This document describes the public surface of the library as seen from another resource. The library ships encrypted; nothing in this document requires reading its source.

## 4.1.5 (2026-11-01)

- إصلاح زر الاستسلام X: يرفع اللاعب يديه ويخفضهما، ويعرف السيرفر أنه مستسلم فيمكن تفتيشه وسرقته.

## 4.1.4 (2026-10-30)

- حماية طلبات الاستدعاء بميزانية لكل لاعب وحد للطلبات الجارية، ورفض الأسماء غير المسجلة فورًا.
- إنهاء سؤال العميل عند انقطاعه أو انتهاء المهلة، وتنظيف المستمع حتى لا تتراكم الطلبات.
- إصلاح قناة رفض الاستدعاء غير المسجل وإظهار عنوان «الإعدادات» بالعربية.
- مهلة سؤال العميل 15 ثانية افتراضيًا؛ يمكن ضبط `w_lib:clientCallbackTimeout` بين ثانية ودقيقتين.
- يلزم اختبار القوائم وطلبات التأكيد بعد إعادة تشغيل كاملة في وقت خلو السيرفر.

## 4.1.3 (2026-10-24)

- **سبب «القطيع» (توقف السيرفر) في ريد ريفر:** فحص صلاحية الأدمن في المكتبة كان ينسخ كائن النظام كله (w_core) في كل
  فحص، حوالي 30 ملي ثانية للفحص. لوحة الأدمن تفحص عشرات المرات، فيتوقف السيرفر ثانية أو أكثر. أداة القياس (profiler)
  أثبتت ذلك: 130 فحصًا في 30 ثانية = 1.7 ثانية توقف. صار الكائن يُجلب مرة واحدة ويُحفظ.

## 4.1.2 (2026-10-24)

- طلب المالك: «إذا جيت أحدد من فوق ما أعرف الحدود، تختفي». اللمعة نقاط صغيرة لا تظهرها اللعبة من الارتفاع، فصار للأشكال خيار
  `solid`: جدار شفاف ملوّن على طول السور أو المسار، أو دائرة مسطحة تحت النقطة، يُرى من أي مسافة (يراه اللاعب نفسه فقط).
  محررات الرسم من الأعلى تستعمله.

## 4.1.1 (2026-10-23)

- السور اللامع (اللمعة 5) صار **أطول** (ثلاثة صفوف: على الأرض، وفوقها بـ 80 سم، وبـ 160 سم)، و**أكثف** (لمعة كل نصف متر)،
  و**أكبر** (اللمعة مرة ونصف حجمها). حد اللمعات لكل سكربت صار 300 (كان 150)، فيظهر حوالي 50 مترًا من السور حول اللاعب.

## 4.1.0 (2026-10-23)

- **لمعة اللعبة بدل الدرو ماركر** (طلب المالك): وحدة جديدة `lib.glow` (`w.glow`) ترسم أشكالًا بلمعة اللعبة نفسها:
  السور `wall` (اللمعة 5)، والمسار `line` (1)، والنقطة `point` (2)، والسهم `arrow` (3)، والدائرة `circle` (4). أي شكل يأخذ أي لمعة.
- أداة وضع الأشياء (`w.placer`)، ونقاط الانتقال (essentials)، و`lib.marker` صارت ترسم باللمعة بدل الدرو ماركر.
- الأمر `/glow` يعرض الأشكال كلها أمام اللاعب، و`/glow wall 5` يعرض شكلًا واحدًا بلمعة معيّنة (دقيقة، يراه هو فقط).

## 4.0.4 (2026-10-17)

- مفتاح التفاعل الافتراضي صار J بدل E (أزرار التفاعل التي لا تحدد مفتاحًا، وزر «ضع» في أداة وضع الأشياء)، لأن E يمسك اللاعب القريب. وأداة الوضع تعطّل فعل J الأصلي في اللعبة أثناء العمل.

## 4.0.3 (2026-10-17)

- أخطاء السكربتات عند اللاعبين تُرسل إلى w_logs (قناة «أخطاء-العميل»): الخطأ نفسه مرة كل دقيقة، و5 تقارير في الدقيقة لكل سكربت كحد أقصى، ويبقى ظاهرًا في F8 كما كان. التفاصيل: w_logs/docs/client-error-hook.md.

## 4.0.2 (2026-10-17)

- قائمة w_lib (registerMenu / showMenu): مرور الفأرة فوق سطر يُضيئه بإطار فقط ولا يغيّر السطر المختار؛ Enter والأسهم تعمل على السطر المختار، والنقر يختار السطر وينفّذه كما كان.

## Quick start

### Requirements

- FXServer build 14901 or newer with OneSync enabled (declared by the library itself).
- Lua 5.4 in every consumer resource (`lua54 'yes'`). The loader refuses to run without it.
- `w_lib` must be started before any resource that uses it. Declare it as a dependency so the server enforces the order.
- `oxmysql` if you call the database exports (`Db*`) or use the offline framework helpers.

### Minimal manifest

```lua
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'my_resource'

-- The loader must be the first shared script.
shared_scripts {
    '@w_lib/init.lua',
    'config.lua',
}

client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }

-- Optional: modules loaded at start instead of on first use (see "Loading the library").
w_lib    { 'locale', 'callback' }   -- imports/ modules, exposed as lib.<name>
w_module { 'framework', 'menu' }    -- modules/ modules, exposed as w.<name>

-- Only when this resource draws w.* interfaces (w.menu, w.promptNui, w.input.nui, w.minigame, w.gizmo).
-- Not needed for lib.* interface calls, which are drawn by the library itself.
-- ui_page 'nui://w_lib/web/build/index.html'

dependency 'w_lib'
```

### What the loader gives you

After `@w_lib/init.lua` runs, every script in the resource has these globals:

| Global | What it is |
| --- | --- |
| `lib` | The ox_lib-compatible surface. `lib.<name>` is either a module from `imports/` (loaded on first access, runs inside your resource) or a proxy to an export of w_lib (runs inside w_lib). |
| `w` | The unified namespace. `w.<module>` resolves a module from `modules/` first (loaded on first access, runs inside your resource) and falls back to `lib` for everything else, so `w.notify`, `w.showContext` and `w.callback` all work. |
| `jo` | An alias of `w`, kept so resources written for jo_libs run unchanged. |
| `cache` | Per-resource cache of player state (`cache.ped`, `cache.vehicle`, `cache.seat`, `cache.mount`, `cache.weapon`, `cache.playerId`, `cache.serverId`, `cache.resource`, `cache.game`) kept up to date by the library, with `lib.onCache(key, cb)` to react to changes. |
| `require` | `lib.require`, a Lua-style module loader that reads files from your own resource. |
| `locale` | Available once `lib.locale()` has been called (or `'locale'` is listed under `w_lib {}`); translates keys from your `locales/<lang>.json`. |
| `SetInterval`, `ClearInterval`, `GetActivePlayers` (server) | Small helpers added to the global environment. |

### Two execution contexts

The single most important rule when reading the rest of this document:

- `lib.<name>` calls that are not an `imports/` module, and every `exports.w_lib:<Name>` call, cross the resource boundary and run inside w_lib. Arguments are serialised, so you cannot pass a function. Anything that needs a handler (`onSelect`, `onAction`, `onClose` and similar) takes the name of an event that you register in your own resource with `RegisterNetEvent` or `AddEventHandler`. Their interfaces are drawn by w_lib's own NUI frame; your resource does not need a `ui_page` for them.
- `w.<module>` calls run inside your resource. They accept real functions. Any of them that draws an interface (`w.menu`, `w.promptNui`, `w.input.nui`, `w.minigame`, `w.gizmo`, `w.clipboard`) draws into your resource's NUI frame, so your manifest must set `ui_page 'nui://w_lib/web/build/index.html'` unless you ship an interface of your own that hosts the library's app.

### A first example

Client:

```lua
-- client/main.lua
lib.locale()

lib.registerContext({
    id = 'my_resource:main',
    title = locale('menu_title'),
    options = {
        {
            title = 'Sell a horse',
            description = 'Opens the sale dialog',
            event = 'my_resource:client:sell',   -- an event name, not a function
        },
    },
})

RegisterNetEvent('my_resource:client:sell', function()
    local input = lib.inputDialog('Sell a horse', {
        { type = 'number', label = 'Price', required = true, min = 1 },
    })
    if not input then return end

    local ok, reason = lib.callback.await('my_resource:sell', false, input[1])
    if ok then
        lib.notify({ title = 'Sold', type = 'success' })
    else
        lib.notify({ title = 'Not sold', description = reason, type = 'error' })
    end
end)

lib.addKeybind({
    name = 'my_resource_menu',
    description = 'Open the menu',
    defaultKey = 'F6',
    onPressed = function()
        lib.showContext('my_resource:main')
    end,
})
```

Server:

```lua
-- server/main.lua
lib.callback.register('my_resource:sell', function(source, price)
    if type(price) ~= 'number' or price < 1 then
        return false, 'bad price'
    end

    -- currency type 0 is cash, 1 is gold (see the framework bridge section)
    local ok = exports.w_lib:FwAddCurrency(source, 0, price)
    return ok == true
end)
```

### How this document is organised

Each section below covers one part of the library. Within a section, every call has its signature, its side (client, server or shared), its parameters with every accepted field, its return value, a description and a short example. Events, convars and commands that belong to the section are listed in tables at its end.

## Contents

- [Loading the library, globals and lifecycle](#loading-the-library-globals-and-lifecycle)
  - [shared_script '@w_lib/init.lua'](#sharedscript-wlibinitlua)
  - [lua54 'yes'](#lua54-yes)
  - [dependency 'w_lib'](#dependency-wlib)
  - [dependencies { '/server:14901', '/onesync' }](#dependencies-server14901-onesync)
  - [w_lib { ... }](#wlib)
  - [w_module { ... }](#wmodule)
  - [ui_page 'nui://w_lib/web/build/index.html'](#uipage-nuiwlibwebbuildindexhtml)
  - [version 'x.y.z'](#version-xyz)
  - [package_id and dependencies_version_min](#packageid-and-dependenciesversionmin)
  - [lib](#lib)
  - [w and jo](#w-and-jo)
  - [cache](#cache)
  - [lib.onCache](#liboncache)
  - [exports.w_lib:cache](#exportswlibcache)
  - [require](#require)
  - [SetInterval and ClearInterval](#setinterval-and-clearinterval)
  - [GetActivePlayers](#getactiveplayers)
  - [Small helper globals](#small-helper-globals)
  - [w.ready](#wready)
  - [w.stopped](#wstopped)
  - [w.waitLibLoading](#wwaitlibloading)
  - [w.onResourceStart](#wonresourcestart)
  - [exports.w_lib:isResourceStarted](#exportswlibisresourcestarted)
  - [w.libLoaded, w.debug, w.debugModules, w.resourceName, w.context, w.isServerSide, w.isClientSide](#wlibloaded-wdebug-wdebugmodules-wresourcename-wcontext-wisserverside-wisclientside)
  - [w.require](#wrequire)
  - [w.isModuleLoaded](#wismoduleloaded)
  - [w.createModule](#wcreatemodule)
  - [exports.w_lib:loadGlobalModule](#exportswlibloadglobalmodule)
  - [w.async](#wasync)
  - [lib.checkDependency](#libcheckdependency)
  - [lib.versionCheck](#libversioncheck)
  - [w.resource.isConvarMatching](#wresourceisconvarmatching)
  - [w.versionChecker](#wversionchecker)
  - [exports.w_lib:StopAddon](#exportswlibstopaddon)
  - [lib.blockControl, lib.unblockControl and lib.isControlBlocked](#libblockcontrol-libunblockcontrol-and-libiscontrolblocked)
  - [lib.notify (server form)](#libnotify-server-form)
  - [exports.w_lib:hasLoaded](#exportswlibhasloaded)
  - [GlobalState['w_lib:locales']](#globalstatewliblocales)
  - [Entity(handle).state.w_entity_setonground](#entityhandlestatewentitysetonground)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Interface: notifications, dialogs, context menus, text UI, clipboard, sounds, NUI focus](#interface-notifications-dialogs-context-menus-text-ui-clipboard-sounds-nui-focus)
  - [Three notification systems](#three-notification-systems)
  - [Dialogs, menus, text UI, progress, sounds, clipboard, drawn text](#dialogs-menus-text-ui-progress-sounds-clipboard-drawn-text)
  - [lib.setNuiFocus](#libsetnuifocus)
  - [lib.resetNuiFocus](#libresetnuifocus)
  - [lib.notify (client)](#libnotify-client)
  - [lib.notify (server)](#libnotify-server)
  - [lib.defaultNotify](#libdefaultnotify)
  - [exports.w_lib:NotifyRaw](#exportswlibnotifyraw)
  - [w.notify](#wnotify)
  - [exports.w_lib:Notify and exports.w_lib:NotifyPlayer](#exportswlibnotify-and-exportswlibnotifyplayer)
  - [w.notif.* (client)](#wnotif-client)
  - [w.notif.* (server)](#wnotif-server)
  - [lib.alertDialog](#libalertdialog)
  - [lib.closeAlertDialog](#libclosealertdialog)
  - [lib.inputDialog](#libinputdialog)
  - [lib.closeInputDialog](#libcloseinputdialog)
  - [lib.registerContext](#libregistercontext)
  - [lib.showContext](#libshowcontext)
  - [lib.hideContext](#libhidecontext)
  - [lib.getOpenContextMenu](#libgetopencontextmenu)
  - [lib.showTextUI](#libshowtextui)
  - [lib.hideTextUI and lib.isTextUIOpen](#libhidetextui-and-libistextuiopen)
  - [lib.showProgress](#libshowprogress)
  - [lib.setProgress, lib.hideProgress and lib.drivenProgressActive](#libsetprogress-libhideprogress-and-libdrivenprogressactive)
  - [lib.playSound](#libplaysound)
  - [lib.setClipboard, w.clipboard.copy and exports.w_lib:clipboard_copy](#libsetclipboard-wclipboardcopy-and-exportswlibclipboardcopy)
  - [exports.w_lib:DrawText2D and w.drawText2D](#exportswlibdrawtext2d-and-wdrawtext2d)
  - [exports.w_lib:DrawText3D and w.drawText3D](#exportswlibdrawtext3d-and-wdrawtext3d)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Interface: menus, panels, progress bars, radial, skill check, voice UI, NUI prompt groups](#interface-menus-panels-progress-bars-radial-skill-check-voice-ui-nui-prompt-groups)
  - [How a consumer reaches this subsystem](#how-a-consumer-reaches-this-subsystem)
  - [Focus and one-frame rules](#focus-and-one-frame-rules)
  - [Progress](#progress)
  - [Things that are not what their names suggest](#things-that-are-not-what-their-names-suggest)
  - [lib.showPanel](#libshowpanel)
  - [lib.hidePanel and lib.panelActive](#libhidepanel-and-libpanelactive)
  - [lib.registerMenu](#libregistermenu)
  - [lib.showMenu](#libshowmenu)
  - [lib.hideMenu](#libhidemenu)
  - [lib.setMenuOptions and lib.getOpenMenu](#libsetmenuoptions-and-libgetopenmenu)
  - [lib.progressBar](#libprogressbar)
  - [lib.cancelProgress and lib.progressActive](#libcancelprogress-and-libprogressactive)
  - [lib.registerRadial](#libregisterradial)
  - [lib.addRadialItem](#libaddradialitem)
  - [lib.removeRadialItem and lib.clearRadialItems](#libremoveradialitem-and-libclearradialitems)
  - [lib.hideRadial, lib.disableRadial and lib.getCurrentRadialId](#libhideradial-libdisableradial-and-libgetcurrentradialid)
  - [exports.w_lib:CreateGroup](#exportswlibcreategroup)
  - [exports.w_lib:AddPrompt](#exportswlibaddprompt)
  - [exports.w_lib:Display, exports.w_lib:Hide and exports.w_lib:IsVisible](#exportswlibdisplay-exportswlibhide-and-exportswlibisvisible)
  - [exports.w_lib:IsCompleted](#exportswlibiscompleted)
  - [exports.w_lib:SetTitle and the SetPrompt* exports](#exportswlibsettitle-and-the-setprompt-exports)
  - [exports.w_lib:DeleteGroup](#exportswlibdeletegroup)
  - [exports.w_lib:SetNextPageKey](#exportswlibsetnextpagekey)
  - [w.promptNui.createGroup](#wpromptnuicreategroup)
  - [w.promptNui.isCompleted and w.promptNui.isDisplayed](#wpromptnuiiscompleted-and-wpromptnuiisdisplayed)
  - [GroupClass methods](#groupclass-methods)
  - [PromptClass methods](#promptclass-methods)
  - [lib.voicePanel](#libvoicepanel)
  - [lib.voiceHint](#libvoicehint)
  - [lib.hideVoiceHint](#libhidevoicehint)
  - [lib.voiceSubtitle](#libvoicesubtitle)
  - [lib.voiceListening](#libvoicelistening)
  - [lib.hideVoice](#libhidevoice)
  - [exports.w_lib:Notify](#exportswlibnotify)
  - [exports.w_lib:NotifyPlayer](#exportswlibnotifyplayer)
  - [w.ui.updateRank](#wuiupdaterank)
  - [w.ui timer: initTimer, startTimer, stopTimer, finishTimer](#wui-timer-inittimer-starttimer-stoptimer-finishtimer)
  - [lib.skillCheck, lib.cancelSkillCheck and lib.skillCheckActive](#libskillcheck-libcancelskillcheck-and-libskillcheckactive)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Localisation: lib.locale, locale files, getLocaleKey, setLocale, the i18n module](#localisation-liblocale-locale-files-getlocalekey-setlocale-the-i18n-module)
  - [Manifest setup: locales_path, files, w_lib { 'locale' }, w_lib_extra](#manifest-setup-localespath-files-wlib-locale-wlibextra)
  - [lib.locale](#liblocale)
  - [locale (global)](#locale-global)
  - [lib.getLocaleKey and exports.w_lib:getLocaleKey](#libgetlocalekey-and-exportswlibgetlocalekey)
  - [lib.setLocale and exports.w_lib:setLocale](#libsetlocale-and-exportswlibsetlocale)
  - [lib.getLocales](#libgetlocales)
  - [lib.getLocale and exports.<your_resource>:getLocale](#libgetlocale-and-exportsyourresourcegetlocale)
  - [GlobalState['w_lib:locales']](#globalstatewliblocales)
  - [w.i18n.__ and the global __](#wi18n-and-the-global)
  - [w.i18n.getLocale](#wi18ngetlocale)
  - [w.i18n.setLocale](#wi18nsetlocale)
  - [w.i18n.onLocaleChange and exports.w_lib:onLocaleChange](#wi18nonlocalechange-and-exportswlibonlocalechange)
  - [w.i18n.addEntry, w.i18n.addEntries, w.i18n.getEntries](#wi18naddentry-wi18naddentries-wi18ngetentries)
  - [w.i18n.loadLocale and w.i18n.init](#wi18nloadlocale-and-wi18ninit)
  - [w.i18n.findMissingKeys](#wi18nfindmissingkeys)
  - [i18n exports on w_lib and on consumer resources](#i18n-exports-on-wlib-and-on-consumer-resources)
  - [Library locale files: w_lib/locales and w_lib/locales_modules](#library-locale-files-wliblocales-and-wliblocalesmodules)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Callbacks, events, hooks and cross-resource communication](#callbacks-events-hooks-and-cross-resource-communication)
  - [The `lib.callback` family](#the-libcallback-family)
  - [The `w.callback` system](#the-wcallback-system)
  - [Event helpers and scoped modules](#event-helpers-and-scoped-modules)
  - [The `lib.hook` pipeline, game events and timing](#the-libhook-pipeline-game-events-and-timing)
  - [Debug output](#debug-output)
  - [manifest `w_module { 'hook' }`](#manifest-wmodule-hook)
  - [lib.callback.register (client)](#libcallbackregister-client)
  - [lib.callback.register (server)](#libcallbackregister-server)
  - [lib.callback.await (client)](#libcallbackawait-client)
  - [lib.callback.await (server)](#libcallbackawait-server)
  - [lib.callback (client)](#libcallback-client)
  - [lib.callback (server)](#libcallback-server)
  - [lib.setValidCallback and lib.isCallbackValid](#libsetvalidcallback-and-libiscallbackvalid)
  - [w.callback.register (client)](#wcallbackregister-client)
  - [w.callback.register (server)](#wcallbackregister-server)
  - [w.callback.registerCallback and w.callback.registerLatentCallback](#wcallbackregistercallback-and-wcallbackregisterlatentcallback)
  - [w.callback.triggerServer (client)](#wcallbacktriggerserver-client)
  - [w.callback.triggerClient (server)](#wcallbacktriggerclient-server)
  - [w.callback.triggerServer (server, local call)](#wcallbacktriggerserver-server-local-call)
  - [w.callback.triggerClient (client, local call)](#wcallbacktriggerclient-client-local-call)
  - [w.callback.trigger](#wcallbacktrigger)
  - [exports.w_lib:getCallbackAPI](#exportswlibgetcallbackapi)
  - [w.emit.triggerServer and w.emit.triggerServer.latent](#wemittriggerserver-and-wemittriggerserverlatent)
  - [w.emit.triggerClient and w.emit.triggerClient.latent (server)](#wemittriggerclient-and-wemittriggerclientlatent-server)
  - [w.emit.triggerServerWithSource](#wemittriggerserverwithsource)
  - [w.emit.isEventInProgress](#wemitiseventinprogress)
  - [w.emit.updateBps](#wemitupdatebps)
  - [lib.triggerClientEvent](#libtriggerclientevent)
  - [w.emit.triggerClient (client, deprecated)](#wemittriggerclient-client-deprecated)
  - [w.triggerEvent.server (deprecated)](#wtriggereventserver-deprecated)
  - [w.hook.registerAction](#whookregisteraction)
  - [w.hook.doActions](#whookdoactions)
  - [w.hook.registerFilter](#whookregisterfilter)
  - [w.hook.applyFilters](#whookapplyfilters)
  - [w.hook.applyServerFilters](#whookapplyserverfilters)
  - [exports.<resource>:registerAction](#exportsresourceregisteraction)
  - [exports.<resource>:registerFilter, RegisterAction, RegisterFilter](#exportsresourceregisterfilter-registeraction-registerfilter)
  - [w.hook.RegisterAction and w.hook.RegisterFilter (deprecated)](#whookregisteraction-and-whookregisterfilter-deprecated)
  - [lib.hook](#libhook)
  - [HookPipeline:dispatch](#hookpipelinedispatch)
  - [HookPipeline:registerHook and HookPipeline:remove](#hookpipelineregisterhook-and-hookpipelineremove)
  - [exports.<resource>:registerHook:<event> and removeHook:<event>](#exportsresourceregisterhookevent-and-removehookevent)
  - [lib.registerHook](#libregisterhook)
  - [EventHook:on, EventHook:off and EventHook:remove](#eventhookon-eventhookoff-and-eventhookremove)
  - [w.gameEvents.listen](#wgameeventslisten)
  - [w.waiter.exec](#wwaiterexec)
  - [w.promise.new](#wpromisenew)
  - [w.timeout.set](#wtimeoutset)
  - [w.timeout.loop](#wtimeoutloop)
  - [w.timeout.delay](#wtimeoutdelay)
  - [w.timeout.noSpam](#wtimeoutnospam)
  - [TimeoutClass methods](#timeoutclass-methods)
  - [lib.timer](#libtimer)
  - [OxTimer methods](#oxtimer-methods)
  - [lib.waitFor](#libwaitfor)
  - [lib.cron.new](#libcronnew)
  - [OxTask methods](#oxtask-methods)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Framework bridge exports (Fw*), permissions and ACL](#framework-bridge-exports-fw-permissions-and-acl)
  - [exports.w_lib:FwReady](#exportswlibfwready)
  - [exports.w_lib:FwName](#exportswlibfwname)
  - [exports.w_lib:FwInventory](#exportswlibfwinventory)
  - [exports.w_lib:FwGetCore](#exportswlibfwgetcore)
  - [exports.w_lib:FwGetPlayerData](#exportswlibfwgetplayerdata)
  - [exports.w_lib:FwGetUser](#exportswlibfwgetuser)
  - [exports.w_lib:FwGetCharacter](#exportswlibfwgetcharacter)
  - [exports.w_lib:FwGetCharacterData](#exportswlibfwgetcharacterdata)
  - [exports.w_lib:FwGetCharacterIdentifier](#exportswlibfwgetcharacteridentifier)
  - [exports.w_lib:FwGetIdentifier](#exportswlibfwgetidentifier)
  - [Character name getters](#character-name-getters)
  - [exports.w_lib:FwGetAge](#exportswlibfwgetage)
  - [Job getters](#job-getters)
  - [exports.w_lib:FwGetMoney](#exportswlibfwgetmoney)
  - [exports.w_lib:FwGetGold](#exportswlibfwgetgold)
  - [exports.w_lib:FwGetPlaytime](#exportswlibfwgetplaytime)
  - [exports.w_lib:FwAddCurrency](#exportswlibfwaddcurrency)
  - [exports.w_lib:FwRemoveCurrency](#exportswlibfwremovecurrency)
  - [exports.w_lib:FwSetJob](#exportswlibfwsetjob)
  - [exports.w_lib:FwSetJobLabel](#exportswlibfwsetjoblabel)
  - [exports.w_lib:FwSetJobGrade](#exportswlibfwsetjobgrade)
  - [Character field setters (online)](#character-field-setters-online)
  - [exports.w_lib:FwRevive, FwHeal, FwRespawn](#exportswlibfwrevive-fwheal-fwrespawn)
  - [exports.w_lib:FwKill](#exportswlibfwkill)
  - [exports.w_lib:FwGetInventoryItems](#exportswlibfwgetinventoryitems)
  - [exports.w_lib:FwGetInventoryWeapons](#exportswlibfwgetinventoryweapons)
  - [exports.w_lib:FwAddItem](#exportswlibfwadditem)
  - [exports.w_lib:FwRemoveItem](#exportswlibfwremoveitem)
  - [exports.w_lib:FwAddWeapon](#exportswlibfwaddweapon)
  - [exports.w_lib:FwRemoveWeapon](#exportswlibfwremoveweapon)
  - [exports.w_lib:FwCanCarryItem](#exportswlibfwcancarryitem)
  - [exports.w_lib:FwCanCarryWeapon](#exportswlibfwcancarryweapon)
  - [exports.w_lib:FwClearInventory](#exportswlibfwclearinventory)
  - [exports.w_lib:FwGetOfflineInventory](#exportswlibfwgetofflineinventory)
  - [exports.w_lib:FwAddItemOffline](#exportswlibfwadditemoffline)
  - [exports.w_lib:FwRemoveItemOffline](#exportswlibfwremoveitemoffline)
  - [exports.w_lib:FwAddWeaponOffline](#exportswlibfwaddweaponoffline)
  - [exports.w_lib:FwRemoveWeaponOffline](#exportswlibfwremoveweaponoffline)
  - [exports.w_lib:FwAddCurrencyOffline](#exportswlibfwaddcurrencyoffline)
  - [exports.w_lib:FwRemoveCurrencyOffline](#exportswlibfwremovecurrencyoffline)
  - [exports.w_lib:FwGetJobOffline](#exportswlibfwgetjoboffline)
  - [exports.w_lib:FwSetPlayerJobOffline](#exportswlibfwsetplayerjoboffline)
  - [exports.w_lib:FwSetJobFullOffline](#exportswlibfwsetjobfulloffline)
  - [exports.w_lib:FwSetJobLabelOffline and FwSetJobGradeOffline](#exportswlibfwsetjoblabeloffline-and-fwsetjobgradeoffline)
  - [exports.w_lib:FwRemoveJobOffline](#exportswlibfwremovejoboffline)
  - [Character field setters (offline)](#character-field-setters-offline)
  - [exports.w_lib:FwGetOfflineCharacters](#exportswlibfwgetofflinecharacters)
  - [exports.w_lib:FwGetDiscordId](#exportswlibfwgetdiscordid)
  - [exports.w_lib:FwGetCharactersWithDiscord](#exportswlibfwgetcharacterswithdiscord)
  - [Database statistics](#database-statistics)
  - [exports.w_lib:FwGetSharedItems, FwGetSharedWeapons, FwGetSharedJobs](#exportswlibfwgetshareditems-fwgetsharedweapons-fwgetsharedjobs)
  - [exports.w_lib:HasPermissionNode](#exportswlibhaspermissionnode)
  - [exports.w_lib:IsAdmin](#exportswlibisadmin)
  - [exports.w_lib:HasPermission](#exportswlibhaspermission)
  - [exports.w_lib:GetPlayerGroup](#exportswlibgetplayergroup)
  - [ACL helpers: lib.addAce, lib.removeAce, lib.addPrincipal, lib.removePrincipal](#acl-helpers-libaddace-libremoveace-libaddprincipal-libremoveprincipal)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Inventory bridge exports (Inv*), stash administration and the database helpers](#inventory-bridge-exports-inv-stash-administration-and-the-database-helpers)
  - [How the adapter is chosen](#how-the-adapter-is-chosen)
  - [Calling rules and gotchas](#calling-rules-and-gotchas)
  - [Stash sources](#stash-sources)
  - [Database helpers](#database-helpers)
  - [exports.w_lib:InvName (server)](#exportswlibinvname-server)
  - [exports.w_lib:InvRegisterUsableItem](#exportswlibinvregisterusableitem)
  - [exports.w_lib:InvGetItemCount](#exportswlibinvgetitemcount)
  - [exports.w_lib:InvCanCarry](#exportswlibinvcancarry)
  - [exports.w_lib:InvAddItem](#exportswlibinvadditem)
  - [exports.w_lib:InvRemoveItem](#exportswlibinvremoveitem)
  - [exports.w_lib:InvGetItems](#exportswlibinvgetitems)
  - [exports.w_lib:InvGetSlot](#exportswlibinvgetslot)
  - [exports.w_lib:InvRegisterStash](#exportswlibinvregisterstash)
  - [exports.w_lib:InvOpenStash](#exportswlibinvopenstash)
  - [exports.w_lib:InvAddItemToStash](#exportswlibinvadditemtostash)
  - [exports.w_lib:InvCreateStash](#exportswlibinvcreatestash)
  - [Client exports: InvName, InvItemLabel, InvClose](#client-exports-invname-invitemlabel-invclose)
  - [exports.w_lib:InvListStashes](#exportswlibinvliststashes)
  - [exports.w_lib:InvGetStashContents](#exportswlibinvgetstashcontents)
  - [exports.w_lib:InvStashAddItem](#exportswlibinvstashadditem)
  - [exports.w_lib:InvStashRemoveItem](#exportswlibinvstashremoveitem)
  - [exports.w_lib:DbReady](#exportswlibdbready)
  - [exports.w_lib:DbQuery](#exportswlibdbquery)
  - [exports.w_lib:DbSingle, DbScalar, DbInsert, DbUpdate](#exportswlibdbsingle-dbscalar-dbinsert-dbupdate)
  - [exports.w_lib:DbTransaction](#exportswlibdbtransaction)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [The w.framework module (framework and inventory abstraction used inside consumer resources)](#the-wframework-module-framework-and-inventory-abstraction-used-inside-consumer-resources)
  - [Loading](#loading)
  - [Detection](#detection)
  - [Loading order and the _custom override layer](#loading-order-and-the-custom-override-layer)
  - [Server/client split](#serverclient-split)
  - [Character lifecycle and inventory listeners](#character-lifecycle-and-inventory-listeners)
  - [Skins and clothes (VORP adapter)](#skins-and-clothes-vorp-adapter)
  - [The exports.w_lib:Fw* layer](#the-exportswlibfw-layer)
  - [w.framework (module table and fields)](#wframework-module-table-and-fields)
  - [w.framework:getFrameworkDetected](#wframeworkgetframeworkdetected)
  - [w.framework:get and w.framework:is](#wframeworkget-and-wframeworkis)
  - [w.framework:getUser](#wframeworkgetuser)
  - [w.framework.UserClass](#wframeworkuserclass)
  - [w.framework.UserClass:canBuy](#wframeworkuserclasscanbuy)
  - [Per-source shortcuts: getUserIdentifiers, getJob, getRPName, addMoney, removeMoney](#per-source-shortcuts-getuseridentifiers-getjob-getrpname-addmoney-removemoney)
  - [w.framework:canUserBuy](#wframeworkcanuserbuy)
  - [w.framework:canUserPayWith](#wframeworkcanuserpaywith)
  - [w.framework:refundUserWith](#wframeworkrefunduserwith)
  - [w.framework:canUseItem](#wframeworkcanuseitem)
  - [w.framework:removeItem](#wframeworkremoveitem)
  - [w.framework:getItemCount](#wframeworkgetitemcount)
  - [w.framework:giveItem](#wframeworkgiveitem)
  - [w.framework:registerUseItem](#wframeworkregisteruseitem)
  - [w.framework:listenItemRemoved](#wframeworklistenitemremoved)
  - [w.framework:onCharacterSelected](#wframeworkoncharacterselected)
  - [w.framework:getSourceFromIdentifiers](#wframeworkgetsourcefromidentifiers)
  - [w.framework:getMyIdentifiers](#wframeworkgetmyidentifiers)
  - [w.framework:getItems](#wframeworkgetitems)
  - [w.framework:getItemData](#wframeworkgetitemdata)
  - [w.framework:addItemDataToPrice](#wframeworkadditemdatatoprice)
  - [w.framework:createInventory](#wframeworkcreateinventory)
  - [w.framework:openInventory](#wframeworkopeninventory)
  - [w.framework:addItemInInventory](#wframeworkadditemininventory)
  - [w.framework:removeInventory](#wframeworkremoveinventory)
  - [w.framework:getItemsFromInventory](#wframeworkgetitemsfrominventory)
  - [w.framework:mergeInventoriesConfiguration](#wframeworkmergeinventoriesconfiguration)
  - [w.framework:getUserSkin](#wframeworkgetuserskin)
  - [w.framework:getUserClothes](#wframeworkgetuserclothes)
  - [w.framework:updateUserSkin](#wframeworkupdateuserskin)
  - [w.framework:updateUserClothes](#wframeworkupdateuserclothes)
  - [w.framework:standardizeSkin and w.framework:revertSkin](#wframeworkstandardizeskin-and-wframeworkrevertskin)
  - [w.framework:standardizeClothes and w.framework:revertClothes](#wframeworkstandardizeclothes-and-wframeworkrevertclothes)
  - [w.framework:convertToPercent and w.framework:extractComponentHashIfAlone](#wframeworkconverttopercent-and-wframeworkextractcomponenthashifalone)
  - [w.framework:createUser](#wframeworkcreateuser)
  - [w.framework:getInventoryItems and exports.w_lib:w_framework_getInventoryItems](#wframeworkgetinventoryitems-and-exportswlibwframeworkgetinventoryitems)
  - [w.framework:loadCoreFiles and w.framework:loadInventoryFiles](#wframeworkloadcorefiles-and-wframeworkloadinventoryfiles)
  - [The Inv* inventory bridge exports](#the-inv-inventory-bridge-exports)
  - [The Fw* export bridge: detection and raw access](#the-fw-export-bridge-detection-and-raw-access)
  - [Fw* online character getters](#fw-online-character-getters)
  - [Fw* online setters, currency and health](#fw-online-setters-currency-and-health)
  - [Fw* online item and weapon operations](#fw-online-item-and-weapon-operations)
  - [Fw* offline (database) operations](#fw-offline-database-operations)
  - [Fw* server-wide statistics and shared definitions](#fw-server-wide-statistics-and-shared-definitions)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [The w.citizen module (one citizen id for every player target)](#the-wcitizen-module-one-citizen-id-for-every-player-target)
  - [What can be typed](#what-can-be-typed)
  - [The target table](#the-target-table)
  - [Where the answer comes from](#where-the-answer-comes-from)
  - [w.citizen.resolve](#wcitizenresolve)
  - [w.citizen.requireOnline](#wcitizenrequireonline)
  - [w.citizen.fromSource and w.citizen.idOf](#wcitizenfromsource-and-wcitizenidof)
  - [w.citizen.normalize and w.citizen.parse](#wcitizennormalize-and-wcitizenparse)
  - [w.citizen.label](#wcitizenlabel)
  - [w.citizen.reasonKey, w.citizen.reasonText and w.citizen.text](#wcitizenreasonkey-wcitizenreasontext-and-wcitizentext)
  - [w.citizen.myId and w.citizen.inputRow (client)](#wcitizenmyid-and-wcitizeninputrow-client)
  - [exports.w_lib:Citizen* (resources without the loader)](#exportswlibcitizen-resources-without-the-loader)
  - [Patterns](#patterns)
- [The w.settings module (live settings edited from the admin console)](#the-wsettings-module-live-settings-edited-from-the-admin-console)
  - [Opting in](#opting-in)
  - [w.settings.define](#wsettingsdefine)
  - [Fields and columns](#fields-and-columns)
  - [Texts](#texts)
  - [The three exports](#the-three-exports)
  - [Storage, boot and drift](#storage-boot-and-drift)
  - [The client side](#the-client-side)
  - [Validation helpers](#validation-helpers)
  - [Safe mode and the console command](#safe-mode-and-the-console-command)
- [Shared utility modules under lib.* (data structures, strings, math, classes, commands, logging)](#shared-utility-modules-under-lib-data-structures-strings-math-classes-commands-logging)
  - [How these utilities reach a consumer resource](#how-these-utilities-reach-a-consumer-resource)
  - [Name collisions and which version wins](#name-collisions-and-which-version-wins)
  - [Classes and containers](#classes-and-containers)
  - [Loading code and data](#loading-code-and-data)
  - [Console, logs, commands, database](#console-logs-commands-database)
  - [Manifest setup](#manifest-setup)
  - [lib.require, lib.load and lib.loadJson](#librequire-libload-and-libloadjson)
  - [lib.print](#libprint)
  - [Global console helpers: log, sprint, eprint, gprint, oprint, wprint, bprint](#global-console-helpers-log-sprint-eprint-gprint-oprint-wprint-bprint)
  - [dprint](#dprint)
  - [lib.class](#libclass)
  - [lib.array](#libarray)
  - [lib.map](#libmap)
  - [lib.set](#libset)
  - [lib.heap](#libheap)
  - [lib.lru](#liblru)
  - [lib.ringbuffer](#libringbuffer)
  - [table.* helpers](#table-helpers)
  - [string.* helpers](#string-helpers)
  - [math.* helpers](#math-helpers)
  - [lib.addCommand](#libaddcommand)
  - [lib.logger](#liblogger)
  - [w.database](#wdatabase)
  - [w.bucket.getPlayersInBucket](#wbucketgetplayersinbucket)
  - [lib.grid](#libgrid)
  - [lib.selector](#libselector)
  - [lib.uuid](#libuuid)
  - [DataView (lib.dataview, shared)](#dataview-libdataview-shared)
  - [w.file](#wfile)
  - [w.date](#wdate)
  - [lib.getFilesInDirectory](#libgetfilesindirectory)
  - [lib.__addCommand (deprecated)](#libaddcommand-deprecated)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Client world helpers under lib.* (entities, streaming, keybinds, zones, points, raycast, markers, DUI, scaleform, vehicles)](#client-world-helpers-under-lib-entities-streaming-keybinds-zones-points-raycast-markers-dui-scaleform-vehicles)
  - [How these helpers reach a consumer resource](#how-these-helpers-reach-a-consumer-resource)
  - [Entity wrappers and statebags](#entity-wrappers-and-statebags)
  - [Points and zones](#points-and-zones)
  - [Keys](#keys)
  - [Streaming, raycast, markers, DUI, scaleform](#streaming-raycast-markers-dui-scaleform)
  - [lib.gameEntity](#libgameentity)
  - [GameEntity:set](#gameentityset)
  - [GameEntity:setr](#gameentitysetr)
  - [GameEntity:sets](#gameentitysets)
  - [GameEntity:get, has, keys](#gameentityget-has-keys)
  - [GameEntity:setHandle](#gameentitysethandle)
  - [GameEntity position, model and heading helpers](#gameentity-position-model-and-heading-helpers)
  - [GameEntity:getRoutingBucket](#gameentitygetroutingbucket)
  - [GameEntity:setRoutingBucket](#gameentitysetroutingbucket)
  - [lib.ped:new](#libpednew)
  - [lib.ped.create (client)](#libpedcreate-client)
  - [lib.ped.create (server)](#libpedcreate-server)
  - [Ped:getArmour, Ped:setArmour](#pedgetarmour-pedsetarmour)
  - [lib.prop:new](#libpropnew)
  - [lib.prop.create (client)](#libpropcreate-client)
  - [lib.prop.create (server)](#libpropcreate-server)
  - [Prop:setOnGround](#propsetonground)
  - [lib.vehicle:new](#libvehiclenew)
  - [lib.vehicle.create (client)](#libvehiclecreate-client)
  - [lib.vehicle.create (server)](#libvehiclecreate-server)
  - [Vehicle:getType, getPlate, setPlate](#vehiclegettype-getplate-setplate)
  - [Vehicle:setOnGround](#vehiclesetonground)
  - [lib.player:new](#libplayernew)
  - [Player:setModel](#playersetmodel)
  - [Player:getRoutingBucket](#playergetroutingbucket)
  - [Player:setRoutingBucket](#playersetroutingbucket)
  - [lib.getClosestObject, lib.getClosestPed, lib.getClosestVehicle](#libgetclosestobject-libgetclosestped-libgetclosestvehicle)
  - [lib.getClosestPlayer (client)](#libgetclosestplayer-client)
  - [lib.getClosestPlayer (server)](#libgetclosestplayer-server)
  - [lib.getNearbyObjects, lib.getNearbyPeds, lib.getNearbyVehicles](#libgetnearbyobjects-libgetnearbypeds-libgetnearbyvehicles)
  - [lib.getNearbyPlayers (client)](#libgetnearbyplayers-client)
  - [lib.getNearbyPlayers (server)](#libgetnearbyplayers-server)
  - [lib.getRelativeCoords](#libgetrelativecoords)
  - [lib.request* helpers](#librequest-helpers)
  - [lib.streamingRequest](#libstreamingrequest)
  - [lib.playAnim](#libplayanim)
  - [lib.addKeybind](#libaddkeybind)
  - [CKeybind methods](#ckeybind-methods)
  - [lib.rawKeys.listen](#librawkeyslisten)
  - [lib.rawKeys.removeListener, lib.rawKeys.getVK](#librawkeysremovelistener-librawkeysgetvk)
  - [lib.disableControls](#libdisablecontrols)
  - [lib.points.new](#libpointsnew)
  - [CPoint:remove](#cpointremove)
  - [lib.points.getAllPoints, getNearbyPoints, getClosestPoint](#libpointsgetallpoints-getnearbypoints-getclosestpoint)
  - [lib.zones.poly](#libzonespoly)
  - [lib.zones.box](#libzonesbox)
  - [lib.zones.sphere](#libzonessphere)
  - [CZone:contains](#czonecontains)
  - [CZone:remove](#czoneremove)
  - [CZone:setDebug](#czonesetdebug)
  - [lib.zones.getAllZones, getCurrentZones, getNearbyZones](#libzonesgetallzones-getcurrentzones-getnearbyzones)
  - [lib.raycast.fromCoords](#libraycastfromcoords)
  - [lib.raycast.fromCamera](#libraycastfromcamera)
  - [lib.glow (the game's glitter as shapes)](#libglow-the-games-glitter-as-shapes)
  - [lib.marker.new](#libmarkernew)
  - [Marker:draw](#markerdraw)
  - [lib.dui:new](#libduinew)
  - [Dui methods](#dui-methods)
  - [lib.scaleform:new](#libscaleformnew)
  - [Scaleform:callMethod](#scaleformcallmethod)
  - [Scaleform:setFullScreen, setProperties, setRenderTarget](#scaleformsetfullscreen-setproperties-setrendertarget)
  - [Scaleform:draw, startDrawing, stopDrawing, isDrawing, dispose](#scaleformdraw-startdrawing-stopdrawing-isdrawing-dispose)
  - [lib.getVehicleProperties](#libgetvehicleproperties)
  - [lib.setVehicleProperties (client)](#libsetvehicleproperties-client)
  - [lib.setVehicleProperties (server)](#libsetvehicleproperties-server)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Client modules under w.* (animation, blips, camera, entities, gizmo, lights, minigames, NUI, input, native prompts, raw keys, screen, player, me, debugger)](#client-modules-under-w-animation-blips-camera-entities-gizmo-lights-minigames-nui-input-native-prompts-raw-keys-screen-player-me-debugger)
  - [How these modules reach the consumer resource](#how-these-modules-reach-the-consumer-resource)
  - [w.player fields and w.player()](#wplayer-fields-and-wplayer)
  - [w.player.forceUpdate](#wplayerforceupdate)
  - [w.player.move](#wplayermove)
  - [w.player.didMoveSinceLastCall](#wplayerdidmovesincelastcall)
  - [w.player.instanceChanged (client)](#wplayerinstancechanged-client)
  - [w.player.instanceChanged (server)](#wplayerinstancechanged-server)
  - [w.me, w.meCoords, w.mePlayerId, w.meServerId, w.meIsMale](#wme-wmecoords-wmeplayerid-wmeserverid-wmeismale)
  - [w.forceUpdateMe and w.updateMeTimer](#wforceupdateme-and-wupdatemetimer)
  - [w.prompt.create](#wpromptcreate)
  - [w.prompt.displayGroup](#wpromptdisplaygroup)
  - [w.prompt.isCompleted](#wpromptiscompleted)
  - [w.prompt.deleteGroup and w.prompt.deleteAllGroups](#wpromptdeletegroup-and-wpromptdeleteallgroups)
  - [w.prompt.setEnabled, setVisible, isEnabled, isVisible, isActive](#wpromptsetenabled-setvisible-isenabled-isvisible-isactive)
  - [w.prompt.editKeyLabel and w.prompt.getKeyLabel](#wprompteditkeylabel-and-wpromptgetkeylabel)
  - [w.prompt.isPressed and w.prompt.waitRelease](#wpromptispressed-and-wpromptwaitrelease)
  - [w.prompt.doesLastCompletedIs](#wpromptdoeslastcompletedis)
  - [w.prompt.getProgress](#wpromptgetprogress)
  - [w.prompt.delete](#wpromptdelete)
  - [w.prompt.isGroupExist and w.prompt.isExist](#wpromptisgroupexist-and-wpromptisexist)
  - [w.prompt.get, getGroup, getPage, getAll, setGroups](#wpromptget-getgroup-getpage-getall-setgroups)
  - [exports.w_lib:w_prompt_get](#exportswlibwpromptget)
  - [w.entity.create](#wentitycreate)
  - [w.entity.delete](#wentitydelete)
  - [w.entity.fadeIn, w.entity.fadeOut, w.entity.fadeAndDelete](#wentityfadein-wentityfadeout-wentityfadeanddelete)
  - [w.entity.requestControl](#wentityrequestcontrol)
  - [w.entity.getEntityInCrosshair](#wentitygetentityincrosshair)
  - [w.entity.createWithMouse](#wentitycreatewithmouse)
  - [w.entity.deleteScenariosFromEntity](#wentitydeletescenariosfromentity)
  - [w.animation.play](#wanimationplay)
  - [w.animation.easeIn and w.animation.easeOut](#wanimationeasein-and-wanimationeaseout)
  - [w.animation.load](#wanimationload)
  - [w.animation.goToCoords](#wanimationgotocoords)
  - [w.animation.setDesiredHeading and w.animation.faceEntity](#wanimationsetdesiredheading-and-wanimationfaceentity)
  - [w.animation.waitTaskEnd](#wanimationwaittaskend)
  - [w.blip.create](#wblipcreate)
  - [w.screen.fadeOut and w.screen.fadeIn](#wscreenfadeout-and-wscreenfadein)
  - [w.utils.loadGameData and w.utils.releaseGameData](#wutilsloadgamedata-and-wutilsreleasegamedata)
  - [w.utils.waiter](#wutilswaiter)
  - [w.utils.screenToWorld](#wutilsscreentoworld)
  - [w.utils.convertToTable](#wutilsconverttotable)
  - [w.light.create](#wlightcreate)
  - [Light methods](#light-methods)
  - [w.camera.freeCamera.start](#wcamerafreecamerastart)
  - [w.camera.freeCamera.stop](#wcamerafreecamerastop)
  - [w.camera.freeCamera helpers](#wcamerafreecamera-helpers)
  - [w.gizmo.moveEntity](#wgizmomoveentity)
  - [w.gizmo.cancel](#wgizmocancel)
  - [w.placer.run](#wplacerrun)
  - [w.placer.cancel, w.placer.isActive and w.placer.canStart](#wplacercancel-wplacerisactive-and-wplacercanstart)
  - [w.minigame.lockpick](#wminigamelockpick)
  - [w.minigame.qte](#wminigameqte)
  - [w.minigame.cancel](#wminigamecancel)
  - [w.nui.isHovering](#wnuiishovering)
  - [w.nui.resetFocus](#wnuiresetfocus)
  - [w.nui.load, w.nui.isLoaded, w.nui.forceFocus](#wnuiload-wnuiisloaded-wnuiforcefocus)
  - [NUI hovering exports](#nui-hovering-exports)
  - [w.input.native](#winputnative)
  - [w.input.nui](#winputnui)
  - [w.input.loadNUI](#winputloadnui)
  - [w.rawKeys.listen](#wrawkeyslisten)
  - [w.rawKeys.removeListener and w.rawKeys.remove](#wrawkeysremovelistener-and-wrawkeysremove)
  - [w.rawKeys.bind](#wrawkeysbind)
  - [w.rawKeys.getBind](#wrawkeysgetbind)
  - [w.rawKeys lookup helpers](#wrawkeys-lookup-helpers)
  - [w.pedTexture.apply](#wpedtextureapply)
  - [w.pedTexture.remove, refreshAll, refreshNow](#wpedtextureremove-refreshall-refreshnow)
  - [w.pedTexture.overwriteBodyPart](#wpedtextureoverwritebodypart)
  - [w.pedTexture.getAll and w.pedTexture.getOverlayAssetFromId](#wpedtexturegetall-and-wpedtexturegetoverlayassetfromid)
  - [w.pedTexture.variations, categories, ordersToApply](#wpedtexturevariations-categories-orderstoapply)
  - [exports.w_lib:w_pedTexture_get](#exportswlibwpedtextureget)
  - [w.debugger.resetText and w.debugger.drawText](#wdebuggerresettext-and-wdebuggerdrawtext)
  - [w.debugger.drawSphere](#wdebuggerdrawsphere)
  - [w.debugger.perfomance and w.debugger.perfomanceRepeat](#wdebuggerperfomance-and-wdebuggerperfomancerepeat)
  - [DataView (dataview module, client)](#dataview-dataview-module-client)
  - [bigInt](#bigint)
  - [Player and me exports](#player-and-me-exports)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)
- [Logic modules under w.* (menu, pricing, component/clothing, version checker)](#logic-modules-under-w-menu-pricing-componentclothing-version-checker)
  - [How these modules reach a consumer resource](#how-these-modules-reach-a-consumer-resource)
  - [w.menu.create](#wmenucreate)
  - [w.menu.createIfNotExist](#wmenucreateifnotexist)
  - [MenuClass:addItem](#menuclassadditem)
  - [MenuItem.sliders](#menuitemsliders)
  - [MenuItem.onClickClientEvent / onClickServerEvent](#menuitemonclickclientevent-onclickserverevent)
  - [MenuClass:send](#menuclasssend)
  - [w.menu.setCurrentMenu](#wmenusetcurrentmenu)
  - [MenuClass:use](#menuclassuse)
  - [w.menu.show](#wmenushow)
  - [w.menu.isOpen](#wmenuisopen)
  - [w.menu.addItem](#wmenuadditem)
  - [w.menu by-id wrappers (send, refresh, reset, sort, updateItem, addItems)](#wmenu-by-id-wrappers-send-refresh-reset-sort-updateitem-additems)
  - [MenuClass:updateValue](#menuclassupdatevalue)
  - [MenuClass:deleteValue](#menuclassdeletevalue)
  - [MenuClass:deleteItem](#menuclassdeleteitem)
  - [MenuClass:push](#menuclasspush)
  - [MenuClass:refresh](#menuclassrefresh)
  - [MenuClass:setCurrentIndex](#menuclasssetcurrentindex)
  - [MenuClass:reset](#menuclassreset)
  - [MenuClass:sort](#menuclasssort)
  - [MenuClass:updateItem (deprecated)](#menuclassupdateitem-deprecated)
  - [MenuClass:removeItem (deprecated)](#menuclassremoveitem-deprecated)
  - [MenuClass:addItems (deprecated)](#menuclassadditems-deprecated)
  - [MenuItem methods (updateValue, deleteValue, getParentMenu)](#menuitem-methods-updatevalue-deletevalue-getparentmenu)
  - [w.menu.delete](#wmenudelete)
  - [w.menu.isExist](#wmenuisexist)
  - [w.menu.get / w.menu.set](#wmenuget-wmenuset)
  - [Current-state queries (getCurrentData, getPreviousData, getCurrentItem, getCurrentMenu, getCurrentIndex, getCurrentMenuId, isCurrentMenu, doesActiveButtonChange)](#current-state-queries-getcurrentdata-getpreviousdata-getcurrentitem-getcurrentmenu-getcurrentindex-getcurrentmenuid-iscurrentmenu-doesactivebuttonchange)
  - [w.menu.missingMenuHandler](#wmenumissingmenuhandler)
  - [w.menu.onChange / w.menu.listeners](#wmenuonchange-wmenulisteners)
  - [w.menu.fireEvent / w.menu.fireAllLevelsEvent](#wmenufireevent-wmenufirealllevelsevent)
  - [w.menu.runRefreshEvents](#wmenurunrefreshevents)
  - [w.menu.forceBack](#wmenuforceback)
  - [w.menu.softHide / w.menu.isSoftHidden](#wmenusofthide-wmenuissofthidden)
  - [w.menu.displayLoader / w.menu.hideLoader](#wmenudisplayloader-wmenuhideloader)
  - [w.menu.updateLang](#wmenuupdatelang)
  - [w.menu.updateVolume / w.menu.playAudio](#wmenuupdatevolume-wmenuplayaudio)
  - [Menu price helpers (formatPrice, formatPrices, isPriceFree, mergePrices, tax)](#menu-price-helpers-formatprice-formatprices-ispricefree-mergeprices-tax)
  - [exports.<resource>:w_menu_get / w_menu_get_current_data](#exportsresourcewmenuget-wmenugetcurrentdata)
  - [w.pricing.new](#wpricingnew)
  - [w.pricing.newGroup](#wpricingnewgroup)
  - [w.pricing.getCosts](#wpricinggetcosts)
  - [w.pricing.tax](#wpricingtax)
  - [w.pricing.isPrice / w.pricing.isPriceGroup](#wpricingisprice-wpricingispricegroup)
  - [PriceClass methods](#priceclass-methods)
  - [PriceClass operators (+, *, /, #, ==)](#priceclass-operators)
  - [PriceGroupClass methods](#pricegroupclass-methods)
  - [w.component (consumer bridge) and exports.w_lib:w_component_get](#wcomponent-consumer-bridge-and-exportswlibwcomponentget)
  - [w.component.apply](#wcomponentapply)
  - [w.component.remove](#wcomponentremove)
  - [w.component.removeAllClothes](#wcomponentremoveallclothes)
  - [w.component.applyComponents](#wcomponentapplycomponents)
  - [w.component.applySkin](#wcomponentapplyskin)
  - [w.component.setWearableState](#wcomponentsetwearablestate)
  - [w.component.getWearableState](#wcomponentgetwearablestate)
  - [Wearable state queries and shirt state setters](#wearable-state-queries-and-shirt-state-setters)
  - [w.component.getComponentEquiped](#wcomponentgetcomponentequiped)
  - [w.component.getComponentsEquiped](#wcomponentgetcomponentsequiped)
  - [w.component.getCategoriesEquiped / isCategoryEquiped](#wcomponentgetcategoriesequiped-iscategoryequiped)
  - [w.component.getCategoryTint](#wcomponentgetcategorytint)
  - [w.component.refreshPed / waitPedLoaded](#wcomponentrefreshped-waitpedloaded)
  - [w.component.getComponentCategory / isMpComponent / getBaseLayer](#wcomponentgetcomponentcategory-ismpcomponent-getbaselayer)
  - [w.component.getPaletteNameFromHash / getCategoryNameFromHash / getWearableStateNameFromHash](#wcomponentgetpalettenamefromhash-getcategorynamefromhash-getwearablestatenamefromhash)
  - [w.component.getCategoryHash / isCategoryAClothes](#wcomponentgetcategoryhash-iscategoryaclothes)
  - [w.component.formatComponentData](#wcomponentformatcomponentdata)
  - [Component name builders (getHeadFromSkinTone, getBodiesUpperFromSkinTone, getBodiesLowerFromSkinTone, getEyesFromIndex, getTeethFromIndex)](#component-name-builders-getheadfromskintone-getbodiesupperfromskintone-getbodieslowerfromskintone-geteyesfromindex-getteethfromindex)
  - [Catalogue loaders (getFullPedComponentList, getFullHorseComponentList, getFullShopItemTintsList, getShopItemTint)](#catalogue-loaders-getfullpedcomponentlist-getfullhorsecomponentlist-getfullshopitemtintslist-getshopitemtint)
  - [w.component.data tables](#wcomponentdata-tables)
  - [HorseComponents (deprecated global)](#horsecomponents-deprecated-global)
  - [Manifest metadata for the version checker (version, package_id, dependencies_version_min)](#manifest-metadata-for-the-version-checker-version-packageid-dependenciesversionmin)
  - [w.versionChecker.checkUpdate](#wversioncheckercheckupdate)
  - [w.versionChecker.GetScriptVersion](#wversioncheckergetscriptversion)
  - [w.versionChecker.StopAddon](#wversioncheckerstopaddon)
  - [exports.w_lib:StopAddon](#exportswlibstopaddon)
  - [Events](#events)
  - [Convars](#convars)
  - [Commands](#commands)

## Loading the library, globals and lifecycle

The library is loaded into a consumer resource by a single manifest line, `shared_script '@w_lib/init.lua'` (or the first entry of a `shared_scripts {}` block), together with `lua54 'yes'` and `dependency 'w_lib'`. `init.lua` refuses to run without Lua 5.4, raises an error if the library is not already in the `started` state, raises an error if it is listed twice in the same manifest, and asks `exports.w_lib:hasLoaded()` whether the library's NUI build is present (a returned error string is raised inside the consumer resource). It then sets `msgpack.setoption('ignore_invalid', true)` for the consumer resource, so values that cannot be serialised (functions, userdata) are silently dropped whenever they cross an export or event boundary. Never load `w_init.lua` or any `resource/` file from a consumer manifest; `init.lua` bootstraps the `w` layer on its own. The library itself declares `dependencies { '/server:14901', '/onesync' }`, so the server must run build 14901 or newer with OneSync enabled.

The consumer resource receives several globals.

`lib` is the ox_lib-style core. `lib.<name>` first looks for an imports module (`imports/<name>/shared.lua` plus `imports/<name>/<client|server>.lua`, read with `LoadResourceFile` and run inside the consumer resource's own Lua state). Only when no such file exists does it become a proxy for `exports.w_lib:<name>`; that proxy is created unconditionally, so a name that is neither an imports module nor an export fails only when it is called. Imports modules run in the consumer resource and can take Lua functions, tables and closures. Export-backed names (`lib.showContext`, `lib.inputDialog`, `lib.notify` on the client, `lib.blockControl`, `lib.checkDependency`, `lib.versionCheck`, `lib.cache` and every other `lib.<x>` defined under `w_lib/resource/`, which `resource/init.lua` auto-exports) run inside the library, so their arguments are msgpack-serialised: functions cannot be passed, handlers must be event names (strings) that the consumer resource registers with `AddEventHandler` or `RegisterNetEvent`, and returned tables are copies.

`w` (and its alias `jo`, the same table) is the jo_libs-style module layer built by `w_init.lua`. `w.<name>` resolves in this order: (1) on the client, the notification bridge (`w.notify`, `w.drawText2D`, `w.drawText3D`, forwarded to the exports `NotifyRaw`, `DrawText2D` and `DrawText3D`); (2) a module under `modules/<name>/`, loaded lazily into the consumer resource, with the aliases `framework -> framework-bridge`, `pl -> player`, `versionChecker -> version-checker`, `notif -> notification`, `pedTexture -> ped-texture`, `gameEvents -> game-events`, `triggerEvent -> trigger-event`, `promptNui -> prompt-nui` and `meCoords`/`mePlayerId`/`meServerId -> me`; (3) the `lib` core. Results are cached per key, including "not found", and the first access of any unknown key costs one `exports.w_lib:loadGlobalModule` call. Because modules run inside the consumer resource, any module that sends NUI messages (`w.promptNui`, `w.menu` and so on) draws into the consumer resource's own NUI frame. Such a consumer resource must declare `ui_page 'nui://w_lib/web/build/index.html'` unless it ships its own UI that handles those messages. `init.lua` detects that `ui_page` and registers the `getConfig` and `init` NUI callbacks plus a `w_lib:setLocale` listener inside the consumer resource, so the shared frame receives the library's colours and locale strings. Resources that only use export-backed UI (`lib.showContext`, `lib.inputDialog`, `lib.progressBar`, `lib.notify`) do not need a `ui_page`, because those draw in the library's own frame; this is also why context-menu rows carry event names rather than functions.

Other globals: `cache`, `require` (equal to `lib.require`), `SetInterval` and `ClearInterval`, `GetActivePlayers` (server), `DataView` (set when `lib.dataview` is pre-loaded), `noop`, and the `w_init` helpers `CreateThreadNow`, `Await`, `InvokeNative`, `GetHashFromString`, `UnJson` and `GetValue`.

Two manifest metadata keys drive eager loading. `w_lib { ... }` names imports modules that `init.lua` loads immediately at start; if the module file returns a function it is called once, but only for names that were not already loaded. Since `init.lua` pre-loads `table`, `string`, `math`, `locale`, `dataview` and (client) `rawKeys` before reading the metadata, `w_lib { 'locale' }` does not initialise locale in this build. A consumer resource must call `lib.locale()` once itself; after that `locale(key)` translates and the `w_lib:setLocale` event re-loads the dictionary automatically. `w_module { ... }` names `w` modules; `w_init.lua` always loads `table`, `print`, `file`, `math` and `trigger-event`, adds the listed ones, sorts them (`table`, `print`, `file`, `math`, `hook` first, then alphabetical) and loads each with `w.require` before setting `w.libLoaded = true`. About one second later the consumer resource fires the local event `w_lib:resourceStarted` with its own name; the library records it and re-broadcasts `w_lib:onResourceStart`, on which `w.onResourceStart` and `exports.w_lib:isResourceStarted` are built. "Started" here means "the resource loaded `@w_lib/init.lua` and its `w` layer finished", so it only works for library-based resources. Lifecycle helpers: `w.ready(cb)` runs `cb` in a thread after `libLoaded` plus 1000 ms, `w.stopped(cb)` runs `cb` when the consumer resource itself stops, `w.waitLibLoading()` blocks until `libLoaded`, plus `w.isModuleLoaded`, `w.require`, `w.createModule` and `w.async` (a lazy proxy that wraps already-loaded `w.*` or `_G` functions into promise-like objects with `:next()` and `:await()`).

The client `cache` table is populated by the library's own 100 ms loop (`cache.ped`, `cache.vehicle`, `cache.seat`, `cache.mount` on RedM, `cache.weapon`) plus `cache.playerId`, `cache.serverId`, `cache.game` and `cache.resource`. In a consumer resource, the first read of a key pulls the current value from `exports.w_lib:cache(key)` and subscribes to the local `w_lib:cache:<key>` event; `lib.onCache(key, fn)` registers change callbacks. `cache(key, fn, timeout)` memoises an arbitrary computed value. On the server only `cache.game` and `cache.resource` exist; reading any other key there calls a client-only export and errors.

Debugging is convar driven: `<resource>:debug on` sets `w.debug = true` in that resource; `<resource>:debug:<moduleFolder> on` or `all:debug:<moduleFolder> on` sets `w.debugModules[<moduleFolder>] = true`. Use `setr` when the client side must see them.

Version helpers: `lib.checkDependency` (shared), `lib.versionCheck` (server, GitHub), `w.resource.isConvarMatching` (shared predicate), and the Jump On Studios `w.versionChecker` module (server). The automatic check of that module, including `dependencies_version_min`, runs only when the resource has both `package_id` and `version` metadata, so it is inert for ordinary Wraith resources. The `StopAddon` export is defective in this build (see its entry); use `TriggerEvent('w_lib:kill:resource', name)` or `w.versionChecker.StopAddon` instead.

Control blocking (`lib.blockControl`, `lib.unblockControl`, `lib.isControlBlocked`; client exports) replaces per-resource `DisableControlAction` loops with a single loop inside the library that triggers the consumer resource's event name on press. Registrations that carry a press event are cleaned up when the consumer resource stops; pure blocks are not.

Server start publishes `GlobalState['w_lib:locales']` and, unless suppressed by `w_lib:ignoreSecurityAdvisory ["stateBagStrictMode"]` or the presence of qb-core, prints a warning two seconds after start if `sv_stateBagStrictMode` is off. The client listens for the server-sent net event `w_lib:setStateBagValue` to set a key on `LocalPlayer.state`. Client-originated replicated state writes go through the internal callback `w_lib:requestSetStateBag`, which only succeeds when a server-side hook inside the library approves that key (the library ships approvals for `w_lib:setVehicleProperties` and `w_entity_setonground` only). With strict mode on, consumer resources should therefore set replicated state from the server.

### shared_script '@w_lib/init.lua'

```lua
shared_script '@w_lib/init.lua'  -- or first entry of shared_scripts {}
```

Side: shared

Parameters: none.

Returns: nothing. Defines the globals `lib`, `w`, `jo`, `cache`, `require`, `noop`, `SetInterval`, `ClearInterval`, `GetActivePlayers` (server), `DataView`, `CreateThreadNow`, `Await`, `InvokeNative`, `GetHashFromString`, `UnJson` and `GetValue`.

The one line that loads the library into a consumer resource. It must come before any script that uses `lib` or `w`. Load it on both sides (`shared_script`): the client copy registers the per-resource notification event used by the server-side `lib.notify` and populates `cache.playerId` and `cache.serverId`. It requires `lua54 'yes'` (an error is raised otherwise), requires the library to be in state `started`, errors if listed twice, and raises whatever string `exports.w_lib:hasLoaded()` returns when the NUI build is missing. It sets msgpack `ignore_invalid` for the resource, pre-loads `lib.table`, `lib.string`, `lib.math`, `lib.locale`, `lib.dataview` and (client) `lib.rawKeys`, then loads the `w` module layer from `w_init.lua` and merges it with `lib`. Never list the library's own `w_init.lua` or `resource/` files in a consumer manifest.

```lua
fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
dependency 'w_lib'

shared_scripts {
    '@w_lib/init.lua',   -- must be first
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'
```

### lua54 'yes'

```lua
lua54 'yes'
```

Side: shared

Parameters: none.

Returns: nothing.

Mandatory in every consumer manifest. Both `init.lua` and `w_init.lua` check `_VERSION` for 5.4 and raise an error stating that Lua 5.4 must be enabled in the resource manifest otherwise.

```lua
lua54 'yes'
```

### dependency 'w_lib'

```lua
dependency 'w_lib'  -- or dependencies { 'w_lib' }
```

Side: shared

Parameters: none.

Returns: nothing.

Makes the server start the library before the consumer resource. `init.lua` errors with `w_lib must be started before this resource.` if `GetResourceState('w_lib')` is not `started` at load time (and `w_init.lua` repeats the check), so the dependency is effectively required.

```lua
dependencies {
    'w_lib',
    'oxmysql',
}
```

### dependencies { '/server:14901', '/onesync' }

```lua
-- declared by w_lib itself, not by consumers
```

Side: server

Parameters: none.

Returns: nothing.

The library's own manifest requires server build 14901 or newer and OneSync. On a server that does not meet them the library does not start, and every consumer resource then fails its "must be started" check. There is nothing to write in a consumer manifest; this is a server owner requirement.

```lua
# server.cfg
onesync on
```

### w_lib { ... }

```lua
w_lib { 'points', 'zones', 'callback', 'waitFor' }
```

Side: shared

Parameters:
- `names` (string[], optional): folder names under `w_lib/imports/` (for example `array`, `callback`, `class`, `cron`, `dataview`, `dui`, `gameEntity`, `grid`, `heap`, `hook`, `locale`, `logger`, `lru`, `map`, `marker`, `math`, `ped`, `playAnim`, `player`, `points`, `print`, `prop`, `rawKeys`, `raycast`, `registerHook`, `require`, `ringbuffer`, `scaleform`, `selector`, `set`, `streamingRequest`, `string`, `table`, `timer`, `triggerClientEvent`, `uuid`, `vehicle`, `waitFor`, `zones` and the `request*`, `getClosest*` and `getNearby*` helpers).

Returns: nothing.

Read by `init.lua` with `GetResourceMetadata(resource, 'w_lib', i)`. Each named imports module that is not already present in `lib` is loaded immediately (`shared.lua` plus the client or server file) and, if its return value is a function, called once with `pcall`. Two consequences: (1) it only pre-loads modules that would otherwise load lazily on first `lib.<name>` access, so listing them is optional; (2) `table`, `string`, `math`, `locale`, `dataview` and (client) `rawKeys` are already loaded before this loop runs, so they are skipped and their initialiser is not called. In particular `w_lib { 'locale' }` does not initialise translations in this build: call `lib.locale()` once in your own script (see the locale subsystem). Until then `locale(key)` returns the key unchanged.

```lua
-- fxmanifest.lua
w_lib {
    'points',
    'zones',
}

-- client.lua / server.lua: locale must still be initialised by you
lib.locale()
print(locale('ui.hello'))
```

### w_module { ... }

```lua
w_module { 'framework', 'notification', 'callback', 'raw-keys' }
```

Side: shared

Parameters:
- `names` (string[], optional): folder names under `w_lib/modules/` or their aliases (`framework`/`framework-bridge`, `pl`/`player`, `versionChecker`/`version-checker`, `notif`/`notification`, `pedTexture`/`ped-texture`, `gameEvents`/`game-events`, `triggerEvent`/`trigger-event`, `promptNui`/`prompt-nui`). Both spellings are accepted; the alias is used internally.

Returns: nothing.

Read by `w_init.lua`. `table`, `print`, `file`, `math` and `trigger-event` are always loaded; the listed modules are added, sorted (`table`, `print`, `file`, `math`, `hook` first, then alphabetically) and loaded with `w.require` before `w.libLoaded` becomes true. Listing a module guarantees it is present before your first script line runs and before `w.ready` fires. Modules not listed are loaded lazily on first `w.<name>` access, which yields (`Wait(0)`) while loading. Modules run inside the consumer resource's Lua state, so any that send NUI messages need the consumer resource to have a `ui_page` (see that entry). A module that exists only for one side (for example `version-checker` has only `server.lua`) resolves to nothing on the other side.

```lua
-- fxmanifest.lua
w_module {
    'framework',     -- alias of framework-bridge -> w.framework
    'notification',  -- w.notif
    'callback',      -- w.callback
    'raw-keys',      -- w.rawKeys
}
```

### ui_page 'nui://w_lib/web/build/index.html'

```lua
ui_page 'nui://w_lib/web/build/index.html'
```

Side: client

Parameters: none.

Returns: nothing.

Needed when the consumer resource uses `w` modules that draw through the consumer resource's own NUI frame (`w.promptNui`, `w.menu` and other `modules/` code that calls `SendNUIMessage` from the consumer's context). Without a `ui_page` the game prints `SEND_NUI_MESSAGE: resource X has no UI frame` and nothing appears. When `init.lua` sees a first `ui_page` containing `w_lib/web/build`, it registers inside the consumer resource the NUI callbacks `getConfig` (returns the `w_lib:primaryColor` and `w_lib:primaryShade` convars) and `init` (answers `1` and pushes the library's `locales/<lib.getLocaleKey()>.json`, falling back to `en.json`, as `{action='setLocale', data=...}`), and re-pushes the locale on the `w_lib:setLocale` event. Do not register your own `getConfig` or `init` NUI callbacks in such a resource. Not needed for export-backed UI (`lib.showContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.progressBar`, `lib.notify`, `lib.showTextUI`), which draws in the library's frame.

```lua
-- consumer with no UI of its own that uses w.promptNui / w.menu
ui_page 'nui://w_lib/web/build/index.html'
```

### version 'x.y.z'

```lua
version 'x.y.z'
```

Side: shared

Parameters: none.

Returns: nothing.

Consumer manifest metadata read by `lib.checkDependency` (on the target resource), `lib.versionCheck` (on the calling resource), `w.resource.isConvarMatching` and `w.versionChecker`. `checkDependency` and `versionCheck` extract the first `x.y.z` and treat a missing value as `unknown` (`checkDependency` fails, `versionCheck` prints an error and stops). `isConvarMatching` and `versionChecker` use the raw string; a missing version reads as `1` there.

```lua
version '1.4.0'
```

### package_id and dependencies_version_min

```lua
package_id '1234'
dependencies_version_min 'w_lib:3.38.0,oxmysql:2.7.3'
```

Side: server

Parameters: none.

Returns: nothing.

Both are optional metadata consumed by `w.versionChecker.checkUpdate()`, which auto-runs on `w.ready` in any resource that loads the `versionChecker` module.

`package_id` is used to query `https://jumpon-studios.com/api/checkScriptVersion?package=<id>` (the server hostname is sent URL-encoded). Without a numeric `package_id`, or without `version` metadata, `checkUpdate` returns immediately and also skips the `dependencies_version_min` check. Wraith resources normally omit it, which makes the whole `versionChecker` module inert for them.

`dependencies_version_min` is only evaluated when the same resource also has `package_id` and `version` metadata. It holds comma-separated `resource:minVersion` pairs with no spaces (a leading space breaks the parser and the resource is reported missing). Every colon is replaced by `>=`, so the `resource:metadataKey` form of `isConvarMatching` cannot be used here. A resource whose state is not `started` prints a "missing" message; one that is started but too old prints an error and stops the calling resource through `TriggerEvent('w_lib:kill:resource', name)`.

```lua
-- only meaningful together with package_id (Jump On Studios packages)
w_module { 'versionChecker' }
package_id '42'
version '1.0.0'
dependencies_version_min 'w_lib:3.38.0,oxmysql:2.7.3'
```

### lib

```lua
lib.<name>  |  lib('<name>')
```

Side: shared

Parameters: none.

Returns: a module table or function (imports) or an export proxy function.

Global core table set by `init.lua`. Fixed fields: `lib.name == 'w_lib'`, `lib.context == 'client' | 'server'`, `lib.cache` (the cache table) and `lib.onCache`. Reading `lib.<name>`: if `imports/<name>/shared.lua` or `imports/<name>/<context>.lua` exist in the library they are loaded into the consumer resource and the return value is stored (a module returning nothing becomes a no-op function). Otherwise `lib.<name>` becomes `function(...) return exports.w_lib[name](nil, ...) end`, an export call into the library: arguments are msgpack-serialised, functions are dropped (`ignore_invalid`), handlers must be event names, returned tables are copies, and a name that is not an export at all only fails when called. Inside the library every `lib.<name>` defined under `resource/` is auto-exported, so `exports.w_lib:<name>` and `lib.<name>` are equivalent for those. On the server, `lib.notify` is replaced by the deprecated server form (see that entry).

```lua
-- imports module: runs in this resource, can take functions
lib.callback.register('myres:getData', function(source) return {} end)

-- export-backed: runs inside w_lib, pass event names not functions
lib.registerContext({ id = 'my_menu', title = 'Menu', options = {
    { title = 'Do it', event = 'myres:doIt' },
}})
lib.showContext('my_menu')
```

### w and jo

```lua
w.<name>   |   jo.<name>
```

Side: shared

Parameters: none.

Returns: a module table, a bridge function, or a `lib` core value.

Unified namespace built by `w_init.lua` and extended by `init.lua`. Fields: `w.libLoaded`, `w.debug`, `w.debugModules`, `w.name == 'w_lib'`, `w.resourceName` (the consumer resource's name), `w.context` (`'client'` or `'server'`), `w.cache` (the same table as `cache`), `w.isServerSide()`, `w.isClientSide()` and `w.async`. Lookup order for `w.<k>`: (1) the client notification bridge (`notify`, `drawText2D`, `drawText3D` mapped to the exports `NotifyRaw`, `DrawText2D`, `DrawText3D`); (2) a module in `w_lib/modules/<k>` (alias resolved, loaded lazily into this resource, yields until loaded; the first access of any unknown key makes one `exports.w_lib:loadGlobalModule` call and registers debug convar listeners for that name); (3) `lib[k]`. The result, including "not found", is cached per key. Calling `w(...)` returns nothing.

`jo` is an alias set by both `w_init.lua` and `init.lua`: `jo` and `w` are the same table, so resources written for jo_libs run unchanged.

```lua
w.ready(function()
    print(w.resourceName, w.context, w.isClientSide())
    w.notif.info('Loaded')      -- modules/notification
    lib.notify({ title = 'Also fine' })
end)

jo.notif.success('Saved')   -- identical to w.notif.success('Saved')
```

### cache

```lua
cache.<key>  |  cache(key: string, fn: function, timeout?: number)
```

Side: shared

Parameters:
- `key` (string, required): cache key. Built-in keys: `game` (`'redm'`, `'fivem'` or `'fxserver'`), `resource` (this resource's name), and on the client `playerId`, `serverId`, `ped`, `vehicle` (handle or `false`), `seat` (`-1` and up, or `false`), `mount` (RedM: mount handle or `false`), `weapon` (hash or `false`).
- `fn` (function, optional): call form only; computes the value when the key is absent (`rawget == nil`) and the result is stored under `key`.
- `timeout` (number, optional): call form only; milliseconds after which the memoised value is cleared.

Returns: the cached value (`false` when the library has no value for the key).

Per-resource cache table. On the client, `cache.playerId` and `cache.serverId` are set at load; `ped`, `vehicle`, `seat`, `mount` and `weapon` are maintained by the library's own 100 ms loop. In a consumer resource the first dot-read of any other key fetches it from `exports.w_lib:cache(key)` (stored as `false` when nil) and subscribes to the local event `w_lib:cache:<key>`, so later reads are plain table reads. Gotchas: on the server only `cache.game` and `cache.resource` exist, and reading any other key calls the client-only export and errors; a key first read with the dot form is stored as `false`, so a later `cache('key', fn)` returns `false` without calling `fn`. Use distinct names for memoised values.

```lua
local ped = cache.ped
if cache.vehicle then print('in vehicle seat', cache.seat) end
if cache.mount then print('riding', cache.mount) end

local model = cache('myModel', function() return joaat('a_c_horse_arabian_white') end, 60000)
```

### lib.onCache

```lua
lib.onCache(key: string, cb: fun(value: any, oldValue: any))
```

Side: client

Parameters:
- `key` (string, required): one of the library-maintained cache keys (`ped`, `vehicle`, `seat`, `mount`, `weapon`; any key for which the library fires `w_lib:cache:<key>`).
- `cb` (function, required): called with `(newValue, oldValue)` in its own thread each time the library reports a change.

Returns: nothing.

Registers a change listener for a cache key. Defined in `init.lua` and runs in the consumer resource, so a real Lua function is accepted. The first call for a key also subscribes the consumer resource to `w_lib:cache:<key>` (which on the server calls a client-only export and errors, so use it on the client). Callbacks are started before the consumer's cache table is updated, which is why `oldValue` is passed.

```lua
lib.onCache('ped', function(ped)
    playerPed = ped
end)

lib.onCache('vehicle', function(vehicle, previous)
    if not vehicle then print('left vehicle', previous) end
end)
```

### exports.w_lib:cache

```lua
exports.w_lib:cache(key: string) -> any
```

Side: client

Parameters:
- `key` (string, required): cache key maintained by the library (`ped`, `vehicle`, `seat`, `mount`, `weapon`, `playerId`, `serverId`, `game`, `resource`).

Returns: the current value from the library's own cache table (`nil` for unknown keys).

Reads a key from the library's cache. The consumer resource's `cache` global uses it on first access; direct calls are rarely needed. Client only (there is no server file). In a consumer resource `lib.cache` is the cache table itself, so use the exports form for a direct call.

```lua
local ped = exports.w_lib:cache('ped')
```

### require

```lua
require(modName: string) -> any   -- same as lib.require
```

Side: shared

Parameters:
- `modName` (string, required): dot path relative to the calling resource root; dots become `/` and the templates `?.lua` then `?/init.lua` are tried (`'modules.utils'` resolves to `modules/utils.lua` or `modules/utils/init.lua`). `'@otherResource.path.to.module'` loads from another resource. On the client the file must be declared in that resource's `files {}`.

Returns: the module's return value (`true` when it returns nil); cached per name in `package.loaded`.

`init.lua` replaces the global `require` with `lib.require`. It loads the chunk in the consumer resource's environment, caches it and raises on circular dependencies. The same imports module also provides `lib.load(filePath, env?)` (runs a file without caching, same path rules) and `lib.loadJson(filePath)` (decodes `<path>.json`).

```lua
local utils = require 'shared.utils'          -- <resource>/shared/utils.lua
local items = lib.loadJson('data.items')       -- <resource>/data/items.json
```

### SetInterval and ClearInterval

```lua
SetInterval(callback: function | number, interval?: number, ...args) -> number id
ClearInterval(id: number)
```

Side: shared

Parameters for `SetInterval`:
- `callback` (function | number, required): function to run repeatedly, or an existing interval id to change its delay.
- `interval` (number, optional, default 0): milliseconds between runs; 0 means every frame.
- `...` (any, optional): extra arguments passed to `callback` on every run.

Parameters for `ClearInterval`:
- `id` (number, required): id returned by `SetInterval`.

Returns: `SetInterval` returns a numeric thread id usable with `ClearInterval` or `SetInterval(id, newInterval)`, and nothing when updating an existing id. `ClearInterval` returns nothing.

`SetInterval` creates a thread that calls `callback` every `interval` ms until cleared. Calling `SetInterval(id, ms)` with an existing id only updates its delay. It errors if `interval` is not a number or `callback` is not a function. `ClearInterval` stops the interval thread after its current wait; it errors if `id` is not a number or no such interval exists, so calling it twice on the same id errors.

```lua
local tick = SetInterval(function()
    updateHud()
end, 100)

SetInterval(tick, 500)   -- slow it down

if tick then
    ClearInterval(tick)
    tick = nil
end
```

### GetActivePlayers

```lua
GetActivePlayers() -> number[]
```

Side: server

Parameters: none.

Returns: an array of connected player server ids as numbers.

Server-side parity for the client native of the same name, defined in `init.lua` for consumer resources (built on `GetNumPlayerIndices` and `GetPlayerFromIndex`). On the client the native itself is used.

```lua
for _, playerId in ipairs(GetActivePlayers()) do
    TriggerClientEvent('myres:refresh', playerId)
end
```

### Small helper globals

```lua
noop()
CreateThreadNow(fn) ; Await(promise) ; InvokeNative(hash, ...)
GetHashFromString(value: string | number) -> number
UnJson(value: string | table | nil) -> table
GetValue(value: any, default: any) -> any
```

Side: shared

| Global | Parameters | Returns | Meaning |
|---|---|---|---|
| `noop` | none | nothing | Empty function defined by `init.lua` in every consumer resource; imports modules that return nothing are stored as `noop`. Handy as a default callback. |
| `CreateThreadNow`, `Await`, `InvokeNative` | as the Citizen equivalents | as the Citizen equivalents | Short names assigned by `w_init.lua` for `Citizen.CreateThreadNow`, `Citizen.Await` and `Citizen.InvokeNative`. |
| `GetHashFromString` | `value` (string | number, required): a model or hash name, a numeric string, or a number | the joaat hash of the string, the signed number for numeric strings (`math.toSigned`), or the value unchanged | Used throughout `w` modules to accept either names or hashes. |
| `UnJson` | `value` (string | table | nil, required): JSON text, an already-decoded table, nil/false or the string `'null'` | the decoded table (`{}` for nil, false or `'null'`); non-string values returned unchanged | Safe decoding of database columns that may hold JSON or nothing. |
| `GetValue` | `value` (any, required): the value that may be nil; `default` (any, required): the fallback. If `default` is nil the value is returned as is; if `default` is false the result is `value or false` | `value` when not nil, otherwise `default` | For optional parameters where `false` must be distinguishable from `nil`. |

```lua
local cb = opts.onDone or noop
cb()

CreateThreadNow(function() print('runs immediately') end)

local model = GetHashFromString('a_c_horse_arabian_white')
local meta = UnJson(row.metadata)
local silent = GetValue(opts.silent, false)
```

### w.ready

```lua
w.ready(cb?: function)
```

Side: shared

Parameters:
- `cb` (function, optional): called once in a new thread after `w.libLoaded` is true plus a 1000 ms delay.

Returns: nothing.

Runs `cb` once all `w_module` entries are loaded and the library is initialised. The 1000 ms delay is fixed. Runs in the consumer resource, so a Lua function is expected. Use it instead of a raw `CreateThread` for code that touches `w.framework` or other modules at start.

```lua
w.ready(function()
    print('w_lib layer ready in', w.resourceName)
end)
```

### w.stopped

```lua
w.stopped(cb: function)
```

Side: shared

Parameters:
- `cb` (function, required): called with no arguments when this resource itself stops.

Returns: nothing.

Registers an `onResourceStop` handler filtered to the calling resource's own name. Use it for cleanup such as deleting entities or removing prompts.

```lua
w.stopped(function()
    for _, ped in ipairs(spawnedPeds) do DeleteEntity(ped) end
end)
```

### w.waitLibLoading

```lua
w.waitLibLoading()
```

Side: shared

Parameters: none.

Returns: nothing.

Blocks in a `Wait(0)` loop until `w.libLoaded` is true. Must be called from a thread. `w.onResourceStart` and the `StopAddon` export wrapper call it internally.

```lua
CreateThread(function()
    w.waitLibLoading()
    print('all w_module entries loaded')
end)
```

### w.onResourceStart

```lua
w.onResourceStart(resource: string, cb: function)
```

Side: shared

Parameters:
- `resource` (string, required): name of another library-based resource.
- `cb` (function, required): run in a thread now if that resource has already announced itself, and again every time it (re)starts.

Returns: nothing.

Blocks until this resource's own `w` layer is loaded, then registers `cb` and checks `exports.w_lib:isResourceStarted`. A resource counts as started when it has loaded `@w_lib/init.lua` and fired `w_lib:resourceStarted` (about one second after its own `w` layer finished); resources that do not use the library never trigger it. Call it from a thread because of the internal `waitLibLoading`.

```lua
CreateThread(function()
    w.onResourceStart('w_inventory', function()
        registerInventoryItems()
    end)
end)
```

### exports.w_lib:isResourceStarted

```lua
exports.w_lib:isResourceStarted(resource: string) -> boolean
```

Side: shared

Parameters:
- `resource` (string, required): resource name.

Returns: `true` if that resource has fired `w_lib:resourceStarted` since it last stopped.

Tracks library-based resources only (those that loaded `@w_lib/init.lua` and finished their `w` layer). Cleared on that resource's `onResourceStop`. Backs `w.onResourceStart`. Registered on both sides of the library.

```lua
if exports.w_lib:isResourceStarted('w_hud') then
    TriggerEvent('w_hud:refresh')
end
```

### w.libLoaded, w.debug, w.debugModules, w.resourceName, w.context, w.isServerSide, w.isClientSide

```lua
w.libLoaded: boolean
w.debug: boolean
w.debugModules: table<string, boolean>
w.resourceName: string
w.context: 'client' | 'server'
w.isServerSide(): boolean
w.isClientSide(): boolean
```

Side: shared

Parameters: none.

Returns: the field values described below.

State fields of the module layer. `w.libLoaded` turns true after the `w_module` list is loaded. `w.debug` mirrors the `<resource>:debug` convar and `w.debugModules['<folder>']` mirrors `<resource>:debug:<folder>` or `all:debug:<folder>` for each loaded module; both update live through convar change listeners. Modules use these to decide whether to print debug output.

```lua
if w.debug then print('verbose mode on for', w.resourceName) end
if w.debugModules['framework-bridge'] then print('framework bridge tracing') end
```

### w.require

```lua
w.require(name: string, needLocal?: boolean) -> true | nil
```

Side: shared

Parameters:
- `name` (string, required): module folder name or alias under `w_lib/modules/`.
- `needLocal` (boolean, optional, default true): in a consumer resource the module files are loaded locally either way; `false` only marks the registry entry as "global", which makes a later `w.require(name)` with the default reload the files.

Returns: `true` when a load was performed, `nil` when already loaded.

Explicitly loads a `w` module (`modules/<name>/shared.lua` then `modules/<name>/<client|server>.lua`) into the calling resource, after asking the library to load its global copy via `exports.w_lib:loadGlobalModule` (waits until the library is started). Registers the module's debug convar listeners. Reading `w.<name>` does the same lazily; `w.require` is the explicit form used at the top of files that must have a module before first use.

```lua
w.require('string')
w.require('resource')
print(w.resource.isConvarMatching('oxmysql'))
```

### w.isModuleLoaded

```lua
w.isModuleLoaded(name: string, needLocal?: boolean) -> boolean
```

Side: shared

Parameters:
- `name` (string, required): module name or alias (`framework`, `notif`, `promptNui`, and so on).
- `needLocal` (boolean, optional, default true): only count a module loaded into this resource with `needLocal = true`. Pass `false` to also accept a load marked global.

Returns: `true` if the module is loaded or currently loading.

Checks the `w` module registry of the calling resource (not the library's). Aliases are resolved before the lookup.

```lua
if not w.isModuleLoaded('framework') then w.require('framework') end
```

### w.createModule

```lua
w.createModule(name: string) -> table
```

Side: shared

Parameters:
- `name` (string, required): key under `w` to create.

Returns: the new or existing table stored at `w[name]`.

Creates an empty table at `w[name]` if absent (`rawset`, no lazy loading) and returns it. Used by every `w` module file to declare itself; a consumer resource can use it to add its own namespace to `w` without triggering the module loader.

```lua
local mod = w.createModule('myShop')
function mod.open() end
w.myShop.open()
```

### exports.w_lib:loadGlobalModule

```lua
exports.w_lib:loadGlobalModule(name: string) -> true
```

Side: shared

Parameters:
- `name` (string, required): `w` module name or alias.

Returns: `true`.

Makes the library itself load the named module (its shared and context files and any `g_shared`, `g_client` or `g_server` global files). `w.require` in a consumer resource calls this automatically before loading the local copy, so direct use is rarely needed. Waits until the library's own layer is loaded. A same-side local event form also exists: `TriggerEvent('w_lib:loadGlobalModule', name, cb)`, where `cb` is required because it is called unconditionally.

```lua
exports.w_lib:loadGlobalModule('framework')
```

### w.async

```lua
w.async.<name>(...) -> { next = fun(self, cb, errCb), await = fun() -> ... }
w.async.<module>.<fn>(...)
```

Side: shared

Parameters: none (the wrapped function receives the arguments passed).

Returns: a promise-like object with `:next(callback, errorCallback)` and `:await()`, the latter returning the wrapped function's results.

Lazy proxy that wraps functions into thread-backed promises. The top level uses `rawget` on `w` and then `_G`, so only modules already loaded are visible (`w.require` the module first); inside a module table normal indexing is used. Nested tables are proxied recursively and wrapped functions are cached. Errors inside the wrapped call reject the promise (`errorCallback` receives the message; `:await()` raises).

```lua
w.require('framework')
local balance = w.async.framework.getMoney(source):await()

w.async.myHeavyFunction(1, 2):next(function(result)
    print(result)
end, function(err) print('failed', err) end)
```

### lib.checkDependency

```lua
lib.checkDependency(resource: string, minimumVersion: string, printMessage?: boolean) -> boolean, string?
```

Side: shared

Parameters:
- `resource` (string, required): resource whose `version` manifest metadata is checked.
- `minimumVersion` (string, required): full `x.y.z` minimum. Give all three segments; a shorter value can error during comparison.
- `printMessage` (boolean, optional): when true and the check fails, prints the message and returns `nil` instead of `false, msg`.

Returns: `true` when satisfied; `false` plus a message string when too old (`nil` after printing when `printMessage` is true).

Export-backed, so it runs in the library; the message names `GetInvokingResource()` as the requiring resource. Only the first `x.y.z` in the version metadata is compared, segment by segment; a resource with no version reads as `unknown` and fails.

```lua
local ok, msg = lib.checkDependency('w_lib', '3.38.0')
if not ok then error(msg) end
lib.checkDependency('oxmysql', '2.7.3', true)  -- prints on failure
```

### lib.versionCheck

```lua
lib.versionCheck(repository: string)
```

Side: server

Parameters:
- `repository` (string, required): GitHub `owner/repo` whose latest non-prerelease release tag is compared with the calling resource's version metadata.

Returns: nothing (prints an update notice when a newer release exists).

Export-backed; the calling resource is `GetInvokingResource()`. Requires `version` metadata containing `x.y.z`, otherwise it prints an error and returns. Performs one HTTP GET to `api.github.com` one second after the call and stays silent on non-200 responses. The library itself does not run it.

```lua
-- server.lua of a consumer
lib.versionCheck('WraithStudio/w_inventory')
```

### w.resource.isConvarMatching

```lua
w.resource.isConvarMatching(str: string) -> boolean
```

Side: shared

Parameters:
- `str` (string, required): one of `'resource'` (must be starting or started), `'!resource'` (must not be starting or started), `'resource>=1.2.0'` with comparator `<`, `>`, `<=`, `>=`, `==` or `=` (compares the resource's `version` metadata), or `'resource:metadataKey>=value'` to compare another manifest metadata key. Whitespace around the comparator is allowed. Resource and key names may only contain letters, digits, `-` and `_` for the comparator form to parse.

Returns: `true` when the resource state and version condition hold.

Shared predicate from `modules/resource`. A missing metadata value is treated as `1`. States other than starting or started (including stopping) count as unavailable. Load with `w.require('resource')` or `w_module { 'resource' }`; lazy `w.resource` access also works.

```lua
w.require('resource')
if not w.resource.isConvarMatching('w_inventory>=2.0.0') then
    print('w_inventory 2.0.0 or newer required')
end
local noVorpInv = w.resource.isConvarMatching('!vorp_inventory')
```

### w.versionChecker

```lua
w.versionChecker.GetScriptVersion() -> string | 1
w.versionChecker.checkUpdate()
w.versionChecker.StopAddon(resource: string) -> true
```

Side: server

Parameters:
- `GetScriptVersion`: none.
- `checkUpdate`: none.
- `StopAddon`: `resource` (string, required): resource name to stop.

Returns: `GetScriptVersion` returns the raw `version` metadata of the calling resource, or `1` when absent. `checkUpdate` returns nothing and prints to the console. `StopAddon` returns `true` immediately; `StopResource` runs in a new thread.

The module has only a server file; on the client `w.versionChecker` does not exist. It becomes available after `w.require('versionChecker')` or `w_module { 'versionChecker' }`, and the first access also schedules `checkUpdate` on `w.ready`.

`checkUpdate` runs automatically in every resource that loads the module. It does nothing unless the resource has both a numeric `package_id` and `version` metadata. When it has them it queries the Jump On Studios API (outbound HTTP, sends the server hostname) and prints an up-to-date or update-available banner, then reads `dependencies_version_min` (`'res:1.0.0,res2:2.0.0'`, no spaces) and for each entry not satisfied by `w.resource.isConvarMatching` prints an error; when the dependency is started but too old it also stops the calling resource through `TriggerEvent('w_lib:kill:resource', name)`. Wraith resources without `package_id` get no dependency check from this module; use `lib.checkDependency` instead.

`StopAddon` stops a resource from the calling resource's own server context, since the module runs inside the consumer resource. It is the working replacement for the defective `exports.w_lib:StopAddon`.

```lua
w.require('versionChecker')
print('running', w.versionChecker.GetScriptVersion())
w.versionChecker.StopAddon(GetCurrentResourceName())
```

### exports.w_lib:StopAddon

```lua
exports.w_lib:StopAddon(resource: string)
```

Side: server

Parameters:
- `resource` (string, required): resource to stop.

Returns: intended `true`; in this build the call raises an error.

Intended to stop a resource from the library's context. It is registered twice inside the library: first by `modules/version-checker/server.lua` (working) and then by `w_init.lua` as `createExport('StopAddon', w.versionChecker.stopAddon)`. The module only defines `StopAddon` with a capital S, so the second registration wraps a nil callback; because it is registered later it is the one an export call reaches, and invoking the export fails with `attempt to call a nil value` after waiting for `libLoaded`. Use `TriggerEvent('w_lib:kill:resource', name)` from a server script, or `w.versionChecker.StopAddon` inside a resource that loaded the module, until this is fixed.

Confirmed from source: `w_init.lua` registers `createExport("StopAddon", w.versionChecker.stopAddon)` while the module defines `w.versionChecker.StopAddon`, so the wrapped callback is nil.

```lua
-- avoid: exports.w_lib:StopAddon(GetCurrentResourceName())
TriggerEvent('w_lib:kill:resource', GetCurrentResourceName())
```

### lib.blockControl, lib.unblockControl and lib.isControlBlocked

```lua
lib.blockControl(control: number, pressEvent?: string) -> boolean     -- exports.w_lib:blockControl(control, pressEvent)
lib.unblockControl(control: number, pressEvent?: string) -> boolean   -- exports.w_lib:unblockControl(control, pressEvent)
lib.isControlBlocked(control: number) -> boolean                      -- exports.w_lib:isControlBlocked(control)
```

Side: client

Parameters:
- `control` (number, required): control hash such as `` `INPUT_MAP` `` (numbers or numeric strings accepted). `blockControl` returns `false` when it is not numeric.
- `pressEvent` (string, optional): for `blockControl`, a local event name triggered with `(control)` on each frame the disabled control is just pressed; omit for a pure block. The event is recorded as owned by the invoking resource. For `unblockControl`, the event name to stop triggering for that control.

Returns: `blockControl` returns `true` on success and `false` for an invalid control. `unblockControl` returns `true` if the control had a registration, `false` otherwise. `isControlBlocked` returns `true` while at least one resource blocks that control through the library.

`blockControl` adds the control to the library's single per-frame loop, which calls `DisableControlAction(0, control, true)` and, on `IsDisabledControlJustPressed`, triggers every registered `pressEvent` for that control. The loop runs only while at least one control is registered. Registrations are reference counted per control: each `blockControl` call needs a matching `unblockControl`. When a resource stops, only registrations that carry a `pressEvent` owned by it are removed automatically (the cleanup walks the press-event map); a pure block with no `pressEvent` is not cleaned up and stays until `unblockControl` is called, so pair pure blocks with `w.stopped`. The event is triggered inside the library, so register it with `AddEventHandler` in the consumer resource. If the library is restarted, registrations are lost and must be redone.

`unblockControl` removes the press event (if given) and decrements the reference count for the control; the control is actually re-enabled when no requester remains. `isControlBlocked` is a diagnostic query of the shared block table.

```lua
local MAP_KEY_EVENT = 'w_map:key:map'
AddEventHandler(MAP_KEY_EVENT, function(control)
    openMap()
end)
exports.w_lib:blockControl(`INPUT_MAP`, MAP_KEY_EVENT)

if exports.w_lib:isControlBlocked(`INPUT_MAP`) then print('map key taken') end

exports.w_lib:unblockControl(`INPUT_MAP`, MAP_KEY_EVENT)
```

### lib.notify (server form)

```lua
lib.notify(playerId: number, data: NotifyProps)
```

Side: server

Parameters:
- `playerId` (number, required): target player's server id.
- `data` (table, required): the same `NotifyProps` table as the client `lib.notify`.
  - `title` (string, optional): translated on the client with `locale()` when the consumer resource's locale dictionary is loaded.
  - `description` (string, optional): same treatment.
  - any other field (`type`, `duration`, `position`, `icon`, and so on): forwarded unchanged to `exports.w_lib:notify` on the client.

Returns: nothing.

Deprecated convenience defined in `init.lua` for the server side of a consumer resource. It triggers the per-resource client net event `__w_notify_<resource>`, which the consumer resource's own client copy of `init.lua` handles by calling `exports.w_lib:notify`, so the consumer resource must load `@w_lib/init.lua` on the client too. Locale placeholders are not supported. Prefer the notification subsystem's own server API.

```lua
lib.notify(source, { title = 'Shop', description = 'Not enough money', type = 'error' })
```

### exports.w_lib:hasLoaded

```lua
exports.w_lib:hasLoaded() -> true | string
```

Side: shared

Parameters: none.

Returns: `true` when the library is usable, otherwise an error string (NUI build missing).

Called by `init.lua` at consumer load; a returned string is raised as an error. In practice the library itself errors at start when `web/build/index.html` is missing, so consumer resources usually hit the "must be started" check first. It can be used by a resource that wants to probe the library without loading `init.lua`.

```lua
local ok = exports.w_lib:hasLoaded()
if ok ~= true then print(ok) end
```

### GlobalState['w_lib:locales']

```lua
GlobalState['w_lib:locales'] -> { { label: string, value: string }, ... }
```

Side: shared

Parameters: none.

Returns: an array of locale options sorted by label; `value` is the file name without `.json` (for example `'ar'`, `'en'`), `label` is the `language` field of that file (or the value when absent).

Set once by the library's server from the files in `w_lib/locales/*.json`. Used by the `/w_lib` settings dialog for the language picker; consumer resources can read it on either side to offer the same list.

```lua
for _, opt in ipairs(GlobalState['w_lib:locales']) do
    print(opt.value, opt.label)
end
```

### Entity(handle).state.w_entity_setonground

```lua
Entity(entity).state:set('w_entity_setonground', true, true)   -- server sets, w_lib client handles
```

Side: shared

Parameters: none.

Returns: nothing.

State-bag contract handled by the library's client. When any entity state bag gets a truthy `w_entity_setonground`, the client waits until it is out of the tutorial session, resolves the entity (up to 10 s), waits for world collision, raycasts down if the entity is in the air and places it on the ground, then clears the key through the library's replicated-state path (the server hook approves clearing this key). On failure the client raises `failed to set ... on ground`. Only library-side code performs the placement; set the key from the server on a networked entity.

Not confirmed from source; treat as best effort.

```lua
-- server, after creating a networked vehicle/object
Entity(entity).state:set('w_entity_setonground', true, true)
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:resourceStarted` | shared (local) | `resource: string` | Fired by every consumer resource with its own name about one second after `w.libLoaded`. The library records it for `isResourceStarted` and re-broadcasts `w_lib:onResourceStart`. Do not trigger it yourself. |
| `w_lib:onResourceStart` | shared (local) | `resource: string` | Re-broadcast by the library on the same side when a library-based resource finished loading its `w` layer. Consumers may listen directly; `w.onResourceStart` is the convenience wrapper. |
| `w_lib:cache:<key>` | client (local) | `value: any, oldValue: any` | Fired by the library's cache for `ped`, `vehicle`, `seat`, `mount` and `weapon` whenever the value changes (`false` when cleared). `lib.onCache` is the intended API. |
| `w_lib:setLocale` | client (local) | `key: string` | Fired by `lib.setLocale` when the player changes language via `/w_lib`. Consumers hosting the shared NUI frame resend the locale JSON, and the imports locale module reloads the consumer's dictionary by calling `lib.locale(key)` once `lib.locale()` was called at least once. Consumers may also listen to rebuild their own localized UI. |
| `w_lib:setStateBagValue` | client (net, server-sent) | `key: string, value: any` | Sets `LocalPlayer.state[key]` on the target client (local, non-replicated write). The handler ignores local triggers, so only the server can drive it: `TriggerClientEvent('w_lib:setStateBagValue', playerId, key, value)`. For replicated state use `Player(id).state` on the server. |
| `w_lib:kill:resource` | server (local) | `resource: string` | Handled inside the library's server. Ignored when `source` is a number (a client cannot trigger it). Waits while the resource is still `starting`, then 100 ms, prints `<resource> Stopped by w_lib` and calls `StopResource`. Use `TriggerEvent` from server scripts only. |
| `w_lib:loadGlobalModule` | shared (local) | `name: string, cb: function` | Event form of `exports.w_lib:loadGlobalModule`; `cb` is required because it is called unconditionally. |
| `__w_notify_<resource>` | client (net) | `NotifyProps` | Per-resource event registered by the consumer's client copy of `init.lua` and used by the deprecated server-form `lib.notify`. |

```lua
AddEventHandler('w_lib:onResourceStart', function(resource)
    if resource == 'w_inventory' then registerItems() end
end)

AddEventHandler('w_lib:cache:weapon', function(weapon)
    print('weapon changed', weapon)
end)

AddEventHandler('w_lib:setLocale', function(key)
    rebuildMenus(key)
end)

-- server
TriggerClientEvent('w_lib:setStateBagValue', source, 'myres:ui', { open = false })

if GetResourceState('oxmysql') ~= 'started' then
    TriggerEvent('w_lib:kill:resource', GetCurrentResourceName())
end
```

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `<resource>:debug` | shared | `on` or `off` (use `setr`, for example `setr w_hud:debug on`) | Read at load and watched with `AddConvarChangeListener` in each resource. `on` sets `w.debug = true` in that resource and prints a warning; anything else turns it off. Set per resource name; the library's own is `w_lib:debug`. A plain `set` only reaches the server side. |
| `<resource>:debug:<moduleFolder>` and `all:debug:<moduleFolder>` | shared | `on` (use `setr`) | Enables `w.debugModules[<moduleFolder>]` in one resource or in every resource that loads that module. The module name is the folder name after alias resolution (`framework-bridge`, `notification`, `prompt-nui`, `raw-keys`, and so on). Listeners are registered when the module loads; later changes apply live with a console notice. |
| `w_lib:locale`, `w_lib:i18n:locale`, `w_lib:userLocales` | shared | locale key (for example `ar`); `0` or `1` for `userLocales` (use `setr`) | The default language is `w_lib:locale`, falling back to `w_lib:i18n:locale`, then `en`. `w_lib:userLocales` (default `1`) lets each player pick a language in the `/w_lib` settings dialog (stored in the client KVP `locale`); set it to `0` to force the server value. The chosen key is what `lib.getLocaleKey()` returns and what consumer NUI frames receive. |
| `w_lib:primaryColor`, `w_lib:primaryShade` | client | colour name and shade number (defaults `wraith` and `1`; use `setr`) | Returned by the `getConfig` NUI callback (in the library and in consumers hosting the shared frame) to theme the UI accent. A colour name the UI has no ramp for is ignored by the UI. |
| `sv_stateBagStrictMode` | server | `true` or `false` | Two seconds after the library's server starts it checks this convar and prints a security warning if it is false. With strict mode on, clients cannot write replicated state bags; the library's client routes entity and player state writes through the internal server callback `w_lib:requestSetStateBag`, which only accepts keys approved by a hook inside the library (`w_lib:setVehicleProperties` and `w_entity_setonground`), so consumers should set replicated state from the server. |
| `w_lib:ignoreSecurityAdvisory` | server | JSON array, for example `["stateBagStrictMode"]` | Suppresses the strict-mode warning when it contains `stateBagStrictMode`. The warning is also suppressed automatically when qb-core is present. |

```lua
# server.cfg
setr w_hud:debug on
setr all:debug:framework-bridge on
setr w_crafting:debug:callback on
setr w_lib:locale ar
setr w_lib:userLocales 1
setr w_lib:primaryColor wraith
setr w_lib:primaryShade 1
setr sv_stateBagStrictMode true
# or, to silence the advisory instead
set w_lib:ignoreSecurityAdvisory ["stateBagStrictMode"]
```

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `/w_lib` | client | none | Registered by the library's client (unrestricted). Opens an input dialog with notification audio (checkbox), notification position (select) and, when `w_lib:userLocales` is `1`, a language select from `GlobalState['w_lib:locales']`. Choices are stored in the library's client KVP; a language change calls `lib.setLocale`, which fires `w_lib:setLocale` and pushes the new strings to the library's frame and to consumer frames hosting the shared UI. |

```lua
-- typed by the player in chat/console
/w_lib
```

## Interface: notifications, dialogs, context menus, text UI, clipboard, sounds, NUI focus

The library draws every piece of its interface in a single NUI frame (`ui_page nui://w_lib/web/build/index.html`). All `lib.<name>` functions in this subsystem are auto-exported by the library, so a consumer resource can call them either as `lib.notify(...)` after loading `@w_lib/init.lua` (which resolves any unknown `lib.<name>` to `exports.w_lib:<name>`) or directly as `exports.w_lib:notify(...)`.

Everything that crosses the export boundary is serialized with msgpack: only strings, numbers, booleans and tables survive. Lua functions are not a supported argument type across that boundary. For context menus this means handlers must be event names: put a string in `ContextMenuItem.event` (client `TriggerEvent`) or `ContextMenuItem.serverEvent` (`TriggerServerEvent`) and register it with `RegisterNetEvent`/`AddEventHandler` in your own resource. Do not rely on `onSelect`, `onExit` or `onBack` from another resource. Some sibling resources do pass `onSelect` closures through `lib.registerContext` and it happens to work because FiveM turns them into function references, but that reference dies when the caller restarts, and the documented contract is event names.

### Three notification systems

There are three different notification systems and their names overlap, which is the most common mistake made with this subsystem.

1. `lib.notify(data)` / `exports.w_lib:notify` is the corner **toast** (title, description, type, position, duration, icon; defaults come from the player's own `/w_lib` settings). The current frame renders only those six fields: `style`, `iconColor`, `iconAnimation`, `alignIcon`, `showDuration` and `id` are accepted by the typings but not drawn.
2. `exports.w_lib:NotifyRaw(data)`, also reachable as `w.notify(data)` on the client and as the client event `RK-text:send`, is the **floating notice** over the world (placement, `useBackground` plate, `variant = 'law'` banner, `meta` readings line, `isRTL`, colours) with an in-game sound played from Lua. `exports.w_lib:Notify(title, message, style, duration)` and the server export `NotifyPlayer(source, ...)` are a fixed-style shortcut onto that same floating notice. Beware: on the server, `w.notify` resolves to the server `lib.notify(playerId, data)`, which sends the toast, not the floating notice.
3. `w.notif.*` (client and server tables; `w.notification` is the same table, and `jo.*` is an alias of `w.*`) posts **native RDR2 feed toasts** through the game's UI feed, with no HTML at all.

Sending `useBackground` or `placement` to `lib.notify` is silently ignored, and sending `type` or `position` to `NotifyRaw` is equally ignored. Also note that the net event `w_lib:notify` has two client handlers registered by the library: one expects a `NotifyProps` table (toast), the other expects `(title, message, style, duration)` strings (floating notice). Triggering it yourself fires both, so prefer the server-side `lib.notify(playerId, data)` (which uses the private event `__w_notify_<yourresource>` handled by your own client half) or `exports.w_lib:NotifyPlayer`.

### Dialogs, menus, text UI, progress, sounds, clipboard, drawn text

Dialogs are modal and one at a time. `lib.alertDialog` and `lib.inputDialog` block the calling coroutine with `Citizen.Await`, take NUI focus with `lib.setNuiFocus(false)` (cursor shown, game input swallowed) and give it back with `lib.resetNuiFocus()` when they close. If a dialog of the same kind is already open the call returns `nil` immediately. Escape always closes them (alert returns `'cancel'`, input returns `nil`) even when no Cancel button is shown; Enter confirms or submits. `lib.inputDialog` also sends a legacy `w_nui_force_focus` message left over from the old multi-iframe shell; the current single frame has no handler for it and focuses the first field itself. The input frame does not enforce `required`, `min`, `max`, `minLength` or `maxLength` on submit; validate the values in Lua.

Context menus (`lib.registerContext` then `lib.showContext`) are non-blocking. Selecting an item closes the menu before running its handlers, and `onExit` is not called on selection, only on close or back-out.

Text UI is a single non-blocking label. `lib.showTextUI` ignores a call whose text equals the currently shown text, even if the options changed, so hide first when only the icon changes. The current text UI frame draws only text, position and icon.

`lib.showProgress` / `lib.setProgress` / `lib.hideProgress` are the script-driven ring used when the consumer resource already owns a clock (for example w_crafting). Nothing times out; a forgotten ring stays until resource restart, so `lib.progressBar` (documented elsewhere) is the safer default.

`lib.playSound(name)` plays one of the frame's six bundled cues by name only (`open`, `close`, `hover`, `select`, `deny`, `finish`); URLs are refused by design.

Clipboard: `lib.setClipboard(value)` and `w.clipboard.copy(value)` both put text on the player's clipboard through the frame. The latter goes through the export `clipboard_copy`, which is registered lazily the first time any resource loads the clipboard module and yields until 1.5 s after that load.

`DrawText2D` / `DrawText3D` are per-frame calls: a 100 ms sweeper removes any text that was not redrawn, so call them from a loop every frame.

Server-side, the txAdmin bridge is off unless the owner sets convar `w_lib:txAdminNotifications 1` and then hides txAdmin's own defaults with the `txAdmin-hideDefault*` convars. `w_lib:progressPropLimit` caps how many props a progress bar may replicate.

### lib.setNuiFocus

```lua
lib.setNuiFocus(allowInput?: boolean, disableCursor?: boolean)
```

Side: client

Parameters:
- `allowInput` (boolean, optional): passed to `SetNuiFocusKeepInput`. `true` keeps game input (keyboard/controls) flowing while the frame has focus; `false`/`nil` swallows it.
- `disableCursor` (boolean, optional): `true` hides the mouse cursor (`SetNuiFocus(true, false)`); `false`/`nil` shows it (`SetNuiFocus(true, true)`).

Returns: nothing

Gives NUI focus to the frame and remembers the `SetNuiFocusKeepInput` state that was active before the call so `lib.resetNuiFocus` can restore it. Every library dialog and menu calls this internally with `(false)`, meaning cursor shown and game input blocked. Calling it while a library dialog is open overrides that dialog's focus. From a consumer resource this resolves to `exports.w_lib:setNuiFocus`.

```lua
lib.setNuiFocus(true, true) -- frame focused, game input still works, no cursor
-- ... later
lib.resetNuiFocus()
```

### lib.resetNuiFocus

```lua
lib.resetNuiFocus()
```

Side: client

Parameters: none

Returns: nothing

Calls `SetNuiFocus(false, false)` and restores the keep-input flag captured at the last `lib.setNuiFocus` call. Called automatically when alert and input dialogs and context menus close.

```lua
lib.resetNuiFocus()
```

### lib.notify (client)

```lua
lib.notify(data: NotifyProps | string)
```

Side: client

Parameters:
- `data` (table | string, required): toast description. A plain string is accepted and becomes `{ description = string }`. Any other non-table value is ignored. Your table is not mutated (a copy is sent).
  - `title` (string, optional): bold first line.
  - `description` (string, optional): body text; newlines become line breaks and inline HTML is rendered.
  - `duration` (number, optional, default 3000): milliseconds before the toast fades.
  - `position` (`'top'|'top-right'|'top-left'|'bottom'|'bottom-right'|'bottom-left'|'center-right'|'center-left'`, optional): default is the player's `/w_lib` setting (KVP `notification_position`, initially `'top-right'`). Several positions can be on screen at once.
  - `type` (`'info'|'warning'|'success'|'error'`, optional): colour class of the toast and the fallback icon (success = tick, error = cross, warning = lock; omitted = `'inform'` with a star; `'info'` also gets the star).
  - `icon` (string | `{IconProp, string}`, optional): a library texture name (`'tick'`, `'cross'`, `'warning'`, `'lock'` ...), a FontAwesome-style name (`'fa-id-card'` or `'fas fa-id-card'`; the prefix is stripped and the last word is used), a `nui://` or http image URL, or a `{prefix, name}` pair (second element used).
  - `id` (string | number, optional): carried to the frame but unused; every call adds a new toast, nothing is replaced or deduplicated.
  - `showDuration` (boolean, optional): accepted, not rendered.
  - `style` (table, optional): accepted, not rendered by the current frame.
  - `iconAnimation` (string, optional): accepted, not rendered.
  - `iconColor` (string, optional): accepted, not rendered.
  - `alignIcon` (`'top'|'center'`, optional): accepted, not rendered.
  - `sound` (`{ bank?: string, set: string, name: string }`, optional): in-game sound played with `PlaySoundFrontend(name, set)`; `bank` is requested and released around it. Only plays when the player has enabled notification audio in `/w_lib` (off by default). The field is stripped before reaching the frame.

Returns: nothing

Shows the corner toast in the library's frame (NUI action `notify`). Fields the floating notice understands (`useBackground`, `placement`, `meta`, `isRTL`, `titleColor` ...) are silently ignored here; use `exports.w_lib:NotifyRaw` for those. Also registered as the client net event `w_lib:notify` (see the Events table for the double-handler caveat). From a consumer resource this resolves to `exports.w_lib:notify(data)`.

```lua
lib.notify({
    title = 'Water',
    description = 'You filled the canteen.',
    type = 'success',
    duration = 4000,
    icon = 'tick',
})
-- or the short form
lib.notify('Not enough money')
```

### lib.notify (server)

```lua
lib.notify(playerId: number, data: NotifyProps)
```

Side: server

Parameters:
- `playerId` (number, required): server id of the target player (`-1` is passed straight to `TriggerClientEvent` and reaches everyone).
- `data` (table, required): the same `NotifyProps` table as the client `lib.notify` (title, description, type, duration, position, icon, id, sound ...). On the client, `title` and `description` are run through your resource's `locale()`: if either matches a key in your `locales/<lang>.json` the translation is used, otherwise the raw text is kept (`locale()` returns its input for unknown keys). No placeholder arguments are supported.

Returns: nothing

Server half of the consumer resource's copy of the library (defined in `@w_lib/init.lua`, not an export of the library). It triggers the private net event `__w_notify_<yourresource>` on the target; the client half of the same `init.lua` in your resource handles it and calls `exports.w_lib:notify`. Requirement: `@w_lib/init.lua` must be loaded as a `shared_script` (both sides) of your resource. Marked deprecated in the annotations but fully functional; this is the recommended server-to-client toast path. `w.notify` on the server resolves to this same function.

```lua
-- server
RegisterNetEvent('myres:server:buy', function(item)
    local src = source
    lib.notify(src, { type = 'success', description = ('Bought %s'):format(item) })
end)
```

### lib.defaultNotify

```lua
lib.defaultNotify(data: { title?: string, description?: string, duration?: number, position?: NotificationPosition, status?: 'info'|'inform'|'warning'|'success'|'error', id?: number })
```

Side: client

Parameters:
- `data` (table, required): v3-style toast props. `data.status` is copied to `data.type` (`'inform'` is mapped to `'info'`) and the table is passed to `lib.notify`. The table you pass is mutated in place (`type` is set). Must be a table; a string is not accepted here.
  - `title` (string, optional)
  - `description` (string, optional)
  - `duration` (number, optional, default 3000)
  - `position` (NotificationPosition, optional): default from `/w_lib` settings.
  - `status` (`'info'|'inform'|'warning'|'success'|'error'`, optional): becomes `type`.
  - `id` (number, optional): unused by the frame.

Returns: nothing

Backwards-compatible wrapper for scripts that still use the ox_lib v3 `status` field. Also bound to the client net event `w_lib:defaultNotify`.

```lua
lib.defaultNotify({ title = 'Bank', description = 'Deposit complete', status = 'inform' })
```

### exports.w_lib:NotifyRaw

```lua
exports.w_lib:NotifyRaw(data: table)
```

Side: client

Parameters:
- `data` (table, required): floating-notice payload (the former standalone w_notify). Every field is optional but the argument must be a table.
  - `title` (string, optional, default `''`): first line.
  - `description` (string, optional, default `''`): second line, typed out at 20 ms per character; newlines become line breaks and inline HTML is allowed.
  - `icon` (string, optional, default `''`): library texture name (`'tick'`, `'cross'`, `'warning'`, `'lock'` ...), a FontAwesome-style name, or a full `nui://` / http image URL; empty shows no icon.
  - `image` (string, optional): a picture shown in place of the icon, for example an item's own image (`nui://vorp_inventory/html/img/items/<name>.png`). When it is set, the icon slot shows the picture only, and no state icon is added for the notice. If the picture fails to load it is hidden and the text is shown on its own.
  - `placement` (`'top-left'|'top-center'|'top-right'|'middle-left'|'middle-center'|'middle-right'|'bottom-left'|'bottom-center'|'bottom-right'`, optional, default `'middle-right'`): where the notice appears; several placements can hold notices at once; ignored when `variant = 'law'` (always top-center).
  - `duration` (number, optional, default 5000): milliseconds on screen.
  - `useBackground` (boolean, optional, default false): `true` draws a plate behind the text (the banner look) and switches the default sound to the menu-open cue.
  - `variant` (`'law'`, optional): wanted/witness banner style (red name over a white rule), pinned top-center, default sound `Objective_Sounds/FAIL`; the plate is not drawn for this variant.
  - `meta` (string | `{ text: string, color?: string }[]`, optional): a third readings line (clock, temperature, wind ...). A string is drawn as-is; parts are joined with `|` and may carry their own CSS colour. Always drawn left-to-right.
  - `contentAlignment` (string, optional, default `'center'`): CSS `text-align` for the text block.
  - `isRTL` (boolean, optional, default false): right-to-left layout.
  - `titleColor` (string, optional, default `'#ffffff'`): CSS colour of the title.
  - `descriptionColor` (string, optional, default `'rgba(255, 255, 255, 0.8)'`): CSS colour of the description.
  - `sound` (string | false, optional): `false` silences this notice; a string names another game sound. Default: `Ledger_Sounds/INFO_SHOW` for a plain notice, `HUD_PLAYER_MENU/MENU_ENTER` when `useBackground` is true, `Objective_Sounds/FAIL` for variant `'law'`.
  - `soundSet` (string, optional): sound set for the `sound` override; defaults to the set matching the default sound.

Returns: nothing

Low-level entry to the floating notice drawn over the world (NUI action `showNotification`). The sound is played from Lua with `PlaySoundFrontend` at the player's game volume, before the frame is told anything. Reachable in a consumer resource as `w.notify(data)` on the client (alias installed by `@w_lib/init.lua`) and as the client event `RK-text:send`. Do not confuse with `lib.notify`: this one ignores `type`/`position`, that one ignores `placement`/`useBackground`.

```lua
exports.w_lib:NotifyRaw({
    title = 'Valentine',
    description = 'The Heartlands, New Hanover',
    meta = { { text = '7:42 PM' }, { text = '12 C', color = '#8fb8ff' } },
    useBackground = true,
    placement = 'top-center',
    duration = 6000,
})

-- plain notice, no plate, silenced
exports.w_lib:NotifyRaw({ title = 'Refused', description = 'Not enough on you.', icon = 'cross', titleColor = '#e74c3c', sound = false })
```

### w.notify

```lua
w.notify(data: table)
```

Side: client

Parameters:
- `data` (table, required): exactly the `NotifyRaw` table (title, description, icon, image, placement, duration, useBackground, variant, meta, contentAlignment, isRTL, titleColor, descriptionColor, sound, soundSet).

Returns: nothing

Consumer-side alias (also `jo.notify`) installed by `@w_lib/init.lua` that forwards to `exports.w_lib:NotifyRaw(data)` on the client. This is the floating notice, not the corner toast. On the server the alias table is empty, so `w.notify` falls through to the server `lib.notify(playerId, data)` from the same `init.lua`: a different function with a different signature that sends the corner toast. Do not assume the same call works on both sides.

```lua
w.notify({
    title = 'Hunger', description = '', icon = 'tick',
    placement = 'middle-right', duration = 5000, useBackground = false,
    contentAlignment = 'center', isRTL = true,
    titleColor = '#34b895', descriptionColor = 'rgba(255,255,255,0.8)',
})
```

### exports.w_lib:Notify and exports.w_lib:NotifyPlayer

```lua
exports.w_lib:Notify(title: string, message: string, style?: 'success'|'error'|'info', duration?: number)          -- client
exports.w_lib:NotifyPlayer(source: number, title: string, message: string, style?: 'success'|'error'|'info', duration?: number)  -- server
```

Side: `Notify` is client; `NotifyPlayer` is server

Parameters:
- `source` (number, required, `NotifyPlayer` only): target server id; `nil` is ignored (`-1` would broadcast).
- `title` (string, required): first line (`nil` becomes `''`).
- `message` (string, required): second line (`nil` becomes `''`).
- `style` (string, optional): `'success'` (tick icon, `#34b895`), `'error'` (cross, `#e74c3c`) or `'info'` (warning icon, `#3498db`). Anything else gets the warning icon and `#3498db`.
- `duration` (number, optional): milliseconds, default 5000.

Returns: nothing

`Notify` is a fixed-style shortcut onto the floating notice: it raises `RK-text:send` with placement `'middle-right'`, no plate, centered content and `isRTL = true`, so the default `Ledger_Sounds/INFO_SHOW` chime plays. Use `NotifyRaw` when you need control over placement, direction or sound.

`NotifyPlayer` is the server counterpart: it triggers `w_lib:notify` on the target with positional arguments. Because that event also has the toast handler, the player additionally sees a small corner toast whose description is the title string.

```lua
-- client
exports.w_lib:Notify('Stable', 'Horse sold', 'success', 4000)

-- server
exports.w_lib:NotifyPlayer(source, 'Bank', 'Deposit complete', 'success')
```

### w.notif.* (client)

Native RDR2 feed toasts through the game's UI feed. Module `notification`, alias `notif`: `w.notif` and `w.notification` are the same table and load lazily on first access; `jo.notif.*` is the same set.

```lua
w.notif.right(text: string, dict?: string, icon?: string, color?: string, duration?: number, soundset_ref?: string, soundset_name?: string)
w.notif.left(title: string, text: string, dict: string, icon: string, color?: string, duration?: number, soundset_ref?: string, soundset_name?: string)
w.notif.rightSuccess(text: string): true
w.notif.rightError(text: string): false
w.notif.simpleTop(title: string, subtitle: string, duration?: number)
```

Side: client

Parameters (shared by `right` and `left`):
- `title` (string, required, `left` only): bold title line.
- `text` (string, required): notification text (anything the game font can draw). Non-strings are `tostring`'ed.
- `dict` (string, optional for `right`, required for `left`): streamed texture dictionary of the icon (for example `'hud_textures'`, `'menu_textures'`, `'blips_mp'`). Requested and awaited before posting when given and it exists. For `left`, `nil` is tolerated (becomes `''` and no icon loads).
- `icon` (string, optional for `right`, required for `left`): texture name inside `dict` (for example `'check'`, `'cross'`).
- `color` (string, optional): game colour label, default `'COLOR_WHITE'` (for example `'COLOR_GREEN'`, `'COLOR_RED'`).
- `duration` (number, optional): milliseconds, default 3000.
- `soundset_ref` (string, optional): sound set, default `'Transaction_Feed_Sounds'`.
- `soundset_name` (string, optional): sound name, default `'Transaction_Positive'`.

Parameters for `simpleTop`:
- `title` (string, required): large title (native mission start/end shard).
- `subtitle` (string, required): smaller line under it.
- `duration` (number, optional): milliseconds, default 3000.

| Function | Returns | Behaviour |
|---|---|---|
| `w.notif.right` | nothing | Right-side feed toast (`UiFeedPostSampleToastRight`). Clears all feed channels first, so it replaces any native toast currently showing. |
| `w.notif.left` | nothing | Left-side feed toast with title and icon (`UiFeedPostSampleToast`). Clears all feed channels first. |
| `w.notif.rightSuccess` | always `true` | `w.notif.right` with a green check (`'hud_textures'`/`'check'`, `COLOR_GREEN`) and the default positive sound. Usable as `return w.notif.rightSuccess(msg)`. |
| `w.notif.rightError` | always `false` | `w.notif.right` with a red cross (`'menu_textures'`/`'cross'`, `COLOR_RED`) and the `'Transaction_Negative'` sound. Usable as `return w.notif.rightError(msg)`. |
| `w.notif.simpleTop` | nothing | Two-text shard at the top of the screen (`UiFeedPostTwoTextShard`). Does not clear other feed channels. |

```lua
w.notif.right('Saddle equipped', 'hud_textures', 'check', 'COLOR_GREEN', 3000)
w.notif.left('Mail', 'A letter arrived', 'blips_mp', 'blip_mp_mail', 'COLOR_WHITE', 4000)
if money < price then return w.notif.rightError('Not enough money') end
return w.notif.rightSuccess('Purchase complete')
w.notif.simpleTop('Bounty claimed', '$45.00', 4000)
```

### w.notif.* (server)

```lua
w.notif.right(source: number, text: string, dict?: string, icon?: string, color?: string, duration?: number, soundset_ref?: string, soundset_name?: string)
w.notif.left(source: number, title: string, text: string, dict: string, icon: string, color?: string, duration?: number, soundset_ref?: string, soundset_name?: string)
w.notif.rightSuccess(source: number, text: string): true
w.notif.rightError(source: number, text: string): false
w.notif.simpleTop(source: number, title: string, subtitle: string, duration?: number)
w.notif.print(source: number, ...: any)
```

Side: server

Parameters:
- `source` (number, required): target server id (`-1` broadcasts for `right`).
- All remaining arguments are forwarded unchanged to the matching client `w.notif.*` function; `print` takes any values to print in that player's F8 console.

| Function | Returns | Event triggered on the target |
|---|---|---|
| `w.notif.right` | nothing | `<yourresource>:client:notif` |
| `w.notif.left` | nothing | `<yourresource>:client:notifLeft` |
| `w.notif.rightSuccess` | always `true` | green-check right toast |
| `w.notif.rightError` | always `false` | red-cross right toast. Unlike the client version it does not pass the `'Transaction_Negative'` sound, so the default positive sound plays. |
| `w.notif.simpleTop` | nothing | `<yourresource>:client:simpleTop` |
| `w.notif.print` | nothing | `<yourresource>:client:notifPrint` (debug helper) |

The client half of the same module in your resource shows the native toast. Both sides of your resource must load the notification module (`w.notif` or `w.require('notification')`) for this to work.

```lua
w.notif.right(source, 'Item received', 'hud_textures', 'check', 'COLOR_GREEN')
w.notif.left(source, 'Sheriff', 'Report to the office', 'blips_mp', 'blip_mp_sheriff')
if not ok then return w.notif.rightError(source, 'No permission') end
w.notif.simpleTop(source, 'Round over', 'You won', 5000)
w.notif.print(source, 'debug', json.encode(payload))
```

### lib.alertDialog

```lua
lib.alertDialog(data: AlertDialogProps, timeout?: number): 'confirm' | 'cancel' | nil
```

Side: client

Parameters:
- `data` (table, required): dialog content and layout.
  - `header` (string, required): title line.
  - `content` (string, required): body, rendered as Markdown (GFM: bold, links, lists, tables); raw HTML is escaped.
  - `size` (`'xs'|'sm'|'md'|'lg'|'xl'`, optional): `xs`/`sm` narrow the plate, `lg`/`xl` widen it, anything else is the default width.
  - `cancel` (boolean, optional): show a Cancel button in addition to Confirm.
  - `labels` (`{ cancel?: string, confirm?: string }`, optional): button captions; giving `labels.cancel` shows the Cancel button even without `cancel = true`.
  - `centered` (boolean, optional): accepted, ignored by the current frame (the dialog is always centered).
  - `overflow` (boolean, optional): accepted, ignored by the current frame.
- `timeout` (number, optional): milliseconds after which the dialog is force-closed with reason `'timeout'`. A reason rejects the pending promise, which surfaces as a Lua error in the coroutine awaiting `lib.alertDialog`; wrap the call in `pcall` when you use `timeout`.

Returns: `'confirm'` or `'cancel'` (what the player pressed; Enter counts as confirm and Escape as cancel even when no Cancel button is shown); `nil` if an alert was already open or if `lib.closeAlertDialog()` was called without a reason.

Blocking confirmation box. Takes NUI focus (cursor visible, game input blocked) until closed. Only one alert can be open; a second call returns `nil` at once. Also exposed as the client net event `w_lib:alertDialog` (used by the txAdmin warn bridge).

```lua
local answer = lib.alertDialog({
    header  = 'Delete room',
    content = 'This **cannot** be undone.',
    cancel = true,
    labels = { confirm = 'Delete', cancel = 'Keep' },
})
if answer ~= 'confirm' then return end
```

### lib.closeAlertDialog

```lua
lib.closeAlertDialog(reason?: string)
```

Side: client

Parameters:
- `reason` (string, optional): when given, the waiting `lib.alertDialog` call is rejected with this string (raises in the awaiting coroutine). When `nil`, it resolves with `nil`.

Returns: nothing

Closes the open alert dialog from script and restores NUI focus. No-op when nothing is open.

```lua
lib.closeAlertDialog() -- caller of lib.alertDialog receives nil
```

### lib.inputDialog

```lua
lib.inputDialog(heading: string, rows: (string | InputDialogRowProps)[], options?: { allowCancel?: boolean, size?: 'xs'|'sm'|'md'|'lg'|'xl' }): any[] | nil
```

Side: client

Parameters:
- `heading` (string, required): dialog title.
- `rows` (table, required): array of rows in display order. A plain string is shorthand for `{ type = 'input', label = string }`. Your table is not mutated (a normalized copy is sent). Fields the current frame actually renders are described; the others are accepted by the typings and ignored.
  - `type` (`'input'|'number'|'checkbox'|'select'|'slider'|'multi-select'|'date'|'date-range'|'time'|'textarea'|'color'`, required): field kind; `date-range` is drawn as a plain text box.
  - `label` (string, required): field caption.
  - `description` (string, optional): helper text under the label.
  - `placeholder` (string, optional): input/number/textarea placeholder.
  - `default` (string | number, optional): initial value; for select the option value; for date `'YYYY-MM-DD'`, for time `'HH:MM'`, for color `'#rrggbb'`. An untouched field submits this value (`''` when absent).
  - `disabled` (boolean, optional): render read-only.
  - `required` (boolean, optional): draws a red asterisk only; submit is not blocked.
  - `icon` (string | `{IconProp, string}`, optional): leading icon in the label (texture name, FontAwesome name or URL).
  - `password` (boolean, optional, input only): mask the text.
  - `min` / `max` (number, optional, number/slider): set as attributes; enforced only by the +/- stepper buttons and the slider, not on typed values. Slider defaults 0-100.
  - `step` (number, optional, number/slider): increment, default 1.
  - `minLength` / `maxLength` (number, optional, input/textarea/date/time/color): set as attributes; typing beyond `maxLength` is prevented by the browser, `minLength` is not enforced on submit.
  - `checked` (boolean, optional, checkbox): initial state.
  - `options` (`{ value: string, label: string }[]` or plain `string[]`, required for select/multi-select): choices; a plain string is used as both value and label.
  - `iconColor`, `autosize`, `searchable`, `clearable`, `maxSelectedValues`, `format`, `returnString`: accepted, ignored by the current frame.
- `options` (table, optional): dialog-level options (a single table, despite the annotation's `[]` suffix).
  - `allowCancel` (boolean, optional, default true): `false` hides the Cancel button. Escape still closes the dialog and returns `nil` either way.
  - `size` (`'xs'|'sm'|'md'|'lg'|'xl'`, optional): `xs`/`sm` narrow, `lg`/`xl` widen, otherwise default width.

Returns: array of values in row order: string for input/textarea/password; number when the row is `'number'` and was changed with the +/- buttons or left at a numeric default, but a string when the player typed it (always `tonumber()` it); boolean for checkbox; option value string for select (`''` when nothing chosen); array of value strings for multi-select; number for slider; `'YYYY-MM-DD'` string for date, `'HH:MM'` for time, `'#rrggbb'` for color; string for date-range. `nil` when cancelled (button or Escape), closed by `lib.closeInputDialog`, or when another input dialog was already open.

Blocking form. Takes NUI focus (cursor shown, game input blocked) and gives it back on submit, cancel or close. Also sends a legacy `w_nui_force_focus` message that the current single-frame build ignores; the frame focuses the first field itself. Enter submits from any single-line field (not from a textarea). Only one input dialog at a time. Values are indexed by row position, so read `input[1]`, `input[2]` ... in the order you declared rows. Validate required/min/max yourself.

```lua
local input = lib.inputDialog('Sell amount', {
    { type = 'number', label = 'Amount', description = 'Max 50', default = 50, min = 1, max = 50 },
    { type = 'select', label = 'Buyer', options = { { value = 'bank', label = 'Bank' }, { value = 'fence', label = 'Fence' } }, default = 'bank' },
    { type = 'textarea', label = 'Note', maxLength = 128 },
}, { allowCancel = true, size = 'sm' })
if not input then return end
local amount = tonumber(input[1])
local buyer, note = input[2], input[3]
if not amount or amount < 1 or amount > 50 or buyer == '' then return end
```

### lib.closeInputDialog

```lua
lib.closeInputDialog()
```

Side: client

Parameters: none

Returns: nothing

Closes an open input dialog from script; the waiting `lib.inputDialog` call returns `nil`. Restores NUI focus. No-op when nothing is open.

```lua
lib.closeInputDialog()
```

### lib.registerContext

```lua
lib.registerContext(context: ContextMenuProps | ContextMenuProps[])
```

Side: client

Parameters:
- `context` (table, required): one menu definition, or an array of definitions (each registered under its own id). Registering an existing id replaces it. The definition is stored as-is; from a consumer resource it arrives through the export boundary, so function fields are not a supported contract.
  - `id` (string, required): unique menu id used by `lib.showContext` and by other menus' `menu` fields.
  - `title` (string, required): header text.
  - `menu` (string, optional): id of the parent menu; the frame shows a Back control instead of the close cross and opens the parent when pressed.
  - `canClose` (boolean, optional): `false` hides the close control and makes Escape play the deny sound instead of closing; you must close it from script (`lib.hideContext`).
  - `onExit` (function, optional): called when the player closes the menu or `lib.hideContext(true)` is called; not called when an item is selected or when Back is pressed. Not supported across the export boundary.
  - `onBack` (function, optional): called when the player presses Back, before the parent opens. Same boundary caveat.
  - `options` (`ContextMenuItem[]` | `{ [title: string]: ContextMenuItem }`, required): items. An array keeps your order; a keyed table uses the key as the item title and is sent sorted by key. Item fields:
    - `title` (string, optional in array form; the key in table form): item caption.
    - `description` (string, optional): second line.
    - `icon` (string | `{IconProp, string}`, optional): texture name, FontAwesome name or URL; an empty slot shows a faint bar so the column stays aligned.
    - `image` (string, optional): image URL drawn in the icon slot instead of `icon` (takes precedence over `icon`).
    - `iconColor` (string, optional): accepted, not applied by the current frame.
    - `progress` (number, optional): 0-100 progress bar inside the item.
    - `arrow` (boolean, optional): show a chevron (also shown automatically when `menu` is set).
    - `metadata` (string | `string[]` | `{ label: string, value?: any }[]` | `{ [label]: value }`, optional): extra lines under the description.
    - `disabled` (boolean, optional): greyed, not clickable.
    - `readOnly` (boolean, optional): not clickable, drawn normally.
    - `menu` (string, optional): id of the submenu to open on click (opened via `lib.showContext`; the menu does not close and no handler runs).
    - `event` (string, optional): client event name; `TriggerEvent(event, args)` on click.
    - `serverEvent` (string, optional): server event name; `TriggerServerEvent(serverEvent, args)` on click.
    - `args` (any, optional): single value passed to `onSelect`/`event`/`serverEvent`.
    - `onSelect` (function(args), optional): callback on click; only reliable inside the library itself. From another resource use `event`/`serverEvent` strings.

Returns: nothing

Stores menu definitions by id; nothing is shown until `lib.showContext(id)`. Clicking an item that has none of `onSelect`/`event`/`serverEvent` (and no `menu`) does nothing and leaves the menu open. When one of them is set the menu closes and focus is released before the handlers run, in the order `onSelect`, `event`, `serverEvent`. From a consumer resource this call crosses the export boundary, so handlers must be event names, not functions.

```lua
lib.registerContext({
    id = 'myres:main',
    title = 'Stable',
    options = {
        { title = 'Horses', description = 'Your animals', icon = 'horse', menu = 'myres:horses' },
        { title = 'Sell horse', icon = 'cross', serverEvent = 'myres:server:sell', args = { horseId = 3 } },
        { title = 'Rename', event = 'myres:client:rename', args = 3 },
        { title = 'Balance: $12', disabled = true },
    },
})
lib.registerContext({ id = 'myres:horses', menu = 'myres:main', title = 'Horses', options = {} })
lib.showContext('myres:main')

RegisterNetEvent('myres:client:rename', function(horseId)
    local input = lib.inputDialog('Rename', { 'New name' })
    if input then TriggerServerEvent('myres:server:rename', horseId, input[1]) end
end)
```

### lib.showContext

```lua
lib.showContext(id: string)
```

Side: client

Parameters:
- `id` (string, required): id of a menu previously passed to `lib.registerContext`. Unknown ids raise the error `No context menu of such id found.`

Returns: nothing

Opens the registered menu (title, `canClose`, parent menu and options are sent to the frame; keyed option tables are sorted by key) and takes NUI focus. Opening a menu while another is open simply replaces it. Non-blocking.

```lua
lib.showContext('myres:main')
```

### lib.hideContext

```lua
lib.hideContext(onExit?: boolean)
```

Side: client

Parameters:
- `onExit` (boolean, optional): `true` also runs the open menu's `onExit` callback (if it has one and it is reachable).

Returns: nothing

Closes the currently open context menu from script. Note that it always calls `lib.resetNuiFocus()` first, even when no menu is open, so it will drop NUI focus held by something else.

```lua
lib.hideContext(true)
```

### lib.getOpenContextMenu

```lua
lib.getOpenContextMenu(): string | nil
```

Side: client

Parameters: none

Returns: id of the open context menu, or `nil`.

Reports which registered menu is currently displayed. Becomes `nil` as soon as an item with a handler is clicked or the menu is closed.

```lua
if lib.getOpenContextMenu() == 'myres:main' then lib.hideContext() end
```

### lib.showTextUI

```lua
lib.showTextUI(text: string, options?: TextUIOptions)
```

Side: client

Parameters:
- `text` (string, required): label text (newlines become line breaks, inline HTML is rendered). If it equals the text currently shown the call is ignored entirely (options are not re-applied).
- `options` (table, optional): appearance. The table you pass is mutated (`options.text` is set) and sent as-is to the frame.
  - `position` (`'right-center'|'left-center'|'top-center'|'bottom-center'`, optional, default `'right-center'`)
  - `icon` (string | `{IconProp, string}`, optional): texture name, FontAwesome-style name (for example `'fa-id-card'`), or image URL.
  - `iconColor` (string, optional): accepted, not rendered by the current frame.
  - `iconAnimation` (string, optional): accepted, not rendered.
  - `style` (string | table, optional): accepted, not rendered.
  - `alignIcon` (`'top'|'center'`, optional): accepted, not rendered.

Returns: nothing

Shows a persistent hint label (for example "Press E to buy a licence"). Non-blocking and does not take focus. Track your own open/closed state in point loops so you do not call it every frame.

```lua
local shown = false
local function onNearby(point)
    if point.currentDistance < 1.2 then
        if not shown then
            shown = true
            lib.showTextUI('[E] Buy licence', { icon = 'fa-id-card', position = 'right-center' })
        end
    elseif shown then
        shown = false
        lib.hideTextUI()
    end
end
```

### lib.hideTextUI and lib.isTextUIOpen

```lua
lib.hideTextUI()
lib.isTextUIOpen(): boolean, string | nil
```

Side: client

Parameters: none

Returns: `lib.hideTextUI` returns nothing. `lib.isTextUIOpen` returns an `isOpen` boolean and the currently shown text (`nil` when closed).

`lib.hideTextUI` hides the text UI and clears the remembered text so the next `lib.showTextUI` with the same string is shown again. `lib.isTextUIOpen` reports the text UI state as tracked by the library on this client.

```lua
local open, text = lib.isTextUIOpen()
if open and text ~= myText then lib.hideTextUI() end
```

### lib.showProgress

```lua
lib.showProgress(data?: { label?: string, position?: 'middle'|'bottom' })
```

Side: client

Parameters:
- `data` (table, optional): options for the script-driven progress ring.
  - `label` (string, optional): text under the ring; `nil` shows no label.
  - `position` (`'middle'|'bottom'`, optional, default `'bottom'`): where the ring sits on screen; any value other than `'middle'` is drawn at the bottom.

Returns: nothing

Opens a progress ring that your script fills: it is sent with duration 0 and `driven = true`, so the frame paints 0% and does not move until `lib.setProgress` is called. Nothing times it out and the frame never reports completion; if you forget `lib.hideProgress` the ring stays until the resource restarts. Calling it while `lib.progressBar` is running replaces that bar's ring in the frame. Use `lib.progressBar` instead when the duration is known up front.

```lua
lib.showProgress({ label = 'Smelting', position = 'bottom' })
CreateThread(function()
    local startedAt, duration = GetGameTimer(), 6000
    while lib.drivenProgressActive() do
        local pct = math.min(math.floor((GetGameTimer() - startedAt) / duration * 100), 100)
        lib.setProgress(pct)
        if pct >= 100 then lib.hideProgress() end
        Wait(100)
    end
end)
```

### lib.setProgress, lib.hideProgress and lib.drivenProgressActive

```lua
lib.setProgress(value: number)
lib.hideProgress()
lib.drivenProgressActive(): boolean
```

Side: client

Parameters:
- `value` (number, required, `setProgress` only): percentage 0-100. Clamped into that range; anything `tonumber()` cannot convert becomes 0.

Returns: `setProgress` and `hideProgress` return nothing; `drivenProgressActive` returns `true` between `lib.showProgress` and `lib.hideProgress`.

| Function | Behaviour |
|---|---|
| `lib.setProgress` | Pushes the current percentage to the driven ring (NUI action `progressValue`). Silently does nothing unless `lib.showProgress` is currently active. Call as often as you like; the frame paints it without re-rendering. |
| `lib.hideProgress` | Closes the driven ring (sends `progressCancel`) and clears the driven flag. No-op when no driven ring is active. This is the only way the ring goes away. |
| `lib.drivenProgressActive` | Reports whether a script-driven progress ring is currently open. Independent of `lib.progressActive` (the timed bar). |

```lua
lib.setProgress(45)
if lib.drivenProgressActive() then lib.hideProgress() end
```

### lib.playSound

```lua
lib.playSound(name: 'open'|'close'|'hover'|'select'|'deny'|'finish')
```

Side: client

Parameters:
- `name` (string, required): one of the frame's bundled cue names: `'open'` (menu_open), `'close'` (menu_close), `'hover'` (button click, throttled to one per 70 ms), `'select'` (selected), `'deny'` (same file as hover, quieter), `'finish'` (coins). Anything that is not a string is ignored; an unknown name plays nothing. Paths and URLs are deliberately not accepted.

Returns: nothing

Plays one of the library's own UI sounds through the NUI frame (sent as action `playSound`). Intended for a resource driving a library panel that has moments the panel does not know about (a craft starting or finishing), so it does not ship a second audio layer. The library's own menus already play these on open, close, hover and select. The sound is played by the browser, so it does not follow the game's volume setting.

```lua
lib.showProgress({ label = 'Crafting...', position = 'bottom' })
lib.playSound('select')
-- when the work lands:
lib.hideProgress()
lib.playSound('finish')
```

### lib.setClipboard, w.clipboard.copy and exports.w_lib:clipboard_copy

```lua
lib.setClipboard(value: string)
w.clipboard.copy(value: string): boolean
exports.w_lib:clipboard_copy(value: string): boolean
```

Side: client

Parameters:
- `value` (string, required): text to place on the player's system clipboard.

Returns: `lib.setClipboard` returns nothing; `w.clipboard.copy` and `clipboard_copy` return `true` once the message was sent.

| Function | Behaviour |
|---|---|
| `lib.setClipboard` | Sends action `setClipboard` to the library's frame, which writes the text to the clipboard with `document.execCommand('copy')`. Fire-and-forget; no confirmation and no waiting for the frame. |
| `w.clipboard.copy` | Module-layer helper (also `jo.clipboard.copy`). Accessing `w.clipboard` in a consumer resource lazily loads the clipboard module in your resource and asks the library to load its global half, which registers the export `clipboard_copy`. The call then goes through `exports.w_lib:clipboard_copy(value)`, which yields until 1.5 s after that global half was loaded, then posts `{ type = 'copy', value }` to the frame. Same end result as `lib.setClipboard`, but can block briefly on the first call. |
| `exports.w_lib:clipboard_copy` | Raw export behind `w.clipboard.copy`. Registered lazily: it only exists inside the library once any resource has required the clipboard module (`w.clipboard` or `w.require('clipboard')`). Calling the export before that raises a missing-export error. Prefer `w.clipboard.copy` or `lib.setClipboard`. |

```lua
lib.setClipboard(('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))

w.clipboard.copy(json.encode(vector3(x, y, z)))

w.require('clipboard') -- makes sure the export exists
exports.w_lib:clipboard_copy('hello')
```

### exports.w_lib:DrawText2D and w.drawText2D

```lua
exports.w_lib:DrawText2D(text: string)
w.drawText2D(text: string)
```

Side: client

Parameters:
- `text` (string, required): text to draw in the frame's single 2D text slot (rendered as HTML, so inline markup and non-Latin scripts work, unlike native `DrawText`).

Returns: nothing

Shows a screen-space text through NUI (action `drawText2D`). Must be called every frame: a 100 ms sweeper sends `removeText2D` as soon as a sweep passes without a call. `w.drawText2D` is the consumer alias installed by `@w_lib/init.lua` (also `jo.drawText2D`); client only, on the server the name resolves to nothing.

```lua
CreateThread(function()
    while editing do
        exports.w_lib:DrawText2D('Editing: press Enter to save')
        Wait(0)
    end
end)

w.drawText2D('Hold F to cancel')
```

### exports.w_lib:DrawText3D and w.drawText3D

```lua
exports.w_lib:DrawText3D(x: number, y: number, z: number, text: string, customId?: string)
w.drawText3D(x: number, y: number, z: number, text: string, customId?: string)
```

Side: client

Parameters:
- `x`, `y`, `z` (number, required): world position.
- `text` (string, required): text to draw at the projected screen position (HTML allowed).
- `customId` (string, optional): stable id for this label. Default is the concatenated coordinates, which means a label following a moving entity gets a new id every frame (flicker); pass your own id for moving targets.

Returns: nothing

Projects a world position to screen (`GetScreenCoordFromWorldCoord`) and draws the text in the frame at that screen fraction; nothing is sent when the point is off screen. Per-frame: labels not redrawn within about 100 ms are removed. `w.drawText3D` is the consumer alias installed by `@w_lib/init.lua` (also `jo.drawText3D`); client only.

```lua
CreateThread(function()
    while true do
        local c = GetEntityCoords(PlayerPedId())
        exports.w_lib:DrawText3D(c.x, c.y, c.z + 1.0, 'You are here', 'myres:me')
        Wait(0)
    end
end)

w.drawText3D(x, y, z + 1.5, 'Horde: 12', 'horde:' .. id)
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:notify` | client | `data: NotifyProps` (handler 1) and `(title, message, style, duration)` (handler 2) | Net event with two client handlers inside the library. Handler 1 passes the first argument to `lib.notify` (a table shows a toast, a string becomes its description). Handler 2 reads the same event as four positional strings and shows the floating notice via the fixed-style `Notify` shortcut (tick/cross/warning icon, middle-right, `isRTL = true`, 5000 ms default). Whatever you send, both run: a table shows the toast and hands the table to the second handler as its title, which the frame cannot render as text; strings show the floating notice and a toast whose description is the first string. The library's txAdmin bridge sends tables here. Prefer server-side `lib.notify(playerId, data)` or `exports.w_lib:NotifyPlayer(...)`. |
| `w_lib:defaultNotify` | client | `data: DefaultNotifyProps` (must be a table; `status` instead of `type`) | Bound directly to `lib.defaultNotify` for v3-style callers. Single handler. |
| `__w_notify_<resource>` | client | `data: NotifyProps` | Internal per-resource net event created by the client half of `@w_lib/init.lua` in every consumer resource (`'__w_notify_'` followed by the resource name). Title and description are localized with `locale()` when your resource has locales loaded, then forwarded to `exports.w_lib:notify(data)`. Exists so server `lib.notify(playerId, data)` lands in the consumer resource's own client context. Never trigger it yourself; it is why server `lib.notify` needs `init.lua` loaded on the client too. |
| `w_lib:alertDialog` | client | `data: AlertDialogProps, timeout?: number` | Bound to `lib.alertDialog` so a server can pop a modal on a client (the txAdmin warn bridge uses it). The player's answer is discarded and not sent back. If an alert is already open the event does nothing. |
| `RK-text:send` | client | `data: table` (same as `NotifyRaw`; must be a table) | Event form of `NotifyRaw`, registered with `RegisterNetEvent` so it can be raised locally on the client or from the server. Kept for scripts written against the old RK-text3d/w_notify resource. Because it is a net event, any client can also trigger it on itself. |
| `<resource>:client:notif`, `:client:notifLeft`, `:client:simpleTop`, `:client:notifPrint` | client | positional arguments identical to `w.notif.right` / `left` / `simpleTop`; `notifPrint` takes any values | Internal transport used by the server-side `w.notif.*` helpers. The event name is prefixed with the resource that loaded the module (inside the library: `w_lib:client:notif`; inside your resource: `<yourresource>:client:notif`), so the server and client halves of the module must be loaded in the same resource. You do not trigger these yourself. |
| `w_lib:progressProps` | server | `props: ProgressPropProps | ProgressPropProps[] | nil` where a prop is `{ model: string (required), bone?: number, pos: vector3 (required), rot: vector3 (required), rotOrder?: number }`; anything that is not a table is stored as `nil` (clears); a single prop table has length 0 and is stored as-is | Triggered by the library's own client progress bar when a bar with `prop` starts (and with `nil` when it ends). Truncates the list to `w_lib:progressPropLimit` and writes it to the player's replicated state bag key `lib:progressProps` so other clients attach the same props. Not normally triggered directly. |

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:txAdminNotifications` | server | integer, default 0 | Master switch for replacing txAdmin's built-in announcement popups with library toasts and alerts. Nothing else in the txAdmin bridge runs unless this is 1 at resource start; all txAdmin convars are read once at start. |
| `txAdmin-hideDefaultAnnouncement` | server | integer | When 1 (and the master switch is 1) the library listens to `txAdmin:events:announcement` and broadcasts a toast to everyone (id `txAdmin:announcement`, title locale `txadmin_announcement` with the author, description = message, 5000 ms). Sent through `w_lib:notify`, so the double-handler caveat applies. Normally set from the txAdmin settings page. |
| `txAdmin-hideDefaultDirectMessage` | server | integer | When 1 the library listens to `txAdmin:events:playerDirectMessage` and sends the target a toast (id `txAdmin:playerDirectMessage`, title locale `txadmin_dm` with the author, 5000 ms). Read only when the master switch is 1. |
| `txAdmin-hideDefaultWarning` | server | integer | When 1 the library listens to `txAdmin:events:playerWarned` and opens an alert dialog on the target via `w_lib:alertDialog` (header locale `txadmin_warn` with the author, content locale `txadmin_warn_content` with reason and action id). Read only when the master switch is 1. |
| `txAdmin-hideDefaultScheduledRestartWarning` | server | integer | When 1 the library listens to `txAdmin:events:scheduledRestart` and broadcasts a toast (id `txAdmin:scheduledRestart`, title locale `txadmin_scheduledrestart`, description = translated message, 5000 ms). Read only when the master switch is 1. |
| `w_lib:progressPropLimit` | server | integer, default 2 | Maximum number of props a single progress bar may attach and replicate to other players; extra entries are truncated. Read once at server start and applied to every `w_lib:progressProps` update. |

```lua
-- server.cfg
set w_lib:txAdminNotifications 1
set txAdmin-hideDefaultAnnouncement 1
set txAdmin-hideDefaultDirectMessage 1
set txAdmin-hideDefaultWarning 1
set txAdmin-hideDefaultScheduledRestartWarning 1
set w_lib:progressPropLimit 3
```

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `/w_lib` | client | none | Opens an input dialog (via `lib.inputDialog`) where the player sets notification audio on/off (checkbox), the notification position (select: top-right, top, top-left, center-right, center-left, bottom-right, bottom, bottom-left) and, when convar `w_lib:userLocales` is 1 (default), the UI locale. Values are stored in resource KVP (`notification_audio`, `notification_position`, `locale`); cancelling saves nothing. The two notification values are the defaults `lib.notify` uses for `position` and for whether `sound` is played; audio is off until the player enables it here. A changed locale calls `lib.setLocale`. |

## Interface: menus, panels, progress bars, radial, skill check, voice UI, NUI prompt groups

### How a consumer reaches this subsystem

Every function documented here as `lib.<name>` lives under `w_lib/resource/` and is exported automatically: the `lib` table's `__newindex` in `resource/init.lua` calls `exports(key, fn)` for anything defined from a file whose source path contains `@w_lib/resource`. A consumer resource loads `@w_lib/init.lua` as its first `shared_script`; that file's `lib` table resolves any name that is not an `imports/` module to a wrapper around `exports.w_lib:<name>` (`init.lua` line 89, `export[index](nil, ...)`). So `lib.showPanel`, `lib.progressBar`, `lib.registerMenu`, `lib.voiceHint` and the rest all cross the export boundary.

Export arguments are serialised, and a function does not survive the trip: it arrives as `nil` and nothing is printed (`panel.lua` lines 19-24 say so explicitly). This has three consequences:

- Panel handlers (`onSelect`, `onAction`, `onTab`, `onNav`, `onField`, `onCancel`, `onClose`) must be event-name strings that the consumer resource registers with `AddEventHandler`. The library fires them locally with `TriggerEvent`, so `RegisterNetEvent` is unnecessary and would let the server trigger them.
- Radial `onSelect` must be the name of an export declared in the resource the library associates with the item (`radial.lua` line 255 calls `exports[resource][onSelect](0, currentMenu, itemIndex)`). For an item in the global menu that is the resource which called `lib.addRadialItem`; for an item inside a submenu it is the resource which called `lib.registerRadial` for that submenu.
- `lib.registerMenu`'s callbacks (`cb`, `onSelected`, `onSideScroll`, `onCheck`, `onClose`) have no string form at all, so from another resource a registered list menu draws and closes but never reports a choice. For a menu with callbacks from a consumer resource use `lib.showContext` (event + args) or `lib.showPanel` instead.

The `w.<module>` functions (`w.promptNui`, `w.ui`) are different. `w_init.lua` loads the module's Lua into the consumer resource's own context (through the `w_module` manifest key, or `w.require('prompt-nui')` / `w.require('ui')`; `promptNui` is an alias of `prompt-nui`, and `jo` is the same table as `w`, set in `w_init.lua` line 355), so real Lua objects and methods are available there. Any `w.<other>` a module touches (`w.rawKeys`, `w.timeout`, `w.framework`, `w.pricing`) is loaded lazily by the `w` table's `__index` on first access, so a consumer never has to require those itself.

The price of running in the consumer's context is that `w.promptNui` sends its NUI messages with the consumer's own `SendNUIMessage` (tagged `messageTargetUiName = 'wui'`), which only reaches the consumer's `ui_page`. A resource that has its own `ui_page` therefore cannot use `w.promptNui` directly and must use the `exports.w_lib:CreateGroup` family, which draws in the library's frame on the resource's behalf. Within one module instance only one prompt group is visible at a time; for the export family that means one group across every resource: `Display` on any group hides the group that was showing, whoever owns it, without telling that owner. Poll `exports.w_lib:IsVisible` rather than keeping your own flag. Multi-page groups: the key that is supposed to cycle pages (default `'A'`, `SetNextPageKey` / `group:setNextPageKey`) is stored upper-cased while the raw-keys module reports key names lower-cased, so the comparison in the module's key handler never matches and a key press never advances the page in this build. From `w.promptNui` you can still switch pages with `group:display(page)`; the export family has no page-switching call.

### Focus and one-frame rules

All of these interfaces draw in the library's single NUI frame (`ui_page nui://w_lib/web/build/index.html`). The panel, the list menu, the skill check and the radial each take NUI focus with `lib.setNuiFocus` and give it back with `lib.resetNuiFocus`, which restores whatever keep-input state existed before; a consumer resource must not call `SetNuiFocus` itself around them.

The panel is a description, not a component tree. To change anything while it is open, call `lib.showPanel` again with the whole description. The frame keeps the selection and the folded/expanded state when the new description has the same `id`, and resets them when the `id` differs, so use one `id` per screen. Do not resend a description every second to move a countdown (send `countdown` / `endsIn` once; the frame ticks them from the moment the description arrived), and do not redraw from `onField` (it fires on every keystroke and would pull the field out from under the cursor).

### Progress

`lib.progressBar` is self-timed: it plays the animation or scenario, attaches props, disables the requested controls, waits for the frame's `progressComplete` callback, and returns `true` on completion, `false` on cancel or interruption (dead, ragdoll, cuffed, falling, swimming unless the matching allow flag is set), or `nil` when the player was already in such a state at the call or a prop model was rejected. Only one bar runs at a time; a second call waits for the first to finish. `LocalPlayer.state.invBusy` is set `true` while the bar runs and restored after.

Props go through the internal server event `w_lib:progressProps`, which trims the list to the `w_lib:progressPropLimit` convar (default 2, read at startup on both sides) and writes it to the player's replicated state bag `lib:progressProps`; every client that receives the bag creates and attaches the objects and deletes them when the bag clears or the player drops. Models are refused if they are a ped or vehicle or larger than 2.5 units in any dimension. The `position` field is declared in `ProgressProps` but `lib.progressBar` does not forward it, so the frame draws the self-timed bar at its default place.

A separate script-driven bar (`lib.showProgress` / `lib.setProgress` / `lib.hideProgress` / `lib.drivenProgressActive`, in `resource/interface/client/main.lua`, outside this file set) exists for cases where the script owns the timing. `lib.cancelProgress` belongs only to the self-timed bar and raises an error when none is active, so guard it with `lib.progressActive()`. `lib.progressCircle` is not defined in this build.

### Things that are not what their names suggest

- There is no `lib.showRadial` (it is a local function). The radial opens only through the `w_lib-radial` keybind (default key `z`), and only when the global menu has at least one item, no NUI frame has focus and the pause menu is closed. Removing or clearing radial items while a submenu is open redraws the global menu, dropping the submenu.
- `lib.skillCheck` sends a `startSkillCheck` message that nothing in the shipped frame handles (no listener in `web/src`, `web/build`, `nui/` or `html/`), so the promise it awaits never resolves, the calling thread blocks forever and the player is left with NUI focus and no game input. `lib.cancelSkillCheck` sends an equally unhandled message. Treat the skill check as unavailable in this version.
- `exports.w_lib:Notify` depends on a resource that handles the `RK-text:send` event (RK-text3d); it is a thin forwarder, not something drawn in the library's frame.

### lib.showPanel

```lua
lib.showPanel(data: PanelProps)
```

Side: client

Parameters:

- `data` (`PanelProps`, required): the whole description of the panel. Errors (`lib.showPanel expects a table`) if not a table. Only the data fields listed here are forwarded to the frame; handler fields stay in Lua.
  - `id` (string, optional but strongly advised): identity of the screen. A redraw with the same id keeps the selected row and the folded/open nav groups; a different id resets them.
  - `title` (string, optional): header title.
  - `subtitle` (string, optional): line under the title.
  - `icon` (string, optional): header icon (texture/blip name or image url).
  - `logo` (string, optional): image url for the header.
  - `theme` (string, optional): visual theme name understood by the frame's CSS; consumers on this server use `'default'`, `'workshop'`, `'personal'`.
  - `search` (boolean, optional, default shown): `false` hides the search field. The search filters rows in the frame by title/description (or nav label/description/search text) with no Lua round trip.
  - `searchPlaceholder` (string, optional).
  - `items` (`PanelItem[]`, optional, default `{}`): the browser list when `nav` is not used. Each `PanelItem`:
    - `id` (string or number, required)
    - `title` (string, required)
    - `description` (string, optional)
    - `icon` (string, optional)
    - `image` (string, optional)
    - `disabled` (boolean, optional)
    - `group` (string, optional): consecutive rows sharing it sit under one heading
    - `meta` (`{label, value?, progress?}[]`, optional)
    - `endsIn` (number, optional): seconds, counted down by the frame, urgent styling at 30 or below
    - `detail` (table, optional): `title?`, `image?`, `description?`, `tag?`, `tagBad?` (draws the tag red), `stats?` (`{label, value?, progress?}[]`, bars under `statsLabel`), `rows?` (`{label, value?, progress?}[]`, tiles), `requirements?` (`{label, amount?, icon?, image?, missing?}[]`), `requirementsLabel?`, `endsIn?`, `endsInLabel?`
  - `actions` (`PanelAction[]`, optional): the button row. Each `PanelAction`:
    - `id` (string, required)
    - `label` (string, required)
    - `icon` (string, optional)
    - `primary` (boolean, optional): Enter runs it; otherwise Enter runs the first action
    - `disabled` (boolean, optional): a disabled action plays the deny sound and fires nothing
    - `input` (`{min?, max?, step?, value?, placeholder?}`, optional): draws a number field whose value is passed as the third argument of `onAction`, falling back to `min` or 0
  - `hints` (`{key, label}[]`, optional): key hints under the actions.
  - `aside` (string, optional): free text at the far end of the header; replaced by the countdown clock when `countdown` is set.
  - `emptyText` (string, optional): shown in the detail pane with nothing selected.
  - `statsLabel` (string, optional): heading over `detail.stats` bars.
  - `tabs` (`{id, label, icon?}[]`, optional): tabs across the top of the browser.
  - `activeTab` (string, optional): starting tab id (default the first tab). Tab switches are handled in the frame; `onTab` only informs Lua.
  - `progress` (`{label?, image?, value? (0-100), info?, cancelLabel?}`, optional): while set, replaces the action row; `cancelLabel` adds a button that fires `onCancel`.
  - `countdown` (number, optional): seconds left for the whole panel, drawn in the header in place of `aside` and ticked down by the frame; send once.
  - `nav` (`PanelNavGroup[]`, optional): replaces the item list with grouped, foldable navigation. Each `PanelNavGroup`:
    - `id` (string, optional): fold state is keyed on it, falling back to `label`
    - `label` (string, optional): a group without a label cannot fold and always shows
    - `private` (boolean, optional): lock icon and red edge
    - `levelLabel` (string, optional): text beside the count
    - `scope` (string, optional): tab id this group belongs to; unscoped shows under all tabs
    - `expanded` (boolean, optional): open on arrival, otherwise the first group opens
    - `items` (table[], required): `id` (string, required), `label` (string, required), `icon?`, `image?`, `count?` (number or string), `description?`, `search?` (extra text matched by the search but never drawn), `disabled?`
  - `activeNav` (string, optional): id of the highlighted nav row; Up/Down walk the rows of open groups and fire `onNav` for the next one.
  - `navCountLabel` (string, optional): unit printed under the tabs with the visible-row tally; omitted, no tally.
  - `blocks` (`Block[]`, optional): composed content replacing the detail pane. Each `Block`:
    - `type` (required): `'section'`, `'stats'`, `'bars'`, `'rows'`, `'table'`, `'cards'`, `'text'`, `'form'`, `'actions'`, `'requirements'`, `'chips'` or `'hero'`
    - `title` (string, optional): ruled heading
    - `note` (string, optional): text at the end of the heading
    - `span` (number, optional): share of the row when blocks sit side by side
    - `items` (table[], optional): `label`, `value?`, `sub?`, `icon?`, `image?`, `progress?`, `id?`, `disabled?`, `danger?`, `actions?` (`BlockAction[]`), `input?` (`{id (required), value?, min?, max?, step?}`, reported through `onField`), `dot?` (CSS colour or `'ok'`, `'warn'`, `'bad'`)
    - `columns` (`{key, label, align? ('start'|'end')}[]`, for `table`)
    - `rows` (`Record<string, string|number>[]`, for `table`)
    - `value` (string, for `text` / `hero`)
    - `image` (string, for `hero`)
    - `icon` (string, optional)
    - `color` (string, for `hero`)
    - `subtitle` (string, optional)
    - `fields` (`Field[]`, for `form`): `id` (required), `label?`, `type?` (`'text'`, `'number'`, `'select'`, `'checkbox'`, `'textarea'`, `'color'`, `'time'`, `'date'`), `value?`, `placeholder?`, `min?`, `max?`, `step?`, `options?` (`{value, label}[]`), `disabled?`
    - `actions` (`BlockAction[]`): `id` (required), `label` (required), `icon?`, `disabled?`, `danger?` (red)
  - `onSelect` (string event name, optional): fired as `(itemId)` when a browser row is picked (not fired when the same row is picked again).
  - `onAction` (string event name, optional): fired as `(actionId, itemId|nil, amount|nil)`; `itemId` is the selected row (or the block row's id for a row action), `amount` only when the action has `input`.
  - `onTab` (string event name, optional): fired as `(tabId)`; ignoring it is normal.
  - `onNav` (string event name, optional): fired as `(navId)` when a nav row is clicked or reached with the arrows.
  - `onField` (string event name, optional): fired as `(fieldId, value)` on every keystroke or change of a form field or row input; keep your own draft state and do not redraw from it.
  - `onCancel` (string event name, optional): fired with no arguments when the progress cancel button is pressed.
  - `onClose` (string event name, optional): fired with no arguments after the player closes the panel (Escape or the close control); the panel state is cleared and focus released before it runs, so the handler may open another panel.

Returns: `nil`

Opens the shared dashboard panel in the library's frame, or replaces the contents of the one already open. Sends only data to the frame, keeps the handler fields in Lua, and takes NUI focus with the cursor shown and game input blocked. Handlers are run through `TriggerEvent` when they are strings (the only form that works from a consumer resource, since the call is an export); a function is honoured only for callers inside the library. Frame behaviour to rely on: Escape closes (while typing in a field, Escape and Enter only blur the field), Up/Down move the selection or the nav row, Enter runs the primary (else first) action, search filters locally, countdowns tick locally from the moment the description arrived. To update, call `lib.showPanel` again with the full description and the same `id`.

```lua
local EV = { action = 'myshop:panel:action', select = 'myshop:panel:select', close = 'myshop:panel:close' }
local selected, myCash = nil, 120

local function draw(stock)
    local items = {}
    for i, it in ipairs(stock) do
        items[i] = {
            id = it.name, title = it.label, image = it.image, group = it.category,
            meta = { { label = 'Price', value = '$' .. it.price } },
            detail = {
                title = it.label, image = it.image, description = it.desc,
                requirements = { { label = 'Cash', amount = it.price, missing = it.price > myCash } },
                requirementsLabel = 'Cost',
            },
        }
    end
    lib.showPanel({
        id = 'myshop', title = 'General Store', subtitle = 'Valentine',
        icon = 'blip_shop_store', search = true, searchPlaceholder = 'Search...',
        aside = '$' .. myCash, emptyText = 'Pick an item',
        items = items,
        actions = {
            { id = 'buy', label = 'Buy', primary = true, input = { min = 1, max = 20, value = 1 } },
            { id = 'close', label = 'Leave' },
        },
        hints = { { key = 'Enter', label = 'Buy' }, { key = 'Esc', label = 'Leave' } },
        onAction = EV.action, onSelect = EV.select, onClose = EV.close,
    })
end

-- AddEventHandler, not RegisterNetEvent: the library fires these locally.
AddEventHandler(EV.action, function(actionId, itemId, amount)
    if actionId == 'buy' and itemId then TriggerServerEvent('myshop:buy', itemId, amount) end
    if actionId == 'close' then lib.hidePanel() end
end)
AddEventHandler(EV.select, function(itemId) selected = itemId end)
AddEventHandler(EV.close, function() selected = nil end)
```

### lib.hidePanel and lib.panelActive

```lua
lib.hidePanel()
lib.panelActive()
```

Side: client

Parameters: none.

Returns:

- `lib.hidePanel`: `nil`
- `lib.panelActive`: `boolean` -- `true` while a panel description is held open

`lib.hidePanel` closes the panel from script without the player having asked: it clears the stored description, sends `hidePanel` to the frame and restores the previous NUI focus state. It does not fire `onClose` and is a no-op when no panel is open. Call it from an `onResourceStop` handler for your own resource so the frame is not left open.

`lib.panelActive` reports whether a panel is open. It becomes `false` after `lib.hidePanel` or after the player closes it (the state is cleared before `onClose` fires).

```lua
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then lib.hidePanel() end
end)

if lib.panelActive() then return end
```

### lib.registerMenu

```lua
lib.registerMenu(data: MenuProps, cb?: fun(selected: number, scrollIndex?: number, args?: table, checked?: boolean))
```

Side: client

Parameters:

- `data` (`MenuProps`, required): the menu definition. Stored under `data.id`; a later call with the same id replaces it. Errors (`No menu id/title/options was provided.`) if `id`, `title` or `options` is missing.
  - `id` (string, required): key used by `lib.showMenu`, `lib.setMenuOptions` and `lib.getOpenMenu`.
  - `title` (string, required): header text.
  - `options` (`MenuOptions[]`, required): the rows; `lib.showMenu` errors if the array is empty.
  - `position` (`'top-left'`, `'top-right'`, `'bottom-left'`, `'bottom-right'`, optional, frame default `'top-left'`): corner the frame draws it in.
  - `disableInput` (boolean, optional, default `nil`): while the menu is open, player firing and control `0xE30CD707` (140 on FiveM) are disabled every frame whenever this is `nil` or `true`; NUI focus is taken with keep-input enabled unless this is exactly `true`, in which case game input is blocked.
  - `canClose` (boolean, optional): forwarded to the frame; `false` stops Escape/Backspace from closing it.
  - `onClose` (`fun(keyPressed?: 'Escape'|'Backspace')`, optional): called when the player closes the menu (`keyPressed` set) or when `lib.hideMenu(true)` is called (`keyPressed` nil).
  - `onSelected` (`fun(selected, scrollIndex?, args)`, optional): fires when the highlighted row changes. `selected` is 1-based; `scrollIndex` is the 1-based value index for a values row the player has already scrolled (otherwise nil). When it is set, `args.isScroll = true` is written into the row's `args` table (or into a fresh table when the row has none).
  - `onSideScroll` (`fun(selected, scrollIndex, args)`, optional): fires when the player changes the value of a values row; both indices 1-based.
  - `onCheck` (`fun(selected, checked: boolean, args)`, optional): fires when a checkbox row is toggled with Enter.
  - `cb`: set from the second argument; do not set it in the table.
  - Row fields (`MenuOptions`; the whole row table is forwarded to the frame):
    - `label` (string, required)
    - `description` (string, optional)
    - `icon` (string or `{IconProp, string}`, optional): FontAwesome name
    - `iconColor` (string, optional)
    - `iconAnimation` (string, optional): declared in the frame typings
    - `image` (string, optional): declared in the frame typings
    - `progress` (number, optional): 0-100 bar on the row
    - `colorScheme` (string, optional): colour of that bar
    - `values` (`Array<string | {label: string}>`, optional): makes a left/right scroll row; the frame draws `label` only
    - `defaultIndex` (number, optional): starting value index for a values row
    - `checked` (boolean, optional): makes a checkbox row; Enter toggles it instead of confirming
    - `args` (table, optional): passed back to every callback; a non-table value raises `Menu args must be passed as a table` from `onSelected`
    - `close` (boolean, optional, default `true`): `false` keeps the menu open after Enter on this row
- `cb` (function, optional): called on Enter on a non-checkbox row as `cb(selected, scrollIndex, args, checked)`. `selected` and `scrollIndex` are 1-based (`scrollIndex` nil for rows without values); `checked` is always `false` on this path. Unless the row has `close = false` the menu is already closed and NUI focus released before `cb` runs.

Returns: `nil`

Stores a list-menu definition for `lib.showMenu`. Because this call crosses the export boundary from a consumer resource, none of the function-typed fields (`cb`, `onSelected`, `onSideScroll`, `onCheck`, `onClose`) can be delivered from a consumer, and there is no event-name alternative in this file: from another resource the menu displays and closes but never reports anything. Use `lib.showContext` or `lib.showPanel` for menus that must call back into your resource.

```lua
-- Callbacks only reach code running inside the library itself; from a consumer
-- resource the menu draws but the functions below are lost (see description).
lib.registerMenu({
    id = 'my_menu',
    title = 'Camp',
    position = 'top-left',
    options = {
        { label = 'Rest', description = 'Sleep until morning', icon = 'bed' },
        { label = 'Volume', values = { 'Low', 'Mid', 'High' }, defaultIndex = 2 },
        { label = 'Auto-cook', checked = true, close = false },
    },
    onClose = function(key) print('closed by', key) end,
}, function(selected, scrollIndex, args, checked)
    print(selected, scrollIndex, checked)
end)
lib.showMenu('my_menu')
```

### lib.showMenu

```lua
lib.showMenu(id: string, startIndex?: number)
```

Side: client

Parameters:

- `id` (string, required): id passed to `lib.registerMenu`. Errors if unknown (`No menu with id ... was found`) or if its options array is empty.
- `startIndex` (number, optional): 1-based row to highlight first (default 1). Converted to 0-based for the frame.

Returns: `nil`

Opens a registered list menu in the library's frame: takes NUI focus with the cursor hidden (keep-input on unless `disableInput` is exactly `true`), starts a per-frame thread that disables player firing and control `0xE30CD707` while any menu is open whose `disableInput` is nil or `true`, and sends position, `canClose`, title, items and the start index to the frame. Keys in the frame: Up/Down move, Left/Right change a values row, Enter confirms or toggles a checkbox, Escape/Backspace close (unless `canClose == false`). Opening a second menu while one is open replaces it without firing the first one's `onClose`.

```lua
lib.showMenu('my_menu', 2)
```

### lib.hideMenu

```lua
lib.hideMenu(onExit?: boolean)
```

Side: client

Parameters:

- `onExit` (boolean, optional): when `true` the menu's `onClose` handler is called (with no key argument) before the frame is told to close.

Returns: `nil`

Closes the open list menu from script, releases NUI focus and sends `closeMenu` to the frame. Does nothing if no menu is open.

```lua
if lib.getOpenMenu() == 'my_menu' then
    lib.hideMenu(true)
end
```

### lib.setMenuOptions and lib.getOpenMenu

```lua
lib.setMenuOptions(id: string, options: MenuOptions | MenuOptions[], index?: number)
lib.getOpenMenu()
```

Side: client

Parameters for `lib.setMenuOptions`:

- `id` (string, required): id of a registered menu. Raises a Lua error (attempt to index nil) if the id was never registered.
- `options` (`MenuOptions` or `MenuOptions[]`, required): with `index`, one row replacing `options[index]`; without `index`, the complete new array of rows. A table whose `[1]` is nil raises `Invalid override format used, expected table of options.`.
- `index` (number, optional): 1-based row to replace.

`lib.getOpenMenu` takes no parameters.

Returns:

- `lib.setMenuOptions`: `nil`
- `lib.getOpenMenu`: `string?` -- id of the open list menu, or `nil`

`lib.setMenuOptions` rewrites the stored options of a registered menu. It does not redraw a menu that is already open; call `lib.showMenu` again to show the change. `lib.getOpenMenu` returns the id of the list menu currently open, `nil` when none is.

```lua
lib.setMenuOptions('my_menu', { label = 'Rest (tired)', description = 'You need it' }, 1)
lib.showMenu('my_menu')

if lib.getOpenMenu() then return end
```

### lib.progressBar

```lua
lib.progressBar(data: ProgressProps)
```

Side: client

Parameters:

- `data` (`ProgressProps`, required): what to show and what to do to the ped while it runs.
  - `duration` (number, required): milliseconds. The frame reports completion, and the client returns `false` if less than `duration - 100` ms elapsed.
  - `label` (string, optional): text on the bar.
  - `position` (`'middle'` or `'bottom'`, optional): declared in the type but not forwarded by `lib.progressBar` (only `label` and `duration` are sent), so it has no effect here.
  - `useWhileDead` (boolean, optional, default `false`): when `false` the bar refuses to start (returns `nil`) or is interrupted if the ped is dead.
  - `allowRagdoll` (boolean, optional, default `false`): same rule for `IsPedRagdoll`.
  - `allowCuffed` (boolean, optional, default `false`): same rule for `IsPedCuffed`.
  - `allowFalling` (boolean, optional, default `false`): same rule for `IsPedFalling`.
  - `allowSwimming` (boolean, optional, default `false`): same rule for `IsPedSwimming`.
  - `canCancel` (boolean, optional, default `false`): lets the `/cancelprogress` command cancel the bar. On FiveM it is key-mapped to X; on RedM no key mapping is registered, so bind it yourself.
  - `anim` (table, optional): `dict` + `clip` play `TaskPlayAnim` with `blendIn` (default 3.0), `blendOut` (default 1.0), `duration` (default -1), `flag` (default 49), `playbackRate` (default 0), `lockX` / `lockY` / `lockZ` (booleans); `scenario` plays `TaskStartScenarioInPlace` with `playEnter` (default `true`). The dict is requested and released automatically; the anim is stopped (`StopAnimTask`, or `ClearPedTasks` for a scenario) when the bar ends.
  - `prop` (`ProgressPropProps` or `ProgressPropProps[]`, optional): objects attached to the ped for everyone to see. Each: `model` (string, required; ped and vehicle models and models over 2.5 units in any dimension are rejected with a printed error and the bar returns `nil`), `bone` (number, default 60309), `pos` (vector3, required), `rot` (vector3, required), `rotOrder` (number, default 0). The list is capped by the `w_lib:progressPropLimit` convar (default 2).
  - `disable` (table, optional): `move` (blocks sprint, move and duck controls), `sprint` (blocks sprint only), `car` (blocks vehicle steer, accelerate, brake, exit), `combat` (blocks aim and player firing), `mouse` (blocks look left/right, up/down and vehicle mouse override).

Returns: `boolean?` -- `true` when it ran to completion, `false` when cancelled or interrupted, `nil` when the ped was already dead/ragdoll/cuffed/falling/swimming (per the allow flags) at the call or a prop model was rejected

Shows the self-timed progress bar in the library's frame and blocks the calling thread until it finishes. If another bar is running the call waits for it first. Sets `LocalPlayer.state.invBusy` to `true` for the duration and restores the previous value after. Props are broadcast through the player's replicated state bag so other clients attach them too. Call it from a thread, since it yields.

```lua
local ok = lib.progressBar({
    label = 'Treating the wound',
    duration = 5000,
    canCancel = true,
    useWhileDead = false,
    disable = { move = true, sprint = true, combat = true },
    anim = { dict = 'mech_inspection@hat_add', clip = 'inspect_loop' },
    prop = { model = 'p_bandage01x', pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0), bone = 57005 },
})
if not ok then return end
TriggerServerEvent('myres:treated')
```

### lib.cancelProgress and lib.progressActive

```lua
lib.cancelProgress()
lib.progressActive()
```

Side: client

Parameters: none.

Returns:

- `lib.cancelProgress`: `nil`
- `lib.progressActive`: `boolean?` -- `true` while a self-timed bar is running, otherwise `false` or `nil`

`lib.cancelProgress` cancels the running self-timed bar so `lib.progressBar` returns `false`. It raises a Lua error `No progress bar is active` when nothing is running, so guard it with `lib.progressActive()`. It does not affect the script-driven bar (`lib.showProgress` / `lib.hideProgress`).

`lib.progressActive` reports whether `lib.progressBar` is currently running (`nil` when idle, `false` briefly after a cancel, `true` while running). Use it as a guard before starting an action or another bar.

```lua
if lib.progressActive() then lib.cancelProgress() end

if lib.progressActive() then return false end
```

### lib.registerRadial

```lua
lib.registerRadial(radial: { id: string, items: RadialItem[] })
```

Side: client

Parameters:

- `radial` (`RadialMenuProps`, required): a radial submenu. Stored under `radial.id` (a nil id raises a Lua error); re-registering replaces it and, if that submenu is open, redraws it.
  - `id` (string, required): submenu id referenced by an item's `menu` field.
  - `items` (`RadialItem[]`, required). Each `RadialItem`:
    - `label` (string, required)
    - `icon` (string or `{IconProp, string}`, required): FontAwesome name
    - `menu` (string, optional): id of the submenu to open when clicked
    - `onSelect` (string, optional): name of an export in the resource that called `lib.registerRadial`, invoked as `(currentMenu, itemIndex)` where `currentMenu` is this submenu's id
    - `keepOpen` (boolean, optional): keep the radial open after a click when there is no submenu
    - `iconWidth` (number, optional)
    - `iconHeight` (number, optional)
    - Extra string keys are allowed and kept; `isMore` is not read by the shipped frame.
  - `resource`: set internally to the invoking resource; every `onSelect` string of every item in this submenu is looked up as an export there, even for items added later with `lib.addRadialItem(item, id)`.

Returns: `nil`

Registers a submenu of the radial menu. Because the call is an export, `onSelect` must be an export name string (functions are dropped); the export is called on the registering resource. Submenus are not removed automatically when their resource stops (only global items are).

```lua
exports('radialHorse', function(currentMenu, itemIndex)
    print('picked', currentMenu, itemIndex)
end)

lib.registerRadial({
    id = 'horse_menu',
    items = {
        { label = 'Call horse', icon = 'horse', onSelect = 'radialHorse' },
        { label = 'Brush', icon = 'broom', onSelect = 'radialHorse' },
    },
})
lib.addRadialItem({ id = 'horse', label = 'Horse', icon = 'horse', menu = 'horse_menu' })
```

### lib.addRadialItem

```lua
lib.addRadialItem(items: RadialMenuItem | RadialMenuItem[], parentMenuId?: string)
```

Side: client

Parameters:

- `items` (`RadialMenuItem` or `RadialMenuItem[]`, required): one item or an array. An item whose `id` already exists in the target menu is replaced in place; otherwise it is appended.
  - `id` (string, required): used for later removal or replacement.
  - `label` (string, required)
  - `icon` (string or `{IconProp, string}`, required)
  - `menu` (string, optional): submenu id to open.
  - `onSelect` (string, optional): export name, called as `(currentMenu | nil, itemIndex)`. For a global item the export is looked up in the resource that called `lib.addRadialItem`; for an item added into a submenu it is looked up in the resource that registered that submenu.
  - `keepOpen` (boolean, optional)
  - `iconWidth` (number, optional)
  - `iconHeight` (number, optional)
- `parentMenuId` (string, optional): add to this registered submenu instead of the global menu. Errors (`No radial submenu with such parent id found.`) if no such submenu.

Returns: `nil`

Adds items to the global radial menu (or a submenu). Tags each item with the invoking resource so a global item's `onSelect` export is found and so global items are removed when that resource stops. If the global menu is open and not inside a submenu it is redrawn.

```lua
lib.addRadialItem({
    { id = 'inv', label = 'Satchel', icon = 'bag-shopping', onSelect = 'openInventory' },
    { id = 'emotes', label = 'Emotes', icon = 'face-smile', menu = 'emote_menu' },
})
```

### lib.removeRadialItem and lib.clearRadialItems

```lua
lib.removeRadialItem(id: string, parentMenuId?: string)
lib.clearRadialItems()
```

Side: client

Parameters for `lib.removeRadialItem`:

- `id` (string, required): item id to remove.
- `parentMenuId` (string, optional): remove from this submenu instead of the global menu. Errors if no such submenu.

`lib.clearRadialItems` takes no parameters.

Returns: `nil` for both

`lib.removeRadialItem` removes the first item with that id. If the radial is open it is redrawn as the global menu: the submenu history is wiped and any submenu the player was in is left.

`lib.clearRadialItems` empties the global radial menu (all resources' items; submenus registered with `lib.registerRadial` are kept). If the radial is open it is redrawn as the now empty global menu, leaving any submenu the player was in.

```lua
lib.removeRadialItem('inv')
lib.clearRadialItems()
```

### lib.hideRadial, lib.disableRadial and lib.getCurrentRadialId

```lua
lib.hideRadial()
lib.disableRadial(state: boolean)
lib.getCurrentRadialId()
```

Side: client

Parameters:

- `lib.disableRadial`: `state` (boolean, required): `true` blocks the keybind from opening the radial and closes it if open; `false` allows it again.
- The other two take none.

Returns:

- `lib.hideRadial`: `nil`
- `lib.disableRadial`: `nil`
- `lib.getCurrentRadialId`: `string?` -- id of the submenu currently shown; `nil` for the global menu or when closed

`lib.hideRadial` closes the radial if open, releases NUI focus and clears the submenu history. There is no public `lib.showRadial`: the radial opens only through the `w_lib-radial` keybind (default key `z`) when the global menu has items, no NUI frame is focused and the pause menu is closed; pressing the key again closes it.

`lib.disableRadial` is the global on/off switch for the radial keybind. The flag is shared by all resources; the last caller wins.

`lib.getCurrentRadialId` returns which registered submenu the radial is in. It returns `nil` both when the global menu is showing and when the radial is closed.

```lua
lib.hideRadial()

lib.disableRadial(true)  -- while cuffed
lib.disableRadial(false)

if lib.getCurrentRadialId() == 'horse_menu' then lib.hideRadial() end
```

### exports.w_lib:CreateGroup

```lua
exports.w_lib:CreateGroup(title: string, position?: string)
```

Side: client

Parameters:

- `title` (string, required): group title. `nil` becomes `''`.
- `position` (string, optional): default `'bottom-right'`. Values the frame knows: `'bottom-right'`, `'center-right'`, `'top-right'`, `'bottom-left'`, `'center-left'`, `'top-left'`.

Returns: `integer` -- the group handle used by every other prompt export

Creates a prompt group drawn in the library's frame on the caller's behalf and returns a numeric handle. The calling resource is recorded as owner: every mutating export (`AddPrompt`, `SetTitle`, `SetPrompt*`, `Display`, `Hide`, `DeleteGroup`) returns `false` and prints a warning when called by another resource. The call waits until the library's module layer has loaded, so call it from a thread, not at file top level. Groups are deleted automatically when the owning resource stops.

```lua
CreateThread(function()
    local id = exports.w_lib:CreateGroup('Cinema board', 'bottom-right')
    exports.w_lib:AddPrompt(id, 'E', 'Read the programme', false)
    exports.w_lib:Display(id)
end)
```

### exports.w_lib:AddPrompt

```lua
exports.w_lib:AddPrompt(id: integer, key: string, label: string, holdTime?: number | false, page?: integer)
```

Side: client

Parameters:

- `id` (integer, required): handle from `CreateGroup`; must be owned by the caller.
- `key` (string, required): keyboard key name as the raw-keys module names it: the Windows virtual-key names in lower case (`'e'`, `'g'`, `'space'`, `'return'`, `'lshift'`, `'f1'`, ...) plus the aliases `'enter'`, `'esc'`, `'backspace'`, `'ctrl'`, `'pageup'`, `'pagedown'`. Case-insensitive; stored upper-cased for the exports and lower-cased for matching. A non-string returns `false`.
- `label` (string, required): text shown beside the key. `nil` becomes `''`.
- `holdTime` (number or `false`, optional): milliseconds the key must be held before it completes; `false` or `nil` means a plain press.
- `page` (integer, optional): 1-based page of the group (default 1). Page cycling by key does not work in this build and the export family has no page-switching call, so pages other than 1 are unreachable through the exports.

Returns: `boolean` -- `true` when added

Adds a prompt row to the group. Adding the same key again appends another row in the frame but replaces the stored prompt object for that key (`SetPrompt*` then affect the newest). If the group is being displayed the row appears immediately.

```lua
exports.w_lib:AddPrompt(id, 'E', 'Sit down', false)
exports.w_lib:AddPrompt(id, 'G', 'Hold to leave', 1500)
```

### exports.w_lib:Display, exports.w_lib:Hide and exports.w_lib:IsVisible

```lua
exports.w_lib:Display(id: integer)
exports.w_lib:Hide(id: integer)
exports.w_lib:IsVisible(id: integer)
```

Side: client

Parameters:

- `id` (integer, required): group handle. `Display` and `Hide` require the caller to own it; `IsVisible` performs no ownership check.

Returns:

- `Display`: `boolean` -- `true` when shown
- `Hide`: `boolean`
- `IsVisible`: `boolean` -- `true` while the group is the one being displayed

`Display` shows the group. Only one prompt group is visible at a time in the whole frame: if another group (of any resource) was visible it is hidden first, and that owner is not notified; scripts must therefore re-check `IsVisible` rather than remember that they displayed it. While a group is visible the library polls its keys every frame and fires `w_lib:promptCompleted`.

`Hide` hides the group and stops the completion poll for it.

`IsVisible` reports whether the group is currently displayed. It becomes `false` when another resource's `Display` evicts it, which is why consumer resources ask this instead of keeping a flag.

```lua
if not exports.w_lib:IsVisible(id) then exports.w_lib:Display(id) end

exports.w_lib:Hide(id)

local ok, vis = pcall(function() return exports.w_lib:IsVisible(id) end)
if ok and vis then print('still showing') end
```

### exports.w_lib:IsCompleted

```lua
exports.w_lib:IsCompleted(id: integer, key: string)
```

Side: client

Parameters:

- `id` (integer, required): group handle (no ownership check).
- `key` (string, required): key name as given to `AddPrompt` (case-insensitive). A non-string returns `false`.

Returns: `boolean` -- `true` only on the game tick in which the press or hold completed

Direct poll alternative to the `w_lib:promptCompleted` event. It is `true` only while `GetGameTimer()` equals the tick the frame reported completion, only when this group is the visible one, and never during a forced hide (pause menu, screen fade, loading screen); so it must be polled every frame (`Wait(0)`) to be caught.

```lua
CreateThread(function()
    while placing do
        if exports.w_lib:IsCompleted(id, 'E') then place() end
        Wait(0)
    end
end)
```

### exports.w_lib:SetTitle and the SetPrompt* exports

```lua
exports.w_lib:SetTitle(id: integer, title: string)
exports.w_lib:SetPromptLabel(id: integer, key: string, label: string)
exports.w_lib:SetPromptEnabled(id: integer, key: string, enabled: boolean)
exports.w_lib:SetPromptVisible(id: integer, key: string, visible: boolean)
```

Side: client

All four take an owned group handle `id` (integer, required); the `SetPrompt*` calls also take `key` (string, required, case-insensitive; an unknown key returns `false`). All return `boolean`.

| Export | Third argument | Effect |
| --- | --- | --- |
| `SetTitle` | `title` (string, required): new title | Changes the group title; redrawn immediately if the group is visible. |
| `SetPromptLabel` | `label` (string, required): new text | Changes a prompt's label; redrawn immediately if its group is visible. |
| `SetPromptEnabled` | `enabled` (boolean, required): `false` greys the row out (still drawn) | Enables or disables (greys) a prompt row. |
| `SetPromptVisible` | `visible` (boolean, required): `false` removes the row from view and disables it; `true` shows and enables it | Shows or hides one prompt row entirely, as opposed to greying it. Setting visible also sets enabled to the same value. Hidden rows are ignored by the key listener. |

```lua
exports.w_lib:SetTitle(id, 'Baloot table')
exports.w_lib:SetPromptLabel(id, 'E', 'Stand up')
exports.w_lib:SetPromptEnabled(id, 'G', hasMoney)
exports.w_lib:SetPromptVisible(id, 'H', false)
```

### exports.w_lib:DeleteGroup

```lua
exports.w_lib:DeleteGroup(id: integer)
```

Side: client

Parameters:

- `id` (integer, required): owned group handle.

Returns: `boolean` -- `true` when deleted, `false` if unknown or not owned

Frees the handle. If the group was visible it is force-hidden (the frame hides it) rather than hidden, which leaves the module's forced-hide flag set until the next `Display` of any group; call `Hide` first for a clean teardown. Wrap it in `pcall` if the handle may already be gone after a restart.

```lua
pcall(function() exports.w_lib:Hide(id); exports.w_lib:DeleteGroup(id) end)
id = nil
```

### exports.w_lib:SetNextPageKey

```lua
exports.w_lib:SetNextPageKey(id: integer, key: string)
```

Side: client

Parameters:

- `id` (integer, required): group handle (no ownership check).
- `key` (string, required): key intended to cycle pages (stored upper-cased; default `'A'`).

Returns: `boolean` -- `false` if the handle is unknown

Sets the page-cycling key label drawn by the frame for a multi-page group. In this build the press never advances the page: the module compares the raw-keys name (lower case) with this upper-cased value, so the comparison fails for every key. Treat it as cosmetic until the module is fixed.

Not confirmed from source; treat as best effort.

```lua
exports.w_lib:SetNextPageKey(id, 'TAB')
```

### w.promptNui.createGroup

```lua
w.promptNui.createGroup(title: string | false, position?: string)
```

Side: client

Parameters:

- `title` (string or `false`, required): group title; `false` draws no title at all.
- `position` (string, optional): `'bottom-right'` (default), `'center-right'`, `'top-right'`, `'bottom-left'`, `'center-left'`, `'top-left'`.

Returns: `GroupClass` -- a group object with the methods listed under GroupClass

Creates a prompt group object inside the calling resource's Lua context (module loaded via `w_module { 'prompt-nui' }` in `fxmanifest.lua` or `w.require('prompt-nui')`; also reachable as `jo.promptNui`). Its NUI messages are sent with the caller's `SendNUIMessage` (after a 1.1 s start-up delay), so they reach only the caller's `ui_page`: this only works in a resource whose `ui_page` is `nui://w_lib/web/build/index.html`. A resource with its own frame must use `exports.w_lib:CreateGroup` instead. Keys are read through the raw-keys module and the group is force-hidden during the pause menu, screen fades and loading screens.

```lua
-- fxmanifest.lua: w_module { 'prompt-nui' }  and  ui_page 'nui://w_lib/web/build/index.html'
local group = w.promptNui.createGroup('Bench', 'bottom-right')
local craft = group:addPrompt('E', 'Craft', 1000)
local leave = group:addPrompt('G', 'Leave', false)
group:display()
CreateThread(function()
    while group:isVisible() do
        if w.promptNui.isCompleted(group, 'E') then startCraft() end
        if w.promptNui.isCompleted(group, 'G') then group:hide() end
        Wait(0)
    end
end)
```

### w.promptNui.isCompleted and w.promptNui.isDisplayed

```lua
w.promptNui.isCompleted(group: GroupClass | integer, key: string, fireMultipleTimes?: boolean)
w.promptNui.isCompleted(key: string, fireMultipleTimes?: boolean)  -- legacy form
w.promptNui.isDisplayed()
```

Side: client

Parameters for `w.promptNui.isCompleted`:

- `group` (`GroupClass` or integer, optional): group object or its numeric id. When given, returns `false` unless that group is the visible one. If the first argument is a string it is treated as the key (legacy signature).
- `key` (string, required): key name, case-insensitive.
- `fireMultipleTimes` (boolean, optional): default `false`, meaning `true` only on the exact game tick the completion was reported. When `true`, stays `true` until the key is released or pressed again.

`w.promptNui.isDisplayed` takes no parameters.

Returns:

- `isCompleted`: `boolean`
- `isDisplayed`: `boolean` -- `true` while any group created in this module instance is displayed

`isCompleted` reports whether the key's press or hold has completed. It returns `false` during a forced hide. Poll it every frame unless `fireMultipleTimes` is set. `isDisplayed` reports whether some group of this module instance is the visible one.

```lua
if w.promptNui.isCompleted(group, 'E') then print('pressed') end

if not w.promptNui.isDisplayed() then group:display() end
```

### GroupClass methods

```lua
group:addPrompt(key: string, label: string, holdTime: number | false, page?: number, price?: table | number | false)
group:addSeparator(page?: number)
group:display(page?: number)
group:hide()
group:forceHide()
group:forceDisplay()
group:setTitle(title: string | false)
group:setPosition(position: string)
group:setNextPageKey(key: string)
group:isVisible()
```

Side: client

`group:addPrompt` parameters:

- `key` (string, required): keyboard key name (lower-cased internally); raw-keys names such as `'e'`, `'space'`, `'return'` or aliases such as `'enter'`, `'esc'`, `'backspace'`.
- `label` (string, required): row text.
- `holdTime` (number or `false`, required): milliseconds to hold, or `false` for a plain press.
- `page` (number, optional): 1-based page, default 1; missing pages are created.
- `price` (table, number or `false`, optional): a price shown beside the label, built through `w.pricing` and `w.framework`; `false` or `nil` for none. The framework and pricing modules are loaded on the first `addPrompt` regardless.

Returns: `PromptClass` -- the new prompt object, for later `setLabel` / `setEnabled` / `setVisible` / `setHoldTime` / `setPrice` calls. It appends a prompt row to a page of the group.

The other methods:

| Method | Parameters | Returns | Effect |
| --- | --- | --- | --- |
| `addSeparator` | `page` (number, optional, default 1) | `nil` | Appends a visual rule between prompt rows on that page. |
| `display` | `page` (number, optional): page to show, clamped to the page count; default the group's current page. This is the only working way to change page in this build. | `nil` | Makes this group the visible one (replacing any other of this module instance), clears a pending forced hide, sends the whole group to the frame and starts the per-frame loop that disables the game's own prompt types and handles forced hides. |
| `hide` | none | `nil` | Marks the group not visible; if it was the visible one, clears the frame's prompt list and the completed-key table. |
| `forceHide` | none | `nil` | Hides the frame's prompt display without changing the group's visible flag (what the loop does during the pause menu or a fade). `isCompleted` returns `false` while forced hidden; the flag is module-wide and is lifted by `forceDisplay` or any `display()`. |
| `forceDisplay` | none | `nil` | Lifts a forced hide. |
| `setTitle` | `title` (string or `false`, required): new title; `false` for none | `nil` | Changes the title; redrawn immediately if the group is visible. |
| `setPosition` | `position` (string, required): `'bottom-right'`, `'center-right'`, `'top-right'`, `'bottom-left'`, `'center-left'`, `'top-left'` | `nil` | Moves the group; redrawn immediately if visible. |
| `setNextPageKey` | `key` (string, required): key label for page cycling (stored upper-cased; default `'A'`) | `nil` | Sets the page-cycling key label. In this build the press never advances the page (upper-cased value compared against lower-case raw-keys names), so use `group:display(page)` to change pages. Not confirmed from source; treat as best effort. |
| `isVisible` | none | `boolean` | The group's own visible flag (set by `display`, cleared by `hide`). |

```lua
local p = group:addPrompt('E', 'Buy', 800, 1, 25)
p:setEnabled(canAfford)

group:addSeparator()
group:addPrompt('G', 'Leave', false)
group:setTitle('Bench: iron')
group:setPosition('center-right')
group:setNextPageKey('TAB')
group:display(1)
if group:isVisible() then group:hide() end
group:forceHide()
group:forceDisplay()
```

### PromptClass methods

```lua
prompt:setLabel(label: string)
prompt:getLabel()
prompt:setEnabled(enabled: boolean)
prompt:setVisible(visible: boolean)
prompt:isVisible()
prompt:setKeyboardKeys(keys: string | string[])
prompt:setHoldTime(holdTime: number | false)
prompt:setPrice(price: table | number | false)
```

Side: client

| Method | Parameters | Returns | Effect |
| --- | --- | --- | --- |
| `setLabel` | `label` (string, required): new text | `nil` | Changes the row label; redrawn immediately if its group is the visible one. |
| `getLabel` | none | `string` -- the current label | Returns the row's current label text. |
| `setEnabled` | `enabled` (boolean, required): `false` greys the row | `nil` | Enables or disables the prompt row (sets the disabled flag and refreshes the frame). |
| `setVisible` | `visible` (boolean, required): `false` hides the row and disables it; `true` shows and enables it | `nil` | Shows or hides a row. Hidden rows are ignored by the key listener. |
| `isVisible` | none | `boolean` | The row's visible flag. |
| `setKeyboardKeys` | `keys` (string or string[], required): one key name or several; any of them completes the prompt. Pass lower-case raw-keys names (`addPrompt` lower-cases for you, this method does not). | `nil` | Replaces the keys bound to the prompt. Does not refresh the frame by itself. |
| `setHoldTime` | `holdTime` (number or `false`, required): milliseconds, or `false` for a plain press | `nil` | Changes the hold duration and refreshes the frame. |
| `setPrice` | `price` (table, number or `false`, required): amount or a `w.pricing` structure; `false` removes it. Loads the framework and pricing modules on every call. | `nil` | Sets the price shown beside the label (money, gold or item stacks as understood by `w.pricing`, then decorated with item data by `w.framework`) and refreshes the frame. Not confirmed from source; treat as best effort. |

```lua
craft:setLabel(('Craft (%d)'):format(qty))
print(craft:getLabel())
craft:setEnabled(hasMaterials)
leave:setVisible(false)
if leave:isVisible() then leave:setVisible(false) end
craft:setKeyboardKeys({ 'e', 'return' })
craft:setHoldTime(2000)
buy:setPrice({ money = 12.5 })
```

### lib.voicePanel

```lua
lib.voicePanel(data: { title?: string, position?: string, coords?: vector3, entity?: number, bone?: number, speaker?: string, talkKey?: string, id?: string, groups?: { label?: string, commands: string[] }[] } | false)
```

Side: client

Parameters:

- `data` (table or `false`, required): the list of phrases currently available, or `false` to hide it.
  - `title` (string, optional): the heading over the list ("You can say").
  - `groups` (`{label?: string, commands: string[]}[]`, optional): phrases grouped however the script groups them. The frame draws nothing unless at least one group is present. `{slot}` names in a phrase are drawn as blanks to fill.
  - `position` (string, optional, default `'bottom-left'`): screen corner when neither `coords` nor `entity` is given; the frame accepts `bottom-left`, `bottom-right`, `top-left`, `top-right`, `middle-left`, `middle-right`.
  - `coords` (vector3, optional): when set the panel is anchored beside that world point, projected every frame by the library (`position` is ignored) and hidden while the point is off screen.
  - `entity` (number, optional): anchor to this entity instead, re-read every frame (a ped's `bone`, SKEL_HEAD `21030` by default), so the list follows a person who moves. `coords` is used when the entity is gone.
  - `speaker` (string, optional): the name shown over the list when no hint for the same person carries one.
  - `talkKey` (string, optional): the push-to-talk key, drawn once as a key cap; pressed in while `lib.voiceListening` is active.
  - `id` (string, optional): the `lib.voiceHint` id this list belongs to. The hint and the list are drawn as ONE dialogue card; without `id` they are paired by projected position.

Returns: `nil`

Shows the available-commands list in a corner, or pinned beside a person. With `coords`/`entity`, the library starts (or reuses) its projection thread, which also drives the voice hints; without them the description is sent once. Pass `false` to remove it. When a hint is up for the same person the frame merges the two into one card (name, what they are saying, then the numbered list under its group labels), placed beside the head -- never over it -- flipped to the other side only when it would not fit, and clamped to the screen.

```lua
local groups = {
    { label = 'Trade', commands = { 'Show me your wares', 'How much for the rifle' } },
    { label = 'Talk', commands = { 'Good day', 'Farewell' } },
}
lib.voicePanel({ title = 'Shopkeeper', position = 'bottom-left', groups = groups })
-- anchored beside a ped instead
lib.voicePanel({ title = 'Shopkeeper', coords = GetPedBoneCoords(ped, 0x796E, 0.0, 0.0, 0.0), groups = groups })
lib.voicePanel(false)
```

### lib.voiceHint

```lua
lib.voiceHint(hint: VoiceHint)
```

Side: client

Parameters:

- `hint` (`VoiceHint`, required): a dialogue card beside a world point. Stored by `id`; calling again with the same `id` replaces it (used to switch between the phrase list and a spoken line). Errors (`lib.voiceHint needs an id and coords (or an entity)`) unless it is a table with `id` and `coords` or `entity`.
  - `id` (string, required): key for replacement and removal.
  - `coords` (vector3, required unless `entity`): world position; the head bone reads best.
  - `entity` (number, optional): follow this entity instead, re-read every frame (`bone`, SKEL_HEAD `21030` by default, on a ped).
  - `title` (string, optional): the ped's name, the card's header.
  - `icon` (string, optional): accepted for compatibility; the card draws no emblem.
  - `commands` (string[], optional): phrases the ped answers to (a `lib.voicePanel` for the same person replaces them with its grouped list).
  - `says` (string, optional): a line the ped is saying now; shown under the name while set. The phrase list folds away until it is cleared (the key row stays, dimmed).
  - `minimal` (boolean, optional): `true` draws no card while nothing is being said -- one line centred above the head: `talkKey` as a small paper key cap, then `title`, on a transparent background (no plate, border, rule or list), kept legible by an ink halo on the letters. It follows the head and is clamped to the screen. While `lib.voiceListening` is active the key cap becomes the level meter on the same line. With `says` set, or when a `lib.voicePanel` belongs to the same person, the normal card is drawn instead.
  - `talkKey` (string, optional): the push-to-talk key for the minimal line (`'G'`, or a keybind name such as `'LMENU'`, shown as `Alt`).
  - `name` (string, optional): the person alone. Inside a minimal `title` it is drawn a weight heavier; it is also the card's heading when a minimal hint speaks (`title` there is the whole prompt, such as "Talk to Clara Morgan").

Returns: `nil`

Adds or updates a projected hint balloon. One shared thread projects every balloon (and the anchored panel) each frame with `GetScreenCoordFromWorldCoord` and removes balloons that go off screen rather than pinning them to the edge; the thread stops by itself when the last balloon and the anchored panel are gone.

```lua
local head = GetPedBoneCoords(ped, 0x796E, 0.0, 0.0, 0.0)
lib.voiceHint({ id = ('ped_%d'):format(ped), coords = head, title = 'Shopkeeper', icon = 'blip_shop_store', commands = { 'Show me your wares' } })
-- make the same balloon speak
lib.voiceHint({ id = ('ped_%d'):format(ped), coords = head, title = 'Shopkeeper', says = 'Take a look around.' })
-- the one-line prompt above the head (what w_voiceintract shows)
lib.voiceHint({ id = ('ped_%d'):format(ped), entity = ped, title = 'Talk to Clara Morgan', name = 'Clara Morgan', talkKey = 'G', minimal = true })
```

### lib.hideVoiceHint

```lua
lib.hideVoiceHint(id?: string)
```

Side: client

Parameters:

- `id` (string, optional): balloon to remove. Omitted: every balloon is removed.

Returns: `nil`

Removes one or all voice hint balloons and tells the frame.

```lua
lib.hideVoiceHint(('ped_%d'):format(ped))
lib.hideVoiceHint()  -- all
```

### lib.voiceSubtitle

```lua
lib.voiceSubtitle(data: VoiceSubtitle | false)
```

Side: client

Parameters:

- `data` (`VoiceSubtitle` or `false`, required): the line to show, or `false` to clear it.
  - `text` (string, required)
  - `state` (`'listening'`, `'matched'` or `'unknown'`, optional, frame default `'listening'`): told apart by a word over the line (Hearing / Understood / Not understood) and its rule (dashed, solid, red), not by colour alone.
  - `speaker` (string, optional): name shown above the text. A `speaker` line whose text a dialogue card on screen is already showing (`lib.voiceHint` `says`) is not drawn a second time; it shows again once that card is gone.
  - `duration` (number, optional, default 4000): milliseconds before it fades.
  - `hold` (boolean, optional): exactly `true` keeps it until replaced or cleared.

Returns: `nil`

Shows one subtitle line: what the player said (with its recognition state) or what an NPC answered. A new call replaces the previous line and restarts its timer.

```lua
lib.voiceSubtitle({ text = said, state = 'listening', hold = true })
lib.voiceSubtitle({ text = 'Welcome in.', speaker = 'Shopkeeper', state = 'matched', duration = 4500 })
lib.voiceSubtitle(false)
```

### lib.voiceListening

```lua
lib.voiceListening(active: boolean, level?: number | number[], label?: string)
```

Side: client

Parameters:

- `active` (boolean, required): `true` shows the microphone indicator; `false` (or `nil`) hides it and the other arguments are ignored.
- `level` (number or number[], optional): a single 0-100 loudness value, or an array of band values (0-100 each) for a spectrum. An array wins over a number; with neither, level 0 is sent.
- `label` (string, optional): text beside the indicator, for example `'Listening'`.

Returns: `nil`

Draws or clears the listening indicator in the library's frame. The meter is drawn once: in the key row of the card that holds a voice panel when one is up, otherwise in place of the key cap of the nearest minimal `lib.voiceHint` line, otherwise with `label` at the bottom of the screen. Purely visual; the script owns speech recognition and calls this as its state changes.

```lua
lib.voiceListening(true, 35, 'Listening')
-- later, with analyser bins
lib.voiceListening(true, { 10, 40, 80, 60, 20 })
lib.voiceListening(false)
```

### lib.hideVoice

```lua
lib.hideVoice()
```

Side: client

Parameters: none.

Returns: `nil`

Clears everything the voice UI draws: all hints, the panel (anchored or cornered), the listening indicator and the subtitle.

```lua
lib.hideVoice()
```

### exports.w_lib:Notify

```lua
exports.w_lib:Notify(title: string, message: string, style?: 'success' | 'error' | 'info', duration?: number)
```

Side: client

Parameters:

- `title` (string, required): title line (`nil` becomes `''`).
- `message` (string, required): body text (`nil` becomes `''`).
- `style` (string, optional): `'success'` (tick, green), `'error'` (cross, red) or `'info'` (warning icon, blue). Anything else falls back to the info icon and colour.
- `duration` (number, optional): milliseconds, default 5000.

Returns: `nil`

Forwards a right-to-left, middle-right notice to the `RK-text:send` event (the RK-text3d notification resource) with fixed icon and colour presets. It does not draw in the library's frame; if no resource handles `RK-text:send` nothing appears.

```lua
exports.w_lib:Notify('Store', 'Not enough money', 'error', 3000)
```

### exports.w_lib:NotifyPlayer

```lua
exports.w_lib:NotifyPlayer(source: number, title: string, message: string, style?: 'success' | 'error' | 'info', duration?: number)
```

Side: server

Parameters:

- `source` (number, required): target player's server id. `nil` does nothing.
- `title` (string, required): title line.
- `message` (string, required): body text.
- `style` (string, optional): `'success'`, `'error'` or `'info'`.
- `duration` (number, optional): milliseconds, default 5000 on the client.

Returns: `nil`

Server-side face of `Notify`: triggers the client event `w_lib:notify` on that player, which calls the client `Notify` export.

```lua
exports.w_lib:NotifyPlayer(source, 'Crafting', 'Recipe saved', 'success')
```

### w.ui.updateRank

```lua
w.ui.updateRank(level: integer, xp: integer, xpRequired: integer)
```

Side: client

Parameters:

- `level` (integer, required): rank number printed on the element.
- `xp` (integer, required): current XP (bar value and header text).
- `xpRequired` (integer, required): XP for the next level (bar maximum).

Returns: `nil`

Writes the `mp_rank_bar` databinding container so the rank element at the top-left of the weapon wheel shows the given level and XP. Module loaded with `w_module { 'ui' }` or `w.require('ui')`; also `jo.ui`.

```lua
w.ui.updateRank(15, 320, 1000)
```

### w.ui timer: initTimer, startTimer, stopTimer, finishTimer

```lua
w.ui.initTimer()
w.ui.startTimer(time?: integer, low?: integer)
w.ui.stopTimer()
w.ui.finishTimer()
```

Side: client

Parameters for `w.ui.startTimer`:

- `time` (integer, optional): seconds to count down from (default 60 when nil).
- `low` (integer, optional): seconds remaining at which the timer turns red (sets `isTimerLow`).

The other three take none.

Returns:

- `initTimer`: `number?` -- the UI state machine id, or `nil` if the flowblock failed to load or the state machine already existed
- `startTimer`, `stopTimer`, `finishTimer`: `nil`

`initTimer` loads the game's `cTimer` UI flowblock, creates the `centralInfoDatastore` bindings (`timerString`, `isVisible`) and the state machine `1546991729`. It must be called from a thread (it waits for the flowblock) before `startTimer`; call `finishTimer` when done to destroy it.

`startTimer` shows the native countdown and decrements it once a second using `w.timeout.delay('updateTimer', ...)`; when it passes zero it calls `w.ui.finishTimer`. It does nothing unless `initTimer` succeeded and the state machine exists. The timeout module is loaded on demand by the `w` table, so no extra require is needed.

`stopTimer` sets the remaining time to 0 and hides the timer without destroying the state machine (the pending tick then calls `finishTimer` within two seconds). No-op before `initTimer`.

`finishTimer` destroys the timer state machine and removes the databinding entries created by `initTimer`. It is called automatically when the countdown ends. No-op before `initTimer`.

```lua
CreateThread(function()
    w.ui.initTimer()
    w.ui.startTimer(90, 10)
end)

w.ui.startTimer(120, 15)
w.ui.stopTimer()
w.ui.finishTimer()
```

### lib.skillCheck, lib.cancelSkillCheck and lib.skillCheckActive

```lua
lib.skillCheck(difficulty: SkillCheckDifficulty | SkillCheckDifficulty[], inputs?: string[])
lib.cancelSkillCheck()
lib.skillCheckActive()
```

Side: client

Parameters for `lib.skillCheck`:

- `difficulty` (`'easy'`, `'medium'`, `'hard'`, `{ areaSize: number, speedMultiplier: number }`, or an array of those, required): one difficulty or a sequence of them, one per round. Forwarded to the frame as-is.
- `inputs` (string[], optional): key names the player must press when the cursor is in the zone; forwarded as-is.

The other two take none.

Returns:

- `lib.skillCheck`: `boolean?` -- `true` on success, `false` on failure; `nil` immediately if a skill check is already active
- `lib.cancelSkillCheck`: `nil`
- `lib.skillCheckActive`: `boolean` -- `true` while a `lib.skillCheck` call is pending

`lib.skillCheck` takes NUI focus (no cursor, game input blocked), sends `startSkillCheck` to the frame and awaits the `skillCheckOver` callback. Warning: no code in the shipped frame (`web/src`, `web/build`) or the legacy `nui/` and `html/` trees handles `startSkillCheck` or sends `skillCheckOver`, so in this build the promise never resolves, the calling thread blocks forever and the player is left with NUI focus and no game input. Do not use it until a frame listener exists.

`lib.cancelSkillCheck` sends `skillCheckCancel` to the frame and raises `No skillCheck is active` when none is running. As with `lib.skillCheck`, the shipped frame has no handler for this message, so it does not unblock a pending `lib.skillCheck` in this build.

`lib.skillCheckActive` is `true` while a `lib.skillCheck` call is pending.

```lua
-- Signature as defined; see the warning in the description before using it.
local ok = lib.skillCheck({ 'easy', 'medium', { areaSize = 40, speedMultiplier = 1.5 } }, { 'w', 'a', 's', 'd' })

if lib.skillCheckActive() then lib.cancelSkillCheck() end
```

### Events

| Name | Side | Payload | Meaning |
| --- | --- | --- | --- |
| `w_lib:promptCompleted` | client | `(id: integer, key: string)` -- handle of the group whose prompt completed, and the upper-cased key name as stored by `AddPrompt` | Fired locally by the library (`TriggerEvent`, so use `AddEventHandler`, not `RegisterNetEvent`) from a per-frame poll while a group created through `CreateGroup` is displayed, on the tick a prompt's press or hold completes. Every resource receives every completion, so filter on your own id and key. The poll runs every frame, so set any busy flag synchronously inside the handler before yielding, or the same action can be queued twice. |
| `w_lib:notify` | client (net) | `(title: string, message: string, style?: 'success'\|'error'\|'info', duration?: number)` -- duration in milliseconds, default 5000 | Net event received by the library's client that runs the `Notify` export. `NotifyPlayer` triggers it; a server script may trigger it directly with `TriggerClientEvent('w_lib:notify', src, ...)` and the same arguments. |
| `w_lib:progressProps` | server (internal) | prop list from `lib.progressBar` | Internal: trims the list to `w_lib:progressPropLimit` and writes it to the player's replicated state bag `lib:progressProps`. Not for consumer use. |

```lua
AddEventHandler('w_lib:promptCompleted', function(id, key)
    if id ~= groupId or key ~= 'E' then return end
    if busy then return end
    busy = true
    CreateThread(function() doAction(); busy = false end)
end)

TriggerClientEvent('w_lib:notify', src, 'Store', 'Purchase complete', 'success', 4000)
```

### Convars

| Name | Side | Value | Meaning |
| --- | --- | --- | --- |
| `w_lib:progressPropLimit` | shared | integer, default 2 (`setr w_lib:progressPropLimit <integer>`) | Maximum number of props attached during one progress bar. Read once at resource start on both the client (`GetConvarInt` in `progress.lua` line 14) and the server (`resource/interface/server/progress.lua` line 1). The server truncates the prop list it receives to this many before writing the state bag; the client also caps how many it creates. Changing it needs a restart of the library. |

```
# server.cfg
setr w_lib:progressPropLimit 3
```

### Commands

| Name | Side | Value | Meaning |
| --- | --- | --- | --- |
| `/cancelprogress` | client | none | Cancels the running `lib.progressBar` when its `canCancel` flag is `true`; otherwise does nothing. On FiveM it is registered as a key mapping on X; on RedM no key mapping is registered, so a consumer resource wanting a cancel key must bind it (for example with `RegisterKeyMapping` in its own resource pointing at this command). |

```lua
-- in a consumer resource, give players a key for it
RegisterKeyMapping('cancelprogress', 'Cancel action', 'keyboard', 'x')
```

## Localisation: lib.locale, locale files, getLocaleKey, setLocale, the i18n module

The library carries two independent localisation systems and one shared language switch.

**System one: the locale import.** A consumer resource ships `locales/<lang>.json`, calls `lib.locale()` once at startup, and then translates with the global `locale(key, ...)`. The import chunk is loaded into the consumer resource by `@w_lib/init.lua`, so the dictionary, the global `locale` function, `lib.getLocales`, `lib.getLocale` and the `exports.<consumer>:getLocale` export all live in the consumer's own Lua state; nothing about the consumer's strings is stored inside the library. Files are read with `LoadResourceFile` from the folder named by the fxmanifest metadata `locales_path` (default `locales`), so the JSON files must be listed in the consumer's `files {}` block for the client to receive them. English (`en.json`) is always loaded first and the active language is merged over it (nested objects key by key, the active language's value replacing the English one), so a key missing from `ar.json` falls back to the English string. A missing or invalid file only logs a warning and yields an empty table. Nested JSON objects are flattened to dotted keys (`ui.settings.locale`), string values may reference other keys with `${other.key}` (resolved once at load), and a value looked up with extra arguments is passed through `string.format`. Use `%s`/`%d` placeholders, escape a literal percent sign as `%%` in any string that will be formatted, and keep every value a string: a numeric value makes `locale(key, arg)` error because numbers have no `:format` method.

An important detail: `@w_lib/init.lua` only resolves the locale module (so `locale()` always exists and returns the key unchanged); it does not execute `lib.locale()`, and the manifest entry `w_lib { 'locale' }` is skipped for the same reason. Every real consumer here (w_inventory, w_survival) calls `lib.locale()` explicitly, and a consumer resource must do so before any UI text is built.

**System two: the i18n module.** The module (`modules/i18n`) is reached as `w.i18n.*` or `jo.i18n.*` once the resource has loaded the w layer via `@w_lib/init.lua`; it is loaded lazily the first time code touches `w.i18n`. It also runs as a private instance inside each resource that touches it: it reads `locales_modules/<lang>.json` from the consumer resource (declare them in `files {}`), flattens nested keys to dotted names, layers the active language over English, and lets a server owner override any single string with the convar `w_lib:i18n:translations:<dotted.key>`. Translation is `w.i18n.__(key)` (also the global `__` once the module is loaded), which returns `#key` when the key is unknown and takes no format arguments. The module initialises itself about one second after the library reports loaded (`w.ready` waits for `libLoaded` then `Wait(1000)`), and lazily on the first `__` / `getEntries` call. Adding the manifest metadata `w_lib_extra 'i18n:i18n:useGlobalLocales'` seeds the dictionary with the library's own `locales_modules` strings (currently only `common.buy` in ar/de/en/es/fr/it) before the consumer's own are merged. Because the module chunk runs inside the consumer resource, its `exports(...)` calls also register `onLocaleChange`, `w_i18n___`, `w_i18n_getEntries`, `w_i18n_addEntry` and `w_i18n_addEntries` on the consumer resource (acting on its instance), exactly as the library has them for its own instance.

The library's own `locales/<lang>.json` files (33 languages, keys such as `ui.cancel`, `ui.confirm`, `txadmin_*`) are the library's NUI strings: they are pushed into the w_lib web frame and are not meant to hold a resource's own text. Do not add consumer keys there.

**How the active language is chosen.** On the server, `lib.getLocaleKey()` returns `GetConvar('w_lib:locale')`, falling back to `GetConvar('w_lib:i18n:locale')` and then `'en'`. On the client, the library's `resource/settings.lua` computes the same default from those two convars (they are read client-side, so set them with `setr`; this server sets both to the same value so the two systems agree), and if the convar `w_lib:userLocales` is `1` (the default) it lets the player's own choice, stored in the library's resource KVP key `locale`, override it. The i18n module reads that same KVP on the client (`GetExternalKvpString('w_lib', 'locale')`) regardless of `w_lib:userLocales`. The player changes it from the `/w_lib` settings dialog (a searchable select built from `GlobalState['w_lib:locales']`, which the server fills from the files in `w_lib/locales`) or, when `w_lib:i18n:allowSwitchLocale` is not `"false"`, from the i18n command `/setLocale <code>` (renamable via `w_lib:i18n:localeCommand`). Both write the KVP (the dialog only when `w_lib:userLocales` is `1`), and both end by firing the local client event `w_lib:setLocale` with the new code. The i18n path additionally fires `w_lib:i18n:switchLocale`, which every loaded i18n instance answers by reloading, running its `onLocaleChange` hooks and firing `w_lib:setLocale` once more, so locale imports reload once per loaded i18n instance. The locale import in every consumer listens to `w_lib:setLocale` and reloads its dictionary automatically, so `locale()` follows the player live (this also undoes a language pinned with `lib.locale('xx')`). Anything cached from `locale()` or from `getLocaleKey` at load time must be refreshed in the consumer's own handler for that event.

Two gotchas. First, the `w_lib:setLocale` event is what carries the new code: `lib.getLocaleKey()` and `w.i18n.getLocale()` may still report the previous language after a switch made via `/setLocale` or a direct `lib.setLocale` call (only the `/w_lib` dialog updates the value `getLocaleKey` reads; only `w.i18n.setLocale` updates `getLocale`). Second, `lib.getLocaleKey()` from a consumer goes through the `exports.w_lib:getLocaleKey()` bridge, which can be a frame or two late at boot, so sibling resources wrap it in `pcall` and retry (w_map and w_pausemenu poll it 20 times at 250 ms, that is up to five seconds).

**Boundaries and conventions.** `lib.getLocaleKey` and `lib.setLocale` are defined in the library's own scripts, so from a consumer they resolve to exports (`exports.w_lib:getLocaleKey`, `exports.w_lib:setLocale`; `init.lua` builds a bridging function when no `imports/<name>` module exists). The rest of the locale import (`lib.locale`, `locale`, `lib.getLocales`, `lib.getLocale`) is plain Lua inside the consumer resource and never crosses an export. `w.i18n` functions are likewise local to the consumer's instance; the exports named `onLocaleChange`, `w_i18n_addEntry`, `w_i18n_addEntries`, `w_i18n_getEntries` and `w_i18n___` exist on w_lib (the library's own instance) and on every consumer that has loaded the module (that consumer's instance). By the library's convention functions are not passed across the export boundary: register hooks with `w.i18n.onLocaleChange` inside the consumer resource, and react to language changes through the events documented below. The client-side `w_lib:setLocale` event is a local (same-side) event: a client `TriggerEvent` reaches every client resource, and nothing on the server ever fires it, so server-side dictionaries stay on the convar language until restart. If a consumer resource mounts the library's frame (`ui_page 'nui://w_lib/web/build/index.html'`), `@w_lib/init.lua` also registers an internal `init` NUI callback and a `w_lib:setLocale` listener that push the library's UI strings into that frame; nothing needs to be done for that. Finally, `lib.notify(playerId, data)` from the server (marked deprecated in `init.lua`) runs `data.title` and `data.description` through the client's `locale()`, so locale keys may be passed there (without format arguments).

### Manifest setup: locales_path, files, w_lib { 'locale' }, w_lib_extra

```lua
locales_path 'folder'                              -- default 'locales'
files { 'locales/*.json' }                         -- for lib.locale() / locale()
files { 'locales_modules/*.json' }                 -- for w.i18n.__()
w_lib { 'locale', ... }                            -- no effect for 'locale' in this version
w_lib_extra 'i18n:i18n:useGlobalLocales'           -- seed w.i18n with the library's shared strings
```

Side: client | server | shared: shared

Parameters:
- `locales_path` (string, optional, default `locales`): folder inside the consumer resource that holds `<lang>.json` files for the locale import. Read once when the import loads (`GetResourceMetadata(resource, 'locales_path', 0)`); only the first value is used.
- `files { ... }`: both systems load JSON from the consuming resource with `LoadResourceFile`. Server-side reads work from disk, but the client only receives files listed in `files {}`.
- `w_lib { 'locale' }`: metadata that `@w_lib/init.lua` walks after start-up to eagerly load import modules and call them when they return a function. For `locale` it has no effect: `init.lua` already resolved `lib.locale` earlier, and the loop skips names already set on `lib`, so `lib.locale()` is never executed by the manifest. Sibling resources still list it for clarity but each calls `lib.locale()` explicitly in code.
- `w_lib_extra 'i18n:i18n:useGlobalLocales'`: checked once when the consumer's i18n instance loads, every value being compared. Accepted spellings are exactly `'i18n:i18n:useGlobalLocales'`, `'["i18n:i18n:useGlobalLocales"]'` or `'["i18n:i18n:useGlobalLocales:true"]'`. When present and the resource is not w_lib, `w.i18n.loadLocale` first copies the library's own dictionary (`exports.w_lib:w_i18n_getEntries()`, the strings of `w_lib/locales_modules` such as `common.buy`) and then merges the consumer's `locales_modules` files over it, so `__('common.buy')` resolves even if the consumer ships no such key. No sibling resource currently uses it.

Returns: n/a

File layout rules for both systems: `en.json` is the fallback base (a missing `en.json` is only a warning for `lib.locale` and silent for `w.i18n`, but then nothing falls back); any other language file may be partial. Nested objects become dotted keys; keep all values strings. Language codes are whatever file names are shipped; the library uses two-letter codes plus `pt-br`, `zh-cn` and `zh-tw`, and the `/w_lib` selector offers exactly the codes present in `w_lib/locales`, so name consumer files the same way.

```lua
-- fxmanifest.lua
shared_script '@w_lib/init.lua'
locales_path 'lang'          -- optional; default is 'locales'
files {
    'lang/*.json',            -- for lib.locale() / locale()
    'locales_modules/*.json', -- for w.i18n.__()
}
w_lib { 'locale', 'table', 'math' }
w_lib_extra 'i18n:i18n:useGlobalLocales'

-- init.lua (still required):
lib.locale()
```

### lib.locale

```lua
lib.locale(key?: string)
```

Side: client | server | shared: shared

Parameters:
- `key` (string, optional): language code to load, for example `'en'`, `'ar'`, `'pt-br'`. Defaults to `lib.getLocaleKey()` (server: convar `w_lib:locale`, then `w_lib:i18n:locale`, then `'en'`; client: the player's saved choice or the same convars). Because the default goes through `exports.w_lib:getLocaleKey()`, calling with no argument very early at boot can throw; wrap in `pcall` or pass an explicit key.

Returns: nothing

Loads (or reloads) the calling resource's translation dictionary. Reads `<locales_path>/en.json` from the calling resource, then, if `key` is not `'en'`, `<locales_path>/<key>.json` merged over it (nested objects are merged key by key, the active language's value replaces the English one; in a consumer the merge is the w-layer `table.merge`, which never adds numbers). The previous dictionary is wiped, nested keys are flattened to dotted names, and every `${other.key}` reference inside a string value is replaced by that key's value (percent signs in the substituted value are escaped so later `string.format` is safe). A missing file logs a warning (`could not load 'locales/xx.json'`) and counts as empty; invalid JSON logs a warning and counts as empty. Keep every value a string: a number stored in the dictionary makes `locale(key, arg)` error. The dictionary lives inside the consumer resource. It is re-run automatically with the new code whenever the client event `w_lib:setLocale` fires, which means a language pinned with `lib.locale('ar')` is replaced by the next switch. `@w_lib/init.lua` pre-resolves this module but does not call it, and the fxmanifest entry `w_lib { 'locale' }` is skipped for the same reason, so the consumer must call `lib.locale()` itself before using `locale()`. Do not confuse it with the global `locale()`: passing a translation key to `lib.locale` makes it look for `locales/<key>.json`.

```lua
-- fxmanifest.lua: shared_script '@w_lib/init.lua'  files { 'locales/*.json' }
-- locales/en.json: { "greet": "Hello %s", "ui": { "close": "Close" } }
lib.locale()            -- follows the library's language
-- or pin it: lib.locale('ar')
print(locale('greet', GetPlayerName(PlayerId())))
print(locale('ui.close'))
```

### locale (global)

```lua
locale(key: string, ...: string | number): string
```

Side: client | server | shared: shared

Parameters:
- `key` (string, required): dotted translation key as flattened from the JSON, for example `'ui.close'`.
- `...` (string | number, optional): `string.format` arguments applied to the translated string (`%s`, `%d`, `%.2f` and so on). Formatting only happens when the first extra argument is truthy; with none the string is returned untouched, so a literal `%` only needs to be written as `%%` in strings that will be formatted.

Returns: string: the translated (and formatted) text, or the key itself when it is not in the dictionary.

Global translation function created in every resource that loads `@w_lib/init.lua` (the locale import is resolved eagerly). Returns the key unchanged until `lib.locale()` has been called, and for unknown keys, so a raw key on screen means a missing entry rather than an error. Looks up the flat dictionary built by `lib.locale()`; `${other.key}` references were already resolved at load time. Follows the player's language automatically because the dictionary is reloaded on the `w_lib:setLocale` event.

```lua
Utils.Notify({ type = 'error', description = locale('cannot_perform') })
local label = locale('evidence_location', 3)   -- "Evidence locker %s" -> "Evidence locker 3"
```

### lib.getLocaleKey and exports.w_lib:getLocaleKey

```lua
lib.getLocaleKey(): string
exports.w_lib:getLocaleKey(): string
```

Side: client | server | shared: shared

Parameters: none

Returns: string: the active language code, for example `'en'` or `'ar'`.

Server: returns `GetConvar('w_lib:locale', GetConvar('w_lib:i18n:locale', 'en'))`. Client: returns the library's `settings.locale`, which is the player's saved choice from the library's KVP `locale` when convar `w_lib:userLocales` is `1` (default), otherwise the convar chain. Defined in the library's own scripts and exported, so in a consumer `lib.getLocaleKey()` falls through `init.lua`'s export bridge to `exports.w_lib:getLocaleKey()` (`init.lua` builds that bridge because no `imports/getLocaleKey` module exists; a sibling comment in w_inventory claiming it returns nil is wrong). The export form is registered explicitly on both sides (and again by `resource/init.lua`'s auto-export of `lib.*` defined under `resource/`), with identical behaviour.

It throws while the library has not registered the export yet (early boot), so sibling resources (w_hud, w_gunsmith, w_map, w_pausemenu, w_inventory) call it inside `pcall` and fall back to a default or retry. Its client value is only updated by the `/w_lib` dialog: after a switch made with `/setLocale` or a direct `lib.setLocale` it still reports the old code until the library restarts, so take the new code from the `w_lib:setLocale` event instead.

```lua
local function currentLang()
    local ok, key = pcall(function() return lib.getLocaleKey() end)
    return (ok and type(key) == 'string' and key ~= '') and key or 'en'
end
Config.IsRTL = (currentLang() == 'ar')

-- export form, same behaviour
local ok, key = pcall(function() return exports.w_lib:getLocaleKey() end)
Config.Locale = (ok and key == 'ar') and 'ar' or 'en'
```

### lib.setLocale and exports.w_lib:setLocale

```lua
lib.setLocale(key: string)
exports.w_lib:setLocale(key: string)
```

Side: client | server | shared: client

Parameters:
- `key` (string, required): language code to switch to. Not validated; the library falls back to its own `locales/en.json` for the NUI frame when `locales/<key>.json` does not exist in w_lib.

Returns: nothing

Client only (from a consumer it resolves to `exports.w_lib:setLocale`; on the server there is no such export and the call throws). Fires the local client event `w_lib:setLocale` with `key`, which makes every resource's locale import reload its dictionary, then sends the library's own `locales/<key>.json` to the library's NUI frame. It does not save the choice to KVP and does not update the value returned by `lib.getLocaleKey()`; the `/w_lib` dialog does both before calling this. It also does not notify `w.i18n` instances (they listen to `w_lib:i18n:switchLocale`). Use it to force the translation dictionaries of all client resources to a language for the current session. The export form is auto-exported by `resource/init.lua` because the function is defined under `w_lib/resource`, with the same behaviour and caveats.

```lua
RegisterCommand('lang_en', function()
    lib.setLocale('en')   -- every resource's locale() now answers in English
end, false)

exports.w_lib:setLocale('ar')
```

### lib.getLocales

```lua
lib.getLocales(): { [string]: string }
```

Side: client | server | shared: shared

Parameters: none

Returns: table: the live flat dictionary (dotted key to string) of the calling resource.

Returns the calling resource's current dictionary by reference (not a copy). It is empty before `lib.locale()` runs and is wiped and refilled in place on every reload (the table identity stays the same), so iterate it when needed rather than caching its contents. Useful for handing a whole catalogue to a NUI frame.

```lua
lib.locale()
SendNUIMessage({ action = 'setLocale', data = lib.getLocales() })
```

### lib.getLocale and exports.<your_resource>:getLocale

```lua
lib.getLocale(resource: string, key: string): string?
exports.<your_resource>:getLocale(key: string): string?
```

Side: client | server | shared: shared

Parameters (`lib.getLocale`):
- `resource` (string, required): name of another started resource that has loaded the library's locale import (and therefore exposes `exports.<resource>:getLocale`).
- `key` (string, required): dotted key to fetch from that resource's dictionary.

Parameters (`exports.<your_resource>:getLocale`):
- `key` (string, required): dotted key to read from that resource's flat dictionary.

Returns: string or nil. For `lib.getLocale`, the string found in the other resource, also stored into the calling resource's own dictionary under the same key.

`lib.getLocale` copies one translation from another resource into the calling resource's dictionary by calling `exports[resource]:getLocale(key)`. It warns if the local dictionary already had that key (it is overwritten) and warns if the other resource has no such key (nil is stored). The other resource must have run `lib.locale()` already, otherwise its dictionary is empty. Because it goes through an export, the other resource must be started and must have loaded `@w_lib/init.lua`; the call throws if the export does not exist. The copied entry is lost when the local dictionary is next reloaded (`w_lib:setLocale` or another `lib.locale` call).

`exports.<your_resource>:getLocale` is registered automatically inside every resource that loads `@w_lib/init.lua` (the locale import chunk runs in the consumer, and its `exports()` call therefore registers on the consumer). It is the backing export used by `lib.getLocale`; other resources can call it directly to read one string in the resource's current language. Returns nil before `lib.locale()` has run in that resource or when the key is absent. This export is on the consumer resource, not on w_lib.

```lua
-- reuse w_inventory's wording for "Cancel" inside this resource
local cancel = lib.getLocale('w_inventory', 'ui_cancel')
print(locale('ui_cancel'))  -- now resolves in this resource too

-- direct export read from another resource
local text = exports.w_inventory:getLocale('police_evidence')
```

### GlobalState['w_lib:locales']

```lua
GlobalState['w_lib:locales']: { label: string, value: string }[]
```

Side: client | server | shared: shared

Parameters: none

Returns: array of `{ label = display name, value = language code }`, sorted by label.

Set once by the library's server script from the JSON files in `w_lib/locales`: `value` is the file name without `.json`, `label` is that file's top-level `"language"` string (or the code when missing). Read by the `/w_lib` dialog to build the language select; a consumer may read it to offer the same list or to check whether a code is one the library knows.

```lua
for _, entry in ipairs(GlobalState['w_lib:locales'] or {}) do
    print(entry.value, entry.label)   -- 'ar' <Arabic name>, 'en' 'English', ...
end
```

### w.i18n.__ and the global __

```lua
w.i18n.__(key: string): string
__(key: string): string
```

Side: client | server | shared: shared

Parameters:
- `key` (string, required): dotted key from the consumer's `locales_modules` JSON (or any raw text used as the key, as w_creators does).

Returns: string: the translation, or `'#' .. key` when unknown.

Translation function of the i18n system. Initialises the instance lazily on first use. Unlike `locale()`, it takes no format arguments and signals a missing key with a leading `#`, so wrap it if the key itself is preferred back. The global `__` is set to this function (`_G.__ = w.i18n.__`) when the module loads in the consumer resource, which happens the first time code touches `w.i18n` (or `jo.i18n`); until then `__` is nil. `jo.i18n.__` is the same function. Exported as `w_i18n___(key)` on w_lib (against the library's own dictionary) and on every consumer that loaded the module.

```lua
local function T(text)
    local ok, out = pcall(w.i18n.__, text)
    if not ok or type(out) ~= 'string' or out:sub(1, 1) == '#' then return text end
    return out
end
lib.inputDialog(T('Enter a name'), { { type = 'input', label = T('First name'), required = true } })

local _ = w.i18n   -- ensures the module (and the global __) is loaded
print(__('shop.buy'))
```

### w.i18n.getLocale

```lua
w.i18n.getLocale(): string
```

Side: client | server | shared: shared

Parameters: none

Returns: string: the language code this i18n instance is using.

Returns the instance's current language. At load it is `GetConvar('w_lib:i18n:locale', 'en')`, overridden on the client by the library's KVP `locale` (the player's saved choice, read with `GetExternalKvpString`) if present; afterwards it changes only through `w.i18n.setLocale` (which the `w_lib:i18n:switchLocale` event calls). It is not updated by `lib.setLocale` or the `/w_lib` dialog, so w_map and w_pausemenu read it only as a fallback after `exports.w_lib:getLocaleKey`. Also reachable as `jo.i18n.getLocale`.

```lua
local ok, code = pcall(w.i18n.getLocale)
local lang = (ok and code ~= '') and code or GetConvar('w_lib:i18n:locale', 'en')
local dir = lang:sub(1, 2) == 'ar' and 'rtl' or 'ltr'
```

### w.i18n.setLocale

```lua
w.i18n.setLocale(locale: string)
```

Side: client | server | shared: shared

Parameters:
- `locale` (string, required): new language code for this instance.

Returns: nothing

Switches this instance: stores the code, reloads the dictionary, runs every callback registered with `w.i18n.onLocaleChange` (hook action `w_i18n_locale_change`, in priority order, each `pcall`-protected, receiving the code), and finally calls `TriggerEvent('w_lib:setLocale', locale)` so every resource's locale import reloads too. It does not save to KVP and does not notify other resources' i18n instances; only the `w_lib:i18n:switchLocale` event does that. Works on the server as well, but nothing on the server ever calls it automatically.

```lua
w.i18n.setLocale('en')   -- this resource's __() and everyone's locale() now English
```

### w.i18n.onLocaleChange and exports.w_lib:onLocaleChange

```lua
w.i18n.onLocaleChange(callback: fun(locale: string), priority?: number)
exports.w_lib:onLocaleChange(callback: function, priority?: number)
```

Side: client | server | shared: shared

Parameters:
- `callback` (function, required): called with the new language code after this instance's dictionary has been reloaded.
- `priority` (number, optional, default 10): ordering among callbacks; lower runs first.

Returns: nothing

Registers a hook (`w.hook.registerAction 'w_i18n_locale_change'`) on the consumer resource's own i18n instance. It fires when `w.i18n.setLocale` runs there, which happens on the client whenever the `w_lib:i18n:switchLocale` event is received (the `/setLocale` command), and whenever the consumer calls `w.i18n.setLocale` itself. It does not fire for the `/w_lib` dialog or `lib.setLocale`; listen to the `w_lib:setLocale` event for those. Touching `w.i18n` loads the module lazily, so registering the hook also makes the resource start following `switchLocale`. Errors thrown by the callback are caught and logged. w_map and w_pausemenu register it with `pcall` one second after start, alongside a `w_lib:setLocale` handler.

`exports.w_lib:onLocaleChange` is the export form bound to the library's own instance (fires when that instance switches: the `/setLocale` command or a `w_lib:i18n:switchLocale` event). The same export name is also registered on every consumer that has loaded the i18n module, bound to that consumer's instance. By the library's convention functions are not passed across the export boundary; use `w.i18n.onLocaleChange` inside the consumer resource, or listen to the `w_lib:setLocale` / `w_lib:i18n:switchLocale` events, instead of this export.

```lua
CreateThread(function()
    Wait(1000)
    if type(w) == 'table' and type(w.i18n) == 'table' then
        pcall(w.i18n.onLocaleChange, function(locale) apply(locale, 'w.i18n') end)
    end
end)
```

### w.i18n.addEntry, w.i18n.addEntries, w.i18n.getEntries

```lua
w.i18n.addEntry(key: string, value: string)
w.i18n.addEntries(entries: table)
w.i18n.getEntries(): table
```

Side: client | server | shared: shared

| Function | Parameters | Returns | Behaviour |
|---|---|---|---|
| `w.i18n.addEntry` | `key` (string, required): dotted key to set; `value` (string, required): translation text | nothing | Adds or overwrites one entry in this instance's dictionary. No convar override is applied. |
| `w.i18n.addEntries` | `entries` (table, required): possibly nested table of strings; nested tables are flattened to dotted keys and each value can be overridden by convar `w_lib:i18n:translations:<dotted.key>` | nothing | Flattens `entries` and merges them into this instance's dictionary (existing keys overwritten). |
| `w.i18n.getEntries` | none | table: the instance's flat dictionary (dotted key to string), by reference | Initialises the instance if needed, then returns its dictionary. |

Entries added with `addEntry` or `addEntries` are lost on the next `loadLocale` / `setLocale` (the dictionary is wiped), so re-add them from an `onLocaleChange` hook if they must survive a switch. Do not keep the reference from `getEntries` across a language switch when `useGlobalLocales` is on (`loadLocale` then replaces the table). All three are exported as `w_i18n_addEntry`, `w_i18n_addEntries` and `w_i18n_getEntries` on w_lib (acting on the library's instance; `w_i18n_getEntries` there returns the library's own module strings from `w_lib/locales_modules` and is what the `useGlobalLocales` manifest flag pulls in) and on every consumer that loaded the module (acting on that consumer's instance).

```lua
w.i18n.addEntry('shop.sold_out', 'Sold out')
print(__('shop.sold_out'))

w.i18n.addEntries({ shop = { buy = 'Buy', sell = 'Sell' } })
print(__('shop.sell'))

local all = w.i18n.getEntries()
for k, v in pairs(all) do print(k, v) end
```

### w.i18n.loadLocale and w.i18n.init

```lua
w.i18n.loadLocale(locale: string)
w.i18n.init()
```

Side: client | server | shared: shared

Parameters (`loadLocale`):
- `locale` (string, required): language code whose `locales_modules/<locale>.json` (in the consumer resource) is layered over English.

Parameters (`init`): none

Returns: nothing

`w.i18n.loadLocale` rebuilds the instance dictionary: wipes it, optionally seeds it with a copy of the library's global entries (`exports.w_lib:w_i18n_getEntries()`) when the manifest metadata `w_lib_extra 'i18n:i18n:useGlobalLocales'` is present and the caller is not w_lib, then merges `locales_modules/en.json` and, if `locale ~= 'en'`, `locales_modules/<locale>.json` from the calling resource. Missing files are silently treated as empty; invalid JSON prints an error and counts as empty. Every value is subject to the convar override `w_lib:i18n:translations:<dotted.key>`. With `useGlobalLocales` the dictionary becomes a new table on each call, so a reference obtained earlier from `getEntries()` goes stale. It does not change `getLocale()` and does not fire hooks; prefer `w.i18n.setLocale` for a real switch.

`w.i18n.init` loads the current locale (`w.i18n.loadLocale(currentLocale)`) and marks the instance initialised. It is called automatically by `w.ready` (a thread that waits for the w layer's `libLoaded` flag and then `Wait(1000)`) and lazily by the first `w.i18n.__` / `getEntries` call, so it is normally never called by hand; call it only if the dictionary must be ready before that.

```lua
w.i18n.loadLocale('fr')   -- reload French strings without firing change hooks

w.i18n.init()
print(__('common.buy'))
```

### w.i18n.findMissingKeys

```lua
w.i18n.findMissingKeys(locale: string)
```

Side: client | server | shared: shared

Parameters:
- `locale` (string, required): language code to compare against English. Passing `'en'` only prints `Cannot compare 'en' with 'en'`.

Returns: nothing (prints one line per missing key)

Development helper: loads the consumer's `locales_modules/en.json` and `locales_modules/<locale>.json` and prints `Missing key '<dotted.key>' in '<locale>'` for every English key absent from the other file (if that file is missing, every key is reported). Does not modify the dictionary.

```lua
RegisterCommand('i18n_check', function(_, args)
    w.i18n.findMissingKeys(args[1] or 'ar')
end, false)
```

### i18n exports on w_lib and on consumer resources

```lua
exports.w_lib:w_i18n___(key: string): string
exports.w_lib:w_i18n_getEntries(): table
exports.w_lib:w_i18n_addEntry(key: string, value: string)
exports.w_lib:w_i18n_addEntries(entries: table)
exports.w_lib:onLocaleChange(callback: function, priority?: number)

exports.<your_resource>:w_i18n___(key: string): string
exports.<your_resource>:w_i18n_getEntries(): table
exports.<your_resource>:w_i18n_addEntry(key: string, value: string)
exports.<your_resource>:w_i18n_addEntries(entries: table)
exports.<your_resource>:onLocaleChange(callback: function, priority?: number)
```

Side: client | server | shared: shared

Parameters:
- `key` / `value` / `entries` / `callback` / `priority`: same meaning as the `w.i18n` functions of the same name.

Returns: as the corresponding `w.i18n` function (tables come back as copies across the export boundary).

On w_lib these act on the library's own i18n instance (strings from `w_lib/locales_modules` plus anything added through them), not on the consumer's instance, so they are mainly useful to read or extend the shared global strings that the `useGlobalLocales` flag imports. Because `modules/i18n/shared.lua` is loaded into every resource that touches `w.i18n`, its `exports(...)` calls register the same five names on that resource as well, each bound to that resource's own instance. Another resource can therefore read a consumer's module strings with `exports.<your_resource>:w_i18n___('some.key')` once the consumer has loaded the module. They exist only after the resource has touched `w.i18n`; calling them earlier throws `No such export`. Do not pass functions through `onLocaleChange` across resources; it exists for parity with w_lib, not as an API to rely on. For a resource's own strings use `w.i18n.*` locally.

```lua
print(exports.w_lib:w_i18n___('common.buy'))   -- "Buy" (the library's shared string)

-- from another resource, after w_shop has loaded w.i18n:
local label = exports.w_shop:w_i18n___('shop.buy')
```

### Library locale files: w_lib/locales and w_lib/locales_modules

```lua
-- w_lib/locales/en.json (library NUI strings)
{ language, settings,
  ui = { cancel, close, back, move_select, confirm, more,
         settings = { locale, locale_description, notification_audio, notification_position },
         position = { top, top-left, ... } },
  open_radial_menu, cancel_progress,
  txadmin_announcement, txadmin_dm, txadmin_warn, txadmin_warn_content, txadmin_scheduledrestart }

-- w_lib/locales_modules/en.json (shared i18n strings)
{ "common": { "buy": "Buy" } }
```

Side: client | server | shared: `locales` is client; `locales_modules` is shared

Parameters: none

Returns: n/a

`w_lib/locales/<lang>.json` holds the library's own UI strings in 33 languages (al, ar, cs, da, de, el, en, es, et, fi, fr, he, hr, hu, id, it, ja, ka, lt, nl, no, pl, pt-br, pt, ro, ru, sk, sl, sv, th, tr, zh-cn, zh-tw). Top-level `"language"` is the display name shown in the `/w_lib` selector; `"ui"` holds the button labels and settings labels the NUI frame uses; the remaining flat keys are the library's key-mapping descriptions and txAdmin notification titles. Values follow the same rules as any locale import file, including cross-references (`ui.settings.locale_description` is `"Current language: ${language} (%s)"`). The library loads this file with `lib.locale` for itself and pushes the raw JSON to its NUI frame (and to a consumer's frame when that consumer mounts `nui://w_lib/web/build/index.html`). These are library strings only; a resource's own text goes in the resource's own `locales/<lang>.json`, and adding a language to the `/w_lib` selector means adding a file here with a `"language"` field.

`w_lib/locales_modules/<lang>.json` is the library's own i18n dictionary, flattened to keys such as `common.buy`, shipped for ar, de, en, es, fr and it. It is what `exports.w_lib:w_i18n___` / `w_i18n_getEntries` answer from and what the `useGlobalLocales` manifest flag copies into a consumer. A consumer's own `locales_modules/<lang>.json` follows the same nested-object layout with string values; using source-language sentences as keys and translating them in `en.json` (with the source language file as an identity map) is also valid.

```lua
-- consumer locales_modules/en.json
{ "shop": { "buy": "Buy", "sell": "Sell" } }
-- consumer code
print(__('shop.buy'))

-- if the consumer mounts the library's frame the ui.* labels arrive on their own:
-- fxmanifest.lua: ui_page 'nui://w_lib/web/build/index.html'
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:setLocale` | client (local, non-network) | `key: string`, the new language code | Fired by `lib.setLocale`, by the `/w_lib` settings dialog after the player picks a different language, and by `w.i18n.setLocale` in every i18n instance (hence once per loaded instance after `/setLocale`). The locale import in every resource already handles it by calling `lib.locale(key)`; register a handler to refresh anything derived from the language (RTL flag, cached strings, blip names, an open NUI). Use the key passed to the handler, not `lib.getLocaleKey()`, because the latter can lag. A handler also exists on the server side of the import, but nothing on the server ever triggers the event, so server dictionaries only change on restart. Any client resource may `TriggerEvent` it, and it reaches all client resources. |
| `w_lib:i18n:switchLocale` | client (local) | `locale: string` | Handled by `modules/i18n/client.lua`, which is loaded into every resource that has touched `w.i18n` (and into w_lib itself): each handler calls its own `w.i18n.setLocale(locale)`, so all i18n instances switch, their `onLocaleChange` hooks run, and each one fires `w_lib:setLocale` in turn. Fired by the `/setLocale` command; a consumer may `TriggerEvent` it to switch every i18n instance client-side without saving to KVP. Nothing fires it on the server and no server handler exists. |

```lua
AddEventHandler('w_lib:setLocale', function(key)
    Config.Locale = key
    Config.IsRTL = (key == 'ar')
    if uiOpen then SendNUIMessage({ action = 'setLocale', data = lib.getLocales() }) end
end)

-- switch every client resource's i18n dictionary at once (session only)
TriggerEvent('w_lib:i18n:switchLocale', 'en')
```

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:locale` | shared (set with `setr`) | language code; default: the value of `w_lib:i18n:locale`, else `en` | Primary default language for the locale import system. Read on the server by `lib.getLocaleKey()` and on the client by the library's settings (as the default before the player's KVP choice). If unset, falls back to `w_lib:i18n:locale` so the two systems agree; this server sets both to the same value. |
| `w_lib:i18n:locale` | shared (set with `setr`) | language code; default `en` | Default language of the i18n module (`w.i18n` / `__`), read once when each i18n instance loads. Also the fallback for `w_lib:locale` on both sides. On the client a player's saved choice (the library's KVP `locale`) overrides it for `w.i18n` as well, whatever `w_lib:userLocales` says. |
| `w_lib:userLocales` | client (set with `setr`) | integer; `1` (default) or `0` | When `1`, `settings.locale` (what `lib.getLocaleKey` returns on the client) is the player's KVP `locale` if set, else the convar default, and the `/w_lib` dialog shows the language selector. When `0` the selector is hidden and the convar language is used. Does not affect the i18n module: `/setLocale` still exists and `w.i18n` still reads the KVP at load. |
| `w_lib:i18n:translations:<dotted.key>` | shared (set with `setr`) | replacement text for that key; default: the value from the JSON file | Per-key override applied by the i18n module whenever it flattens a locale file or `addEntries` payload (`GetConvar('w_lib:i18n:translations:' .. key, fileValue)`). Lets a server owner reword any i18n string of any resource without editing files. Applies to every language and is read inside each resource's own instance. Has no effect on `locale()` strings or on `addEntry`. |
| `w_lib:i18n:allowSwitchLocale` | client (set with `setr`) | string; `"true"` (default) or any other value | Read by the library's client-only i18n script at start (it runs only inside w_lib). When `"true"`, the command named by `w_lib:i18n:localeCommand` and its chat suggestion are registered. Independent of `w_lib:userLocales`. |
| `w_lib:i18n:localeCommand` | client (set with `setr`) | command name without the slash; default `setLocale` | Name of the language-switch command registered when `allowSwitchLocale` is true; a chat suggestion is added under the same name. |

```lua
-- server.cfg
setr w_lib:locale "ar"
setr w_lib:i18n:locale "ar"
setr w_lib:userLocales 0                          # everyone uses the server language
setr w_lib:i18n:translations:common.buy "Purchase"
setr w_lib:i18n:allowSwitchLocale "false"
setr w_lib:i18n:localeCommand "lang"              # players type /lang ar
```

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `/w_lib` | client | none | Opens the library's settings dialog (`lib.inputDialog`): notification audio checkbox, notification position select and, when `w_lib:userLocales` is `1`, a searchable language select whose options come from `GlobalState['w_lib:locales']` (labels are the `"language"` field of each `w_lib/locales/<code>.json`, values the codes). Choosing a different language saves it to the library's KVP `locale`, updates the value `lib.getLocaleKey()` returns, and calls `lib.setLocale` (firing `w_lib:setLocale`); picking the same language again does nothing. Consumers cannot add options; ship the same codes as `w_lib/locales`. |
| `/setLocale <locale>` | client | `locale: string`, not validated; a missing argument prints a usage line | Registered by the library when `w_lib:i18n:allowSwitchLocale` is true, under the name from `w_lib:i18n:localeCommand`. Saves the code to the library's KVP `locale` (the same key the `/w_lib` dialog uses, so it persists and is picked up by both systems on the next start), calls the library's own `w.i18n.setLocale` (which fires `w_lib:setLocale`, reloading every resource's `locale()` dictionary), then `TriggerEvent('w_lib:i18n:switchLocale', locale)` so every loaded i18n instance in every client resource (the library's own included, a second time) switches and runs its `onLocaleChange` hooks. It does not update the value `lib.getLocaleKey()` returns during the current session. |

```lua
-- nothing to call; tell players to type /w_lib or /setLocale ar and react to the change:
AddEventHandler('w_lib:setLocale', function(key) rebuildMenus(key) end)
w.i18n.onLocaleChange(function(locale) rebuildMenus(locale) end)
```

## Callbacks, events, hooks and cross-resource communication

The library ships two independent request/response ("callback") systems. Pick one per resource and never use the same name in both. Be aware that in a consumer resource `w.callback` is not `lib.callback`: the `w` table resolves a w module first and only falls back to `lib.<name>` when no module of that name exists. So `w.waitFor`, `w.timer` and `w.cron` reach the lib versions, but `w.callback` and `w.hook` are the w modules.

### The `lib.callback` family

The first system is the ox_lib style `lib.callback` family. It is loaded into the consumer resource's own Lua VM the first time `lib.callback` is touched, so the pending-request table, the reply event `__ox_cb_<yourResource>` and the timeout all live inside the consumer resource. On the client, `lib.callback.await('name', delay, ...)` asks the server; on the server, `lib.callback.await('name', playerId, ...)` asks one client. A handler registered on the server always receives `source` as its first argument; a handler registered on the client receives only the arguments that were sent.

Names are owned. `lib.callback.register` calls the library export `setValidCallback`, which records that the registering resource owns the name and prints a SCRIPT ERROR if another resource tries to take it.

Two behaviours are not visible from the API:

1. The reply that tells a caller "that callback does not exist" is sent by the library on `__w_cb_<resource>`, while the caller listens on `__ox_cb_<resource>`. Calling an unregistered name therefore does not error; it hangs until the convar `w_lib:callbackTimeout` (default 300000 ms) rejects the promise and `lib.callback.await` raises "callback event ... timed out". Wrap awaits in `pcall` if a missing handler is possible.
2. If a handler throws, the library prints the error and the caller receives no values (nil). Treat nil as failure.

### The `w.callback` system

The second system is `w.callback` (also reachable as `jo.callback`, since `jo` is an alias of the same `w` table). In a consumer resource, `w.callback` is the table returned by `exports.w_lib:getCallbackAPI()`, so every call is a function reference into the library's own VM, and the registry of names is global per side: one client registry per player and one server registry, shared by all resources.

Because the whole table crosses the export boundary as function references, Lua functions can be passed to `w.callback.register` and as the `cb` argument of `triggerServer`/`triggerClient`. The library detects a "function" by testing for a callable table, which is exactly what a cross-resource function reference is. Arguments and return values are msgpack-serialised, so send plain data (numbers, strings, tables, vectors), not userdata or closures inside tables. Server handlers receive `source` first.

The `cb` slot is optional: if the second argument is not a function it is treated as the first data argument and the call becomes synchronous (it yields and returns the handler's return values). Server-to-client `w.callback.triggerClient` and server-side `w.callback.await` settle once on the response, player disconnect, calling resource stop, or a default 15000 ms deadline (`w_lib:clientCallbackTimeout`, clamped to 1000-120000 ms). A timeout returns nil and removes the reply listener; it does not prove the client action was not performed. Client-to-server requests have a separate default 30000 ms timeout (`w_lib:callbackTimeout`). The server rejects unregistered names immediately and limits requests and in-flight handlers per player. Register server callbacks at file load, before any client can ask. Names beginning with `w_lib:` survive resource stops; every other name is dropped automatically when the registering resource stops, and re-registering an existing name is refused with an error print. A "latent" registration (`w.callback.register.latent` / `registerLatentCallback`) sends the reply through the bandwidth-limited latent event path governed by the convar `w_lib:emit:bps`.

### Event helpers and scoped modules

`w.emit` wraps the event natives with one-time msgpack packing and adds latent (rate-limited) variants and multi-target sends; `lib.triggerClientEvent` is the ox_lib equivalent for arrays of players. `w.emit.triggerServerWithSource(source, event, ...)` makes the target client re-trigger a server event so that the handler sees that player as `source` (`w.triggerEvent.server` is the deprecated older name, loaded by default on every server script). The client-side `w.emit.triggerClient` is deprecated and unsafe: it asks the server to relay any event to any client without validation (server event `w_lib:server:emit:dispatch`). Do not use it.

The emit, hook, waiter, promise, timeout and gameEvents modules are "scoped": their code is loaded into the consumer resource's VM when `w.<module>` is first touched (or when `w.require("emit")` and similar are called). This means `w.hook` action and filter lists, `w.timeout` debounce ids and `w.emit.updateBps` are per resource. `w.hook.registerAction` in resource A and `w.hook.doActions` in resource B do not see each other. To hook into another resource's action, call `exports.<thatResource>:registerAction(name, fn, priority)`, which every resource exposes automatically once it has loaded `w.hook`. The library itself exposes `exports.w_lib:registerAction` and fires actions such as `w_lib:applySkinAndClothes:before/after`, `w_lib:applySkin:before`, `w_lib:applyClothes:before/after` and `w_i18n_locale_change`. A function passed this way arrives as a function reference and is removed when the registering resource stops. `registerFilter`, `RegisterAction` and `RegisterFilter` are exported too, but only by resources that declare `w_module { 'hook' }` in their fxmanifest. Client-to-server filtering within the same resource is `w.hook.applyServerFilters`, which uses a `w.callback` named `<yourResource>:hook:callFilter` that is registered only when the server side has loaded `w.hook`; call `w.require("hook")` in a server script at startup or the client call will hang.

### The `lib.hook` pipeline, game events and timing

The ox_lib hook pipeline (`lib.hook`, `lib.registerHook`) is a separate, class-based mechanism for letting other resources veto or observe an event in the consumer resource. The owning resource creates `lib.hook:new('event', filter)`, which auto-creates the exports `registerHook:<event>` and `removeHook:<event>`; other resources call `lib.registerHook('owner:event', handler, options)` and receive an `EventHook` object with `:on(handler)`, `:off()` and `:remove()`. The pipeline filter is effectively required: with no filter, no registered hook ever runs. `dispatch(payload)` returns a to-be-closed result; declare it with `local result <close> = pipeline:dispatch(payload)` so that closing it broadcasts `(ok, payload)` to every hook's post-handler.

`w.gameEvents.listen` (client only) exposes 119 native RDR2 game events (`EVENT_*` names, listed under its entry) as local client events `w_lib:gameEvents:<NAME>`; the polling loop runs inside the library only after the first listener registers.

Timing utilities: `w.waiter.exec` (poll until a condition or a timeout), `w.promise.new` (turn a callback-style function into a blocking call), `w.timeout.set/loop/delay/noSpam` (cancelable timers, trailing and leading debounce), `lib.timer` (pausable countdown, blocking unless `async=true`, `onEnd` required in practice), `lib.waitFor` (poll a function until non-nil, error after 1000 ms by default) and the server-only `lib.cron.new` (5-field cron expressions; each resource that loads `lib.cron` gets its own task list and its own midnight job that restarts stopped tasks).

### Debug output

`<yourResource>:debug on` sets `w.debug` in that resource (hook modules then print "Action fired" / "Filter fired"). `<resource>:debug:<module> on` or `all:debug:<module> on` enables module-level tracing in the resource whose code runs, so `w.callback` response tracing (which runs inside the library) needs `w_lib:debug:callback` or `all:debug:callback`. All of these are read at load and live-updated; use `setr` for anything the client must see.

### manifest `w_module { 'hook' }`

```lua
w_module { 'hook' }  -- in your fxmanifest.lua
```

Side: shared

Parameters: none (the value is any module folder name or alias; several may be listed).

Returns: n/a

Declares w modules to preload when the consumer resource starts. For this subsystem the relevant effect is on `'hook'`: besides loading `w.hook` (and, on the server, registering the `<yourResource>:hook:callFilter` callback) before the resource's scripts run, it makes the resource export `registerFilter`, `RegisterAction` and `RegisterFilter` in addition to the always-present `registerAction`. Listing `'callback'` or `'emit'` simply preloads those modules.

```lua
-- fxmanifest.lua
shared_script '@w_lib/init.lua'
w_module { 'hook', 'callback' }
```

### lib.callback.register (client)

```lua
lib.callback.register(name: string, cb: fun(...): ...)
```

Side: client

Parameters:
- `name` (string, required): Unique callback name. Convention is `'resource:purpose'`. Ownership is recorded in the library via `setValidCallback`; another resource re-registering the same name gets a SCRIPT ERROR print and its handler is still attached, so both would answer. Registering the same name twice in the same resource silently adds a second handler (both reply).
- `cb` (function, required): Handler run when the server calls this name. Receives exactly the arguments the server sent (no source). Whatever it returns (multiple values allowed) is sent back to the server. If it throws, the error is printed and the server receives nil.

Returns: nothing

Registers a client-side handler that answers server requests made with `lib.callback.await(name, playerId, ...)` or `lib.callback(name, playerId, cb, ...)`. Runs inside the consumer resource; the reply is routed automatically on the net event `__ox_cb_<name>`. Register at file load, before the server may ask. The handler is wrapped in `pcall`, so a thrown error never crashes the caller, but the caller sees nil.

```lua
lib.callback.register('w_inventory:usingItem', function(data, noAnim)
    -- play animation, then report success
    return true
end)
```

### lib.callback.register (server)

```lua
lib.callback.register(name: string, cb: fun(source: number, ...): ...)
```

Side: server

Parameters:
- `name` (string, required): Unique callback name; ownership is recorded in the library and cleared when the resource stops. Registering twice in the same resource adds a second handler.
- `cb` (function, required): Handler; the first argument is always the requesting player's server id (`source`), followed by the client's arguments. Return values (multiple allowed) are sent back. Thrown errors are printed and the client receives nil.

Returns: nothing

Registers a server-side handler answering client requests made with `lib.callback.await` / `lib.callback`. The handler runs in the consumer resource and is pcall-wrapped. Always validate `source` inside the handler; any client that knows the name can call it.

```lua
lib.callback.register('w_creators:getCharacters', function(source)
    return exports.oxmysql:query_async('SELECT * FROM characters WHERE identifier = ?', { GetPlayerIdentifierByType(source, 'license') })
end)
```

### lib.callback.await (client)

```lua
lib.callback.await(event: string, delay: number|false|nil, ...): ...
```

Side: client

Parameters:
- `event` (string, required): Name registered on the server with `lib.callback.register`.
- `delay` (number|false|nil, required): Rate limit in ms as in `lib.callback`; when the call is suppressed the function returns nil immediately. Pass `false` for no limit.
- `...` (any, optional): Arguments delivered to the server handler after `source`.

Returns: the server handler's return values (multiple allowed); nil if the handler errored; raises the error `callback event <name>:<key> timed out` after `w_lib:callbackTimeout` ms (default 300000) if no reply arrives, including when the name is not registered.

Sends a request to the server and yields the current thread until the reply arrives. Must be called from a thread that may yield (`CreateThread`, an event handler, an NUI callback). Because the invalid-name notification never reaches the caller in this build, an unregistered name waits for the full timeout and then errors; use `pcall` to survive that.

```lua
CreateThread(function()
    local ok, problem = lib.callback.await('w_crafting:admin:saveBench', false, { id = 3, label = 'Forge' })
    if not ok then print(problem) end
end)
```

### lib.callback.await (server)

```lua
lib.callback.await(event: string, playerId: number, ...): ...
```

Side: server

Parameters:
- `event` (string, required): Name registered on the target client.
- `playerId` (number, required): Target player's server id; must exist or an assertion error is raised.
- `...` (any, optional): Arguments delivered to the client handler.

Returns: the client handler's return values; nil if it errored; raises `callback event ... timed out` after `w_lib:callbackTimeout` ms if the client never replies.

Sends a request to one client and yields until the reply. Use from a thread that may yield. An unregistered client name hangs for the timeout and then errors (see the overview).

```lua
local success = lib.callback.await('w_inventory:usingItem', source, data, noAnim)
if success then
    -- consume the item
end
```

### lib.callback (client)

```lua
lib.callback(event: string, delay: number|false|nil, cb: function, ...)
```

Side: client

Parameters:
- `event` (string, required): Name registered on the server with `lib.callback.register`.
- `delay` (number|false|nil, required): Rate limit in ms. A number greater than 0 blocks further calls of the same event name until that many ms (`GetGameTimer`) have passed since the last accepted call; a suppressed call returns nothing immediately (no wait, `cb` never runs). Pass `false` or nil for no limit.
- `cb` (function, required): Called asynchronously with the server handler's return values. Must be a function or a callable table, otherwise an assertion error is raised. If nil, a warning is printed and the call behaves like `lib.callback.await` (it yields).
- `...` (any, optional): Arguments delivered to the server handler after `source`. Must be msgpack-serialisable.

Returns: nothing (asynchronous) when `cb` is given; the handler's return values when `cb` is nil (await fallback).

Asynchronous form of a server callback: sends the request and returns at once; `cb` is invoked later with the response. The `w_lib:callbackTimeout` convar only applies in await mode; in cb mode a missing server handler simply means `cb` is never called. Response values are the server handler's return values; nil means the handler errored.

```lua
lib.callback('w_creators:getCharacters', false, function(chars)
    print(#chars)
end)
```

### lib.callback (server)

```lua
lib.callback(event: string, playerId: number, cb: function, ...)
```

Side: server

Parameters:
- `event` (string, required): Name registered on the target client with `lib.callback.register`.
- `playerId` (number, required): Server id of the target player. Asserts `DoesPlayerExist` and raises `target playerId ... does not exist` otherwise.
- `cb` (function, required): Called asynchronously with the client handler's return values. Must be a function or callable table; nil prints a warning and falls back to awaiting.
- `...` (any, optional): Arguments delivered to the client handler.

Returns: nothing (asynchronous) when `cb` is given.

Asynchronous request to one client. The client's return values arrive in `cb`. Nothing is called if the client never answers.

```lua
lib.callback('w_inventory:getVehicleData', source, function(model, class)
    print(model, class)
end, netId)
```

### lib.setValidCallback and lib.isCallbackValid

```lua
lib.setValidCallback(callbackName: string, isValid: boolean)
lib.isCallbackValid(callbackName: string): boolean
```

Side: shared

Parameters:
- `callbackName` (string, required): Callback name to claim or test.
- `isValid` (boolean, required, `setValidCallback` only): `true` claims the name. `false` is meant to release it, but the release path indexes a string and raises an error; do not rely on it.

Returns:
- `setValidCallback`: nothing; prints a SCRIPT ERROR (with stack trace) if the name is owned by another resource.
- `isCallbackValid`: `true` only if the invoking resource is the recorded owner of that name; `false` both for unknown names and for names owned by another resource.

`setValidCallback` is the internal registry behind `lib.callback.register`. It is defined under `resource/` so it is auto-exported; a consumer resource reaches it as `lib.setValidCallback` (which resolves to `exports.w_lib:setValidCallback`). It marks a callback name as owned by the invoking resource so other resources cannot overwrite it; ownership is dropped automatically when that resource stops. It is marked "for internal use only" in the source and is normally never called directly. `isCallbackValid` (also `exports.w_lib:isCallbackValid`) checks whether the calling resource owns a `lib.callback` name.

```lua
-- setValidCallback is called for you by lib.callback.register; manual use:
exports.w_lib:setValidCallback('myres:ping', true)

if not lib.isCallbackValid('myres:ping') then
    lib.callback.register('myres:ping', function(source) return 'pong' end)
end
```

### w.callback.register (client)

```lua
w.callback.register(name: string, cb: fun(...): ...)
```

Side: client

Parameters:
- `name` (string, required): Unique name in the client-wide `w.callback` registry (one registry per client, shared by all resources). Refused with the error print `Callback already registered` if already taken. Cleared when the resource stops.
- `cb` (function, required): Handler; receives the arguments sent by the server (no source). Its return values are sent back as the reply.

Returns: nothing

Registers a client callback that the server can trigger with `w.callback.triggerClient(name, source, ...)`. Because `w.callback` in a consumer resource is the exported API table of the library, `cb` crosses into the library as a function reference; this is supported and is how sibling resources use it. Also reachable as `jo.callback.register`.

```lua
w.callback.register('myres:client:getCoords', function(precise)
    local c = GetEntityCoords(PlayerPedId())
    return precise and c or vector3(math.floor(c.x), math.floor(c.y), math.floor(c.z))
end)
```

### w.callback.register (server)

```lua
w.callback.register(name: string, cb: fun(source: number, ...): ...)
w.callback.register.latent(name: string, cb: fun(source: number, ...): ...)
```

Side: server

Parameters:
- `name` (string, required): Unique server-wide callback name. Names whose first `:`-separated segment is `w_lib` are never auto-removed; all others are removed when the registering resource stops. Re-registering an existing name prints `Callback already registered` and keeps the old handler.
- `cb` (function, required): Handler; the first argument is always the requesting player's server id, then the client's arguments. Return values are sent back.

Returns: nothing

Registers a server callback answering `w.callback.triggerServer` from clients. In a consumer resource `w.callback.register` is a callable table built by the scoped module file: calling it runs `registerCallback`; `w.callback.register.latent(name, cb)` runs `registerLatentCallback` (the reply is sent through the bandwidth-limited latent path, see the convar `w_lib:emit:bps`); `w.callback.register.Callback` / `.LatentCallback` map to the same functions. Register at startup, before clients can call.

```lua
w.callback.register('wraith_cinema:adminRequest', function(src, payload)
    local ok, response = pcall(handle, src, payload)
    if not ok then return { ok = false } end
    return response
end)
```

### w.callback.registerCallback and w.callback.registerLatentCallback

```lua
w.callback.registerCallback(name: string, cb: fun(source: number, ...): ..., latent?: boolean)
w.callback.registerLatentCallback(name: string, cb: fun(source: number, ...): ...)
```

Side: server

Parameters:
- `name` (string, required): Unique server-wide callback name.
- `cb` (function, required): Handler receiving `source` then the client's arguments.
- `latent` (boolean, optional, default `false`, `registerCallback` only): `true` sends the reply with the latent (rate-limited) client event.

Returns: nothing

`registerCallback` is the explicit form of `w.callback.register` on the server. It refuses (error print) if the name is already registered. `registerLatentCallback` is the same as `registerCallback` with `latent = true`: the reply is sent to the client through the library's own `w.emit.triggerClient.latent`, throttled to the bits per second of the convar `w_lib:emit:bps` (server default 100000). Use it for large replies (big tables, images) so they do not stall the connection. The consumer resource's own `w.emit.updateBps` does not change this rate; the convar does.

```lua
w.callback.registerCallback('w_baloot:server:getRound', function(source)
    return { round = 1, hand = {} }
end)

w.callback.registerLatentCallback('myres:server:getBigTable', function(source)
    return BigTable
end)
```

### w.callback.triggerServer (client)

```lua
w.callback.triggerServer(name: string, cb?: function, ...): ...
```

Side: client

Parameters:
- `name` (string, required): Server callback name registered with `w.callback.register` on the server.
- `cb` (function|any, optional): If a function: called asynchronously with the reply and `triggerServer` returns nothing. If any other non-nil value: treated as the first data argument and the call is synchronous. If nil: synchronous with the remaining arguments.
- `...` (any, optional): Data arguments delivered to the server handler after `source`. Must be msgpack-serialisable.

Returns: synchronous mode: the server handler's return values (multiple allowed); asynchronous mode: nothing.

Calls a server `w.callback` (net event `w_lib:triggerCallback`, reply on a per-request event). Synchronous mode yields the current thread until the reply. No timeout exists: if the server has no such callback it waits 5 s, prints an error and never replies, so the client thread hangs forever. Register server callbacks at startup.

```lua
-- synchronous
local result = w.callback.triggerServer('w_baloot:server:play', card)
-- asynchronous
w.callback.triggerServer('wraith_cinema:adminRequest', function(result)
    print(result.ok)
end, { action = 'snapshot' })
```

### w.callback.triggerClient (server)

```lua
w.callback.triggerClient(name: string, source: number, cb?: function, ...): ...
```

Side: server

Parameters:
- `name` (string, required): Client callback name registered on that client with `w.callback.register`.
- `source` (number, required): Target player's server id. nil prints `Source value is missing` and returns nothing; a player for whom `GetPlayerIdentifier(source, 1)` is nil (not connected) prints `Player is not connected` and returns nothing.
- `cb` (function|any, optional): Function: called asynchronously with the client's reply. Non-function: prepended to the data arguments and the call is synchronous.
- `...` (any, optional): Arguments delivered to the client handler.

Returns: synchronous mode: the client handler's return values; asynchronous mode: nothing.

Asks one client to run a `w.callback` and yields for (or calls `cb` with) the answer. No timeout: if the client has no such callback the client prints an error and the server thread waits forever, so make sure the client registers at load.

```lua
local coords = w.callback.triggerClient('myres:client:getCoords', source, nil, true)
print(coords)
```

### w.callback.triggerServer (server, local call)

```lua
w.callback.triggerServer(name: string, cb?: function, ...): ...
```

Side: server

Parameters:
- `name` (string, required): A server callback name registered in this server's `w.callback` registry (by any resource). If missing, waits 5 s, then returns `false` and prints an error.
- `cb` (function|any, optional): Function: invoked with the handler's return values. Non-function: prepended to the data arguments.
- `...` (any, optional): Arguments passed straight to the handler. No `source` is injected; if the handler expects `source` first, pass it as the first data argument.

Returns: the handler's return values when `cb` is not a function; nothing otherwise; `false` if the callback does not exist (after a 5 s wait).

Runs a server-registered `w.callback` locally on the server (a cross-resource function call through the library's registry, no network). Useful to reuse another resource's server callback. Remember the handler was written to receive `source` first.

```lua
local round = w.callback.triggerServer('w_baloot:server:getRound', nil, targetSource)
```

### w.callback.triggerClient (client, local call)

```lua
w.callback.triggerClient(name: string, cb?: function, ...): ...
```

Side: client

Parameters:
- `name` (string, required): A client callback registered with `w.callback.register` on this client (by any resource). Missing: returns `false` and prints an error.
- `cb` (function|any, optional): Function: receives the return values. Non-function: becomes the first data argument.
- `...` (any, optional): Arguments passed to the handler.

Returns: the handler's return values (or nothing when `cb` is a function); `false` if unknown.

Runs a client-registered `w.callback` locally on this client (no network). Lets one resource call a callback another client resource registered.

```lua
local coords = w.callback.triggerClient('myres:client:getCoords', nil, true)
```

### w.callback.trigger

```lua
w.callback.trigger(name: string, cb?: function, latent?: any)
```

Side: shared

Parameters:
- `name` (string, required): Callback name registered on the current side.
- `cb` (function|any, optional): As in the local modes of `triggerClient`/`triggerServer`.
- `latent` (any, optional): Despite the name this is simply forwarded as the next argument of the local trigger call (a single data argument). No further varargs are forwarded.

Returns: nothing (the underlying result is not returned).

Convenience that runs a callback registered on the same side as the caller: on the client it calls `w.callback.triggerClient(name, cb, latent)` (local execution); on the server it calls `w.callback.triggerServer(name, cb, latent)` (local execution). It discards return values, so it is only useful with a `cb` function. Prefer the explicit local functions.

```lua
w.callback.trigger('myres:client:getCoords', function(coords) print(coords) end)
```

### exports.w_lib:getCallbackAPI

```lua
exports.w_lib:getCallbackAPI(): table
```

Side: shared

Parameters: none

Returns: the `w.callback` table living in the library (client: `register`, `triggerServer`, `triggerClient`, `trigger`; server: `registerCallback`, `registerLatentCallback`, `triggerServer`, `triggerClient`, `trigger`, plus a `register` placeholder that the scoped module file replaces with the callable table).

This is how a consumer resource obtains `w.callback`; the w layer calls it automatically when `w.callback` is first touched, so it is only needed from a resource that does not load the library's init at all. Every function in the returned table is a function reference into the library; arguments must be msgpack-serialisable, and Lua functions passed as `cb` are accepted because they arrive as callable references.

```lua
local callback = exports.w_lib:getCallbackAPI()
callback.registerCallback('other:ping', function(source) return 'pong' end)
```

### w.emit.triggerServer and w.emit.triggerServer.latent

```lua
w.emit.triggerServer(eventName: string, ...)
w.emit.triggerServer.latent(eventName: string, ...)
```

Side: client

Parameters:
- `eventName` (string, required): Server net event name registered with `RegisterNetEvent` / `RegisterServerEvent`.
- `...` (any, optional): Arguments, msgpack-packed once. Large payloads are the use case for the latent form.

Returns: nothing

`w.emit.triggerServer` is the equivalent of `TriggerServerEvent` using the internal pre-packed native. It is a callable table: `w.emit.triggerServer(...)` sends normally, `w.emit.triggerServer.latent(...)` sends rate-limited through `TriggerLatentServerEvent`, with the bits per second taken from the convar `w_lib:emit:bps` (client default 20000, live-updated) or the last `w.emit.updateBps` call in this resource. Use the latent form for big payloads so they stream instead of blocking.

```lua
w.emit.triggerServer('myres:server:save', data)
w.emit.triggerServer.latent('myres:server:uploadPhoto', base64)
```

### w.emit.triggerClient and w.emit.triggerClient.latent (server)

```lua
w.emit.triggerClient(eventName: string, source: integer|table, ...)
w.emit.triggerClient.latent(eventName: string, source: integer|table, ...)
```

Side: server

Parameters:
- `eventName` (string, required): Client net event name (`RegisterNetEvent` on the client).
- `source` (integer|table, required): One server id (or -1 for all players), an array of ids, or a hash table whose keys are server ids (values ignored). An empty or mixed table is passed to the native as-is and fails.
- `...` (any, optional): Arguments, packed once for all targets.

Returns: nothing

`TriggerClientEvent` to one or many players with a single msgpack pass. Before each payload it sends `w_lib:client:emit:start` so that `w.emit.isEventInProgress` works on the client. The `.latent` variant uses `TriggerLatentClientEvent` at the bits per second from the convar `w_lib:emit:bps` (server default 100000) or this resource's last `w.emit.updateBps`. Use it for large tables so the transfer does not stall other traffic; the client can poll `w.emit.isEventInProgress` meanwhile.

```lua
w.emit.triggerClient('myres:client:refresh', { [12] = true, [15] = true }, payload)
w.emit.triggerClient.latent('myres:client:catalog', source, Catalog)
```

### w.emit.triggerServerWithSource

```lua
w.emit.triggerServerWithSource(source: integer, event: string, ...)
```

Side: server

Parameters:
- `source` (integer, required): Player whose client will re-trigger the event; the server handler then sees this id as `source`.
- `event` (string, required): Server net event name (must be `RegisterNetEvent`/`RegisterServerEvent` on the server).
- `...` (any, optional): Arguments forwarded unchanged.

Returns: nothing

Round-trips through the client (event `w_lib:emit:client:redirect`, handled inside the library's client) so that a server event handler written for clients receives the correct `source`. Replaces the deprecated `w.triggerEvent.server`. The client can drop or alter it; only use it for handlers that already treat client input as untrusted.

```lua
w.emit.triggerServerWithSource(source, 'vorp_inventory:useItem', 'bread')
```

### w.emit.isEventInProgress

```lua
w.emit.isEventInProgress(eventName: string): boolean|nil
```

Side: client

Parameters:
- `eventName` (string, required): Client event name the server is sending with `w.emit.triggerClient`.

Returns: `true` while a server `w.emit` send announced for this event has not yet arrived; nil otherwise.

The server's `w.emit.triggerClient` first sends `w_lib:client:emit:start`, then the payload; between the two this returns `true`. Lets a UI show a loading state for large latent transfers. Only tracks sends made with `w.emit` on the server, and only in resources that have loaded the emit module (the module registers the event name as a net event in the consumer resource when the start notice arrives).

```lua
if w.emit.isEventInProgress('myres:client:bigData') then
    print('still downloading')
end
```

### w.emit.updateBps

```lua
w.emit.updateBps(bps: integer)
```

Side: shared

Parameters:
- `bps` (integer, required): New bits per second for latent sends from this resource's copy of the module (`tonumber` is applied).

Returns: nothing

Changes the latent bandwidth used by the `w.emit` latent functions of the calling resource only. Latent `w.callback` replies are sent by the library's own copy of the module, so they are not affected. The convar `w_lib:emit:bps` applies to every copy and overrides this value whenever it changes.

```lua
w.emit.updateBps(50000)
```

### lib.triggerClientEvent

```lua
lib.triggerClientEvent(eventName: string, targetIds: number|number[], ...)
```

Side: server

Parameters:
- `eventName` (string, required): Client net event name.
- `targetIds` (number|number[], required): A single server id (or -1 for all) or an array of server ids (`lib.array.isArray` is used to detect the array).
- `...` (any, optional): Arguments, msgpack-packed once.

Returns: nothing

ox_lib style multi-target `TriggerClientEvent` that packs the arguments once. Loaded into the consumer resource on first use.

```lua
lib.triggerClientEvent('myres:client:notify', { 3, 7, 12 }, 'Round starts')
```

### w.emit.triggerClient (client, deprecated)

```lua
w.emit.triggerClient(eventName: string, source: integer|table, ...)
```

Side: client

Parameters:
- `eventName` (string, required): Client event to fire on the target players.
- `source` (integer|table, required): Target server id, array of ids, or -1 for everyone.
- `...` (any, optional): Arguments.

Returns: nothing

Deprecated since 2.12.2 and unsafe: asks the server (event `w_lib:server:emit:dispatch`) to relay an arbitrary event to arbitrary clients with no validation, so any client can abuse it. Do not use; send to the server and let a server-authoritative handler forward.

```lua
-- avoid; shown only for recognition
w.emit.triggerClient('myres:client:ping', -1)
```

### w.triggerEvent.server (deprecated)

```lua
w.triggerEvent.server(source: integer, event: string, ...)
```

Side: server

Parameters:
- `source` (integer, required): Player whose client re-triggers the server event.
- `event` (string, required): Server net event name.
- `...` (any, optional): Arguments.

Returns: nothing

Deprecated since 2.3.7; identical behaviour to `w.emit.triggerServerWithSource` but through the event `w_lib:trigger-event:client:receive`. The trigger-event module is in the default module list, so it is available without `w.require`. Server only (no client file exists). Use `w.emit.triggerServerWithSource`.

```lua
w.triggerEvent.server(source, 'myres:server:useItem', 'bread')
```

### w.hook.registerAction

```lua
w.hook.registerAction(name: string, fct: function, priority?: integer)
```

Side: shared

Parameters:
- `name` (string, required): Action name; any string agreed between the firing code and the hooks.
- `fct` (function, required): Called with the arguments passed to `doActions`. Errors are caught and logged; the return value is ignored.
- `priority` (integer, optional, default 10): Lower runs first; equal priorities run in registration order.

Returns: nothing

Adds a listener to an action hook in the calling resource's hook list (hook lists are per resource). To listen to another resource's actions use `exports.<thatResource>:registerAction`. Listeners registered from another resource are removed automatically when that resource stops.

```lua
w.hook.registerAction('myres:playerSat', function(source, tableId)
    print(('%s sat at %s'):format(source, tableId))
end, 5)
```

### w.hook.doActions

```lua
w.hook.doActions(name: string, ...)
```

Side: shared

Parameters:
- `name` (string, required): Action name to fire.
- `...` (any, optional): Arguments given to every listener.

Returns: nothing

Runs every function registered on this resource's action (via `w.hook.registerAction` locally or `exports.<thisResource>:registerAction` from other resources), in priority order, each in `pcall`. Prints a debug line when `w.debug` is on.

```lua
w.hook.doActions('myres:playerSat', source, tableId)
```

### w.hook.registerFilter

```lua
w.hook.registerFilter(name: string, fct: fun(value: any, ...): any, priority?: integer)
```

Side: shared

Parameters:
- `name` (string, required): Filter name.
- `fct` (function, required): Receives the current value plus the extra arguments and must return the new value (returning nothing sets the value to nil for the next filter). Errors are caught and the value is left unchanged.
- `priority` (integer, optional, default 10): Lower runs first.

Returns: nothing

Adds a value transformer to a filter hook in the calling resource's list. Other resources can add filters only through the exported `registerFilter`, which exists when this resource declares `w_module { 'hook' }` in its manifest. On the server, filters can be reached from the same resource's client through `w.hook.applyServerFilters` (the server callback then passes `source` after the value).

```lua
w.hook.registerFilter('myres:sellPrice', function(price, source, item)
    return price * 0.9
end)
```

### w.hook.applyFilters

```lua
w.hook.applyFilters(name: string, value: any, ...): any
```

Side: shared

Parameters:
- `name` (string, required): Filter name.
- `value` (any, required): Initial value; returned unchanged if no filter is registered.
- `...` (any, optional): Extra arguments passed to each filter after the value.

Returns: the value after every registered filter has transformed it.

Runs the filter chain of this resource in priority order and returns the final value.

```lua
local price = w.hook.applyFilters('myres:sellPrice', basePrice, source, item)
```

### w.hook.applyServerFilters

```lua
w.hook.applyServerFilters(name: string, value: any, ...): any
```

Side: client

Parameters:
- `name` (string, required): Filter name registered on the server side of the same resource.
- `value` (any, required): Initial value.
- `...` (any, optional): Extra arguments; server filters receive `(value, source, ...)`.

Returns: the filtered value (yields until the server answers).

Runs the server-side filter chain of the consumer resource from its client through a synchronous `w.callback` named `<yourResource>:hook:callFilter`. That callback exists only after the resource's server script has loaded `w.hook` (touch `w.hook` or call `w.require('hook')` on the server at startup, or declare `w_module { 'hook' }`); otherwise the client waits forever.

```lua
-- server.lua
w.require('hook')
w.hook.registerFilter('myres:maxWeight', function(v, source) return v + 10 end)
-- client.lua
local max = w.hook.applyServerFilters('myres:maxWeight', 50)
```

### exports.<resource>:registerAction

```lua
exports['<resource>']:registerAction(name: string, fct: function, priority?: integer)
```

Side: shared

Parameters:
- `name` (string, required): Action name fired by that resource with `w.hook.doActions`.
- `fct` (function, required): The listener; it crosses as a function reference and receives the `doActions` arguments (msgpack-serialised).
- `priority` (integer, optional, default 10).

Returns: nothing

Every resource that has loaded `w.hook` automatically exposes this export (the library included, as `exports.w_lib:registerAction`, which targets the library's own action list, for example `w_lib:applySkinAndClothes:before`, `w_lib:applyClothes:after`, `w_i18n_locale_change`). Use it to listen to another resource's actions; the entry is tagged with the registering resource's name and removed when it stops. The exports `registerFilter`, `RegisterAction` and `RegisterFilter` exist only on resources that declare `w_module { 'hook' }`.

```lua
exports.w_baloot:registerAction('w_baloot:gameEnded', function(tableId, winners)
    print(tableId, json.encode(winners))
end)
```

### exports.<resource>:registerFilter, RegisterAction, RegisterFilter

```lua
exports['<resource>']:registerFilter(name: string, fct: fun(value: any, ...): any, priority?: integer)
exports['<resource>']:RegisterAction(name: string, fct: function, priority?: integer)
exports['<resource>']:RegisterFilter(name: string, fct: fun(value: any, ...): any, priority?: integer)
```

Side: shared

Parameters:
- `name` (string, required): Filter (or action) name applied by that resource with `w.hook.applyFilters` (or `w.hook.doActions`).
- `fct` (function, required): The filter; it crosses as a function reference, receives `(value, ...)` and must return the new value.
- `priority` (integer, optional, default 10).

Returns: nothing

Exported only by resources whose fxmanifest declares `w_module { 'hook' }` (w_init creates the `registerAction`, `RegisterAction`, `registerFilter` and `RegisterFilter` exports, each waiting for the library to finish loading before running). A resource that merely touched `w.hook` at runtime exposes `registerAction` only. Ask the owning resource's author whether it declares the module.

```lua
exports.w_baloot:registerFilter('w_baloot:betLimit', function(limit, source)
    return math.min(limit, 500)
end)
```

### w.hook.RegisterAction and w.hook.RegisterFilter (deprecated)

```lua
w.hook.RegisterAction(name: string, fct: function, priority?: integer)
w.hook.RegisterFilter(name: string, fct: function, priority?: integer)
```

Side: shared

Parameters:
- `name` (string, required): Action or filter name.
- `fct` (function, required): Listener, or filter function returning the new value.
- `priority` (integer, optional, default 10).

Returns: nothing

Deprecated capitalised aliases of `w.hook.registerAction` and `w.hook.registerFilter`. They work but print a deprecation notice 3 s later. Use the lowercase forms.

```lua
w.hook.registerAction('myres:playerSat', handler) -- use the lowercase form
w.hook.registerFilter('myres:sellPrice', handler) -- use the lowercase form
```

### lib.hook

```lua
lib.hook:new(event: string, filter: fun(hook: table, payload: any): boolean): HookPipeline
```

Side: shared

Parameters:
- `event` (string, required): Event name; other resources address it as `'<yourResource>:<event>'`. Creates the exports `registerHook:<event>` and `removeHook:<event>` on the owning resource.
- `filter` (function, required): Called per registered hook as `filter(hook, payload)`; the hook table carries the options the registrant passed (plus `cb`, `resource`, `hookId`). Return `false` to skip that hook. If omitted, no hook ever runs and none receives the post-dispatch event, so pass `function() return true end` to run all.

Returns: `HookPipeline` instance with `:registerHook`, `:remove`, `:dispatch`.

ox_lib style hook pipeline for a resource that wants to let others veto or observe one of its operations. Hooks registered by other resources are removed when they stop. Create once at load. Available on both sides; the pipeline lives on the side where it was created.

```lua
local createItem = lib.hook:new('createItem', function(hook, payload)
    return not hook.itemFilter or hook.itemFilter[payload.name]
end)
```

### HookPipeline:dispatch

```lua
pipeline:dispatch(payload: any): { ok: boolean, size: number }
```

Side: shared

Parameters:
- `payload` (any, required): Data given to the filter and to each hook callback.

Returns: a to-be-closed result table: `ok = false` if any hook returned `false` (dispatch stops at the first rejection), `size` = number of hooks that passed the filter.

Runs the pipeline. Declare the result with `<close>`: when the variable goes out of scope (or an error unwinds), every hook that passed the filter gets a local event named by its `hookId` with `(ok, payload)`, which is what `EventHook:on` listens to; an error during the scope sets `ok = false`.

```lua
local result <close> = createItem:dispatch({ name = 'bread', count = 2 })
if not result.ok then return false end
-- perform the operation here; hooks are told ok=true when the scope closes
```

### HookPipeline:registerHook and HookPipeline:remove

```lua
pipeline:registerHook(cb?: fun(payload: any): boolean, options?: table): string
pipeline:remove(resource: string, hookId?: string)
```

Side: shared

Parameters:
- `cb` (function, optional, `registerHook`): Called with the payload during dispatch; returning `false` rejects the operation.
- `options` (table, optional, `registerHook`): Free-form metadata copied onto the hook record so the pipeline filter can read it (any field names; `cb`, `resource` and `hookId` are overwritten).
- `resource` (string, required, `remove`): Owning resource name.
- `hookId` (string, optional, `remove`): Specific hook; omitted removes all hooks of that resource.

Returns: `registerHook`: hookId string `'<resource>:<event>:<index>'`; `remove`: nothing.

`registerHook` is the local form of registration (the export `registerHook:<event>` calls it); other resources should use `lib.registerHook` instead. `remove` removes hooks; the export `removeHook:<event>` calls it with the invoking resource.

```lua
local id = createItem:registerHook(function(payload) return payload.count < 100 end, { itemFilter = { bread = true } })
createItem:remove('w_gunsmith')
```

### exports.<resource>:registerHook:<event> and removeHook:<event>

```lua
exports['<resource>']['registerHook:<event>'](nil, funcref?, options?): string
exports['<resource>']['removeHook:<event>'](nil, hookId?)
```

Side: shared

Parameters:
- `funcref` (function, optional): Hook callback; returning `false` rejects.
- `options` (table, optional): Metadata for the owner's filter.
- `hookId` (string, optional, `removeHook`): The id returned by `registerHook`; omitted removes all of the invoking resource's hooks.

Returns: `registerHook`: hookId string.

Exports created automatically by `lib.hook:new` on the owning resource. The leading nil stands in for the `self` argument that the colon syntax would pass. `lib.registerHook` wraps them; call them directly only from non-Lua resources.

```lua
local hookId = exports.w_inventory['registerHook:createItem'](nil, function(p) return true end, {})
```

### lib.registerHook

```lua
lib.registerHook(eventName: string, handler?: fun(payload: any): boolean | table, options?: table): EventHook
```

Side: shared

Parameters:
- `eventName` (string, required): `'resourceName:eventName'` (split on the first colon); errors with `Invalid event format` otherwise. The resource must have created `lib.hook:new(eventName)` on the same side.
- `handler` (function|table, optional): Function run in the owner's pipeline (return `false` to reject). If a table is given and `options` is nil, the table is taken as options and no handler is set.
- `options` (table, optional): Metadata the owner's filter can read (field names defined by the owner).

Returns: `EventHook` with `:on(handler)`, `:off()`, `:remove()`.

Registers into another resource's `lib.hook` pipeline through its exports. The handler crosses as a function reference and receives a msgpack copy of the payload. Remove with `:remove()` or let it be removed when the consumer resource stops.

```lua
local hook = lib.registerHook('w_inventory:createItem', function(payload)
    return payload.name ~= 'dynamite'
end, { itemFilter = { dynamite = true } })
hook:on(function(ok, payload) print('created?', ok, payload.name) end)
```

### EventHook:on, EventHook:off and EventHook:remove

```lua
hook:on(handler: fun(ok: boolean, payload: any))
hook:off()
hook:remove()
```

Side: shared

Parameters:
- `handler` (function, required, `on`): Receives `ok` (`false` if any hook rejected or the owner's scope errored) and the payload after the owner's dispatch result is closed.

Returns: nothing

`on` attaches a post-execution handler (`AddEventHandler` on the hookId local event); a previous handler is replaced. `off` detaches the post-execution handler; the hook itself stays registered. `remove` detaches the handler and removes the hook from the owner's pipeline through its `removeHook:<event>` export; the object must not be used afterwards.

```lua
hook:on(function(ok, payload) if ok then print('done') end end)
hook:off()
hook:remove()
```

### w.gameEvents.listen

```lua
w.gameEvents.listen(eventName: string, callback: fun(data: table))
```

Side: client

Parameters:
- `eventName` (string, required): One of the 119 `EVENT_*` names below, or `'all'` to receive every event of groups 0-3. An unknown name raises an error inside the library's register handler (printed; the callback never fires).
- `callback` (function, required): Receives one table: `event_name` (string), the named fields of that event, and `value_0..value_(size-1)` raw int32 reads of every slot. Field types are int, float or bool (bools arrive as 0/1 ints).

Returns: nothing

Subscribes to native RDR2 game events. Client only (also reachable as `w.gameEvents` via the alias `'game-events'`). The library loads its polling code the first time any resource touches `w.gameEvents` and starts polling the game event queues only after the first listener registers; it then fires the local client events `w_lib:gameEvents:<NAME>` (and `w_lib:gameEvents:all`), which this function binds with `AddEventHandler`.

Available names: EVENT_BUCKED_OFF, EVENT_CALCULATE_LOOT, EVENT_CALM_PED, EVENT_CARRIABLE_PROMPT_INFO_REQUEST, EVENT_CARRIABLE_UPDATE_CARRY_STATE, EVENT_CARRIABLE_VEHICLE_STOW_COMPLETE, EVENT_CARRIABLE_VEHICLE_STOW_START, EVENT_CHALLENGE_GOAL_COMPLETE, EVENT_CHALLENGE_GOAL_UPDATE, EVENT_CHALLENGE_REWARD, EVENT_CONTAINER_INTERACTION, EVENT_CRIME_CONFIRMED, EVENT_DAILY_CHALLENGE_STREAK_COMPLETED, EVENT_ENTITY_BROKEN, EVENT_ENTITY_DAMAGED, EVENT_ENTITY_DESTROYED, EVENT_ENTITY_DISARMED, EVENT_ENTITY_EXPLOSION, EVENT_ENTITY_HOGTIED, EVENT_HEADSHOT_BLOCKED_BY_HAT, EVENT_HELP_TEXT_REQUEST, EVENT_HITCH_ANIMAL, EVENT_HOGTIED_ENTITY_PICKED_UP, EVENT_HORSE_BROKEN, EVENT_IMPENDING_SAMPLE_PROMPT, EVENT_INVENTORY_ITEM_PICKED_UP, EVENT_INVENTORY_ITEM_REMOVED, EVENT_ITEM_PROMPT_INFO_REQUEST, EVENT_LOOT, EVENT_LOOT_COMPLETE, EVENT_LOOT_PLANT_START, EVENT_LOOT_VALIDATION_FAIL, EVENT_MISS_INTENDED_TARGET, EVENT_MOUNT_OVERSPURRED, EVENT_NETWORK_AWARD_CLAIMED, EVENT_NETWORK_BOUNTY_REQUEST_COMPLETE, EVENT_NETWORK_BULLET_IMPACTED_MULTIPLE_PEDS, EVENT_NETWORK_CASHINVENTORY_TRANSACTION, EVENT_NETWORK_CREW_CREATION, EVENT_NETWORK_CREW_DISBANDED, EVENT_NETWORK_CREW_INVITE_RECEIVED, EVENT_NETWORK_CREW_JOINED, EVENT_NETWORK_CREW_KICKED, EVENT_NETWORK_CREW_LEFT, EVENT_NETWORK_CREW_RANK_CHANGE, EVENT_NETWORK_DAMAGE_ENTITY, EVENT_NETWORK_GANG, EVENT_NETWORK_GANG_WAYPOINT_CHANGED, EVENT_NETWORK_HOGTIE_BEGIN, EVENT_NETWORK_HOGTIE_END, EVENT_NETWORK_HUB_UPDATE, EVENT_NETWORK_INCAPACITATED_ENTITY, EVENT_NETWORK_LASSO_ATTACH, EVENT_NETWORK_LASSO_DETACH, EVENT_NETWORK_LOOT_CLAIMED, EVENT_NETWORK_MINIGAME_REQUEST_COMPLETE, EVENT_NETWORK_PED_DISARMED, EVENT_NETWORK_PED_HAT_SHOT_OFF, EVENT_NETWORK_PERMISSION_CHECK_RESULT, EVENT_NETWORK_PICKUP_COLLECTION_FAILED, EVENT_NETWORK_PICKUP_RESPAWNED, EVENT_NETWORK_PLAYER_COLLECTED_PICKUP, EVENT_NETWORK_PLAYER_COLLECTED_PORTABLE_PICKUP, EVENT_NETWORK_PLAYER_DROPPED_PORTABLE_PICKUP, EVENT_NETWORK_PLAYER_JOIN_SCRIPT, EVENT_NETWORK_PLAYER_JOIN_SESSION, EVENT_NETWORK_PLAYER_LEFT_SCRIPT, EVENT_NETWORK_PLAYER_LEFT_SESSION, EVENT_NETWORK_PLAYER_MISSED_SHOT, EVENT_NETWORK_POSSE_CREATED, EVENT_NETWORK_POSSE_DATA_CHANGED, EVENT_NETWORK_POSSE_DISBANDED, EVENT_NETWORK_POSSE_EX_ADMIN_DISBANDED, EVENT_NETWORK_POSSE_EX_INACTIVE_DISBANDED, EVENT_NETWORK_POSSE_JOINED, EVENT_NETWORK_POSSE_LEADER_SET_ACTIVE, EVENT_NETWORK_POSSE_LEFT, EVENT_NETWORK_POSSE_MEMBER_DISBANDED, EVENT_NETWORK_POSSE_MEMBER_JOINED, EVENT_NETWORK_POSSE_MEMBER_KICKED, EVENT_NETWORK_POSSE_MEMBER_LEFT, EVENT_NETWORK_POSSE_MEMBER_SET_ACTIVE, EVENT_NETWORK_PROJECTILE_ATTACHED, EVENT_NETWORK_PROJECTILE_NO_DAMAGE_IMPACT, EVENT_NETWORK_REVIVED_ENTITY, EVENT_NETWORK_SESSION_EVENT, EVENT_NETWORK_SESSION_MERGE_END, EVENT_NETWORK_SESSION_MERGE_START, EVENT_NETWORK_VEHICLE_LOOTED, EVENT_NETWORK_VEHICLE_UNDRIVABLE, EVENT_OBJECT_INTERACTION, EVENT_PED_ANIMAL_INTERACTION, EVENT_PED_CREATED, EVENT_PED_DESTROYED, EVENT_PED_HAT_KNOCKED_OFF, EVENT_PED_WHISTLE, EVENT_PICKUP_CARRIABLE, EVENT_PLACE_CARRIABLE_ONTO_PARENT, EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP, EVENT_PLAYER_ESCALATED_PED, EVENT_PLAYER_HAT_EQUIPPED, EVENT_PLAYER_HAT_KNOCKED_OFF, EVENT_PLAYER_HORSE_AGITATED_BY_ANIMAL, EVENT_PLAYER_MOUNT_WILD_HORSE, EVENT_PLAYER_PROMPT_TRIGGERED, EVENT_RAN_OVER_PED, EVENT_REVIVE_ENTITY, EVENT_SCENARIO_ADD_PED, EVENT_SCENARIO_DESTROY_PROP, EVENT_SCENARIO_REMOVE_PED, EVENT_SHOCKING_ITEM_STOLEN, EVENT_SHOT_FIRED_BULLET_IMPACT, EVENT_SHOT_FIRED_WHIZZED_BY, EVENT_STAT_VALUE_CHANGED, EVENT_TRIGGERED_ANIMAL_WRITHE, EVENT_UI_ITEM_INSPECT_ACTIONED, EVENT_UI_QUICK_ITEM_USED, EVENT_VEHICLE_CREATED, EVENT_VEHICLE_DESTROYED.

Named fields from the data file:

| Event | Named fields |
|---|---|
| EVENT_ENTITY_DAMAGED | target_entity, initiator_entity, weapon, ammo, damage_amount (float), coord_x, coord_y, coord_z |
| EVENT_NETWORK_DAMAGE_ENTITY | target_entity, initiator_entity, damage_amount, is_victim_destroyed, is_victim_incapacitated, weapon, ammo, instigated_weapon, victim_speed, damager_speed, is_responsible_for_collision |
| EVENT_NETWORK_INCAPACITATED_ENTITY | target_entity, initiator_entity, weapon, damage_amount |
| EVENT_BUCKED_OFF | rider, mount |
| EVENT_PED_WHISTLE | initiator_entity, whistle_type |
| EVENT_INVENTORY_ITEM_PICKED_UP | inventory_item, entity_model, is_item_was_used, is_item_was_bought, target_entity |
| EVENT_INVENTORY_ITEM_REMOVED | target_entity, prompt_info, inventory_item |
| EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP | pickup_name, target_entity, initiator_entity, pickup_model, inventory_item_quantity, inventory_item |
| EVENT_NETWORK_PLAYER_COLLECTED_PICKUP | target_entity, initiator_entity, pickup_type, pickup_entity_model, pickup_ammo_amount, pickup_ammo_type |
| EVENT_HORSE_BROKEN | initiator_entity, target_entity, event_type |
| EVENT_CRIME_CONFIRMED | crime_type, criminal_entity, witness_entity |
| EVENT_NETWORK_POSSE_* | a posse id and network_gamer_handle |
| EVENT_NETWORK_CREW_* | joined_crew / kicked_crew |

Many slots are only exposed as `value_N`. Print the received table once to see the exact fields of the event you need.

```lua
w.gameEvents.listen('EVENT_ENTITY_DAMAGED', function(data)
    if data.target_entity == PlayerPedId() then
        print(('hit by weapon %s for %s'):format(data.weapon, data.damage_amount))
    end
end)
```

### w.waiter.exec

```lua
w.waiter.exec(condition: fun(): boolean, executable?: function, loopSpeed?: integer, maxDuration?: integer): boolean
```

Side: shared

Parameters:
- `condition` (function, required): Polled each iteration; the loop ends when it returns a truthy value.
- `executable` (function, optional): Run after each failed test (before the wait).
- `loopSpeed` (integer, optional, default 0): Wait between tests in ms (0 means every frame/tick).
- `maxDuration` (integer, optional, default 5000): Give up after this many ms. On the server, time comes from `os.time()` so the resolution is 1 second.

Returns: `true` if the condition became true, `false` on timeout.

Blocking poll loop; call from a thread that may yield.

```lua
local loaded = w.waiter.exec(function() return HasModelLoaded(model) end, nil, 10, 3000)
```

### w.promise.new

```lua
w.promise.new(cb: function, ...): ...
```

Side: shared

Parameters:
- `cb` (function, required): Callback-style function. It is called with the given arguments plus a resolver function appended at the end (or substituted where the string `'promiseReturnFunction'` was placed). It must eventually call the resolver.
- `...` (any, optional): Arguments for `cb`. Use the literal string `'promiseReturnFunction'` in the position where `cb` expects its completion callback if it is not the last parameter.

Returns: whatever values the resolver was called with.

Turns a callback-style API into a blocking call: yields until the resolver is invoked and returns its arguments. Never returns if the resolver is never called.

```lua
local result = w.promise.new(TriggerEvent, 'vorp_inventory:getItemCount', 'promiseReturnFunction', 'bread')
-- or with a callback-last API
local chars = w.promise.new(function(done) SomeApi.load(done) end)
```

### w.timeout.set

```lua
w.timeout.set(msec: integer|function, cb: function, ...): TimeoutClass
```

Side: shared

Parameters:
- `msec` (integer|function, required): Number: delay in ms (`SetTimeout`). Function: a waiter run in its own thread; `cb` runs after it returns unless cleared meanwhile.
- `cb` (function, required): Executed once with the extra arguments.
- `...` (any, optional): Arguments stored and passed to `cb`.

Returns: `TimeoutClass` instance (see the methods entry).

Cancelable one-shot timer, armed immediately. The returned object has `:clear()` (cancel), `:setCb(fn)`, `:setMsec(v)`, `:execute()` (run now if not canceled) and the fields `msec`, `cb`, `args`, `canceled`. Changing `msec` after creation has no effect on a timer created with `set` because it is already armed.

```lua
local t = w.timeout.set(5000, function(msg) print(msg) end, 'five seconds passed')
-- later
t:clear()
```

### w.timeout.loop

```lua
w.timeout.loop(msec: integer, cb: function, ...): TimeoutClass
```

Side: shared

Parameters:
- `msec` (integer, required): Interval in ms between runs; read from the object's `msec` field each iteration so `:setMsec` changes it live. Must be a number (a waiter function is not supported here).
- `cb` (function, required): Run immediately, then after every interval, until `:clear()`.
- `...` (any, optional): Arguments passed to `cb` every time.

Returns: `TimeoutClass` instance; call `:clear()` to stop the loop.

Repeating timer in its own thread. The first execution is immediate, and if `cb` yields the interval starts after it returns. Note that `:execute()` on a loop object also cancels it (`execute` calls `clear`).

```lua
local loop = w.timeout.loop(1000, function() print('tick') end)
SetTimeout(10000, function() loop:clear() end)
```

### w.timeout.delay

```lua
w.timeout.delay(id: string, msec: integer|function, cb: function, ...): TimeoutClass
```

Side: shared

Parameters:
- `id` (string, required): Debounce key, scoped to the calling resource's copy of the module.
- `msec` (integer|function, required): Delay in ms or a waiter function.
- `cb` (function, required): Runs after the delay if no newer delay with the same id was created.
- `...` (any, optional): Arguments for `cb`.

Returns: `TimeoutClass` instance.

Trailing-edge debounce: each call cancels the pending timer with the same id and starts a new one, so `cb` runs once, `msec` after the last call.

```lua
AddEventHandler('myres:inputChanged', function(text)
    w.timeout.delay('search', 300, function(q) doSearch(q) end, text)
end)
```

### w.timeout.noSpam

```lua
w.timeout.noSpam(id: string, msec: integer|function, cb: function, ...): TimeoutClass
```

Side: shared

Parameters:
- `id` (string, required): Debounce key.
- `msec` (integer|function, required): Quiet window in ms (or a waiter function).
- `cb` (function, required): The first call runs it immediately (synchronously, before `noSpam` returns); calls arriving inside the window are deferred: only the last one runs, `msec` after it was made.
- `...` (any, optional): Arguments for `cb`.

Returns: `TimeoutClass` instance.

Leading-edge debounce with trailing catch-up: the first call executes at once and opens a window of `msec`; further calls during the window (including while the first `cb` is still yielding) cancel each other and the last one runs `msec` after it was made, which also acts as a new window. After that deferred run finishes, the next call is treated as a first call again.

```lua
RegisterCommand('save', function()
    w.timeout.noSpam('save', 2000, function() TriggerServerEvent('myres:save') end)
end)
```

### TimeoutClass methods

```lua
t:clear()
t:setCb(cb: function)
t:setMsec(msec: integer|function)
t:execute(): boolean
```

Side: shared

Parameters:
- `cb` (function, optional, `setCb`): Replacement callback (takes effect if the timer has not fired yet).
- `msec` (integer|function, optional, `setMsec`): New interval. Only meaningful for loop objects (applies from the next iteration); a `set`/`delay`/`noSpam` timer is already armed with its original value.

Returns: `execute`: `true` if it ran, `false` if canceled; the others return nothing.

Methods of the object returned by `w.timeout.set/loop/delay/noSpam`. `clear()` marks it canceled so the pending callback (or loop) never runs. `execute()` first marks the object canceled (so the scheduled run is skipped and a loop stops) and then runs the callback immediately unless it was already canceled. The object also has a `start()` method, but it is used internally when the timer is created, and calling it again on a fired or canceled timer does nothing useful.

```lua
local t = w.timeout.set(3000, print, 'late')
t:setCb(function() print('changed') end)
t:execute() -- runs now; the scheduled run is skipped
```

### lib.timer

```lua
lib.timer(time: number, onEnd: fun(self: OxTimer), async?: boolean): OxTimer
```

Side: shared

Parameters:
- `time` (number, required): Duration in ms, must be greater than 0 (assertion error otherwise).
- `onEnd` (function, required): Called with the timer object when it reaches zero (unless `forceEnd(false)`). The constructor accepts nil, but the timer then throws `attempt to call a nil value (method onEnd)` when it expires, so always pass a function.
- `async` (boolean, optional, default `false`): `false` blocks the calling thread until the timer ends. `true` runs it in its own thread and returns immediately.

Returns: `OxTimer` object with `:pause()`, `:play()`, `:isPaused()`, `:forceEnd(triggerOnEnd)`, `:restart(async)`, `:getTimeLeft(format)`.

Pausable countdown based on `GetGameTimer`. Because the default is synchronous, use `async = true` to keep the returned object to pause or query it.

```lua
local t = lib.timer(60000, function() print('round over') end, true)
t:pause()
print(t:getTimeLeft('s'))
t:play()
```

### OxTimer methods

```lua
t:getTimeLeft(format?: 'ms'|'s'|'m'|'h'): number|{ms,s,m,h}
t:pause()
t:play()
t:isPaused(): boolean
t:forceEnd(triggerOnEnd: boolean)
t:restart(async?: boolean)
```

Side: shared

Parameters:
- `format` (string, optional, `getTimeLeft`): Unit; omitted returns a table with all four, each rounded to 2 decimals. Can go negative after expiry.
- `triggerOnEnd` (boolean, optional, `forceEnd`): Whether `onEnd` still fires. Nothing happens if the timer already ended.
- `async` (boolean, optional, `restart`): Run detached (`true`) or block (`false`/nil). `restart` resets to the initial duration without firing `onEnd`.

Returns: see the signature.

Control methods of the object returned by `lib.timer`. `pause()` freezes the remaining time; `play()` resumes; `forceEnd(true)` ends early and still calls `onEnd`; `forceEnd(false)` ends silently; `restart()` ends silently and starts again from the initial duration.

```lua
if t:isPaused() then t:play() end
t:forceEnd(true)
```

### lib.waitFor

```lua
lib.waitFor(cb: fun(): any, errMessage?: string, timeout?: number|false): any
```

Side: shared

Parameters:
- `cb` (function, required): Polled every frame/tick until it returns a non-nil value (`false` counts as a value).
- `errMessage` (string, optional, default `'failed to resolve callback'`): Message used when timing out.
- `timeout` (number|false, optional, default 1000): Milliseconds before raising an error (`'<message> (waited X ms)'`). The default is also used when a non-number truthy value is given. `false` waits forever.

Returns: the first non-nil value returned by `cb`; raises an error on timeout.

Yields the current thread until `cb` yields a value. Returns immediately without yielding if the first call already returns a value. Use `pcall` to get a boolean instead of an error.

```lua
local ped = lib.waitFor(function()
    local p = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(p) then return p end
end, 'entity never appeared', 5000)
```

### lib.cron.new

```lua
lib.cron.new(expression: string, job: fun(task: OxTask, date: table), options?: { debug?: boolean, maxDelay?: number }): OxTask
```

Side: server

Parameters:
- `expression` (string, required): Five space-separated fields: minute hour day month weekday (lower-cased before parsing). Each field accepts `*` (any), a number, a list `1,15,30`, a range `9-17`, or a step `*/5`. minute 0-59, hour 0-23, day 1-31 or `l` for the last day of the month, month 1-12 or names jan..dec (comma lists of names allowed), weekday 1-7 with 1 = Sunday, or names sun..sat and name ranges like mon-fri. Numeric weekday 0 passes validation but is treated like 7 (Saturday), so write 1 or `sun` for Sunday. Invalid values raise `invalid cron expression`.
- `job` (function, required): Run in its own thread at each scheduled minute; receives the task object and the current `os.date('*t')` table. Must be a function or an error is raised.
- `options` (table, optional): Optional settings; the table passed becomes the task object.
  - `debug` (boolean, optional, default nil): Print scheduling decisions through `lib.print.debug`.
  - `maxDelay` (number, optional, default 1): Seconds a run may be late (for example after a long server hitch) and still execute immediately; if later than this the task is stopped until the next midnight restart (0 disables the tolerance so any lateness stops it).
  - Any other field: copied onto the task object (the table itself becomes the task).

Returns: `OxTask` with `:stop()`, `:run()`, `:getNextTime()`, `:getAbsoluteNextTime()`, `:getTimeAsString(timestamp?)` and the fields `id`, `expression`, `isActive`, `lastRun`, `maxDelay`.

Server-only scheduler using the server's local clock (`os.date`). The import runs inside the consumer resource: the task list is per resource, and the import itself creates a `'0 0 * * *'` job in that resource that restarts every inactive task at midnight. A task becomes inactive when `:stop()` is called, when its scheduled time expired beyond `maxDelay`, or when its next occurrence is not today (for example a weekday or day of month that does not match); the midnight job brings it back, so `:stop()` is not permanent across midnight. Duplicate runs inside the same minute are suppressed via `lastRun`.

```lua
lib.cron.new('*/5 * * * *', function()
    saveInventories(true)
end)

local payday = lib.cron.new('0 18 * * mon-fri', function(task, date)
    print('payday at', task:getTimeAsString())
end, { debug = true, maxDelay = 30 })
```

### OxTask methods

```lua
task:stop(msg?: string)
task:run()
task:getNextTime(): number?
task:getAbsoluteNextTime(): number
task:getTimeAsString(timestamp?: number): string
```

Side: server

Parameters:
- `msg` (string, optional, `stop`): Reason printed when debug is on.
- `timestamp` (number, optional, `getTimeAsString`): Unix time to format; default the absolute next run.

Returns: `getNextTime`: unix time of the next run today, or nil if none today, inactive, or within 60 s of `lastRun`; `getAbsoluteNextTime`: unix time of the next run on any day; `getTimeAsString`: `'Weekday HH:MM, DD Month YYYY'`.

Control and inspection of a cron task. `stop()` sets `isActive = false` and the scheduling loop exits (until the midnight restart job of the consumer resource runs it again); `run()` restarts an inactive task and is a no-op on an active one.

```lua
local task = lib.cron.new('30 3 * * *', backup)
print('next backup:', task:getTimeAsString())
task:stop()
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:gameEvents:<EVENT_NAME>` | client (local) | `data` table: `event_name`, named fields, `value_i` slots | Fired by the library for each game event that at least one resource listens to; fires only after some resource called `w.gameEvents.listen` for that name. Bind with `AddEventHandler`. |
| `w_lib:gameEvents:all` | client (local) | same `data` table | Fires for every event of every group once any `'all'` listener exists. |
| `w_lib:gameEvents:register` | client (local) | event name | Internal way `w.gameEvents.listen` registers interest. |
| `__ox_cb_<resource>` | client and server (net) | callback reply | Reply event of the `lib.callback` system, listened to by the calling resource. |
| `__w_cb_<resource>` | client and server (net) | invalid-name notice | Sent by the library when a `lib.callback` name does not exist; the caller does not listen on it, so the call times out instead. |
| `w_lib:triggerCallback` | server (net) | callback request | Carries `w.callback.triggerServer` requests; the reply arrives on a per-request event. |
| `w_lib:client:emit:start` | client (net) | event name | Sent by the server's `w.emit.triggerClient` before each payload so `w.emit.isEventInProgress` works. |
| `w_lib:emit:client:redirect` | client (net) | server event name and arguments | Handled inside the library's client; makes the client re-trigger the server event for `w.emit.triggerServerWithSource`. |
| `w_lib:trigger-event:client:receive` | client (net) | server event name and arguments | Same purpose for the deprecated `w.triggerEvent.server`. |
| `w_lib:server:emit:dispatch` | server (net) | event name, targets, arguments | Relay used by the deprecated and unsafe client-side `w.emit.triggerClient`; do not use. |
| `<hookId>` (`'<resource>:<event>:<index>'`) | shared (local) | `(ok, payload)` | Fired when a `lib.hook` dispatch result is closed; what `EventHook:on` listens to. |
| Actions `w_lib:applySkinAndClothes:before`, `w_lib:applySkinAndClothes:after`, `w_lib:applySkin:before`, `w_lib:applyClothes:before`, `w_lib:applyClothes:after`, `w_i18n_locale_change` | shared (hook actions) | `doActions` arguments | Actions fired by the library; listen with `exports.w_lib:registerAction`. |

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:callbackTimeout` | shared | milliseconds, default 300000 | How long `lib.callback.await` (client and server) waits for a reply before raising `callback event ... timed out`. Read once with `GetConvarInt` when the `lib.callback` import first loads in each resource, so set it in server.cfg before resources start and use `setr` so the client copy sees the same value. Does not apply to `w.callback`, which has no timeout. |
| `w_lib:emit:bps` | shared | bits per second; defaults 20000 (client) and 100000 (server) | Bandwidth for all latent sends made through `w.emit` (and latent `w.callback` replies). Read at module load in every resource and updated live through `AddConvarChangeListener`; use `setr` so the client sees it too. |
| `<resource>:debug` | shared | `on` / `off` | Sets `w.debug` in that resource; hooks then print "Action fired" / "Filter fired" lines and module tracing via `dprint` is unlocked. Live-updated; use `setr` for client visibility. Not for production. |
| `<resource>:debug:<module>` | shared | `on` / `off` | Sets `w.debugModules[module]` in the resource that loaded that module; the listener is created when the module loads. The resource in the name is the one whose code prints: `w.callback` response tracing runs inside the library, so use `w_lib:debug:callback`. |
| `all:debug:<module>` | shared | `on` / `off` | Same as above for every resource that loaded the module, for example `all:debug:callback`. |

Example server.cfg lines:

```lua
-- server.cfg
setr w_lib:callbackTimeout 15000
setr w_lib:emit:bps 200000
setr w_baloot:debug on
setr all:debug:callback on
```

### Commands

No console or chat commands belong to this subsystem.

## Framework bridge exports (Fw*), permissions and ACL

The library contains two independent framework detectors, and it matters which one a given export uses.

The first is the framework bridge. On both client and server it polls `GetResourceState` every 500 ms (every 2 s after 60 attempts) for exactly three cores, in this order: `vorp_core` (via `exports.vorp_core:GetCore()`), `rsg-core` (via `exports['rsg-core']:GetCoreObject()`) and `qbr-core` (a small QB-shaped wrapper built from `exports['qbr-core']:GetPlayer/GetPlayerData/GetItems/GetJobs/GetWeapons`; its `Shared.Items/Jobs/Weapons` are snapshotted once at detection time). Internally RSG and QBR share one code path, so everything documented as "RSG" below also applies to QBR; the public name returned by `FwName()` is `'vorp'`, `'rsgcore'` or `'qbr'`. Nothing else (RedEM, QR, RPX, TPZ, FRP) is supported by the Fw* exports: they return nil, false, 0 or `""` on an unknown framework.

All Fw* functions are plain exports (`exports.w_lib:FwGetMoney(src)`); there is no `lib.Fw*` alias. Detection is asynchronous, so a consumer resource must poll `exports.w_lib:FwReady()` before trusting any other Fw* call (w_admin polls every 200 ms for up to 30 s). Because everything crosses the Cfx export boundary, only data survives: `FwGetUser`, `FwGetCharacter` and `FwGetCore` hand back framework objects whose methods are not callable from the consumer resource. Use the Fw setters and `FwGetSharedItems/Weapons/Jobs` instead of calling methods on those objects, and never pass a Lua function as an argument to any library export; where a callback is needed, the library expects an event name string.

Currency types are integers everywhere: `0` = cash (VORP money / RSG `money.cash`), `1` = gold (VORP gold / RSG `money.gold` when that balance exists, else `money.bloodmoney`), `2` = VORP rol / RSG `money.blkbank`. The offline currency exports differ slightly: on RSG they always write the `bloodmoney` key for type 1, with no gold check.

The online Fw inventory functions (`FwGetInventoryItems`, `FwAddItem`, `FwAddWeapon` and so on) do not talk to the framework's inventory directly. They route through the library's inventory bridge (`exports.w_lib:InvName/InvGetItems/InvAddItem/InvRemoveItem/InvGetSlot/InvCanCarry`), which picks the active bag as follows: if `w_inventory` is started it always wins; otherwise the server convar `w_lib:inventory` (default `'auto'`) forces one of `w_inventory`, `vorp_inventory`, `rsg-inventory`, `qbr-inventory` (aliases `w`, `ox` -> `w_inventory`, `vorp`, `rsg`, `qbr`; case and whitespace insensitive); `'auto'` takes the first started of `w_inventory`, `rsg-inventory`, `qbr-inventory`, `vorp_inventory`. The chosen name is replicated to clients as the read-only convar `w_lib:activeInventory`. An invalid forced value prints an error and disables the bridge, after which every Inv*/Fw inventory call returns false or empty. One special case: when the active bag is `w_inventory` and `exports.w_inventory:GetNativeStorage()` reports a framework, the online Fw inventory functions delegate to `vorp_inventory` when that value is `'vorp'`, and the offline ones delegate to w_inventory's `GetNativeOfflineInventory` / `MutateNativeOfflineInventory` for any non-nil value. Weapons are recognised by the name prefix `WEAPON_` (case-insensitive).

The "Offline" exports write straight to MySQL (the library loads `@oxmysql/lib/MySQL.lua`) and never touch an online player object. Do not call them for a connected player, or the framework will overwrite the change on save. Their key arguments differ per framework and per function, so read each entry. Under VORP some take the account identifier (`characters.identifier`, e.g. `steam:xxx`, which affects every character on that account: `FwAddCurrencyOffline`, `FwRemoveCurrencyOffline`, `FwSetJobFullOffline`, `FwSetJobLabelOffline`, `FwSetJobGradeOffline`, `FwGetDiscordId`) and others take `charId` (`characters.charidentifier`: `FwGetJobOffline`, `FwSetPlayerJobOffline`, `FwRemoveJobOffline`, the `FwSet*Offline` character-field setters, the offline inventory functions). Under RSG/QBR the identifier argument is always the citizenid and `charId` is ignored or is also the citizenid. Several return `(false, reasonString)` on failure; the RSG job-offline setters return true even when no row matched.

The permission helpers use the second detector, the `w.framework` module, whose ids are `vorp`, `redemrp_old`, `redemrp_2023`, `qbr`, `rsg` (RSG V1), `rsg_v2` (RSG V2), `qr`, `rpx`, `tpz`, `frp`. `GetPlayerGroup(source)` returns the TPZ group (the only framework whose user object has `getGroup`), the VORP account group (`users.group` via vorp_core when it is not `''` or `'user'`, else the character group), or the RedEM group, and nil on RSG, RSG v2, QBR, QR, RPX, FRP or when the player has no framework user. `HasPermission(source, group)` asks the core's own HasPermission on rsg/rsg_v2/qr (`Core.Functions.HasPermission`) and qbr (`exports['qbr-core']:HasPermission`); on every other framework it compares `GetPlayerGroup` with the requested group and treats the four admin groups `admin`, `superadmin`, `owner`, `god` as interchangeable (a superadmin passes `HasPermission(src, 'admin')`). `IsAdmin(source)` is `HasPermission(source, 'admin')` OR `IsPlayerAceAllowed(source, 'command')`.

`HasPermissionNode(source, node)` is the recommended check for a resource's own features. It normalises the node (lowercased, trimmed, 1-96 characters, dot-delimited segments each matching `^[a-z][a-z0-9_-]*$`), returns true for console (source 0), true for `IsAdmin`, then checks the exact ACE, then wildcard ACEs from the most specific prefix to the least (`a.b.c` -> `a.b.*` -> `a.*`) and finally `*`. Grant nodes in `server.cfg` with standard ACE lines, for example `add_ace group.staff w_baloot.admin allow`, `add_ace group.staff w_legal.* allow`, `add_principal identifier.steam:110000112345678 group.staff`. The `lib.addAce/removeAce/addPrincipal/removePrincipal` helpers are thin `ExecuteCommand` wrappers around those same commands (a numeric principal becomes `player.<id>`) and are exported, so they are reachable as `lib.addAce` from a resource that loads `@w_lib/init.lua` or as `exports.w_lib:addAce`.

Two internal mechanisms consumers must know about. First, `FwKill` under VORP only fires the client event `w_:client:killPlayer` on the target; the library registers no handler for it, so the consumer resource (w_admin does this) must `RegisterNetEvent('w_:client:killPlayer')` on the client and set the ped's health to 0, or `FwKill` does nothing visible. Under RSG it triggers `rsg-medic:client:KillPlayer`, and `FwRevive/FwHeal/FwRespawn` trigger `rsg-medic:client:adminRevive/adminHeal`, so rsg-medic must be present. Second, the server registers the lib.callback `w_lib:checkPlayerAce` (returns `IsPlayerAceAllowed(source, ace)`); the library's own client-side `RegisterCommand` wrapper uses it with `command.<name>` when a command is registered as restricted, and a consumer client may call `lib.callback.await('w_lib:checkPlayerAce', 100, 'some.ace')` to test an ACE without writing a server callback.

Common mistakes: calling Fw* before `FwReady()` is true; comparing `FwName()` to `'rsgcore'` when QBR returns `'qbr'`; passing the VORP account identifier where a function wants `charId` (or vice versa); expecting `FwGetPlayerData` to work on VORP (it always returns nil there); expecting `FwGetOfflineInventory` to return one table (it returns two: items, weapons); and putting `weaponName` before `count` in `FwCanCarryWeapon`.

### exports.w_lib:FwReady

```lua
exports.w_lib:FwReady()
```

Side: shared

Parameters: none

Returns: `boolean` - true once `vorp_core`, `rsg-core` or `qbr-core` has been detected on this side.

Detection runs in a background thread on client and server independently (500 ms polls, 2 s after 60 attempts; a warning is printed once at attempt 60). Poll this before using any other Fw* export; w_admin polls every 200 ms for up to 30 s.

```lua
CreateThread(function()
    while not exports.w_lib:FwReady() do Wait(200) end
    print(('framework: %s'):format(exports.w_lib:FwName()))
end)
```

### exports.w_lib:FwName

```lua
exports.w_lib:FwName()
```

Side: shared

Parameters: none

Returns: `string|nil` - `'vorp'`, `'rsgcore'` or `'qbr'`; nil until a framework is detected.

Public name of the detected framework. QBR reports `'qbr'` even though every Fw* export treats it exactly like RSG internally, so a check such as `name ~= 'rsgcore'` will be true for QBR. Returns nil until `FwReady()` is true.

```lua
if exports.w_lib:FwName() == 'vorp' then
    print('running on VORP')
end
```

### exports.w_lib:FwInventory

```lua
exports.w_lib:FwInventory()
```

Side: shared

Parameters: none

Returns: `string|nil` - active inventory resource name (`'w_inventory'`, `'vorp_inventory'`, `'rsg-inventory'` or `'qbr-inventory'`); nil when the inventory bridge has no bag and no framework has been detected yet.

Returns `exports.w_lib:InvName()` (the inventory bridge's active bag, which honours the `w_lib:inventory` convar and prefers `w_inventory` when started). Falls back to the framework's default inventory name (`vorp_inventory` / `rsg-inventory` / `qbr-inventory`) only if `InvName` fails or returns nil.

```lua
local bag = exports.w_lib:FwInventory()
if bag == 'w_inventory' then print('Wraith inventory active') end
```

### exports.w_lib:FwGetCore

```lua
exports.w_lib:FwGetCore()
```

Side: shared

Parameters: none

Returns: `table|nil` - raw core object (VORP `GetCore()` table, RSG `GetCoreObject()` table, or the QBR wrapper `{Functions={GetPlayer,GetPlayerData}, Shared={Items,Jobs,Weapons}}`).

Hands back the framework core as a data handle. Functions inside it do not survive the export boundary, so do not call core methods on the result; only plain data such as RSG/QBR `Core.Shared.*` is usable, and `FwGetSharedItems/Weapons/Jobs` are the safer way to read that. Returns nil until detected.

```lua
local core = exports.w_lib:FwGetCore()
local jobs = core and core.Shared and core.Shared.Jobs or {}
```

### exports.w_lib:FwGetPlayerData

```lua
exports.w_lib:FwGetPlayerData()
```

Side: client

Parameters: none

Returns: `table|nil` - RSG/QBR PlayerData table (`citizenid`, `charinfo`, `money`, `job`, `metadata`, ...) or nil.

Client only. Always nil on VORP because VORP keeps no local player data table. On RSG/QBR returns `Core.Functions.GetPlayerData()` (pcall-guarded, nil on error). Also nil before detection. Consumers (w_hud, w_pausemenu, w_inventory) wrap it in pcall and fall back to their own state when nil.

```lua
local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
local cash = ok and pd and pd.money and pd.money.cash or 0
```

### exports.w_lib:FwGetUser

```lua
exports.w_lib:FwGetUser(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `table|nil` - VORP user object (`Core.getUser`) or RSG/QBR player object (`Core.Functions.GetPlayer`); nil when the player has no framework session or the framework is unknown.

Returns the framework's live player object. Its methods are not callable across the export boundary, so sibling resources use it purely as an "is this player loaded" test. Use the other Fw* exports for real operations.

```lua
if not exports.w_lib:FwGetUser(src) then return end -- player not loaded into a character yet
```

### exports.w_lib:FwGetCharacter

```lua
exports.w_lib:FwGetCharacter(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `table|nil` - VORP `getUsedCharacter` table (`firstname`, `lastname`, `charIdentifier`, `identifier`, `job`, `jobLabel`, `jobGrade`, `money`, `gold`, `xp`, `hours`, `age`, `nickname`, `charDescription`, ...) or RSG/QBR PlayerData (`citizenid`, `license`, `charinfo{firstname,lastname,age,nickname,description}`, `job{name,label,grade{level}}`, `money{cash,gold,bloodmoney,blkbank}`, `metadata{playtime,xp}`); nil if no user.

Raw character record. Data fields are readable; any setter functions on the VORP object are not usable through the export. Prefer `FwGetCharacterData` for a framework-neutral shape.

```lua
local char = exports.w_lib:FwGetCharacter(src)
if char then print(json.encode(char)) end
```

### exports.w_lib:FwGetCharacterData

```lua
exports.w_lib:FwGetCharacterData(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `table|nil` - `{ firstname: string, lastname: string, job: string ('unemployed' default), jobLabel: string ('Unemployed' default), jobGrade: integer, money: number, gold: number, xp: number, charIdentifier: integer|string, identifier: string }`; nil when not loaded.

Framework-neutral snapshot of the character. On VORP `jobLabel` defaults to `'Unemployed'` (it does not fall back to the job name like `FwGetJobLabel`). The RSG branch fills `gold` from `money.bloodmoney` only (unlike `FwGetGold`, which prefers `money.gold`), `xp` from `metadata.xp`, and `identifier` from `license` (falling back to citizenid).

```lua
local data = exports.w_lib:FwGetCharacterData(src)
if data then print(data.firstname, data.job, data.money) end
```

### exports.w_lib:FwGetCharacterIdentifier

```lua
exports.w_lib:FwGetCharacterIdentifier(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `integer|string|nil` - VORP `charIdentifier` (number) or RSG/QBR citizenid (string); nil when not loaded.

Per-character key. This is the value to store against character-owned data (w_hud, w_stables and w_inventory all key on it) and the `charId` to pass to the offline inventory, job and character-field exports on VORP.

```lua
local ok, cid = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(src) end)
if not ok or not cid then return end
```

### exports.w_lib:FwGetIdentifier

```lua
exports.w_lib:FwGetIdentifier(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `string|nil` - VORP account identifier (`characters.identifier`, e.g. `steam:...`) or RSG/QBR license (falls back to citizenid); nil when not loaded.

Account-level key shared by all characters of one player. On VORP this is the identifier expected by `FwAddCurrencyOffline`, `FwSetJobFullOffline`, `FwGetDiscordId` and friends; on RSG the offline exports want the citizenid instead (`FwGetCharacterIdentifier`).

```lua
local account = exports.w_lib:FwGetIdentifier(src)
```

### Character name getters

All are server side, take `source` (integer, required, player server id) and return a string.

```lua
exports.w_lib:FwGetCharacterName(source: integer)
exports.w_lib:FwGetFirstName(source: integer)
exports.w_lib:FwGetLastName(source: integer)
exports.w_lib:FwGetNickname(source: integer)
exports.w_lib:FwGetDescription(source: integer)
```

| Export | Returns | Source of the value |
| --- | --- | --- |
| `FwGetCharacterName` | `'firstname lastname'` (single space between; either half may be empty), or `GetPlayerName(source)` when no character is loaded or the framework is unknown | VORP firstname/lastname; RSG/QBR `charinfo` |
| `FwGetFirstName` | first name, `''` when unknown | VORP `char.firstname`; RSG/QBR `charinfo.firstname` |
| `FwGetLastName` | last name, `''` when unknown | VORP `char.lastname`; RSG/QBR `charinfo.lastname` |
| `FwGetNickname` | nickname, `''` when unset | VORP `char.nickname`; RSG/QBR `charinfo.nickname` |
| `FwGetDescription` | description text, `''` when unknown | VORP `charDescription`; RSG/QBR `charinfo.description` |

`FwGetCharacterName` falls back to the account/player name rather than nil when the character is not loaded, so do not use an empty result as a "not loaded" test.

```lua
local name = exports.w_lib:FwGetCharacterName(src)
local first, last = exports.w_lib:FwGetFirstName(src), exports.w_lib:FwGetLastName(src)
local nick = exports.w_lib:FwGetNickname(src)
```

### exports.w_lib:FwGetAge

```lua
exports.w_lib:FwGetAge(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `number|string|nil` - VORP `char.age` or RSG/QBR `charinfo.age`; nil when not loaded or unset.

Character age exactly as the framework stores it, with no coercion.

```lua
local age = exports.w_lib:FwGetAge(src) or 0
```

### Job getters

Server side; each takes `source` (integer, required, player server id).

```lua
exports.w_lib:FwGetJob(source: integer)
exports.w_lib:FwGetJobLabel(source: integer)
exports.w_lib:FwGetJobGrade(source: integer)
```

| Export | Returns | Source of the value |
| --- | --- | --- |
| `FwGetJob` | `string` job name, `'unemployed'` when none or not loaded | VORP `char.job`; RSG/QBR `job.name` |
| `FwGetJobLabel` | `string` job label; VORP falls back to the job name, then `'Unemployed'`; RSG/QBR falls back to `'Unemployed'` | VORP `char.jobLabel` or `char.job`; RSG/QBR `job.label` |
| `FwGetJobGrade` | `integer` job grade, 0 when none or not loaded | VORP `char.jobGrade`; RSG/QBR `job.grade.level` |

```lua
if exports.w_lib:FwGetJob(src) == 'police' then
    print(exports.w_lib:FwGetJobLabel(src), exports.w_lib:FwGetJobGrade(src))
end
```

### exports.w_lib:FwGetMoney

```lua
exports.w_lib:FwGetMoney(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `number` - cash balance (VORP `char.money`, RSG/QBR `money.cash`), 0 when not loaded.

Cash only (currency type 0). Read before `FwRemoveCurrency` to avoid negative balances, since `FwRemoveCurrency` on VORP does not check funds.

```lua
local held = exports.w_lib:FwGetMoney(src)
if held < price then return false end
```

### exports.w_lib:FwGetGold

```lua
exports.w_lib:FwGetGold(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `number` - gold balance (VORP `char.gold`; RSG/QBR `money.gold`, else `money.bloodmoney`), 0 when not loaded.

Currency type 1. On RSG the gold slot is `money.gold` when the server defines it and `bloodmoney` otherwise; `FwAddCurrency` and `FwRemoveCurrency` with type 1 resolve the same slot.

```lua
local gold = exports.w_lib:FwGetGold(src)
```

### exports.w_lib:FwGetPlaytime

```lua
exports.w_lib:FwGetPlaytime(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `number` - VORP `char.hours` or RSG/QBR `metadata.playtime`, 0 when unknown.

Units follow the framework: VORP stores hours, RSG stores whatever its playtime metadata holds.

```lua
local hours = exports.w_lib:FwGetPlaytime(src)
```

### exports.w_lib:FwAddCurrency

```lua
exports.w_lib:FwAddCurrency(source: integer, currencyType: integer, amount: number)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `currencyType` (integer, required) - `0` = cash, `1` = gold (RSG: `money.gold` when present, else `bloodmoney`), `2` = VORP rol / RSG `blkbank`.
- `amount` (number, required) - amount to add.

Returns: `boolean` - true on success; false when the player is not loaded, the framework is unknown, or (RSG/QBR) the balance slot for that type does not exist or `AddMoney` returned false.

VORP: `char.addCurrency(currencyType, amount)`. RSG/QBR: `player.Functions.AddMoney(slot, amount)`.

```lua
exports.w_lib:FwAddCurrency(src, 0, 25.0) -- give $25 cash
```

### exports.w_lib:FwRemoveCurrency

```lua
exports.w_lib:FwRemoveCurrency(source: integer, currencyType: integer, amount: number)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `currencyType` (integer, required) - `0` = cash, `1` = gold/bloodmoney, `2` = rol/blkbank.
- `amount` (number, required) - amount to remove.

Returns: `boolean` - true on success; VORP returns true without checking funds, RSG/QBR returns `RemoveMoney(...) ~= false` (false when the slot does not exist).

VORP does not verify the balance, so check `FwGetMoney`/`FwGetGold` first (w_crafting and w_stables do). RSG/QBR relies on the core's `RemoveMoney` result.

```lua
if exports.w_lib:FwGetMoney(src) >= fee and exports.w_lib:FwRemoveCurrency(src, 0, fee) == true then
    print('paid')
end
```

### exports.w_lib:FwSetJob

```lua
exports.w_lib:FwSetJob(source: integer, jobName: string, grade?: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `jobName` (string, required) - job name (RSG/QBR: a key of `Core.Shared.Jobs`; unknown names are still attempted inside pcall and the pcall result is returned).
- `grade` (integer, optional, default 0) - job grade (RSG/QBR coerces with `tonumber`).

Returns: `boolean` - true when applied, false when the player is not loaded or the framework is unknown.

VORP: calls `char.setJob(jobName, false)` and `char.setJobGrade(grade or 0, false)` (the `false` suppresses VORP's own notification). RSG/QBR: `player.Functions.SetJob(jobName, tonumber(grade) or 0)`. Online player only.

```lua
exports.w_lib:FwSetJob(src, 'police', 2)
```

### exports.w_lib:FwSetJobLabel

```lua
exports.w_lib:FwSetJobLabel(source: integer, label: string)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `label` (string, required) - VORP: the new `jobLabel` text. RSG/QBR: matched against `Core.Shared.Jobs` labels or names; the matching job is applied at the current grade, otherwise `SetJob(label, currentGrade)` is attempted inside pcall.

Returns: `boolean` - true when applied, false otherwise.

VORP sets only the display label (`char.setJobLabel`). RSG/QBR has no free-form label, so the label is resolved to a job and the player's job is changed while keeping the current grade.

```lua
exports.w_lib:FwSetJobLabel(src, 'Sheriff')
```

### exports.w_lib:FwSetJobGrade

```lua
exports.w_lib:FwSetJobGrade(source: integer, grade: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `grade` (integer, required) - new grade. VORP passes it through unchanged; RSG/QBR coerces with `tonumber`, default 0.

Returns: `boolean` - true when applied, false when not loaded, no job, or unknown framework.

VORP: `char.setJobGrade(grade, false)`. RSG/QBR: `SetJob(currentJobName, grade)`.

```lua
exports.w_lib:FwSetJobGrade(src, 3)
```

### Character field setters (online)

Server side; each takes `source` (integer, required, player server id) and the new value, and returns `boolean` - true when applied, false when not loaded or the framework is unknown.

```lua
exports.w_lib:FwSetFirstName(source: integer, firstName: string)
exports.w_lib:FwSetLastName(source: integer, lastName: string)
exports.w_lib:FwSetNickname(source: integer, nickname: string)
exports.w_lib:FwSetAge(source: integer, age: number)
exports.w_lib:FwSetDescription(source: integer, description: string)
```

| Export | Value parameter | VORP | RSG/QBR |
| --- | --- | --- | --- |
| `FwSetFirstName` | `firstName` (string, required) | `char.setFirstname` | `charinfo.firstname` in memory plus immediate `UPDATE players SET charinfo = JSON_SET(...)` |
| `FwSetLastName` | `lastName` (string, required) | `char.setLastname` | `charinfo.lastname` in memory plus DB `JSON_SET` |
| `FwSetNickname` | `nickname` (string, required) | `char.setNickName` | `charinfo.nickname` in memory plus DB `JSON_SET` |
| `FwSetAge` | `age` (number, required) | `char.setAge` | `charinfo.age` in memory plus DB `JSON_SET` |
| `FwSetDescription` | `description` (string, required) | `char.setCharDescription` | `charinfo.description` in memory plus DB `JSON_SET` |

```lua
exports.w_lib:FwSetFirstName(src, 'Arthur')
exports.w_lib:FwSetLastName(src, 'Morgan')
exports.w_lib:FwSetNickname(src, 'Dutch')
exports.w_lib:FwSetAge(src, 36)
exports.w_lib:FwSetDescription(src, 'A quiet rancher.')
```

### exports.w_lib:FwRevive, FwHeal, FwRespawn

```lua
exports.w_lib:FwRevive(source: integer)
exports.w_lib:FwHeal(source: integer)
exports.w_lib:FwRespawn(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `boolean` - true on VORP/RSG/QBR, false on an unknown framework.

| Export | VORP | RSG/QBR |
| --- | --- | --- |
| `FwRevive` | `Core.Player.Revive(source, true)` | `TriggerClientEvent('rsg-medic:client:adminRevive', source)` |
| `FwHeal` | `Core.Player.Heal(source)` | `TriggerClientEvent('rsg-medic:client:adminHeal', source)` |
| `FwRespawn` | `Core.Player.Respawn(source, true)` | same `rsg-medic:client:adminRevive` event as `FwRevive` |

On RSG/QBR rsg-medic must be installed.

```lua
exports.w_lib:FwRevive(target)
exports.w_lib:FwHeal(target)
exports.w_lib:FwRespawn(target)
```

### exports.w_lib:FwKill

```lua
exports.w_lib:FwKill(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `boolean` - true on VORP/RSG/QBR, false otherwise.

VORP: fires the client event `w_:client:killPlayer` on the target; the library registers no client handler, so the consumer resource must register one (see the Events table). Without a handler `FwKill` returns true but nothing happens. RSG/QBR: `TriggerClientEvent('rsg-medic:client:KillPlayer', source)`.

```lua
-- server
exports.w_lib:FwKill(target)

-- client (required on VORP)
RegisterNetEvent('w_:client:killPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)
```

### exports.w_lib:FwGetInventoryItems

```lua
exports.w_lib:FwGetInventoryItems(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `table` - array of `{ name, count, amount, label, weight, id, slot, metadata, info }` for every non-weapon item (`count` and `amount` are the same number; `id` and `slot` are the same slot; `metadata` and `info` are the same table). When the active bag is `w_inventory` and its native storage is `'vorp'`, returns vorp_inventory's `getUserInventoryItems(source)` result instead.

Reads the active inventory through `exports.w_lib:InvGetItems` and filters out names starting with `WEAPON_`. Returns an empty table when the bridge has no active bag.

```lua
for _, it in ipairs(exports.w_lib:FwGetInventoryItems(src)) do
    print(it.name, it.count, it.slot)
end
```

### exports.w_lib:FwGetInventoryWeapons

```lua
exports.w_lib:FwGetInventoryWeapons(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `table` - array of `{ name, id (metadata.weaponId or slot), slot, weight, label, custom_label, serial_number, ammo, components, metadata, info, type='weapon', group=0, propietary='', used: boolean, used2: boolean }`. With w_inventory native `'vorp'` storage, vorp_inventory's `getUserInventoryWeapons(source)` result instead.

Weapons are the items whose name starts with `WEAPON_` (case-insensitive). `serial_number` comes from `metadata.serie/serial/serial_number` (`''` if none); `ammo` from `metadata.ammo` (0 if none); `used`/`used2` accept `true`, `1` or `'1'`, and `used2` is only true when `used` is also true.

```lua
for _, w in ipairs(exports.w_lib:FwGetInventoryWeapons(src)) do
    print(w.name, w.id, w.ammo)
end
```

### exports.w_lib:FwAddItem

```lua
exports.w_lib:FwAddItem(source: integer, itemName: string, count?: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `itemName` (string, required) - item name as defined in the active inventory.
- `count` (integer, optional, default 1) - quantity.

Returns: `boolean` - true only when `exports.w_lib:InvAddItem` returned true.

Thin wrapper over `exports.w_lib:InvAddItem(source, itemName, count or 1, nil)` (no metadata). Use `InvAddItem` directly when metadata is needed.

```lua
if not exports.w_lib:FwAddItem(src, 'bread', 2) then
    print('could not add')
end
```

### exports.w_lib:FwRemoveItem

```lua
exports.w_lib:FwRemoveItem(source: integer, itemName: string, count?: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `itemName` (string, required) - item name.
- `count` (integer, optional, default 1) - quantity.

Returns: `boolean` - true only when `exports.w_lib:InvRemoveItem` returned true.

Wrapper over `exports.w_lib:InvRemoveItem(source, itemName, count or 1, nil, nil)` (no metadata, no slot).

```lua
exports.w_lib:FwRemoveItem(src, 'bread', 1)
```

### exports.w_lib:FwAddWeapon

```lua
exports.w_lib:FwAddWeapon(source: integer, weaponName: string, ammo?: table|number)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `weaponName` (string, required) - weapon item name, e.g. `WEAPON_REVOLVER_CATTLEMAN`.
- `ammo` (table|number, optional, default 0 / `{}`) - VORP-style ammo map `{ AMMO_REVOLVER = 20 }` or a plain count. On the native-VORP and vorp_inventory paths only a table is honoured (a number is replaced by `{}`); on every other bag a table is summed into one integer and a number is floored (minimum 0), stored as `metadata.ammo`.

Returns: `boolean` - true on success.

w_inventory native `'vorp'` storage: `exports.vorp_inventory:createWeapon(source, weaponName, ammoTable, nil, {})`. Otherwise `exports.w_lib:InvAddItem(source, weaponName, 1, { ammo = ... })`.

```lua
exports.w_lib:FwAddWeapon(src, 'WEAPON_REVOLVER_CATTLEMAN', { AMMO_REVOLVER = 12 })
```

### exports.w_lib:FwRemoveWeapon

```lua
exports.w_lib:FwRemoveWeapon(source: integer, weaponId: integer|string)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `weaponId` (integer|string, required) - the `id` reported by `FwGetInventoryWeapons`: a slot, a vorp weapon id (also tried as `'w<id>'` under vorp_inventory), or a metadata `weaponId` / `serial` / `serial_number`.

Returns: `boolean` - true when a matching `WEAPON_` item was removed, false when nothing matched.

w_inventory native `'vorp'` storage: `exports.vorp_inventory:subWeapon(source, weaponId)`. Otherwise resolves the slot via `InvGetSlot`, then scans `InvGetItems` for matching metadata, and removes one unit with `InvRemoveItem(source, name, 1, metadata, slot)`; under vorp_inventory `metadata.weaponId` is filled with `tonumber(weaponId)` when missing.

```lua
for _, w in ipairs(exports.w_lib:FwGetInventoryWeapons(src)) do
    exports.w_lib:FwRemoveWeapon(src, w.id)
end
```

### exports.w_lib:FwCanCarryItem

```lua
exports.w_lib:FwCanCarryItem(source: integer, itemName: string, count?: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `itemName` (string, required) - item name.
- `count` (integer, optional, default 1) - quantity.

Returns: `boolean` - `exports.w_lib:InvCanCarry(...) == true`.

Weight/slot check delegated to the active inventory bridge.

```lua
if exports.w_lib:FwCanCarryItem(src, 'bread', 5) then exports.w_lib:FwAddItem(src, 'bread', 5) end
```

### exports.w_lib:FwCanCarryWeapon

```lua
exports.w_lib:FwCanCarryWeapon(source: integer, count: integer, weaponName: string)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `count` (integer, required; default 1 when nil) - quantity. Note that this comes before `weaponName`.
- `weaponName` (string, required) - weapon item name.

Returns: `boolean` - `exports.w_lib:InvCanCarry(source, weaponName, count or 1) == true`.

Same check as `FwCanCarryItem` but with the argument order `(source, count, weaponName)`.

```lua
if exports.w_lib:FwCanCarryWeapon(src, 1, 'WEAPON_RIFLE_SPRINGFIELD') then print('ok') end
```

### exports.w_lib:FwClearInventory

```lua
exports.w_lib:FwClearInventory(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `boolean` - always true.

Iterates `exports.w_lib:InvGetItems(source)` and calls `InvRemoveItem(source, name, count or 1, metadata or {}, slot)` for each entry, weapons included. Individual failures are ignored.

```lua
exports.w_lib:FwClearInventory(target)
```

### exports.w_lib:FwGetOfflineInventory

```lua
exports.w_lib:FwGetOfflineInventory(charId: integer|string)
```

Side: server

Parameters:
- `charId` (integer|string, required) - VORP charidentifier (number) or RSG/QBR citizenid (string).

Returns: two values, `items: table, weapons: table`. Row shapes depend on the path:
- w_inventory bag: items `{ name, count, weight, label, type='item', itemId=slot, slot, metadata }`; weapons `{ name, count=1, weight, label, type='weapon', itemId=slot, slot, serial_number, ammo (number), metadata }`.
- vorp_inventory: items `{ name, count, label, type='item', weight=0, itemId=items_crafted id }` from inventory_type `'default'`; weapons `{ name, count=1, weight=1.0, label, type='weapon', itemId=loadout.id, serial_number, ammo (decoded JSON table), group=comps, used, used2 }`.
- RSG/QBR: items `{ name, count, label, type (from the row), weight, itemId=slot }`; weapons `{ name, count=1, weight, label, type='weapon', itemId=slot, serial_number (info.serie), ammo (info.ammo) }`.
- When w_inventory reports any native storage, whatever `exports.w_inventory:GetNativeOfflineInventory(charId)` returns is passed through instead.

Direct database read for a player who is offline. Sources: w_inventory bag -> the inventory JSON column of `characters` (VORP, keyed by charidentifier) or `players` (RSG, keyed by citizenid); vorp_inventory -> `character_inventories`/`items_crafted`/`items` joins plus the `loadout` table; rsg/qbr -> `players.inventory` JSON. Blocking (MySQL await). Returns two empty tables on an unknown framework.

```lua
local items, weapons = exports.w_lib:FwGetOfflineInventory(charId)
print(#items, #weapons)
```

### exports.w_lib:FwAddItemOffline

```lua
exports.w_lib:FwAddItemOffline(charId: integer|string, itemName: string, count?: integer)
```

Side: server

Parameters:
- `charId` (integer|string, required) - VORP charidentifier or RSG/QBR citizenid.
- `itemName` (string, required) - item name; must exist in `exports.w_inventory:Items` (w_inventory bag) or the VORP `items` table; on RSG unknown names are still inserted with default fields.
- `count` (integer, optional) - quantity. Defaults to 1 on the w_inventory and native paths (floored, minimum 1). On the vorp_inventory and RSG paths it is used as-is, so pass a number there (nil would break the arithmetic/SQL).

Returns: `boolean success, string|nil error` (`'Player not found'`, `'Item definition not found'`, `'Failed to create item instance'`, `'Unknown framework'`); on the native path whatever `MutateNativeOfflineInventory` returns.

Writes to the database for an offline character. w_inventory bag: stacks onto an existing row when the definition is stackable and not a weapon; non-stackable and weapon definitions get one row per unit. vorp_inventory: adds to the existing `character_inventories` row or creates `items_crafted` plus `character_inventories` rows. RSG/QBR: increments the matching row of `players.inventory` or appends a new one. Do not use on a connected player. With native w_inventory storage delegates to `exports.w_inventory:MutateNativeOfflineInventory(charId, 'add', itemName, count or 1)`.

```lua
local ok, err = exports.w_lib:FwAddItemOffline(charId, 'bread', 3)
if not ok then print(err) end
```

### exports.w_lib:FwRemoveItemOffline

```lua
exports.w_lib:FwRemoveItemOffline(charId: integer|string, itemName: string, count?: integer)
```

Side: server

Parameters:
- `charId` (integer|string, required) - VORP charidentifier or RSG/QBR citizenid.
- `itemName` (string, required) - item name.
- `count` (integer, optional) - quantity, default 1 on the w_inventory and native paths; on the vorp_inventory and RSG paths a nil count subtracts nil and errors, so pass a number.

Returns: `boolean success, string|nil error` (`'Player not found'`, `'Item not found in inventory'`, `'Failed to parse inventory'`, `'Unknown framework'`).

Database removal for an offline character. w_inventory bag: fails if the total held is below `count`, otherwise drains across stacks. vorp_inventory: decrements the first matching `character_inventories` row or deletes it together with its `items_crafted` row. RSG/QBR: rewrites `players.inventory`, touching only the first matching row. Native w_inventory storage delegates to `MutateNativeOfflineInventory(charId, 'remove', itemName, count or 1)`.

```lua
local ok, err = exports.w_lib:FwRemoveItemOffline(charId, 'bread', 1)
```

### exports.w_lib:FwAddWeaponOffline

```lua
exports.w_lib:FwAddWeaponOffline(charId: integer|string, weaponName: string, ammo?: table|number)
```

Side: server

Parameters:
- `charId` (integer|string, required) - VORP charidentifier or RSG/QBR citizenid.
- `weaponName` (string, required) - weapon name, e.g. `WEAPON_REVOLVER_CATTLEMAN`.
- `ammo` (table|number, optional) - ammo map or count; used by the w_inventory bag path (summed to one integer) and passed through to the native storage path. Ignored on the vorp loadout path (inserted with `'{}'`) and on RSG.

Returns: `boolean success, string|nil error`.

w_inventory bag: inserts a new weapon row with generated serial, durability and expiry. vorp_inventory: `INSERT INTO loadout` for that charidentifier (label = weaponName). RSG/QBR: same as `FwAddItemOffline(charId, weaponName, 1)`. Native storage: `MutateNativeOfflineInventory(charId, 'add', weaponName, 1, nil, ammo)`.

```lua
exports.w_lib:FwAddWeaponOffline(charId, 'WEAPON_REVOLVER_CATTLEMAN', 6)
```

### exports.w_lib:FwRemoveWeaponOffline

```lua
exports.w_lib:FwRemoveWeaponOffline(charId: integer|string, weaponId?: integer|string, weaponName?: string)
```

Side: server

Parameters:
- `charId` (integer|string, required) - VORP charidentifier or RSG/QBR citizenid.
- `weaponId` (integer|string, optional) - `itemId` from `FwGetOfflineInventory`: `loadout.id` (vorp_inventory, required there), slot number or `'w<slot>'` or serial (w_inventory bag), slot (RSG).
- `weaponName` (string, optional) - fallback match by name when `weaponId` is nil (w_inventory bag) or when the slot does not match (RSG). On the native storage path it is the item passed to `MutateNativeOfflineInventory`, so pass both.

Returns: `boolean` - true when a row was removed (the VORP loadout path always returns true).

Removes one weapon from an offline character. Pass the `itemId` and name obtained from `FwGetOfflineInventory`. Native storage: `MutateNativeOfflineInventory(charId, 'remove', weaponName, 1, weaponId)`.

```lua
local _, weapons = exports.w_lib:FwGetOfflineInventory(charId)
if weapons[1] then exports.w_lib:FwRemoveWeaponOffline(charId, weapons[1].itemId, weapons[1].name) end
```

### exports.w_lib:FwAddCurrencyOffline

```lua
exports.w_lib:FwAddCurrencyOffline(identifier: string, currencyType: integer, amount: number)
```

Side: server

Parameters:
- `identifier` (string, required) - VORP: account identifier (`characters.identifier`); the update applies to every character on that account. RSG/QBR: citizenid.
- `currencyType` (integer, required) - `0` = VORP money / RSG cash, `1` = VORP gold / RSG bloodmoney (always bloodmoney offline, no gold check), `2` = VORP rol / RSG blkbank.
- `amount` (number, required) - amount to add.

Returns: `boolean success, string|nil error`. Error codes: `'invalid_amount'` (amount missing, not a number, NaN, infinite or not above 0; outside the direct SQL path also a currency type other than 0 or 1), `'invalid_data'` (unknown currency type on the direct SQL path) and `'economy_unavailable'` (w_centralbank is not started or not ready; this code also covers a host with no w_centralbank whose framework is neither VORP nor RSG). On the w_centralbank path the result is whatever `AdjustPlayer` answers.

Two paths. When w_centralbank is started (Wraith Core, where w_core runs), the change goes through `exports.w_centralbank:AdjustPlayer(identifier, 'cash'|'gold', amount, 'offline-framework-currency')`, so only types 0 and 1 are accepted. Without w_centralbank, on a host with no w_core resource at all, it writes the framework table directly: VORP `UPDATE characters SET <col> = <col> + ? WHERE identifier = ?`; RSG `JSON_SET` on `players.money WHERE citizenid = ?`. Offline players only.

```lua
exports.w_lib:FwAddCurrencyOffline('steam:110000112345678', 0, 100)
```

### exports.w_lib:FwRemoveCurrencyOffline

```lua
exports.w_lib:FwRemoveCurrencyOffline(identifier: string, currencyType: integer, amount: number)
```

Side: server

Parameters:
- `identifier` (string, required) - VORP account identifier (all characters of the account) or RSG/QBR citizenid.
- `currencyType` (integer, required) - `0` = money/cash, `1` = VORP gold / RSG bloodmoney, `2` = rol/blkbank.
- `amount` (number, required) - amount to subtract; the balance is clamped at 0 with `GREATEST`.

Returns: `boolean success, string|nil error` (`'invalid_amount'`, `'invalid_data'`, `'economy_unavailable'`, or `AdjustPlayer`'s answer on the w_centralbank path; same meanings as `FwAddCurrencyOffline`).

Same as `FwAddCurrencyOffline` with subtraction: through w_centralbank `AdjustPlayer` with a negative amount when it is started; without it (no w_core on the host) a direct write to VORP `characters` or RSG `players`, clamped at zero.

```lua
exports.w_lib:FwRemoveCurrencyOffline('steam:110000112345678', 1, 5)
```

### exports.w_lib:FwGetJobOffline

```lua
exports.w_lib:FwGetJobOffline(identifier: string, charId: integer)
```

Side: server

Parameters:
- `identifier` (string, required) - RSG/QBR citizenid (ignored on VORP).
- `charId` (integer, required) - VORP charidentifier (ignored on RSG).

Returns: `table|nil` - `{ name: string ('unemployed' default), label: string, grade: integer, gradeName: string (RSG only, '' when unset) }`; nil when the row is missing or the framework is unknown.

Reads the job of an offline character. Pass both arguments; each framework uses the one it needs.

```lua
local job = exports.w_lib:FwGetJobOffline(citizenid, charId)
if job then print(job.name, job.grade) end
```

### exports.w_lib:FwSetPlayerJobOffline

```lua
exports.w_lib:FwSetPlayerJobOffline(identifier: string, charId: integer, jobName: string, jobGrade: integer, jobLabel: string)
```

Side: server

Parameters:
- `identifier` (string, required) - RSG/QBR citizenid (ignored on VORP).
- `charId` (integer, required) - VORP charidentifier (ignored on RSG).
- `jobName` (string, required) - job name; on RSG looked up in `Core.Shared.Jobs` to fill label, payment and isboss.
- `jobGrade` (integer, required) - grade level, written as-is (RSG grade data is looked up with `tostring(jobGrade)`).
- `jobLabel` (string, required) - label written on VORP (`characters.joblabel`); RSG uses the shared job's label instead (falling back to `jobName`).

Returns: `boolean` - true on VORP/RSG, false otherwise.

Per-character offline job update. VORP: `UPDATE characters SET job, jobgrade, joblabel WHERE charidentifier`. RSG: replaces `players.job` with a full job object (`onduty=false`, `grade.name` `'Unknown'` when the grade is not in the shared definition).

```lua
exports.w_lib:FwSetPlayerJobOffline(citizenid, charId, 'doctor', 0, 'Doctor')
```

### exports.w_lib:FwSetJobFullOffline

```lua
exports.w_lib:FwSetJobFullOffline(identifier: string, jobName: string, jobGrade: integer)
```

Side: server

Parameters:
- `identifier` (string, required) - VORP account identifier (affects every character of the account) or RSG/QBR citizenid.
- `jobName` (string, required) - job name; on RSG it is also written as the label.
- `jobGrade` (integer, required) - grade level (RSG coerces with `tonumber`, default 0).

Returns: `boolean` - true on VORP/RSG (even when no RSG row matched), false on an unknown framework.

VORP: `UPDATE characters SET job, jobGrade WHERE identifier`. RSG: rewrites the `players.job` JSON (name, label = jobName, grade.level). Prefer `FwSetPlayerJobOffline` when the charId is known and a per-character update is wanted.

```lua
exports.w_lib:FwSetJobFullOffline(identifier, 'police', 1)
```

### exports.w_lib:FwSetJobLabelOffline and FwSetJobGradeOffline

```lua
exports.w_lib:FwSetJobLabelOffline(identifier: string, jobLabel: string)
exports.w_lib:FwSetJobGradeOffline(identifier: string, jobGrade: integer)
```

Side: server

Parameters:
- `identifier` (string, required) - VORP account identifier (all characters of the account) or RSG/QBR citizenid.
- `jobLabel` (string, required, `FwSetJobLabelOffline`) - new label.
- `jobGrade` (integer, required, `FwSetJobGradeOffline`) - grade level (RSG coerces with `tonumber`, default 0).

Returns: `boolean` - true on VORP/RSG, false otherwise.

`FwSetJobLabelOffline`: VORP `UPDATE characters SET jobLabel WHERE identifier`; RSG `players.job` JSON label. `FwSetJobGradeOffline`: VORP `UPDATE characters SET jobGrade WHERE identifier`; RSG `players.job` JSON `grade.level`.

```lua
exports.w_lib:FwSetJobLabelOffline(identifier, 'Deputy')
exports.w_lib:FwSetJobGradeOffline(identifier, 2)
```

### exports.w_lib:FwRemoveJobOffline

```lua
exports.w_lib:FwRemoveJobOffline(charId: integer)
```

Side: server

Parameters:
- `charId` (integer, required) - VORP charidentifier.

Returns: `boolean` - true on VORP, false on RSG/QBR (not implemented there; multijob scripts own it).

VORP only: sets `job='unemployed'`, `jobgrade=0`, `joblabel='Unemployed'` for that character.

```lua
exports.w_lib:FwRemoveJobOffline(charId)
```

### Character field setters (offline)

Server side. Each takes the same first two keys and a new value.

```lua
exports.w_lib:FwSetFirstNameOffline(identifier: string, charId: integer, value: string)
exports.w_lib:FwSetLastNameOffline(identifier: string, charId: integer, value: string)
exports.w_lib:FwSetNicknameOffline(identifier: string, charId: integer, value: string)
exports.w_lib:FwSetAgeOffline(identifier: string, charId: integer, value: number)
exports.w_lib:FwSetDescriptionOffline(identifier: string, charId: integer, value: string)
```

Parameters:
- `identifier` (string, required) - RSG/QBR citizenid (ignored on VORP).
- `charId` (integer, required) - VORP charidentifier; required on VORP (returns `false, 'character_not_found'` when nil).
- `value` (string, or number for `FwSetAgeOffline`; required) - the new value.

Returns: `boolean success, string|nil error` (`'character_not_found'`); false on an unknown framework.

| Export | VORP column (`characters`, by charidentifier) | RSG (`players.charinfo` via `JSON_SET`, by citizenid) |
| --- | --- | --- |
| `FwSetFirstNameOffline` | `firstname` | `charinfo.firstname` |
| `FwSetLastNameOffline` | `lastname` | `charinfo.lastname` |
| `FwSetNicknameOffline` | `nickname` | `charinfo.nickname` |
| `FwSetAgeOffline` | `age` | `charinfo.age` |
| `FwSetDescriptionOffline` | `charDescription` | `charinfo.description` |

```lua
exports.w_lib:FwSetFirstNameOffline(citizenid, charId, 'Arthur')
exports.w_lib:FwSetLastNameOffline(citizenid, charId, 'Morgan')
exports.w_lib:FwSetNicknameOffline(citizenid, charId, 'Dutch')
exports.w_lib:FwSetAgeOffline(citizenid, charId, 40)
exports.w_lib:FwSetDescriptionOffline(citizenid, charId, 'Drifter.')
```

### exports.w_lib:FwGetOfflineCharacters

```lua
exports.w_lib:FwGetOfflineCharacters(searchTerm?: string, limit?: integer, extraIds?: string[])
```

Side: server

Parameters:
- `searchTerm` (string, optional) - `LIKE '%term%'` against firstname, lastname, identifier and discordid (VORP) or citizenid, firstname and lastname (RSG). nil or `''` returns unfiltered rows.
- `limit` (integer, optional, default 200) - row limit (`tonumber` applied).
- `extraIds` (string[], optional) - extra account keys to include (VORP identifier / RSG license) OR-ed into the WHERE clause; only used when `searchTerm` is non-empty.

Returns: `table` - array of `{ charId: string, identifier: string, cacheKey: string, firstName, lastName, nickname, jobName, jobLabel, jobGrade, cash, gold, lastLogin, discordid }`; empty on an unknown framework.

Unified character listing for admin panels. On VORP `charId` is `tostring(charIdentifier)` and `identifier`/`cacheKey` are the account identifier; on RSG `charId` and `identifier` are the citizenid, `cacheKey` is the license, `gold` is `money.bloodmoney` and `lastLogin` comes from `metadata.lastlogin`. `nickname` is always `''` on VORP; `discordid` is always `''` on RSG.

```lua
for _, row in ipairs(exports.w_lib:FwGetOfflineCharacters('Morgan', 50)) do
    print(row.charId, row.firstName, row.lastName)
end
```

### exports.w_lib:FwGetDiscordId

```lua
exports.w_lib:FwGetDiscordId(identifier: string)
```

Side: server

Parameters:
- `identifier` (string, required) - VORP account identifier (`characters.identifier`).

Returns: `string|nil` - first non-empty `characters.discordid` for that identifier; nil on RSG/QBR or when none is stored.

VORP only. Blocking MySQL read (`MySQL.single.await`); do not call it from a hot path, and wrap it in pcall.

```lua
local ok, discord = pcall(function() return exports.w_lib:FwGetDiscordId(identifier) end)
```

### exports.w_lib:FwGetCharactersWithDiscord

```lua
exports.w_lib:FwGetCharactersWithDiscord(limit?: integer)
```

Side: server

Parameters:
- `limit` (integer, optional, default 200) - row limit.

Returns: `table` - array of `{ identifier: string, discordid: string }` (DISTINCT); `{}` on RSG/QBR.

VORP only: characters that have a non-empty discordid.

```lua
local rows = exports.w_lib:FwGetCharactersWithDiscord(500)
```

### Database statistics

Server side, no parameters, one blocking SQL query each. Intended for dashboards.

```lua
exports.w_lib:FwGetTotalCash()
exports.w_lib:FwCountCharacters()
exports.w_lib:FwCountAllCharacters()
```

| Export | Returns | VORP and any non-RSG framework | RSG/QBR |
| --- | --- | --- | --- |
| `FwGetTotalCash` | `number`, 0 when the query returns nothing | `SUM(characters.money)` | `SUM(players.money.cash)` |
| `FwCountCharacters` | `number` of characters | `COUNT(identifier)` of `characters` rows | `COUNT(citizenid)` of `players` rows |
| `FwCountAllCharacters` | `number` of accounts (VORP users) rather than characters | `COUNT(*)` of the `users` table | `COUNT(*)` of `players` |

```lua
local total = exports.w_lib:FwGetTotalCash()
local n = exports.w_lib:FwCountCharacters()
local accounts = exports.w_lib:FwCountAllCharacters()
```

### exports.w_lib:FwGetSharedItems, FwGetSharedWeapons, FwGetSharedJobs

```lua
exports.w_lib:FwGetSharedItems()
exports.w_lib:FwGetSharedWeapons()
exports.w_lib:FwGetSharedJobs()
```

Side: server

Parameters: none

Returns:
- `FwGetSharedItems`: `table` - `Core.Shared.Items` keyed by item name (RSG/QBR); `{}` on VORP or before detection.
- `FwGetSharedWeapons`: `table` - `Core.Shared.Weapons` (RSG/QBR); `{}` on VORP or before detection.
- `FwGetSharedJobs`: `table` - `Core.Shared.Jobs` keyed by job name, each with `label` and `grades` (RSG/QBR); `{}` on VORP or before detection.

These are the safe way to read the RSG/QBR definitions across the export boundary, as plain data. VORP has no `Core.Shared`, so consumers (w_crafting, w_legal, w_gunsmith) fall back to their own item lists when the result is empty. On QBR the tables are snapshots taken at detection time. `FwGetSharedJobs` is the same table that `FwSetJob`, `FwSetJobLabel` and `FwSetPlayerJobOffline` consult.

```lua
local shared = exports.w_lib:FwGetSharedItems()
local def = shared['bread']
if def then print(def.label) end

for name, job in pairs(exports.w_lib:FwGetSharedJobs()) do print(name, job.label) end
local weapons = exports.w_lib:FwGetSharedWeapons()
```

### exports.w_lib:HasPermissionNode

```lua
exports.w_lib:HasPermissionNode(source: integer|string, node: string)
```

Side: server

Parameters:
- `source` (integer|string, required) - player server id (`tonumber` is applied); 0 is the console and always passes once the node is valid.
- `node` (string, required) - permission node: lowercase dot-delimited identifiers, each segment `^[a-z][a-z0-9_-]*$`, total 1-96 characters, no leading, trailing or double dots. Input is trimmed and lowercased before validation, e.g. `'w_baloot.admin'`, `'w_legal.court.judge'`.

Returns: `boolean allowed, string reason` - the reason is `'console'`, `'admin'`, the exact node, the wildcard that matched (`'a.b.*'`, `'a.*'`), `'*'`, `'forbidden'`, `'invalid source'`, or one of the validation messages `'permission node must be a string'`, `'permission node must contain between 1 and 96 characters'`, `'permission node must be dot-delimited lowercase identifiers'`.

Resolution order: malformed node -> false plus message; source 0 -> true, `'console'`; nil, below 1 or disconnected source (`GetPlayerName` is nil) -> false, `'invalid source'`; `exports.w_lib:IsAdmin(source)` -> true, `'admin'`; `IsPlayerAceAllowed(source, node)`; then wildcard ACEs from the most specific prefix to the least (`'a.b.c'` checks `'a.b.*'` then `'a.*'`; a single-segment node has no prefix wildcards); then the global `'*'` ACE; otherwise false, `'forbidden'`. Grant with standard `server.cfg` ACE lines. This is the check every Wraith resource uses for its own feature gates (w_baloot, w_legal, w_logs, w_pausemenu, w_stables).

```lua
-- server.cfg: add_ace group.staff w_baloot.admin allow
--             add_principal identifier.steam:110000112345678 group.staff
local function isAdmin(src)
    if src == 0 then return true end
    return exports.w_lib:HasPermissionNode(src, 'w_baloot.admin') == true
end
```

### exports.w_lib:IsAdmin

```lua
exports.w_lib:IsAdmin(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id; nil returns false.

Returns: `boolean`

True when `HasPermission(source, 'admin')` is true (so any of admin, superadmin, owner or god on VORP-style frameworks, or the core's own `'admin'` permission on RSG/QBR/QR) OR when `IsPlayerAceAllowed(source, 'command')` is true (e.g. `add_ace group.admin command allow` in `server.cfg`). Source 0 (console) is not special-cased here; `HasPermissionNode` handles console.

```lua
if exports.w_lib:IsAdmin(src) ~= true then
    return exports.w_lib:NotifyPlayer(src, 'Admin', 'Not allowed', 'error')
end
```

### exports.w_lib:HasPermission

```lua
exports.w_lib:HasPermission(source: integer, group: string)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.
- `group` (string, required) - framework group or permission name, e.g. `'admin'`, `'moderator'`.

Returns: `boolean`

rsg / rsg_v2 / qr: `exports['rsg-core' or 'qr-core']:GetCoreObject().Functions.HasPermission(source, group) == true`. qbr: `exports['qbr-core']:HasPermission(source, group) == true`. Any other framework (VORP, RedEM, TPZ, ...): true when `GetPlayerGroup(source) == group`, or when both the requested group and the player's group are in the admin set `{admin, superadmin, owner, god}`; false when the player has no group. The core calls are pcall-guarded, but consumers still wrap it in pcall while the framework starts.

```lua
local ok, allowed = pcall(function() return exports.w_lib:HasPermission(src, 'moderator') end)
if ok and allowed == true then print('moderator') end
```

### exports.w_lib:GetPlayerGroup

```lua
exports.w_lib:GetPlayerGroup(source: integer)
```

Side: server

Parameters:
- `source` (integer, required) - player server id.

Returns: `string|nil` - group name, or nil when the player has no `w.framework` user (or the user has no data table), or on frameworks without a group concept (rsg, rsg_v2, qbr, qr, rpx, frp).

Uses the `w.framework` module detector (ids `vorp`, `redemrp_old`, `redemrp_2023`, `qbr`, `rsg`, `rsg_v2`, `qr`, `rpx`, `tpz`, `frp`). TPZ: `user:getGroup()` (the only user class with that method). VORP: `exports.vorp_core:GetCore().getUser(source).getGroup` (the account group from `users.group`) when it is a non-empty string other than `'user'`; otherwise the character's `data.group`. RedEM 2023: `data.GetGroup()` or `data.group`; RedEM old: `data.getGroup()`. Everything else: nil.

```lua
local group = exports.w_lib:GetPlayerGroup(src) or 'user'
```

### ACL helpers: lib.addAce, lib.removeAce, lib.addPrincipal, lib.removePrincipal

```lua
lib.addAce(principal: string|integer, ace: string, allow?: boolean)
lib.removeAce(principal: string|integer, ace: string, allow?: boolean)
lib.addPrincipal(child: string|integer, parent: string)
lib.removePrincipal(child: string|integer, parent: string)
```

Side: server

Parameters:
- `principal` / `child` (string|integer, required) - principal name such as `'group.staff'` or `'identifier.steam:...'`; a number is turned into `'player.<id>'` (a connected player's server id).
- `ace` (string, required; `addAce`/`removeAce`) - ACE object, e.g. `'w_legal.*'` or `'command.revive'`.
- `allow` (boolean, optional; `addAce`/`removeAce`) - `false` writes `deny`; anything else (including nil) writes `allow`. For `removeAce` it must match the kind of the grant being removed.
- `parent` (string, required; `addPrincipal`/`removePrincipal`) - parent principal, e.g. `'group.staff'`.

Returns: nothing

| Helper | Command run | Also reachable as |
| --- | --- | --- |
| `lib.addAce` | `ExecuteCommand('add_ace <principal> <ace> allow|deny')` | `exports.w_lib:addAce` |
| `lib.removeAce` | `ExecuteCommand('remove_ace <principal> <ace> allow|deny')` | `exports.w_lib:removeAce` |
| `lib.addPrincipal` | `ExecuteCommand('add_principal <child> <parent>')` so the child inherits the parent's ACEs | `exports.w_lib:addPrincipal` |
| `lib.removePrincipal` | `ExecuteCommand('remove_principal <child> <parent>')` | `exports.w_lib:removePrincipal` |

Grants made this way are runtime-only and vanish on restart; persistent grants belong in `server.cfg`. Functions cannot be passed here, only strings and numbers. The `lib.*` form requires a resource that loads `@w_lib/init.lua`.

```lua
lib.addAce(src, 'w_legal.court.judge')        -- player.<src>
lib.addAce('group.staff', 'w_lib.*', true)
lib.removeAce(src, 'w_legal.court.judge')
lib.addPrincipal(src, 'group.staff')
lib.removePrincipal(src, 'group.staff')
```

### Events

| Name | Side | Payload or value | Meaning |
| --- | --- | --- | --- |
| `w_:client:killPlayer` | client | none | Client net event triggered by `FwKill` on VORP only. The library does not handle it anywhere; the consumer resource must register a handler that kills the local ped (w_admin does `SetEntityHealth(PlayerPedId(), 0)`). Without a handler `FwKill` returns true but nothing happens. |
| `w_lib:checkPlayerAce` | client (called), server (registered) | `lib.callback.await('w_lib:checkPlayerAce', timeout: number|false, ace: string)` -> `boolean` (`IsPlayerAceAllowed(source, ace)` evaluated on the server for the caller) | A lib.callback (not a plain net event) registered by the library's server. Clients call it through `lib.callback.await` to test their own ACE without writing a server callback; the reply is routed back to the calling resource. The library's client `RegisterCommand` override uses it with `command.<name>` when the third argument (restricted) is true, so a client command registered with `restricted=true` only runs for players holding that ACE. Only usable from a resource that loads `@w_lib/init.lua`. |

```lua
-- client
RegisterNetEvent('w_:client:killPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

local allowed = lib.callback.await('w_lib:checkPlayerAce', 100, 'w_legal.admin')
if allowed then print('has ace') end
```

### Convars

| Name | Side | Payload or value | Meaning |
| --- | --- | --- | --- |
| `w_lib:inventory` | shared (set with `setr` in `server.cfg`) | `'auto'` (default) or one of `w_inventory`, `vorp_inventory`, `rsg-inventory`, `qbr-inventory`; aliases `w`, `ox` -> `w_inventory`, `vorp` -> `vorp_inventory`, `rsg` -> `rsg-inventory`, `qbr` -> `qbr-inventory`. Case and whitespace are ignored. | Forces which inventory resource the bridge (and therefore `FwInventory` and every Fw inventory export) uses. Ignored whenever `w_inventory` is started, because `w_inventory` is always the authority. `'auto'` picks the first started of `w_inventory`, `rsg-inventory`, `qbr-inventory`, `vorp_inventory`. A value that is not a known adapter prints `[w_lib] invalid w_lib:inventory value: ...` and leaves the bridge without a bag (Inv*/Fw inventory calls return false or empty); a known but not-yet-started value prints a warning and is retried on the next call. Use `setr` so the client sees the same value; the client consults it only after the replicated `w_lib:activeInventory` (when set and started locally) and a locally started `w_inventory` have been ruled out. |
| `w_lib:activeInventory` | shared (replicated, read-only) | `GetConvar('w_lib:activeInventory', '')` -> the inventory resource name the server bridge selected, `''` before selection | Set by the library (`SetConvarReplicated`) once the server bridge picks a bag; do not set it yourself. Clients read it first when resolving `exports.w_lib:InvName` / `FwInventory` so both sides agree. |

```lua
-- server.cfg
setr w_lib:inventory "vorp_inventory"
```

```lua
local bag = GetConvar('w_lib:activeInventory', '')
```

### Commands

This subsystem registers no commands of its own. The ACL helpers wrap the standard Cfx console commands `add_ace`, `remove_ace`, `add_principal` and `remove_principal`, which are the same commands used in `server.cfg` to grant permission nodes.

## Inventory bridge exports (Inv*), stash administration and the database helpers

The library owns a single inventory adapter for the whole server, so a consumer resource never talks to w_inventory, vorp_inventory, rsg-inventory or qbr-inventory directly. Every function in this subsystem is a plain resource export and is called as `exports.w_lib:<Name>(...)`. None of them is mirrored as `lib.<Name>` (they are registered with `exports()`, not as `lib` fields, and no wrapper table exists), and none of them is reachable through the `w.*` module tables. The server-side `Inv*` exports cover the player inventory, per-script stashes, and a stash catalogue with offline editing of any stash (used by admin tools). Three `Inv*` exports exist on the client. The `Db*` exports are server only.

### How the adapter is chosen

Adapter selection is lazy: it happens on the first `Inv*` call, and in a background thread that polls every 200 ms for the first 30 s, prints a red "no supported inventory is running yet" line once, then keeps polling every 2 s. The rules, in order:

1. If the resource `w_inventory` is started it is always chosen, regardless of any convar.
2. Otherwise the server convar `w_lib:inventory` is read. The value is lowercased and whitespace is stripped; the aliases `w` and `ox` map to `w_inventory`, `vorp` to `vorp_inventory`, `rsg` to `rsg-inventory`, `qbr` to `qbr-inventory`.
3. A value that is not one of the four adapters disables the bridge: a red console warning is printed once and every `Inv*` export returns its failure value (`false`, `0`, `nil` or `{}`).
4. A valid value whose resource is not started yet makes the bridge wait for it (a yellow warning, printed once).
5. With the default value `auto`, the first started resource in the order `w_inventory`, `rsg-inventory`, `qbr-inventory`, `vorp_inventory` wins.

Once chosen, the name is published to every client through the replicated convar `w_lib:activeInventory` and printed as `[w_lib] inventory bridge -> <name>`. If a native inventory was chosen and `w_inventory` starts later in the boot sequence, the next `Inv*` call switches to `w_inventory` and re-registers every usable item. Use `setr` (not `set`) for `w_lib:inventory` so the client fallback can read it too; the client normally follows `w_lib:activeInventory`, which the server writes for you.

### Calling rules and gotchas

- All `Inv*` exports are synchronous from the caller's point of view and return plain values, but several adapters wait on callbacks internally (vorp_inventory wraps every callback-style call in a promise with a 5 s timeout that resolves to `nil`; the stash administration exports run MySQL `.await` queries). Call them from a thread, event handler or callback, never from top-level file scope during resource load.
- Player inventory exports take the player's server id (`source`); stash exports take a stash id string.
- Item names are passed through unchanged. Weapon handling is keyed on the name starting with `WEAPON_` (case-insensitive) and only matters for vorp_inventory, where weapons are separate objects: count is ignored, one weapon is created or removed per call, and metadata carries ammo, components and serial.
- Metadata tables are forwarded verbatim to w_inventory, vorp_inventory and rsg/qbr `AddItem`; rsg/qbr ignore metadata (and slot) for counting and removal.
- `InvRegisterUsableItem` is the only export that takes a Lua function. FiveM passes it across the export boundary as a function reference and the library invokes it from inside the inventory's own use handler, so keep the handler short or wrap its body in `CreateThread`. The definition is owned by the invoking resource (`GetInvokingResource`), is dropped when that resource stops (and unregistered from w_inventory), is keyed by item name (a later registration of the same name from any resource replaces the earlier one), and is re-applied automatically whenever the adapter is (re)selected, so registering before any inventory has started is fine. Every other export takes only strings, numbers and tables.

### Stash sources

The stash administration exports treat two kinds of storage:

- `stash` sources are named inventories in the active inventory system plus a library-owned catalogue table `w_lib_stashes` (`id`, `label`, `slots`, `max_weight`). The library creates the table on boot and re-registers every row with the active inventory at every server start (a thread waits for the table, then for an inventory, then calls `InvRegisterStash` per row).
- `vehicle:inventory`, `vehicle:trunk` and `vehicle:glovebox` sources are JSON columns on the framework's horse/wagon table, chosen from `exports.w_lib:FwName()`: `'qbr'` uses `horses`, `'rsgcore'` uses `player_horses`, anything else uses `stables`. The table must have an `id` column and the named column. Rows are addressed by their numeric id. When the active inventory is w_inventory and the column is `trunk` or `glovebox`, the library asks w_inventory (`GetLoadedVehicleInventoryId`) whether that storage is currently loaded and, if so, edits or reads the live inventory instead of the row. The `inventory` column and every other adapter always go straight to the JSON column.

Every returned item list is normalised to the same shape (`{ slot, name, item, label, count, amount, metadata, isWeapon }`, sorted by slot) so an admin UI can render any inventory the same way. Table schemas are discovered through `information_schema` and cached (an empty result is retried after 10 s). The stash administration exports are meant for administration and offline editing; for a script's own stash use `InvRegisterStash`, `InvAddItemToStash` and `InvOpenStash`, which go straight to the adapter.

### Database helpers

The `Db*` exports wrap oxmysql and hide the driver. The library loads `@oxmysql/lib/MySQL.lua` itself, so a consumer resource does not need oxmysql in its own manifest. Each call is synchronous (it awaits internally) and returns two values: `result, nil` on success, or `nil` (`false` for `DbReady` and `DbTransaction`) plus an error table on failure. The error table is `{ operation = string, code = string, message = string (max 1024 chars) }` and, for `DbTransaction` validation errors, `index` = the offending query index. When the failure is the permanent boot failure, the table returned by any `Db*` call is the stored one, so its `operation` field is `'ready'` (codes `connection_failed` / `healthcheck_failed`) rather than the name of the call that was made. Always test the second return value: `DbSingle` legitimately returns `nil, nil` when no row matches.

Parameters are never interpolated; they go to oxmysql prepared-statement handling, so use `?` placeholders (or oxmysql named placeholders with a keyed table). Validation runs before the readiness check and rejects non-string, empty, over-1 MiB or NUL-containing SQL, non-table parameters, non-finite numbers, tables deeper than 8 levels or with more than 10000 entries, cyclic tables, and keys that are not strings or numbers. The bridge becomes ready after `MySQL.ready` and a `SELECT 1` health check; if either fails the error is stored permanently and every call returns it (there is no retry), so call `DbReady` with a timeout during your resource's startup. Failed queries are also printed to the server console (via `lib.print.error` when available) together with the invoking resource's name.

### exports.w_lib:InvName (server)

```lua
exports.w_lib:InvName()
```

Side: server

Parameters: none.

Returns: `string | nil` — one of `'w_inventory'`, `'rsg-inventory'`, `'qbr-inventory'`, `'vorp_inventory'`, or `nil` when no supported inventory is running yet (or `w_lib:inventory` holds an invalid value).

Runs adapter selection and returns the name of the active inventory resource. Calling it triggers detection, so it is the standard way to wait for an inventory during startup: poll until it returns a non-nil value. On success it also sets the replicated convar `w_lib:activeInventory`, and it switches to w_inventory if that resource started after a native inventory was chosen.

```lua
CreateThread(function()
    local name
    repeat
        name = exports.w_lib:InvName()
        if not name then Wait(500) end
    until name
    print('inventory is ' .. name)
end)
```

### exports.w_lib:InvRegisterUsableItem

```lua
exports.w_lib:InvRegisterUsableItem(item: string, closeAfterUsed?: boolean, callback: function(source: number, data: table))
```

Side: server

Parameters:
- `item` (string, required): item name; converted with `tostring`, an empty string returns `false`.
- `closeAfterUsed` (boolean, optional, default `true`): close the player's inventory UI when the item is used. `nil` counts as `true`; only an explicit `false` disables it. If a function is passed here instead, it is taken as the callback and closing defaults to `true`.
- `callback` (function, required): invoked as `callback(source, data)` when the player uses the item. This is the one place the library accepts a function across the export boundary. `data` contains:
  - `metadata` (table, always): item metadata (w_inventory metadata, vorp `item.metadata`, rsg/qbr `info`); `{}` when none.
  - `slot` (number | string | nil): slot used (w_inventory slot; vorp slot, id or mainid; rsg/qbr slot).
  - `item` (table, always): the raw item table the underlying inventory passed; adapter-specific.

Returns: `boolean` — `true` when the definition was accepted (even if no inventory is running yet; it is applied when one starts, and a failure to register with the adapter is only printed in red); `false` when `item` is empty or `callback` is not a function.

Registers a use handler for an item across all adapters (w_inventory `RegisterUsableItem`, vorp `registerUsableItem`, rsg-core `Functions.CreateUseableItem`, qbr-core `CreateUseableItem`). The definition is owned by the invoking resource: it is removed (and unregistered from w_inventory via `UnregisterUsableItem`) when that resource stops, and a later registration for the same item name from any resource replaces it. Definitions are stored and re-applied whenever the bridge selects or switches its adapter. The callback runs inside the inventory's own use handler, so do long work in `CreateThread`. Ordering differs between adapters: on vorp the inventory is closed before the callback runs, on the others after.

```lua
exports.w_lib:InvRegisterUsableItem('horse_brush', true, function(source, data)
    CreateThread(function()
        local quality = data.metadata.quality or 0
        exports.w_lib:InvRemoveItem(source, 'horse_brush', 1, nil, data.slot)
        TriggerClientEvent('myres:client:brushHorse', source, quality)
    end)
end)
```

### exports.w_lib:InvGetItemCount

```lua
exports.w_lib:InvGetItemCount(src: number, item: string, meta?: table)
```

Side: server

Parameters:
- `src` (number, required): player server id.
- `item` (string, required): item name. Names starting with `WEAPON_` (case-insensitive) are counted as weapons on vorp_inventory (number of weapons whose name matches, case-insensitive).
- `meta` (table, optional): metadata filter. Forwarded to w_inventory `Search(src, 'count', item, meta)` and to vorp `getItem`'s fourth argument; ignored by rsg-inventory and qbr-inventory.

Returns: `number` — total count; `0` when the player has none, the adapter returned nothing, or no inventory is active.

Counts how many of an item the player carries. w_inventory: `exports.w_inventory:Search(src, 'count', item, meta)`. vorp_inventory: `getItem` count or amount (callback awaited, 5 s timeout), or the number of matching weapons for `WEAPON_` names. rsg/qbr: `GetItemByName` amount (or count).

```lua
local n = exports.w_lib:InvGetItemCount(source, 'horse_brush')
if n < 1 then return end
```

### exports.w_lib:InvCanCarry

```lua
exports.w_lib:InvCanCarry(src: number, item: string, count: number)
```

Side: server

Parameters:
- `src` (number, required): player server id.
- `item` (string, required): item name; `WEAPON_` names use vorp `canCarryWeapons(src, count, cb, item)`.
- `count` (number, required): quantity to test.

Returns: `boolean` — `true` only when the adapter answered `true` (rsg/qbr answering `nil` is treated as `true`); `false` when no inventory is active or the vorp callback timed out.

Checks weight and slot capacity before giving an item. w_inventory: `CanCarryItem`. vorp_inventory: `canCarryItem` or `canCarryWeapons` (callback awaited, 5 s timeout). rsg/qbr: `CanAddItem`.

```lua
if not exports.w_lib:InvCanCarry(source, 'bread', 3) then
    return lib.notify(source, { type = 'error', description = 'Inventory full' })
end
```

### exports.w_lib:InvAddItem

```lua
exports.w_lib:InvAddItem(src: number, item: string, count: number, meta?: table)
```

Side: server

Parameters:
- `src` (number, required): player server id.
- `item` (string, required): item name. On vorp_inventory a `WEAPON_` name creates exactly one weapon (`count` ignored).
- `count` (number, required): quantity to add.
- `meta` (table, optional): item metadata, forwarded verbatim to w_inventory `AddItem`, vorp `addItem` and rsg/qbr `AddItem` (as the `info` table). For vorp weapons only these fields are read:
  - `ammo` (table, optional): ammo table passed to vorp `createWeapon`; must be a table, any other type is replaced by `{}`.
  - `components` (table, optional, default `{}`): component list for `createWeapon`.
  - `serial` (string, optional): custom serial number for the weapon (`createWeapon`'s eighth argument).

Returns: `boolean` — `true` when the adapter reported success; `false` otherwise or when no inventory is active. Capacity is not checked first; call `InvCanCarry` yourself.

Gives an item to a player. w_inventory: `exports.w_inventory:AddItem == true`. vorp_inventory: `addItem` (callback awaited, must answer `true`) or `createWeapon` for `WEAPON_` names (any non-nil, non-false answer counts as success). rsg/qbr: `AddItem(src, item, count, false, meta, 'w_lib') == true`.

```lua
if exports.w_lib:InvCanCarry(source, 'gold_nugget', 2) then
    local ok = exports.w_lib:InvAddItem(source, 'gold_nugget', 2, { quality = 87 })
    if not ok then print('add failed') end
end
-- weapon on any inventory (metadata only matters on vorp)
exports.w_lib:InvAddItem(source, 'WEAPON_REVOLVER_CATTLEMAN', 1, { serial = 'WS-0001', ammo = {}, components = {} })
```

### exports.w_lib:InvRemoveItem

```lua
exports.w_lib:InvRemoveItem(src: number, item: string, count: number, meta?: table, slot?: number|string)
```

Side: server

Parameters:
- `src` (number, required): player server id.
- `item` (string, required): item name. `WEAPON_` names remove one weapon on vorp_inventory (`count` ignored).
- `count` (number, required): quantity to remove.
- `meta` (table, optional): metadata filter forwarded to w_inventory `RemoveItem` and vorp `subItem` (defaults to `{}` on vorp); ignored by rsg/qbr. For vorp weapons these fields choose which weapon:
  - `weaponId` (number, optional): vorp weapon id to remove; if given and no weapon has that id the call returns `false`.
  - `serial` (string, optional): `serial_number` to match; if given and nothing matches the call returns `false`.
  - `serial_number` (string, optional): same as `serial`.
  - When none of the above is given, the first weapon whose name matches (case-insensitive) is removed.
- `slot` (number | string, optional): slot to remove from. Honoured by w_inventory only; ignored by the other adapters.

Returns: `boolean` — `true` when the adapter reported success; `false` when nothing matched, the adapter failed, or no inventory is active.

Takes an item from a player. w_inventory: `RemoveItem(src, item, count, meta, slot)`. vorp_inventory: `subItem` (callback awaited), or `subWeapon(src, weaponId)` for `WEAPON_` names after locating the weapon by `weaponId`, serial or name. rsg/qbr: `RemoveItem(src, item, count, false, 'w_lib')` (metadata and slot ignored).

```lua
-- consume the item the marketplace listing came from
local ok = exports.w_lib:InvRemoveItem(source, entry.name, 1, entry.metadata, entry.slot)
if not ok then return end
```

### exports.w_lib:InvGetItems

```lua
exports.w_lib:InvGetItems(src: number)
```

Side: server

Parameters:
- `src` (number, required): player server id.

Returns: `table` — array of `{ slot, name, label, count, weight, metadata }` for every occupied slot; `{}` when empty, when the player is offline (rsg/qbr), or when no inventory is active. On vorp_inventory item slots are vorp item ids and weapons are appended with `slot = 'w' .. weaponId`, `count` 1, `weight` 0 and `metadata = { serial, weaponId, isWeapon = true, ammo, components }`. On rsg/qbr `metadata` is the item's `info` table and `count` is `amount`.

Reads the whole player inventory in one unified shape (w_inventory `GetInventory(src).items`; vorp `getUserInventoryItems` plus `getUserInventoryWeapons`; rsg/qbr `PlayerData.items`). The `slot` value returned here is what `InvGetSlot` and `InvRemoveItem` expect back.

```lua
local counts = {}
for _, entry in pairs(exports.w_lib:InvGetItems(source)) do
    counts[entry.name] = (counts[entry.name] or 0) + (tonumber(entry.count) or 0)
end
```

### exports.w_lib:InvGetSlot

```lua
exports.w_lib:InvGetSlot(src: number, slot: number|string)
```

Side: server

Parameters:
- `src` (number, required): player server id.
- `slot` (number | string, required): slot as returned by `InvGetItems` (a number for w_inventory/rsg/qbr, used as the `PlayerData.items` key on rsg/qbr; an item id or `'w<id>'` string for vorp, compared with `tostring`).

Returns: `table | nil` — `{ name, label, count, metadata }` (vorp returns the full `InvGetItems` entry including `slot` and `weight`); `nil` when the slot is empty, the player is offline, or no inventory is active.

Reads a single slot. w_inventory: `GetSlot(src, slot)`. rsg/qbr: `PlayerData.items[slot]`. vorp: linear search of `InvGetItems`.

```lua
local it = exports.w_lib:InvGetSlot(source, data.slot)
if not it or it.name ~= data.item then return end
```

### exports.w_lib:InvRegisterStash

```lua
exports.w_lib:InvRegisterStash(id: string, label?: string, slots?: number, maxWeight?: number)
```

Side: server

Parameters:
- `id` (string, required): stash id; converted with `tostring`. An empty string returns `false`. Use a stable, unique id such as `'horse_12'` or `'tribe_7'`.
- `label` (string, optional, default `id`): display name.
- `slots` (number, optional, default 50): slot count; passed through `tonumber`.
- `maxWeight` (number, optional, default 100000): maximum weight in the inventory's units; passed through `tonumber`.

Returns: `boolean` — `true` when registered with the active inventory (vorp and w_inventory always report `true`; rsg/qbr report `false` only when `CreateInventory` explicitly returned `false`); `false` when `id` is empty or no inventory is active. A `false` caused by no inventory running is not retried automatically: call again later. The definition (label, slots, max weight) is cached in memory regardless of the result.

Declares a shared stash with the active inventory. w_inventory: `RegisterStash(id, label, slots, maxWeight)`. vorp_inventory: `registerInventory{ id, name = label, limit = slots, acceptWeapons = true, shared = true, ignoreItemStackLimit = true, whitelistItems = false, UsePermissions = false, UseBlackList = false, whitelistWeapons = false }`. rsg/qbr: `CreateInventory(id, { label, slots, maxweight })`; the cached definition is also what `InvOpenStash` passes to `OpenInventory` on rsg/qbr. Safe to call repeatedly; the common idiom is to register right before opening. Not persisted across restarts (see `InvCreateStash` for that).

```lua
local stashId = ('horse_%d'):format(horse.id)
exports.w_lib:InvRegisterStash(stashId, horse.name, 10, 30000)
exports.w_lib:InvOpenStash(source, stashId)
```

### exports.w_lib:InvOpenStash

```lua
exports.w_lib:InvOpenStash(src: number, stashId: string)
```

Side: server

Parameters:
- `src` (number, required): server id of the player who should see the stash.
- `stashId` (string, required): id registered with `InvRegisterStash` (or `InvCreateStash`).

Returns: `boolean` — `true` when the open call was issued (w_inventory and vorp always `true`; rsg/qbr `true` when `OpenInventory` did not throw); `false` when no inventory is active.

Opens a stash UI for a player from the server. w_inventory: `forceOpenInventory(src, 'stash', stashId)`. vorp_inventory: `openInventory(src, stashId)`. rsg/qbr: `OpenInventory(src, stashId, config)` using the definition cached by `InvRegisterStash` (`{}` when never registered).

```lua
local opened = exports.w_lib:InvOpenStash(source, 'horse_' .. horse.id)
if not opened then return fail('saddlebag_unavailable') end
```

### exports.w_lib:InvAddItemToStash

```lua
exports.w_lib:InvAddItemToStash(stashId: string, item: string, count: number, meta?: table)
```

Side: server

Parameters:
- `stashId` (string, required): id previously passed to `InvRegisterStash`.
- `item` (string, required): item name.
- `count` (number, required): quantity.
- `meta` (table, optional): item metadata stored with the stack (forwarded verbatim to w_inventory `AddItem` and rsg/qbr `AddItem` `info`). On vorp_inventory the whole table (including `charid`) is stored as the item metadata and additionally:
  - `charid` (number, optional): character id vorp requires for `addItemsToCustomInventory`; `charId` is also accepted; default 1 when the caller has no player context (vorp rejects 0).

Returns: `boolean` — `true` on success, `false` otherwise or when no inventory is active. w_inventory: `AddItem` returned `true`. vorp: `addItemsToCustomInventory` answered something other than `nil`/`false` within 5 s. rsg/qbr: the `AddItem` call did not throw (its return value is not inspected).

Puts an item directly into a registered stash without a player. w_inventory: `AddItem(stashId, item, count, meta)`. vorp_inventory: `addItemsToCustomInventory(stashId, {{ name, amount, metadata }}, charid)`. rsg/qbr: `AddItem(stashId, item, count, false, meta, 'w_lib')`.

```lua
exports.w_lib:InvRegisterStash('tribe_7', 'Tribe chest', 60, 200000)
exports.w_lib:InvAddItemToStash('tribe_7', 'consumable_coffee', 5, { charid = charId })
```

### exports.w_lib:InvCreateStash

```lua
exports.w_lib:InvCreateStash(id: string, label?: string, slots?: number, maxWeight?: number)
```

Side: server

Parameters:
- `id` (string, required): stash id (`tostring`); an empty string returns `false`. Existing catalogue rows with the same id are updated (`ON DUPLICATE KEY UPDATE`).
- `label` (string, optional, default `id`): display name (`tostring`).
- `slots` (number, optional, default 50): slot count; floored, minimum 1.
- `maxWeight` (number, optional, default 100000): maximum weight; floored, minimum 1.

Returns: `boolean` — `true` only when the row was written to `w_lib_stashes` and `InvRegisterStash` returned `true` with the active inventory; `false` when the id is empty, the SQL failed (including when the catalogue table could not be created at boot), or no inventory is running.

Creates a persistent, library-managed stash: upserts into the table `w_lib_stashes` (`id varchar(100)`, `label varchar(150)`, `slots`, `max_weight`; created by the library on boot) and registers it with the active inventory through `InvRegisterStash`. Managed stashes are re-registered automatically at every server start once an inventory is detected, so unlike `InvRegisterStash` the definition survives restarts, and they appear in `InvListStashes`. Blocks until the catalogue table setup thread has finished.

```lua
local ok = exports.w_lib:InvCreateStash('town_bank_vault', 'Bank vault', 200, 500000)
if ok then exports.w_lib:InvOpenStash(source, 'town_bank_vault') end
```

### Client exports: InvName, InvItemLabel, InvClose

Side: client

| Export | Signature | Returns | Description |
|---|---|---|---|
| `InvName` | `exports.w_lib:InvName()` | `string \| nil` — `'w_inventory'`, `'rsg-inventory'`, `'qbr-inventory'`, `'vorp_inventory'`, or `nil` when none is started | Client counterpart of the server `InvName`. Resolution order: (1) replicated convar `w_lib:activeInventory` (normalised through the same aliases) if that resource is started; (2) `w_inventory` if started; (3) the previously detected name if still started; (4) convar `w_lib:inventory` (must be `setr`) if that resource is started; (5) the first started of `w_inventory`, `rsg-inventory`, `qbr-inventory`, `vorp_inventory`. |
| `InvItemLabel` | `exports.w_lib:InvItemLabel(item: string)` | `string` — the display label from w_inventory's item definitions when the active inventory is w_inventory and the item is known; otherwise the item name itself; `'Unknown'` when `item` is `nil` or `false` | Display label lookup for UI. Only w_inventory is queried (`exports.w_inventory:Items(item).label`); other inventories fall back to the raw name, so keep your own label table if you need labels on vorp/rsg/qbr. |
| `InvClose` | `exports.w_lib:InvClose()` | `nil` | Closes the player's inventory UI on whichever inventory is active: the w_inventory `closeInventory` export, or the local client events `vorp_inventory:closeInventory`, `rsg-inventory:client:closeinv`, `qbr-inventory:client:closeinv` (each wrapped in `pcall`). Does nothing when no inventory is detected. Use it before opening your own NUI so focus and scroll are released. |

Parameters:
- `InvItemLabel`: `item` (string, required) — item name.
- `InvName` and `InvClose` take no parameters.

```lua
local inv = exports.w_lib:InvName()
if inv ~= 'w_inventory' then
    -- saddlebag is opened server-side through InvOpenStash on other inventories
end

local label = exports.w_lib:InvItemLabel('consumable_coffee')
lib.notify({ description = ('Received %s'):format(label) })

exports.w_lib:InvClose()
lib.showContext('myres_menu')
```

### exports.w_lib:InvListStashes

```lua
exports.w_lib:InvListStashes()
```

Side: server

Parameters: none.

Returns: `table` — array sorted by name of `{ id: string, name: string, owner: string ('' when shared), kind: 'house'|'tribe'|'vehicle'|'horse'|'shop'|'player'|'custom', source: 'stash'|'vehicle:inventory'|'vehicle:trunk'|'vehicle:glovebox', storageType?: 'inventory'|'trunk'|'glovebox', vehicleType?: string }`. Duplicates (same source, id and owner) are collapsed. Pass `id`, `owner` and `source` back to `InvGetStashContents` and the `InvStash*` exports.

Enumerates every known stash for admin tooling. Sources by active inventory: w_inventory reads rows of the table `w_inventory` (`owner`, `name`) plus `GetRegisteredStashes` (skipping entries whose owner is `true`, i.e. per-player templates); vorp_inventory reads distinct `character_inventories.inventory_type` and `loadout.curr_inv` (not `'default'`), labelled via `getCustomInventoryData` when available; rsg/qbr read `stashitems.stash` or, failing that, `inventories.identifier`. The `w_lib_stashes` catalogue is always added. When the framework's horse table (`horses` for qbr, `player_horses` for rsgcore, else `stables`) has an `id` column plus `inventory`, `trunk` or `glovebox` columns, one entry is added per column and row with id `'<column>-<rowid>'`, `owner` = row id, name `'<row name> (#id)'` or `'#id'`, kind `'vehicle'` when the row's `type` contains wagon, cart or vehicle, otherwise `'horse'` for the `inventory` column and `'vehicle'` for `trunk`/`glovebox`. For stash entries the kind is guessed from words in the id: propert, house, home, motel, apartment give `house`; tribe, gang, faction, camp give `tribe`; trunk, glove, vehicle, wagon, cart give `vehicle`; horse, stable, mount, saddle give `horse`; shop, store, market give `shop`; `player` when an owner is set; otherwise `custom`. Runs SQL synchronously, so call it from a thread or callback. Returns `{}` with no inventory active, except for catalogue and vehicle rows.

```lua
lib.callback.register('myadmin:getStashes', function(source)
    return exports.w_lib:InvListStashes() or {}
end)
```

### exports.w_lib:InvGetStashContents

```lua
exports.w_lib:InvGetStashContents(name: string, owner?: string, source?: string)
```

Side: server

Parameters:
- `name` (string, required): stash id (the `id` field from `InvListStashes`). For vehicle sources the trailing digits of `name` are used as the row id when `owner` is not numeric.
- `owner` (string, optional): owner identifier for owner-scoped w_inventory stashes (`''` or `nil` for shared). For vehicle sources: the numeric row id. Ignored on vorp/rsg/qbr stashes.
- `source` (string, optional, default `'stash'`): `'stash'` (any value that is not a vehicle source is treated as stash) or `'vehicle:inventory'` / `'vehicle:trunk'` / `'vehicle:glovebox'` (the bare column name `'inventory'`, `'trunk'` or `'glovebox'` is also accepted).

Returns: `table` — array sorted by slot of `{ slot, name, item, label, count, amount, metadata, isWeapon }`; `{}` when the stash is unknown, the vehicle table, column or row id cannot be resolved, or no inventory is active. vorp weapons come back with slot `'w<weaponId>'` and `metadata = { isWeapon = true, weaponId, serial, components }`.

Reads a stash's items in the unified shape. w_inventory: `GetInventoryItems(name, owner)` with fallback to the `w_inventory` table's `data` column; vorp: `getCustomInventoryItems` plus `getCustomInventoryWeapons`; rsg/qbr: `GetInventory(name)` with fallback to `stashitems.items` or `inventories.items`. Vehicle sources: when the active inventory is w_inventory, the column is `trunk` or `glovebox` and w_inventory reports that storage as loaded, the live inventory is read; otherwise (and always for the `inventory` column) the JSON column of the row is decoded.

```lua
local items = exports.w_lib:InvGetStashContents(data.name, data.owner or '', data.source or 'stash')
for _, it in ipairs(items) do print(it.slot, it.name, it.count) end
```

### exports.w_lib:InvStashAddItem

```lua
exports.w_lib:InvStashAddItem(name: string, owner?: string, item: string, count?: number, metadata?: table, source?: string)
```

Side: server

Parameters:
- `name` (string, required): stash id (or vehicle row reference for vehicle sources; trailing digits are the row id when `owner` is not numeric).
- `owner` (string, optional): owner identifier for owner-scoped w_inventory stashes (`''` or `nil` for shared); vehicle row id for vehicle sources; on vorp used as the character id when `metadata` has no `charid`/`charId`.
- `item` (string, required): item name; `WEAPON_` names on vorp go through `addWeaponsToCustomInventory`.
- `count` (number, optional, default 1): quantity; floored and clamped to at least 1.
- `metadata` (table, optional): item metadata (a non-table becomes `{}`). Extra fields read on vorp:
  - `charid` / `charId` (number, optional): character id for the custom inventory call; falls back to `tonumber(owner)`, then 1.
  - `serial` / `serial_number` (string, optional): weapon `serial_number`.
  - `components` (table, optional, default `{}`): weapon components.
  - `label` (string, optional): weapon `custom_label`.
  - `description` (string, optional): weapon `custom_desc`.
- `source` (string, optional, default `'stash'`): `'stash'` or a vehicle source as in `InvGetStashContents`.

Returns: `boolean` — `true` when the item was stored; `false` when no inventory is active, the vehicle row or column cannot be resolved, or every adapter path failed.

Administrative add into any stash, creating it if needed. w_inventory: `GetInventory(name, owner)`; if missing, `RegisterStash` on the fly (catalogue label, slots and max weight if known, else 100 slots and 1000000 weight, owner-scoped when `owner` is set), then `AddItem(inventory.id, item, count, metadata)`. vorp: `registerInventory{ limit = 100, shared, acceptWeapons }` if `isCustomInventoryRegistered` is `false`, then `addItemsToCustomInventory` or `addWeaponsToCustomInventory`. rsg/qbr: `AddItem(name, item, count, false, metadata, 'w_lib:stashadmin')`, falling back to editing `stashitems.items` (or `inventories.items`) JSON directly: it stacks onto the first existing stack with the same name when both the new and the stored metadata are empty, otherwise appends a new slot (highest slot + 1) using `amount`/`info` fields, and inserts the row when absent. Vehicle sources: the live w_inventory trunk/glovebox inventory when loaded, else the JSON column (`count`/`metadata` fields; fails when the row does not exist).

```lua
local ok = exports.w_lib:InvStashAddItem('tribe_7', '', 'consumable_coffee', 5, {}, 'stash')
local ok2 = exports.w_lib:InvStashAddItem('trunk-12', '12', 'bread', 2, {}, 'vehicle:trunk')
```

### exports.w_lib:InvStashRemoveItem

```lua
exports.w_lib:InvStashRemoveItem(name: string, owner?: string, item: string, count?: number, slot?: number|string, source?: string)
```

Side: server

Parameters:
- `name` (string, required): stash id (or vehicle row reference).
- `owner` (string, optional): owner identifier for owner-scoped w_inventory stashes (`''` or `nil` for shared); vehicle row id for vehicle sources.
- `item` (string, required): item name.
- `count` (number, optional, default 1): quantity; floored and clamped to at least 1.
- `slot` (number | string, optional): slot from `InvGetStashContents` (numeric strings are converted with `tonumber`). On vorp a slot starting with `'w'` removes that weapon by id (`count` and `item` ignored). In the rsg/qbr and vehicle JSON fallbacks the slot, if given, selects the stack, otherwise the first stack with that name; removal fails if the selected stack holds fewer than `count`.
- `source` (string, optional, default `'stash'`): `'stash'` or a vehicle source.

Returns: `boolean` — `true` when removed; `false` otherwise or when no inventory is active.

Administrative remove from any stash. w_inventory: `RemoveItem(inventoryId, item, count, nil, slot)` after ensuring the stash exists (same on-the-fly registration as `InvStashAddItem`). vorp: `removeCustomInventoryWeaponById(name, id)` for `'w<id>'` slots, else `removeItemFromCustomInventory(name, item, count, slot)`. rsg/qbr: `RemoveItem(name, item, count, tonumber(slot) or false, 'w_lib:stashadmin')` with direct JSON fallback. Vehicle sources: the live w_inventory trunk/glovebox inventory when loaded, else the JSON column.

```lua
local ok = exports.w_lib:InvStashRemoveItem('tribe_7', '', 'consumable_coffee', 1, data.slot, 'stash')
```

### exports.w_lib:DbReady

```lua
exports.w_lib:DbReady(timeoutMs?: number)
```

Side: server

Parameters:
- `timeoutMs` (number, optional, default 0): how long to wait for the database, in ms; floored and clamped to 0..60000. 0 returns immediately.

Returns: `true, nil` when the database is ready; `false, error` otherwise, where `error = { operation = 'ready', code = 'connection_failed' | 'healthcheck_failed' | 'timeout', message = string }`.

Blocks (polling every 25 ms) until the library's oxmysql connection has passed `MySQL.ready` and a `SELECT 1` health check, or until the timeout. If the connection or health check failed at boot the failure is permanent and is returned immediately. Call it once during your startup before the first query.

```lua
CreateThread(function()
    local ok, err = exports.w_lib:DbReady(30000)
    if not ok then return print('database unavailable: ' .. err.code .. ' ' .. err.message) end
    -- safe to query now
end)
```

### exports.w_lib:DbQuery

```lua
exports.w_lib:DbQuery(sql: string, parameters?: table)
```

Side: server

Parameters:
- `sql` (string, required): SQL text with `?` placeholders (or oxmysql named placeholders). Must be a non-empty string, at most 1 MiB, without NUL bytes; surrounding whitespace is trimmed.
- `parameters` (table, optional, default `{}`): array (for `?`) or keyed table (for named placeholders) of values. Allowed values: finite numbers, strings, booleans, `nil`, nested tables up to 8 levels and 10000 entries with string or number keys, no cycles.

Returns: `rows, nil` on success, where `rows` is whatever `MySQL.query.await` returns (an array of row tables, possibly empty); `nil, error` on failure with `error = { operation, code, message }` where `code` is `'invalid_query'`, `'query_too_large'`, `'invalid_parameters'`, `'not_ready'` or `'query_failed'` (`operation = 'query'`), or the stored boot failure `'connection_failed'` / `'healthcheck_failed'` (`operation = 'ready'`).

Synchronous SELECT (`MySQL.query.await`). Validation runs before the readiness check. Parameters are never interpolated. `query_failed` errors are also logged to the console with the calling resource's name. Call from a thread or handler.

```lua
local rows, err = exports.w_lib:DbQuery('SELECT id, name FROM stables WHERE identifier = ?', { identifier })
if err then return print(err.message) end
for _, row in ipairs(rows) do print(row.id, row.name) end
```

### exports.w_lib:DbSingle, DbScalar, DbInsert, DbUpdate

```lua
exports.w_lib:DbSingle(sql: string, parameters?: table)
exports.w_lib:DbScalar(sql: string, parameters?: table)
exports.w_lib:DbInsert(sql: string, parameters?: table)
exports.w_lib:DbUpdate(sql: string, parameters?: table)
```

Side: server

Parameters (identical for all four):
- `sql` (string, required): SQL text; same validation as `DbQuery`. `DbInsert` expects an INSERT statement; `DbUpdate` expects an UPDATE or DELETE statement.
- `parameters` (table, optional, default `{}`): same rules as `DbQuery`.

Returns: on failure every one of them returns `nil, error` with the same error shape and codes as `DbQuery`, with `operation` set to `'single'`, `'scalar'`, `'insert'` or `'update'` (or `'ready'` for the stored boot failure). On success:

| Export | Driver call | Success return |
|---|---|---|
| `DbSingle` | `MySQL.single.await` | `row, nil` — the first result row as a table, or `nil` when nothing matched. Because a miss also yields `nil`, always check the second value to tell "no row" from "failed". |
| `DbScalar` | `MySQL.scalar.await` | `value, nil` — the first column of the first row (`nil` when no row). Intended for `COUNT(*)`, `MAX()` and single-column lookups. |
| `DbInsert` | `MySQL.insert.await` | `insertId, nil` — the auto-increment id oxmysql reports. |
| `DbUpdate` | `MySQL.update.await` | `affectedRows, nil`. |

```lua
local horse, err = exports.w_lib:DbSingle('SELECT * FROM stables WHERE id = ? LIMIT 1', { id })
if err then return false end
if not horse then return print('no such horse') end

local total, err2 = exports.w_lib:DbScalar('SELECT COUNT(*) FROM stables WHERE identifier = ?', { identifier })
local count = tonumber(total) or 0

local logId, err3 = exports.w_lib:DbInsert('INSERT INTO myres_logs (identifier, action) VALUES (?, ?)', { identifier, 'sold' })
if err3 then return end

local affected, err4 = exports.w_lib:DbUpdate('UPDATE stables SET name = ? WHERE id = ?', { newName, id })
if err4 or (affected or 0) == 0 then return false end
```

### exports.w_lib:DbTransaction

```lua
exports.w_lib:DbTransaction(queries: table, sharedParameters?: table)
```

Side: server

Parameters:
- `queries` (table, required): array of 1 to 256 entries. Each entry is either a SQL string or a table:
  - `query` (string, required): SQL text, validated like `DbQuery`.
  - `values` (table, optional): parameters for this query; `parameters` is accepted as an alias; validated like `DbQuery`.
- `sharedParameters` (table, optional, default `{}`): parameters applied to plain-string queries (oxmysql transaction semantics); validated like `DbQuery`.

Returns: `true, nil` when the transaction committed; `false, error` otherwise with `error = { operation, code, message, index? }` where `code` is `'invalid_queries'`, `'invalid_query'`, `'query_too_large'`, `'invalid_parameters'`, `'not_ready'`, `'transaction_failed'` or `'transaction_rolled_back'` (`operation = 'transaction'`), or the stored boot failure `'connection_failed'` / `'healthcheck_failed'` (`operation = 'ready'`). `index` is the 1-based index of the offending entry for per-entry validation errors (absent for `sharedParameters` errors).

Runs several statements atomically through `MySQL.transaction.await`; a driver result other than `true` is reported as `transaction_rolled_back`. Validation of every entry and of `sharedParameters` happens before anything is sent, so a bad entry fails the whole call without touching the database. `transaction_failed` and `transaction_rolled_back` are also logged to the console.

```lua
local ok, err = exports.w_lib:DbTransaction({
    { query = 'UPDATE characters SET money = money - ? WHERE charidentifier = ?', values = { price, buyer } },
    { query = 'UPDATE stables SET identifier = ?, charid = ? WHERE id = ?', values = { buyerIdentifier, buyer, horseId } },
})
if not ok then print(('transfer failed at %s: %s'):format(tostring(err.index), err.message)) end
```

### Events

No events are exposed by this subsystem.

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:inventory` | shared (set with `setr` in server.cfg) | `"auto"` (default), `"w_inventory"`, `"vorp_inventory"`, `"rsg-inventory"`, `"qbr-inventory"`; aliases `w`, `ox`, `vorp`, `rsg`, `qbr` | Optional manual pin of the inventory adapter, read by the server during adapter selection and by the client as a fallback (use `setr` so the client sees it). Ignored whenever `w_inventory` is started, since w_inventory always wins. The value is lowercased and whitespace-stripped. Any other value prints `[w_lib] invalid w_lib:inventory value: <value>` once in red and disables every `Inv*` export until fixed; a valid value whose resource is not started prints a yellow "configured inventory is not started yet" warning once and waits. With `auto` the first started of `w_inventory`, `rsg-inventory`, `qbr-inventory`, `vorp_inventory` is used. Example: `setr w_lib:inventory "vorp_inventory"`. |
| `w_lib:activeInventory` | shared (replicated, written by the library) | `string` — the adapter name chosen by the server, empty before detection | Set by the library with `SetConvarReplicated` as soon as the server picks an adapter. Do not set it yourself; read it on the client with `GetConvar('w_lib:activeInventory', '')` (or call the client `InvName` export, which does this for you) to know which inventory the server is using. |

### Commands

No commands are exposed by this subsystem.

## The w.framework module (framework and inventory abstraction used inside consumer resources)

`w.framework` is the module a consumer resource uses to talk to whatever core and inventory happen to be running, without naming any of them. Supported cores are VORP, RedEM:RP (old and 2023), RSG (v1 and v2), QBR, QR, RPX, TPZ and FRP; supported inventories are vorp_inventory v1 and v2, redemrp (old and 2023), rsg (v1 and v2), qbr, qr, rpx, tpz, gm and w_inventory.

### Loading

The module is loaded like every other module of the library: add `'@w_lib/init.lua'` to `shared_scripts`, then either declare it in the manifest with `w_module { 'framework' }`, call `w.require("framework")`, or simply touch `w.framework` (the `w` table lazy-loads a module on first access). `"framework"` is an alias for the folder `"framework-bridge"`, so `w.require("framework-bridge")` is the same thing. After loading, `w.fw` is a shortcut for `w.framework`, and `jo.framework` is the same table (`_ENV.jo = w`).

The module's `shared.lua`, `client.lua` and `server.lua` (and the matching `cores/<core>/` and `inventories/<inventory>/` adapter files) execute inside each consumer resource, so `w.framework` methods run in your own context: callbacks such as `onCharacterSelected`, `listenItemRemoved` and `registerUseItem` accept real Lua functions. The `g_shared` / `g_client` / `g_server` files run once inside the library itself; they are executed the first time any consumer resource loads the module (the consumer's loader calls `exports.w_lib:loadGlobalModule("framework")`; the library's own manifest only auto-loads version-checker and i18n). They register the shared net events (`w_lib:client:applySkin*`, `w_lib:server:applySkin*`) and the export `w_framework_getInventoryItems`.

Anything you call as `exports.w_lib:<Name>()` crosses the export boundary: pass plain data (numbers, strings, tables). The library's convention for callbacks across that boundary is an event name that you register with `RegisterNetEvent` / `AddEventHandler`. The single documented exception is `exports.w_lib:InvRegisterUsableItem`, which accepts a function reference and calls it from the inventory bridge; `w.framework:registerUseItem` relies on it.

### Detection

Detection happens when the module loads (`shared.lua` runs `detectCores()` and `detectInventories()` immediately). Every core and inventory entry in the detector tables has an id, a display name, an adapter folder and a `matchResources` list. Each match string is a resource name, optionally prefixed with `!` (that resource must not be starting or started) and optionally followed by a comparator on a manifest field: `rsg-core<2.0.0` compares the resource's `version` metadata, `vorp_inventory:vorp_github==https://github.com/VORPCORE/vorp_inventory-lua` compares the named metadata field (comparators: `<`, `<=`, `==`, `=`, `>=`, `>`). A positive match requires the resource state to be `starting` or `started`. The loader then waits (1 s polling, printing `Waiting start of <resource>`) until every positively matched resource is `started`, so put the library and the core before your resource in the start order.

Cores detected (id / name / adapter folder / match):

| id | name | folder | match |
|---|---|---|---|
| vorp | VORP Core | vorp_core | vorp_core |
| redemrp_old | RedEM:RP Old Core | redemrp_old | redem |
| redemrp_2023 | RedEM:RP 2023 Core | redemrp_2023 | !redem + redem_roleplay |
| qbr | QBCore RedM Edition | qbr_core | qbr-core |
| rsg | RSG V1 Core | rsg-core | rsg-core<2.0.0 |
| rsg_v2 | RSG V2 Core | rsg-core_v2 | rsg-core>=2.0.0 |
| qr | QRCore Core | qr-core | qr-core |
| rpx | RPX Core | rpx-core | rpx-core |
| tpz | TPZ-CORE | tpz_core | tpz_core |
| frp | FRP Core | frp_core | frp_core |

Inventories detected:

| id | name | folder | match |
|---|---|---|---|
| vorp | VORP Inventory | vorp_inventory_v1 | vorp_core + !w_inventory + vorp_inventory:vorp_github==https://github.com/VORPCORE/vorp_inventory-lua |
| vorp_v2 | VORP Inventory V2 | vorp_inventory_v2 | vorp_core + !w_inventory + vorp_inventory:vorp_github==https://github.com/VORPCORE/vorp_inventory-v2 |
| redemrp | RedEM:RP Inventory | redemrp_inventory_old | redem |
| redemrp_2023 | RedEM:RP Inventory 2023 | redemrp_inventory_2023 | !redem + redem_roleplay |
| qbr | QBCore Inventory | qbr-inventory | qbr-core + !w_inventory + qbr-inventory |
| rsg | RSG Inventory | rsg-inventory | rsg-core + !w_inventory + rsg-inventory<2.0.0 |
| rsg_v2 | RSG Inventory V2 | rsg-inventory_v2 | rsg-core + !w_inventory + rsg-inventory>=2.0.0 |
| qr | QRCore Inventory | qr-inventory | qr-core + !w_inventory + qr-inventory |
| rpx | RPX Inventory | rpx-inventory | rpx-inventory |
| tpz | TPZ-CORE Inventory | tpz_inventory | tpz_inventory |
| ox | w_inventory | w_inventory | w_inventory |
| gm | GM Inventory | gm_inventory | gm_inventory |

When no core is found an error is printed, `getFrameworkDetected()` returns `false`, and `w.framework:get()` / `:is()` then raise a Lua error (`attempt to index a boolean`) because `get()` reads `getFrameworkDetected().id` without a guard. More than one core or inventory prints a warning and the first match wins. No inventory found is not an error (only the `inventories/_custom` files are loaded in that case). `w.framework:get()` returns the core id in lower case (`"vorp"`, `"rsg_v2"`, ...) and `w.framework:is(name)` compares case-insensitively.

### Loading order and the _custom override layer

For each of `shared` / `client` / `server` (and `g_*` inside the library) the module loads `cores/<detected folder>/<file>.lua` for every detected core, then `cores/_custom/<file>.lua`; the same for `inventories/<detected>/` then `inventories/_custom/`. The folders `cores/_default` and `inventories/_default` exist in the source tree but nothing loads them (the loader only iterates detected folders plus `_custom`); treat them as reference material only. Consequences:

- Every `UserClass` method, `createUser` and the skin/clothes internals exist only if the detected core adapter defines them (VORP defines all of them).
- `removeInventory` and `getItemsFromInventory` exist only if the detected inventory adapter defines them (nil otherwise, so calling them errors).
- The `event_item_removed` and `inventory:OnItemRemoved` bridge handlers found in the `_default` files are never registered.

Because `_custom` is loaded last it can overwrite any `w.framework` or `w.framework.UserClass` method. `cores/_custom/FrameworkClass.lua` and `UserClass.lua` are placeholders (comment only, never loaded either, since the loader loads only the shared/client/server/g_* stems); `cores/_custom/{client,server}.lua` run in every consumer resource (empty in this build); `cores/_custom/{g_client,g_server}.lua` run once inside the library (empty); `cores/_custom/g_shared.lua` plus `inventories/_custom/{server,g_server,g_shared}.lua` carry real code. These files are part of the library and are replaced when the library is updated.

In this build, `inventories/_custom/server.lua` redefines `canUseItem`, `getItemCount`, `registerUseItem`, `giveItem`, `createInventory`, `openInventory` and `addItemInInventory` so they delegate to the library's lazy inventory bridge exports (`exports.w_lib:InvGetItemCount` / `InvRemoveItem` / `InvRegisterUsableItem` / `InvCanCarry` / `InvAddItem` / `InvRegisterStash` / `InvOpenStash` / `InvAddItemToStash`). That bridge resolves the running inventory at call time: w_inventory wins whenever it is started; otherwise the server convar `w_lib:inventory` (default `"auto"`) forces one of w_inventory / vorp_inventory / rsg-inventory / qbr-inventory; otherwise the first started in the order w_inventory, rsg-inventory, qbr-inventory, vorp_inventory. The chosen name is replicated in the convar `w_lib:activeInventory`. Only `removeInventory` and `getItemsFromInventory` still come from the detected inventory adapter (on w_inventory: `exports.w_inventory:RemoveInventory` / `GetInventoryItems`). `inventories/_custom/g_shared.lua` (loaded after `cores/_custom/g_shared.lua`, so it wins) redefines `w.framework:getInventoryItems()` to build the item catalogue from `exports.w_inventory:Items()` when w_inventory is started, falling back to the detected adapter's catalogue, else `{}`.

`w.framework.core` holds the raw core object on the server (on VORP: `exports.vorp_core:GetCore()`; an empty table on the client and for adapters that do not set it) and `w.framework.inv` holds the raw inventory API for adapters that set it (vorp v1/v2, redemrp old/2023, rpx, rsg v2, tpz, gm; empty table on w_inventory). Use them only when you have already checked `w.framework:is("vorp")` or similar.

### Server/client split

Everything about money, jobs, identifiers, items, skins and clothes is server-side. `w.framework:getUser(source)` returns a `w.framework.UserClass` instance (there is no `UserClass.new`; use `UserClass:get(source)` or `w.framework:getUser`). On VORP `UserClass:get` returns `false` with an error print when `Core.getUser(source)` is nil, so check the result before calling methods; the shortcut methods (`getJob`, `getRPName`, `canUserBuy`, `addMoney`, `removeMoney`) do not check and raise an error for a player without a character. Also on VORP the instance stores its data on the shared class table (`self.source` / `self.data` are written to `w.framework.UserClass` and the returned object only proxies to it), so fetch a fresh user right before use and never keep one across a `Wait`.

Money types are integers: 0 = dollars/cash, 1 = gold, 2 = rol; `canUserBuy` also accepts the strings `"gold"` and `"rol"`. Prices given to `canUserPayWith` / `refundUserWith` go through `w.pricing.get` (alias of `w.pricing.getCosts`) and accept: a number (dollars), one Cost table (`{money=n}` | `{gold=n}` | `{rol=n}` | `{item="name", quantity=n, keep=bool}`), an array of Costs, or a PriceClass. A Cost may hold only one type or `w.pricing` raises an error (caught and reported as `false`). Normalisation keeps only item/quantity/keep for item costs (any `meta` field is dropped, so metadata cannot be matched through these two functions) and merges the item catalogue fields (label, image, ...) into item costs. `keep=true` means the item is required but neither removed nor refunded.

The client side of the module only offers `w.framework:getMyIdentifiers()` (which calls a server callback that the same resource's server-side copy of the module registers, so load the framework module on both sides of your resource), the shared item-catalogue helpers (`getItems`, `getItemData`, `addItemDataToPrice`, `inventoryItems`) and `getFrameworkDetected()`. `w.framework:get()`, `:is()` and every `UserClass` method do not exist on the client.

### Character lifecycle and inventory listeners

`w.framework:onCharacterSelected(cb)` fires `cb(source, isNew)` whenever the core reports a character selection (VORP: the net event `vorp_CharSelectedCharacter` gives `isNew=false`; the server-side `vorp_NewCharacter` event gives `isNew=true`; the handler ignores `vorp_NewCharacter` if a client triggers it or the player has no VORP user). Because the module runs in your resource, each consumer resource gets its own callback list. The library also uses it to maintain the identifier-to-source map read by `getSourceFromIdentifiers`.

`w.framework:listenItemRemoved([item,] cb)` reacts to the local server event `w_lib:inventory:listenerItemRemoved` (`source, item, {quantity, metadata}, reason`); the callback receives `(source, item, data)`, not `(source, quantity, meta, reason)` as the annotation says. That event is emitted inside the library only by the vorp v1/v2 adapters (from VORP's net event `vorp_inventory:Server:OnItemRemoved`) and the rsg v2 adapter (from `rsg-inventory:server:itemRemovedFromPlayerInventory`). On w_inventory nothing emits it, so treat `listenItemRemoved` as inactive there unless you `TriggerEvent` it yourself.

### Skins and clothes (VORP adapter)

`getUserSkin` / `getUserClothes` return the character's appearance converted to the library's standard keys. Skin: `model`, `headHash`, `bodyUpperHash`, `bodyLowerHash`, `eyesHash`, `teethHash`, `hair`, `beards_*`, `hair_bonnet`, `bodyType`, `bodyWeight`, `bodyScale`, `expressions.<name>` as -1..1 decimals, `overlays.<layer> = {id, opacity, tint0, tint1, tint2, palette, sheetGrid, sexe}`. Clothes: one entry per standard category (accessories, armor, badges, beards_complete, belts, boots, hair_accessories, jewelry_bracelets, chaps, belt_buckles, cloaks, coats, coats_closed, dresses, eyewear, gauntlets, gloves, gunbelts, gunbelt_accs, hair, hats, holsters_left, loadouts, masks, neckties, neckwear, pants, ponchos, jewelry_rings_left, jewelry_rings_right, satchels, shirts_full, skirts, spats, boot_accessories, suspenders, teeth, vests) with value `{hash, palette, tint0, tint1, tint2, drawable, wearableState, state}`; numeric values are normalised to `{hash=n}`, entries whose hash is 0/-1/1/nil are dropped, and palette 0/nil clears the tints. `updateUserSkin` / `updateUserClothes` take standard data and convert it back to the core format before saving.

The client net events `w_lib:client:applySkin` / `applyClothes` / `applySkinAndClothes` apply standard data to a ped (they need the library's `component` module, are debounced 100 ms per ped, and run the hooks `w_lib:applySkin:before`, `w_lib:applyClothes:before/after` and `w_lib:applySkinAndClothes:before/after` through `w.hook.doActions`). The server net events `w_lib:server:applySkin` / `applyClothes` / `applySkinAndClothes` are for a client to send core-format (or JSON string) data to be standardised and echoed back to itself; on VORP `applySkin` and `applySkinAndClothes` are ignored once the player has a selected character because the library already re-applies the skin on VORP's `vorpcharacter:reloadedskinlistener`.

### The exports.w_lib:Fw* layer

The `exports.w_lib:Fw*` layer (`resource/fwbridge`) is a second, export-based bridge that wraps the raw core directly (VORP, RSG Core, and QBR reported as `"qbr"` but handled like RSG). It is what most sibling resources use for identity, money, jobs and offline database edits; every `Fw*` function takes and returns plain data and works from any resource without loading the module. `FwName` / `FwReady` / `FwInventory` / `FwGetCore` exist on both sides, `FwGetPlayerData` on the client only, everything else on the server. Item operations in that layer route through the same `Inv*` inventory bridge (`resource/invbridge`) as the `_custom` `w.framework` adapter, so both surfaces stay consistent about which inventory is active. The `Inv*` exports are documented below because the `w.framework` item methods are defined in terms of them.

### w.framework (module table and fields)

```lua
w.framework          -- also w.fw, jo.framework
w.framework.core     : table
w.framework.inv      : table
w.framework.inventoryItems : table<string, ItemData>
```

Side: shared

Parameters: none

Returns: the module table

The module table, loaded lazily on first access of `w.framework`, by `w.require("framework")` (alias of `"framework-bridge"`), or by `w_module { 'framework' }` in `fxmanifest.lua`. After load, `w.fw` is the same table. Fields:

| field | side | value |
|---|---|---|
| `core` | shared | Raw core object, set by the core adapter on the server (VORP: `exports.vorp_core:GetCore()`). Empty table `{}` on the client and when the adapter does not set it. Only use after a `w.framework:is("vorp")` style check. |
| `inv` | shared | Raw inventory API object set by some server inventory adapters (vorp v1/v2, redemrp old/2023, rpx, rsg v2, tpz, gm). Empty table on w_inventory, on undetected inventories and on the client. |
| `inventoryItems` | shared | Item catalogue keyed by item name. In a consumer resource it is filled after `w.ready` (library loaded + 1 s) by calling `exports.w_lib:w_framework_getInventoryItems()`, retried up to 60 times every 500 ms while the result is empty. Each entry built from w_inventory is `{ item, label, type = "item_standard" or "item_weapon", description, image = "nui://w_inventory/web/images/<file>" or an absolute URL }`; other adapters produce their own shape with at least `item` and `label`. Prefer `getItems()` / `getItemData()`, which refresh the table when it is empty. |
| `UserClass` | server | Class of per-player objects, see below. |

```lua
w_module { 'framework' } -- in fxmanifest.lua
-- then anywhere:
local core = w.framework:getFrameworkDetected()
if core then print(core.name) end

if w.framework:is("vorp") then
  local user = w.framework.core.getUser(source)
end
```

### w.framework:getFrameworkDetected

```lua
w.framework:getFrameworkDetected()
```

Side: shared

Parameters: none

Returns: `table|false` - `{ id: string, name: string, folder: string, matchResources: string[] }` of the first detected core, or `false` when none

Returns the detector entry for the active core (see the detection tables). Detection runs once at module load; the result is cached. Available on both sides (`w.framework:get()` only exists on the server). This is the safe way to test for a core: `get()` / `is()` raise an error when nothing is detected.

```lua
local core = w.framework:getFrameworkDetected()
if core then print(core.id, core.name) end
```

### w.framework:get and w.framework:is

```lua
w.framework:get()
w.framework:is(name: string)
```

Side: server

Parameters:
- `name` (string, required, `is` only): core id to compare with, case-insensitive: vorp, redemrp_old, redemrp_2023, qbr, rsg, rsg_v2, qr, rpx, tpz, frp

Returns: `get` returns the core id in lower case (`"vorp"`, `"redemrp_old"`, `"redemrp_2023"`, `"qbr"`, `"rsg"`, `"rsg_v2"`, `"qr"`, `"rpx"`, `"tpz"` or `"frp"`); `is` returns a boolean

`get` returns the id of the detected core (the annotation mentions `"VORP"` / `"RedEM"` style names, but the code returns the detector id). `is` is true when the detected core id equals `name` (case-insensitive). When no core was detected both raise a Lua error (`getFrameworkDetected()` returns `false` and `.id` is indexed on it); use `getFrameworkDetected()` to test safely.

```lua
print("core:", w.framework:get())
if w.framework:is("vorp") then
  -- VORP specific branch
end
```

### w.framework:getUser

```lua
w.framework:getUser(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id

Returns: `UserClass|false` - a `w.framework.UserClass` instance, or `false` (with an error print) when `source` is not numeric or the core has no user for that source

Shortcut for `w.framework.UserClass:get(source)`. Always test the result: on VORP it is `false` before a character is selected. Do not keep the object across a `Wait` (on VORP the fields live on the shared class table).

```lua
local user = w.framework:getUser(source)
if not user then return end
print(user:getRPName(), user:getMoney(0))
```

### w.framework.UserClass

```lua
w.framework.UserClass
w.framework.UserClass:get(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id (numeric or numeric string)

Returns: `UserClass|false` - instance with `.source` and `.data`, or `false` (with error print) when `source` is not a number or the core has no user

Class of per-player objects returned by `UserClass:get(source)` / `w.framework:getUser(source)`. Instance fields: `source` (integer) and `data` (the raw core character object; on VORP `getUsedCharacter`). There is no `:new()`; use `:get()`. On VORP, `source` and `data` are written on the class table itself and the returned object proxies to it through `__index`, so fetch a fresh object each time and do not hold it across `Wait()`. The methods `get`, `getMoney`, `addMoney`, `removeMoney`, `getIdentifiers`, `getJob`, `getJobGrade`, `setJob` and `getRPName` come from the core adapter (VORP confirmed; on a core whose adapter lacks one of them the method is nil). `canBuy` and `giveGold` are defined by the module itself.

| method | parameters | returns | notes |
|---|---|---|---|
| `user:getMoney(moneyType?)` | `moneyType` (integer, optional, default 0): 0 dollars, 1 gold, 2 rol | number - balance (0 for an unknown type) | VORP: `data.money` / `gold` / `rol` |
| `user:addMoney(amount, moneyType?)` | `amount` (number, required); `moneyType` (integer, optional, default 0) | boolean on VORP - `true` once `data.addCurrency(moneyType, amount)` was called (VORP's own function answers nothing); `false` when `data.addCurrency` is missing or returns an explicit `false`. Other adapters return their core's result | Adds currency through the core |
| `user:removeMoney(amount, moneyType?)` | `amount` (number, required); `moneyType` (integer, optional, default 0) | boolean on VORP - `true` once `data.removeCurrency(moneyType, amount)` was called; `false` when it is missing or returns an explicit `false`. Other adapters return their core's result | No balance check. `canBuy(..., removeIfCan)` charges only when this returns `true` |
| `user:getIdentifiers()` | none | `{ identifier = string, charid = number|string }` | VORP: `data.identifier`, `data.charIdentifier` |
| `user:getJob()` | none | string - job name | VORP: `data.job` |
| `user:getJobGrade()` | none | number - job grade | VORP: `data.jobGrade` |
| `user:setJob(job, grade)` | `job` (string, required); `grade` (number, required) | any - VORP: `data.setJob(job)` and `data.setJobGrade(grade)` (truthy when both succeed) | Sets job and grade through the core |
| `user:getRPName()` | none | string - `"firstname lastname"` | Roleplay name |
| `user:giveGold(amount)` | `amount` (number, required) | result of `addMoney(amount, 1)` (boolean on VORP, as above) | Shortcut for money type 1 |

```lua
local user = w.framework.UserClass:get(source)
if not user then return end
print(user:getMoney(1)) -- gold
user:addMoney(100, 0)
if user:getJob() == "police" then user:setJob("police", 2) end
user:giveGold(2)
```

### w.framework.UserClass:canBuy

```lua
user:canBuy(price: number|table, moneyType?: integer, removeIfCan?: boolean)
```

Side: server

Parameters:
- `price` (number|table, required): amount (absolute value is used) or a table
  - `money` (number): used when `moneyType` is 0 or nil
  - `gold` (number): used when `moneyType` is 1
  - `rol` (number): used when `moneyType` is 2
- `moneyType` (integer, optional, default 0): 0 dollars, 1 gold, 2 rol
- `removeIfCan` (boolean, optional, default false): remove the amount when affordable

Returns: boolean - true when balance >= price (false with error print when `price` is nil)

Balance check with optional charge. The default money type is 0 (the annotation says 1). If a table is passed without the field for the money type, `math.abs(nil)` raises an error before the nil check.

```lua
if not user:canBuy(price, 0, true) then return false, "not enough money" end
```

### Per-source shortcuts: getUserIdentifiers, getJob, getRPName, addMoney, removeMoney

```lua
w.framework:getUserIdentifiers(source: integer)
w.framework:getJob(source: integer)
w.framework:getRPName(source: integer)
w.framework:addMoney(source: integer, amount: number, moneyType?: integer)
w.framework:removeMoney(source: integer, amount: number, moneyType?: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `amount` (number, required, money calls only): amount to add or remove (`removeMoney` has no balance check; use `canUserBuy` for that)
- `moneyType` (integer, optional, money calls only, default 0): 0 dollars, 1 gold, 2 rol

Returns: see table

| method | returns | notes |
|---|---|---|
| `getUserIdentifiers` | `table|nil` - `{ identifier = string, charid = number|string }`, or nil when the user does not exist | Shortcut for `UserClass:getIdentifiers()`. On VORP `identifier` is the account identifier and `charid` is `charIdentifier`. Returns nil (not false) when the user is missing. Also served to the client through the callback `<resource>:server:framework:getPlayerIdentifiers`. |
| `getJob` | string - job name | Raises an error if the user does not exist |
| `getRPName` | string - `"firstname lastname"` | Raises an error if the user does not exist |
| `addMoney` | boolean on VORP - `true` once `character.addCurrency` was called, `false` when it is missing or returns an explicit `false` (other adapters: their core's result) | Shortcut for `UserClass:addMoney`. Raises an error if the user does not exist |
| `removeMoney` | boolean on VORP - `true` once `character.removeCurrency` was called, `false` when it is missing or returns an explicit `false` (other adapters: their core's result) | Shortcut for `UserClass:removeMoney`. Raises an error if the user does not exist |

Only `getUserIdentifiers` tolerates a missing user; guard the others with `getUser` first if the player may not have a character yet.

```lua
local ids = w.framework:getUserIdentifiers(source)
if ids then print(ids.identifier, ids.charid) end
print(w.framework:getJob(source), w.framework:getRPName(source))
w.framework:addMoney(source, 50, 0)
w.framework:removeMoney(source, 10, 1) -- 10 gold
```

### w.framework:canUserBuy

```lua
w.framework:canUserBuy(source: integer, amount: number|table, moneyType?: integer|string, removeIfCan?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `amount` (number|table, required): amount, or a table with the field matching `moneyType`
  - `money` (number, required when `moneyType` is 0): dollar amount
  - `gold` (number, required when `moneyType` is 1): gold amount
  - `rol` (number, required when `moneyType` is 2): rol amount
- `moneyType` (integer|string, optional): 0 dollars, 1 gold, 2 rol, or the strings `"gold"` / `"rol"`; anything else (including nil) becomes 0
- `removeIfCan` (boolean, optional, default false): when true the amount is removed if the player has enough

Returns: boolean - true when the player has at least the amount (and it was removed when `removeIfCan` is true)

Checks (and optionally charges) one currency through `UserClass:canBuy`. The default money type is 0 (dollars) despite the annotation saying 1. If a table is given without the required field it prints an error and returns false. Raises an error if the player has no user object.

```lua
if w.framework:canUserBuy(source, 25, 0, true) then
  w.framework:giveItem(source, "bread", 1)
end
```

### w.framework:canUserPayWith

```lua
w.framework:canUserPayWith(source: integer, prices: PriceInput, removeIfCan?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `prices` (number|table, required): price input normalised by `w.pricing.get` (alias of `w.pricing.getCosts`): a number (dollars), one Cost, an array of Costs, or a PriceClass. A Cost may contain exactly one of `money` / `gold` / `rol` / `item` or normalisation fails.
  - `money` (number, optional): dollars required
  - `gold` (number, optional): gold required
  - `rol` (number, optional): rol required
  - `item` (string, optional): item name required
  - `quantity` (number, optional, default 1): quantity of the item
  - `keep` (boolean, optional, default false): when true the item must be owned but is not removed
  - `meta`: not supported - `w.pricing` drops it during normalisation, so metadata is never matched
- `removeIfCan` (boolean, optional, default false): when true and every cost is affordable, all costs are taken (items removed unless `keep`, currencies removed)

Returns: `boolean, integer` - `true, 0` when affordable; `false, index` of the first cost that failed; `false` alone (with an error print) when the price input is invalid

Checks every cost first (items through `canUseItem`, currencies through `canUserBuy`), then removes them all only if all passed. Marked `@ignore` in the source but it is a plain public method.

```lua
local ok, failedIndex = w.framework:canUserPayWith(source, { { money = 10 }, { item = "bread", quantity = 2 } }, true)
if not ok then print("cannot pay cost #" .. tostring(failedIndex)) end
```

### w.framework:refundUserWith

```lua
w.framework:refundUserWith(source: integer, prices: PriceInput)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `prices` (number|table, required): same price input as `canUserPayWith`
  - `money` / `gold` / `rol` (number, optional): currency to give back
  - `item` (string, optional): item to give back
  - `quantity` (number, optional, default 1): quantity
  - `keep` (boolean, optional): items with `keep=true` are not refunded
  - `meta`: not supported (dropped by normalisation)

Returns: nil (`false` when the price input is invalid)

Reverse of `canUserPayWith`: gives back every cost (`giveItem` / `addMoney`). Use it when a later step fails after charging. `giveItem` performs a carry check, so an item refund can silently fail when the inventory is full.

```lua
if not craftSucceeded then w.framework:refundUserWith(source, price) end
```

### w.framework:canUseItem

```lua
w.framework:canUseItem(source: integer, item: string, amount: integer, meta?: table, remove?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `item` (string, required): item name
- `amount` (integer, required): required quantity (non-numeric becomes 1)
- `meta` (table, optional): metadata the stack must match (passed to the inventory bridge)
- `remove` (boolean, optional, default false): remove the quantity when the player has it

Returns: boolean - true when the player has at least `amount` (and, when `remove` is true, `InvRemoveItem` returned true)

Defined by `inventories/_custom/server.lua` (loaded last, so it overrides the detected adapter): `count = exports.w_lib:InvGetItemCount(source, item, meta)`; false when `count < amount`; otherwise true, or the result of `exports.w_lib:InvRemoveItem` when `remove` is true. Returns false while no supported inventory is running.

```lua
if w.framework:canUseItem(source, "lockpick", 1, nil, true) then
  -- consumed one lockpick
end
```

### w.framework:removeItem

```lua
w.framework:removeItem(source: integer, item: string, quantity: integer, meta?: table)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `item` (string, required): item name
- `quantity` (integer, required): quantity to remove
- `meta` (table, optional): metadata the removed stack must match

Returns: boolean - true when the player had enough and the items were removed

Equivalent to `canUseItem(source, item, quantity, meta, true)`.

```lua
if w.framework:removeItem(source, "bread", 1) then print("eaten") end
```

### w.framework:getItemCount

```lua
w.framework:getItemCount(source: integer, item: string, meta?: table)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `item` (string, required): item name
- `meta` (table, optional): metadata filter

Returns: integer - total quantity (0 when none or the inventory bridge is not ready)

Delegates to `exports.w_lib:InvGetItemCount`.

```lua
local n = w.framework:getItemCount(source, "bread")
```

### w.framework:giveItem

```lua
w.framework:giveItem(source: integer, item: string, quantity: integer, meta?: table)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `item` (string, required): item name
- `quantity` (integer, required): quantity (non-numeric becomes 1)
- `meta` (table, optional): metadata for the new stack

Returns: boolean - false when the player cannot carry it or the add failed

Checks `exports.w_lib:InvCanCarry(source, item, quantity)` first, then `exports.w_lib:InvAddItem(source, item, quantity, meta)`.

```lua
if not w.framework:giveItem(source, "bread", 2) then print("inventory full") end
```

### w.framework:registerUseItem

```lua
w.framework:registerUseItem(item: string, closeAfterUsed?: boolean, callback: function)
w.framework:registerUseItem(item: string, callback: function)
```

Side: server

Parameters:
- `item` (string, required): item name
- `closeAfterUsed` (boolean, optional, default true; nil becomes true): close the inventory after use. If a function is passed here it is taken as the callback
- `callback` (function, required): `function(source: integer, data: { metadata: table, slot: number|nil, item: table })` - `data.item` is the raw slot data from the inventory

Returns: boolean - false when `callback` is not a function; otherwise the result of `exports.w_lib:InvRegisterUsableItem == true` (true even when no inventory is running yet; the registration is queued)

Registers a usable item through `exports.w_lib:InvRegisterUsableItem`. Your Lua function is handed to the library as a function reference (the one export in the library that accepts one); the bridge stores it with your resource name as owner, applies it to the active inventory when one starts, and unregisters it when your resource stops. One definition per item name across the server: a later registration of the same item replaces the earlier one.

```lua
w.framework:registerUseItem("bandage", true, function(source, data)
  print(source, "used bandage from slot", data.slot)
end)
```

### w.framework:listenItemRemoved

```lua
w.framework:listenItemRemoved(item: string, callback: function)
w.framework:listenItemRemoved(callback: function)
```

Side: server

Parameters:
- `item` (string, optional): item name to listen for; omit (one-argument form) to listen for every item
- `callback` (function, required): `function(source: integer, item: string, data: { quantity: number, metadata: table })` - called through `pcall`. The removal reason is not forwarded to the callback.

Returns: nil

Registers a listener for the local server event `w_lib:inventory:listenerItemRemoved`. Inside the library that event is emitted only by the vorp v1/v2 adapters (from `vorp_inventory:Server:OnItemRemoved`) and the rsg v2 adapter; on w_inventory nothing emits it, so it fires only if something triggers the event manually. The real callback arguments are `(source, item, data)`, not `(source, quantity, meta, reason)` as annotated.

```lua
w.framework:listenItemRemoved("lantern", function(source, item, data)
  print(source, "lost", data.quantity, item)
end)
```

### w.framework:onCharacterSelected

```lua
w.framework:onCharacterSelected(cb: function)
```

Side: server

Parameters:
- `cb` (function, required): `function(source: integer, isNew: boolean)` - `isNew` is true when the character was just created

Returns: nil

Registers a callback fired when the core reports a character selection for a player (VORP: net event `vorp_CharSelectedCharacter` gives `isNew` false; server-side event `vorp_NewCharacter(playerSource)` gives `isNew` true, ignored if triggered from a client or if the player has no VORP user). Callbacks are per resource because the module runs inside your resource. The module registers one itself to keep the identifier-to-source map for `getSourceFromIdentifiers`. Sibling resources often also listen to VORP events directly; `onCharacterSelected` is the framework-neutral way.

```lua
w.framework:onCharacterSelected(function(source, isNew)
  TriggerClientEvent("myres:client:playerLoaded", source)
end)
```

### w.framework:getSourceFromIdentifiers

```lua
w.framework:getSourceFromIdentifiers(identifier: string, charid: string|number)
```

Side: server

Parameters:
- `identifier` (string, required): account identifier (as returned by `getUserIdentifiers().identifier`)
- `charid` (string|number, required): character id (`getUserIdentifiers().charid`)

Returns: `integer|false` - the online player's server id, or false

Looks up the source in a map maintained from `onCharacterSelected`, players already online when your resource loaded, and `playerDropped`. The key is `identifier .. "|" .. charid` formatted with `%s`, so the values must format identically to what `getUserIdentifiers` returned.

```lua
local src = w.framework:getSourceFromIdentifiers(ids.identifier, ids.charid)
if src then TriggerClientEvent("myres:notify", src, "hello") end
```

### w.framework:getMyIdentifiers

```lua
w.framework:getMyIdentifiers()
```

Side: client

Parameters: none

Returns: table - `{ identifier: string, charid: number|string }` of the local player; cached after the first successful call

Asks the server for the local player's identifiers through the callback `<yourResource>:server:framework:getPlayerIdentifiers`, which is registered by the server-side copy of this module in the same resource. Load the framework module on both sides of your resource or this call never resolves. Waits for the answer. Call it only after a character is selected: if the server answers nil (no character yet) the cache becomes nil and the next call errors on `table.isEmpty(nil)`.

```lua
local ids = w.framework:getMyIdentifiers()
print(ids.identifier, ids.charid)
```

### w.framework:getItems

```lua
w.framework:getItems()
```

Side: shared

Parameters: none

Returns: `table<string, ItemData>` - the item catalogue (may be empty if the inventory has not started yet)

Returns `w.framework.inventoryItems`, refreshing it from `exports.w_lib:w_framework_getInventoryItems()` when it is empty (the refresh is skipped inside the library itself or while the library is not started). Safe on client and server.

```lua
local items = w.framework:getItems()
print(items["bread"] and items["bread"].label)
```

### w.framework:getItemData

```lua
w.framework:getItemData(item: string)
```

Side: shared

Parameters:
- `item` (string, required): item name (inventory key)

Returns: table - the catalogue entry `{ item, label, type, description, image }`; when the item is unknown it prints an error and returns `{ label = "Not exist" }`

Looks the item up in the catalogue (refreshing when empty). The fallback is a table, not false, despite the annotation, so test `data.item` or `data.label ~= "Not exist"`.

```lua
local data = w.framework:getItemData("bread")
if data.item then print(data.label, data.image) end
```

### w.framework:addItemDataToPrice

```lua
w.framework:addItemDataToPrice(price: table)
```

Side: shared

Parameters:
- `price` (table, required): a price to enrich. Accepted shapes, tested in this order: one cost with an `item` field; `{costs = Cost[]}`; `{prices = Price[]}`; or a plain array of prices. Non-table input is returned unchanged.
  - `item` (string, optional): item name; when present the table is treated as a single cost and every catalogue field (label, type, description, image, item) that is still nil is copied into it
  - `costs` (table, optional): array of cost tables, each enriched the same way (checked only when `item` is absent)
  - `prices` (table, optional): array of nested prices, processed recursively (checked only when `item` and `costs` are absent)

Returns: table - the same table, mutated

Walks a price structure and copies label/description/image/type from the item catalogue into every item cost that lacks them. `w.pricing` calls it automatically when it normalises item costs, so prices built through `w.pricing` already carry these fields. Mutates and returns the input.

```lua
local price = { costs = { { item = "bread", quantity = 2 }, { money = 5 } } }
w.framework:addItemDataToPrice(price)
print(price.costs[1].label)
```

### w.framework:createInventory

```lua
w.framework:createInventory(invName: string, name: string, invConfig: table)
```

Side: server

Parameters:
- `invName` (string, required): unique stash id
- `name` (string, required): label (falls back to `invName`)
- `invConfig` (table, required): configuration (non-table becomes `{}`)
  - `maxSlots` (integer, optional, default 50): slot count (the key `slots` is also accepted)
  - `maxWeight` (number, optional, default 100): max weight in kilograms; multiplied by 1000 for the inventory
  - `acceptWeapons` / `shared` / `ignoreStackLimit` / `whitelist` / `blacklist` / `weaponlist` / `permissions` (optional): accepted by the generic signature but ignored by the `_custom` adapter

Returns: boolean - true when `exports.w_lib:InvRegisterStash` returned true

Registers a stash through `exports.w_lib:InvRegisterStash` (w_inventory `RegisterStash`; vorp `registerInventory`; rsg/qbr `CreateInventory`). Only id, label, slots and weight are used.

```lua
w.framework:createInventory("shop_storage_1", "Shop storage", { maxSlots = 30, maxWeight = 60 })
```

### w.framework:openInventory

```lua
w.framework:openInventory(source: integer, invName: string)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `invName` (string, required): stash id created with `createInventory`

Returns: boolean

Opens the stash for the player through `exports.w_lib:InvOpenStash` (w_inventory `forceOpenInventory 'stash'`; vorp `openInventory`; rsg/qbr `OpenInventory` with the stored stash definition). The older adapter paths that sent `w_lib:client:openInventory` are overridden by this `_custom` definition.

```lua
w.framework:openInventory(source, "shop_storage_1")
```

### w.framework:addItemInInventory

```lua
w.framework:addItemInInventory(source: integer|nil, invId: string, item: string, quantity: integer, metadata?: table, needWait?: boolean)
```

Side: server

Parameters:
- `source` (integer, optional): ignored by the `_custom` adapter (kept for signature compatibility)
- `invId` (string, required): stash id
- `item` (string, required): item name
- `quantity` (integer, required): quantity
- `metadata` (table, optional): metadata (on vorp_inventory `metadata.charid` / `charId` is used as the owner id, default 1)
- `needWait` (boolean, optional): ignored

Returns: boolean

Adds an item to a stash through `exports.w_lib:InvAddItemToStash`.

```lua
w.framework:addItemInInventory(nil, "shop_storage_1", "bread", 5)
```

### w.framework:removeInventory

```lua
w.framework:removeInventory(invName: string)
```

Side: server

Parameters:
- `invName` (string, required): stash id

Returns: any - w_inventory: result of `exports.w_inventory:RemoveInventory(invName)`

Removes the stash from the inventory's server cache. Not overridden by `_custom`, so it exists only when a detected inventory adapter defines it (w_inventory does); with no detected inventory the method is nil and calling it raises an error.

```lua
if w.framework.removeInventory then w.framework:removeInventory("shop_storage_1") end
```

### w.framework:getItemsFromInventory

```lua
w.framework:getItemsFromInventory(invId: string)
```

Side: server

Parameters:
- `invId` (string, required): stash id

Returns: `table|nil` - w_inventory: `exports.w_inventory:GetInventoryItems(invId)`, i.e. the inventory's items table keyed by slot (`{ slot, name, label, count, weight, metadata, ... }`), or nil when the inventory is not loaded

Reads a stash's content. Not overridden by `_custom`; exists only when the detected inventory adapter defines it (w_inventory does), nil otherwise. The shape documented in the annotations (`{ item, amount, id, metadata }`) is not what w_inventory returns.

Not confirmed from source; treat as best effort.

```lua
for slot, it in pairs(w.framework:getItemsFromInventory("shop_storage_1") or {}) do print(slot, it.name, it.count) end
```

### w.framework:mergeInventoriesConfiguration

```lua
w.framework:mergeInventoriesConfiguration(...: table)
```

Side: server

Parameters:
- `...` (table, required): one or more inventory configuration tables
  - `maxSlots` (integer, optional, default 0): summed across configs
  - `maxWeight` (number, optional, default 0): summed across configs
  - `acceptWeapons` (boolean, optional): intended as AND of all configs, but `config.acceptWeapons or true` makes the result always true
  - `shared` (boolean, optional): same quirk, result always true
  - `ignoreStackLimit` (boolean, optional): same quirk, result always true
  - `whitelist` (table, optional): merged with `table.merge`
  - `blacklist` (table, optional): merged
  - `weaponlist` (table, optional): merged
  - `permissions` (table, optional): merged

Returns: table - `{ maxSlots, maxWeight, acceptWeapons, shared, ignoreStackLimit, whitelist, blacklist, weaponlist, permissions }`

Combines several inventory configs into one for `createInventory`. Slots and weight are added; the boolean flags always come out true because of the `or true` in the source. On this server only `maxSlots` / `maxWeight` are used by `createInventory` anyway.

```lua
local cfg = w.framework:mergeInventoriesConfiguration({ maxSlots = 20, maxWeight = 50 }, { maxSlots = 10, maxWeight = 25 })
w.framework:createInventory("camp_chest", "Camp chest", cfg)
```

### w.framework:getUserSkin

```lua
w.framework:getUserSkin(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id

Returns: table - standard skin (see `standardizeSkin`). `teethHash` is filled from the clothes' teeth component when the skin has no `teethHash` / `teethIndex`

Reads and standardises the character's skin from the core (VORP: `character.skin` JSON).

```lua
local skin = w.framework:getUserSkin(source)
TriggerClientEvent("w_lib:client:applySkin", source, nil, skin)
```

### w.framework:getUserClothes

```lua
w.framework:getUserClothes(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id

Returns: table - standard clothes (category -> `{ hash, palette, tint0, tint1, tint2, ... }`); `{}` when the core has none

Reads the character's clothes from the core (VORP: `comps` merged with `compTints`) and standardises them. On VORP it errors if the player has no character (the adapter indexes `user.data` without a check).

```lua
local clothes = w.framework:getUserClothes(source)
for cat, data in pairs(clothes) do print(cat, data.hash) end
```

### w.framework:updateUserSkin

```lua
w.framework:updateUserSkin(source: integer, skinData: table, overwrite?: boolean)
w.framework:updateUserSkin(source: integer, category: string, data: any, overwrite?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `skinData` (table|string, required): standard skin table, or a single standard key name followed by its value
- `data` (any, optional): value for the single-key form
- `overwrite` (boolean, optional): true replaces the stored skin, false/nil merges. Always the last argument

Returns: nil

Saves skin data: `revertSkin` then the core adapter's `updateUserSkinInternal` (VORP: a `Teeth` key is redirected to the clothes; `vorpcharacter:updateCache(skin)` when overwriting, `vorpcharacter:savenew(false, skin)` when merging).

```lua
w.framework:updateUserSkin(source, "hair", { hash = 0x1234ABCD })
```

### w.framework:updateUserClothes

```lua
w.framework:updateUserClothes(source: integer, clothes: table, overwrite?: boolean)
w.framework:updateUserClothes(source: integer, category: string, value: table|number, overwrite?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `clothes` (table|string, required): either a standard clothes table (category -> component data) or a single category name followed by its value
- `value` (table|number, optional): component data for the single-category form: `{ hash, palette, tint0, tint1, tint2, state, drawable, wearableState }` or a hash
- `overwrite` (boolean, optional): true replaces the whole outfit (every current category is reset to hash 0 first), false/nil merges. Always the last argument

Returns: nil

Saves clothes for the character: converts standard keys back to the core format (`revertClothes`) and calls the core adapter's `updateUserClothesInternal`. VORP: sends `vorpcharacter:updateCache(nil, comps)` to the client and rewrites `compTints` through the character object. VORP gotcha: because the adapter reads a misspelled field (`comptTints`) the tint map is always rebuilt from the categories you pass, so tints of untouched categories are lost even when merging.

```lua
w.framework:updateUserClothes(source, "hats", { hash = 12345, palette = "metaped_tint_hair", tint0 = 3, tint1 = 0, tint2 = 0 })
-- or the whole outfit
w.framework:updateUserClothes(source, standardClothes, true)
```

### w.framework:standardizeSkin and w.framework:revertSkin

```lua
w.framework:standardizeSkin(skin: table)
w.framework:revertSkin(standard: table)
```

Side: server

Parameters:
- `skin` (table, required, `standardizeSkin`): skin in the core's own format
- `standard` (table, required, `revertSkin`): standard skin table

Returns: `standardizeSkin` returns a standard skin: `model`, `headHash`, `bodyUpperHash`, `bodyLowerHash`, `eyesHash`, `teethHash`, `hair {hash}`, `beards_complete` / `beards_chin` / `beards_chops` / `beards_mustache` / `beards` / `hair_bonnet {hash}`, `bodyType`, `bodyWeight`, `bodyScale`, `expressions = { arms, calves, cheekbonesDepth, ..., waist }` as decimals -1..1, `overlays = { ageing, freckles, moles, scar, spots, acne, grime, hair, complex, disc, beard, blush, eyebrow, eyeliner, eyeshadow, lipstick, foundation, masks }` each `{ id, opacity, tint0, tint1, tint2, palette, sheetGrid, sexe }`. `revertSkin` returns the skin in the core's format (overlays/expressions removed when empty)

`standardizeSkin` converts core skin data to the standard layout through the core adapter's `standardizeSkinInternal` (VORP implements it; it also uses `w.component` to resolve head/body hashes). Overlays with opacity 0 (or only a palette) are dropped; expressions equal to 0 are dropped and the rest normalised with `convertToPercent`; scalar hair/beard values are wrapped in `{ hash = n }`. Input is copied. `revertSkin` is the inverse: `beards_chin`, `beards_chops`, `beards_mustache`, `beards` and `hair_bonnet` are moved through unchanged. Passing nil to `revertSkin` errors (`table.copy(nil)`).

```lua
local skin = w.framework:standardizeSkin(rawSkin)
print(skin.model, skin.headHash)
local coreSkin = w.framework:revertSkin(skin)
```

### w.framework:standardizeClothes and w.framework:revertClothes

```lua
w.framework:standardizeClothes(clothes: table)
w.framework:revertClothes(standard: table)
```

Side: server

Parameters:
- `clothes` (table, required, `standardizeClothes`): clothes in the core's own format (VORP comps table keys such as Hat, Coat, Pant, ...)
- `standard` (table, required, `revertClothes`): standard clothes table (category -> component data)

Returns: `standardizeClothes` returns standard clothes: category -> `{ hash, palette?, tint0?, tint1?, tint2?, drawable?, wearableState?, state? }`; `revertClothes` returns clothes in the core's format

`standardizeClothes` converts core-specific clothes keys to the standard categories (VORP adapter: accessories, armor, badges, beards_complete, belts, boots, hair_accessories, jewelry_bracelets, chaps, belt_buckles, cloaks, coats, coats_closed, dresses, eyewear, gauntlets, gloves, gunbelts, gunbelt_accs, hair, hats, holsters_left, loadouts, masks, neckties, neckwear, pants, ponchos, jewelry_rings_left, jewelry_rings_right, satchels, shirts_full, skirts, spats, boot_accessories, suspenders, teeth, vests). Numeric values become `{ hash = n }`; a table with `comp` is renamed to `hash`; entries with hash 0/-1/1 or nil (and no drawable/wearableState) are removed; palette 0/nil clears the tints. Unknown keys are kept as-is (printed when `w.debug`). Input is copied, not mutated. Requires a core adapter that defines `standardizeClothesInternal` (VORP does). `revertClothes` is the inverse; unknown standard keys are merged through unchanged, and the input is copied.

```lua
local std = w.framework:standardizeClothes(rawComps)
print(std.hats and std.hats.hash)
local coreComps = w.framework:revertClothes({ hats = { hash = 12345 } })
```

### w.framework:convertToPercent and w.framework:extractComponentHashIfAlone

```lua
w.framework:convertToPercent(value: number|string)
w.framework:extractComponentHashIfAlone(data: any)
```

Side: server

Parameters:
- `value` (number|string, required, `convertToPercent`): a value in percent (e.g. 50) or already a decimal (e.g. 0.5)
- `data` (any, required, `extractComponentHashIfAlone`): component data table or raw value

Returns: `convertToPercent` returns a number - decimal between -1 and 1 (0 when not numeric); `extractComponentHashIfAlone` returns `data.hash` when the table has only that key, otherwise the input

Small helpers used by the skin and clothes conversions. `convertToPercent` divides values outside -1..1 by 100; it is used for skin expressions. `extractComponentHashIfAlone` is a helper for clothes tables.

```lua
print(w.framework:convertToPercent(35)) -- 0.35
local hash = w.framework:extractComponentHashIfAlone({ hash = 12345 })
```

### w.framework:createUser

```lua
w.framework:createUser(source: integer, data: table, spawnCoordinate?: vector4, isDead?: boolean)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `data` (table, required): new character data
  - `firstname` (string, optional, default `""`)
  - `lastname` (string, optional, default `""`)
  - `skin` (table, required): standard skin (reverted internally; nil errors); `skin.model == "mp_male"` sets gender Male, otherwise Female
  - `comps` (table, required): standard clothes (reverted internally; nil errors)
  - `age` (number, optional)
  - `charDescription` (string, optional, default `""`)
  - `nickname` (string, optional, default `""`)
- `spawnCoordinate` (vector4, optional): spawn position and heading; VORP default `vec4(2537.684, -1278.066, 49.218, 42.520)`
- `isDead` (boolean, optional, default false): start dead

Returns: nil

Defined only by the VORP core adapter (the `_default` stub is never loaded): calls `Core.getUser(source).addCharacter(...)` with JSON-encoded skin/comps and compTints `"[]"`, sends the client event `vorp:initCharacter(coords, heading, isDead)`, then after 3 s triggers `vorp_NewCharacter` so `onCharacterSelected` fires with `isNew=true`. Marked ignore in the docs annotations.

```lua
w.framework:createUser(source, { firstname = "John", lastname = "Marston", skin = standardSkin, comps = standardClothes })
```

### w.framework:getInventoryItems and exports.w_lib:w_framework_getInventoryItems

```lua
w.framework:getInventoryItems()                  -- exists only inside the library
exports.w_lib:w_framework_getInventoryItems()    -- what consumer resources call
```

Side: shared

Parameters: none

Returns: `table<string, { item: string, label: string, type: "item_standard"|"item_weapon", description: string|nil, image: string }>` - empty table if the inventory is not ready

`w.framework:getInventoryItems()` exists only inside the library (defined by `inventories/_custom/g_shared.lua`, which overrides `cores/_custom/g_shared.lua`); in a consumer resource `w.framework.getInventoryItems` is nil. It builds the catalogue from `exports.w_inventory:Items()` when w_inventory is started (type `item_weapon` when the definition has `weapon = true`), otherwise from the detected adapter's catalogue, otherwise `{}`. Consumer resources reach it through the export `exports.w_lib:w_framework_getInventoryItems()` or `w.framework:getItems()`. The export returns the library's cached catalogue, building it on first call (concurrent callers wait; a failed build prints an error and leaves `{}` so the next call retries). It is available on client and server once the framework module has been loaded globally (any consumer resource loading it triggers that). Plain data only.

```lua
local items = exports.w_lib:w_framework_getInventoryItems()
print(items.bread and items.bread.label)
```

### w.framework:loadCoreFiles and w.framework:loadInventoryFiles

```lua
w.framework:loadCoreFiles(file: string)
w.framework:loadInventoryFiles(file: string)
```

Side: shared

Parameters:
- `file` (string, required): file stem to load: `"shared"`, `"client"`, `"server"`, `"g_shared"`, `"g_client"` or `"g_server"`

Returns: `loadCoreFiles` returns false when no core is detected, true otherwise; `loadInventoryFiles` always returns true

Internal loaders used by the module itself. `loadCoreFiles` loads `cores/<detected folder>/<file>.lua` for every detected core, then `cores/_custom/<file>.lua` (missing files are skipped). `loadInventoryFiles` does the same for `inventories/`; when no inventory is detected only the `_custom` file is loaded (this is why the item helpers still work through the `Inv*` bridge). Neither ever loads a `_default` folder. Exposed on the table but consumer resources do not need to call them.

```lua
-- internal; called by the module during load
```

### The Inv* inventory bridge exports

```lua
exports.w_lib:InvName()
exports.w_lib:InvGetItemCount(source: integer, item: string, meta?: table)
exports.w_lib:InvCanCarry(source: integer, item: string, count: integer)
exports.w_lib:InvAddItem(source: integer, item: string, count: integer, meta?: table)
exports.w_lib:InvRemoveItem(source: integer, item: string, count: integer, meta?: table, slot?: integer)
exports.w_lib:InvRegisterStash(id: string, label?: string, slots?: integer, maxWeight?: number)
exports.w_lib:InvAddItemToStash(stashId: string, item: string, count: integer, meta?: table)
exports.w_lib:InvOpenStash(source: integer, stashId: string)
exports.w_lib:InvGetItems(source: integer)
exports.w_lib:InvGetSlot(source: integer, slot: integer|string)
exports.w_lib:InvRegisterUsableItem(item: string, closeAfterUsed?: boolean, callback: function)
exports.w_lib:InvItemLabel(item: string)
exports.w_lib:InvClose()
```

Side: shared for `InvName`; client for `InvItemLabel` and `InvClose`; server for the rest

These exports resolve the active inventory at call time (see the convar `w_lib:inventory`). Item names starting with `WEAPON_` are treated as weapons on vorp_inventory.

| export | side | parameters | returns | notes |
|---|---|---|---|---|
| `InvName()` | shared | none | `string|nil` - `"w_inventory"`, `"vorp_inventory"`, `"rsg-inventory"` or `"qbr-inventory"`; nil when no supported inventory is running | Server: resolves (and caches) the adapter. Client: reads `w_lib:activeInventory`, then prefers a started w_inventory, then the convar `w_lib:inventory`, then the same detection order. |
| `InvGetItemCount(source, item, meta?)` | server | `source` (integer, required); `item` (string, required; WEAPON_* names count weapons on vorp_inventory); `meta` (table, optional; honoured by w_inventory Search and vorp getItem, ignored by rsg/qbr) | integer - quantity, 0 when none or no inventory is running | Item count of a player |
| `InvCanCarry(source, item, count)` | server | `source` (integer, required); `item` (string, required); `count` (integer, required) | boolean | w_inventory `CanCarryItem`; vorp `canCarryItem` / `canCarryWeapons`; rsg/qbr `CanAddItem`, nil treated as true |
| `InvAddItem(source, item, count, meta?)` | server | `source` (integer, required); `item` (string, required; WEAPON_* on vorp_inventory creates a weapon with `meta.ammo` table, `meta.components`, `meta.serial`); `count` (integer, required); `meta` (table, optional) | boolean | Adds an item without a carry check |
| `InvRemoveItem(source, item, count, meta?, slot?)` | server | `source` (integer, required); `item` (string, required; WEAPON_* on vorp_inventory removes one weapon matched by `meta.weaponId` / `meta.serial` / name); `count` (integer, required); `meta` (table, optional); `slot` (integer, optional, w_inventory only) | boolean | Removes an item |
| `InvRegisterStash(id, label?, slots?, maxWeight?)` | server | `id` (string, required; empty returns false); `label` (string, optional, default id); `slots` (integer, optional, default 50); `maxWeight` (number, optional, default 100000, grams in w_inventory/rsg units) | boolean - false when no inventory is running (the definition is still stored for `InvOpenStash`) | Registers a stash and remembers its definition |
| `InvAddItemToStash(stashId, item, count, meta?)` | server | `stashId` (string, required); `item` (string, required); `count` (integer, required); `meta` (table, optional; vorp: `meta.charid` / `charId` used as owner, default 1) | boolean | Adds an item to a stash |
| `InvOpenStash(source, stashId)` | server | `source` (integer, required); `stashId` (string, required) | boolean | w_inventory `forceOpenInventory 'stash'`; vorp `openInventory`; rsg/qbr `OpenInventory` with the stored definition |
| `InvGetItems(source)` | server | `source` (integer, required) | table - array of `{ slot, name, label, count, weight, metadata }`; on vorp_inventory weapons appear with slot `"w<id>"` and metadata `{ serial, weaponId, isWeapon = true, ammo, components }` | Normalised list of a player's items |
| `InvGetSlot(source, slot)` | server | `source` (integer, required); `slot` (integer|string, required; vorp: item id or `"w<id>"`) | `table|nil` - `{ name, label, count, metadata }` (vorp also slot/weight) | Reads one slot |
| `InvRegisterUsableItem(item, closeAfterUsed?, callback)` or `(item, callback)` | server | `item` (string, required; empty returns false); `closeAfterUsed` (boolean, optional, default true; only false disables); `callback` (function, required): `function(source, { metadata, slot, item })` - a function reference is accepted by this export | boolean - false for an empty item name or a non-function callback; true otherwise (queued when no inventory is running yet) | Owner = the calling resource (`GetInvokingResource`). Definitions are keyed by item name server-wide, re-applied when the adapter changes, and removed when the owning resource stops (w_inventory: `UnregisterUsableItem`). |
| `InvItemLabel(item)` | client | `item` (string, required) | string - label from w_inventory's item definitions, otherwise the item name (`"Unknown"` for nil) | w_inventory only |
| `InvClose()` | client | none | nil | Closes the inventory UI (w_inventory `closeInventory`; `vorp_inventory:closeInventory`; rsg/qbr `client:closeinv`) |

```lua
-- server
if exports.w_lib:InvName() == "w_inventory" then end
local n = exports.w_lib:InvGetItemCount(source, "bread")
if exports.w_lib:InvCanCarry(source, "bread", 5) then
  exports.w_lib:InvAddItem(source, "bread", 2, { quality = 100 })
end
exports.w_lib:InvRemoveItem(source, "bread", 1)
exports.w_lib:InvRegisterStash("camp_chest", "Camp chest", 30, 60000)
exports.w_lib:InvAddItemToStash("camp_chest", "bread", 5)
exports.w_lib:InvOpenStash(source, "camp_chest")
for _, it in ipairs(exports.w_lib:InvGetItems(source)) do print(it.name, it.count) end
local s = exports.w_lib:InvGetSlot(source, 3)
exports.w_lib:InvRegisterUsableItem("bandage", function(source, data) print(source, data.slot) end)

-- client
print(exports.w_lib:InvItemLabel("bread"))
exports.w_lib:InvClose()
```

### The Fw* export bridge: detection and raw access

```lua
exports.w_lib:FwName()
exports.w_lib:FwReady()
exports.w_lib:FwInventory()
exports.w_lib:FwGetCore()
exports.w_lib:FwGetPlayerData()
exports.w_lib:FwGetUser(source: integer)
exports.w_lib:FwGetCharacter(source: integer)
```

Side: shared for `FwName`, `FwReady`, `FwInventory`, `FwGetCore`; client for `FwGetPlayerData`; server for `FwGetUser`, `FwGetCharacter`

Parameters:
- `source` (integer, required, `FwGetUser` / `FwGetCharacter`): player server id

Returns: see table

| export | returns | notes |
|---|---|---|
| `FwName()` | `string|nil` - `"vorp"`, `"rsgcore"` or `"qbr"` (nil until detected) | Detects vorp_core, rsg-core, qbr-core only; detection polls every 500 ms |
| `FwReady()` | boolean | True once the bridge has detected a core. Poll it before using the other `Fw*` exports at startup |
| `FwInventory()` | `string|nil` - active inventory resource name (from `InvName`), falling back to the framework's default inventory name | Consistent with `exports.w_lib:InvName()` |
| `FwGetCore()` | `table|nil` - raw core object (VORP Core, RSG core object, or a QB-shaped wrapper for QBR) | Data fields are usable across the export boundary; functions on it are not callable from another resource. Prefer the `Fw*` getters |
| `FwGetPlayerData()` | `table|nil` - RSG/QBR PlayerData; nil on VORP | Local player data on RSG-style cores only |
| `FwGetUser(source)` | `table|nil` - raw core user (VORP `getUser` / RSG `GetPlayer`) | Functions on it are not callable across exports |
| `FwGetCharacter(source)` | `table|nil` - raw character (VORP `getUsedCharacter` / RSG PlayerData) | Plain fields only across exports |

```lua
while not exports.w_lib:FwReady() do Wait(250) end
if exports.w_lib:FwName() == "vorp" then end
print(exports.w_lib:FwInventory())
local char = exports.w_lib:FwGetCharacter(source)
```

### Fw* online character getters

```lua
exports.w_lib:FwGetCharacterIdentifier(source: integer)
exports.w_lib:FwGetCharacterName(source: integer)
exports.w_lib:FwGetFirstName(source: integer)
exports.w_lib:FwGetLastName(source: integer)
exports.w_lib:FwGetIdentifier(source: integer)
exports.w_lib:FwGetJob(source: integer)
exports.w_lib:FwGetJobLabel(source: integer)
exports.w_lib:FwGetJobGrade(source: integer)
exports.w_lib:FwGetMoney(source: integer)
exports.w_lib:FwGetGold(source: integer)
exports.w_lib:FwGetPlaytime(source: integer)
exports.w_lib:FwGetDescription(source: integer)
exports.w_lib:FwGetAge(source: integer)
exports.w_lib:FwGetNickname(source: integer)
exports.w_lib:FwGetCharacterData(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id

Returns: see table

| export | returns |
|---|---|
| `FwGetCharacterIdentifier` | `number|string|nil` - VORP `charIdentifier` / RSG `citizenid` |
| `FwGetCharacterName` | string - `"firstname lastname"` (`GetPlayerName` when no character) |
| `FwGetFirstName` | string (`""` when unknown) |
| `FwGetLastName` | string (`""` when unknown) |
| `FwGetIdentifier` | `string|nil` - VORP identifier / RSG license or citizenid |
| `FwGetJob` | string - job name, `"unemployed"` by default |
| `FwGetJobLabel` | string - job label (VORP `jobLabel` or job), `"Unemployed"` by default |
| `FwGetJobGrade` | number - job grade, 0 by default |
| `FwGetMoney` | number - cash balance (0 by default) |
| `FwGetGold` | number - gold (VORP) / gold or bloodmoney (RSG) |
| `FwGetPlaytime` | number - VORP hours / RSG `metadata.playtime` (0 by default) |
| `FwGetDescription` | string - character description |
| `FwGetAge` | `number|nil` |
| `FwGetNickname` | string |
| `FwGetCharacterData` | `table|nil` - `{ firstname, lastname, job, jobLabel, jobGrade, money, gold, xp, charIdentifier, identifier }`, same shape on every core (RSG gold = bloodmoney) |

```lua
local d = exports.w_lib:FwGetCharacterData(source)
print(d.firstname, d.money)
local charId = exports.w_lib:FwGetCharacterIdentifier(source)
print(exports.w_lib:FwGetJob(source), exports.w_lib:FwGetJobGrade(source))
```

### Fw* online setters, currency and health

```lua
exports.w_lib:FwSetJob(source: integer, jobName: string, grade?: number)
exports.w_lib:FwSetJobLabel(source: integer, label: string)
exports.w_lib:FwSetJobGrade(source: integer, grade: number)
exports.w_lib:FwSetFirstName(source: integer, firstName: string)
exports.w_lib:FwSetLastName(source: integer, lastName: string)
exports.w_lib:FwSetNickname(source: integer, nickname: string)
exports.w_lib:FwSetAge(source: integer, age: number)
exports.w_lib:FwSetDescription(source: integer, description: string)
exports.w_lib:FwAddCurrency(source: integer, currencyType: integer, amount: number)
exports.w_lib:FwRemoveCurrency(source: integer, currencyType: integer, amount: number)
exports.w_lib:FwRevive(source: integer)
exports.w_lib:FwHeal(source: integer)
exports.w_lib:FwRespawn(source: integer)
exports.w_lib:FwKill(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `jobName` (string, required): job name; `grade` (number, optional for `FwSetJob`, default 0; required for `FwSetJobGrade`)
- `label`, `firstName`, `lastName`, `nickname`, `description` (string, required): new value
- `age` (number, required): new age
- `currencyType` (integer, required): 0 cash, 1 gold (VORP) / gold or bloodmoney (RSG), 2 rol (VORP) / blkbank (RSG)
- `amount` (number, required): amount

Returns: boolean for every call

| export | notes |
|---|---|
| `FwSetJob` | VORP `setJob` + `setJobGrade`; RSG `Functions.SetJob` |
| `FwSetJobLabel` | VORP `setJobLabel`; RSG resolves a job by label and re-applies it with the current grade |
| `FwSetJobGrade` | Sets the job grade |
| `FwSetFirstName` | RSG also updates the `players.charinfo` column |
| `FwSetLastName` | Sets the last name |
| `FwSetNickname` | Sets the nickname |
| `FwSetAge` | Sets the age |
| `FwSetDescription` | Sets the character description |
| `FwAddCurrency` | Adds currency to an online player |
| `FwRemoveCurrency` | Removes currency from an online player (no balance check on VORP) |
| `FwRevive` | VORP `Core.Player.Revive` / RSG `rsg-medic:client:adminRevive` |
| `FwHeal` | Heals the player |
| `FwRespawn` | Respawns the player |
| `FwKill` | VORP: client event `w_:client:killPlayer`; RSG: `rsg-medic:client:KillPlayer` |

```lua
exports.w_lib:FwSetJob(source, "police", 1)
exports.w_lib:FwSetJobLabel(source, "Sheriff")
exports.w_lib:FwAddCurrency(source, 0, 25)
exports.w_lib:FwRemoveCurrency(source, 1, 2)
exports.w_lib:FwRevive(source)
```

### Fw* online item and weapon operations

```lua
exports.w_lib:FwGetInventoryItems(source: integer)
exports.w_lib:FwGetInventoryWeapons(source: integer)
exports.w_lib:FwAddItem(source: integer, itemName: string, count?: integer)
exports.w_lib:FwRemoveItem(source: integer, itemName: string, count?: integer)
exports.w_lib:FwAddWeapon(source: integer, weaponName: string, ammo?: number|table)
exports.w_lib:FwRemoveWeapon(source: integer, weaponId: number|string)
exports.w_lib:FwCanCarryItem(source: integer, itemName: string, count?: integer)
exports.w_lib:FwCanCarryWeapon(source: integer, count: integer, weaponName: string)
exports.w_lib:FwClearInventory(source: integer)
```

Side: server

Parameters:
- `source` (integer, required): player server id
- `itemName` (string, required): item name
- `count` (integer, optional, default 1; for `FwCanCarryWeapon` required, nil becomes 1): quantity
- `weaponName` (string, required): WEAPON_* name
- `ammo` (number|table, optional): ammo count, or a table of ammo type -> count (kept as a table for vorp_inventory, summed for the others)
- `weaponId` (number|string, required): slot, weaponId or serial stored in the weapon's metadata

Returns: see table

| export | returns | notes |
|---|---|---|
| `FwGetInventoryItems(source)` | table - array of `{ name, count, amount, label, weight, id, slot, metadata, info }` (non-weapon items); when w_inventory runs in VORP native storage mode it returns vorp_inventory's own list | Player's items via the inventory bridge |
| `FwGetInventoryWeapons(source)` | table - array of `{ name, id, slot, weight, label, custom_label, serial_number, ammo, components, metadata, info, type = "weapon", group, propietary, used, used2 }` | Items whose name starts with WEAPON_ |
| `FwAddItem(source, itemName, count?)` | boolean | Adds an item without metadata (no carry check; use `FwCanCarryItem`) |
| `FwRemoveItem(source, itemName, count?)` | boolean | Removes an item |
| `FwAddWeapon(source, weaponName, ammo?)` | boolean | Gives a weapon as an item with `metadata.ammo` (vorp native storage: `createWeapon`) |
| `FwRemoveWeapon(source, weaponId)` | boolean | Removes one weapon located by slot/weaponId/serial |
| `FwCanCarryItem(source, itemName, count?)` | boolean | Weight/slot check |
| `FwCanCarryWeapon(source, count, weaponName)` | boolean | Carry check for a weapon; note the argument order: `count` before `weaponName` |
| `FwClearInventory(source)` | boolean (true) | Removes every item returned by `InvGetItems` from the player's inventory |

```lua
for _, it in ipairs(exports.w_lib:FwGetInventoryItems(source)) do print(it.name, it.count) end
if exports.w_lib:FwCanCarryItem(source, "bread", 5) then exports.w_lib:FwAddItem(source, "bread", 2) end
exports.w_lib:FwAddWeapon(source, "WEAPON_REVOLVER_CATTLEMAN", 12)
exports.w_lib:FwCanCarryWeapon(source, 1, "WEAPON_REVOLVER_CATTLEMAN")
```

### Fw* offline (database) operations

```lua
exports.w_lib:FwGetOfflineInventory(charId: number|string)
exports.w_lib:FwAddItemOffline(charId: number|string, itemName: string, count?: integer)
exports.w_lib:FwRemoveItemOffline(charId: number|string, itemName: string, count?: integer)
exports.w_lib:FwAddWeaponOffline(charId: number|string, weaponName: string, ammo?: number|table)
exports.w_lib:FwRemoveWeaponOffline(charId: number|string, weaponId: number|string, weaponName?: string)
exports.w_lib:FwAddCurrencyOffline(identifier: string, currencyType: integer, amount: number)
exports.w_lib:FwRemoveCurrencyOffline(identifier: string, currencyType: integer, amount: number)
exports.w_lib:FwSetJobFullOffline(identifier: string, jobName: string, jobGrade: number)
exports.w_lib:FwSetJobLabelOffline(identifier: string, jobLabel: string)
exports.w_lib:FwSetJobGradeOffline(identifier: string, jobGrade: number)
exports.w_lib:FwGetJobOffline(identifier: string, charId: number|string)
exports.w_lib:FwSetPlayerJobOffline(identifier: string, charId: number|string, jobName: string, jobGrade: number, jobLabel: string)
exports.w_lib:FwRemoveJobOffline(charId: number|string)
exports.w_lib:FwSetNicknameOffline(identifier: string, charId: number|string, value: string)
exports.w_lib:FwSetFirstNameOffline(identifier: string, charId: number|string, value: string)
exports.w_lib:FwSetLastNameOffline(identifier: string, charId: number|string, value: string)
exports.w_lib:FwSetAgeOffline(identifier: string, charId: number|string, value: number)
exports.w_lib:FwSetDescriptionOffline(identifier: string, charId: number|string, value: string)
exports.w_lib:FwGetDiscordId(identifier: string)
```

Side: server

Parameters:
- `charId` (number|string): VORP `charidentifier` / RSG `citizenid`. In the `identifier, charId` pairs, `identifier` is the RSG citizenid (used on RSG) and `charId` the VORP charidentifier (used on VORP; required on VORP, nil returns `false, "character_not_found"`)
- `identifier` (string): VORP account identifier / RSG citizenid (VORP job and currency updates keyed only by identifier apply to every character of that identifier)
- `itemName` (string, required); `count` (integer, optional, default 1)
- `weaponName` (string): WEAPON_* name (required for `FwAddWeaponOffline`; optional for `FwRemoveWeaponOffline`, where it is used by w_inventory when `weaponId` is nil, by RSG, and by the native storage path)
- `ammo` (number|table, optional): ammo count or table (summed for w_inventory; ignored by the VORP loadout insert)
- `weaponId` (number|string, required): slot (or `"w<slot>"`), serial, or VORP loadout id
- `currencyType` (integer, required): 0 cash, 1 gold/bloodmoney, 2 rol/blkbank; `amount` (number, required; `FwRemoveCurrencyOffline` clamps the result at 0)
- `jobName` (string), `jobGrade` (number), `jobLabel` (string): job fields
- `value` (string or number): new field value

Returns: see table

| export | returns | notes |
|---|---|---|
| `FwGetOfflineInventory(charId)` | `table, table` - items array and weapons array read from the database (`{ name, count, weight, label, type, itemId, ... }`) | SQL, or w_inventory's native offline helpers when it runs in native storage mode |
| `FwAddItemOffline(charId, itemName, count?)` | `boolean, string?` - false plus a reason (`"Player not found"`, `"Item definition not found"`, `"Unknown framework"`, ...) on failure | Adds an item to an offline character's stored inventory |
| `FwRemoveItemOffline(charId, itemName, count?)` | `boolean, string?` | Removes an item offline |
| `FwAddWeaponOffline(charId, weaponName, ammo?)` | `boolean, string?` | Adds a weapon offline |
| `FwRemoveWeaponOffline(charId, weaponId, weaponName?)` | boolean | Removes a weapon offline |
| `FwAddCurrencyOffline(identifier, currencyType, amount)` | `boolean, string?` - false plus `"invalid_amount"`, `"invalid_data"` or `"economy_unavailable"` (also returned when no framework was detected), or `AdjustPlayer`'s answer | Through w_centralbank `AdjustPlayer` when it is started; without w_centralbank on a host with no w_core, a direct write to VORP `characters` (every character of the identifier) or RSG `players` |
| `FwRemoveCurrencyOffline(identifier, currencyType, amount)` | `boolean, string?` - same codes as `FwAddCurrencyOffline` | Same two paths, removing currency offline; the direct write is clamped at zero |
| `FwSetJobFullOffline(identifier, jobName, jobGrade)` | boolean | Sets job and grade offline (VORP: all characters of the identifier) |
| `FwSetJobLabelOffline(identifier, jobLabel)` | boolean | Sets the job label offline |
| `FwSetJobGradeOffline(identifier, jobGrade)` | boolean | Sets the job grade offline |
| `FwGetJobOffline(identifier, charId)` | `table|nil` - `{ name, label, grade, gradeName? }` | Reads a character's job from the database |
| `FwSetPlayerJobOffline(identifier, charId, jobName, jobGrade, jobLabel)` | boolean | Sets a single character's job offline (per character, unlike `FwSetJobFullOffline`); `jobLabel` is used on VORP |
| `FwRemoveJobOffline(charId)` | boolean - false on RSG | Resets the character to unemployed (VORP only) |
| `FwSetNicknameOffline(identifier, charId, value)` | `boolean, string?` | Offline nickname update |
| `FwSetFirstNameOffline(identifier, charId, value)` | `boolean, string?` | Offline first-name update |
| `FwSetLastNameOffline(identifier, charId, value)` | `boolean, string?` | Offline last-name update |
| `FwSetAgeOffline(identifier, charId, value)` | `boolean, string?` | Offline age update |
| `FwSetDescriptionOffline(identifier, charId, value)` | `boolean, string?` | Offline description update |
| `FwGetDiscordId(identifier)` | `string|nil` - discord id stored in `characters.discordid` (VORP only) | Reads the Discord id from the VORP characters table |

```lua
local items, weapons = exports.w_lib:FwGetOfflineInventory(charId)
local ok, err = exports.w_lib:FwAddItemOffline(charId, "bread", 1)
exports.w_lib:FwAddCurrencyOffline(identifier, 0, 100)
exports.w_lib:FwSetPlayerJobOffline(identifier, charId, "doctor", 0, "Doctor")
exports.w_lib:FwSetNicknameOffline(identifier, charId, "Jack")
local discord = exports.w_lib:FwGetDiscordId(identifier)
```

### Fw* server-wide statistics and shared definitions

```lua
exports.w_lib:FwGetTotalCash()
exports.w_lib:FwCountCharacters()
exports.w_lib:FwCountAllCharacters()
exports.w_lib:FwGetOfflineCharacters(searchTerm?: string, limit?: integer, extraIds?: string[])
exports.w_lib:FwGetCharactersWithDiscord(limit?: integer)
exports.w_lib:FwGetSharedItems()
exports.w_lib:FwGetSharedWeapons()
exports.w_lib:FwGetSharedJobs()
```

Side: server

Parameters:
- `searchTerm` (string, optional): LIKE filter on names / identifier / discord
- `limit` (integer, optional, default 200): row limit
- `extraIds` (table, optional): extra identifiers (VORP identifier / RSG license) to include when searching

Returns: see table

| export | returns | notes |
|---|---|---|
| `FwGetTotalCash()` | number - sum of cash over all characters | SQL |
| `FwCountCharacters()` | number - number of characters | SQL |
| `FwCountAllCharacters()` | number - number of accounts (VORP users table) / players (RSG) | SQL |
| `FwGetOfflineCharacters(searchTerm?, limit?, extraIds?)` | table - array of `{ charId, identifier, cacheKey, firstName, lastName, nickname, jobName, jobLabel, jobGrade, cash, gold, lastLogin, discordid }` | Character list for admin panels (SQL) |
| `FwGetCharactersWithDiscord(limit?)` | table - array of `{ identifier, discordid }` (VORP only; `{}` otherwise) | Distinct identifiers that have a discord id |
| `FwGetSharedItems()` | table - RSG/QBR `Core.Shared.Items`; `{}` on VORP | Shared item definitions of QB-style cores |
| `FwGetSharedWeapons()` | table - `Core.Shared.Weapons`; `{}` on VORP | Shared weapon definitions of QB-style cores |
| `FwGetSharedJobs()` | table - `Core.Shared.Jobs`; `{}` on VORP | Shared job definitions of QB-style cores |

```lua
print(exports.w_lib:FwGetTotalCash(), exports.w_lib:FwCountCharacters())
local rows = exports.w_lib:FwGetOfflineCharacters("john", 50)
local jobs = exports.w_lib:FwGetSharedJobs()
```

### Events

| name | side | payload | meaning |
|---|---|---|---|
| `w_lib:inventory:listenerItemRemoved` | server (local, non-net) | `source: integer, item: string, data: { quantity: number, metadata?: table }, reason?: string` | Consumed by `w.framework:listenItemRemoved` in every resource that loaded the module (`AddEventHandler`, so `TriggerEvent` from any server resource reaches it). Emitted inside the library only by the vorp v1/v2 and rsg v2 adapters; an inventory integration can `TriggerEvent` it to notify all consumer resources. `reason` (e.g. `"dropped"`) is received by the handler but not passed to listeners. No generic `inventory:OnItemRemoved` bridge is active in this build. |
| `w_lib:client:applySkinAndClothes` | client (net) | `ped: integer|nil, skin: table, clothes: table` (standard data; nil ped = the player's ped) | Registered once inside the library. Waits for the ped to load, then (debounced 100 ms per ped) runs hook `w_lib:applySkinAndClothes:before`, applies skin and components via `w.component`, refreshes the ped, then `w_lib:applySkinAndClothes:after`. Does nothing if the component module is not loaded. Can also be `TriggerEvent`ed locally on the client. On VORP the library itself sends it on `vorpcharacter:reloadedskinlistener`. |
| `w_lib:client:applySkin` | client (net) | `ped: integer|nil, skin: table` | Applies only the skin (hooks: `w_lib:applySkin:before`, then `w_lib:applySkinAndClothes:after` - the source reuses that name). Debounced 100 ms per ped; needs the component module. |
| `w_lib:client:applyClothes` | client (net) | `ped: integer|nil, clothes: table` | Applies only clothes components (hooks `w_lib:applyClothes:before/after`). Debounced 100 ms per ped; needs the component module. |
| `w_lib:server:applySkinAndClothes` | server (net) | `ped: integer|nil, skin: table|string, clothes: table|string` (core format, table or JSON) | For a client to have core-format data standardised and sent back to itself as `w_lib:client:applySkinAndClothes`. The teeth component is moved from clothes into `skin.teeth`. On VORP ignored once the player already has a selected character. |
| `w_lib:server:applyClothes` | server (net) | `ped: integer|nil, clothes: table|string` | Standardises and echoes clothes back to the calling client as `w_lib:client:applyClothes`. Not gated on VORP. |
| `w_lib:server:applySkin` | server (net) | `ped: integer|nil, skin: table|string` | Standardises and echoes the skin back to the calling client as `w_lib:client:applySkin`. Ignored on VORP once a character is selected. |
| `w_lib:client:openInventory` | client (net) | `name: string, config: { maxWeight: number (passed as maxweight), maxSlots: integer (passed as slots) }` | Registered inside the library only by the qbr core, the qr core and the rsg v1 inventory adapters; forwards to `inventory:server:OpenInventory 'stash'` and `inventory:client:SetCurrentStash`. Legacy transport of those adapters' `openInventory`, now overridden by the `_custom` adapter. Not registered on VORP/w_inventory. |

### Convars

| name | side | value | meaning |
|---|---|---|---|
| `w_lib:inventory` | server | `setr w_lib:inventory "auto"` (default) or `"w_inventory"`, `"vorp_inventory"`, `"rsg-inventory"`, `"qbr-inventory"` (aliases: w, ox, vorp, rsg, qbr) | Read by the library's inventory bridge (the `Inv*` exports the `_custom` adapter delegates to). Ignored whenever w_inventory is started (w_inventory always wins). Otherwise `"auto"` picks the first started of w_inventory, rsg-inventory, qbr-inventory, vorp_inventory; a name forces that adapter (an invalid name or a not-yet-started resource prints a warning and the bridge reports not ready). The chosen adapter is published in `w_lib:activeInventory` and returned by `exports.w_lib:InvName()` / `FwInventory()`. |
| `w_lib:activeInventory` | shared (replicated) | `GetConvar("w_lib:activeInventory", "")` - active inventory resource name, `""` until the bridge has resolved one | Written by the server inventory bridge (`SetConvarReplicated`) once it has chosen an adapter. Read-only for consumer resources; the client inventory bridge uses it so client and server agree on the active inventory. |

### Commands

This module registers no commands.

## The w.citizen module (one citizen id for every player target)

Every input that names another player takes the **citizen id** (`players.citizenid`: `'1'`, `'12'`, a vanity `'777'`), never a server id. A server id changes on every connection and, since the citizen id is plain digits, the two collide: a form that asked for "the player's id" answered "player not found" to a citizen id, or hit whoever held that server id. `w.citizen` says who an id is and whether he is in the game right now. When he is, his server id comes with the answer, so nobody has to look it up. When he is not, the feature takes its offline path, or tells the user that the player must be online.

The module loads like any other: touch `w.citizen`, call `w.require("citizen")` or list it under `w_module { 'citizen' }`. `shared.lua` (normalize, parse, label, the locale strings) and `server.lua` or `client.lua` run inside your resource.

| Side | Functions |
|---|---|
| shared | `normalize`, `parse`, `label`, `reasonKey`, `reasonText`, `text` |
| server | `resolve`, `requireOnline`, `fromSource`, `idOf` |
| client | `myId`, `inputRow` |

### What can be typed

| Input | Meaning |
|---|---|
| `'12'`, `' 12 '`, `'012'`, `'١٢'` | Citizen id 12. Surrounding spaces, invisible bidi or zero-width marks, no-break spaces and leading zeros are dropped. Arabic-Indic and Persian digits count as digits. |
| `12` (a Lua number) | Citizen id 12. A number given to `resolve` is **always** a citizen id. Use `fromSource` for a server id you already hold. |
| `'omg95204'`, `'OMG95204'` | The old random form (3 letters + 5 digits), upper-cased. Accepted until the migration has run everywhere. |
| `'#7'`, `'# 7'`, `'＃٧'` | An explicit **server** id: the character in play on server id 7 (1..65535). |
| `'me'` | The caller, only when `resolve` is given `{ self = source }`. |
| a target table | Asked again by its `citizenid` (is he still online?). A table holding only a `source` is treated like `fromSource`. |

Anything else is `'invalid_id'`: letters, `'0'`, more than 9 digits, or an empty string. The rules match w_core's `C.Normalize`. They live in the library as well, so a client dialog can refuse a malformed id before it asks the server.

### The target table

```lua
{
    citizenid = '12',            -- string, canonical form
    source    = 7,               -- server id while the character is in play, nil otherwise
    online    = true,            -- source ~= nil
    name      = 'John Doe',      -- character first + last name ('' when the character has none)
    license   = 'license:...',   -- account identifier (players.license; VORP: characters.identifier)
    row       = { ... },         -- offline only: the saved row (w_core: citizenid, cid, license, name, charinfo, job, gang, last_updated)
}
```

Store `citizenid`, never `source`. Use `source` only for something that happens now (a client event, a notification, a teleport).

### Where the answer comes from

- **w_core running**: `exports.w_core:ResolveCitizen` (w_core `server/citizen.lua`, the owner of the id). An online character is found in `WCore.Players`. Otherwise its `players` row is read. Inside w_core itself `WCore.Citizen.Resolve` is called directly, which also works while w_core is still `starting`. A player who dropped between w_core's read and the answer comes back as offline.
- **no w_core** (another core), or an older w_core without that export, or an export error: the library's `Fw*` bridge answers instead. It scans the online players with `FwGetCharacterIdentifier` / `FwGetCharacterName` / `FwGetIdentifier`, then falls back to `FwCharacterRows('citizenid', id)`. That reads `players` on RSG-family cores and `characters.charidentifier` on VORP.

### w.citizen.resolve

```lua
w.citizen.resolve(input: any, opts?: { self?: integer }) -> target | nil, reason
```

Side: server

Parameters:
- `input` (any, required): see [What can be typed](#what-can-be-typed)
- `opts.self` (integer, optional): the caller's server id, so `'me'` names him

Returns: the target, or `nil` and `'invalid_id'` (not an id) / `'not_found'` (no such character; nobody on that server id; a connected player with no character in play yet)

Who the id is, online or not. Use it for every action that works without the player present: hiring, ownership, money, items, a job, a record, a warrant. The database write uses `target.citizenid`. The live part (a notification, a HUD refresh) runs only `if target.online`.

```lua
local target, reason = w.citizen.resolve(data.citizenid)
if not target then return false, w.citizen.reasonText(reason, source) end
MySQL.insert.await('INSERT INTO my_employees (citizenid, name) VALUES (?, ?)', { target.citizenid, target.name })
if target.online then TriggerClientEvent('my_res:client:hired', target.source) end
```

### w.citizen.requireOnline

```lua
w.citizen.requireOnline(input: any, opts?: { self?: integer }) -> target | nil, reason, offlineTarget?
```

Side: server

Returns: the target when he is in the game. Otherwise `nil` and `'invalid_id'` / `'not_found'` / `'offline'`. With `'offline'`, the offline target comes as a third value, so the message can still name him.

For actions that need the player present: teleport, revive, spectate, a private message, a live jail.

```lua
local target, reason, offline = w.citizen.requireOnline(args.target, { self = source })
if not target then
    local text = w.citizen.reasonText(reason, source)
    if offline then text = ('%s: %s'):format(w.citizen.label(offline), text) end
    return w.notify(source, { description = text, type = 'error' })
end
SetEntityCoords(GetPlayerPed(target.source), GetEntityCoords(GetPlayerPed(source)))
```

### w.citizen.fromSource and w.citizen.idOf

```lua
w.citizen.fromSource(serverId: integer|string) -> target | nil, 'invalid_id' | 'not_found'
w.citizen.idOf(serverId: integer|string) -> string | nil
```

Side: server

`fromSource` is for a server id your code already holds and a user did not type: a player picked from a nearby list, the `source` of an event. It returns the same target table. It answers `'not_found'` when nobody is on that id or the player has no character in play yet (the character selection screen). `idOf` returns only the citizen id of the character in play on that server id: the value to store.

```lua
local owner = w.citizen.idOf(source)   -- '12'
```

### w.citizen.normalize and w.citizen.parse

```lua
w.citizen.normalize(value: any) -> string | nil
w.citizen.parse(input: any) -> 'citizen', string | 'server', integer | 'self' | nil
```

Side: shared

`normalize` returns the canonical citizen id (`' 007 '` gives `'7'`, `'omg95204'` gives `'OMG95204'`, `12` gives `'12'`) or nil. `parse` only says what kind of id was typed. It asks nobody, so a client can validate a field with it.

### w.citizen.label

```lua
w.citizen.label(target: table|nil) -> string
```

Side: shared

`'John Doe (12)'` for a notification or a log line. It gives just `'12'` when the character has no name, and `''` without a target.

### w.citizen.reasonKey, w.citizen.reasonText and w.citizen.text

```lua
w.citizen.reasonKey(reason: string|nil) -> string          -- 'citizen.invalid_id' | 'citizen.not_found' | 'citizen.offline'
w.citizen.reasonText(reason: string|nil, src?: integer) -> string
w.citizen.text(name: string, src?: integer) -> string      -- 'label' | 'placeholder' | 'help' | 'invalid_id' | 'not_found' | 'offline'
```

Side: shared

The strings live in w_lib's own `locales/<lang>.json` under `"citizen"`, so every resource uses the same words for the same failure. On the server, `src` picks that player's language (`getPlayerLocaleKey`). Without it, and on the client, the language of that side is used. A missing language falls back to English. An unknown reason reads as not found.

| key | en | ar |
|---|---|---|
| `citizen.label` | Citizen ID | رقم المواطن |
| `citizen.placeholder` | e.g. 12 | مثال: 12 |
| `citizen.help` | The player's fixed citizen ID. For a server ID put # in front (e.g. #5) | رقم المواطن الثابت. لرقم السيرفر اكتب # قبله (مثل #5) |
| `citizen.invalid_id` | Invalid citizen ID | رقم المواطن غير صحيح |
| `citizen.not_found` | No player with this ID | لا يوجد لاعب بهذا الرقم |
| `citizen.offline` | The player is not online right now | اللاعب غير متصل الآن |

### w.citizen.myId and w.citizen.inputRow (client)

```lua
w.citizen.myId() -> string | nil
w.citizen.inputRow(overrides?: table) -> table
```

Side: client

`myId` returns the local character's citizen id. It is nil before a character is in play, and on cores that keep no player data on the client (VORP). It reads the core's player data on every call, so use it in menus and not in every frame. `inputRow` returns a `lib.inputDialog` / `w.inputDialog` row that asks for a citizen id, with the label, placeholder and `#` hint in the player's language. `overrides` replaces any of its fields.

```lua
local input = w.inputDialog('Hire', { w.citizen.inputRow() })
if not input then return end
if not w.citizen.parse(input[1]) then
    return w.notify({ description = w.citizen.reasonText('invalid_id'), type = 'error' })
end
local ok, message = lib.callback.await('my_res:hire', false, input[1])   -- send the text as typed
```

### exports.w_lib:Citizen* (resources without the loader)

A resource that does not load `@w_lib/init.lua` reaches the same functions through exports. They run in w_lib's VM:

| Export | Same as |
|---|---|
| `exports.w_lib:CitizenResolve(input, opts)` | `w.citizen.resolve` |
| `exports.w_lib:CitizenRequireOnline(input, opts)` | `w.citizen.requireOnline` |
| `exports.w_lib:CitizenFromSource(serverId)` | `w.citizen.fromSource` |
| `exports.w_lib:CitizenIdOf(serverId)` | `w.citizen.idOf` |
| `exports.w_lib:CitizenNormalize(value)` | `w.citizen.normalize` |
| `exports.w_lib:CitizenLabel(target)` | `w.citizen.label` |
| `exports.w_lib:CitizenReasonKey(reason)` | `w.citizen.reasonKey` |
| `exports.w_lib:CitizenReasonText(reason, src)` | `w.citizen.reasonText` |
| `exports.w_lib:CitizenText(name, src)` | `w.citizen.text` |

All of them are server-side.

### Patterns

- **Forms (NUI or dialogs)**: one field, labelled with the citizen id (`w.citizen.text('label')` / your locale). Send the text as typed. Do not strip non-digits and do not `Number()` it: old ids contain letters, and `'#5'` is a server id.
- **Commands**: a command that only acts on a player in the game can keep `type = 'playerId'`. That parser reads the citizen id through `requireOnline` (and `'#5'` as a server id, `'me'` as the caller), hands the handler the live server id, and tells the caller why it refused (`invalid_id` / `not_found` / `offline`). A command that also works on an offline character declares the argument with **no** `type` (the raw text arrives; `type = 'string'` refuses anything `tonumber` reads, so `12` would never reach the handler) and resolves it with `resolve`, passing `{ self = source }` when `me` should work.
- **Lists the user picks from** (nearby players, the online list): these already carry a server id. Use `fromSource` and store `target.citizenid`.
- **Messages**: `w.citizen.reasonText(reason, source)`, prefixed with `w.citizen.label(target)` when you have one.

## The w.settings module (live settings edited from the admin console)

`w.settings` lets the admin console (w_admin: Scripts hub, Food & drink) change a resource's settings while the server runs. Every value comes with a plain explanation in Arabic and English. The resource stays the authority: it validates every change again, saves it, writes it into its own `Config` in place, and sends the client half to every player. w_admin only draws the page, checks its own levels and asks. Only data crosses resources, never functions (a function turns into a funcref on the way).

The module loads like any other (touch `w.settings`). `shared.lua` (constructors, the validator, `define`) and `server.lua` or `client.lua` run inside your resource. The server-console command lives in `g_server.lua`, inside w_lib.

### Opting in

Two lines in the manifest, and one shared file loaded **last** in `shared_scripts` (after everything that builds the `Config` it edits):

```lua
shared_scripts {
    '@w_lib/init.lua',
    'shared/config.lua',
    -- ...
    'shared/settings_schema.lua', -- LAST
}
w_settings 'yes'                   -- w_admin finds the resource by this line (GetResourceMetadata)
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/*.lua' }   -- the central store needs oxmysql
```

There is no registry: w_admin scans the resources for `w_settings 'yes'`. Start order and restarts need no handling.

### w.settings.define

`w.settings.define(spec) -> handle` (shared, once per resource)

| Field | Meaning |
|---|---|
| `version` | Your schema version (information only). |
| `access(src) -> boolean` | The resource's own admin test (server). The console (src 0) always passes. |
| `accessAce` | The ACE named in the refusal (`no_access`). |
| `links` | `{ { id, command, level? } }`: "open its own interface" buttons (texts under `settings.links.<id>`). |
| `groups` | See below. |

A **group** is either a form or a table:

| Field | Meaning |
|---|---|
| `id` | Letters, digits, `_` and `-` (no dots). |
| `store` | `'central'` (default): one row per changed key in `w_admin_settings`. `'own'`: your existing save path (`apply`). |
| `clientVisible` | The clients read these values. Central values are pushed to every client. |
| `level` | The w_admin level this group needs (`'god'` for economy). By default, the resource's level. |
| `fields` | A form: a list of fields (keys may contain dots: `needs.hungerRate`). |
| `rows()`, `columns` | A table: one row per item. `rows()` returns `{ { id, label?, family?, image?, locked? } }`. `locked` is a text key or `{ ar, en }` that says why the row cannot change. A cell's key is `<group>.<row>.<column>`. |
| `describe(id) -> { label?, image? }` | Row labels and pictures that cost something (another resource's catalogue). Asked only when the page opens the table. |
| `families` | `{ { id } }`: the table's filter chips and bulk-edit scopes (texts under `settings.<group>.families.<id>`). |
| `readOnly` | `{ { key, read(row) } }`: columns shown but never edited. |
| `checkRow(row, cells, changed) -> reason?` | Refuses a combination on one row (for example a buff strength without a buff). |
| `apply(changes, actor) -> ok, err` | Own groups only: save the changes. `changes = { { key, value, old, reset } }`. |
| `onChange(changes, actor)` | Runs after a successful apply (for example, re-applying a satchel bonus to its owners). |

The handle offers `onChange(fn)`, `apply(changes, actor)` (your own panel can use it), `values(group?)`, `schema()`, `get(key)` and `ready()`.

```lua
WHudLive = w.settings.define({
    resource = 'w_hud', version = 1, accessAce = 'w_hud.admin',
    access = function(src) return WHudAdmin.isAdmin(src) end,
    links = { { id = 'hudmenu', command = 'hudmenu' } },
    groups = {
        { id = 'needs', store = 'own', clientVisible = true, apply = ownApply, fields = {
            w.settings.number({ key = 'needs.hungerRate', min = 0, max = 25, step = 0.1, default = 1,
                read = function() return WHudSrv.needs.hungerRate end }),
        } },
        { id = 'food', store = 'central', clientVisible = true, rows = foodRows, describe = describeItem,
          families = { { id = 'fruit' }, { id = 'meat' } },
          columns = {
            w.settings.number({ key = 'hunger', min = -50, max = 100, step = 1, integer = true,
                read = function(row) return Config.Consumables[row].hunger or 0 end,
                write = function(row, v) Config.Consumables[row].hunger = v ~= 0 and v or nil end }),
        } },
    },
})
```

### Fields and columns

`w.settings.number / bool / enum / text / list(def)` set `def.type` and return `def`.

| Key | Types | Meaning |
|---|---|---|
| `key` | all | The stored key. A column key has no dots. |
| `read()` / `read(row)` | all | The value in effect now. Never return nil (use 0, false, `'none'`). |
| `write(v)` / `write(row, v)` | central | Write the value into your Config. Called on the server and on every client. |
| `default` | own | The code default of an own value (a value or `function(row)`). Central defaults are captured automatically: the value before the first override. |
| `min`, `max`, `step`, `integer` | number | Out of range or off the step is **refused**, never clamped. |
| `options` | enum | `{ { value } }`. Texts: `<base>.options.<value>` (`''` is written `none`). |
| `maxLength`, `pattern` | text | Longer text is refused, never cut (a cut could split an Arabic letter). |
| `item`, `maxItems` | list | The item's field definition and the list's limit. |
| `validate(v) -> reason?` | all | Your own rule (server only; it does not travel in the schema). |
| `requiresRestart` | all | Saved now, written at the next start. |
| `advanced` | all | The page hides it behind "all columns / advanced". |
| `derived` | all | `{ kind, args }`: a calculated hint the page computes (`drainTime`, `deathTime`, `buffTime`, `kg`, ...). |
| `unit`, `label`, `help`, `example`, `danger`, `confirm` | all | A text key or `{ ar, en }`. By default they are read from `<base>.<sub>`. |

### Texts

Every text is read from **your** `locales/ar.json` and `locales/en.json` when the schema is built, so the schema always carries both languages. Keys follow the definition:

| What | Key |
|---|---|
| title, description | `settings.title`, `settings.description` |
| group | `settings.<group>.label`, `.help`, `.confirm` |
| field | `settings.<field key>.label`, `.help`, `.example`, `.unit`, `.danger`, `.confirm` |
| column | `settings.<group>.<column>.label`, ... |
| option | `settings.<...>.options.<value>` |
| family, read-only column | `settings.<group>.families.<id>`, `settings.<group>.readOnly.<key>` |
| link | `settings.links.<id>.label`, `.help` |

Write help for ordinary people: start with a verb that says the effect, say who notices, whether it can be undone, and give an example with units. At most 240 characters.

`w.settings.textOf(key) -> { ar, en } | nil` reads one of them. `w.settings.reloadTexts()` drops the cache.

### The three exports

`define` registers them inside your resource (server):

| Export | Returns |
|---|---|
| `WSettingsSchema()` | `{ resource, version, title, description, links?, groups = { { id, label, help, confirm?, store, clientVisible, type, level?, fields } } }`. A table group has one field `{ key = group id, type = 'table', columns, families?, readOnly? }`. |
| `WSettingsValues(group?)` | `{ values, defaults, overridden = { [key] = { by, at, base } }, rows?, orphans }`. Without a group: every form group. For a table group: `rows = { { id, label, image, family, locked?, cells, defaults, overridden = { column... } } }`. |
| `WSettingsApply(changes, actor)` | `{ ok, applied = { { key, value, old, reset? } }, rejected = { { key, reason } }, batch }`. `changes` is a dense array of `{ key, from, to }` or `{ key, from, reset = true }` (at most 500, 256 KB). `actor = { src, cid, name, via, note }`. |

The rules inside `WSettingsApply`:

1. Only `w_admin`, `w_lib` (the console command) and the resource itself may call it.
2. The actor passes `access(src)` (the console always does).
3. **All or nothing.** The reasons are `unknown_key`, `out_of_range`, `bad_type`, `locked_row`, `stale`, `duplicate`, `too_many`, `too_large`, `no_access`, `not_ready`, `rate_limited` (more than 2 applies a second), `safe_mode` and `db_error`.
4. **Compare-and-set.** `from` must equal the value in effect, or the change is `stale`. This covers two admins, or your own panel, editing the same value.
5. **Order.** Own groups save (`apply`). Then the central rows and the audit rows are written in one transaction. Then `write` runs, then `onChange`, then the push. A failed save applies nothing: own groups already saved are rolled back with their old values.

A central value equal to its code default is not stored: its row is deleted. Resetting a stored value that is not applied (an orphan) only deletes its row.

### Storage, boot and drift

```sql
w_admin_settings        (resource, skey) PK, value, base, updated_at, updated_by
w_admin_settings_audit  id, batch, resource, skey, old_value, new_value (NULL = back to the default),
                        actor_cid, actor_name, actor_src, via, note, created_at
w_admin_settings_presets id, name, data, created_by, created_at
```

`w.settings.ensureTables()` creates them. The module and w_admin both run it, so whichever starts first creates them. `updated_by`, `actor_cid` and `created_by` hold citizen ids (history for w_core's citizen registry).

At boot, a thread reads the resource's rows in declaration order (a buff type before its strength). It captures each original value and writes the stored one. A row whose field or row no longer exists, whose row is now locked, or whose value no longer passes validation is listed as an **orphan**. Orphans are shown, never applied and never deleted automatically. Each row keeps `base`, the code default it replaced. When the code later changes that default, the override still applies, and the page compares `overridden[key].base` with `defaults[key]` to say "the default changed after your edit" and offer "keep mine" (re-apply the same value, which re-bases it) or "take the new one" (reset).

### The client side

The client module keeps the client's `Config` in step. The snapshot holds every central value of a `clientVisible` group that is in effect.

- **When it starts** (a player who joins later, or a restart), it asks for the snapshot through the callback `<resource>:w_settings:snapshot`.
- **After every change**, it receives the snapshot through the net event `<resource>:w_settings`, 100 ms after the last change.

Each value goes through the **same** `write` function the server uses. A key that left the snapshot gets its original value back. Readers that look `Config.*` up when they run see the change without any edit.

### Validation helpers

| Function | Meaning |
|---|---|
| `w.settings.check(field, value) -> reason?` | Type, range, step, options, length, pattern (plain data: works on a schema field). |
| `w.settings.checkField(field, value)` | `check` plus the field's own `validate`. |
| `w.settings.index(groups)` | The key lookup of a definition or a schema. |
| `w.settings.locate(index, key) -> kind, field, group, row` | `'field'` or `'cell'`. |
| `w.settings.checkChanges(index, changes, opts?) -> list, rejected` | The shape of a batch. The resource passes `opts.current` and `opts.row` for compare-and-set and locks. |
| `w.settings.copy(v)`, `w.settings.equal(a, b)` | Deep copy, and equality (numbers within 1e-9). |
| `w.settings.cellKey(group, row, col)` | `'<group>.<row>.<col>'`. |

### Safe mode and the console command

| Convar / command | Effect |
|---|---|
| `setr w_settings:safe 1` | Every resource boots with its code defaults. Its stored central values are listed as orphans (reason `safe`), and new central values are refused (`safe_mode`). Resets still work, so a bad value can be removed. |
| `wsettings list` | The resources that opted in, and how many values were changed (server console only). |
| `wsettings show <resource>` | The changed values, with their defaults, and the orphans. |
| `wsettings reset <resource> [key]` | Back to the code default: one key, or every changed value. |

## Shared utility modules under lib.* (data structures, strings, math, classes, commands, logging)

### How these utilities reach a consumer resource

Everything in this section is made available by one manifest line: `shared_script '@w_lib/init.lua'`, placed first among the shared scripts of the consumer resource. `lua54 'yes'` is mandatory (the loader raises at startup without it), and the library must be started before the consumer resource or the loader raises as well.

`init.lua` does not proxy these utilities through exports. The first time the consumer resource touches `lib.<name>`, the loader reads `w_lib/imports/<name>/shared.lua` plus the `server.lua` or `client.lua` half and runs it inside the consumer resource's own Lua state. The first time it touches `w.<name>` (alias `jo.<name>`), the w layer does the same with `w_lib/modules/<name>/`. Everything in this subsystem therefore runs in-process: real Lua functions can be passed (heap comparators, array callbacks, grid filters, command handlers, class methods) and instances keep their metatables. Only when no `imports/<name>` file exists does `lib.<name>` fall back to `exports.w_lib:<name>`. The one place that happens inside this subsystem is `lib.addCommand` with `restricted`, which calls `lib.addAce`; that resolves to the export defined by the library's ACL module, which runs `add_ace` through `ExecuteCommand`. Nothing here expects a function to cross an export boundary.

The modules `table`, `print`, `file`, `math` (and `string`, pulled in by `print`) and `trigger-event` are loaded in every consumer resource at startup. `date`, `utils`, `bucket` and `database` load lazily the first time `w.date`, `w.utils`, `w.bucket` or `w.database` is indexed (or `w.require('date')` is called). Imports can be preloaded with the manifest line `w_lib { 'array', 'class' }`; note that an import whose value is a function, such as `addCommand`, is called once with no arguments by that preload. Modules can be preloaded with `w_module { 'date' }`. `modules/utils` also has a `client.lua` half with more functions (`loadGameData`, `releaseGameData`, `waiter`, and others) that belongs to another subsystem.

### Name collisions and which version wins

`lib.table`, `lib.string` and `lib.math` are the standard Lua tables themselves (the imports assign `lib.math = math` and so on), and the w modules also write onto the same globals. The loader deliberately imports the ox-derived extensions first and then loads the w modules, so the w module version wins for:

- `math.round` (floors; it does not round half up)
- `math.clamp` (no bound swapping)
- `math.lerp` (plain `a + (b - a) * t`, not a per-frame iterator)
- `table.merge` (signature `table.merge(deepMerge?, t1, t2, ...)`, mutates `t1`)
- `table.map` (callback receives `value, key, table`)

Everything else coexists. ox-only: `math.interp`, `math.groupdigits`, `math.hextorgb`, `math.tohex`, `math.torgba`, `math.toscalars`, `math.tovector`, `math.normaltorotation`, `table.contains`, `table.matches`, `table.deepclone`, `table.shuffle`, `table.freeze`, `table.isfrozen`, `string.random`. w-only: `math.toHex`, `math.fromHex`, `math.toSigned`, the `table.copy`/`table.filter`/`table.find` family and the `string:split`/`string:trim` methods.

`w.table`, `w.math` and `w.string` are empty marker tables created by `w.createModule`; the functions live on the Lua globals, so write `table.copy(t)`, not `w.table.copy(t)`. Also note that after `init.lua` runs, the global `require` is replaced by `lib.require`, and `rawset` refuses to write into frozen tables.

### Classes and containers

`lib.class(name, super?)` returns a class table. Instances are created with `Class:new(...)` (colon call), the initialiser is defined as `function Class:constructor(...)`, and `self:super(...)` inside it runs the parent constructor. Any field assigned to `self.private` inside the constructor becomes private: reading it from outside a method of that class returns nil and writing raises an error. If the constructor assigns nothing to `self.private`, the field is removed (`self.private` is nil afterwards), so methods that need private state must have the constructor create at least one private field. `instance:instanceOf(Class)` walks the inheritance chain; `instance:isClass(Class)` checks the exact class.

`lib.array`, `lib.heap`, `lib.lru`, `lib.map`, `lib.set`, `lib.ringbuffer` and `lib.selector` are all such classes (always construct with `:new`). The containers support the `#` operator and `pairs()`; `lib.map` and `lib.set` also serialise correctly through `json.encode` and msgpack, so they can be sent over events and arrive as plain tables. `lib.array` is a plain sequence with a metatable, so it works with `ipairs`, `table.unpack` and `table.concat`.

### Loading code and data

`lib.require('a.b')` caches and detects circular loads; `lib.load('a.b')` runs the chunk every time; `lib.loadJson('a.b')` decodes `a/b.json`. Dots become slashes, `package.path` is `./?.lua;./?/init.lua`, and the resource searched is the consumer resource unless the name starts with `@otherResource.`. All three use `LoadResourceFile`: on the server that reads from disk; on the client the file must be listed in the owning resource's `files {}`. `w.file.load` has a different default: a name without `@` is looked up inside `w_lib/modules/`, so a consumer resource must always write `w.file.load('@myres.data.items')`. `lib.getFilesInDirectory` is server only and lists real files on disk relative to the consumer resource folder.

### Console, logs, commands, database

`lib.print.<level>` honours the convars `w_lib:printlevel` and `w_lib:printlevel:<resource>` (error < warn < info < verbose < debug; default info). The global functions `log`, `sprint`, `eprint`, `gprint`, `oprint`, `wprint`, `bprint` and `dprint` from the print module colour their output and prefix the resource name on the server. `dprint` prints when `Config.debug` is true in the consumer resource or the convar `<resource>:debug` is `on`; the module-level convars `<resource>:debug:<module>` and `all:debug:<module>` only affect `dprint` calls made from inside the library's own module files (the module name is taken from the chunk path `@@w_lib/modules/<module>/...`), so they do not enable `dprint` in consumer scripts.

`lib.logger` is server only, buffers for 500 ms and POSTs to Datadog, Loki or Fivemanage depending on `w_lib:logger`. With datadog or fivemanage an empty key convar turns it into a no-op; with loki it always posts.

`lib.addCommand` parses typed parameters, sends chat suggestions and registers ace restrictions. Read the parameter table rules in its entry: a `string` parameter rejects numeric-looking input, `longString` only works as the last parameter, and `false` rather than `{}` must be passed for no properties.

`w.database` helpers build SQL by string concatenation with no escaping, run synchronously with `MySQL.*.await` (call them from a script body or `CreateThread`) and require oxmysql to be started; indexing `w.database` runs oxmysql's `lib/MySQL.lua` inside the consumer resource so the `MySQL` global becomes available there.

`w.bucket` keeps a per-resource list of players per routing bucket that is only updated by the server event `onPlayerBucketChange(source, newBucket, oldBucket)`, which nothing in the library triggers: fire it from the consumer resource right after `SetPlayerRoutingBucket` or the list stays empty.

### Manifest setup

```lua
shared_script '@w_lib/init.lua'
-- optional preloads:
w_lib { 'array', 'class' }
w_module { 'date', 'utils' }
```

Side: shared

Parameters:
- `w_lib` (string[] metadata, optional): names of `imports/<name>` modules to load eagerly at startup instead of on first use of `lib.<name>`. An import whose value is a function (for example `addCommand`) is called once with no arguments by this preload, which is harmless for the functions in this subsystem but pointless; preload data-structure and class imports only.
- `w_module` (string[] metadata, optional): names of `modules/<name>` to load eagerly; otherwise `w.<name>` loads lazily on first access. `table`, `print`, `file`, `math`, `trigger-event` (and `string`, pulled in by `print`) are always loaded.

Returns: nothing

Required to use anything in this document. Put it first among the shared scripts and set `lua54 'yes'`; the library must be started before the consumer resource or `init.lua` raises. It creates the globals `lib`, `w` (alias `jo`), `cache` and `DataView`, replaces the global `require` with `lib.require`, loads the ox-derived table/string/math extensions and then the w modules (the w versions win on name conflicts, see above).

```lua
fx_version 'cerulean'
lua54 'yes'
games { 'rdr3' }
shared_scripts { '@w_lib/init.lua', 'config.lua' }
w_module { 'date' }
```

### lib.require, lib.load and lib.loadJson

```lua
lib.require(modName: string): any            -- also the global require
lib.load(filePath: string, env?: table): any
lib.loadJson(filePath: string): table
```

Side: shared

Parameters:
- `modName` / `filePath` (string, required): module name with dots as path separators. For `lib.require` it is resolved against `package.path` (`./?.lua;./?/init.lua`) inside the calling resource; `lib.load` uses the same naming; `lib.loadJson` takes the path without the `.json` extension. Prefix `@otherResource.` to load from another resource. A non-string raises.
- `env` (table, optional, `lib.load` only): environment table for the chunk; default the caller's globals.

Returns:
- `lib.require`: whatever the chunk returns, or `true` when it returns nil. Cached: later calls return the same value.
- `lib.load`: the chunk's return value, freshly evaluated on every call.
- `lib.loadJson`: the decoded JSON table.

All three load through `LoadResourceFile`: on the server any file on disk works; on the client the file must be declared in the owning resource's `files {}`. `lib.require` tries, in order, the original FiveM `require` (under pcall), `package.preload[modName]` (loader functions may be registered there), then the resource file search. It raises with the list of tried paths when nothing is found, and raises `circular-dependency` if a module requires itself while loading. `package.loaded` is read-only. `lib.load` raises `file not found` with the tried paths; `lib.loadJson` raises when the file is missing.

```lua
local Config = lib.require('config')                         -- config.lua or config/init.lua
local Shared = lib.require('@w_inventory.modules.items.shared')
local Items  = lib.load('data.items')                          -- data/items.lua, re-run every call
local locale = lib.loadJson('locales.ar')                      -- locales/ar.json
```

### lib.print

```lua
lib.print.error(...)
lib.print.warn(...)
lib.print.info(...)
lib.print.verbose(...)
lib.print.debug(...)
```

Side: shared

Parameters:
- `...` (any, optional): values joined with a tab; tables are json-encoded (sorted keys, indented, functions shown as `tostring`).

Returns: nothing

Prints `^5[resource] <prefix> message^7` where the prefix is `[ERROR]` (red), `[WARN]` (yellow), `[INFO]`, `[VERBOSE]` (blue) or `[DEBUG]` (magenta). Output is suppressed when the level is above the configured print level (error=1, warn=2, info=3, verbose=4, debug=5; default info, so debug and verbose are hidden). The level comes from the convar `w_lib:printlevel:<resource>`, falling back to `w_lib:printlevel`. It is re-read live where `AddConvarChangeListener` exists; otherwise it is fixed at load.

```lua
lib.print.info(('[w_survival] ready %s'):format(json.encode(state)))
lib.print.error(err)
lib.print.debug('payload', data)
```

### Global console helpers: log, sprint, eprint, gprint, oprint, wprint, bprint

```lua
log(...)  sprint(...)  eprint(...)  gprint(...)  oprint(...)  wprint(...)  bprint(...)
```

Side: shared

Parameters:
- `...` (any, optional): values to print. Tables are json-encoded (`log` uses indented output). A string containing `%s`/`%d`/`%f` placeholders consumes the following arguments through `string.format`; supply at least as many following arguments as placeholders or `string.format` raises. Colour tags `~red~`, `~green~`, `~orange~`, `~blue~` inside strings are converted to console colour codes.

Returns: nothing

Always-loaded console helpers from the print module. `sprint`/`eprint` print in red, `gprint` green, `oprint`/`wprint` orange, `bprint` blue; on the server they prefix the current resource name to the first argument, which must therefore be a string or number. `log` prints uncoloured. All of them are unconditional; see `dprint` for debug-gated output.

```lua
gprint('Database table created: %s', tableName)
eprint('failed to load', err)
```

### dprint

```lua
dprint(cbOrFirstArg: function | any, ...)
```

Side: shared

Parameters:
- `cbOrFirstArg` (function | any, required): if a function, it is used as the printer instead of the console; otherwise it is simply the first value to print.
- `...` (any, optional): values, same formatting rules as `log`.

Returns: nothing

Debug print. It prints when the global `Config.debug` in the consumer resource is truthy, or the convar `<resource>:debug` is `on` (this sets `w.debug` and is watched live). A third gate, `w.debugModules[<module>]`, is keyed by the third `/`-separated segment of the calling file's chunk name. For the library's own module files (`@@w_lib/modules/<module>/...`) that is the module folder, driven by the convars `<resource>:debug:<module>` and `all:debug:<module>`. For consumer files the segment is a file or sub-folder name that no convar listener is registered for, so consumer code should rely on `Config.debug` or `<resource>:debug`.

```lua
dprint('spawned horse', horseData)
-- server.cfg: set w_horses:debug "on"
```

### lib.class

```lua
lib.class(name: string, super?: table): Class
```

Side: shared

Parameters:
- `name` (string, required): class name, stored as `__name`. A non-string raises.
- `super` (Class, optional): parent class created with `lib.class`. Must be a hash table; the new class's metatable is set to it so methods (and the constructor, when the child defines none) are inherited.

Returns: a class table. Instances are created with `Class:new(...)`.

Creates a class in the ox_lib style. Define the initialiser as `function Class:constructor(...)`; it is removed from the method table on the first `:new` and run with the new object. Inside the constructor call `self:super(...)` to run the parent's constructor. Fields assigned to `self.private` inside the constructor become private: after construction, reads from outside class methods return nil and writes raise `cannot set value of private field`. If the constructor assigns nothing to `self.private` the field is removed entirely, so create at least one private field in the constructor when methods need private state. Method definitions use colon syntax. Instances carry the class as their metatable, so `isClass` and `instanceOf` work by metatable walk.

```lua
local Animal = lib.class('Animal')
function Animal:constructor(name)
    self.name = name
    self.private.secret = 42 -- only readable from Animal methods
end
function Animal:speak() return ('%s makes a sound'):format(self.name) end

local Dog = lib.class('Dog', Animal)
function Dog:constructor(name)
    self:super(name)
end
function Dog:speak() return self.name .. ' barks' end

local rex = Dog:new('Rex')
print(rex:speak(), rex:instanceOf(Animal), rex:isClass(Animal)) -- Rex barks  true  false
```

#### Instance methods shared by every class

```lua
Class:new(...): instance
instance:isClass(class: Class): boolean
instance:instanceOf(class: Class): boolean
```

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `Class:new(...)` | `...` (any, optional): forwarded to `Class:constructor(self, ...)` | a new instance whose metatable is the class | Always call with a colon. Present on every `lib.class` class and on `lib.array`, `lib.heap`, `lib.lru`, `lib.map`, `lib.set`, `lib.ringbuffer`, `lib.selector`. Sets up the private table and the temporary `self:super` helper for the duration of the constructor. |
| `instance:isClass(class)` | `class` (Class, required) | `true` only when the instance's own class is exactly `class` | No inheritance considered. |
| `instance:instanceOf(class)` | `class` (Class, required): class or ancestor | `true` when `class` is the instance's class or any ancestor | Walks the metatable chain. Can also be called as a plain function on an arbitrary table; `lib.array.isArray` uses `lib.array.instanceOf(tbl, lib.array)`. |

```lua
local h = lib.heap:new()
if obj:isClass(lib.array) then print('a plain Array, not a subclass') end
print(Dog:new('Rex'):instanceOf(Animal)) -- true
```

### lib.array

```lua
lib.array:new(...: any): Array
lib.array:from(iter: table | string | function): Array
lib.array.isArray(tbl: any): boolean
```

Side: shared

Parameters:
- `...` (any, optional, `:new`): initial elements, stored at indices 1..n.
- `iter` (table | string | function, required, `:from`): a sequence table is unpacked; a string is split into single characters; a function is treated as an iterator and each returned value is appended. Any other type raises.
- `tbl` (any, required, `isArray`): value to test.

Returns: an Array instance (a sequence table with `lib.array` as metatable). `isArray` returns `true` when `tbl` is a table whose `table.type` is `array` or `empty`, or an Array instance; non-tables return `false`. `isArray` is a static helper (dot call, not colon).

JavaScript-style array class. Assigning a non-number index raises `Cannot insert non-number index`. Works with `#`, `ipairs`, `table.unpack` and `table.concat`.

```lua
local a = lib.array:new('a', 'b', 'c')
local b = lib.array:from({ 1, 2, 3 })
local chars = lib.array:from('abc') -- {'a','b','c'}
if lib.array.isArray(data) then print('sequence') end
```

#### Array methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `arr:at(index)` | `index` (number, required): 1-based; negative counts from the end (-1 is last) | the element or nil | |
| `arr:merge(...)` | `...` (table or Array, required): one or more sequence tables | a new Array with arr's elements followed by each argument's | does not modify arr |
| `arr:every(testFn)` | `testFn(element)` returns truthy to pass | `true` when every element passes (true for empty) | stops at the first failure |
| `arr:fill(value, start?, endIndex?)` | `value` (any, required); `start` (number, default 1, negative from end, clamped to 1); `endIndex` (number, default #arr, negative from end, clamped to #arr) | arr itself (mutated) | overwrites existing elements only; does not grow |
| `arr:filter(testFn)` | `testFn(element)` returns truthy to keep | a new Array | non-mutating |
| `arr:find(testFn, last?)` | `testFn` predicate; `last` (boolean) searches from the end | first (or last) matching element, or nil | linear search |
| `arr:findIndex(testFn, last?)` | as `find` | index of the match, or nil | |
| `arr:indexOf(value, last?)` | `value` compared with `==`; `last` searches from the end | index or nil | |
| `arr:forEach(cb)` | `cb(element)` called per element, no index | nothing | |
| `arr:includes(element, fromIndex?)` | `element` compared with `==`; `fromIndex` (number, default 1) | boolean | |
| `arr:join(seperator?)` | `seperator` (string, default `,`) | concatenated string via `table.concat` (elements must be strings or numbers) | |
| `arr:map(cb)` | `cb(element, index, array)`; its return is stored at the same index | a new Array | the callback must not return nil: results pass through `table.unpack`, so a nil truncates the new array at that point. Distinct from the global `table.map` |
| `arr:pop()` / `arr:shift()` | none | removed last (pop) or first (shift) element | mutating |
| `arr:push(...)` / `arr:unshift(...)` | `...` (any, required): appended to the end (push) or inserted at the start in the given order (unshift) | the new length | mutating |
| `arr:reduce(reducer, initialValue?, reverse?)` | `reducer(accumulator, element, index)` returns the new accumulator; `initialValue` (when omitted the first, or last if reverse, element is used and iteration starts at the second); `reverse` (boolean) iterates right to left | the final accumulator | |
| `arr:reverse()` / `arr:toReversed()` | none | `reverse` returns arr reversed in place; `toReversed` returns a new reversed Array | |
| `arr:slice(start?, finish?)` | `start` (default 1, negative from end, clamped to 1); `finish` (default #arr, inclusive, negative from end, clamped to #arr) | a new Array with the shallow-copied range | inclusive |

```lua
local last = arr:at(-1)
local evens = arr:filter(function(n) return n % 2 == 0 end)
local admin = players:find(function(p) return p.group == 'admin' end)
local names = players:map(function(p) return p.name end)
local total = prices:reduce(function(acc, p) return acc + p end, 0)
arr:push('x', 'y')
local next = queue:shift()
lib.array:new(1, 2, 3, 4):fill(0, 2, 3) -- {1,0,0,4}
print(arr:join(', '))
```

### lib.map

```lua
lib.map:new(initial?: table): Map
```

Side: shared

Parameters:
- `initial` (table, optional): key/value pairs copied in with `pairs()`, so their order is not guaranteed. A non-table raises.

Returns: a Map instance.

Insertion-ordered hash map. Keys may be any non-nil value; values must be non-nil (use `delete`). Supports `#` (size), `pairs(map)` (insertion order), `json.encode` (keeps order) and msgpack, so it can travel over events and arrives as a plain table.

```lua
local m = lib.map:new()
m:set('b', 2):set('a', 1)
for k, v in m:entries() do print(k, v) end -- b 2, then a 1
```

#### Map methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `map:set(key, value)` | `key` (any non-nil, required; nil raises); `value` (any non-nil, required; nil raises with `use :delete(key)`) | the map (chainable) | updating an existing key keeps its original position |
| `map:get(key)` | `key` | the value or nil | |
| `map:has(key)` | `key` | boolean | |
| `map:delete(key)` | `key` | `true` when an entry was removed | deleted slots are compacted automatically once the number of tombstones is at least the number of live entries and at least 8 |
| `map:entries()` / `map:each()` | none | iterator yielding `key, value` in insertion order | `each` is an alias of `entries` |
| `map:keys()` / `map:values()` | none | iterators in insertion order | |
| `map:toTable()` | none | a plain key-to-value table | |
| `map:toArray()` | none | a `lib.array` of `{ key = k, value = v }` records in insertion order | |
| `map:size()` / `map:isEmpty()` / `map:clear()` | none | as named; `clear` returns the map | |

```lua
map:set(source, player)
if map:has(source) then map:delete(source) end
TriggerClientEvent('myres:list', src, map:toArray())
```

### lib.set

```lua
lib.set:new(...: any): Set
```

Side: shared

Parameters:
- `...` (any, optional): initial members; nil arguments are ignored.

Returns: a Set instance.

Insertion-ordered set built on `lib.map`. Supports `#` (size), `pairs`/`ipairs` (index, value), `json.encode` and msgpack (serialises as an array).

```lua
local s = lib.set:new('a', 'b')
s:add('c'):add('a')
print(#s) -- 3
```

#### Set methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `set:add(value)` | `value` (any, required); nil and duplicates are ignored | the set (chainable) | |
| `set:remove(value)` | `value` | `true` when the member existed | |
| `set:has(value)` | `value` | boolean | |
| `set:union(other)` | `other` (Set, required; must support `:each`, `:has`, `:size`) | a new Set | |
| `set:intersection(other)` | `other` | a new Set | |
| `set:difference(other)` | `other` | a new Set of elements in `set` not in `other` | |
| `set:equals(other)` / `set:isSubsetOf(other)` | `other` | boolean | |
| `set:each()` / `set:toArray()` / `set:size()` / `set:isEmpty()` / `set:clear()` | none | as named | |

```lua
if not seen:has(id) then seen:add(id) end
local missing = required:difference(owned)
for item in missing:each() do print(item) end
```

### lib.heap

```lua
lib.heap:new(comparator?: fun(a: any, b: any): boolean): Heap
```

Side: shared

Parameters:
- `comparator` (function, optional): returns `true` when `a` should come out before `b`. Default `a < b` (min-heap). Passing a non-function raises.

Returns: a Heap instance.

Binary heap / priority queue. Supports `#` (size).

```lua
local pq = lib.heap:new(function(a, b) return a.priority < b.priority end)
pq:push({ priority = 5, job = 'x' }, { priority = 1, job = 'y' })
local first = pq:pop() -- job y
```

#### Heap methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `heap:push(...)` | `...` (any): one or more values, each sifted into place; pushing nothing is a no-op | the heap (chainable) | |
| `heap:pop()` | none | removes and returns the top element, or nil when empty | |
| `heap:peek()` | none | the top element without removing it | |
| `heap:size()` / `heap:isEmpty()` | none | element count (same as `#heap`) / boolean | |
| `heap:clear()` | none | the emptied heap | |
| `heap:drain()` | none | a new `lib.array` of all elements in pop order, leaving the heap empty | ascending for the default comparator |

```lua
heap:push(3):push(1, 2)
print(heap:peek()) -- 1
local sorted = heap:drain()
```

### lib.lru

```lua
lib.lru:new(capacity: integer): Lru
```

Side: shared

Parameters:
- `capacity` (integer, required): maximum entries; must be a positive integer or the constructor raises.

Returns: an Lru instance.

Least-recently-used cache. Supports `#` (size) and `pairs(lru)` (most recent first).

```lua
local cache = lib.lru:new(100)
cache:set('ped:123', data)
local v = cache:get('ped:123')
```

#### Lru methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `lru:get(key)` | `key` (any, required) | the value; marks the entry most recently used | |
| `lru:peek(key)` | `key` | the value without touching recency | |
| `lru:has(key)` | `key` | boolean | |
| `lru:set(key, value)` | `key`, `value` (required); an existing key is updated and moved to the front | when inserting pushes the cache over capacity, the evicted (least recent) key and value; otherwise nil | |
| `lru:delete(key)` | `key` | `true` when removed | |
| `lru:size()` / `lru:capacity()` | none | integers | |
| `lru:clear()` | none | the Lru | |
| `lru:each()` | none | iterator yielding `key, value` from most to least recently used | `pairs(lru)` uses `each` |

```lua
local oldKey, oldValue = cache:set(key, value)
if oldKey then releaseResource(oldValue) end
for k, v in cache:each() do print(k, v) end
```

### lib.ringbuffer

```lua
lib.ringbuffer:new(capacity: integer): RingBuffer
```

Side: shared

Parameters:
- `capacity` (integer, required): fixed size; positive integer or the constructor raises.

Returns: a RingBuffer instance.

Fixed-capacity circular buffer that overwrites the oldest value. Supports `#` and `pairs` (values oldest first, single loop variable).

```lua
local recent = lib.ringbuffer:new(50)
recent:push(message)
```

#### RingBuffer methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `rb:push(value)` | `value` (any, required) | the overwritten value when the buffer was full, else nil | |
| `rb:get(i)` | `i` (integer, required): 1 = oldest, negative counts from the newest (-1 = newest) | the element or nil for out-of-range | non-integers raise |
| `rb:each()` | none | iterator oldest to newest | |
| `rb:toArray()` | none | a `lib.array`, oldest first | |
| `rb:size()` / `rb:capacity()` / `rb:isFull()` / `rb:isEmpty()` | none | as named | |
| `rb:clear()` | none | the RingBuffer | |

```lua
local dropped = rb:push(v)
local newest = rb:get(-1)
for v in rb:each() do print(v) end
```

### table.* helpers

The functions below live on the global `table`. `lib.table` is the same table. The first group comes from the w modules; the second group is ox-derived and survives the load order.

#### table.copy

```lua
table.copy(t: any): any
```

Side: shared

Parameters:
- `t` (any, required): non-tables are returned unchanged.

Returns: a deep copy with the same metatable on the root and each nested table.

w-module deep clone. `table.deepclone` from ox also exists and does not preserve metatables.

```lua
local cfg = table.copy(Config.defaults)
```

#### table.merge

```lua
table.merge(deepMerge?: boolean, t1: table, t2: table, ...: table): table
```

Side: shared

Parameters:
- `deepMerge` (boolean, optional): when the first argument is not a boolean it is treated as `t1` and deep merge defaults to `true`. `false` replaces nested tables wholesale.
- `t1` (table, required): target; mutated and returned.
- `t2, ...` (table, required): sources merged left to right; later values win. nil sources are skipped.

Returns: `t1`

Effective w-module version (overrides the ox `table.merge` that added duplicate numbers). With a single table argument it is returned unchanged.

```lua
local settings = table.merge(table.copy(Defaults), UserConfig)
local shallow = table.merge(false, a, b)
```

#### table.mergeAfter

```lua
table.mergeAfter(t1: table, ...: table): table
```

Side: shared

Parameters:
- `t1` (table, required): target sequence; mutated.
- `...` (table, required): tables whose values (any keys) are appended to `t1` in `pairs()` order.

Returns: `t1`

Append-style merge for arrays.

```lua
local all = table.mergeAfter({}, listA, listB)
```

#### table.map

```lua
table.map(t: table, func: fun(value: any, key: any, t: table): any): table
```

Side: shared

Parameters:
- `t` (table, required): source; nil is treated as empty.
- `func` (function, required): receives `value, key, table`; its return is stored under the same key.

Returns: a new table (deep-copied via `table.copy`).

Effective w-module version; same key set as the source.

```lua
local labels = table.map(items, function(item) return item.label end)
```

#### table.filter

```lua
table.filter(t: table, filterIter: fun(value: any, key: any, t: table): boolean, keepKeyAssociation?: boolean): table
```

Side: shared

Parameters:
- `t` (table, required): source.
- `filterIter` (function, required): return truthy to keep.
- `keepKeyAssociation` (boolean, optional, default false): when false, numeric keys are re-sequenced 1..n; string keys are always kept.

Returns: a new table.

```lua
local alive = table.filter(players, function(p) return not p.dead end)
```

#### table.find

```lua
table.find(t: table, func: fun(value, key, t): boolean | any): value | false, key?
```

Side: shared

Parameters:
- `t` (table, required): source; nil or a non-table returns `false`.
- `func` (function | any, required): predicate, or a plain value compared with `==`.

Returns: the found value and its key, or `false`.

Arrays are scanned in order; hash tables in `pairs()` order.

```lua
local ped, index = table.find(peds, function(p) return p.netId == netId end)
if table.find(modules, 'hook') then print('hook enabled') end
```

#### table.includes

```lua
table.includes(t: table, value: any, fromIndex?: integer): boolean, key: any
```

Side: shared

Parameters:
- `t` (table, required): source; nil returns `false, 0`; a non-table prints an error and returns `false, nil`.
- `value` (any, required): compared with `==`; nil or false returns `false, 0`.
- `fromIndex` (integer, optional): accepted but not used by the implementation; the search always starts at 1.

Returns: `true` and the index/key, or `false` and 0.

```lua
local found, idx = table.includes(allowed, job)
```

#### table.count and table.isEmpty

```lua
table.count(t: table): integer
table.isEmpty(t: table): boolean
```

Side: shared

Parameters:
- `t` (table, required): for `count`, nil returns 0 and a non-table raises; for `isEmpty`, a table with no entries returns `true`.

Returns: `count` gives `#t` when greater than 0, otherwise the number of `pairs()` entries; `isEmpty` gives a boolean.

```lua
if table.isEmpty(inventory) then return end
print(table.count(players))
```

#### table.extract

```lua
table.extract(t: table, key: any): any
```

Side: shared

Parameters:
- `t` (table, required): source; mutated (the key is removed). nil returns nil.
- `key` (any, required): key to pull out.

Returns: the value, deep-copied when it is a table.

```lua
local metadata = table.extract(item, 'metadata')
```

#### table.slice

```lua
table.slice(t: table, s?: integer, e?: integer): table
```

Side: shared

Parameters:
- `t` (table, required): sequence.
- `s` (integer, optional): start, default 1.
- `e` (integer, optional): end inclusive, default `s`, so `table.slice(t, 3)` returns one element.

Returns: a new array of `t[s..e]` (via `table.move`).

Note that the default end is `s`, not `#t`.

```lua
local page = table.slice(rows, 11, 20)
```

#### table.upsert and table.addMultiLevels

```lua
table.upsert(t?: table, ...keys: any | keys: any[], value: any): table
table.addMultiLevels(t?: table, ...keys: any | keys: any[]): table
```

Side: shared

Parameters:
- `t` (table, optional): when the first argument is a table it is the target (mutated); otherwise a new table is created.
- `keys` (any... | any[], required): path of keys, either as separate arguments or one array; intermediate tables are created. A non-table intermediate raises.
- `value` (any, required, `upsert` only): always the last argument; stored at the path.

Returns: the target table.

`upsert` is a deep set. `addMultiLevels` ensures the nested tables exist without overwriting existing ones.

```lua
table.upsert(state, 'players', source, 'bucket', 5)
table.upsert(state, { 'players', source, 'ready' }, true)
table.addMultiLevels(cache, 'horses', source)
cache.horses[source].saddle = true
```

#### table.getDeep and table.doesKeyExist

```lua
table.getDeep(t: table, keys: any[]): value: any, exists: boolean, missingKey: string
table.doesKeyExist(t: table, keys: any[]): boolean, value: any
```

Side: shared

Parameters:
- `t` (table, required): root. `getDeep` raises on nil or a non-table; `doesKeyExist` returns `false` for nil.
- `keys` (any[], required): array path. For `doesKeyExist` this must be one array: the implementation always takes its first vararg as the key list, so passing keys as separate string arguments does not work.

Returns: `getDeep` gives `value, true, ''` when found and `nil, false, <first missing key>` otherwise. `doesKeyExist` gives `true` and the value when the leaf is truthy, `false` otherwise.

Prefer `table.getDeep` when `false` must be distinguished from missing.

```lua
local level, ok = table.getDeep(player, { 'skills', 'hunting', 'level' })
local exists, value = table.doesKeyExist(cfg, { 'shops', 'valentine', 'items' })
```

#### table.deleteDeepValue and table.deleteAndClear

```lua
table.deleteDeepValue(t: table, keys: any[]): table, deleted: boolean
table.deleteAndClear(t: table, keys: any[]): boolean
```

Side: shared

Parameters:
- `t` (table, required): root. `deleteDeepValue` raises on nil or a non-table; `deleteAndClear` returns `false` for a non-table.
- `keys` (any[], required): array path; the last key is removed. For `deleteAndClear` the path must be non-empty and intermediate non-table values return `false` (with a debug print).

Returns: `deleteDeepValue` gives the table and `true` when the parent path existed (`false` when an intermediate was missing). `deleteAndClear` gives `true` when the leaf existed and was removed.

`deleteDeepValue` leaves empty parents in place. `deleteAndClear` uses `table.remove` for array parents and then removes every parent that became empty, stopping at the root.

```lua
table.deleteDeepValue(state, { 'players', source })
table.deleteAndClear(zones, { 'valentine', 'saloon', zoneId })
```

#### table.clearForNui

```lua
table.clearForNui(t: table): table
```

Side: shared

Parameters:
- `t` (table, required): source; not mutated.

Returns: a recursive copy with every function value dropped.

Prepares a table carrying callbacks for `SendNUIMessage` or `json.encode`.

```lua
SendNUIMessage({ action = 'setMenu', data = table.clearForNui(menu) })
```

#### table.isEgal

```lua
table.isEgal(table1: any, table2: any, strict?: boolean, canMissInTable1?: boolean, canMissInTable2?: boolean): boolean
```

Side: shared

Parameters:
- `table1` (any, required): non-tables are compared with `==`.
- `table2` (any, required): other value.
- `strict` (boolean, optional, default true): keys of `table2` are also checked against `table1`.
- `canMissInTable1` (boolean, optional, default false): when true, keys present only in `table2` are ignored during the strict pass.
- `canMissInTable2` (boolean, optional, default false): when true, keys present only in `table1` are ignored.

Returns: boolean

Recursive deep equality with optional one-sided tolerance. ox `table.matches` is the plain strict variant.

```lua
if not table.isEgal(oldOutfit, newOutfit) then save(newOutfit) end
```

#### table.freeze and table.isfrozen

```lua
table.freeze(tbl: table): table
table.isfrozen(tbl: table): boolean
```

Side: shared

Parameters:
- `tbl` (table, required): table to make read-only. It is mutated in place: contents move behind a proxy metatable. Nested tables stay mutable unless frozen themselves.

Returns: `freeze` returns the same table; `isfrozen` reports whether its metatable is the `readonly` marker.

Any assignment, including `rawset` (which the table import patches), raises `cannot set values on a frozen table`. `#`, `pairs` and the original metatable's `__index` behaviour are preserved.

```lua
local Config = table.freeze({ maxHorses = 5 })
Config.maxHorses = 6 -- error
```

#### table.contains, table.matches, table.deepclone, table.shuffle

```lua
table.contains(tbl: table, value: any | any[]): boolean
table.matches(t1: any, t2: any): boolean
table.deepclone(tbl: table): table
table.shuffle(tbl: table): table
```

Side: shared

Parameters:
- `tbl` / `t1` / `t2` (table, required). `contains`: when `value` is a table, every element of it must be present among `tbl`'s values. `matches`: strict recursive equality of keys and values. `deepclone`: recursive copy without metatables. `shuffle`: Fisher-Yates in place.

Returns: as named; `shuffle` returns the same table.

ox-derived helpers that nothing in the w modules overrides.

```lua
if table.contains(player.licenses, { 'weapon', 'hunting' }) then print('licensed') end
local deck = table.shuffle(table.deepclone(cards))
```

### string.* helpers

The methods below are on the string metatable, so they can be called on any string with colon syntax. `string.random`, `string.spaceNumber` and `string.compare` are dot-call functions.

#### String methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `str:split(delimiter, pieces?)` | `delimiter` (string, required): passed straight to CfxLua `string.strsplit`, so each character of it acts as a separator; `pieces` (number, optional): maximum number of pieces | array of parts | |
| `str:trim()` | none | the string without leading/trailing whitespace (CfxLua `strtrim`) | |
| `str:firstToUpper()` | none | the string with its first lowercase ASCII letter uppercased | |
| `str:removeAccent()` | none | copy with Latin accented letters (A/E/I/O/U variants, N with tilde, C cedilla) replaced by their base letter | UTF-8 aware for the mapped characters only; other multibyte characters, Arabic included, are left untouched |
| `str:compareVersionWith(version)` | `version` (string, required): dotted numeric segments; non-numeric segments compare as strings | -1 when `str` is older, 0 when equal, 1 when newer | `'1.10.0'` vs `'1.9.0'` gives 1 |
| `str:convertVersion()` | none | segments weighted by 1000 per level: `'1.2.3'` gives 1002003; non-numeric segments count as 0 | |
| `str:extractConvarComparator()` | none | `resource, convar?, comparator?, value?` | parses `resourceName[:convar](< > <= >= == =)value`; `'rsg-core>=2.0.0'` gives `'rsg-core', nil, '>=', '2.0.0'`; without a comparator the whole string is returned alone |
| `str:toHex()` | none | the number encoded by the hex digits after the first two characters (the string must start with a two-character prefix such as `0x`), converted to a signed 32-bit value; the original string when it does not parse | despite the name this converts a hex string to a number; for number-to-hex use `math.toHex` |

```lua
local parts = ('a,b,c'):split(',')  -- {'a','b','c'}
local name = input:trim()
print(('horse'):firstToUpper()) -- Horse
local key = label:removeAccent():lower()
if GetResourceMetadata('w_lib', 'version', 0):compareVersionWith('3.38.0') < 0 then print('update w_lib') end
local v = ('3.38.0'):convertVersion() -- 3038000
local res, convar, op, wanted = ('vorp_core>=1.0.0'):extractConvarComparator()
local hash = ('0xC9F7A5DB'):toHex()
```

#### string.random

```lua
string.random(pattern: string, length?: integer): string
```

Side: shared

Parameters:
- `pattern` (string, required): template. `1` = digit 0-9, `A` = uppercase letter, `a` = lowercase letter, `.` = uppercase letter or digit, `^` = next character literally, anything else copied as-is.
- `length` (integer, optional): output length; shorter truncates the pattern, longer pads with spaces. Default is the pattern length excluding `^`.

Returns: the generated string.

```lua
local plate = string.random('AAA 111')
local code = string.random('........', 8)
```

#### string.spaceNumber

```lua
string.spaceNumber(number: number, decimal?: integer): string
```

Side: shared

Parameters:
- `number` (number, required): value to format.
- `decimal` (integer, optional, default 0): decimal places.

Returns: digits grouped in threes with a space, for example `1 234 567.50`; sign preserved.

```lua
print(string.spaceNumber(1234567.5, 2)) -- 1 234 567.50
```

#### string.compare

```lua
string.compare(a: any, b: any, caseSensitive?: boolean): -1 | 0 | 1
```

Side: shared

Parameters:
- `a` (any, required): converted with `tostring`.
- `b` (any, required): converted with `tostring`.
- `caseSensitive` (boolean, optional, default false): both strings are lowercased after accent removal and trimming. The per-string segment cache is keyed only by the string, so the first call's `caseSensitive` setting sticks for that string until the cache entry is collected; do not mix modes on the same strings.

Returns: 0 only when `a == b` exactly; otherwise -1 when `a` sorts before `b`, 1 when after. Digit runs compare numerically, so `item2` sorts before `item10`. Two strings that differ only by case or accents return 1, not 0.

Natural-order comparator for `table.sort`.

```lua
table.sort(names, function(x, y) return string.compare(x, y) < 0 end)
```

### math.* helpers

The functions below live on the global `math`; `lib.math` is the same table.

#### math.round

```lua
math.round(number: number, precision?: number): number
```

Side: shared

Parameters:
- `number` (number, required): value to round.
- `precision` (number, optional): decimal places; nil or 0 or less means whole number.

Returns: `math.floor(number)` or `math.floor(number * 10^precision) / 10^precision`.

The effective version in a consumer resource is the w-module one, which floors (2.7 gives 2; 2.79 with precision 1 gives 2.7). The ox half-up variant is overwritten at load time and is not reachable.

```lua
print(math.round(2.7))      -- 2
print(math.round(2.789, 2)) -- 2.78
```

#### math.clamp

```lua
math.clamp(x: number, min: number, max: number): number
```

Side: shared

Parameters:
- `x` (number, required): value.
- `min` (number, required): lower bound.
- `max` (number, required): upper bound; must be greater than or equal to `min`, bounds are not swapped.

Returns: `math.max(math.min(x, max), min)`

Effective w-module version; it overrides the ox one that swapped reversed bounds.

```lua
local hp = math.clamp(hp + delta, 0, 100)
```

#### math.lerp and math.interp

```lua
math.lerp(a: number | vector, b: number | vector, t: number): number | vector
math.interp(start: number | vector2 | vector3 | vector4, finish: same, factor: number): same
```

Side: shared

Parameters:
- `a` / `start` (number | vector, required): start value.
- `b` / `finish` (number | vector, required): end value, same type as the start.
- `t` / `factor` (number, required): factor, normally 0..1.

Returns: `a + (b - a) * t`

`math.lerp` is the effective w-module version: a plain one-shot interpolation. The ox per-frame iterator form `(start, finish, durationMs)` is overwritten and not available; use `math.interp` for the same one-shot maths or loop with `GetGameTimer`. `math.interp` is the ox one-shot interpolation and is identical in effect.

```lua
local pos = math.lerp(startCoords, endCoords, progress)
local alpha = math.interp(0, 255, 0.5) -- 127.5
```

#### math.groupdigits

```lua
math.groupdigits(number: number | string, seperator?: string): string
```

Side: shared

Parameters:
- `number` (number | string, required): value; a leading sign or prefix and a decimal part are preserved.
- `seperator` (string, optional, default `,`): thousands separator.

Returns: a string with digits grouped in threes.

```lua
local price = math.groupdigits(1234567) -- '1,234,567'
local txt = ('$%s'):format(math.groupdigits(price))
```

#### Hex helpers: math.hextorgb, math.tohex, math.toHex, math.fromHex, math.toSigned

```lua
math.hextorgb(input: string): r: integer, g: integer, b: integer
math.tohex(n: number | string, upper?: boolean): string
math.toHex(n: integer, prefix?: boolean): string
math.fromHex(hex: string): integer
math.toSigned(n: number): number
```

Side: shared

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| `math.hextorgb(input)` | `input` (string, required): hex colour with or without a leading `#`, six hex digits | three integers 0-255 | parses `#RRGGBB` |
| `math.tohex(n, upper?)` | `n` (number or string, required): integer value, `string.format %x` is applied; `upper` (boolean, optional): uppercase digits | `0x` followed by the hex digits | ox helper, always prefixed with `0x` |
| `math.toHex(n, prefix?)` | `n` (integer, required): a non-number is returned unchanged; `prefix` (boolean, optional, default false): add `0x` | uppercase hex string, for example `FF` or `0xFF` | w-module helper, distinct from `math.tohex` |
| `math.fromHex(hex)` | `hex` (string, required): hex digits; a non-string is returned unchanged. The implementation is `tonumber(hex, 16)`, which returns nil for a `0x` prefix, so pass plain digits | `tonumber(hex, 16)`, nil when unparsable | inverse of `math.toHex` |
| `math.toSigned(n)` | `n` (number, required): unsigned 32-bit value; non-numbers returned unchanged | `n - 2^32` when `n >= 2^31`, else `n` | converts an unsigned 32-bit hash to the signed form natives expect; `GetHashFromString` from the w layer uses it for numeric strings |

```lua
local r, g, b = math.hextorgb('#ff8800')
print(math.tohex(255), math.tohex(255, true)) -- 0xff  0xFF
local hash = math.toHex(joaat('WEAPON_REVOLVER_CATTLEMAN'), true)
local n = math.fromHex('FF') -- 255
local signed = math.toSigned(3379563880)
```

#### math.toscalars, math.tovector, math.torgba

```lua
math.toscalars(input: string, min?: number, max?: number, round?: boolean | number): number...
math.tovector(input: string | table, min?: number, max?: number, round?: boolean | number): number | vector2 | vector3 | vector4
math.torgba(input: string | table): vector4
```

Side: shared

Parameters:
- `input` (required): for `toscalars`, text containing numbers such as `'vec3(1.0, 2.5, 3)'` or `'1, 2, 3'`; a function-call prefix is stripped. For `tovector`, a string parsed with `toscalars`, an array of numbers, or a table with x/y/z/w fields; other types raise. For `torgba`, four components r, g, b, a; r/g/b must be 0-255 (rounded when given as a string), a must be 0-1 (asserted); fewer than four components fails the assertion.
- `min` (number, optional): each value below this raises.
- `max` (number, optional): each value above this raises.
- `round` (boolean | number, optional): `true` rounds every value to an integer (half up); a number N rounds only the first N values. For table input to `tovector`, every value is validated against min/max after rounding but the rounded value is not written back, so table components keep their original values.

Returns: `toscalars` gives the parsed numbers as multiple return values and raises when a token is not numeric. `tovector` gives vector2/3/4 depending on component count, or a plain number for a single component. `torgba` gives `vector4(r, g, b, a)`.

Useful for config values and JSON/NUI data.

```lua
local x, y, z = math.toscalars('vec3(10.5, -3, 2)')
local coords = math.tovector({ x = 1.0, y = 2.0, z = 3.0 })
local v = math.tovector('1.0, 2.0')
local c = math.torgba({ 255, 128, 0, 0.5 })
```

#### math.normaltorotation

```lua
math.normaltorotation(input: vector3): vector3
```

Side: shared

Parameters:
- `input` (vector3, required): surface normal, for example from a raycast. Other types raise.

Returns: `vec3(pitch, yaw, 0.0)` in degrees.

Converts a normal into a rotation for placing props flush with a surface.

```lua
local rot = math.normaltorotation(hitNormal)
SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)
```

### lib.addCommand

```lua
lib.addCommand(commandName: string | string[], properties: OxCommandProperties | false, cb: fun(source: number, args: table, raw: string))
```

Side: server

Parameters:
- `commandName` (string | string[], required): command name without slash, or an array of aliases that share the same handler and properties.
- `properties` (table | false, required): command metadata. Pass `false` for a bare command with no suggestion, no parsing and no restriction. Must be a non-empty hash table: an array, or an empty table `{}`, is not `table.type` `hash` and routes the call to the deprecated `lib.__addCommand` path with a console warning.
  - `help` (string, optional): description shown in the chat suggestion.
  - `params` (table[], optional): ordered parameter definitions; each entry is a table with:
    - `name` (string, required): key under which the parsed value is stored in `args`.
    - `help` (string, optional): shown in the suggestion, suffixed with `(type: <type>)` when `type` is set. A `playerId` param is suffixed with the `citizen.help` string instead (what to type, in the server's language).
    - `type` (`'number'` | `'playerId'` | `'string'` | `'longString'`, optional): `number` converts with `tonumber`; `string` accepts only input that is not numeric (a numeric string is rejected); `playerId` takes the player's **citizen id** (`'12'`, the old `'OMG95204'`, see [w.citizen](#the-wcitizen-module-one-citizen-id-for-every-player-target)) and passes the handler his current server id, takes `'#7'` for an explicit server id (any connected player, even one still choosing a character) and `me` for the caller. A citizen who is not connected is refused with the `offline` reason: an offline-capable command declares the param with no `type` (not `string`, which refuses `12`) and resolves it with `w.citizen.resolve` instead. `longString` works only on the last parameter and captures the rest of the raw line from that word onward; no type keeps the raw word.
    - `optional` (boolean, optional, default false): when false a missing or invalid value aborts the command with a red console trace and `cb` is not called; when true a missing value is nil, but a present-yet-invalid value still aborts. A refused `playerId` also tells the caller why (the `citizen.invalid_id` / `not_found` / `offline` string as a notification, or a console line for the console).
  - `restricted` (boolean | string | string[], optional): `false`/nil = anyone; `true` = registered as restricted so the caller needs ace `command.<name>` (no ace is added for you); a principal string such as `'group.admin'` or an array of principals = registered as restricted and each principal is granted `command.<name>` via `lib.addAce` (the `exports.w_lib:addAce` export, which runs `add_ace`) if it does not already have it.
- `cb` (function, required): handler run in-process (a real function, not an event name). Receives `source` (0 for console), `args` (positional entries are replaced by `args[param.name]` when `params` are defined; otherwise the raw word array) and the raw string. Errors are caught with pcall and traced as `command '<name>' failed to execute`.

Returns: nothing

Registers one or more server commands with typed argument parsing, ace restriction and chat suggestions. Suggestions are broadcast to everyone 1 s after resource start and to each joining player; commands added later are pushed immediately.

```lua
lib.addCommand({ 'additem', 'giveitem' }, {
    help = 'Gives an item to a player',
    params = {
        { name = 'target', type = 'playerId', help = 'The player to receive the item' },
        { name = 'item', type = 'string', help = 'The name of the item' },
        { name = 'count', type = 'number', help = 'Amount', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args, raw)
    local count = args.count or 1
    print(('give %sx %s to %s'):format(count, args.item, args.target))
end)

lib.addCommand('survivalsave', false, function(source)
    print('flush requested by', source)
end)
```

### lib.logger

```lua
lib.logger(source: number | string | nil, event: string, message: string, ...: string | table)
```

Side: server

Parameters:
- `source` (number | string | nil, optional): when a positive number it is treated as a player id and their name and non-ip identifiers are attached as tags (cached until `playerDropped`). Any other value is stringified into the payload.
- `event` (string, required): category or service name (Datadog service, Loki stream event, Fivemanage service).
- `message` (string, required): log text.
- `...` (string | table, optional): extra tags. Datadog: all values are converted with `tostring` and joined with commas into `ddtags` (use `key:value` strings). Loki and Fivemanage: tables are merged key by key into the metadata, strings are parsed as `key:value` (Loki also accepts comma-separated lists).

Returns: nothing

Server-only remote logger. Entries are buffered and flushed in one HTTP POST 500 ms after the first call; failures are printed with warn. The provider is chosen by the convar `w_lib:logger` (default `datadog`). If the convar names an unknown provider, or `datadog:key` / `fivemanage:key` is empty for those providers, `lib.logger` becomes a no-op function, so it is safe to call unconditionally. The loki provider has no key check: once selected it always posts to `loki:endpoint`.

```lua
lib.logger(source, 'addItem', ('"%s" added %sx %s to "%s"'):format(invokingResource, count, item.name, inv.label))
lib.logger(source, 'admin', 'kicked player', 'reason:cheating')
```

### w.database

```lua
w.database.addTable(tableName: string, definition: string): boolean
w.database.addColumn(tableName: string, name: string, definition: string): boolean
w.database.addTrigger(triggerName: string, definition: string): boolean
w.database.doesTableExist(tableName: string): boolean
```

Side: server

Parameters:
- `tableName` (string, required): table name, inserted unquoted and unescaped into the SQL. Existence is checked with `SHOW TABLES LIKE ?`, so `_` and `%` act as wildcards. For `addColumn`, when the table is not found the function raises `Table <name> does not exist`.
- `definition` (string, required): for `addTable`, the column list placed between the parentheses of `CREATE TABLE IF NOT EXISTS <tableName> (<definition>)`; for `addColumn`, the column type and options appended after the name; for `addTrigger`, everything after `CREATE TRIGGER \`name\`` (timing, event, table, body).
- `name` (string, required, `addColumn`): column name, backtick-quoted in the ALTER but not escaped; existence checked with `SHOW COLUMNS FROM <table> LIKE ?`.
- `triggerName` (string, required, `addTrigger`): trigger name; existence checked with `SHOW TRIGGERS WHERE \`Trigger\` = ?`.

Returns:
- `addTable`: `true` when the table was created now; `false` when it already existed.
- `addColumn`: `true` when the column was added; `false` when it already existed.
- `addTrigger`: `true` when created; `false` when a trigger with that name already exists.
- `doesTableExist`: boolean.

Idempotent schema bootstrap helpers. `addTable` never alters an existing table (add columns separately with `addColumn`). All of them require oxmysql to be started, run synchronously with `MySQL.*.await`, and print a green line when they change something; for `addColumn` the green `column added` line is printed before the ALTER runs, so wrap it in pcall if the table may be missing. Indexing `w.database` runs oxmysql's `lib/MySQL.lua` in the consumer resource. Never pass user input as names.

```lua
local SCHEMA = [[
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `points` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
]]
w.database.addTable('w_baloot_players', SCHEMA)
w.database.addColumn('w_baloot_tables', 'qayd', 'VARCHAR(16) NULL')
w.database.addTrigger('w_shop_stock_log', 'AFTER UPDATE ON w_shop_stock FOR EACH ROW INSERT INTO w_shop_log (item, old_count, new_count) VALUES (NEW.item, OLD.count, NEW.count)')
if not w.database.doesTableExist('w_horses') then runMigration() end
```

### w.bucket.getPlayersInBucket

```lua
w.bucket.getPlayersInBucket(bucketId: number): number[]
```

Side: server

Parameters:
- `bucketId` (number, required): routing bucket id.

Returns: an array of player server ids known to be in that bucket, or `{}` when none. The internal list itself is returned; do not mutate it.

Reads a per-resource registry that is maintained only by the server event `onPlayerBucketChange(source, newBucket, oldBucket)` and by `playerDropped` (which removes the player from `GetPlayerRoutingBucket`). Nothing in the library triggers `onPlayerBucketChange`, so the list is empty unless the consumer resource (or another resource) fires that event after every `SetPlayerRoutingBucket`. Because the module is loaded into each resource separately, every resource that indexed `w.bucket` receives the event and keeps its own copy.

```lua
local function setBucket(source, bucket)
    local old = GetPlayerRoutingBucket(source)
    SetPlayerRoutingBucket(source, bucket)
    TriggerEvent('onPlayerBucketChange', source, bucket, old)
end

for _, src in ipairs(w.bucket.getPlayersInBucket(5)) do
    TriggerClientEvent('myres:instanceMsg', src, 'hello')
end
```

### lib.grid

```lua
lib.grid.addEntry(entry: { coords: vector, length?: number, width?: number, radius?: number, [string]: any })
lib.grid.removeEntry(entry: table): boolean
lib.grid.getNearbyEntries(point: vector, filter?: fun(entry: table): boolean): Array
lib.grid.getCell(point: vector): table[]
lib.grid.getCellPosition(point: vector): x: number, y: number
```

Side: shared

Parameters:
- `entry` (table, required, `addEntry`/`removeEntry`): stored by reference and returned later by lookups; keep the same table to remove it. For `removeEntry` it must be the exact table previously passed to `addEntry` and still hold `coords`, `length`, `width`.
  - `coords` (vector3 or any value with x/y, required): centre of the entry.
  - `length` (number, required unless `radius` is given): half-extent along Y; defaults to `radius * 2` and is written back into the table.
  - `width` (number, required unless `radius` is given): half-extent along X; defaults to `radius * 2` and is written back.
  - `radius` (number, required when `length` or `width` is absent): used only to derive the missing length/width; if it is absent while `length` or `width` is also absent the call raises (arithmetic on nil).
  - any other field: kept as-is for the consumer resource's own use.
- `point` (vector, required, lookups): position with `.x` and `.y`.
- `filter` (function, optional, `getNearbyEntries`): return truthy to include the entry. The result is cached per cell block and filter reference, so reuse the same function object (do not create a new closure each call) or every call misses the cache.

Returns:
- `addEntry`: nothing.
- `removeEntry`: `true` when the entry was found in at least one cell.
- `getNearbyEntries`: a `lib.array` of unique entries found in the point's cell and its neighbouring cells (one cell delta in every direction). On a cache hit the same Array object is returned again, so treat it as read-only.
- `getCell`: the list of entries registered in exactly that cell (an empty table if none; the same table is reused between calls for the same cell).
- `getCellPosition`: the integer cell coordinates.

A fixed 34 x 50 cell spatial grid covering x -3700..4500 and y -4400..8000 (the RDR2 map). `addEntry` gives every cell the entry's box touches a reference and clears the lookup cache; `removeEntry` removes the entry from every cell it occupied, prunes empty cells and clears the cache. `getNearbyEntries` is a cheap neighbourhood query; do a precise distance check on the results. `getCell` and `getCellPosition` are lower-level access.

```lua
local shop = { coords = vec3(-300.0, 800.0, 118.0), radius = 25.0, name = 'General store', type = 'shop' }
lib.grid.addEntry(shop)

local function isShop(e) return e.type == 'shop' end
local near = lib.grid.getNearbyEntries(GetEntityCoords(cache.ped), isShop)
for i = 1, #near do print(near[i].name) end

local cx, cy = lib.grid.getCellPosition(coords)
lib.grid.removeEntry(shop)
```

### lib.selector

```lua
lib.selector:new(sets: {weight: number, item: any}[] | table<string, {weight, item}[]>): OxSelector
```

Side: shared

Parameters:
- `sets` (table, required): either an array of items, which becomes the set named `default`, or a map of set name to array of items. Each item is a two-element array `{ weight, value }` where weight is a number of 0 or more (asserted) and value is anything. Each set must be a non-empty array (asserted). The table is kept by reference, not cloned, so do not mutate it afterwards. A non-table prints an error through `lib.print.error` and then raises.

Returns: a Selector instance.

Weighted random picker with named sets. Table values returned by the getters are deep-cloned so callers cannot mutate the pool.

```lua
local loot = lib.selector:new({
    common = { { 70, 'bread' }, { 30, 'water' } },
    rare = { { 1, { name = 'gold_bar', count = 1 } } },
})
local item = loot:getRandomWeighted('common')
```

#### Selector methods

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `sel:getRandom(setName?)` | `setName` (string, optional): nil means `default`; an unknown name also falls back to `default` | the item value (second element of the pair, deep-cloned if a table), nil when the set is missing | uniform, ignores weights |
| `sel:getRandomWeighted(setName?)` | `setName` (string, optional): nil means `default`. An unknown name is not handled cleanly: when a `default` set exists it raises (the total weight for the unknown name is nil), when no `default` exists it returns nil. Always pass a registered name | the item value, nil when total weight is 0 | uses weights |
| `sel:getRandomAmount(setName, count)` / `sel:getRandomWeightedAmount(setName, count)` | `setName` (string or nil); `count` (number, required): independent draws, greater than 0 (asserted); draws may repeat | a plain array of values | |
| `sel:getSet(setName?)` | `setName`: falls back to `default` for nil or unknown names and raises when neither exists | deep clone of the item list | |
| `sel:getAllSets()` | none | deep clone of all sets | |
| `sel:addSet(setName, items)` | `setName` (string, asserted); `items` (non-empty `{weight, value}[]`, asserted) | nothing | on an existing name prints an error through `lib.print.error` and does nothing |
| `sel:updateSet(setName, newItems)` | as `addSet` | nothing | on a missing name prints an error and does nothing |
| `sel:removeSet(setName)` | `setName` (string, asserted) | nothing | |

```lua
local drops = loot:getRandomWeightedAmount('common', 3)
loot:addSet('legendary', { { 1, 'legendary_pelt' } })
```

### lib.uuid

```lua
lib.uuid.generate(): string
lib.uuid.validate(str: any): boolean
```

Side: shared

Parameters:
- `str` (any, required, `validate`): candidate value.

Returns: `generate` gives a 36-character UUID v7 string, time-ordered: the first 48 bits are the current time in ms (`os.time` on the server, `GetCloudTimeAsInt` on the client), the rest random from `math.random`. `validate` gives `true` only for a 36-character 8-4-4-4-12 hex string whose version nibble is 7 and whose variant bit is set; UUID v4 and other versions are rejected.

```lua
local id = lib.uuid.generate()
if not lib.uuid.validate(id) then return end
```

### DataView (lib.dataview, shared)

```lua
DataView.ArrayBuffer(length: number): DataView      -- also lib.dataview.ArrayBuffer
view:Buffer(): string
view:ByteLength(): number
view:GetInt8|GetUint8|GetInt16|GetUint16|GetInt32|GetUint32|GetInt64|GetUint64|GetFloat32|GetFloat64(offset: number, littleEndian?: boolean): number
view:SetInt8|SetUint8|SetInt16|SetUint16|SetInt32|SetUint32|SetInt64|SetUint64|SetFloat32|SetFloat64(offset: number, value: number, littleEndian?: boolean): DataView
```

Side: shared

Parameters:
- `length` (number, required, `ArrayBuffer`): size in bytes (default 0). Built with `string.blob` when available so natives can write into it; otherwise a zero-filled string of at least 41 bytes.
- `offset` (number, required, Get/Set): zero-based byte offset; nil is treated as 0.
- `value` (number, required, Set only): value packed with `string.pack`.
- `littleEndian` (boolean, optional): default little-endian; pass `false` for big-endian.

Returns: `ArrayBuffer` gives a view object with `Buffer`, `ByteLength` and typed Get/Set methods. `Buffer` returns the raw blob string currently held; `ByteLength` the length given at creation. Get methods return the decoded number; Set methods return the view (chainable).

Binary buffer helper loaded eagerly by `init.lua`, which sets the global `DataView`. Typical use: allocate, pass `view:Buffer()` as the output argument of a native, then read with `GetInt64` or `GetInt32`. `Buffer` returns the same mutable string a native wrote into, but every Set call replaces the stored blob with a new string, so call `Buffer()` again after a Set before handing it to a native.

```lua
local view = DataView.ArrayBuffer(16)
Citizen.InvokeNative(0x..., weaponHash, view:Buffer())
local guid = view:GetInt64(0)

view:SetInt32(0, 1234):SetFloat32(4, 0.5)
print(view:GetInt32(0), view:GetFloat32(4))
```

### w.file

```lua
w.file.load(modname: string): any | false | nil
w.file.read(modname: string) | w.file.read(resource: string, path: string): content: string | false, resource: string, modpath: string
w.file.readJson(modname: string) | w.file.readJson(resource: string, path: string): content: string | false, resource: string, modpath: string
w.file.loadJson(modname: string) | w.file.loadJson(resource: string, path: string): table | false
w.file.isExist(modname: string) | w.file.isExist(resource: string, path: string): boolean
```

Side: shared

Parameters:
- `modname` (string, required, one-argument form): dotted path without extension. `@resource.path.to.file` loads `<resource>/path/to/file.lua` (on the client the file must be in that resource's `files {}`). Without `@` the path is resolved inside the library as `modules/<path>.lua`, so a consumer resource must use the `@` form for its own files. For `w.file.load` a non-string returns nil.
- `resource, path` (string, string, two-argument form for read/readJson/loadJson/isExist): explicit resource name and slash path, no extension.

Returns:
- `load`: the chunk's return value; `false` when the file is missing or raises at runtime (message printed). A syntax error raises.
- `read` / `readJson`: file contents (or `false`) plus the resolved resource and path; `.lua` or `.json` is appended.
- `loadJson`: the decoded table; `{}` for an empty or `null` file; `false` when missing or invalid JSON (message printed).
- `isExist`: `true` when `<path>.lua` exists (only `.lua` is checked).

Uncached loaders used by the library's own modules; `w.database` uses `w.file.load` to load `@oxmysql.lib.MySQL`.

```lua
local Items = w.file.load('@w_shop.data.items')
w.file.load('@oxmysql.lib.MySQL') -- makes the MySQL global available here
local raw = w.file.readJson('w_map', 'data/labels')
local labels = w.file.loadJson('@w_map.data.labels') or {}
if w.file.isExist('@w_hud.config') then print('config present') end
```

### w.date

```lua
w.date.now(): integer
w.date.convertMsToInterval(ms: integer, lang?: table): string
```

Side: shared

Parameters:
- `ms` (integer, required, `convertMsToInterval`): duration in milliseconds.
- `lang` (table, optional): unit labels. Any falsy value (including `false`) selects the English defaults. When a custom table is passed, every unit left out is skipped and the defaults below no longer apply to it.
  - `d` (string, default `day` in the built-in table): singular day label; days are skipped when absent.
  - `ds` (string, default `days`): plural day label; required whenever `d` is set, because a duration of 2 or more days formats with `ds` and a nil `ds` raises.
  - `h` (string, default `h`): hours label; skipped when absent.
  - `min` (string, default `min`): minutes label; skipped when absent.
  - `s` (string, default `s`): seconds label; skipped when absent.
  - `ms` (string, default `ms`): milliseconds label; skipped when absent.
  - `separator` (string): between parts; `, ` in the built-in table, but a single space when a custom table omits it.
  - `now` (string, default `now`): returned when every part is zero.

Returns: `now` gives, on the server, `os.time() * 1000` (unix epoch ms, second precision) and on the client `GetGameTimer()` (ms since game start, not epoch). `convertMsToInterval` gives a string such as `1 day, 2 h, 5 min, 3 s` with zero parts omitted.

Do not compare a client `w.date.now()` value with a server one; the two clocks are different.

```lua
local started = w.date.now()
local elapsed = w.date.now() - started
print(w.date.convertMsToInterval(93784000)) -- 1 day, 2 h, 3 min, 4 s
print(w.date.convertMsToInterval(5000, { s = 'sec', separator = ' ' })) -- 5 sec
```

### lib.getFilesInDirectory

```lua
lib.getFilesInDirectory(path: string, pattern: string): files: string[], fileCount: integer
```

Side: server

Parameters:
- `path` (string, required): directory relative to the consumer resource folder (`GetResourcePath(resource) .. '/' .. path`). A path starting with `@` is passed to `io.readdir` unchanged, including the `@` character, so do not rely on that form.
- `pattern` (string, required): Lua pattern matched against each directory entry name, for example `'%.sql$'` or `'%.lua$'`.

Returns: an array of matching entry names (not full paths, not sorted) and their count. Both empty and 0 when the directory cannot be opened.

Lists real files on disk with `io.readdir` (a CfxLua extension), so the files do not need to be in `files {}`. Read them afterwards with `LoadResourceFile` or `io`.

```lua
local files = lib.getFilesInDirectory('migrations', '%.sql$')
table.sort(files)
for _, fileName in ipairs(files) do
    local sql = LoadResourceFile(GetCurrentResourceName(), ('migrations/%s'):format(fileName))
end
```

### lib.__addCommand (deprecated)

```lua
lib.__addCommand(group: string | string[] | false, name: string | string[], callback: fun(source, args, raw), parameters?: string[], help?: string)
```

Side: server

Parameters:
- `group` (string | string[] | false, required): ace principal(s) granted `command.<name>`; `false` means `builtin.everyone` (still added as an ace). The command is always registered as restricted.
- `name` (string | string[], required): command name or aliases.
- `callback` (function, required): handler `(source, args, raw)`.
- `parameters` (string[], optional): entries of the form `argName:type` or `argName:?type` (optional); type `number` converts; an arg named `target` with value `me` becomes the caller; type mismatches send a chat error to the caller (or print for console).
- `help` (string, optional): suggestion text.

Returns: nothing

Pre-3.0 syntax kept for compatibility. `lib.addCommand` falls back to it automatically, with a console warning, when called with the old argument shape. Do not use in new code.

```lua
lib.__addCommand('group.admin', 'oldcmd', function(source, args) end, { 'target:number', 'reason:?string' }, 'Legacy command')
```

### Events

| Name | Side | Payload | Meaning |
|---|---|---|---|
| `onPlayerBucketChange` | server (local event) | `source: number, newBucket: number, oldBucket: number` | Consumed by the `w.bucket` module to move a player between its bucket lists. Nothing happens when `oldBucket` equals `newBucket`. The consumer resource is responsible for triggering it right after `SetPlayerRoutingBucket`; the library does not. |

```lua
TriggerEvent('onPlayerBucketChange', source, 12, 0)
```

### Convars

| Name | Side | Value | Meaning |
|---|---|---|---|
| `w_lib:printlevel` | shared | `error`, `warn`, `info`, `verbose`, `debug` (default `info`) | Global threshold for `lib.print`. Server scripts read server convars; client scripts read replicated convars, so use `setr` for the client side. |
| `w_lib:printlevel:<resourceName>` | shared | same values | Per-resource override of `w_lib:printlevel`. |
| `<resourceName>:debug` | shared | `on` enables, anything else disables; applied live | Enables `dprint` output (and prints a "debug mode" warning) for the whole resource. Use `setr` when client scripts must see it. |
| `<resourceName>:debug:<module>` | shared | `on` / anything else; applied live | Enables `dprint` calls made inside one library module's files (module = folder under `modules/`, for example `menu`, `prompt`) as loaded by that resource. Does not affect `dprint` calls in consumer scripts. |
| `all:debug:<module>` | shared | `on` / anything else; applied live | Same as above for every resource. |
| `w_lib:logger` | server | `datadog` (default), `loki`, `fivemanage` | Selects the `lib.logger` backend; anything else disables `lib.logger`. Read once when the logger module is first used in a resource. |
| `w_lib:logger:hostname` | server | string | Hostname reported in every log; default `sv_projectName` with colour codes stripped, or `fxserver`. |
| `datadog:key` | server | Datadog API key (quotes stripped) | Empty disables the logger. Payload fields: hostname, service=event, message, resource, ddsource=source, ddtags. |
| `datadog:site` | server | site domain, default `datadoghq.com` | Endpoint becomes `https://http-intake.logs.<site>/api/v2/logs`. |
| `loki:endpoint` | server | host or URL | `https://` is prepended when no scheme is given; `/loki/api/v1/push` is appended. Not validated: an empty value still produces requests. Streams are labelled server=hostname, resource, event; each value line holds the message plus player tags and extra key:value tags. |
| `loki:user` | server | string | Basic-auth user; when set an Authorization header is built with `loki:password` (falls back to `loki:key`). |
| `loki:password` / `loki:key` | server | string | Basic-auth password. |
| `loki:tenant` | server | string | Sent as `X-Scope-OrgID` when non-empty. |
| `fivemanage:key` | server | authorization token | Empty disables the logger. Posts to `https://api.fivemanage.com/api/logs/batch` with level info, message, resource and metadata (hostname, service, source, player identifiers, extra tags). |
| `fivemanage:dataset` | server | string | Sent as `X-Fivemanage-Dataset` when non-empty. |

```cfg
setr w_lib:printlevel "info"
set w_lib:printlevel:w_inventory "debug"
setr w_hud:debug "on"
setr all:debug:menu "on"

set w_lib:logger "loki"
set w_lib:logger:hostname "wraith-main"
set loki:endpoint "logs.example.com"
set loki:user "wraith"
set loki:password "secret"
```

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| none | | | This subsystem registers no console or chat commands of its own. Commands are created by the consumer resource through `lib.addCommand`. |

## Client world helpers under lib.* (entities, streaming, keybinds, zones, points, raycast, markers, DUI, scaleform, vehicles)

### How these helpers reach a consumer resource

Everything in this subsystem except the vehicle-properties functions and the zone creator lives under `w_lib/imports/<name>/`. When a consumer resource loads `@w_lib/init.lua`, the first read of `lib.<name>` loads `imports/<name>/shared.lua` plus `imports/<name>/client.lua` or `server.lua` (concatenated, shared first) into the consumer resource itself, using `LoadResourceFile` and `load`. The code therefore runs in the consumer's Lua VM, not in the library's. This has three consequences:

- Callbacks such as `onEnter`, `onPressed`, `nearby`, `inside` and the `rawKeys` listener are real Lua functions and can be passed directly.
- State (zones, points, keybinds, DUI handles) is private to the consumer resource.
- `exports.w_lib:<name>` is not a route to any of these helpers. The export fallback in `init.lua` only triggers when no import file exists for the name.

The same `lib.<name>` is also reachable as `w.<name>` (and `jo.<name>`) in a consumer: `init.lua` sets `w = lib` when the module layer is not present, and `jo = w`.

Which side a helper exists on follows its file: a `client.lua` only means client-only; a `shared.lua` means both sides; a helper with both `client.lua` and `server.lua` has two different signatures (`getClosestPlayer`, `getNearbyPlayers`, `ped.create`, `prop.create`, `vehicle.create`), so read the entry that matches the side you are on.

`lib.getVehicleProperties` and `lib.setVehicleProperties` are different. They are defined under `resource/` inside the library itself, are auto-exported by `resource/init.lua` (any `lib.<name>` assigned from a `resource/` file becomes `exports.w_lib:<name>`), and reach a consumer through the export fallback. The client file exits immediately on RedM (`if cache.game == 'redm' then return end`), so on a RedM client neither function exists. Only the server-side `setVehicleProperties` (a statebag write) exists on RedM.

### Entity wrappers and statebags

`lib.gameEntity` is a `lib.class` base; `lib.ped`, `lib.prop` and `lib.vehicle` extend it and `lib.player` extends `lib.ped`. An instance comes either from `lib.<type>:new(handle)` (`lib.player:new(serverId)`) or from the side-specific `lib.<type>.create(...)`, which requests the model on the client and wraps the new handle. Every instance exposes `handle`, `netId`, `statebag` (`'entity:<netId>'`, `'player:<serverId>'`, or `'localEntity:<handle>'` when `netId` is 0) and `type` (`'Ped'`, `'Prop'`, `'Vehicle'`, `'Player'`).

Statebag writes go through `:set(key, value, mode)`:

- `mode` nil writes an unreplicated local value.
- `:setr` (mode 1) writes a replicated value.
- `:sets` (mode 2) writes a synced value and is only allowed on Player instances (error otherwise).
- A local entity (`netId` 0) silently drops the mode.

On the server, `setr` writes directly and `sets` additionally fires the internal event `w_lib:setStateBagValue` to the target player so `LocalPlayer.state[key]` is updated there. On the client, `setr` is direct when the Cfx convar `sv_stateBagStrictMode` is false. When it is true, and always for `sets`, the client asks the server through the internal callback `w_lib:requestSetStateBag`. The server accepts only if a `lib.hook` pipeline (`'setEntityState'` or `'setPlayerState'`) has at least one hook registered for that key and every hook returns true, and for player bags only if the caller targets its own bag. When accepted, the server writes the bag and the client then also writes the value locally.

The library itself registers hooks only for the keys `'w_lib:setVehicleProperties'` (only clearing it, and only when the stored plate matches the vehicle) and `'w_entity_setonground'` (value true or nil). Consequence: in strict mode a client `setr` of your own key returns false unless your server registered a hook, and a client `sets` always returns false unless you registered a `'setPlayerState'` hook.

Server-side `prop:setOnGround()` and `vehicle:setOnGround()` do not place anything themselves. They set the replicated key `'w_entity_setonground' = true`, and the library's client handler on the machine that streams the entity waits for collision, drops it to the ground and clears the key. Gotcha in the current source: that handler wraps non-vehicles with `lib.object:new`, and no `imports/object` module exists, so for props the handler errors before placing anything and the key is never cleared. Only `vehicle:setOnGround()` works from the server. Place props on the client instead.

### Points and zones

Both use the library's spatial grid (`lib.grid`, loaded lazily) and a single 300 ms thread per resource that reads the player ped position.

Points are radius checks: `onEnter` fires once when the distance becomes less than or equal to `distance`, `onExit` fires once when it leaves, and `nearby` runs every frame (`SetInterval 0`) for every point currently inside, while `point.currentDistance` and `point.isClosest` are updated. `lib.points.getClosestPoint()` returns the point with the smallest `currentDistance`.

Zones are polygons (`poly`, `box`) or spheres: `onEnter`/`onExit` fire once per transition, and `inside` runs every frame while the player is in the zone. The order is deterministic: all exits are processed first, farthest first, then entries nearest first. `zone.distance` is refreshed every tick while the zone is nearby. On the server, `lib.zones.*` still builds the zone (so `zone:contains(coords)` works for server-side checks) but no thread runs, so `onEnter`/`onExit`/`inside`/`debug` never fire there.

Loading `lib.zones` also defines a global named `Zones` in the consumer resource pointing at the registry; do not rely on a global of that name yourself. Any extra field you put in a point or zone table is kept on the object (w_inventory stores `inv`, `invId`, `instance` and so on, and reads them back from `getClosestPoint()`). Ids come from `#table + 1`, so they are not stable after removals; keep your own reference and call `:remove()`.

### Keys

`lib.addKeybind` registers `'+name'` / `'-name'` commands and a `RegisterKeyMapping`, so the binding appears in the player's key settings and the player can rebind it. Because command names are global on the server, prefix `name` with your resource name (w_wheel uses `GetCurrentResourceName() .. '_wheel_open'`). There is no API to unregister a keybind; use `:disable(true)`. RedM has no `GET_CONTROL_INSTRUCTIONAL_BUTTON`, so `keybind.currentKey` returns the `defaultKey` you passed, not what the player rebound.

`lib.rawKeys.listen` is the silent alternative: it uses `RegisterRawKeymap` under a name prefixed with your resource, does not appear in settings, cannot be rebound, and calls your callback with true on press and false on release. `lib.rawKeys` and `w.rawKeys` are the same table in a consumer: `imports/rawKeys/client.lua` returns `w.rawKeys` when the module layer (`modules/raw-keys`) already defined it, otherwise it defines `listen`, `removeListener` and `getVK` itself. Only those three are documented here; `w.rawKeys.bind` does not exist for consumers.

`lib.disableControls` is a reference-counted set of control ids; call `lib.disableControls()` every frame to apply `DisableControlAction` for everything currently added.

### Streaming, raycast, markers, DUI, scaleform

Every `lib.request*` helper validates its argument, requests the asset and yields (`lib.waitFor`) until it has loaded, returning the asset (`requestModel` returns the hash, so it accepts either a model name or a hash). They raise an error on invalid input or timeout. The default timeout is 30000 ms for the `streamingRequest` family and `requestAudioBank` (the annotations claim 10000, but the code uses `timeout or 30000`); `requestScaleformMovie` is the exception with `lib.waitFor`'s 1000 ms default. Because they yield, call them from a thread.

`lib.playAnim` requests the dictionary, calls `TaskPlayAnim` with defaults `8.0 / -8.0 / -1` and immediately marks the dictionary as no longer needed. `lib.raycast.fromCoords` yields until the shape test resolves and returns `hit, entityHit, endCoords, surfaceNormal, materialHash`, ignoring `cache.ped`; `fromCamera` builds the destination from the final rendered camera. `lib.marker.new` returns a table with a `:draw()` method you call every frame; the type may be a name from the GTA-derived enum or, as RedM consumers do, a raw marker hash such as `0x07DCE236`. `lib.dui` and `lib.scaleform` are `lib.class` classes created with `:new({...})`; DUIs are destroyed automatically when the consumer resource stops.

The zone creator is a developer tool: `/zone poly|box|sphere [useLast]` needs the `command.zone` ace (restricted command) and the save needs the `command` ace. On Enter it sends the internal event `w_lib:saveZone`, which appends generated Lua to `w_lib/created_zones.lua` on the server. Its key handling uses GTA numeric control ids on both games (only look and chat controls are translated for RedM), so the key layout listed under the command is the FiveM one.

---

### lib.gameEntity

```lua
lib.gameEntity  -- base class; use lib.ped / lib.prop / lib.vehicle / lib.player
```

Side: shared

Parameters: none (do not construct it directly).

Returns: Class table. Instances expose `handle` (number), `netId` (number, 0 for local entities), `statebag` (string: `'entity:<netId>'`, `'player:<serverId>'` or `'localEntity:<handle>'`) and `type` (string).

Base class of every entity wrapper. Its constructor is package-private, so do not call `lib.gameEntity:new` yourself; create a `lib.ped`, `lib.prop`, `lib.vehicle` or `lib.player` instead. All methods below are inherited by those classes. `setHandle` computes `netId` and `statebag` and calls `EnsureEntityStateBag` for local entities and for server-side non-player entities.

```lua
local veh = lib.vehicle:new(vehicleHandle)
print(veh.handle, veh.netId, veh.statebag, veh.type)
```

### GameEntity:set

```lua
entity:set(key: string, value: any, mode?: 1 | 2): boolean
```

Side: shared

Parameters:
- `key` (string, required): statebag key.
- `value` (any, required): msgpack-able value; nil clears.
- `mode` (number, optional): nil = local/unreplicated write; 1 = replicated (same as `setr`); 2 = synced player-only value (same as `sets`). Ignored when `netId` is 0.

Returns: boolean, true on success. On the client, mode 1 under `sv_stateBagStrictMode=true` and mode 2 always go through the server callback `w_lib:requestSetStateBag`; the call returns false when the server has no `lib.hook` registered for the key or a hook rejects it, and otherwise writes the value locally (unreplicated) after the server wrote the bag and returns true.

Writes a value to the entity's statebag. Mode 2 on a non-Player instance raises an error. On the server, mode 2 additionally triggers the internal client event `w_lib:setStateBagValue` on that player so `LocalPlayer.state[key]` is updated. Yields on the client when it has to ask the server.

```lua
local ped = lib.ped:new(handle)
ped:set('owner', cache.serverId) -- local only
ped:set('job', 'doctor', 1)      -- replicated
```

### GameEntity:setr

```lua
entity:setr(key: string, value: any): boolean
```

Side: shared

Parameters:
- `key` (string, required): statebag key.
- `value` (any, required): value to replicate; nil clears.

Returns: boolean.

Shortcut for `entity:set(key, value, 1)`. Server: direct replicated write. Client: direct when `sv_stateBagStrictMode` is false; otherwise validated by server hooks (the library only accepts `'w_entity_setonground'` = true/nil and clearing `'w_lib:setVehicleProperties'` when the stored plate matches), so register your own `'setEntityState'` hook server-side for other keys.

```lua
if not veh:setr('locked', true) then print('server rejected the write') end
```

### GameEntity:sets

```lua
entity:sets(key: string, value: any): boolean
```

Side: shared

Parameters:
- `key` (string, required): statebag key.
- `value` (any, required): value synced between server and the entity owner.

Returns: boolean.

Shortcut for `entity:set(key, value, 2)`. Only valid on `lib.player` instances (error otherwise). From the server it writes the value and pushes it to the player's `LocalPlayer.state`. From the client it always goes through the server and returns false unless a server `'setPlayerState'` hook accepts the key and the target is the caller's own bag.

```lua
-- server
local player = lib.player:new(source)
player:sets('hunger', 80)
```

### GameEntity:get, has, keys

```lua
entity:get(key: string): any
entity:has(key: string): boolean
entity:keys(): string[]
```

Side: shared

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `get(key)` | `key` (string, required) | any: `GetStateBagValue(entity.statebag, key)` | Reads a statebag value. |
| `has(key)` | `key` (string, required) | boolean | `StateBagHasKey` on the entity's bag. |
| `keys()` | none | string[]: all keys in the bag | `GetStateBagKeys` on the entity's bag. |

```lua
local job = lib.player:new(-1):get('job')
if veh:has('owner') then print('owned') end
for _, k in ipairs(veh:keys()) do print(k) end
```

### GameEntity:setHandle

```lua
entity:setHandle(handle: number)
```

Side: shared

Parameters:
- `handle` (number, required): entity script handle to bind the wrapper to.

Returns: nil.

Rebinds a wrapper to a handle: stores it, computes `netId` (server id for Player instances, otherwise `NetworkGetNetworkIdFromEntity`) and `statebag`, and calls `EnsureEntityStateBag` for local entities and for server-side non-player entities. The constructors call it for you; it is useful only when you built a wrapper with handle 0 (`lib.ped:new(0)`) and the entity appears later.

```lua
local ped = lib.ped:new(0)
-- later, once the entity exists
ped:setHandle(handle)
```

### GameEntity position, model and heading helpers

```lua
entity:getCoords(): vector3
entity:setCoords(x: number, y: number, z: number, deadFlag?: boolean, ragdollFlag?: boolean, clearArea?: boolean)
entity:getModel(): number
entity:getHeading(): number
entity:setHeading(heading: number)
```

Side: shared

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `getCoords()` | none | vector3 | `GetEntityCoords(handle)`. |
| `setCoords(x, y, z, deadFlag?, ragdollFlag?, clearArea?)` | `x`, `y`, `z` (number, required); `deadFlag`, `ragdollFlag`, `clearArea` (boolean, optional, default false) | nil | `SetEntityCoords(handle, x, y, z, true, deadFlag, ragdollFlag, clearArea)`. |
| `getModel()` | none | number: model hash | `GetEntityModel(handle)`. |
| `getHeading()` | none | number | `GetEntityHeading(handle)`. |
| `setHeading(heading)` | `heading` (number, required): degrees | nil | `SetEntityHeading(handle, heading)`. |

```lua
local pos = ped:getCoords()
prop:setCoords(100.0, 200.0, 30.0)
print(ped:getModel(), ped:getHeading())
ped:setHeading(90.0)
```

### GameEntity:getRoutingBucket

```lua
entity:getRoutingBucket(): number
```

Side: shared

Parameters: none.

Returns: number. The server reads `GetEntityRoutingBucket`; the client returns the replicated statebag key `'bucket'` or 0.

Routing bucket of the entity. The client value is only meaningful when the bucket was set through `setRoutingBucket` on the server (which replicates `'bucket'`).

```lua
print(veh:getRoutingBucket())
```

### GameEntity:setRoutingBucket

```lua
entity:setRoutingBucket(bucket: number)
```

Side: server

Parameters:
- `bucket` (number, required): routing bucket id.

Returns: nil (does nothing on the client).

`SetEntityRoutingBucket` and replicates the value under the statebag key `'bucket'`. No-op on the client.

```lua
local veh = lib.vehicle:new(NetworkGetEntityFromNetworkId(netId))
veh:setRoutingBucket(5)
```

### lib.ped:new

```lua
lib.ped:new(handle: number): Ped
```

Side: shared

Parameters:
- `handle` (number, required): existing ped handle. 0 creates an empty wrapper (handle 0, no netId/statebag) without touching natives.

Returns: Ped instance (type `'Ped'`) with all GameEntity methods plus `getArmour`/`setArmour`.

Wraps an existing ped. A handle greater than 0 is resolved to a netId/statebag immediately, so the entity must exist and (on the server) be network-registered.

```lua
local ped = lib.ped:new(PlayerPedId())
ped:setr('busy', true)
```

### lib.ped.create (client)

```lua
lib.ped.create(model: string | number, x: number, y: number, z: number, heading?: number, isNetworked?: boolean, bScriptHostPed?: boolean): Ped
```

Side: client

Parameters:
- `model` (string | number, required): model name or hash; loaded with `lib.requestModel` (yields, errors on invalid model).
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional, default 0).
- `isNetworked` (boolean, optional, default false).
- `bScriptHostPed` (boolean, optional, default false).

Returns: Ped instance wrapping the new handle.

Client-side ped creation. On RedM (`cache.game == 'redm'`) it calls the model-first RDR3 `CreatePed` with two extra trailing false flags; on FiveM the pedType-first form. The model is released with `SetModelAsNoLongerNeeded` after creation.

```lua
CreateThread(function()
    local ped = lib.ped.create('a_m_m_valfarmer_01', -300.0, 800.0, 118.0, 90.0, true)
    SetEntityAsMissionEntity(ped.handle, true, true)
end)
```

### lib.ped.create (server)

```lua
lib.ped.create(model: string | number, x: number, y: number, z: number, heading?: number): Ped, reason?: string
```

Side: server

Parameters:
- `model` (string | number, required): model hash or name (passed straight to `CreatePed`; no request is possible server-side).
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional, default 0).

Returns: Ped instance. On RedM (convar `gamename` `'rdr3'`/`'redm'`, or `GetGameName`) it returns `lib.ped:new(0)` plus the string `'server_create_ped_unsupported'` and creates nothing. On FiveM it calls `CreatePed(0, model, x, y, z, heading, true, true)` and waits up to 2500 ms for `DoesEntityExist` to be true on two consecutive checks; on failure (or if wrapping the handle raises) it returns `lib.ped:new(0)`.

Server-side ped creation is not supported on RedM because FXServer's `CreatePed` RPC uses the GTA argument order; create the ped on a client instead. Check `ped.handle > 0` before use.

```lua
local ped, reason = lib.ped.create(`a_m_m_valfarmer_01`, -300.0, 800.0, 118.0, 90.0)
if ped.handle == 0 then print('ped not created', reason) end
```

### Ped:getArmour, Ped:setArmour

```lua
ped:getArmour(): number
ped:setArmour(amount: number)
```

Side: shared

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `getArmour()` | none | number | `GetPedArmour(handle)`. |
| `setArmour(amount)` | `amount` (number, required): armour value | nil | `SetPedArmour(handle, amount)`. |

```lua
print(ped:getArmour())
ped:setArmour(50)
```

### lib.prop:new

```lua
lib.prop:new(handle: number): Prop
```

Side: shared

Parameters:
- `handle` (number, required): existing object handle.

Returns: Prop instance (type `'Prop'`).

Wraps an existing object. Unlike `lib.ped:new`, a handle of 0 is still passed to `setHandle` (netId 0, statebag `'localEntity:0'`).

```lua
local prop = lib.prop:new(objectHandle)
prop:setHeading(180.0)
```

### lib.prop.create (client)

```lua
lib.prop.create(model: string | number, x: number, y: number, z: number, heading?: number, isNetworked?: boolean, netMissionEntity?: boolean, dynamic?: boolean): Prop
```

Side: client

Parameters:
- `model` (string | number, required): loaded via `lib.requestModel`.
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional): applied with `setHeading` after creation when given.
- `isNetworked` (boolean, optional, default false).
- `netMissionEntity` (boolean, optional, default false).
- `dynamic` (boolean, optional, default false).

Returns: Prop instance.

`CreateObject(hash, x, y, z, isNetworked, netMissionEntity, dynamic)` wrapper; releases the model afterwards.

```lua
local crate = lib.prop.create('p_crate01x', pos.x, pos.y, pos.z, 0.0, true)
crate:setOnGround()
```

### lib.prop.create (server)

```lua
lib.prop.create(model: string | number, x: number, y: number, z: number, heading?: number, dynamic?: boolean): Prop
```

Side: server

Parameters:
- `model` (string | number, required): model hash or name passed to `CreateObjectNoOffset`.
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional): applied with `setHeading` when given.
- `dynamic` (boolean, optional, default false).

Returns: Prop instance (networked, mission entity).

`CreateObjectNoOffset(model, x, y, z, true, true, dynamic)`. No existence wait is performed, unlike `ped.create`.

```lua
local crate = lib.prop.create(`p_crate01x`, 100.0, 200.0, 30.0, 0.0)
```

### Prop:setOnGround

```lua
prop:setOnGround(): boolean
```

Side: shared

Parameters: none.

Returns: client: `PlaceObjectOnGroundProperly` result; server: result of `setr('w_entity_setonground', true)`.

The client places the object directly. The server only sets the replicated key `'w_entity_setonground' = true` and relies on the library's client handler; in the current source that handler wraps non-vehicle entities with `lib.object:new`, which is not defined anywhere, so for props the client errors, the object is not placed and the key is never cleared. Treat the server form as non-functional for props and place them on the client.

```lua
-- client
prop:setOnGround()
```

### lib.vehicle:new

```lua
lib.vehicle:new(handle: number): Vehicle
```

Side: shared

Parameters:
- `handle` (number, required): existing vehicle handle.

Returns: Vehicle instance (type `'Vehicle'`).

Wraps an existing vehicle (the library itself uses it in the vehicleProperties statebag handler).

```lua
local veh = lib.vehicle:new(cache.vehicle)
print(veh:getPlate())
```

### lib.vehicle.create (client)

```lua
lib.vehicle.create(model: string | number, x: number, y: number, z: number, heading?: number, isNetworked?: boolean, netMissionEntity?: boolean): Vehicle
```

Side: client

Parameters:
- `model` (string | number, required): loaded via `lib.requestModel`.
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional, default 0).
- `isNetworked` (boolean, optional, default false).
- `netMissionEntity` (boolean, optional, default false).

Returns: Vehicle instance.

`CreateVehicle` wrapper; releases the model afterwards.

```lua
local wagon = lib.vehicle.create('wagon02x', pos.x, pos.y, pos.z, heading, true, true)
```

### lib.vehicle.create (server)

```lua
lib.vehicle.create(model: string | number, type: VehicleType, x: number, y: number, z: number, heading?: number): Vehicle
```

Side: server

Parameters:
- `model` (string | number, required): model hash or name.
- `type` (string, required): `'automobile' | 'bike' | 'boat' | 'heli' | 'plane' | 'submarine' | 'trailer' | 'train'`. Used only when the native `CreateVehicleServerSetter` exists (FiveM); otherwise ignored and `CreateVehicle(model, x, y, z, heading, true, true)` is used.
- `x`, `y`, `z` (number, required): position.
- `heading` (number, optional, default 0).

Returns: Vehicle instance.

Note that the second positional argument is the vehicle type, unlike the client signature. No existence wait is performed.

```lua
local veh = lib.vehicle.create(`wagon02x`, 'automobile', 100.0, 200.0, 30.0, 90.0)
```

### Vehicle:getType, getPlate, setPlate

```lua
vehicle:getType(): string
vehicle:getPlate(): string
vehicle:setPlate(plate: string)
```

Side: shared

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `getType()` | none | VehicleType string | `GetVehicleType(handle)`. |
| `getPlate()` | none | string | `GetVehicleNumberPlateText(handle)`. |
| `setPlate(plate)` | `plate` (string, required): plate text | nil | `SetVehicleNumberPlateText(handle, plate)`. |

```lua
print(veh:getType())
local plate = veh:getPlate()
veh:setPlate('WRAITH01')
```

### Vehicle:setOnGround

```lua
vehicle:setOnGround(): boolean?
```

Side: shared

Parameters: none.

Returns: client: `SetVehicleOnGroundProperly` result; server: nil (the `setr` result is not returned).

Direct on the client. On the server it sets the replicated key `'w_entity_setonground' = true` and the library's client handler on the machine that streams the vehicle waits for collision, drops it and clears the key. This is the only entity type for which the server form currently works (see Prop:setOnGround).

```lua
veh:setOnGround()
```

### lib.player:new

```lua
lib.player:new(netId: number): Player
```

Side: shared

Parameters:
- `netId` (number, required): player server id. -1 means the local player on the client (`cache.serverId`) and the player at index 0 (`GetPlayerFromIndex(0)`) on the server.

Returns: Player instance (type `'Player'`) with `playerId` (client: local player index from `GetPlayerFromServerId`; server: server id), `netId` = server id, statebag `'player:<serverId>'`, and `handle` resolved dynamically via `GetPlayerPed(playerId)` on the client and stored once on the server.

Wraps a player. Inherits Ped and GameEntity methods; `:sets` is allowed on this type.

```lua
local me = lib.player:new(-1)
print(me.handle, me.netId, me:get('job'))
```

### Player:setModel

```lua
player:setModel(model: string | number)
```

Side: shared

Parameters:
- `model` (string | number, required): model to apply.

Returns: nil.

`SetPlayerModel(playerId, model)`. The model must already be loaded on the client.

```lua
lib.requestModel('mp_male')
lib.player:new(-1):setModel('mp_male')
```

### Player:getRoutingBucket

```lua
player:getRoutingBucket(): number
```

Side: shared

Parameters: none.

Returns: number. Server: `GetPlayerRoutingBucket(playerId)`; client: the replicated `'bucket'` state or 0.

Overrides `GameEntity:getRoutingBucket` for players.

```lua
print(lib.player:new(source):getRoutingBucket())
```

### Player:setRoutingBucket

```lua
player:setRoutingBucket(bucket: number)
```

Side: server

Parameters:
- `bucket` (number, required): bucket id.

Returns: nil (no-op on the client).

`SetPlayerRoutingBucket` and replicates `'bucket'` on the player statebag.

```lua
lib.player:new(source):setRoutingBucket(3)
```

### lib.getClosestObject, lib.getClosestPed, lib.getClosestVehicle

```lua
lib.getClosestObject(coords: vector3, maxDistance?: number): number?, vector3?
lib.getClosestPed(coords: vector3, maxDistance?: number): number?, vector3?
lib.getClosestVehicle(coords: vector3, maxDistance?: number, includePlayerVehicle?: boolean): number?, vector3?
```

Side: shared

Parameters (all three):
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).
- `includePlayerVehicle` (boolean, optional, `getClosestVehicle` only): client only, include `cache.vehicle` (default excluded). Ignored on the server.

| Function | Returns | Description |
|---|---|---|
| `getClosestObject` | object handle and its coords, or nil, nil | Scans `GetGamePool('CObject')` for the nearest object strictly closer than `maxDistance`. |
| `getClosestPed` | ped handle and coords, or nil, nil | Nearest non-player ped (`IsPedAPlayer` false) from `GetGamePool('CPed')`. |
| `getClosestVehicle` | vehicle handle and coords | Nearest vehicle from `GetGamePool('CVehicle')`. |

```lua
local obj, objCoords = lib.getClosestObject(GetEntityCoords(cache.ped), 3.0)
local ped = lib.getClosestPed(GetEntityCoords(cache.ped), 5.0)
local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0)
```

### lib.getClosestPlayer (client)

```lua
lib.getClosestPlayer(coords: vector3, maxDistance?: number, includePlayer?: boolean): playerId?, playerPed?, playerCoords?, playerVehicle?
```

Side: client

Parameters:
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).
- `includePlayer` (boolean, optional, default false): include the local player.

Returns: local player index, ped handle, coords, and the vehicle the ped is in (0 when on foot).

Iterates `GetActivePlayers()`. When the ped is in a vehicle, coords come from `GetWorldPositionOfEntityBone(ped, 0)`. Returns a player index; use `GetPlayerServerId` to convert.

```lua
local id, ped, pos, veh = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0)
if id then TriggerServerEvent('myres:give', GetPlayerServerId(id)) end
```

### lib.getClosestPlayer (server)

```lua
lib.getClosestPlayer(coords: vector3, maxDistance?: number, ignorePlayerId?: number | false): playerId?, playerPed?, playerCoords?
```

Side: server

Parameters:
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).
- `ignorePlayerId` (number | false, optional): server id to skip (usually the source).

Returns: server id, ped handle, coords.

The server variant iterates `GetActivePlayers()`; note that the third argument is a server id to ignore, not a boolean, and there is no vehicle return.

```lua
local target = lib.getClosestPlayer(GetEntityCoords(GetPlayerPed(source)), 3.0, source)
```

### lib.getNearbyObjects, lib.getNearbyPeds, lib.getNearbyVehicles

```lua
lib.getNearbyObjects(coords: vector3, maxDistance?: number): { object: number, coords: vector3 }[]
lib.getNearbyPeds(coords: vector3, maxDistance?: number): { ped: number, coords: vector3 }[]
lib.getNearbyVehicles(coords: vector3, maxDistance?: number, includePlayerVehicle?: boolean): { vehicle: number, coords: vector3 }[]
```

Side: shared

Parameters (all three):
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).
- `includePlayerVehicle` (boolean, optional, `getNearbyVehicles` only): client only, include `cache.vehicle`. Ignored on the server.

| Function | Returns | Description |
|---|---|---|
| `getNearbyObjects` | array of `{ object, coords }` | All objects within range, unsorted. |
| `getNearbyPeds` | array of `{ ped, coords }` for non-player peds | All NPC peds within range, unsorted. |
| `getNearbyVehicles` | array of `{ vehicle, coords }` | All vehicles within range, unsorted. |

```lua
for _, e in ipairs(lib.getNearbyObjects(pos, 10.0)) do print(e.object) end
local peds = lib.getNearbyPeds(GetEntityCoords(cache.ped), 15.0)
local vehs = lib.getNearbyVehicles(GetEntityCoords(cache.ped), 25.0, true)
```

### lib.getNearbyPlayers (client)

```lua
lib.getNearbyPlayers(coords: vector3, maxDistance?: number, includePlayer?: boolean): { id: number, ped: number, coords: vector3, vehicle: number }[]
```

Side: client

Parameters:
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).
- `includePlayer` (boolean, optional, default false): include the local player.

Returns: array of `{ id = player index, ped, coords, vehicle (0 on foot) }`.

`id` is a local player index; convert with `GetPlayerServerId`. Coords come from bone 0 when the ped is in a vehicle.

```lua
local nearby = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 3.0)
if #nearby == 1 then print(GetPlayerServerId(nearby[1].id)) end
```

### lib.getNearbyPlayers (server)

```lua
lib.getNearbyPlayers(coords: vector3, maxDistance?: number): { id: number, ped: number, coords: vector3 }[]
```

Side: server

Parameters:
- `coords` (vector3, required): origin.
- `maxDistance` (number, optional, default 2.0).

Returns: array of `{ id = server id, ped, coords }`. No vehicle field.

Includes every player, including the one at `coords`.

```lua
for _, p in ipairs(lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), 20.0)) do
    if p.id ~= source then TriggerClientEvent('myres:hear', p.id) end
end
```

### lib.getRelativeCoords

```lua
lib.getRelativeCoords(coords: vector3 | vector4, headingOrRotation?: number | vector3, offset: vector3): vector3 | vector4
```

Side: shared

Parameters:
- `coords` (vector3 | vector4, required): origin. If a vector4 is given, its `w` is used as the heading when no numeric heading is passed, and a vector4 (with that `w`) is returned.
- `headingOrRotation` (number | vector3, optional): heading in degrees, or a full rotation vector3 (pitch, roll, yaw in degrees). Omit when `coords` is a vector4 (then pass the offset as the second argument).
- `offset` (vector3, required): local-space offset (x right, y forward, z up).

Returns: vector3 (or vector4 keeping the heading when `coords` was a vector4).

Three call forms: `(vec3, heading, offset)`, `(vec4, offset)`, `(vec3, rotationVec3, offset)`. With a rotation vector a full 3D rotation is applied; with a heading only the xy plane is rotated and z is added directly.

```lua
local front = lib.getRelativeCoords(GetEntityCoords(cache.ped), GetEntityHeading(cache.ped), vec3(0, 2.0, 0))
local spot = lib.getRelativeCoords(vec4(100.0, 200.0, 30.0, 90.0), vec3(1.0, 0, 0)) -- vector4
```

### lib.request* helpers

```lua
lib.requestModel(model: string | number, timeout?: number): number
lib.requestAnimDict(animDict: string, timeout?: number): string
lib.requestAnimSet(animSet: string, timeout?: number): string
lib.requestAudioBank(audioBank: string, timeout?: number): string
lib.requestNamedPtfxAsset(ptFxName: string, timeout?: number): string
lib.requestStreamedTextureDict(textureDict: string, timeout?: number): string
lib.requestScaleformMovie(scaleformName: string, timeout?: number): number
lib.requestWeaponAsset(weaponType: string | number, timeout?: number, weaponResourceFlags?: number, extraWeaponComponentFlags?: number): string | number
```

Side: client

Every helper yields until the asset is loaded and errors on invalid input or timeout, so call them from a thread.

| Function | Argument validation | Timeout default | Returns | Notes |
|---|---|---|---|---|
| `requestModel` | name (joaat applied) or hash; error if neither `IsModelValid` nor `IsModelInCdimage` | 30000 ms | the model hash once loaded | Release with `SetModelAsNoLongerNeeded` after spawning. |
| `requestAnimDict` | error if not a string or `DoesAnimDictExist` is false | 30000 ms | the dictionary name (immediately if already loaded) | Remember `RemoveAnimDict` when done. |
| `requestAnimSet` | error if not a string | 30000 ms | the clipset name | `RequestAnimSet` + wait. |
| `requestAudioBank` | script audio bank name | 30000 ms | the bank name once `RequestScriptAudioBank` returns true | Polls `RequestScriptAudioBank(bank, false)` until it succeeds. |
| `requestNamedPtfxAsset` | error if not a string | 30000 ms | the asset name | `RequestNamedPtfxAsset` + wait. |
| `requestStreamedTextureDict` | error if not a string | 30000 ms | the dictionary name | `RequestStreamedTextureDict` + wait. |
| `requestScaleformMovie` | error if not a string | 1000 ms (`lib.waitFor` default); pass `false` to wait forever | scaleform handle once `HasScaleformMovieLoaded` is true | Used internally by `lib.scaleform`. |
| `requestWeaponAsset` | name or hash; error for other types | 30000 ms | the `weaponType` argument | `RequestWeaponAsset(weapon, flags, componentFlags)` + wait. |

`requestWeaponAsset` extra parameters:
- `weaponResourceFlags` (number, optional, default 31, all anims): 1 BASE, 2 COVER, 4 MELEE, 8 MOTION, 16 STEALTH, 32 ALL_MOVEMENT_VARIATION. Error if not a number.
- `extraWeaponComponentFlags` (number, optional, default 0): 1 FLASH, 2 SCOPE, 4 SUPP, 8 SCLIP2, 16 GRIP. Error if not a number.

```lua
CreateThread(function()
    local hash = lib.requestModel('a_c_horse_arabian_white')
    local horse = CreatePed(hash, x, y, z, 0.0, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)

    lib.requestAnimDict('amb_wander@code_human_wander@male_a')
    lib.requestAnimSet('move_m@drunk@verydrunk')
    lib.requestAudioBank('DLC_HEIST_HACKING_SNAKE_SOUNDS')
    lib.requestNamedPtfxAsset('scr_re_hitch')
    UseParticleFxAsset('scr_re_hitch')
    lib.requestStreamedTextureDict('blips_mp')
    local sf = lib.requestScaleformMovie('mp_big_message_freemode', 5000)
    lib.requestWeaponAsset(`WEAPON_REVOLVER_CATTLEMAN`)
end)
```

### lib.streamingRequest

```lua
lib.streamingRequest(request: function, hasLoaded: function, assetType: string, asset: string | number, timeout?: number, ...: any): string | number
```

Side: client

Parameters:
- `request` (function, required): native that starts the request, called as `request(asset, ...)`.
- `hasLoaded` (function, required): native that reports readiness, called as `hasLoaded(asset)`.
- `assetType` (string, required): label used in the timeout error message.
- `asset` (string | number, required): asset identifier.
- `timeout` (number, optional, default 30000 ms).
- `...` (any, optional): extra arguments forwarded to `request`.

Returns: `asset` once `hasLoaded` is true; errors on timeout.

Generic loader behind every `lib.request*` helper; use it for asset types without a dedicated helper.

```lua
lib.streamingRequest(RequestIpl, IsIplActive, 'ipl', 'my_ipl')
```

### lib.playAnim

```lua
lib.playAnim(ped: number, animDictionary: string, animationName: string, blendInSpeed?: number, blendOutSpeed?: number, duration?: integer, animFlags?: number, startPhase?: number, phaseControlled?: boolean, controlFlags?: integer, overrideCloneUpdate?: boolean)
```

Side: client

Parameters:
- `ped` (number, required): ped handle.
- `animDictionary` (string, required): loaded with `lib.requestAnimDict` (yields, errors if the dictionary does not exist).
- `animationName` (string, required): clip name.
- `blendInSpeed` (number, optional, default 8.0).
- `blendOutSpeed` (number, optional, default -8.0).
- `duration` (integer, optional, default -1).
- `animFlags` (number, optional, default 0): bit flags: 1 LOOPING, 2 HOLD_LAST_FRAME, 4 REPOSITION_WHEN_FINISHED, 8 NOT_INTERRUPTABLE, 16 UPPERBODY, 32 SECONDARY, 64 REORIENT_WHEN_FINISHED, 128 ABORT_ON_PED_MOVEMENT, 256 ADDITIVE, 512 TURN_OFF_COLLISION, 1024 OVERRIDE_PHYSICS, 2048 IGNORE_GRAVITY, 4096 EXTRACT_INITIAL_OFFSET, 8192 EXIT_AFTER_INTERRUPTED, 16384 TAG_SYNC_IN, 32768 TAG_SYNC_OUT, 65536 TAG_SYNC_CONTINUOUS, 131072 FORCE_START, 262144 USE_KINEMATIC_PHYSICS, 524288 USE_MOVER_EXTRACTION, 1048576 HIDE_WEAPON, 2097152 ENDS_IN_DEAD_POSE, 4194304 ACTIVATE_RAGDOLL_ON_COLLISION, 8388608 DONT_EXIT_ON_DEATH, 16777216 ABORT_ON_WEAPON_DAMAGE, 33554432 DISABLE_FORCED_PHYSICS_UPDATE, 67108864 PROCESS_ATTACHMENTS_ON_START, 134217728 EXPAND_PED_CAPSULE_FROM_SKELETON, 268435456 USE_ALTERNATIVE_FP_ANIM, 536870912 BLENDOUT_WRT_LAST_FRAME, 1073741824 USE_FULL_BLENDING.
- `startPhase` (number, optional, default 0.0).
- `phaseControlled` (boolean, optional, default false).
- `controlFlags` (integer, optional, default 0): 1 DISABLE_LEG_IK, 2 DISABLE_ARM_IK, 4 DISABLE_HEAD_IK, 8 DISABLE_TORSO_IK, 16 DISABLE_TORSO_REACT_IK, 32 USE_LEG_ALLOW_TAGS, 64 USE_LEG_BLOCK_TAGS, 128 USE_ARM_ALLOW_TAGS, 256 USE_ARM_BLOCK_TAGS, 512 PROCESS_WEAPON_HAND_GRIP, 1024 USE_FP_ARM_LEFT, 2048 USE_FP_ARM_RIGHT, 4096 DISABLE_TORSO_VEHICLE_IK, 8192 LINKED_FACIAL.
- `overrideCloneUpdate` (boolean, optional, default false).

Returns: nil.

Requests the dictionary, calls `TaskPlayAnim` and immediately `RemoveAnimDict`. Call from a thread because the request yields.

```lua
CreateThread(function()
    lib.playAnim(cache.ped, 'amb_wander@code_human_wander@male_a', 'idle', 8.0, -8.0, -1, 1)
end)
```

### lib.addKeybind

```lua
lib.addKeybind(data: KeybindProps): CKeybind
```

Side: client

Parameters:
- `data` (table, required): keybind definition. The same table is returned with the metatable and hash attached, so any extra field you add is kept.
  - `name` (string, required): command suffix; `'+name'` and `'-name'` commands are registered and the key mapping is keyed on `'+name'`. Command names are server-global, so prefix with your resource name.
  - `description` (string, required): label shown in the player's key settings.
  - `defaultKey` (string, optional, default `''`): key name for `RegisterKeyMapping`, for example `'E'`, `'TAB'`, `'F5'`.
  - `defaultMapper` (string, optional, default `'keyboard'`): input mapper id (`keyboard`, `mouse_button`, `pad_digitalbutton`, ...).
  - `secondaryKey` (string, optional): registers a second mapping `'~!+name'` for the same command.
  - `secondaryMapper` (string, optional, default = `defaultMapper`): mapper for the secondary key.
  - `disabled` (boolean, optional, default false): when true, presses and releases are ignored.
  - `allowInPauseMenu` (boolean, optional, default false): when false, presses and releases are ignored while `IsPauseMenuActive()` is true.
  - `onPressed` (function(self), optional): called as `data:onPressed()` on key down.
  - `onReleased` (function(self), optional): called as `data:onReleased()` on key up.
  - any other string key (any, optional): stored on the object untouched.

Returns: CKeybind, the same table with fields `hash` (number, `joaat('+name') | 0x80000000`), `name`, `description`, `defaultKey`, `defaultMapper`, `disabled`, `isPressed` (boolean, true while held), `currentKey` (string; on RedM always `defaultKey`), and methods `getCurrentKey()`, `isControlPressed()`, `disable(toggle)`.

Registers a rebindable key mapping and its press/release commands. Presses are dropped while disabled or while the pause menu is open unless `allowInPauseMenu` is true. 500 ms after registration the `/+name` and `/-name` chat suggestions are removed. Because the file is loaded into the consumer resource, callbacks are plain functions. There is no unregister; use `:disable(true)`. On RedM `getCurrentKey()` cannot read the player's rebinding (no `GET_CONTROL_INSTRUCTIONAL_BUTTON`) and returns `defaultKey`.

```lua
local bind = lib.addKeybind({
    name = GetCurrentResourceName() .. '_interact',
    description = 'Interact',
    defaultKey = 'E',
    defaultMapper = 'keyboard',
    onPressed = function(self)
        print('pressed', self.name, self.isPressed)
    end,
    onReleased = function(self) print('released') end,
})

bind:disable(true)  -- ignore input for a while
bind:disable(false)
```

### CKeybind methods

```lua
keybind:getCurrentKey(): string
keybind:isControlPressed(): boolean
keybind:disable(toggle: boolean)
```

Side: client

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `getCurrentKey()` | none | string: on RedM the `defaultKey` passed at creation (or `''`); on FiveM the instructional button text with its first two characters stripped | Reads the key currently bound. Also available as the field `keybind.currentKey` through `__index`. |
| `isControlPressed()` | none | boolean: true between `onPressed` and `onReleased` | Returns the `isPressed` flag (also readable directly as `keybind.isPressed`). |
| `disable(toggle)` | `toggle` (boolean, required): true ignores further presses/releases; false re-enables | nil | Sets `keybind.disabled` and resets `isPressed` to false. |

```lua
local key = bind.currentKey  -- same as bind:getCurrentKey()
if bind:isControlPressed() then print('held') end
bind:disable(true)
```

### lib.rawKeys.listen

```lua
lib.rawKeys.listen(key: string | number, callback: fun(pressed: boolean)): number?
```

Side: client

Parameters:
- `key` (string | number, required): key name (case-insensitive: A-Z, 0-9, F1-F12, TAB, ENTER/RETURN, ESC/ESCAPE, SPACE, BACKSPACE/BACK, SHIFT, CTRL/CONTROL, ALT, LEFT, UP, RIGHT, DOWN, DELETE, INSERT, HOME, END, PAGEUP, PAGEDOWN, CAPSLOCK, NUMPAD0-9) or a Windows virtual-key code from that same set.
- `callback` (function(pressed: boolean), required): called with true on key down and false on key up. Errors are caught and logged through `lib.print.error`.

Returns: listener id (number), or nil when the key is unknown (a warning is printed).

Silent raw key watch via `RegisterRawKeymap` named `'<yourResource>:rawkey:<key>'`; it does not appear in the player's key settings and cannot be rebound. One keymap per key per resource is registered; several listeners can share it and are dispatched newest first. Use `lib.addKeybind` for a named, rebindable action. In a consumer `lib.rawKeys` and `w.rawKeys` are the same table: the import file returns `w.rawKeys` when the module layer already defined it (`modules/raw-keys`), otherwise it defines `listen`, `removeListener` and `getVK` itself. `w.rawKeys.bind` does not exist for consumers.

```lua
local id = lib.rawKeys.listen('F8', function(pressed)
    if pressed then print('F8 down') end
end)
-- later
lib.rawKeys.removeListener(id)
```

### lib.rawKeys.removeListener, lib.rawKeys.getVK

```lua
lib.rawKeys.removeListener(id: number): boolean
lib.rawKeys.getVK(key: string | number): number?
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `removeListener(id)` | `id` (number, required): id returned by `listen` | true when a listener was removed, false otherwise (including nil id) | Removes one listener; the underlying raw keymap stays registered. |
| `getVK(key)` | `key` (string | number, required): key name or code | the Windows virtual-key code, or the number unchanged, or nil for unknown names | Name to VK lookup using the same table as `listen`. |

```lua
lib.rawKeys.removeListener(id)
print(lib.rawKeys.getVK('TAB')) -- 9
```

### lib.disableControls

```lua
lib.disableControls()
lib.disableControls:Add(...: number | number[])
lib.disableControls:Remove(...: number | number[])
lib.disableControls:Clear(...: number | number[])
```

Side: client

Parameters:
- `lib.disableControls()`: none.
- `Add`, `Remove`, `Clear`: `...` (number | table, required): control ids as varargs, or a single array table of ids.

Returns: nil (all four).

`lib.disableControls` is a callable table. Calling it runs `DisableControlAction(0, control, true)` for every control id currently stored; call it every frame from your own loop. Control ids are stored with a reference count (readable as `lib.disableControls[control]`), so two `Add` calls for the same control need two `Remove` calls. On RedM pass RDR3 control hashes.

| Method | Description |
|---|---|
| `Add(...)` | Increments the reference count of each control (creates it at 1). |
| `Remove(...)` | Decrements the count; the control is dropped when it reaches zero. |
| `Clear(...)` | Removes the controls regardless of their reference count. |

```lua
lib.disableControls:Add(0x8FFC75D6, 0xE30CD707) -- add controls
CreateThread(function()
    while blocking do
        lib.disableControls()
        Wait(0)
    end
    lib.disableControls:Remove(0x8FFC75D6, 0xE30CD707)
end)

lib.disableControls:Add({ 0x8FFC75D6, 0xE30CD707 })
lib.disableControls:Clear(0x8FFC75D6, 0xE30CD707)
```

### lib.points.new

```lua
lib.points.new(data: PointProperties): CPoint
lib.points.new(coords: vector3, distance: number, data?: table): CPoint  -- legacy form
```

Side: client

Parameters:
- `data` (table, required): point definition (first form); the same table becomes the point. In the legacy form `coords` and `distance` are positional and every field of the third table is copied onto the point.
  - `coords` (vector3 | vector4 | {x,y,z} | {1,2,3}, required): converted to vector3; anything else errors.
  - `distance` (number, required): activation radius; also stored as `point.radius`.
  - `onEnter` (function(self), optional): once when the player comes within `distance`.
  - `onExit` (function(self), optional): once when the player leaves.
  - `nearby` (function(self), optional): every frame while within `distance`.
  - any other string key (any, optional): kept on the point (w_inventory stores `inv`, `invId`, `instance`, `model`, ...).

Returns: CPoint, the same table with `id` (number), `coords`, `distance`, `radius`, `remove(self)`, and the runtime fields `currentDistance` (number while inside, nil after leaving), `inside` (true while inside, nil after leaving) and `isClosest` (true for the nearest point).

Registers a radius point in the resource's grid. A 300 ms thread checks nearby points; `nearby` callbacks run through a per-frame interval while at least one point is inside. Keep your own reference and call `point:remove()` to unregister.

```lua
local point = lib.points.new({
    coords = vec3(-300.0, 800.0, 118.0),
    distance = 2.5,
    onEnter = function(self) print('entered', self.id) end,
    onExit = function(self) print('left') end,
    nearby = function(self)
        if self.currentDistance < 1.2 and IsControlJustReleased(0, 0xCEFD9220) then
            print('use')
        end
    end,
})
-- later
point:remove()
```

### CPoint:remove

```lua
point:remove()
```

Side: client

Parameters: none.

Returns: nil.

Removes the point from the grid and the registry and clears it as closest point. Does not fire `onExit`.

```lua
point:remove()
```

### lib.points.getAllPoints, getNearbyPoints, getClosestPoint

```lua
lib.points.getAllPoints(): table<number, CPoint>
lib.points.getNearbyPoints(): CPoint[]
lib.points.getClosestPoint(): CPoint?
```

Side: client

Parameters: none.

| Function | Returns | Description |
|---|---|---|
| `getAllPoints()` | the live registry keyed by id (holes after removals) | Every point created by this resource. |
| `getNearbyPoints()` | array of points currently inside their distance (rebuilt every 300 ms) | Live array; do not keep it across ticks. |
| `getClosestPoint()` | the inside point with the smallest `currentDistance`, or nil | w_inventory calls it on key press and reads `closest.currentDistance` and its custom fields. `lib.points.closest` is a deprecated alias. |

```lua
for id, p in pairs(lib.points.getAllPoints()) do print(id, p.coords) end
print(#lib.points.getNearbyPoints())
local closest = lib.points.getClosestPoint()
if closest and closest.currentDistance < 1.2 then print(closest.inv) end
```

### lib.zones.poly

```lua
lib.zones.poly(data: PolyZone): CZone
```

Side: shared

Parameters:
- `data` (table, required): zone definition; the same table becomes the zone object.
  - `points` (vector3[] | {x,y,z}[] | vector4[], required): polygon vertices in order (3 or more). If they are not on one z plane, the most common z (or the average of the equally most common ones) is applied to every vertex.
  - `thickness` (number, optional, default 4): vertical extent of the zone.
  - `debug` (boolean, optional, default false): client only; draws the polygon every frame.
  - `debugColour` ({r,g,b,a}, optional, default 255,42,24,100).
  - `onEnter` (function(self), optional): client only, once on entry.
  - `onExit` (function(self), optional): client only, once on exit.
  - `inside` (function(self), optional): client only, every frame while inside.
  - `contains` (function(self, coords, updateDistance), optional): replaces the default polygon test.
  - any other string key (any, optional): kept on the zone (for example `name`).

Returns: CZone with `id`, `__type` `'poly'`, `polygon`, `coords` (centroid), `radius` (largest vertex distance from the centroid), `thickness`, `distance` (client), and the methods `contains`, `remove`, `setDebug` (client).

Creates a polygon zone. On the server only `contains()` is useful. The `/zone` creator's `'function'` output uses this exact shape. Polygons that cannot be triangulated print a warning when debug is enabled.

```lua
local zone = lib.zones.poly({
    name = 'valentine_center',
    points = { vec3(-300.0, 800.0, 118.0), vec3(-280.0, 800.0, 118.0), vec3(-280.0, 780.0, 118.0), vec3(-300.0, 780.0, 118.0) },
    thickness = 8.0,
    onEnter = function(self) print('entered', self.name) end,
    onExit = function(self) print('left', self.name) end,
    inside = function(self) DrawMarker(0x07DCE236, self.coords.x, self.coords.y, self.coords.z, 0,0,0, 0,0,0, 1.0,1.0,1.0, 255,255,255,100, false,false,2,false,nil,nil,false) end,
})
```

### lib.zones.box

```lua
lib.zones.box(data: BoxZone): CZone
```

Side: shared

Parameters:
- `data` (table, required): zone definition.
  - `coords` (vector3 | {x,y,z}, required): center.
  - `size` (vector3 | {x,y,z}, optional, default 4 x 4 x 4): full width (x), length (y), height (z). Stored halved on `zone.size`; `zone.width`/`zone.length` hold the full values and `zone.thickness` = height.
  - `rotation` (number | vector3 | vector4 | matrix, optional, default 0): heading in degrees around z, converted with `quat(rotation, vec3(0,0,1))`.
  - `debug`, `debugColour`, `onEnter`, `onExit`, `inside`, `contains`: as for `poly`.
  - any other string key (any, optional): kept.

Returns: CZone with `__type` `'box'`, `polygon` (4 rotated corners), `coords`, `size` (half), `width`, `length`, `thickness`, `rotation` (quat).

Axis box built as a rotated 4-point polygon; `contains()` is the polygon test.

```lua
local zone = lib.zones.box({
    coords = vec3(-300.0, 800.0, 118.0),
    size = vec3(6.0, 4.0, 4.0),
    rotation = 45.0,
    onEnter = function() print('in box') end,
})
```

### lib.zones.sphere

```lua
lib.zones.sphere(data: SphereZone): CZone
```

Side: shared

Parameters:
- `data` (table, required): zone definition.
  - `coords` (vector3 | {x,y,z}, required): center.
  - `radius` (number, optional, default 2): coerced to float.
  - `debug`, `debugColour`, `onEnter`, `onExit`, `inside`: as for `poly` (debug draws marker type 28). A custom `contains` field is overwritten.
  - any other string key (any, optional): kept.

Returns: CZone with `__type` `'sphere'`, `coords`, `radius`; `contains()` is distance < radius.

Sphere zone; the cheapest shape.

```lua
local safe = lib.zones.sphere({ coords = vec3(-300.0, 800.0, 118.0), radius = 25.0, onEnter = function() print('safe zone') end })
```

### CZone:contains

```lua
zone:contains(coords: vector3, updateDistance?: boolean): boolean
```

Side: shared

Parameters:
- `coords` (vector3, required): position to test (the annotation marks it optional but the code always uses it).
- `updateDistance` (boolean, optional): when true, also refreshes `zone.distance = #(zone.coords - coords)`.

Returns: boolean.

Polygon test for poly/box (glm polygon contains with a vertical tolerance of `thickness / 4`), distance test for spheres. Works on the server too, which is how server-side scripts check a position against a zone.

```lua
if zone:contains(GetEntityCoords(cache.ped)) then print('inside') end
```

### CZone:remove

```lua
zone:remove()
```

Side: shared

Parameters: none.

Returns: nil.

Unregisters the zone from the registry and the grid and clears any pending enter/exit for it. `onExit` is not fired.

```lua
zone:remove()
```

### CZone:setDebug

```lua
zone:setDebug(enable?: boolean, colour?: { r, g, b, a })
```

Side: client

Parameters:
- `enable` (boolean, optional): true to draw the zone every frame, false to stop.
- `colour` (table, optional): `{ r, g, b, a }` integers; each missing component falls back to the previous colour, then to 255, 42, 24, 100.

Returns: nil.

Toggles debug drawing (triangulated fill plus edges for poly/box, a marker for spheres). Enabling when already enabled is a no-op.

```lua
zone:setDebug(true, { r = 0, g = 255, b = 0, a = 80 })
```

### lib.zones.getAllZones, getCurrentZones, getNearbyZones

```lua
lib.zones.getAllZones(): table<number, CZone>
lib.zones.getCurrentZones(): table<number, CZone>
lib.zones.getNearbyZones(): CZone[]
```

Side: `getAllZones` and `getNearbyZones` shared; `getCurrentZones` client

Parameters: none.

| Function | Returns | Description |
|---|---|---|
| `getAllZones()` | registry keyed by id | All zones created by this resource (same table as the global `Zones` the module defines). |
| `getCurrentZones()` | zones the player is inside that have an `inside` handler or debug enabled, keyed by id (false on the server) | Only zones with `inside` or `debug` appear here; a zone with just `onEnter`/`onExit` is tracked via `zone.insideZone` instead. |
| `getNearbyZones()` | array of zones in the player's grid neighbourhood (client; refreshed every 300 ms). Empty on the server. | Candidate zones from the grid, not necessarily containing the player. |

```lua
for id, z in pairs(lib.zones.getAllZones()) do print(id, z.__type) end
for _, z in pairs(lib.zones.getCurrentZones()) do print(z.name) end
print(#lib.zones.getNearbyZones())
```

### lib.raycast.fromCoords

```lua
lib.raycast.fromCoords(coords: vector3, destination: vector3, flags?: number, ignore?: number): hit: boolean, entityHit: number, endCoords: vector3, surfaceNormal: vector3, materialHash: number
```

Side: client

Parameters:
- `coords` (vector3, required): start.
- `destination` (vector3, required): end.
- `flags` (number, optional, default 511, INCLUDE_ALL): bits 1 MOVER, 2 VEHICLE, 4 PED, 8 RAGDOLL, 16 OBJECT, 32 PICKUP, 64 GLASS, 128 RIVER, 256 FOLIAGE.
- `ignore` (number, optional, default 4, NO_COLLISION): 1 GLASS, 2 SEE_THROUGH, 3 both, 7 all.

Returns: `hit, entityHit, endCoords, surfaceNormal, materialHash`.

`StartShapeTestLosProbe` ignoring `cache.ped`, then yields (`Wait(0)`) until the result is ready. Call from a thread.

```lua
local hit, entity, endCoords = lib.raycast.fromCoords(origin, vec3(origin.x, origin.y, origin.z - 100.0), 511, 4)
if hit then print('ground at', endCoords.z) end
```

### lib.raycast.fromCamera

```lua
lib.raycast.fromCamera(flags?: number, ignore?: number, distance?: number): hit, entityHit, endCoords, surfaceNormal, materialHash
```

Side: client

Parameters:
- `flags` (number, optional, default 511).
- `ignore` (number, optional, default 4).
- `distance` (number, optional, default 10): ray length from the camera.

Returns: same as `fromCoords`.

Casts from `GetFinalRenderedCamCoord` along the final rendered camera forward vector (`GetFinalRenderedCamRot(2)`). `lib.raycast.cam` is a deprecated alias.

```lua
local hit, entity, coords = lib.raycast.fromCamera(511, 4, 20.0)
```

### lib.glow (the game's glitter as shapes)

```lua
local id = lib.glow.wall(points, opts)        -- a wall along a border (closed when 3+ points)
local id = lib.glow.line(points, opts)        -- a path
local id = lib.glow.circle(center, radius, opts)
local id = lib.glow.point(at, opts)
local id = lib.glow.arrow(at, opts)           -- down at `at`; opts.heading = a flat arrow on the ground pointing there
lib.glow.remove(id) · lib.glow.clear() · lib.glow.count() · lib.glow.looks
lib.glow.frame(key, kind, ...)                -- every frame, like DrawMarker (the shape goes 350 ms after the last call)
```

Side: client (w_lib 4.1.0). The owner chose these five looks of the game's own particle glitter to replace `DrawMarker` (2026-10-23):

| look | effect (dictionary/name) | job | default of |
|---|---|---|---|
| 1 | `eagle_eye/eagle_eye_trail` | paths, routes | `line` |
| 2 | `eagle_eye/eagle_eye_clue` | a point to use (a board, a door) | `point` |
| 3 | `eagle_eye/eagle_eye_entity` | arrows | `arrow` |
| 4 | `eagle_eye/eagle_eye_lootable_plant` | circles on the ground | `circle` |
| 5 | `scr_net_fire_smoke/scr_mp_item_pickup_highlight` | walls, borders | `wall` |

A shape is a set of spots, one looped particle each. Every 200 ms the spots nearest the camera within `range` burn, at most
`w_lib:glowBudget` (convar, default 300 since 4.1.1) per resource; the rest are put out, so a long border costs no more than a short one.
Ground shapes (wall, line, circle) sit on the ground once it is loaded. A look the game refuses falls back to a small
`DrawMarker` ring. Particles are local: only this player sees them. They stop when the resource stops.

Options (all optional): `look` (1-5), `color` ({r,g,b} 0-255, a tint; not every effect takes it), `alpha` (0-1), `scale`,
`lift` (metres above the point or the ground), `range` (metres, default `w_lib:glowRange` = 60), `ground` (true/false),
`id` (redraw that shape in place: its particles move instead of starting again), `solid` (4.1.2: `true` or
`{ color, alpha, height, size }`: beside the glitter, every frame while the shape is in range, a see-through wall along a
wall / line or a flat ring under a point / circle / arrow, seen from any distance -- the glitter is not seen from high up,
so the top-down editors pass it). Per shape: `wall` `closed`, `step` (0.5),
`rows` ({0.0, 0.8, 1.6}: heights of the wall's rows; look 5 is drawn 1.5 times its size since 4.1.1); `line` `step` (2.0), `closed`; `circle` `step` (0.8); `arrow` `size` (1.2),
`heading`, `step`.

```lua
-- a farm's border as a wall while the player is near it
local border = lib.glow.wall(farm.poly, { range = 80.0 })
-- a spot to use, drawn every frame like a marker
CreateThread(function()
    while near do lib.glow.frame('shop', 'circle', shop.coords, 0.8) Wait(0) end
end)
```

`/glow` (w_lib itself) shows every shape in front of the player for a minute; `/glow wall 5` one shape in one look; `/glow off`.
`lib.marker`, the placer (`w.placer`) and the essentials teleports draw with `lib.glow` since 4.1.0.

### lib.marker.new

```lua
lib.marker.new(options: MarkerProps): Marker
```

Side: client

Parameters:
- `options` (table, required): cloned into the marker object (`table.clone`), so later edits to your options table are not seen.
  - `type` (string | number, optional, default 0): a name from the GTA-derived enum (UpsideDownCone, VerticalCylinder, ThickChevronUp, ThinChevronUp, CheckeredFlagRect, CheckeredFlagCircle, VerticleCircle, PlaneModel, LostMCTransparent, LostMC, Number0..Number9, ChevronUpx1/x2/x3, HorizontalCircleFat, ReplayIcon, HorizontalCircleSkinny, HorizontalCircleSkinny_Arrow, HorizontalSplitArrowCircle, DebugSphere, DollarSign, HorizontalBars, WolfHead, QuestionMark, PlaneSymbol, HelicopterSymbol, BoatSymbol, CarSymbol, MotorcycleSymbol, BikeSymbol, TruckSymbol, ParachuteSymbol, Unknown41, SawbladeSymbol, Unknown43) or a raw number; an unknown name falls back to 0. RedM consumers pass an RDR3 marker hash such as `0x07DCE236`.
  - `coords` ({x,y,z} or vector3, required): position; you may mutate `marker.coords` later.
  - `width` (number, optional, default 2.0): x and y scale.
  - `height` (number, optional, default 1.0): z scale.
  - `color` ({r,g,b,a}, optional, default {255,100,0,100}).
  - `rotation` ({x,y,z}, optional, default 0,0,0).
  - `direction` ({x,y,z}, optional, default 0,0,0).
  - `bobUpAndDown` (boolean, optional, default false).
  - `faceCamera` (boolean, optional, default false).
  - `rotate` (boolean, optional, default false).
  - `textureDict` (string, optional).
  - `textureName` (string, optional).
  - `invert` (boolean, optional, default false).

Returns: Marker table with the resolved fields and a `:draw()` method.

Builds a reusable `DrawMarker` argument set. Nothing is drawn until you call `marker:draw()` every frame. `width`/`height` are coerced to floats.

```lua
local marker = lib.marker.new({
    type = 0x07DCE236, coords = vec3(-300.0, 800.0, 118.0),
    width = 0.35, height = 0.2, color = { r = 20, g = 190, b = 110, a = 190 },
})
CreateThread(function()
    while showMarker do marker:draw() Wait(0) end
end)
```

### Marker:draw

```lua
marker:draw()
```

Side: client

Parameters: none.

Returns: nil.

Calls `DrawMarker` with the stored fields (scale = width, width, height; the fixed argument after `faceCamera` is 2). Must be called each frame.

```lua
marker:draw()
```

### lib.dui:new

```lua
lib.dui:new(data: DuiProperties): Dui
```

Side: client

Parameters:
- `data` (table, required): DUI definition.
  - `url` (string, required): page to load in the DUI browser.
  - `width` (number, required): browser width in pixels.
  - `height` (number, required): browser height in pixels.
  - `debug` (boolean, optional, default false): print create/remove/setUrl/sendMessage traces.

Returns: Dui object with fields `url`, `duiObject`, `duiHandle`, `runtimeTxd`, `txdObject`, `dictName` (`'w_lib_dui_dict_<resource>_<gametimer>_<n>'`), `txtName` (`'w_lib_dui_txt_...'`) and the methods below.

Creates a DUI browser plus a runtime texture dictionary and texture so the page can be drawn with sprite natives using `dictName` / `txtName`. All DUIs created by the consumer resource are removed automatically on `onResourceStop`.

```lua
local dui = lib.dui:new({ url = 'https://example.com', width = 1280, height = 720 })
CreateThread(function()
    while dui.duiObject do
        DrawSprite(dui.dictName, dui.txtName, 0.5, 0.5, 0.5, 0.5, 0.0, 255, 255, 255, 255)
        Wait(0)
    end
end)
```

### Dui methods

```lua
dui:remove()
dui:setUrl(url: string)
dui:sendMessage(message: table)
dui:sendMouseMove(x: number, y: number)
dui:sendMouseDown(button: 'left' | 'middle' | 'right')
dui:sendMouseUp(button: 'left' | 'middle' | 'right')
dui:sendMouseWheel(deltaX: number, deltaY: number)
```

Side: client

All return nil.

| Method | Parameters | Description |
|---|---|---|
| `remove()` | none | Sets the URL to `about:blank`, destroys the DUI and forgets it. The runtime txd is not released explicitly and `duiObject` is not cleared on the object. |
| `setUrl(url)` | `url` (string, required): new page URL | Navigates the DUI and updates `dui.url`. |
| `sendMessage(message)` | `message` (table, required): JSON-encodable table delivered to the page as a window message | `json.encode(message)` then `SendDuiMessage`. |
| `sendMouseMove(x, y)` | `x`, `y` (number, required): pixel position inside the DUI | Forwards a mouse move to the page. |
| `sendMouseDown(button)` | `button` (string, required): `'left'`, `'middle'` or `'right'` | Forwards a mouse button press. |
| `sendMouseUp(button)` | `button` (string, required): `'left'`, `'middle'` or `'right'` | Forwards a mouse button release. |
| `sendMouseWheel(deltaX, deltaY)` | `deltaX`, `deltaY` (number, required): scroll deltas | Forwards a wheel event (the native takes `deltaY` first; the wrapper reorders for you). |

```lua
dui:setUrl('https://example.com/page2')
dui:sendMessage({ action = 'setVolume', value = 0.5 })
dui:sendMouseMove(100, 50)
dui:sendMouseDown('left')
dui:sendMouseUp('left')
dui:sendMouseWheel(0, -120)
dui:remove()
```

### lib.scaleform:new

```lua
lib.scaleform:new(details: string | detailsTable): Scaleform
```

Side: client

Parameters:
- `details` (string | table, required): movie name, or a table.
  - `name` (string, required): scaleform movie name; loaded with `lib.requestScaleformMovie` (yields, 1000 ms default timeout).
  - `fullScreen` (boolean, optional, default false): draw with `DrawScaleformMovieFullscreen`.
  - `x`, `y`, `width`, `height` (number, optional, default 0): used by `DrawScaleformMovie` when not full screen.
  - `renderTarget` ({ name: string, model: string | number }, optional): registers/links a named render target immediately via `setRenderTarget`.

Returns: Scaleform object with `sfHandle`, `fullScreen`, `x`, `y`, `width`, `height`, `target`, `targetName`.

Loads a scaleform movie and keeps its handle. Call from a thread. Because `x`/`y`/`width`/`height` default to 0, a non-fullscreen movie drawn without `setProperties` has zero size.

```lua
local sf = lib.scaleform:new({ name = 'mp_big_message_freemode', fullScreen = true })
sf:callMethod('SHOW_SHARD_WASTED_MP_MESSAGE', { 'Title', 'Subtitle' })
sf:startDrawing()
SetTimeout(5000, function() sf:stopDrawing() sf:dispose() end)
```

### Scaleform:callMethod

```lua
scaleform:callMethod(name: string, args?: (number | string | boolean)[], returnValue?: 'boolean' | 'integer' | 'string'): any
```

Side: client

Parameters:
- `name` (string, required): movie method name.
- `args` (table, optional): array of strings (added as player-name strings), integers, floats or booleans; other types raise an error.
- `returnValue` (string, optional): when given, the method is ended with `EndScaleformMovieMethodReturnValue` and the value is awaited (1000 ms, error on timeout) and returned as integer or boolean; any other string reads it as a string.

Returns: nil, or the awaited return value.

Begin/End scaleform method with typed argument conversion. Errors if the handle was disposed.

```lua
sf:callMethod('SET_DATA_SLOT', { 0, 'label', 1.5, true })
local ok = sf:callMethod('IS_READY', nil, 'boolean')
```

### Scaleform:setFullScreen, setProperties, setRenderTarget

```lua
scaleform:setFullScreen(isFullscreen: boolean)
scaleform:setProperties(x: number, y: number, width: number, height: number)
scaleform:setRenderTarget(name: string, model: string | number)
```

Side: client

All return nil.

| Method | Parameters | Description |
|---|---|---|
| `setFullScreen(isFullscreen)` | `isFullscreen` (boolean, required) | Sets the `fullScreen` flag used by `draw()`. |
| `setProperties(x, y, width, height)` | `x` (number, required): screen x (0-1); `y` (number, required): screen y; `width`, `height` (number, required) | Sets the non-fullscreen rectangle. Ignored (info log) while `fullScreen` is true. |
| `setRenderTarget(name, model)` | `name` (string, required): named render target; `model` (string | number, required): model to link, strings are hashed | Releases any previous target, then, only if the name is not already registered, registers and links the named render target and stores its render id so `draw()` renders into it. If the name was already registered (by anyone) nothing is stored. |

```lua
sf:setFullScreen(true)
sf:setProperties(0.5, 0.5, 0.4, 0.3)
sf:setRenderTarget('tvscreen', 'prop_tv_flat_01')
```

### Scaleform:draw, startDrawing, stopDrawing, isDrawing, dispose

```lua
scaleform:draw()
scaleform:startDrawing()
scaleform:stopDrawing()
scaleform:isDrawing(): boolean
scaleform:dispose()
```

Side: client

Parameters: none.

| Method | Returns | Description |
|---|---|---|
| `draw()` | nil | Draws one frame (into the render target when set): full screen or with the stored rectangle. |
| `startDrawing()` | nil | Starts an internal per-frame draw thread (no-op if already drawing). |
| `stopDrawing()` | nil | Stops the internal draw thread. |
| `isDrawing()` | boolean | Whether `startDrawing` is active. |
| `dispose()` | nil | Marks the movie as no longer needed, releases the render target, clears the handle and stops drawing. |

```lua
CreateThread(function() while show do sf:draw() Wait(0) end end)
sf:startDrawing()
if sf:isDrawing() then sf:stopDrawing() end
sf:dispose()
```

### lib.getVehicleProperties

```lua
lib.getVehicleProperties(vehicle: number): VehicleProperties?
```

Side: client (FiveM only)

Parameters:
- `vehicle` (number, required): vehicle handle; nil is returned when it does not exist.

Returns: VehicleProperties table: `model`, `plate`, `plateIndex`, `lockState`, `bodyHealth`, `engineHealth`, `tankHealth`, `fuelLevel`, `oilLevel`, `dirtLevel` (rounded), `paintType1/2`, `color1`/`color2` (index or {r,g,b}), `pearlescentColor`, `interiorColor`, `dashboardColor`, `wheelColor`, `wheelWidth`, `wheelSize`, `wheels`, `windowTint`, `xenonColor`, `neonEnabled` (boolean[4]), `neonColor` {r,g,b}, `extras` (id -> 0 on / 1 off), `tyreSmokeColor`, `mod*` fields 0-49, `modRoofLivery`, `livery`, `windows`/`doors` (broken indices), `tyres` (index -> 1 burst / 2 on rim), `bulletProofTyres`, `driftTyres` (build >= 2372).

FiveM only: `resource/vehicleProperties/client.lua` returns early when `cache.game == 'redm'`, so this function does not exist on a RedM client. Reaches a consumer through the export fallback (`exports.w_lib:getVehicleProperties`). Also rolls up all windows while reading.

```lua
local props = lib.getVehicleProperties(cache.vehicle)
TriggerServerEvent('garage:save', props)
```

### lib.setVehicleProperties (client)

```lua
lib.setVehicleProperties(vehicle: number, props: VehicleProperties, fixVehicle?: boolean): boolean
```

Side: client (FiveM only)

Parameters:
- `vehicle` (number, required): vehicle handle; errors if it does not exist.
- `props` (table, required): any subset of the fields returned by `getVehicleProperties`; only present fields are applied. `lockState` is applied only when the convar `w_lib:setLockState` is true.
- `fixVehicle` (boolean, optional): call `SetVehicleFixed` afterwards (needed when toggling extras).

Returns: boolean, true if the vehicle is not networked or this client owns it.

FiveM only (same RedM early return). Applies mods, colours, damage and extras. The library also listens to the statebag key `'w_lib:setVehicleProperties'` and applies it on the owning client, which is how the server variant works.

```lua
lib.setVehicleProperties(vehicle, { plate = 'WRAITH01', color1 = 12 }, true)
```

### lib.setVehicleProperties (server)

```lua
lib.setVehicleProperties(vehicle: number, props: VehicleProperties)
```

Side: server

Parameters:
- `vehicle` (number, required): server entity handle.
- `props` (table, required): VehicleProperties subset.

Returns: nil.

Writes `Entity(vehicle).state 'w_lib:setVehicleProperties'` (replicated). The owning client applies it and clears the key (retrying up to 10 times, 400 ms apart). Because the RedM client file is disabled, on RedM the value is written but nothing applies it. Also reachable as `exports.w_lib:setVehicleProperties` from other languages.

```lua
local veh = CreateVehicle(model, x, y, z, heading, true, true)
lib.setVehicleProperties(veh, { plate = 'WRAITH01' })
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:setVehicleProperties` | client | `netId` (number): vehicle network id, waits up to 100 frames for it to exist; `props` (table): VehicleProperties subset | Deprecated legacy path triggered with `TriggerClientEvent('w_lib:setVehicleProperties', playerId, netId, props)`; applies `props` on the receiving client via `lib.setVehicleProperties`. Not registered on RedM clients. Prefer the server `lib.setVehicleProperties` statebag route. |
| `w_lib:setStateBagValue` | client (internal) | key and value | Fired by the server for `:sets` so the target player's `LocalPlayer.state[key]` is updated. |
| `w_lib:saveZone` | server (internal) | generated zone data | Sent by the `/zone` creator on Enter; appends generated Lua to `w_lib/created_zones.lua`. Requires the `command` ace. |

```lua
TriggerClientEvent('w_lib:setVehicleProperties', src, NetworkGetNetworkIdFromEntity(veh), { plate = 'ABC' })
```

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:setLockState` | client | boolean, default false (`setr w_lib:setLockState true`) | Read once at load. When true, `lib.setVehicleProperties` applies `props.lockState` with `SetVehicleDoorsLocked`; otherwise `lockState` is ignored. FiveM only. |
| `sv_stateBagStrictMode` | server (Cfx convar, read by the client) | boolean, default false (`setr sv_stateBagStrictMode true`) | Read once (`GetConvarBool`) by `imports/gameEntity/shared.lua` on the client. When true, client `entity:setr()` calls are routed through the library's server callback and accepted only if a server `lib.hook` for that key allows them; when false the client writes replicated values directly. |

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `/zone <poly|box|sphere> [useLast]` | client | `zoneType` (string, required): `'poly'`, `'box'` or `'sphere'`; anything else notifies "Invalid zone type". `useLast` (string, optional): any value other than 0, `''`, false or nil duplicates the last box/sphere dimensions (heading, height, width, length) saved in this session; not allowed for poly. | Interactive zone creator, registered with `RegisterCommand` restricted = true, so the player needs the `command.zone` ace; the save event additionally checks the `command` ace. |

Controls as coded (GTA numeric control ids; only look and chat controls are translated to RDR3 hashes, so the RedM key layout is not guaranteed): W/S/A/D move Y/X, R/F move Z, scroll changes step, Shift+scroll height (poly/box) or radius (sphere), Ctrl+scroll width and Alt+scroll length (box), Q increases and E decreases heading (box), G cycles display mode, C toggles camera/grid movement, Space adds a poly point or recenters on the ped, Backspace edits the last poly point, X toggles controls, Enter saves, Esc cancels.

On save the current cursor position is appended as the last poly point, an input dialog asks for a name and a format (`'function'`, `'array'` or `'target'`; default `'array'`), the client sends the internal event `w_lib:saveZone` and the server appends generated Lua (a `lib.zones.poly/box/sphere` call, a plain table, or an ox_target call) to `w_lib/created_zones.lua`. Copy from that file into the consumer resource.

```lua
-- in game, as an admin with the command ace:
-- /zone box
-- ...adjust with the keys shown in the text UI, press Enter, name it, choose Format = Function
-- then read w_lib/created_zones.lua and paste the generated lib.zones.box({...}) into your client script
```

## Client modules under w.* (animation, blips, camera, entities, gizmo, lights, minigames, NUI, input, native prompts, raw keys, screen, player, me, debugger)

### How these modules reach the consumer resource

Everything under `w.*` is loaded by `@w_lib/init.lua` (put it first in `shared_scripts`) through the module layer. A module is loaded either by listing it in the manifest (`w_module { 'prompt', 'entity', 'player' }`) or lazily on first access: indexing `w.<module>` (or calling `w.require("<module>")`) reads `modules/<module>/shared.lua` and `modules/<module>/client.lua` (or `server.lua`) out of the library and executes them inside the consumer resource's own Lua context. Files prefixed `g_` (`g_client.lua`, `g_server.lua`) run only inside the library itself and are reached from the consumer resource through exports or events. `w` and `jo` are the same table, so `jo.<module>.<fn>` is identical to `w.<module>.<fn>`.

The loader accepts these module name aliases: `pl` -> `player`, `pedTexture` -> `ped-texture`, and `meCoords` / `mePlayerId` / `meServerId` -> `me`. Two lazy-load traps follow from the loader returning `rawget(w, <aliased name>)` after loading:

- The very first access to `w.meCoords`, `w.mePlayerId` or `w.meServerId` before the `me` module is loaded returns `w.me` (the ped handle) instead of the requested field.
- `w.dataview` is always `nil`, because the dataview file defines the global `DataView` rather than a `w` table.

List `'me'` and `'dataview'` in `w_module`, or call `w.require` first, to avoid both.

Consequences of the code running in the consumer resource's context:

1. Ordinary Lua functions can be passed as callbacks to `w.*` functions (`onMove`, `onPinBroken`, raw key listeners, `w.player.move`, and so on). The "event names only / plain data only" rule applies to the `exports.w_lib:*` surface, never to `w.*` module functions, with one exception: `w.pedTexture` (see below).
2. Every native prompt, blip or entity created through these modules belongs to the consumer resource and is cleaned up automatically when that resource stops (each module installs a `w.stopped` hook). Lights are drawn per frame by a thread inside the consumer resource, so they simply vanish when it stops.
3. Anything that calls `SendNUIMessage` runs against the consumer resource's own `ui_page`. The gizmo and the minigames send their drawing to the frame named `wui`, and `w.input.nui` to `w_input`, from inside the consumer resource. They therefore only work when the manifest declares `ui_page 'nui://w_lib/web/build/index.html'` (the unified w_lib web app) and the NUI callbacks they register (`gizmo:UpdateEntity`, `w_minigame:finished`, `w_minigame:lockpick:pinBroken`, `w_input:click`, `w_nui_is_hovering`) are answered by that page. A resource with its own `ui_page` cannot use `w.gizmo`, `w.minigame` or `w.input.nui` and must fall back to natives or to the `exports.w_lib` API. For placing things in the world, such a resource can use `w.placer` (see below), which draws only through the library's own frame.

`w.nui.load` is a permanent no-op (the multi-frame shell was removed), so `w.nui.isLoaded` always returns `false` and `w.nui.forceFocus` always prints "This nui is not loaded". Only `w.nui.resetFocus` and the hovering functions still do something.

**Prompt module rules.** `w.prompt.create(group, label, key, holdTime, page)` registers a native RDR3 UI prompt. `group` is any string of your choosing; `key` is a control name string (`"INPUT_CONTEXT_RT"`) or its hash, or a list of them sharing one prompt (every element is stored, the first one is the canonical key used for the label). Prompts whose group name contains the substring `interaction` are not attached to a native prompt group and therefore show on screen by themselves, immediately, with no per-frame call. Every other group is attached to a native group and is only visible on the frames where `w.prompt.displayGroup(group, title)` is called. Completion is polled: call `w.prompt.isCompleted(group, key)` every frame, with the key written exactly as at create time (lookups are by the raw value, not normalised). With `holdTime > 0` the prompt is a hold prompt; when it completes, the module disables it until the key is released so it does not fire repeatedly. Without `holdTime` it fires on "just pressed"; pass `fireMultipleTimes = true` to keep returning `true` while the key stays held. All prompts of the consumer resource are deleted on stop. The free camera, the mouse placement tool and the gizmo reuse the groups `interaction_freecam`, `interaction_mouse` and `interaction_GizmoPrompts`; do not create prompts in those groups yourself.

**Player and me.** `w.player` (alias `w.pl`) is a per-resource mirror of the local player with the fields `ped`, `coords`, `playerId`, `serverId`, `isMale`, refreshed by the library every 100 ms (the library polls in its own context and broadcasts the client event `w_lib:player:update` with a list of `{key, value}` pairs; the consumer's copy of the module applies them). `w.player()` called as a function returns `w.player.ped`. `w.player.move(cb, interval)` and `w.player.didMoveSinceLastCall(id)` hang off that event. `w.player.instanceChanged(cb)` receives routing-bucket changes: the library's server polls `GetPlayerRoutingBucket` every 2 s and fires `w_lib:player:instanceChanged` on the server (`AddEventHandler`, args `source, new, old`) and to that client (`RegisterNetEvent`, args `new, old`). The older `me` module exposes the same data as plain fields: `w.me` (ped), `w.meCoords`, `w.mePlayerId`, `w.meServerId`, `w.meIsMale`, refreshed every 1000 ms through the event `w_me:updateMe`; call `w.forceUpdateMe()` when a fresh value is needed right now (it blocks until the refreshed values arrive).

**Raw keys.** `w.rawKeys.listen(key, cb)` watches a physical key with `RegisterRawKeymap` under the name `<yourResource>:rawkey:<key>`; it is silent, not rebindable, and safe to use from several resources on the same key. `w.rawKeys.bind({...})` is the opposite: a named, player-rebindable action (`RegisterKeyMapping` through `lib.addKeybind`) that shows in the player's key settings. Key names are the vk_qwerty names (`"A"`, `"F1"`, `"TAB"`, `"OEM_COMMA"`) plus the aliases listed on the `listen` entry; the server convar `w_lib:keyboard_layout` (`"qwerty"` default, or `"azerty"`) only changes what `getKeyFromVK` returns and is re-read live.

**Debug gates and misc.** Every module reads a per-resource debug convar: set `<yourResource>:debug "on"` to set `w.debug = true`; the gizmo module registers the `/gizmo` test command inside the consumer resource only if `w.debug` was already `true` when the gizmo module loaded. `w.utils.convertToTable` lives in `modules/utils/shared.lua` and is documented below.

Known quirks visible in the source that you should code around:

- `w.entity.create` always reads the heading from the 3rd argument even when `coords` is a vector4 (the vector4 branch never triggers), and only creates peds and objects (not vehicles).
- `w.entity.fadeIn` on a vehicle errors (it references an undefined horses list).
- `w.screen.fadeIn`'s `needWait` only waits while a fade-out is in progress, so it effectively returns immediately.
- `w.utils.releaseGameData` only really releases models (texture and animation dictionaries are left loaded).
- `w.utils.screenToWorld` caches the camera FOV once at module load.
- `w.prompt.getKeyLabel` / `editKeyLabel` work on the first key of a multi-key prompt.
- The gizmo's "Finish" prompt is never created because its key convar does not exist.
- `w.light.create` treats `ease = false` as the default 1000 ms (pass `0` for instant changes).
- `w.camera.freeCamera.stop()` from outside does not end the blocked `start()` loop; only the exit key does.
- `w.input.nui` waits 500 ms and prints "This nui is not loaded: w_input" on every call.

The `pedTexture` module is the one `w.*` table that crosses the export boundary: `w.pedTexture` is `exports.w_lib:w_pedTexture_get()`, so its functions execute inside the library and the layer tables passed to them are serialized (plain data only, no functions). Results are also stored in the entity state bag `w_pedTexture`.

### w.player fields and w.player()

```lua
w.player.ped: integer
w.player.coords: vector3
w.player.playerId: integer
w.player.serverId: integer
w.player.isMale: boolean
w.player() -> integer  -- returns w.player.ped; alias w.pl
```

Side: client

Parameters: none.

Returns: see fields.

Cached local-player values, mirrored from the library which polls every 100 ms and fires the client event `w_lib:player:update` with the changed pairs. Calling `w.player()` returns `w.player.ped`. Load with `w_module { 'player' }` or `w.require("player")`. Values may lag up to 100 ms behind the natives; call `w.player.forceUpdate()` first when they must be fresh. `serverId` is read once at load and never refreshed by the update event.

```lua
local ped = w.player.ped
local dist = #(w.player.coords - target)
if w.pl.isMale then print("male") end
```

### w.player.forceUpdate

```lua
w.player.forceUpdate()
```

Side: client

Parameters: none.

Returns: nothing.

Calls `exports.w_lib:w_player_force_update()`, which re-reads ped and coords inside the library and broadcasts `w_lib:player:update` immediately if something changed.

```lua
w.player.forceUpdate()
```

### w.player.move

```lua
w.player.move(cb: function, interval?: integer)
```

Side: client

Parameters:
- `cb` (function, required): called (pcall, own thread) once immediately and then whenever the player's coords change, at most every `interval` ms.
- `interval` (integer, optional, default 0): minimum ms between two runs; effectively never below the 100 ms poll rate.

Returns: nothing.

Movement hook driven by the coords entries of `w_lib:player:update`. A callback that is still running is not re-entered.

```lua
w.player.move(function()
  checkNearbyZones(w.player.coords)
end, 500)
```

### w.player.didMoveSinceLastCall

```lua
w.player.didMoveSinceLastCall(id: string): boolean
```

Side: client

Parameters:
- `id` (string, required): any unique key for this call site.

Returns: `true` if a coords update happened since the previous call with the same id (always `true` the first time).

Cheap per-call-site movement check based on the timestamp of the last coords update.

```lua
if w.player.didMoveSinceLastCall("myres:zones") then recomputeZones() end
```

### w.player.instanceChanged (client)

```lua
w.player.instanceChanged(cb: fun(newInstance: integer, oldInstance: integer|nil))
```

Side: client

Parameters:
- `cb` (function, required): called on every routing-bucket change of the local player, and once at registration with the current bucket (`oldInstance` nil).

Returns: nothing.

Registers the callback, waits for the library to be loaded, and if the current bucket is not yet known fetches it through the server callback `w_lib:player:getPlayerInstance` (blocking, so call it from a thread). Later changes arrive through the net event `w_lib:player:instanceChanged`, which the server polls every 2 s.

```lua
CreateThread(function()
  w.player.instanceChanged(function(newInstance, oldInstance)
    print("bucket", oldInstance, "->", newInstance)
  end)
end)
```

### w.player.instanceChanged (server)

```lua
w.player.instanceChanged(cb: fun(source: integer, newInstance: integer, oldInstance: integer|nil))
```

Side: server

Parameters:
- `cb` (function, required): called for every player whose routing bucket changed (also on first sight of a player, with `oldInstance` nil).

Returns: nothing.

Server-side registration, fed by the local event `w_lib:player:instanceChanged` that the library's poller triggers every 2 s (polling starts at `w.ready` inside the library). Requires the player module on the server (`w_module { 'player' }`). On the server `w.player()` returns the `w.player` table itself.

```lua
w.player.instanceChanged(function(source, newInstance, oldInstance)
  print(source, "moved to bucket", newInstance)
end)
```

### w.me, w.meCoords, w.mePlayerId, w.meServerId, w.meIsMale

```lua
w.me: integer        -- ped
w.meCoords: vector3
w.mePlayerId: integer
w.meServerId: integer
w.meIsMale: boolean
```

Side: client

Parameters: none.

Returns: see fields.

Older flat mirror of the local player, refreshed every 1000 ms by the library through the client event `w_me:updateMe`. The module has no `w.createModule`; it sets the fields directly on `w`. Load it with `w_module { 'me' }` or `w.require("me")`: if the first thing the code does is read `w.meCoords` (or `mePlayerId` / `meServerId`) before the module is loaded, the loader loads it and returns `w.me` (the ped handle) for that first access. Used internally by `w.entity.createWithMouse`. Coordinates can be up to 1 s old; use `w.forceUpdateMe()` or `w.player` for fresher data.

```lua
w.require("me")
local ped = w.me
local pos = w.meCoords
```

### w.forceUpdateMe and w.updateMeTimer

```lua
w.forceUpdateMe()
w.updateMeTimer(value?: integer)
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `w.forceUpdateMe()` | none | nothing | Calls `exports.w_lib:w_me_forceUpdateMe()` and blocks until the resulting `w_me:updateMe` event has refreshed the local fields. |
| `w.updateMeTimer(value)` | `value` (integer, optional): ignored in consumers | nothing | Deprecated no-op in consumer resources (inside the library it changes the 1000 ms refresh loop). Kept for compatibility. |

```lua
w.forceUpdateMe()
print(w.meCoords)
w.updateMeTimer(500) -- no effect in the consumer resource
```

### w.prompt.create

```lua
w.prompt.create(group: string, str: string, key: string|integer|(string|integer)[], holdTime?: integer|false, page?: integer): integer|false
```

Side: client

Parameters:
- `group` (string, required): group name. If it contains `interaction` the prompt is standalone and shows without `displayGroup`; otherwise it is attached to a native group created on first use and shown only on frames where `displayGroup` is called.
- `str` (string, required): label of the prompt.
- `key` (string | integer | table, required): control name (for example `"INPUT_CONTEXT_RT"`), control hash, or a list of them bound to the same prompt. With a list every element is stored so any of them can be used to query the prompt; the first element is the canonical key used for labels. Returns `false` and prints when nil or an empty list.
- `holdTime` (integer | false, optional, default 0/false): hold duration in ms; a value above 0 makes it a hold prompt (`PromptSetHoldMode`). Otherwise it is a press prompt.
- `page` (integer, optional, default 0): page index inside the group. Pages are only meaningful for non-interaction groups.

Returns: integer native prompt id, or `false` when arguments are missing.

Registers a native prompt (priority 2, enabled, visible) and stores it under group/page/key exactly as given (string or hash, not normalised). Creating the same canonical key again in the same group/page deletes the old prompt first. All prompts are deleted on resource stop.

```lua
w.prompt.create("interaction_shop", "Open shop", "INPUT_CONTEXT_RT", 1000)
CreateThread(function()
  while true do
    if w.prompt.isCompleted("interaction_shop", "INPUT_CONTEXT_RT") then openShop() end
    Wait(0)
  end
end)
```

### w.prompt.displayGroup

```lua
w.prompt.displayGroup(group: string, title: string)
```

Side: client

Parameters:
- `group` (string, required): existing group name (silently ignored if unknown).
- `title` (string, required): title shown above the group's prompts.

Returns: nothing.

Calls `PromptSetActiveGroupThisFrame` for the group with its page count. Must be called every frame; not needed for groups whose name contains `interaction`.

```lua
while nearDoor do
  w.prompt.displayGroup("door", "House door")
  Wait(0)
end
```

### w.prompt.isCompleted

```lua
w.prompt.isCompleted(group: string, key: string|integer, fireMultipleTimes?: boolean, page?: integer): boolean
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required): key exactly as used at create (used for the table lookup); it is also hashed for the control checks.
- `fireMultipleTimes` (boolean, optional, default false): when true keeps returning `true` while the key stays pressed (press prompts) or while this hold prompt is the last completed one and its key is still held (hold prompts).
- `page` (integer, optional): default is the group's current page.

Returns: boolean.

Poll every frame. Returns `false` when the group is unknown or the prompt is disabled or hidden. Hold prompts: `true` once `PromptHasHoldModeCompleted`, then the prompt is disabled until the key is released (a thread re-enables it). Press prompts: `true` on `IsControlJustPressed`.

```lua
if w.prompt.isCompleted("interaction_shop", "INPUT_CONTEXT_RT") then openShop() end
```

### w.prompt.deleteGroup and w.prompt.deleteAllGroups

```lua
w.prompt.deleteGroup(group: string)
w.prompt.deleteAllGroups()
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `w.prompt.deleteGroup(group)` | `group` (string, required) | nothing | Deletes every prompt of the group on every page and forgets the group. The usual way to close a set of prompts. |
| `w.prompt.deleteAllGroups()` | none | nothing | Deletes every group created by the consumer resource. Called automatically on resource stop. |

```lua
w.prompt.deleteGroup("interaction_shop")
```

### w.prompt.setEnabled, setVisible, isEnabled, isVisible, isActive

```lua
w.prompt.setEnabled(group: string, key: string|integer, value: boolean, page?: integer)
w.prompt.setVisible(group: string, key: string|integer, value: boolean, page?: integer)
w.prompt.isEnabled(group: string, key: string|integer, page?: integer): boolean
w.prompt.isVisible(group: string, key: string|integer, page?: integer): boolean
w.prompt.isActive(group: string, key: string|integer, page?: integer): boolean
```

Side: client

Parameters shared by all five: `group` (string, required), `key` (string | integer, required, as used at create), `page` (integer, optional, default current page). `setEnabled` and `setVisible` also take `value` (boolean, required).

| Function | Returns | Description |
|---|---|---|
| `setEnabled` | nothing | Enables or disables the native prompt (greyed out when false); disabled prompts never report `isCompleted`. |
| `setVisible` | nothing | Shows or hides the prompt and records the state for `isVisible`; hidden prompts never report `isCompleted`. |
| `isEnabled` | boolean, `false` when not active | True when the prompt is active and enabled. |
| `isVisible` | boolean | Returns the visibility recorded by `setVisible` (true for an existing prompt that was never hidden, false for an unknown prompt). |
| `isActive` | boolean (`UiPromptIsActive`), `false` when the prompt does not exist | Whether the native prompt is currently active on screen. |

```lua
w.prompt.setEnabled("door", "INPUT_CONTEXT_RT", hasKey)
w.prompt.setVisible("door", "INPUT_CONTEXT_LT", false)
if w.prompt.isEnabled("door", "INPUT_CONTEXT_RT") then print("enabled") end
print(w.prompt.isVisible("door", "INPUT_CONTEXT_LT"), w.prompt.isActive("door", "INPUT_CONTEXT_RT"))
```

### w.prompt.editKeyLabel and w.prompt.getKeyLabel

```lua
w.prompt.editKeyLabel(group: string, key: string|integer, label: string, page?: integer)
w.prompt.getKeyLabel(group: string, key: string|integer, page?: integer): string|nil|false
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required): key. For multi-key prompts the create label is stored under the first key only.
- `label` (string, required, `editKeyLabel` only): new label.
- `page` (integer, optional, default current page).

Returns: `editKeyLabel` nothing; `getKeyLabel` the stored label, `nil` when unknown, `false` when arguments are missing.

`editKeyLabel` changes the prompt text (`PromptSetText`) and stores the label; `getKeyLabel` returns the label last set by `create` or `editKeyLabel`.

```lua
w.prompt.editKeyLabel("interaction_shop", "INPUT_CONTEXT_RT", ("Buy ($%d)"):format(price))
local label = w.prompt.getKeyLabel("interaction_shop", "INPUT_CONTEXT_RT")
```

### w.prompt.isPressed and w.prompt.waitRelease

```lua
w.prompt.isPressed(key: string|integer): boolean
w.prompt.waitRelease(key: string|integer)
```

Side: client

Parameters:
- `key` (string | integer, required): control name or hash.

Returns: `isPressed` boolean; `waitRelease` nothing.

`isPressed` is a plain `IsControlPressed(0, hash)` and does not involve any prompt. `waitRelease` blocks every frame while the control is pressed (checks both enabled and disabled control state).

```lua
if w.prompt.isPressed("INPUT_SPRINT") then print("sprinting") end
w.prompt.waitRelease("INPUT_CONTEXT_RT")
```

### w.prompt.doesLastCompletedIs

```lua
w.prompt.doesLastCompletedIs(group: string, key: string|integer, page?: integer): boolean
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required): key.
- `page` (integer, optional, default current page).

Returns: boolean.

True when this hold prompt is the last one that completed and its key has not been released yet (compares the stored prompt id). For press prompts the module stores the key instead of the prompt id, so this is never true for them; `isCompleted` with `fireMultipleTimes` covers press prompts through `IsControlPressed` instead.

```lua
if w.prompt.doesLastCompletedIs("door", "INPUT_CONTEXT_RT") then print("still holding") end
```

### w.prompt.getProgress

```lua
w.prompt.getProgress(group: string, key: string|integer, page?: integer): number  -- alias w.prompt.getPromptProgress
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required): key.
- `page` (integer, optional, default current page).

Returns: number 0.0-1.0 hold progress (0 when unknown).

Reads the native hold progress of a hold prompt.

```lua
local p = w.prompt.getProgress("interaction_shop", "INPUT_CONTEXT_RT")
```

### w.prompt.delete

```lua
w.prompt.delete(group: string, key: string|integer, page?: integer)  -- alias w.prompt.deletePrompt
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required): key.
- `page` (integer, optional, default current page).

Returns: nothing.

Deletes the native prompt (`PromptDelete`). The entry stays in the module's table, so `isExist` still returns `true` afterwards; prefer `deleteGroup` for a clean removal.

```lua
w.prompt.delete("door", "INPUT_CONTEXT_LT")
```

### w.prompt.isGroupExist and w.prompt.isExist

```lua
w.prompt.isGroupExist(group: string): boolean
w.prompt.isExist(group: string, key: string|integer, page?: integer): boolean  -- alias w.prompt.isPromptExist
```

Side: client

Parameters:
- `group` (string, required): group name.
- `key` (string | integer, required, `isExist` only): key exactly as passed at create (string or hash; not normalised).
- `page` (integer, optional, default current page, `isExist` only).

Returns: boolean.

`isGroupExist` is true once `create` has been called for the group and it was not deleted. `isExist` is true when a prompt is registered under group/page/key; a prompt created with `"INPUT_CONTEXT_RT"` is not found with its hash.

```lua
if not w.prompt.isExist("door", "INPUT_CONTEXT_RT") then createDoorPrompts() end
```

### w.prompt.get, getGroup, getPage, getAll, setGroups

```lua
w.prompt.get(group: string, key: string|integer, page?: integer): integer|false
w.prompt.getGroup(group: string): integer|false
w.prompt.getPage(group: string): integer
w.prompt.getAll(): table
w.prompt.setGroups(groups: table)
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `get` | `group` (string, required), `key` (string \| integer, required), `page` (integer, optional, default current page) | native prompt id or `false` | Gives the native prompt handle for natives the module does not wrap. |
| `getGroup` | `group` (string, required) | native group id (random int chosen at first create) or `false` | Native prompt group handle for the named group. |
| `getPage` | `group` (string, required) | current active page index (0 when unknown or negative) | Reads `PromptGetGroupActivePage`; used as the default page by every other function. |
| `getAll` | none | the internal groups table | Exposes the module's internal prompt registry. |
| `setGroups` | `groups` (table, required): a table previously returned by `getAll` | nothing | Replaces the internal registry. Intended for sharing prompt state between scripts; treat as advanced. |

```lua
local id = w.prompt.get("door", "INPUT_CONTEXT_RT")
if id then PromptSetPriority(id, 3) end
local gid = w.prompt.getGroup("door")
local page = w.prompt.getPage("menu")
local all = w.prompt.getAll()
```

### exports.w_lib:w_prompt_get

```lua
exports.w_lib:w_prompt_get(): table  -- also exports.<anyResourceUsingPrompt>:w_prompt_get()
```

Side: client

Parameters: none.

Returns: that resource's `w.prompt` table.

The prompt module registers this export in every resource that loads it (the export call is in the scoped `client.lua`), so `exports.w_lib:w_prompt_get()` returns the library's own prompt instance and `exports.w_myres:w_prompt_get()` returns that of `w_myres`. Prompts made through a foreign instance belong to that resource's context. Because this crosses the export boundary, only plain data can be passed to the returned functions. Normal consumers should use their own `w.prompt` instead.

```lua
local libPrompt = exports.w_lib:w_prompt_get()
```

### w.entity.create

```lua
w.entity.create(model: string|integer, coords: vector3|vector4, heading?: number, networked?: boolean, fadeDuration?: integer): integer
```

Side: client

Parameters:
- `model` (string | integer, required): model name or hash. Loaded (blocking) via `w.utils.loadGameData` and released with `SetModelAsNoLongerNeeded` afterwards. Must be a ped or an object model; any other model type produces no entity and the call errors.
- `coords` (vector3 | vector4, required): spawn position. Only x, y, z are used; the w of a vector4 is ignored.
- `heading` (number, optional, default 0): heading in degrees. The 3rd argument is always the heading, even when `coords` is a vector4 (the vector4 branch compares `type()` to a function and never runs), so always pass it explicitly.
- `networked` (boolean, optional, default false): passed to `CreatePed` / `CreateObject`.
- `fadeDuration` (integer, optional, default 0): when above 0 the entity spawns with alpha 0 and `w.entity.fadeIn` runs in a separate thread for this many ms.

Returns: integer entity handle.

Creates a ped or an object at (0, 0, 0) and then moves it to coords/heading. Peds get `mp_male` / `mp_female` outfit presets with basic head/body/eyes clothing so they are not invisible, otherwise `SetRandomOutfitVariation`; health core 100, health 600, stamina core 100. The handle is remembered and deleted when the consumer resource stops.

```lua
local ped = w.entity.create("a_m_m_valfarmer_01", vector3(coords.x, coords.y, coords.z), heading + 0.0, false, 400)
FreezeEntityPosition(ped, true)
SetBlockingOfNonTemporaryEvents(ped, true)
```

### w.entity.delete

```lua
w.entity.delete(entity: integer)
```

Side: shared

Parameters:
- `entity` (integer, required): entity handle (client) or server-side entity handle (server).

Returns: nothing.

Calls `DeleteEntity` if the entity exists. On the client it also removes the handle from the module's auto-cleanup list. The server module (`modules/entity/server.lua`) offers the same function for server-side handles; it is the only `w.entity` function available on the server.

```lua
w.entity.delete(npc)
```

### w.entity.fadeIn, w.entity.fadeOut, w.entity.fadeAndDelete

```lua
w.entity.fadeIn(entity: integer, duration?: integer)
w.entity.fadeOut(entity: integer, duration?: integer)
w.entity.fadeAndDelete(entity: integer, duration?: integer)
```

Side: client

Parameters:
- `entity` (integer, required): entity whose alpha is changed (`fadeAndDelete` ignores an entity that does not exist).
- `duration` (integer, optional, default 1000): fade duration in ms.

Returns: nothing.

All three block. `fadeIn` raises `SetEntityAlpha` from the current alpha to 255 over `duration` in a `Wait(10)` loop; do not use it on a vehicle, the vehicle branch references an undefined horses list and errors. `fadeOut` lowers the alpha to 0; for a vehicle (wagon) it also fades every harnessed draft horse and hides the reins, and it does not delete the entity. `fadeAndDelete` runs `fadeOut` for `duration` then `w.entity.delete`; if the consumer resource is already stopped it deletes immediately without fading.

```lua
SetEntityAlpha(obj, 0)
w.entity.fadeIn(obj, 800)

w.entity.fadeOut(wagon, 1500)
w.entity.delete(wagon)

w.entity.fadeAndDelete(npc, 500)
```

### w.entity.requestControl

```lua
w.entity.requestControl(entity: integer)
```

Side: client

Parameters:
- `entity` (integer, required): networked entity handle.

Returns: nothing.

Blocks, calling `NetworkRequestControlOfEntity` every 100 ms, until `NetworkHasControlOfEntity` is true. Never times out; do not call it on an entity that can never be owned.

```lua
w.entity.requestControl(horse)
SetEntityCoords(horse, coords)
```

### w.entity.getEntityInCrosshair

```lua
w.entity.getEntityInCrosshair(distance?: number, flags?: integer, toIgnore?: integer): boolean, vector3, integer
```

Side: client

Parameters:
- `distance` (number, optional, default 100, applied by `screenToWorld`): max raycast distance.
- `flags` (integer, optional, default 16): shape-test flags. In the standard shape-test flag table 16 is objects (1 world, 2 vehicles, 8 peds, 16 objects); pass 8 or `1|2|8|16` for peds or everything.
- `toIgnore` (integer, optional, default `PlayerPedId()`): entity ignored by the ray.

Returns: hit (boolean), hit coordinates (vector3), entity hit (integer, 0 when none).

Draws a small crosshair sprite (`hud_textures` / `breadcrumb`) at screen centre and raycasts from the camera through it with `w.utils.screenToWorld`. Must be called every frame while the crosshair should be visible.

```lua
CreateThread(function()
  while aiming do
    local hit, pos, ent = w.entity.getEntityInCrosshair(50.0, 8)
    if hit and ent ~= 0 and IsControlJustPressed(0, `INPUT_ATTACK`) then target = ent end
    Wait(0)
  end
end)
```

### w.entity.createWithMouse

```lua
w.entity.createWithMouse(model: string|integer, keepEntity?: boolean, networked?: boolean, mouse?: vector2, heading?: number): integer|false, vector3?, number?
```

Side: client

Parameters:
- `model` (string | integer, required): model name or hash of the preview/placed entity.
- `keepEntity` (boolean, optional, default true): when true a real entity is created at the final spot (with the `networked` flag) and returned; when false only position and heading are meaningful.
- `networked` (boolean, optional, default false): networked flag of the final entity (the preview is always local).
- `mouse` (vector2, optional, default `vec2(0.5, 0.5)`): screen point (0-1) the ray is cast through.
- `heading` (number, optional, default 0): initial heading. The scroll wheel changes it in 5 degree steps.

Returns: on placement, entity (integer; when `keepEntity` is false this is the already-deleted preview handle), final coords (vector3), final heading (number). On cancel, a single `false`.

Blocking placement tool. Spawns a translucent, collision-less preview 5 m in front of the player, follows the raycast hit under the mouse (max 10 m from the player), and shows prompts in group `interaction_mouse`: Rotate (scroll), Place (`INPUT_CONTEXT_RT` held 1.5 s), Cancel (`INPUT_CONTEXT_LT` held 1.5 s). Disables `INPUT_ATTACK` and `INPUT_AIM` while active. Uses `w.me` for the player ped (the `me` module is loaded on first access).

```lua
local ent, pos, heading = w.entity.createWithMouse("p_crate14x", true, true)
if ent then print("placed at", pos, heading) end
```

### w.entity.deleteScenariosFromEntity

```lua
w.entity.deleteScenariosFromEntity(entity: integer, size?: number, maxScenario?: integer, maxAttempt?: integer, waitTime?: integer)
```

Side: client

Parameters:
- `entity` (integer, required): entity whose attached scenario points are disabled. Prints an error and returns if it does not exist.
- `size` (number, optional, default 2.0): search radius around the entity.
- `maxScenario` (integer, optional, default 8): max scenario points read per attempt.
- `maxAttempt` (integer, optional, default 10): attempts before giving up.
- `waitTime` (integer, optional, default 100): delay between attempts in ms.

Returns: nothing (runs in its own thread).

Uses `GetScenarioPointsInArea` through a DataView buffer and calls `SetScenarioPointActive(point, false)` on every point whose entity is the given one. Stops after the first attempt that found a match.

```lua
w.entity.deleteScenariosFromEntity(chairProp)
```

### w.animation.play

```lua
w.animation.play(ped: integer, dict: string, name: string, duration?: integer, flag?: integer|integer[], offset?: number): number
```

Side: client

Parameters:
- `ped` (integer, required): entity that plays the animation.
- `dict` (string, required): animation dictionary; loaded automatically (blocking) before playing.
- `name` (string, required): animation name inside the dictionary.
- `duration` (integer, optional, default -1): duration in ms passed to `TaskPlayAnim`.
- `flag` (integer | integer[], optional, default 0): animation flags. Pass the integer value, or a list of bit indices such as `{0, 3}` which is turned into `(1<<0)|(1<<3)`.
- `offset` (number, optional, default 0.0): start offset 0.0-1.0.

Returns: number, the animation length in milliseconds (`GetAnimDuration * 1000`).

Loads the dictionary (waits for it), then calls `TaskPlayAnim(ped, dict, name, easeIn, easeOut, duration, flag, offset, false, false, false)` using `w.animation.easeIn` / `easeOut`. Returns the natural duration so the caller can `Wait` on it.

```lua
local ms = w.animation.play(PlayerPedId(), "amb_work@world_human_broom@male_a@idle_a", "idle_a", -1, {0})
Wait(ms)
```

### w.animation.easeIn and w.animation.easeOut

```lua
w.animation.easeIn: number   -- default 4.0
w.animation.easeOut: number  -- default -4.0
```

Side: client

Parameters: none.

Returns: number.

Blend-in and blend-out speeds passed to `TaskPlayAnim` by `w.animation.play`. Assign a different number before calling `play` to change the blend. Per resource (the consumer's copy of the module).

```lua
w.animation.easeIn = 8.0
w.animation.easeOut = -2.0
```

### w.animation.load

```lua
w.animation.load(dict: string, waiter?: boolean)
```

Side: client

Parameters:
- `dict` (string, required): animation dictionary name.
- `waiter` (boolean, optional, default false): when true the call blocks (`Wait(10)` loop) until the dictionary is loaded.

Returns: nothing.

Requests the animation dictionary if it is not loaded. Returns immediately when it is already loaded. Without `waiter` it only issues the request.

```lua
w.animation.load("amb_work@world_human_broom@male_a@idle_a", true)
```

### w.animation.goToCoords

```lua
w.animation.goToCoords(ped: integer, coords: vector3|vector4, speed?: number, waiter?: boolean, distanceToStop?: number)
```

Side: client

Parameters:
- `ped` (integer, required): ped to move.
- `coords` (vector3 | vector4, required): destination. With a vector4 the ped, once arrived, turns to heading `w` (a vector4 also forces the blocking path).
- `speed` (number, optional, default 1.0): walk speed.
- `waiter` (boolean, optional, default false): when true (or when `coords` is a vector4) the call blocks until the task sequence ends or the ped is within `distanceToStop`.
- `distanceToStop` (number, optional, default nil): only used in the blocking path; stop waiting once the ped is closer than this to `coords`. Default waits for the sequence to finish.

Returns: nothing.

Non-blocking path: issues `TaskGoToCoordAnyMeans` directly. Blocking path: builds a task sequence, clears the ped's tasks, performs it, waits 500 ms, then polls every frame until `GetSequenceProgress == -1` or the ped is within `distanceToStop`; with a vector4 it then calls `w.animation.setDesiredHeading(ped, coords.w, true)`. The blocking path clears existing ped tasks.

```lua
w.animation.goToCoords(npc, vec4(-300.0, 800.0, 118.0, 90.0), 1.0, true, 0.5)
```

### w.animation.setDesiredHeading and w.animation.faceEntity

```lua
w.animation.setDesiredHeading(ped: integer, heading: number, waiter?: boolean)
w.animation.faceEntity(ped: integer, target: integer, waiter?: boolean)
```

Side: client

Parameters:
- `ped` (integer, required): ped to turn.
- `heading` (number, required, `setDesiredHeading` only): target heading in degrees (taken modulo 360).
- `target` (integer, required, `faceEntity` only): entity to face.
- `waiter` (boolean, optional, default true): when true the call blocks until the ped is still again; pass `false` explicitly for fire-and-forget.

Returns: nothing.

`setDesiredHeading` unfreezes the ped if frozen, calls `TaskAchieveHeading(ped, heading, 10000)`, then in a thread waits 1 s plus until `IsPedStill`, clears the ped's tasks and re-freezes it if it was frozen. With `waiter` the caller waits for that thread. `faceEntity` has the same mechanics with `TaskTurnPedToFaceEntity(ped, target, 10000)`.

```lua
w.animation.setDesiredHeading(npc, 180.0)
w.animation.faceEntity(npc, PlayerPedId())
```

### w.animation.waitTaskEnd

```lua
w.animation.waitTaskEnd(ped: integer, task: string|integer)
```

Side: client

Parameters:
- `ped` (integer, required): ped running the task.
- `task` (string | integer, required): script task name or hash (passed through `GetHashFromString`).

Returns: nothing.

Blocks (`Wait(10)` loop) while `GetScriptTaskStatus(ped, task) <= 1`, that is until the named script task is no longer running or waiting.

```lua
w.animation.waitTaskEnd(PlayerPedId(), "SCRIPT_TASK_PLAY_ANIM")
```

### w.blip.create

```lua
w.blip.create(locationOrEntity: vector3|integer, name: string, sprite: string|integer, blipHash?: integer, color?: string|integer): integer|false
```

Side: client

Parameters:
- `locationOrEntity` (vector3 | integer, required): world coordinates (any value with x, y, z) or an entity handle. A number is treated as an entity; if that entity does not exist the function returns `false`.
- `name` (string, required): label shown on the map (`SetBlipName`).
- `sprite` (string | integer, required): sprite name (joaat applied) or sprite hash, for example `"blip_shop_horse"`.
- `blipHash` (integer, optional, default 1664425300): blip type hash passed to `BlipAddForCoords` / `BlipAddForEntity`.
- `color` (string | integer, optional, default none): blip modifier name or hash applied with `BlipAddModifier` (`GetHashFromString`), for example `"BLIP_MODIFIER_MP_COLOR_2"`.

Returns: integer blip handle, or `false` when an entity handle was given and the entity does not exist.

Creates a native blip, remembers it so it is removed when the consumer resource stops, and announces it to w_map (`exports.w_map:Register(blip, {name, sprite, color})`) if w_map is running, re-announcing 1 s after w_map (re)starts. Store the handle and use `RemoveBlip` yourself to drop it early.

```lua
local handle = w.blip.create(vector3(-300.0, 800.0, 118.0), "Stable", "blip_shop_horse", 1664425300, "BLIP_MODIFIER_MP_COLOR_2")
-- later: if handle then RemoveBlip(handle) end
```

### w.screen.fadeOut and w.screen.fadeIn

```lua
w.screen.fadeOut(duration?: integer, needWait?: boolean)
w.screen.fadeIn(duration?: integer, needWait?: boolean)
```

Side: client

Parameters:
- `duration` (integer, optional, default 500): fade time in ms.
- `needWait` (boolean, optional): `fadeOut` default true, block until `IsScreenFadingOut` becomes false. `fadeIn` default false; as written it only waits while `IsScreenFadingOut` is true, so it does not actually wait for the fade-in to finish.

Returns: nothing.

`fadeOut` calls `DoScreenFadeOut(duration)` and, by default, waits for the fade to complete. `fadeIn` calls `DoScreenFadeIn(duration)`; to wait for the fade-in, poll `IsScreenFadedIn` yourself.

```lua
w.screen.fadeOut(500)
SetEntityCoords(PlayerPedId(), dest)
w.screen.fadeIn(800)
while not IsScreenFadedIn() do Wait(0) end
```

### w.utils.loadGameData and w.utils.releaseGameData

```lua
w.utils.loadGameData(name: string|integer, waiter?: boolean)
w.utils.releaseGameData(name: string|integer)
```

Side: client

Parameters:
- `name` (string | integer, required): model name/hash, animation dictionary name, or streamed texture dictionary name. Detected in that order.
- `waiter` (boolean, optional, `loadGameData` only): when true, blocks until the asset is loaded.

Returns: nothing.

`loadGameData` is one request helper for the three asset kinds: `RequestModel`, `RequestAnimDict` or `RequestStreamedTextureDict`. Unknown names are silently ignored. `releaseGameData` calls `SetModelAsNoLongerNeeded` for a loaded model; as written it does nothing for texture dictionaries and (because of an inverted check) never calls `RemoveAnimDict` for a loaded animation dictionary, so release those with natives yourself.

```lua
w.utils.loadGameData("p_crate14x", true)
w.utils.loadGameData("hud_textures", true)
w.utils.releaseGameData("p_crate14x")
```

### w.utils.waiter

```lua
w.utils.waiter(cb: fun(): boolean, maxDuration?: integer, loopTimer?: integer): boolean
```

Side: client

Parameters:
- `cb` (function, required): polled; waiting continues while it returns `true`.
- `maxDuration` (integer, optional, default 1000): timeout in ms.
- `loopTimer` (integer, optional, default 0): wait between polls in ms.

Returns: `true` when `cb` returned `false` before the timeout, `false` on timeout.

Blocking wait-until helper with timeout. Note the inverted sense: `cb` should return `true` while waiting is still needed.

```lua
local ok = w.utils.waiter(function() return not HasModelLoaded(model) end, 5000, 50)
```

### w.utils.screenToWorld

```lua
w.utils.screenToWorld(distance?: number, flags?: integer, toIgnore?: integer, mouseX?: number, mouseY?: number): boolean, vector3, vector3, integer
```

Side: client

Parameters:
- `distance` (number, optional, default 100): ray length.
- `flags` (integer, optional, default `1|2|8|16`, world, vehicles, peds, objects): shape-test flags. With 0 no test runs and `(false, ray end point, ray direction, 0)` is returned.
- `toIgnore` (integer, optional, default `PlayerPedId()`): entity ignored.
- `mouseX` (number, optional, default 0.5): screen X 0-1.
- `mouseY` (number, optional, default 0.5): screen Y 0-1.

Returns: hit (boolean), endCoords (vector3), surfaceNormal (vector3), entityHit (integer).

Builds a ray from the final rendered camera through the given screen point (glm ray picking) and runs `StartShapeTestRay` / `GetShapeTestResult` synchronously. The camera FOV and screen ratio are cached once when the utils module loads, so results drift if the FOV changes (aiming, custom cameras) or the resolution changes.

```lua
local hit, pos, normal, ent = w.utils.screenToWorld(30.0, 1|16, PlayerPedId(), GetControlNormal(0, `INPUT_CURSOR_X`), GetControlNormal(0, `INPUT_CURSOR_Y`))
```

### w.utils.convertToTable

```lua
w.utils.convertToTable(value: any, key: string): table
```

Side: shared

Parameters:
- `value` (any, required): value to wrap. A table is returned unchanged.
- `key` (string, required): key under which a non-table value is stored.

Returns: the original table, or `{ [key] = value }`.

Normalises an argument that may be given either as a table or as a bare value.

```lua
local opts = w.utils.convertToTable("p_crate14x", "model") -- { model = "p_crate14x" }
```

### w.light.create

```lua
w.light.create(coords: vector3, intensity?: number, rgb?: {r,g,b}, range?: number, ease?: number): Light
```

Side: client

Parameters:
- `coords` (vector3, required): light position.
- `intensity` (number, optional, default 1.0): target intensity 0.0-1.0. The light starts at 0 and eases towards it.
- `rgb` (table, optional, default `{255, 160, 122}`): array `{r, g, b}` 0-255.
- `range` (number, optional, default 10.0): light radius.
- `ease` (number, optional, default 1000): easing time base in ms for intensity and position changes. Pass `0` to apply changes instantly. Passing `false` does not disable easing: the code does `ease or 1000`, so `false` becomes 1000.

Returns: Light object with fields `id`, `coords`, `targetCoords`, `rgb`, `range`, `intensity`, `targetIntensity`, `ease`, `deleted` and methods `delete`, `setCoords`, `setIntensity`, `update`.

Registers a light drawn every frame with `DrawLightWithRange` by a single thread in the consumer resource (which sleeps 100 ms when no light exists). Intensity and position move towards their targets with `math.lerp(current, target, deltaTime/ease)`, an exponential approach rather than a linear fade. `light.rgb` and `light.range` may be changed directly on the returned table. Lights stop being drawn when the consumer resource stops.

```lua
local light = w.light.create(GetEntityCoords(PlayerPedId()), 0.8, {255, 200, 120}, 6.0, 500)
Wait(5000)
light:delete()
```

### Light methods

```lua
light:delete()
light:setCoords(coords: vector3)
light:setIntensity(intensity: number)
light:update(deltaTime: number)
```

Side: client

| Method | Parameters | Returns | Description |
|---|---|---|---|
| `light:delete()` | none | nothing | Marks the light deleted and sets its target intensity to 0; it is removed from the draw list once the intensity reaches 0 (next frame when `ease` is 0). |
| `light:setCoords(coords)` | `coords` (vector3, required): new target position | nothing | Moves the light smoothly; the light eases to the new position (instantly when `ease` is 0). |
| `light:setIntensity(intensity)` | `intensity` (number, required): new target intensity 0.0-1.0 | nothing | Eases the light to the new intensity. |
| `light:update(deltaTime)` | `deltaTime` (number, required): elapsed ms | nothing | Advances the easing of intensity and coords. Called by the module's own draw thread every frame; normally never called by the consumer. |

```lua
light:setCoords(GetEntityCoords(PlayerPedId()))
light:setIntensity(0.2)
```

### w.camera.freeCamera.start

```lua
w.camera.freeCamera.start(options?: table)
-- also callable as w.camera.freeCamera(options), w.freecam(options), w.cam.freeCamera(options)
```

Side: client

Parameters:
- `options` (table, optional): free camera options.
  - `interpolate` (integer, optional, default 0): interpolation time in ms used when switching from and back to the previous camera.
  - `showPrompts` (boolean, optional, default true): create the native prompts (Speed, Move Up/Down, Move, Exit) in group `interaction_freecam`.
  - `range` (number, optional, default 10000): maximum distance from the starting camera position; movement beyond it is ignored.

Returns: nothing (returns when the exit key is pressed).

Blocking. Creates a scripted camera at the current rendering (or gameplay) camera, then loops every frame handling mouse rotation, keyboard movement (disabled-control normals), speed change and the exit key (`IsControlJustPressed`) until exit is pressed; then restores the previous camera and destroys its own. Returns immediately if already active. It does not freeze the player or disable any game controls; do that yourself if needed. Keys, labels and speeds come from the `w_lib:camera:*` convars. Rotation can be frozen with `lockRotate`. Stopped automatically when the consumer resource stops.

```lua
CreateThread(function()
  w.camera.freeCamera({ interpolate = 500, range = 200 })
  print("free camera closed")
end)
```

### w.camera.freeCamera.stop

```lua
w.camera.freeCamera.stop()
```

Side: client

Parameters: none.

Returns: nothing.

Stops the free camera from outside: deletes its prompt group, restores the previous camera (with the `interpolate` value given at start) and destroys the free cam. No-op when not active. It does not make a pending `start()` call return: that loop keeps running (harmlessly, the camera handle is -1) until the exit key is pressed.

```lua
w.camera.freeCamera.stop()
```

### w.camera.freeCamera helpers

```lua
w.camera.freeCamera.lockRotate()
w.camera.freeCamera.unlockRotate()
w.camera.freeCamera.getCam(): integer
w.camera.freeCamera.getPromptGroup(): string
w.camera.freeCamera.isActive(): boolean
w.camera.freeCamera.isLocked(): boolean
```

Side: client

Parameters: none for all six.

| Function | Returns | Description |
|---|---|---|
| `lockRotate()` | nothing | Disables mouse rotation of the free camera (movement still works). |
| `unlockRotate()` | nothing | Re-enables mouse rotation after `lockRotate`. |
| `getCam()` | integer camera handle, -1 when inactive | Returns the scripted camera handle so `GetCamCoord` / `GetCamRot` can be read while the free camera runs. |
| `getPromptGroup()` | string, always `"interaction_freecam"` | Name of the prompt group the free camera uses, so the consumer can add prompts to it with `w.prompt.create` while it is active (they are deleted with the group when the camera stops). |
| `isActive()` | boolean | True while the free camera exists. |
| `isLocked()` | boolean | True when rotation is locked by `lockRotate`. |

```lua
local cam = w.camera.freeCamera.getCam()
if cam ~= -1 then print(GetCamCoord(cam)) end
w.prompt.create(w.camera.freeCamera.getPromptGroup(), "Save position", "INPUT_CONTEXT_A")
if w.camera.freeCamera.isActive() and not w.camera.freeCamera.isLocked() then
  w.camera.freeCamera.lockRotate()
end
```

### w.gizmo.moveEntity

```lua
w.gizmo.moveEntity(entity: integer, cfg?: table, allowPlace?: fun(position: vector3): boolean): table|nil
```

Side: client

Parameters:
- `entity` (integer, required): entity to move. Returns `nil` (with a debug print) when nil or when a gizmo is already active.
- `cfg` (table, optional): overrides for the `w_lib:gizmo:*` convar defaults.
  - `enableCam` (boolean, optional, default convar `w_lib:gizmo:enableCam` = true): create a free camera and freeze the player.
  - `maxDistance` (number | false, optional, default 100): max distance the entity may move from its start; `false` rejects every move.
  - `maxCamDistance` (number, optional, default 80): max camera distance from the player.
  - `minY` (number, optional, default -40): camera pitch minimum.
  - `maxY` (number, optional, default 40): camera pitch maximum.
  - `movementSpeed` (number, optional, default 0.1): camera speed; the speed keys adjust it between the min/max convars.
  - `allowTranslateX` / `allowTranslateY` / `allowTranslateZ` (boolean, optional, default true): enable the translate handles per axis.
  - `allowRotateX` / `allowRotateY` / `allowRotateZ` (boolean, optional, default true): enable the rotate handles per axis.
  - `allowSnapToGround` (boolean, optional, default true): offer the Snap to Ground prompt (`PlaceObjectOnGroundProperly`).
  - `rotationSnap` (number, optional, default 5): snap step in degrees while the rotation-snap key is held.
  - `onMove` (function, optional): called as `onMove(position: vector3, rotation: vector3)` on every accepted gizmo update and after snapping.
  - `onlyOnMove` (boolean, optional, default convar `w_lib:gizmo:onlyOnMove` = false): when true and `onMove` is set, the module does not move the entity itself; only `onMove` receives the values.
  - `onBeforeClose` (function, optional): called as `onBeforeClose(responseData, gizmoCam, previousCam)` on confirm; if it returns a camera handle that camera becomes the one restored.
- `allowPlace` (function, optional): validator called with the proposed position (vector3) for both entity moves and camera moves; return `false` to reject.

Returns: table `{entity, coords, position (alias of coords), rotation}` on confirm; the same shape plus `canceled = true` with the original coords/rotation when the cancel key was used; an empty table when closed by `w.gizmo.cancel`; `nil` when not started.

Blocking 3D gizmo. Sends `SetupGizmo` to the NUI frame named `wui` from the consumer resource, so it only works when the `ui_page` is `nui://w_lib/web/build/index.html`. Takes NUI focus with keep-input, hides the HUD, sets the player unarmed, waits 500 ms, and shows prompts in group `interaction_GizmoPrompts`: Cancel, Confirm, Switch mode (translate/rotate), Snap to Ground, Free cam/Focus entity, Camera speed, Rotation snap (shown in rotate mode, held), plus Move prompts when the camera is enabled. Entity updates arrive through the NUI callback `gizmo:UpdateEntity` and are applied with `SetEntityCoordsNoOffset` / `SetEntityRotation` after the `maxDistance` and `allowPlace` checks. Cancel restores the stored position. Cleans up on resource stop.

```lua
CreateThread(function()
  local data = w.gizmo.moveEntity(prop, { enableCam = true, allowRotateX = false, allowRotateY = false,
    onMove = function(pos, rot) print(pos, rot) end })
  if data and data.coords and not data.canceled then
    TriggerServerEvent("myres:savePlacement", data.coords, data.rotation)
  end
end)
```

### w.gizmo.cancel

```lua
w.gizmo.cancel()
```

Side: client

Parameters: none.

Returns: nothing.

Closes the active gizmo from outside: releases NUI focus, restores the camera and unfreezes the player. The pending `moveEntity` call then returns an empty table (no `canceled` flag; the entity is left where it is).

```lua
w.gizmo.cancel()
```

### w.placer.run

```lua
w.placer.run(opts: table): table|nil, string|nil
```

Side: client (blocking: call it from a thread)

A guided editor that places a list of spots in the world, one key press per spot. It is meant for admin tools in resources that ship their own `ui_page`, where `w.gizmo` cannot draw. It draws nothing into the caller's frame. The key cards are a library prompt group (`w.prompt.createGroup`, drawn in w_lib's frame). The instruction line is `w.showTextUI`. The ghosts are LOCAL entities: nobody else sees them, and no state bag is ever read on them.

Parameters (`opts`):
- `steps` (table, required): the spots, in order. Each step:
  - `id` (string, required): the key of the value in the result.
  - `kind` (`'ped'` | `'object'` | `'vehicle'` | `'point'` | `'camera'`, default `'point'`). A ped, object or vehicle step shows a see-through ghost of `model`. Peds are created with `w.entity.create` (random outfit). Vehicles are created with `CreateVehicle(..., bDontAutoCreateDraftAnimals = true)`, so a draft vehicle has no team. Objects are created with `CreateObject`.
  - `model` (string | hash): the ghost's model (ped, object and vehicle steps).
  - `anchor` (`'aim'` | `'front'` | `'self'`): where the spot is. `aim` (the default) is the point the gameplay camera looks at, capped at `distance` metres from the admin. `front` is `distance` metres (default 1.6) ahead of the admin. `self` is the admin's own position, which is the default for camera steps.
  - `distance` (number): the reach of an `aim` step (default `opts.aimDistance`), or the metres ahead for `front`.
  - `height` (number): metres added to the spot. A camera step defaults to 0.65, the eye above the root.
  - `ground` (boolean): snap the spot to the ground. The default is true, except for `self` anchors and camera steps.
  - `face` (`'player'` | `'away'` | `'side'` | `'free'`) and `heading` (number): how the ghost starts turned. The defaults are `player` for peds and `side` for vehicles. The mouse wheel then turns the ghost by `opts.rotateStep` degrees per notch.
  - `ring` (number): draws a ring of this radius at the admin's feet, for example the interaction distance.
  - `text` (string): the instruction line for this step.
  - `current` (vector3 | vector4 | `{x,y,z,w}`): the stored spot. It is drawn as a faded marker, and the skip key keeps it. A kept ped, object or vehicle stands as a ghost for the rest of the run.
  - `optional` (boolean): the skip key skips the step when nothing is stored. `removable` (boolean): the remove key clears a stored spot (the result holds `false`).
  - `when(values, ctx)` (function): return false to skip the step by itself (the stored value stays).
  - `capture(value, ctx)` (function): returns the fields a placement sets (default `{ [id] = value }`). For example, `{ npc = value, interact = ctx.playerCoords }`.
  - `skipLabel(values, ctx)` and `skip(values, ctx)` (functions): the step's own meaning for the skip key. When `skipLabel` returns a label, the key shows it and `skip` returns the fields to set. Example: "same as the display spot".
  - `lookAt` (string | string[]) and `lookHeight` (number): camera steps only. The step ids the camera looks at (the first one with a spot wins) and the height above that ghost's root. A line is drawn from the camera spot to it.
  - `frame(spot, target, ctx)` (function): camera steps only. Returns `camCoords, pointAt, fov` for the look-through key. `ctx` holds `targetEntity` (the ghost) and `targetHeading`. The default looks straight from the spot.
  - `create(model, coords, heading)` (function): creates your own ghost entity instead.
- `title` (string | false): the title of the key cards.
- `maxDistance` (number, default 60): every spot must stay within this distance of the first spot set in the run. A spot too far is refused, and so is keeping a stored spot that far. The save on the confirm step is also refused while the admin stands farther than this from the first spot, because a server that checks the spots against the admin's position would refuse the whole run. Set it to 0 to turn the check off.
- `aimDistance` (number, default 12), `rotateStep` (degrees, default 5), `fov` (default 42), `cancelHold` (ms, default 1000).
- `confirm` (boolean, default true): adds a last step, "check, then save".
- `textPosition` (default `'bottom-center'`) and `keyPosition` (default `'bottom-right'`).
- `keys` (table): `{ place = 'E', skip = 'G', remove = 'DELETE', back = 'BACK', cancel = 'X', look = 'C' }`. Cancel is a hold.
- `labels` (table): `place`, `skip`, `keep`, `remove`, `back`, `cancel`, `look`, `save`, `confirm`, `rotate`, `tooFar` (a `%d` format that receives the metres), and `step`. `step` is a format string `'Step %d/%d - %s'` (step number, total, text) or a function taking the same three values. Missing labels fall back to built-in English or Arabic, following the library language.

Returns: the table of fields the admin set, or `nil` and a reason when he left without saving: `'cancelled'`, `'dead'`, `'mounted'`, `'stopped'` (the resource stopped), `'busy'` (an editor is already running), `'invalid'` or `'error'`. A placed ped, object or vehicle spot is a `vector4` (x, y, ground z, heading 0-360). A point or camera spot is a `vector3`. A kept spot is absent from the result (nil means keep it as it is). A cleared spot is `false`.

While it runs, every frame it does the following:
- Claims the walk-up prompt arbitration at distance 0 (`exports.w_lib:WalkupClaim(0)`), so another resource's walk-up prompt cannot replace the cards. The group is displayed again if something hid it.
- Disables the game controls on its keys (E would mount the ghost horse), plus attack, aim, the weapon wheel and weapon switching (the wheel turns the ghost). It also hides the game's native prompts.
- Drops key presses made while a NUI has focus or the pause menu is open.

It stops by itself on death, on mounting or entering a vehicle, and when the resource stops. Every exit path deletes the ghosts, the look-through camera, the cards and its text line. Your own walk-up prompts (`w.prompt.at`) are in the same resource, so the claim does not silence them. Gate their `canInteract` on `w.placer.isActive()`, or on a busy flag of your own.

```lua
CreateThread(function()
  local values, reason = w.placer.run({
    title = 'Valentine', maxDistance = 60.0,
    steps = {
      { id = 'npc', kind = 'ped', model = 'U_M_M_BwmStablehand_01', anchor = 'front', ring = 2.5,
        text = 'Press E to place the stable hand where you stand',
        capture = function(v, ctx) return { npc = v, interact = ctx.playerCoords } end },
      { id = 'preview', kind = 'ped', model = 'A_C_Horse_Morgan_Bay', text = 'Press E to place the horse' },
      { id = 'camera', kind = 'camera', lookAt = 'preview', lookHeight = 0.4, text = 'Stand where the camera goes' },
      { id = 'wagon', kind = 'vehicle', model = 'cart01', optional = true, removable = true, text = 'The wagon' },
    },
  })
  if values then TriggerServerEvent('myres:savePlaces', values) end
end)
```

### w.placer.cancel, w.placer.isActive and w.placer.canStart

```lua
w.placer.cancel()
w.placer.isActive(): boolean
w.placer.canStart(): boolean, string|nil
```

Side: client

Parameters: none.

Returns: `cancel` returns nothing, and the running `run` returns `nil, 'cancelled'`. `isActive` returns true while an editor runs in this resource. `canStart` returns false with `'busy'`, `'dead'` or `'mounted'` when an editor could not start now.

```lua
if not w.placer.canStart() then return notify('Get off your horse first') end
```

### w.minigame.lockpick

```lua
w.minigame.lockpick(config?: table): "success"|"failed"|"canceled"|"busy"
```

Side: client

Parameters:
- `config` (table, optional): shallow-merged over the defaults (`table.merge` with `deepMerge = false`). A function field `onPinBroken` is allowed because the module runs in the consumer's context; it is stripped (`table.clearForNui`) before sending to NUI.
  - `pins` (integer, optional, default 1): lockpicks available before failure.
  - `pinHealth` (integer, optional, default 100): health of each pick.
  - `pinDamage` (integer, optional, default 20): damage per tick when forcing at a wrong angle.
  - `pinDamageInterval` (integer, optional, default 150): min ms between damage ticks.
  - `solvePadding` (number, optional, default 4): tolerance in degrees around the solution.
  - `maxDistFromSolve` (number, optional, default 45): angle distance used for cylinder allowance.
  - `cylRotSpeed` (number, optional, default 3): cylinder rotation per tick while pushing.
  - `animPostFx` (string | false, optional, default `"PauseMenuIn"`): `AnimpostfxPlay` effect while open; `false` or `""` disables.
  - `onPinBroken` (function, optional): called (no args, pcall-protected) each time a pick breaks.

Returns: string status: `"success"`, `"failed"` (also for an unknown status from the UI), `"canceled"` (closed from the UI or by `w.minigame.cancel`), or `"busy"` when another minigame is running.

Blocking. Places the cursor at (0.5, 0.3), sends `w_minigame:show` to the `wui` frame from the consumer resource (requires `ui_page nui://w_lib/web/build/index.html`), takes NUI focus (input not kept), plays the post-fx, and waits for the NUI callback `w_minigame:finished`. On finish it sends `w_minigame:hide`, restores the previous focus/keep-input state and stops the post-fx. Messages are held until 1.1 s after the module loaded.

```lua
local result = w.minigame.lockpick({ pins = 3, pinHealth = 80, onPinBroken = function() print("snap") end })
if result == "success" then TriggerServerEvent("myres:doorOpened") end
```

### w.minigame.qte

```lua
w.minigame.qte(config?: table): "success"|"failed"|"canceled"|"busy"
```

Side: client

Parameters:
- `config` (table, optional): shallow-merged over the defaults. When passing one of the `{min, max}` range tables, pass both `min` and `max` because the whole subtable is replaced.
  - `roundCount` (integer, optional, default 4): rounds to complete.
  - `allowedKeys` (string[], optional, default A-Z): keys the UI may ask for.
  - `rotationCount` (integer, optional, default 1): full indicator rotations allowed per round.
  - `targetStartAngle` ({min, max}, optional, default `{min = 100, max = 300}`): target segment start angle range.
  - `targetArcSize` ({min, max}, optional, default `{min = 50, max = 60}`): target segment size range in degrees.
  - `rotationDuration` ({min, max}, optional, default `{min = 2000, max = 3000}`): full rotation duration range in ms.
  - `introDelay` (integer, optional, default 200): ms before the indicator starts.
  - `successDelay` (integer, optional, default 450): ms after a successful round.
  - `failureDelay` (integer, optional, default 550): ms before closing after a failed round.
  - `roundDelay` (integer, optional, default 100): ms between rounds.
  - `animPostFx` (string | false, optional, default `"PauseMenuIn"`): post-fx while open; `false` disables.

Returns: string status as for `lockpick`.

Blocking quick-time-event minigame with the same show/focus/finish mechanics as `lockpick` (same `ui_page` requirement). Does not move the cursor.

```lua
local ok = w.minigame.qte({ roundCount = 3, allowedKeys = { "W", "A", "S", "D" } }) == "success"
```

### w.minigame.cancel

```lua
w.minigame.cancel(): boolean
```

Side: client

Parameters: none.

Returns: `true` if a minigame was running and got canceled, `false` otherwise.

Closes the running minigame; the blocked `lockpick` / `qte` call returns `"canceled"`.

```lua
if w.minigame.cancel() then print("minigame aborted") end
```

### w.nui.isHovering

```lua
w.nui.isHovering(global?: boolean): boolean
```

Side: client

Parameters:
- `global` (boolean, optional, default true): `true` asks the library (`exports.w_lib:w_nui_is_global_hovering`) whether any registered resource's NUI is hovered; `false` asks only the consumer's own `ui_page`.

Returns: boolean.

Local mode sends `{ action = "w_nui_is_hovering" }` to the consumer's `ui_page` and blocks until the page answers through the NUI callback `w_nui_is_hovering` with `{ hovering = boolean }`; if the page never answers this call never returns. Global mode loops over every resource that registered with `w_nui_init` and calls their `w_nui_is_hovering` export (same blocking caveat per resource).

```lua
if not w.nui.isHovering() then
  -- mouse is over the game world
end
```

### w.nui.resetFocus

```lua
w.nui.resetFocus()
```

Side: client

Parameters: none.

Returns: nothing.

Sends `{ action = "w_nui_reset_focus" }` to the consumer's `ui_page` via `SendNUIMessage`. Does not touch `SetNuiFocus`.

```lua
w.nui.resetFocus()
```

### w.nui.load, w.nui.isLoaded, w.nui.forceFocus

```lua
w.nui.load(uiName: string, url: string)
w.nui.isLoaded(uiName: string): boolean
w.nui.forceFocus(uiName: string)
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `load(uiName, url)` | `uiName` (string, required, ignored), `url` (string, required, ignored) | nothing | Permanent no-op kept for compatibility (the multi-frame shell no longer exists). Because it never marks anything loaded, `isLoaded` stays false for every name. |
| `isLoaded(uiName)` | `uiName` (string, required): NUI name | boolean, always `false` in this version | Reports whether `load` registered the name. |
| `forceFocus(uiName)` | `uiName` (string, required): NUI name | nothing | Intended to send `w_nui_force_focus` to the `ui_page`; in this version it always prints "This nui is not loaded: <name>" and returns because `isLoaded` is always false. |

```lua
w.nui.load("w_input", "nui://w_lib/nui/input/index.html") -- does nothing
print(w.nui.isLoaded("wui")) -- false
w.nui.forceFocus("wui") -- prints "This nui is not loaded: wui"
```

### NUI hovering exports

```lua
exports.w_lib:w_nui_init()
exports.w_lib:w_nui_is_global_hovering(): boolean
exports.<resource>:w_nui_is_hovering(): boolean
```

Side: client

Parameters: none for all three.

| Export | Returns | Description |
|---|---|---|
| `exports.w_lib:w_nui_init()` | nothing | Registers the calling resource (`GetInvokingResource`) in the library's hovering list. Called automatically at `w.ready` by every resource that loads the nui module, so it is rarely called directly. Resources are dropped from the list on `onResourceStop`. |
| `exports.w_lib:w_nui_is_global_hovering()` | `true` if any registered resource reports its NUI hovered | Iterates the registered resources and calls `exports[<resource>]:w_nui_is_hovering()` until one returns true. Each of those calls blocks until that resource's page answers. |
| `exports.<resource>:w_nui_is_hovering()` | boolean | Defined in the consumer resource by the nui module: asks its `ui_page` (message action `w_nui_is_hovering`, answered via NUI callback `w_nui_is_hovering` with `data.hovering`) and returns the answer. It is what the library's global check calls, so the page must answer it or global hovering checks hang. |

```lua
exports.w_lib:w_nui_init()
local hovered = exports.w_lib:w_nui_is_global_hovering()
local mine = exports.w_myres:w_nui_is_hovering()
```

### w.input.native

```lua
w.input.native(label: string, placeholder: string, maxStringLength?: integer): string
```

Side: client

Parameters:
- `label` (string, required): text shown above the field (registered as text entry `FMMC_KEY_TIP1`).
- `placeholder` (string, required): initial text in the field.
- `maxStringLength` (integer, optional, default 60): max characters.

Returns: the string typed (`""` when canceled or empty).

Blocking native on-screen keyboard (`DisplayOnscreenKeyboard`). Polls `UpdateOnscreenKeyboard` every frame until confirmed (1) or canceled (2), then waits 100 ms and returns.

```lua
local name = w.input.native("Horse name", "", 24)
if name ~= "" then TriggerServerEvent("myres:rename", name) end
```

### w.input.nui

```lua
w.input.nui(options: table, cb?: fun(result)): table|false|nil
```

Side: client

Not confirmed from source; treat as best effort.

Parameters:
- `options` (table, required): input panel definition sent to the frame named `w_input` on the consumer's `ui_page`.
  - `rows` (table, required): list of rows. Each row is either a plain array of column entries or `{ columns = {...}, position? = "header"|"content"|"footer", ...other row metadata }`. Only content scrolls. Inside a column entry the key `for` is renamed to `target`. Column order is preserved because the NUI derives entry ids from indexes.
  - `lang` (table, optional): translation strings; only string keys starting with `inputNui` with string values are forwarded (message `setStrings`).
- `cb` (function, optional): when given, the call returns `nil` immediately and `cb(result)` runs in a new thread when the NUI answers.

Returns: without `cb`, the data table posted by the NUI callback `w_input:click` (the annotation documents `false` on cancel). With `cb`, `nil`. Returns `false` immediately (plus an error print) if an input panel is already open.

Sends `setStrings` then `newInput` (`messageTargetUiName "w_input"`, field `event`) to the `ui_page`, sets NUI focus with input not kept, and waits for the NUI callback `w_input:click`. Because `w.nui.isLoaded` is always false, every call first waits 500 ms and `w.nui.forceFocus` prints "This nui is not loaded: w_input". Price-type entries listed in the callback's `priceIds` are converted with `w.pricing.new` / `w.pricing.newGroup` before the result is returned. Focus and keep-input are restored afterwards. Whether the current unified w_lib web build still serves the `w_input` frame protocol could not be confirmed.

```lua
local result = w.input.nui({
  rows = {
    { columns = { { type = "text", label = "Name", id = "name" } } },
    { position = "footer", columns = { { type = "button", label = "OK", class = "success" } } }
  }
})
if result then print(json.encode(result)) end
```

### w.input.loadNUI

```lua
w.input.loadNUI()
```

Side: client

Parameters: none.

Returns: nothing.

Requires the nui module and calls `w.nui.load("w_input", ...)`, which is a no-op in this version.

```lua
w.input.loadNUI()
```

### w.rawKeys.listen

```lua
w.rawKeys.listen(key: string|integer, callback: fun(pressed: boolean)): integer|nil
```

Side: client

Parameters:
- `key` (string | integer, required): key name from the QWERTY VK table (`"A"`, `"1"`, `"F1"`, `"TAB"`, `"SPACE"`, `"OEM_COMMA"`), an alias (`backspace`, `enter`, `ctrl`, `esc`, `pageup`, `pagedown`, `hanja`, `numpad_multiply` / `numpad_add` / `numpad_subtract` / `numpad_decimal`, `"l shift"`, `"r shift"`, `"l ctrl"`, `"r ctrl"`, `"l alt"`, `"r alt"`, `";"`, `"+"`, `","`, `"-"`, `"/"`, `` "`" ``, `"["`, `"\\"`, `"]"`, `"'"`), or a numeric VK code. Case-insensitive.
- `callback` (function, required): called with `true` on press and `false` on release (pcall-protected; errors are printed).

Returns: listener id for `removeListener`, or `nil` (with an error print) when the key is unknown.

Registers, once per key per resource, a `RegisterRawKeymap` named `<yourResource>:rawkey:<key>` and appends the callback. Not rebindable, not shown in the player's settings, and several resources can watch the same key. Fires even while NUI has focus unless guarded by the consumer.

```lua
w.rawKeys.listen("I", function(pressed)
  if pressed and not IsNuiFocused() then openInventory() end
end)
```

### w.rawKeys.removeListener and w.rawKeys.remove

```lua
w.rawKeys.removeListener(id: integer): boolean
w.rawKeys.remove(key: string|integer)
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `removeListener(id)` | `id` (integer, required): id returned by `listen` | `true` when removed, `false` otherwise | Removes one listener. The raw keymap itself stays registered (harmless). |
| `remove(key)` | `key` (string \| integer, required): key name, alias or VK | nothing | Deprecated since 2.9.0: drops all listeners of the key in the consumer resource. Use `removeListener`. |

```lua
local id = w.rawKeys.listen("F5", cb)
w.rawKeys.removeListener(id)
```

### w.rawKeys.bind

```lua
w.rawKeys.bind(data: table): CKeybind|nil
```

Side: client

Parameters:
- `data` (table, required): keybind definition forwarded to `lib.addKeybind` (ox_lib style). The same table becomes the keybind object.
  - `name` (string, required): unique action name in the consumer resource; binding the same name twice prints an error and returns the existing keybind.
  - `description` (string, optional, default = `name`): text shown in the player's key settings.
  - `defaultKey` (string, optional, default `''`): default key in `RegisterKeyMapping` syntax, for example `"F5"`.
  - `defaultMapper` (string, optional, default `"keyboard"`): input mapper id.
  - `onPressed` (fun(self), optional): press handler.
  - `onReleased` (fun(self), optional): release handler.
  - `disabled` (boolean, optional): start disabled.
  - `secondaryKey` (string, optional): second default key; `secondaryMapper` (string, optional) is its mapper.
  - `allowInPauseMenu` (boolean, optional): fire even while the pause menu is open.

Returns: CKeybind object (fields `disabled`, `isPressed`, `hash`, `currentKey`; methods `getCurrentKey()`, `isControlPressed()`, `disable(toggle)`), or `nil` with an error when `lib.addKeybind` is unavailable.

Registers a named, player-rebindable action through `RegisterKeyMapping` (`+name` / `-name` commands). Requires `@w_lib/init.lua` to be loaded before (`lib.addKeybind`). On RedM `GET_CONTROL_INSTRUCTIONAL_BUTTON` does not exist, so `currentKey` / `getCurrentKey()` return the requested `defaultKey`, not what the player rebound. Use `bind` for actions the player should see and rebind; use `listen` for silent raw watching.

```lua
local keybind = w.rawKeys.bind({
  name = "open_crafting",
  description = "Open crafting menu",
  defaultKey = "F5",
  onPressed = function() openCrafting() end,
})
```

### w.rawKeys.getBind

```lua
w.rawKeys.getBind(name: string): CKeybind|nil
```

Side: client

Parameters:
- `name` (string, required): name given to `bind`.

Returns: the keybind or `nil`.

Returns the keybind registered under that name in the consumer resource.

```lua
local kb = w.rawKeys.getBind("open_crafting")
if kb then kb:disable(true) end
```

### w.rawKeys lookup helpers

```lua
w.rawKeys.getVK(key: string|integer): integer|nil
w.rawKeys.getKeyFromVK(vk: integer): string|nil
w.rawKeys.getAliasFromStandardKey(key: string): string
w.rawKeys.getAllVK(): integer[]
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `getVK(key)` | `key` (string \| integer, required): key name or alias; a number is returned unchanged | VK code or `nil` | Resolves a key name to its virtual-key code using the QWERTY table (layout convar not applied). |
| `getKeyFromVK(vk)` | `vk` (integer, required): virtual-key code | lower-case key name, honouring `w_lib:keyboard_layout` | Reverse lookup; with layout `"azerty"` the AZERTY table is merged over QWERTY first. |
| `getAliasFromStandardKey(key)` | `key` (string, required): standard VK name such as `"oem_comma"` or `"return"` | the friendly alias (`","`, `"enter"`) or the lower-cased input | Inverse of the alias table, useful for showing a human-readable key. |
| `getAllVK()` | none | cached array of every VK code in the QWERTY table | Lists all known virtual-key codes. |

```lua
print(w.rawKeys.getVK("TAB")) -- 9
print(w.rawKeys.getKeyFromVK(65)) -- "a" ("q" on azerty)
print(w.rawKeys.getAliasFromStandardKey("RETURN")) -- "enter"
for _, vk in ipairs(w.rawKeys.getAllVK()) do print(vk) end
```

### w.pedTexture.apply

```lua
w.pedTexture.apply(ped: integer, layerName: string, data: table|table[])
```

Side: client

Parameters:
- `ped` (integer, required): networked ped (local entities are rejected with a debug message).
- `layerName` (string, required): one of the keys of `w.pedTexture.categories`: `acne`, `ageing`, `beard`, `blush`, `complex`, `disc`, `eyebrow`, `eyeliner`, `eyeshadow`, `foundation`, `freckles`, `grime`, `hair`, `lipstick`, `masks`, `moles`, `scar`, `spots` (all in category `heads`). Unknown names print an error.
- `data` (table, required): one layer, or an array of layers for the same name. Pass `{}` to clear the layer. Plain data only (this call crosses the export boundary).
  - `id` (integer, one of `id` / `albedo` required): overlay id; turned into an albedo name (`mp_u_faov_<layer>_%03d`, `mp_u_faov_eyebrow_<m|f>_%03d`, `mp_u_faov_m_hair_%03d`, or `mp_u_faov_m_hair_<string>` for a string hair id).
  - `albedo` (string, one of `id` / `albedo` required): explicit albedo texture name; normal and material are derived as `<albedo>_nm` and `<albedo>_ab`.
  - `sexe` (string, optional): `"m"` / `"f"` for eyebrow ids; default from `IsPedMale`.
  - `sheetGrid` (integer, optional, default 0): sheet grid index (used by eyeliner/eyeshadow/lipstick variations).
  - `opacity` (number, optional, default 1.0): layer alpha.
  - `blendType` (integer, optional): default 1 for scar/spots/disc/complex/acne/ageing/moles/freckles, else 0.
  - `palette` (string | integer, optional, default `"metaped_tint_makeup"` for heads): tint palette.
  - `tint0` / `tint1` / `tint2` (integer, optional, default 0): palette tint indices. `palette` and tints are only applied to layers whose default blend type is 0 (not scar/spots/disc/complex/acne/ageing/moles/freckles), regardless of a `blendType` override.

Returns: nothing (work happens in a delayed thread, 200 ms debounce per ped).

Stores the layer in the library's per-ped table (seeded from the entity state bag `w_pedTexture` if present), then rebuilds the whole head texture: waits for the ped to be ready, requests a texture from the ped's meta asset GUIDs, adds every stored layer in `w.pedTexture.ordersToApply` order, applies it and writes the layer table to the entity state bag `w_pedTexture`. Retries up to 5 times when the texture is invalid. Waits 2 s first if the screen is faded out or a loading screen is visible. This table is the export proxy `exports.w_lib:w_pedTexture_get()`, so it executes inside the library.

```lua
w.pedTexture.apply(PlayerPedId(), "scar", { id = 3, opacity = 0.8 })
w.pedTexture.apply(PlayerPedId(), "eyeliner", { id = 0, sheetGrid = 1, tint0 = 12 })
```

### w.pedTexture.remove, refreshAll, refreshNow

```lua
w.pedTexture.remove(ped: integer, layerName: string)
w.pedTexture.refreshAll(ped: integer)
w.pedTexture.refreshNow(ped: integer)
```

Side: client

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `remove(ped, layerName)` | `ped` (integer, required): networked ped; `layerName` (string, required): layer to clear | nothing | Equivalent to `apply(ped, layerName, {})`: drops the layer and rebuilds the texture. |
| `refreshAll(ped)` | `ped` (integer, required): networked ped | nothing | Re-applies every stored layer (from the library's cache or from the entity state bag `w_pedTexture`) and executes the pending update immediately. Does nothing when no layers are stored. Use after a ped model or outfit change wiped the overlays. |
| `refreshNow(ped)` | `ped` (integer, required): ped with a pending debounced update | nothing | Executes the pending 200 ms delayed texture rebuild right away. Errors if no update was ever scheduled for this ped (the delay entry is nil), so only call it after `apply`. |

```lua
w.pedTexture.remove(PlayerPedId(), "scar")
w.pedTexture.refreshAll(PlayerPedId())
w.pedTexture.apply(ped, "blush", { id = 1 })
w.pedTexture.refreshNow(ped)
```

### w.pedTexture.overwriteBodyPart

```lua
w.pedTexture.overwriteBodyPart(ped: integer, category: string, overlays: table<string, table>, forceRemove?: boolean)  -- alias w.pedTexture.overwriteCategory
```

Side: client

Parameters:
- `ped` (integer, required): networked ped.
- `category` (string, required): body part category; `"heads"` is the only one defined.
- `overlays` (table, required): map `layerName -> layer data` (same shape as `apply`'s `data`). nil or empty applies nothing after the clear.
- `forceRemove` (boolean, optional, default false): when true the category is cleared even if nothing was stored before.

Returns: nothing.

Replaces the whole set of layers of a category: empties the stored layers (when the category exists or `forceRemove`), triggers one rebuild through `remove`, then applies each overlay. The idiom for pushing a complete face set.

```lua
w.pedTexture.overwriteBodyPart(ped, "heads", {
  eyebrow = { id = 2 },
  freckles = { id = 4, opacity = 0.6 },
}, true)
```

### w.pedTexture.getAll and w.pedTexture.getOverlayAssetFromId

```lua
w.pedTexture.getAll(ped: integer): table<string, table>
w.pedTexture.getOverlayAssetFromId(isMale: boolean, category: string, data: integer|table): string
```

Side: client

Parameters:
- `getAll`: `ped` (integer, required): ped (cache or state bag is used).
- `getOverlayAssetFromId`: `isMale` (boolean, required): sex used for eyebrow names when `data.sexe` is absent; `category` (string, required): layer name (eyebrow and hair have special patterns); `data` (integer | table, required): overlay id, or table with `id` / `sexe` / `albedo` (`albedo` is returned as-is).

Returns: `getAll` a map `layerName -> stored layer data` (albedo/normal/material form); `getOverlayAssetFromId` the albedo texture name string.

`getAll` lists every layer currently applied to the ped across all categories. `getOverlayAssetFromId` is a pure helper that builds the `mp_u_faov_*` texture name for an overlay id.

```lua
for layer, data in pairs(w.pedTexture.getAll(PlayerPedId())) do print(layer, data.albedo) end
print(w.pedTexture.getOverlayAssetFromId(true, "scar", 3)) -- mp_u_faov_scar_003
```

### w.pedTexture.variations, categories, ordersToApply

```lua
w.pedTexture.variations: table<layerName, {label: string, value: false|{id, sexe?, sheetGrid?}}[]>
w.pedTexture.categories: table<layerName, "heads">
w.pedTexture.ordersToApply: { heads: string[] }
```

Side: client

Parameters: none.

Returns: data tables (a serialized copy in the consumer resource).

Catalogue data for building UIs: `variations` lists the known overlay choices per layer (`value` false means none; hair is split into `mp_male` / `mp_female` sub-tables), `categories` maps each layer to its body part, `ordersToApply` gives the layer draw order for heads.

```lua
for _, v in ipairs(w.pedTexture.variations.scar) do print(v.label, v.value and v.value.id) end
```

### exports.w_lib:w_pedTexture_get

```lua
exports.w_lib:w_pedTexture_get(): table
```

Side: client

Parameters: none.

Returns: the library's `w.pedTexture` table.

Returns the ped-texture module living inside the library; the consumer file `modules/ped-texture/client.lua` assigns it to `w.pedTexture` automatically, so it does not need to be called directly. All its functions run in the library's context (state is shared per client, keyed by ped); arguments must be plain serializable data.

```lua
local pedTexture = exports.w_lib:w_pedTexture_get()
```

### w.debugger.resetText and w.debugger.drawText

```lua
w.debugger.resetText()
w.debugger.drawText(text: string, x?: number, y?: number)
```

Side: client

Parameters:
- `text` (string, required, `drawText` only): text to draw (scale 0.35, white, drop shadow, font 0).
- `x` (number, optional, default 0.01): screen X 0-1.
- `y` (number, optional): screen Y 0-1. Default is the running offset, incremented by 0.02 before each call.

Returns: nothing.

`drawText` draws per-frame debug text; without `y`, successive calls stack downwards. `resetText` resets the running Y offset to 0.02; call it once per frame before a series of `drawText` calls.

```lua
CreateThread(function() while true do
  w.debugger.resetText()
  w.debugger.drawText(("coords %s"):format(w.player.coords))
  Wait(0)
end end)
```

### w.debugger.drawSphere

```lua
w.debugger.drawSphere(coords: vector3, size?: vector3, color?: {r,g,b,a})
```

Side: client

Parameters:
- `coords` (vector3, required): centre; nil is ignored.
- `size` (vector3, optional, default `vec3(0.5, 0.5, 0.5)`): scale per axis.
- `color` (table, optional, default `{ r = 255, g = 0, b = 0, a = 100 }`): `{ r, g, b, a }` 0-255.

Returns: nothing.

Per-frame `DrawMarker` sphere (marker `0x50638AB9`).

```lua
w.debugger.drawSphere(zoneCenter, vec3(2.0, 2.0, 2.0), { r = 0, g = 255, b = 0, a = 80 })
```

### w.debugger.perfomance and w.debugger.perfomanceRepeat

```lua
w.debugger.perfomance(title?: string, cb: function): number
w.debugger.perfomanceRepeat(title?: string, numberRepeat?: integer, cb: function, waitBetweenRepeat?: integer): number
```

Side: shared

Parameters:
- `title` (string, optional, default `""`): label printed with the result.
- `numberRepeat` (integer, optional, default 1, `perfomanceRepeat` only): repetitions (min 1).
- `cb` (function, required): function to time.
- `waitBetweenRepeat` (integer, optional, default none, `perfomanceRepeat` only): wait in ms between runs.

Returns: duration in microseconds (integer); for `perfomanceRepeat` the average.

`perfomance` runs `cb` once and prints and returns its duration (the real name is spelled `perfomance`). It uses `os.microtime` on the server and `GetNumberOfMicrosecondsSinceLastCall` on the client, and is equivalent to `perfomanceRepeat(title, 1, cb)`. `perfomanceRepeat` times `cb` `numberRepeat` times, prints `<time>, Performance average on N repetition: <title> -> X us` and returns the average.

```lua
w.debugger.perfomance("build menu", function() buildMenu() end)
w.debugger.perfomanceRepeat("raycast", 100, function() w.utils.screenToWorld(50.0) end, 0)
```

### DataView (dataview module, client)

```lua
DataView.ArrayBuffer(length: integer): DataView
DataView.Wrap(blob: string): DataView
view:Buffer(): string
view:ByteLength(): integer
view:ByteOffset(): integer
view:SubView(offset: integer): DataView
view:Get<T>(offset: integer, bigEndian?: boolean)
view:Set<T>(offset: integer, value, bigEndian?: boolean): DataView
view:GetFixedString|GetFixedInt|GetFixedUint(offset, typelen, bigEndian?)
view:SetFixedString|SetFixedInt|SetFixedUint(offset, typelen, value, bigEndian?)
```

Side: client

Parameters:
- `length` (integer, required): buffer size in bytes for `ArrayBuffer` (a minimum of 41 bytes is allocated so the string is not interned).
- `offset` (integer, required): zero-based byte offset for Get/Set. Out-of-range reads return nil; out-of-range writes are ignored.
- `<T>` (string, required): one of `Int8`, `Uint8`, `Int16`, `Uint16`, `Int32`, `Uint32`, `Int64`, `Uint64`, `LuaInt`, `UluaInt`, `LuaNum`, `Float32`, `Float64`, `String` (zero-terminated).
- `bigEndian` (boolean, optional): default little endian.

Returns: see signature.

Global helper defined by the dataview module (`w.require("dataview")` or list `'dataview'` in `w_module`; the module creates no `w.dataview` table, so `w.dataview` is nil) for passing binary structs to natives that take a buffer pointer: create the buffer, pass `view:Buffer()` to the native, then read fields back with the typed getters.

```lua
w.require("dataview")
local view = DataView.ArrayBuffer(8 * 8)
local ok = Citizen.InvokeNative(0x79923CD21BECE14E, 1, view:Buffer(), Citizen.ReturnResultAnyway())
if ok then print(view:GetInt64(0), view:GetInt32(8)) end
```

### bigInt

```lua
bigInt(value: integer|string): integer
```

Side: client

Parameters:
- `value` (integer | string, required): value written into an Int64 slot of a 16-byte DataView.

Returns: the value read back as a 64-bit integer.

Global defined by the dataview module: round-trips a value through DataView `SetInt64` / `GetInt64`. Requires the dataview module to be loaded.

```lua
w.require("dataview")
local hash = bigInt(0x79923CD21BECE14E)
```

### Player and me exports

```lua
exports.w_lib:w_player_force_update()
exports.w_lib:w_me_forceUpdateMe()
```

Side: client

Parameters: none.

Returns: nothing.

| Export | Description |
|---|---|
| `exports.w_lib:w_player_force_update()` | Forces the library to re-read the local player values and broadcast `w_lib:player:update` when something changed. Wrapped by `w.player.forceUpdate`. |
| `exports.w_lib:w_me_forceUpdateMe()` | Makes the library re-read the local player and broadcast `w_me:updateMe` now. Wrapped by `w.forceUpdateMe`. |

```lua
exports.w_lib:w_player_force_update()
exports.w_lib:w_me_forceUpdateMe()
```

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `w_lib:player:update` | client (local) | `values`: array of `{key, value}` pairs; keys are `ped`, `playerId`, `isMale` (when the ped handle changed) and `coords` (when moved more than 0.0001) | Triggered by the library every 100 ms when something changed, and by `w_player_force_update`. The consumer's player module already applies it to `w.player`; listen only for raw notifications. `AddEventHandler("w_lib:player:update", function(values) ... end)` |
| `w_lib:player:instanceChanged` | client (net event) | `newInstance` (integer), `oldInstance` (integer or nil the first time a player is seen) | Sent to the affected player by the library's server poller (every 2 s) when the routing bucket changed. Prefer `w.player.instanceChanged`, which wraps it. `RegisterNetEvent("w_lib:player:instanceChanged", function(newInstance, oldInstance) ... end)` |
| `w_lib:player:instanceChanged` | server (local) | `source` (integer), `newInstance` (integer), `oldInstance` (integer or nil) | Emitted by the library's server poller for every player whose routing bucket changed. `AddEventHandler("w_lib:player:instanceChanged", function(source, newInstance, oldInstance) ... end)` |
| `w_me:updateMe` | client (local) | `me` (integer ped), `meCoords` (vector3), `mePlayerId` (integer), `meServerId` (integer), `meIsMale` (boolean) | Broadcast by the library every 1000 ms and on `w_me_forceUpdateMe`. The me module already consumes it. |

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `<yourResource>:debug` | shared | `"on"` or `"off"` (use `setr`) | Read by the module loader for every resource that uses the library: `"on"` sets `w.debug = true` (live-updated through a convar change listener), enables `dprint` output, and makes the gizmo module register `/gizmo` in that resource if it was already on when the gizmo module loaded. Per-module variants `<resource>:debug:<module>` and `all:debug:<module>` toggle `w.debugModules[module]`. |
| `w_lib:keyboard_layout` | client | `"qwerty"` (default) or `"azerty"`, case-insensitive | Keyboard layout used by `w.rawKeys.getKeyFromVK` (AZERTY names merged over QWERTY when `"azerty"`). Re-read live through a convar change listener. Does not affect `listen` / `getVK`, which always use the QWERTY table. |
| `w_lib:camera:keys:moveX` / `moveY` / `moveUp` / `moveDown` / `speedUp` / `speedDown` / `exit` | client | control name or numeric hash (through `GetHashFromString`); defaults `INPUT_SCRIPTED_FLY_LR`, `INPUT_SCRIPTED_FLY_UD`, `INPUT_SCRIPTED_FLY_ZUP`, `INPUT_SCRIPTED_FLY_ZDOWN`, `INPUT_SELECT_PREV_WEAPON`, `INPUT_SELECT_NEXT_WEAPON`, `INPUT_QUIT` | Control names used by the free camera, read once when the camera module loads. Must be replicated (`setr`) to reach clients. |
| `w_lib:camera:strings:move` / `moveUpDown` / `exit` / `speed` | client | text; defaults `"Move"`, `"Move Up/Down"`, `"Exit"`, `"Speed %.2f"` (the speed string is a `string.format` pattern receiving the current speed) | Prompt labels of the free camera. |
| `w_lib:camera:movement:speed` / `maxSpeed` / `minSpeed` / `speedIncrement` | client | float; defaults 0.05, 0.5, 0.01, 0.05 | Free camera movement tuning, read with `GetConvarFloat` at module load. |
| `w_lib:camera:rotation:speed` / `minY` / `maxY` | client | float; defaults 5.0, -80.0, 80.0 (pitch clamp in degrees) | Free camera rotation tuning, read at module load. |
| `w_lib:gizmo:enableCam`, `allowTranslateX/Y/Z`, `allowRotateX/Y/Z`, `allowSnapToGround`, `onlyOnMove` | client | boolean (`GetConvarBool`); defaults true except `onlyOnMove` false | Gizmo defaults read at module load. |
| `w_lib:gizmo:maxDistance`, `maxCamDistance`, `minY`, `maxY`, `rotationSnap` | client | integer (`GetConvarInt`); defaults 100, 80, -40, 40, 5 | Gizmo defaults read at module load. |
| `w_lib:gizmo:movementSpeed`, `maxMovementSpeed`, `minMovementSpeed`, `movementSpeedIncrement` | client | float (`GetConvarFloat`); defaults 0.1, 0.2, 0.001, 0.01 | Gizmo camera speed defaults. |
| `w_lib:gizmo:keys:moveX`, `moveY`, `moveUp`, `moveDown`, `cancel`, `switchMode`, `snapToGround`, `confirm`, `focusEntity`, `cameraSpeedUp`, `cameraSpeedDown`, `rotationSnap` | client | numeric control hash (`GetConvarInt`); defaults `INPUT_SCRIPTED_FLY_LR`, `INPUT_SCRIPTED_FLY_UD`, `INPUT_FRONTEND_X`, `INPUT_FRONTEND_RUP`, `INPUT_GAME_MENU_TAB_RIGHT_SECONDARY`, `INPUT_RELOAD`, `INPUT_INTERACT_OPTION1`, `INPUT_FRONTEND_ACCEPT`, `INPUT_SHOP_SPECIAL`, `INPUT_SELECT_PREV_WEAPON`, `INPUT_SELECT_NEXT_WEAPON`, `INPUT_FRONTEND_Y` | Gizmo key bindings. Key convars must be the numeric hash, not the name (for example `setr w_lib:gizmo:keys:confirm -2064326857`). |

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `/gizmo` | client | none | Test command registered by the gizmo module in the consumer resource only when `w.debug` is already true at the moment the gizmo module loads (convar `<yourResource>:debug "on"` set before start). Spawns a networked `p_crate14x` 3 m ahead, runs `w.gizmo.moveEntity` with `enableCam = true`, prints the result as JSON (`dprint`) and deletes the crate. |

## Logic modules under w.* (menu, pricing, component/clothing, version checker)

### How these modules reach a consumer resource

Add `'@w_lib/init.lua'` to `shared_scripts` and list the modules you need in a `w_module { ... }` block of your `fxmanifest.lua`; `w_init.lua` reads that metadata (w_creators, for example, lists `'component'`, `'callback'`, `'player'`). Any module is also loaded lazily the first time you index `w.<module>` (the `w` table's `__index` calls the loader) or when you call `w.require("menu")`. `jo` is an alias of the same `w` table (`_ENV.jo = w`), so `jo.menu.*` and `w.menu.*` are identical. Aliases that matter here: `w.versionChecker` is the folder `version-checker`, `w.framework` is `framework-bridge`, `w.pedTexture` is `ped-texture`.

The loader reads, per module folder, `shared.lua` and then `client.lua` / `server.lua` into the calling resource, and, only inside w_lib, the `g_shared.lua` / `g_client.lua` / `g_server.lua` files (global files). When a consumer resource loads a module, w_lib is first asked (`exports.w_lib:loadGlobalModule`) to load that module's `g_` files in its own VM. This split is what makes the four modules behave differently at the resource boundary.

**Menu (client only) and pricing (shared) have no `g_` files.** They are plain Lua loaded inside the consumer resource. Every consumer resource therefore owns a private menu registry: a menu created by resource A does not exist for resource B, and `w.menu.isOpen()` reports only your own menus. Because the code runs in your VM, handlers (`onClick`, `onActive`, ...) may be real Lua functions. Two exports (`w_menu_get`, `w_menu_get_current_data`) are registered by each resource that loads the module, under that resource's own name; w_lib's manifest lists only `version-checker` and `i18n`, so `exports.w_lib:w_menu_get` does not exist unless w_lib itself loaded the menu module. If you ever take a menu or item table through an export boundary, functions cannot cross it: use the string fields `onClickClientEvent` / `onClickServerEvent` (the same `<event>ClientEvent` / `<event>ServerEvent` suffix applies to `onActive`, `onChange`, `onExit`, `onEnter`, `onBack`, `onTick`, `onBeforeEnter`); `w.menu.fireEvent` triggers those event names with `(currentData, ...)` before calling the function field. `PriceClass` / `PriceGroupClass` are metatable objects; when you send a price to the server or through an export, send `price:getCosts()` (a plain array), not the object.

**Where the menu is drawn.** The menu module sends its messages with `SendNUIMessage` from the consumer resource, so they land in the consumer's `ui_page` frame. `w.nui.load` (called at startup by the menu module) is a no-op, and the old page `nui://w_lib/nui/menu/index.html` is not in w_lib's `files` list, so nothing is mounted for you. A resource with no `ui_page` shows no menu at all (w_baloot's manifest comment records exactly this failure). w_lib's own default page `nui://w_lib/web/build/index.html` does not contain the menu message handlers (`updateMenu`, `setCurrentMenu`, `updatePreview`, ...); the page in w_lib's files that does is `nui://w_lib/html/dist/index.html`. Which page a consumer should declare could not be confirmed from a working sibling (w_gunsmith declares its own `web/build` and that bundle does not contain the menu handlers either), so treat "declare a `ui_page` that implements the w_menu protocol" as the rule and verify on your server. The NUI callbacks (`click`, `backMenu`, `missingMenu`, `onBeforeEnter`, `updatePreview`, `messageReceived`) are registered in your resource, so the page must post to the resource that declares the `ui_page`.

**Component (clothing) is the opposite.** `modules/component/shared.lua` is a three-line bridge that, in any resource other than w_lib, sets `w.component = exports.w_lib:w_component_get()`. The full API (data tables from `g_shared.lua` and the ped functions from `g_client.lua`) executes inside w_lib; every `w.component.<fn>(...)` call is a cross-resource export call. Consequences:

- Arguments and return values are copied, never references.
- `w.component.data.*` tables are a snapshot taken when the bridge ran.
- `w.cache.component` (w_lib's per-ped cache of tints and wearable states, filled on the first `apply()` for a ped and cleared after the delayed reapply) lives only inside w_lib and is `nil` in your VM.
- Functions cannot be passed as arguments (no component function takes one anyway).

Wearable states are remembered per ped in the entity state bag under `wearableState:<category>` only when set through w_lib (`setWearableState`, or `apply()` with `data.wearableState`); the branch in `apply()` that was meant to save a pre-existing state references an undefined variable and never fires. After every `apply()` / `setWearableState`, w_lib schedules a delayed refresh that reapplies all cached tints and saved non-base states; call `w.component.refreshPed(ped)` to flush it now. `g_shared.lua` is loaded on both sides of w_lib, so the data tables and name builders are reachable from a server script too, but the `*FromSkinTone` / `*FromIndex` builders call `IsPedMale` when given a numeric ped and therefore only work server-side with a model name string.

**Menu lifecycle and ordering rules.**

1. `w.menu.create(id, data)` builds the Lua object only (`data` must be a table).
2. `addItem` fills it.
3. `send()` (or `w.menu.send(id)`) pushes it to the NUI.
4. `setCurrentMenu(id)` / `menu:use()` makes it the active one.
5. `w.menu.show(true)` displays it.

Calling `send()` twice turns into `refresh()`. Changes made with `updateValue` / `deleteValue` / `deleteItem` are queued and only reach the screen after `push()`; `refresh()` resends the whole menu instead; the deprecated `updateItem` / `removeItem` only touch the Lua object and need `refresh()`. Child navigation is declared with `item.child = "<otherMenuId>"`; if that id has never been created, the NUI asks Lua for it and `w.menu.missingMenuHandler(id, fn)` can build it on demand.

Event order on navigation: leaving a menu fires the old item's `onExit` then the old menu's `onExit`, then the new menu's `onEnter` and the new item's `onActive`; moving inside a menu fires old item `onExit`, new item `onActive`, then the menu's `onChange`; moving a slider fires item `onChange` then menu `onChange`; then every `w.menu.onChange` listener runs. Handlers receive `currentData = { menu = id, index = n, item = <item table> }`; on slider changes each `item.sliders[i]` carries `.current`, a computed `.value` and a `.changed` flag. Handler errors are caught and printed, but a handler that blocks longer than 10 s trips a watchdog that releases the dispatch lock. `item.bufferOnChange = false` (or any grid slider) makes the dispatcher poll every frame instead of every 10 ms while a previous handler is still running; events still pass through `w.timeout.noSpam`, so very fast bursts can be coalesced. While open, the weapon wheel, pause and cancel controls are disabled and the minimap is hidden; `distanceToClose` closes the menu when the player walks away from where it was opened. `w.menu.show` flips the open flag inside a new thread, so `w.menu.isOpen()` only becomes true on the next frame (w_gunsmith waits for it in a loop). Item prices are not rewritten at `addItem` time (the formatted value is discarded); only a loader is shown while the inventory item list is fetched for array-form prices with `.item` entries. `menu:updateValue(..., "price", v)` does format the value.

**Pricing** is the shared vocabulary for "what something costs". Every input is normalised to a canonical cost array: `{ { money = 5 }, { gold = 1 }, { rol = 2 }, { item = "bread", quantity = 2, keep = false, ...item data } }`. One currency per cost entry; currencies are merged by type; item costs are merged when name and keep flag match; item costs are enriched with every field of the framework's inventory record (label, image, ...) that is not already set. An unknown item name prints an error and gets label `"Not exist"`, and the first item lookup may fetch the item list (it can yield). `w.pricing.new` gives a `PriceClass` (a single price, possibly several costs that are all required); `w.pricing.newGroup` gives a `PriceGroupClass` (several `PriceClass` alternatives joined by `operator = "or"` (default) or `"and"`). A flat `{ money = 5, gold = 1 }` given to `newGroup` becomes two alternatives, whereas given to `new` it becomes one price with two costs; this is the most common mistake.

**Version checker** is server-only and meant for Jump On Studios packages. It reads `version`, `package_id` and `dependencies_version_min` from your fxmanifest, runs automatically (`w.ready(w.versionChecker.checkUpdate)` at the end of the module file) when the module is listed in `w_module`, and stops your resource, through w_lib's internal, local-only server event `w_lib:kill:resource`, if a declared dependency is running but too old. Without both `version` and `package_id` the whole check, dependencies included, is skipped.

### w.menu.create

```lua
w.menu.create(id: string, data: table): MenuClass
```

Side: client

Parameters:

- `id` (string, required): unique menu id. Creating an id that already exists replaces the old menu; if that menu is currently open, `onExit` is fired on the current menu and item first.
- `data` (table, required): menu configuration. Must be a table (the code reads `data.tick` before merging, so `nil` raises an error); pass `{}` for defaults. Extra keys are kept on the object and sent to the NUI (functions stripped).
  - `type` (string, optional, default `"list"`): `"list"` or `"tile"` layout.
  - `title` (string, optional, default `"Jump On"`): big title shown by the NUI.
  - `subtitle` (string, optional, default `""`): subtitle line.
  - `numberOnScreen` (integer, optional, default 8, capped at 13): list menus, items visible before scrolling.
  - `numberOnLine` (integer, optional, NUI default 4): tile menus, items per row.
  - `numberLineOnScreen` (integer, optional, NUI default 6): tile menus, rows visible.
  - `distanceToClose` (number or false, optional, default false): metres from the position where `show(true)` was called; beyond it the menu auto-closes.
  - `displayBackButton` (boolean, optional, default false): show the back button in the NUI.
  - `currentIndex` (integer, optional, default 1): item selected when the menu is first used (w_gunsmith passes a saved index).
  - `price` / `priceTitle` (table / string, optional): a menu-level price and label read by the menu NUI page (`cMenu.price`, `cMenu.priceTitle`); not touched by Lua.
  - `onBeforeEnter` (function, optional): fired by the NUI just before the menu becomes visible (only a boolean flag is sent to the NUI; the function stays in Lua).
  - `onEnter` (function, optional): fired when the menu becomes the current one; receives `currentData`.
  - `onBack` (function, optional): fired when back/escape is pressed on this menu.
  - `onExit` (function, optional): fired when leaving the menu or when the menu closes.
  - `onChange` (function, optional): fired on every scroll/slider change inside the menu.
  - `onTick` (function, optional, alias `tick`): fired every frame while this menu is open; errors are reported once per open.
  - `<event>ClientEvent` / `<event>ServerEvent` (string, optional): event names triggered in addition to the function for the same event (for example `onEnterClientEvent`).

Returns: `MenuClass` table (also stored internally under `id`). Returns the string `"The `id` of the menu is missing"` when `id` is nil.

Builds the Lua-side menu object. Nothing is shown until you `addItem()`, `send()`, `setCurrentMenu()` / `use()` and `w.menu.show(true)`. The object is a merged copy of the `MenuClass` defaults with your data.

```lua
local menu = w.menu.create("shop_root", {
  title = "General Store",
  subtitle = "Choose a section",
  numberOnScreen = 12,
  displayBackButton = true,
  onEnter = function(data) print("entered", data.menu) end,
  onBack = function() w.menu.show(false) end,
})
```

### w.menu.createIfNotExist

```lua
w.menu.createIfNotExist(id: string, data: table): MenuClass, boolean
```

Side: client

Parameters:

- `id` (string, required): menu id.
- `data` (table, required): same configuration table as `w.menu.create`; only used when the menu does not exist yet.

Returns: the existing or newly created `MenuClass`, and `true` when it was created (`false` when it already existed).

Returns `w.menu.get(id)` when the id is registered, otherwise calls `w.menu.create`.

```lua
local menu, created = w.menu.createIfNotExist("shop_root", { title = "Store" })
if created then menu:addItem({ title = "Buy" }) end
```

### MenuClass:addItem

```lua
menu:addItem(index: integer|table, item?: table): MenuItem
```

Side: client

Parameters:

- `index` (integer or table, required): insert position (1-based). When called with a single table argument, that table is the item and it is appended at `#items + 1`.
- `item` (table, optional): item definition, merged over the `MenuItem` defaults. Every field is sent to the NUI except functions.
  - `title` (string, default `""`): label.
  - `subtitle` (string, default `""`): second line.
  - `footer` (string, default `""`): footer text.
  - `description` (string, default `""`): description panel text.
  - `child` (string or false, default false): id of the menu opened when Enter is pressed.
  - `visible` (boolean, default true): hidden items are skipped by the NUI.
  - `disabled` (boolean, default false): greyed out, cannot be clicked.
  - `data` (table, default `{}`): free storage, returned back to you in `currentData.item.data`.
  - `prefix` (string or false, default false): small icon before the title (icon file name).
  - `icon` (string, optional): left icon file name or full image URL.
  - `iconRight` (string, optional): right icon file name.
  - `iconClass` (string, optional): CSS class applied to the icon.
  - `color` (string, optional): row colour keyword read by the NUI; w_gunsmith uses `"red"` and `"green"`.
  - `textRight` (string or false, default false): text shown at the right of the row.
  - `price` (table, number or false, default false): item price, sent to the NUI exactly as you pass it (Lua does not rewrite it here); annotations document `price.money`, `price.gold` and `0` for "Free"; cost arrays from `w.pricing` are accepted by `menu:updateValue`.
  - `priceTitle` (string, optional): replaces the "Price" label.
  - `priceRight` (boolean, optional): show the price at the right of the title.
  - `previewPalette` (boolean, default true): show a colour square when a palette slider exists.
  - `statistics` (table, default `{}`): array of statistic rows for the NUI (`{ label, type, class, value }` per the annotations; not read by Lua).
  - `sliders` (table, default `{}`): array of slider definitions, see `MenuItem.sliders`.
  - `bufferOnChange` (boolean, default true): `false` makes slider changes dispatch every frame instead of every 10 ms while a handler is busy.
  - `tick` (function, optional): alias for `onTick`.
  - `onActive` (function): fired when the item becomes selected, receives `currentData`.
  - `onClick` (function): fired when Enter is pressed on the item.
  - `onChange` (function): fired when one of the item's sliders changes.
  - `onExit` (function): fired when the selection leaves the item.
  - `onTick` (function): fired every frame while the item is selected.
  - `<event>ClientEvent` / `<event>ServerEvent` (string): event names triggered with `(currentData, ...)` for the same events; use these instead of functions whenever the item table crosses an export boundary.

Returns: the stored `MenuItem` table (with `.index` set and a `getParentMenu()` method).

Adds an item to the menu object. Inserting in the middle renumbers the following items' `.index`. Slider `.value` fields are computed at insert time (a grid slider needs `values[1].current` or the call errors). If `price` is an array of costs containing an `.item` entry and the inventory item list is not loaded yet, the NUI loader is shown while it loads; the price itself is not modified. The change is not visible until `send()` / `refresh()`.

```lua
local menu = w.menu.get("shop_root")
menu:addItem({
  title = "Bread",
  price = { money = 2 },
  textRight = "x3",
  onClick = function(data)
    TriggerServerEvent("myshop:buy", data.item.title)
  end,
})
menu:addItem({ title = "Clothes", child = "shop_clothes" })
```

### MenuItem.sliders

```lua
item.sliders = { { type = "slider"|"switch"|"grid"|"palette", ... }, ... }
```

Side: client

Not confirmed from source; treat as best effort.

Parameters:

- `slider` (table, required): one entry per slider on the item. Fields read by Lua (`updateSliderCurrentValue`) and by the menu NUI page.
  - `type` (string, default `"slider"`): `"slider"` (value list under the item), `"switch"` (value list changed with the row's left/right arrows), `"grid"` (1 or 2 axis pad), `"palette"` (colour tint picker); the NUI also knows `"sprite"` and `"color"` whose fields were not confirmed.
  - `title` (string, optional): heading shown above the slider.
  - `description` (string, optional): text under the slider.
  - `values` (array, slider/switch): the choices; each entry is a table such as `{ label = "Small", price = { money = 5 } }` (a `values[i].price` overrides the item price while selected); after a change Lua sets `slider.value = values[current]`.
  - `current` (integer, default 1): 1-based index of the selected value (for palette: the tint index between `min` and `max`).
  - `looped` (boolean): wrap around at the ends (read by the NUI).
  - `forceDisplay` (boolean): show the slider even when `values` has a single entry (read by the NUI).
  - `translate` (boolean): translate labels through the NUI language table (read by the NUI).
  - `values` for grid (array of 1 or 2 tables): each axis needs a `.current`; Lua sets `slider.value = { x, y }` rounded to 3 decimals; min/max/gap per axis could not be confirmed in the NUI source.
  - `labels` (array of strings, grid): axis labels (read by the NUI).
  - `palette` (string, palette type; alias `tint`): palette name from `w.component.data.palettes`, for example `"metaped_tint_hair"`.
  - `min` / `max` (integer, palette): first and last selectable tint index (read by the NUI).
  - `disabledTints` (array of integers, palette): tint indexes that are skipped (read by the NUI).
  - `changed` (boolean, set by the library): `true` in `onChange` when this slider's `current` differs from the previous event.

Returns: n/a

Sliders are edited by the NUI; each change is sent back to Lua, merged into the item and delivered through the item's `onChange` then the menu's `onChange`. Read the result from `currentData.item.sliders[i].current` / `.value`.

```lua
menu:addItem({
  title = "Hair colour",
  sliders = {
    { type = "switch", title = "Style", values = { { label = "Short" }, { label = "Long" } }, current = 1 },
    { type = "palette", palette = "metaped_tint_hair", current = 3, min = 0, max = 63 },
  },
  bufferOnChange = false,
  onChange = function(data)
    local style = data.item.sliders[1].value.label
    local tint = data.item.sliders[2].value
    print(style, tint)
  end,
})
```

### MenuItem.onClickClientEvent / onClickServerEvent

```lua
item.<event>ClientEvent = "eventName" ; item.<event>ServerEvent = "eventName"
```

Side: client

Parameters:

- `<event>ClientEvent` (string, optional): client event name triggered with `(currentData, ...)` for `onActive`, `onClick`, `onChange`, `onExit`, `onTick` (items) or `onEnter`, `onBack`, `onExit`, `onChange`, `onTick`, `onBeforeEnter` (menus).
- `<event>ServerEvent` (string, optional): server event name triggered with `TriggerServerEvent(name, currentData, ...)`.

Returns: n/a

String-based handlers. Required whenever the item or menu table is built in another resource and passed through an export (functions cannot cross the export boundary); register the handler with `RegisterNetEvent` / `AddEventHandler`.

```lua
RegisterNetEvent("myshop:buyClicked", function(data) print(data.item.title) end)
menu:addItem({ title = "Bread", onClickClientEvent = "myshop:buyClicked", onClickServerEvent = "myshop:sv:buy" })
```

### MenuClass:send

```lua
menu:send()
```

Side: client

Parameters: none.

Returns: nothing.

Sends the menu (items included, functions stripped) to the NUI. The first call registers it; later calls behave like `refresh()`. Must be called for the root and for every child menu before they can be displayed (w_gunsmith sends the root then every child, then `setCurrentMenu`, then `show`).

```lua
w.menu.send("shop_root")
w.menu.send("shop_clothes")
w.menu.setCurrentMenu("shop_root")
w.menu.show(true)
```

### w.menu.setCurrentMenu

```lua
w.menu.setCurrentMenu(id: string, keepHistoric?: boolean, resetMenu?: boolean)
```

Side: client

Parameters:

- `id` (string, required): menu id; if unknown, the `missingMenuHandler` for that id is run (or an error is printed).
- `keepHistoric` (boolean, optional, default true): keep the back-navigation history; `false` also clears the previous-state snapshot.
- `resetMenu` (boolean, optional, default true): reset the selection before displaying.

Returns: nothing.

Makes the menu the active one in the NUI. The NUI then reports the change back and the library fires `onEnter` / `onActive`.

```lua
w.menu.setCurrentMenu("shop_root")
w.menu.show(true)
```

### MenuClass:use

```lua
menu:use(keepHistoric?: boolean, resetMenu?: boolean)
```

Side: client

Parameters:

- `keepHistoric` (boolean, optional, default true): keep the navigation history (back button returns to the previous menu).
- `resetMenu` (boolean, optional, default true): reset the selection before displaying.

Returns: nothing.

Shortcut for `w.menu.setCurrentMenu(menu.id, keepHistoric, resetMenu)`.

```lua
menu:use(false)   -- make it current and forget the history
```

### w.menu.show

```lua
w.menu.show(show: boolean, keepInput?: boolean, hideRadar?: boolean, playMenuAnimation?: boolean, hideCursor?: boolean)
```

Side: client

Parameters:

- `show` (boolean, required): `true` to display, `false` to hide; a call that does not change the state is ignored.
- `keepInput` (boolean, optional, default true): `SetNuiFocusKeepInput` while shown (the player can still move).
- `hideRadar` (boolean, optional, default true): accepted but unused; the code always sets the minimap type to 0 while shown and restores it on hide.
- `playMenuAnimation` (boolean, optional, default true): play the open/close animation.
- `hideCursor` (boolean, optional, default false): hide the mouse cursor (NUI focus without cursor).

Returns: nothing.

Shows or hides the menu layer (the work runs in a new thread). On show: takes NUI focus, hides the minimap, starts the per-frame loop that disables weapon-wheel/pause/cancel controls, evaluates `distanceToClose` and fires `onTick` handlers. On hide: the loop fires `onExit` on the current menu and item, clears the current/previous state, and NUI focus is released after a 150 ms delay (restoring the previous keep-input setting). Hide is also what `onBack` handlers call to close the root menu.

```lua
w.menu.setCurrentMenu("shop_root")
w.menu.show(true)
-- later, from an onClick or onBack:
w.menu.show(false)
```

### w.menu.isOpen

```lua
w.menu.isOpen(): boolean
```

Side: client

Parameters: none.

Returns: `true` while a menu of this resource is shown.

Reflects the last `w.menu.show()` call, but the flag is set inside a thread, so it changes on the frame after the call, not synchronously. Sibling resources poll it to detect that the player closed the menu (ESC, back, `distanceToClose`, death) and then clean up.

```lua
CreateThread(function()
  local guard = 0
  while not w.menu.isOpen() and guard < 100 do guard = guard + 1; Wait(10) end
  while w.menu.isOpen() do Wait(100) end
  cleanupCamera()
end)
```

### w.menu.addItem

```lua
w.menu.addItem(id: string, p: integer|table, item?: table)
```

Side: client

Parameters:

- `id` (string, required): menu id (must exist, otherwise indexing nil errors).
- `p` (integer or table, required): position, or the item table when used as the only item argument.
- `item` (table, optional): item table, same fields as `MenuClass:addItem`.

Returns: nothing (the wrapper discards the item).

Convenience wrapper: `menus[id]:addItem(p, item)`. This is the idiom used by w_gunsmith.

```lua
w.menu.addItem("shop_root", { title = "Save", color = "green", onClick = function() w.menu.show(false) end })
```

### w.menu by-id wrappers (send, refresh, reset, sort, updateItem, addItems)

```lua
w.menu.send(id) ; w.menu.refresh(id) ; w.menu.reset(id) ; w.menu.sort(id, first?, last?) ; w.menu.updateItem(id, index, key, value) ; w.menu.addItems(id, items)
```

Side: client

Parameters:

- `id` (string, required): menu id; an unknown id errors (indexing nil).
- `...` (any, optional): same arguments as the `MenuClass` method of the same name.

Returns: nothing.

Each wrapper calls the method of the same name on `menus[id]`. `updateItem` and `addItems` are deprecated like their methods.

```lua
w.menu.updateItem("shop_root", 1, "title", "Sold out")
w.menu.refresh("shop_root")
```

### MenuClass:updateValue

```lua
menu:updateValue(keys: string|table, value: any): boolean
```

Side: client

Parameters:

- `keys` (string or table, required): property name or path array from the menu root, for example `{ "items", 2, "textRight" }`.
- `value` (any, required): new value (copied). When the last key is `"price"`, or `"priceRight"` with a non-boolean, the value is passed through `w.menu.formatPrice` first.

Returns: `true`.

Applies the change to the Lua object and queues it; nothing is sent until `menu:push()`. Preferred replacement for `updateItem`.

```lua
menu:updateValue({ "items", 3, "disabled" }, true)
menu:updateValue("subtitle", "Total: $12")
menu:push()
```

### MenuClass:deleteValue

```lua
menu:deleteValue(keys: string|table)
```

Side: client

Parameters:

- `keys` (string or table, required): property path. A two-element path `{ "items", index }` is redirected to `deleteItem(index)`.

Returns: nothing.

Removes a nested value from the menu object and queues the deletion for `push()`.

```lua
menu:deleteValue({ "items", 2, "textRight" })
menu:push()
```

### MenuClass:deleteItem

```lua
menu:deleteItem(index: integer)
```

Side: client

Parameters:

- `index` (integer, required): index of the item to remove.

Returns: nothing.

Removes the item, renumbers following items and queues the updates; if the menu is current and the removed item was selected, a `currentIndex` update is queued too. Requires `push()`.

```lua
menu:deleteItem(4)
menu:push()
```

### MenuClass:push

```lua
menu:push()
```

Side: client

Parameters: none.

Returns: nothing.

Sends every queued `updateValue` / `deleteValue` / `deleteItem` change to the NUI in one message and clears the queue. Does nothing when the queue is empty. If the menu is current and the selection index is past the end, it is clamped and pushed too.

```lua
menu:updateValue({ "items", 1, "title" }, "Bread (x2)")
menu:push()
```

### MenuClass:refresh

```lua
menu:refresh()
```

Side: client

Parameters: none.

Returns: nothing.

Resends the whole menu definition to the NUI without changing the selection (`currentIndex` is stripped from the payload; if it now exceeds `#items` it is clamped with `setCurrentIndex`). If this menu is current, the item events are re-run (`onExit` / `onActive` of the selected item).

```lua
w.menu.updateItem("shop_root", 1, "title", "Sold out")
w.menu.refresh("shop_root")
```

### MenuClass:setCurrentIndex

```lua
menu:setCurrentIndex(index: integer)
```

Side: client

Parameters:

- `index` (integer, required): 1-based item index to select.

Returns: nothing.

Moves the selection in both Lua and the NUI immediately (no `push` needed).

```lua
menu:setCurrentIndex(3)
```

### MenuClass:reset

```lua
menu:reset()
```

Side: client

Parameters: none.

Returns: nothing.

Tells the NUI to reset the menu state, moving the cursor back to the first item. Lua's `currentIndex` is not changed.

```lua
w.menu.reset("shop_root")
```

### MenuClass:sort

```lua
menu:sort(first?: integer, last?: integer)
```

Side: client

Parameters:

- `first` (integer, optional, default 1): first position to sort.
- `last` (integer, optional, default `#items`): last position to sort.

Returns: nothing.

Sorts items alphabetically by title (`string.compare`) within the range and renumbers `.index`. Only when a partial range is given does it keep `currentIndex` on the same item (and it leaves an `isCurrentIndex = true` flag on that item because of a typo in the cleanup); a full-range sort does not track the selection. Call `refresh()` or `send()` afterwards.

```lua
menu:sort(2)      -- keep item 1 ("Back") in place, sort the rest
menu:refresh()
```

### MenuClass:updateItem (deprecated)

```lua
menu:updateItem(index: integer, key: string, value: any)  -- deprecated
```

Side: client

Parameters:

- `index` (integer, required): item index.
- `key` (string, required): property name.
- `value` (any, required): new value, written directly to `items[index][key]`.

Returns: nothing.

Deprecated since 2.3.0 but still used by w_gunsmith. Writes the Lua object only; call `refresh()` (`w.menu.refresh(id)`) afterwards to show it.

```lua
w.menu.updateItem("shop_root", 1, "title", "None (selected)")
w.menu.refresh("shop_root")
```

### MenuClass:removeItem (deprecated)

```lua
menu:removeItem(index: integer)  -- deprecated
```

Side: client

Parameters:

- `index` (integer, required): item index; `nil` prints an error.

Returns: nothing.

Deprecated since 2.4.0: removes the item from the Lua object and renumbers, but queues nothing, so you must `refresh()`. Use `deleteItem` + `push` instead.

```lua
menu:removeItem(2)
menu:refresh()
```

### MenuClass:addItems (deprecated)

```lua
menu:addItems(items: table)  -- deprecated
```

Side: client

Parameters:

- `items` (table, required): array of item tables.

Returns: nothing.

Deprecated since 2.4.0; prints a memory-leak warning and calls `addItem` for each entry. Use `addItem` in a loop.

```lua
for _, def in ipairs(defs) do menu:addItem(def) end  -- preferred over menu:addItems(defs)
```

### MenuItem methods (updateValue, deleteValue, getParentMenu)

```lua
item:updateValue(keys: string|table, value: any)
item:deleteValue(keys: string|table)
item:getParentMenu(): MenuClass
```

Side: client

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `item:updateValue(keys, value)` | `keys` (string or table, required): property name or path relative to the item, for example `"title"` or `{ "sliders", 1, "current" }`; `value` (any, required) | nothing | Prefixes `{ "items", item.index }` and calls the parent menu's `updateValue`; requires `menu:push()`. If the selected item did not change, the previous-state snapshot is refreshed so the next event does not report a false change. Only works on an item returned by `addItem` (a bare item table has no parent menu). |
| `item:deleteValue(keys)` | `keys` (string or table, required): property path relative to the item | nothing | Prefixes the item path and calls the parent menu's `deleteValue`; requires `push()`. |
| `item:getParentMenu()` | none | the `MenuClass` the item was added to (an empty table for an item that was never added) | Set by `addItem`; lets a handler reach its menu without knowing the id. |

```lua
local item = w.menu.getCurrentItem()
item:updateValue("textRight", "$5")
item:deleteValue("description")
item:getParentMenu():push()
```

### w.menu.delete

```lua
w.menu.delete(id: string)
```

Side: client

Parameters:

- `id` (string, required): menu id.

Returns: nothing.

Removes the menu from the Lua registry and tells the NUI to drop it. Safe to call for an unknown id. w_gunsmith deletes all its menus before rebuilding them.

```lua
if w.menu.isExist("shop_root") then w.menu.delete("shop_root") end
```

### w.menu.isExist

```lua
w.menu.isExist(id: string): boolean
```

Side: client

Parameters:

- `id` (string, required): menu id.

Returns: `true` when the id is registered in this resource.

Registry check; menus of other resources are not visible.

```lua
if not w.menu.isExist("shop_root") then buildShop() end
```

### w.menu.get / w.menu.set

```lua
w.menu.get(id: string): MenuClass|nil
w.menu.set(id: string, menu: MenuClass)
```

Side: client

Parameters:

- `id` (string, required): menu id.
- `menu` (MenuClass, required for `set`): menu object to store under that id.

Returns: `get` returns the `MenuClass` or `nil`; `set` returns nothing.

`get` returns the registered menu object so you can call its methods. `set` replaces the registry entry directly (no NUI message).

```lua
local menu = w.menu.get("shop_root")
if menu then menu:setCurrentIndex(1) end
w.menu.set("shop_root", savedMenu)
```

### Current-state queries (getCurrentData, getPreviousData, getCurrentItem, getCurrentMenu, getCurrentIndex, getCurrentMenuId, isCurrentMenu, doesActiveButtonChange)

```lua
w.menu.getCurrentData(): table
w.menu.getPreviousData(): table
w.menu.getCurrentItem(): table|nil
w.menu.getCurrentMenu(): MenuClass|nil
w.menu.getCurrentIndex(): integer
w.menu.getCurrentMenuId(): string
w.menu.isCurrentMenu(id: string): boolean
w.menu.doesActiveButtonChange(): boolean
```

Side: client

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| `w.menu.getCurrentData()` | none | `{ menu = string, index = integer, item = table }` (empty table when nothing is open) | The same table passed as first argument to every handler. `item` is the live item table (sliders carry `.current` / `.value` / `.changed`). |
| `w.menu.getPreviousData()` | none | the snapshot of `currentData` from the previous NUI event | Useful inside `onChange` to compare with the previous item/slider state. |
| `w.menu.getCurrentItem()` | none | `currentData.item` | The selected item table of the current menu. |
| `w.menu.getCurrentMenu()` | none | the current `MenuClass`, `nil` when none | Registry lookup of `currentData.menu`. |
| `w.menu.getCurrentIndex()` | none | `currentIndex` of the current menu | Errors if no menu is current (indexes nil); guard with `isOpen()`. |
| `w.menu.getCurrentMenuId()` | none | id of the current menu | Errors when no menu is current. |
| `w.menu.isCurrentMenu(id)` | `id` (string, required): menu id | `true` when a menu is open and its id matches | Returns `false` when no menu is open. |
| `w.menu.doesActiveButtonChange()` | none | `true` when the current menu id or index differs from the previous snapshot | Distinguishes a selection move from a slider change inside `onChange` handlers. |

```lua
local data = w.menu.getCurrentData()
print(data.menu, data.index, data.item and data.item.title)

local prev = w.menu.getPreviousData()
if prev.index ~= w.menu.getCurrentIndex() then print("moved") end

if not w.menu.doesActiveButtonChange() then applySliderPreview() end
if w.menu.isCurrentMenu("shop_root") then w.menu.refresh("shop_root") end
```

### w.menu.missingMenuHandler

```lua
w.menu.missingMenuHandler(id: string, callback: function)
```

Side: client

Parameters:

- `id` (string, required): menu id that may be requested before it exists.
- `callback` (function, required): run in a new thread when the NUI or `setCurrentMenu` asks for a missing id; it should create and send the menu.

Returns: nothing.

Lets a child menu be built lazily when an item with `child = id` is entered.

```lua
w.menu.missingMenuHandler("shop_clothes", function()
  local m = w.menu.create("shop_clothes", { title = "Clothes" })
  m:addItem({ title = "Hat" })
  m:send()
end)
```

### w.menu.onChange / w.menu.listeners

```lua
w.menu.onChange(cb: function)
w.menu.listeners: { { resource = string, cb = function }, ... }
```

Side: client

Parameters:

- `cb` (function, required): called with the current `{ menu, index, item }` after every NUI change (selection or slider) once the menu/item handlers ran; errors are printed with the registering resource name.

Returns: nothing.

Global listener stored in `w.menu.listeners` with the invoking resource; listeners are removed automatically when that resource stops. `w.menu.listeners` is the array of registered listeners, exposed for inspection.

```lua
w.menu.onChange(function(data)
  print("menu", data.menu, "item", data.index)
end)
print(#w.menu.listeners)
```

### w.menu.fireEvent / w.menu.fireAllLevelsEvent

```lua
w.menu.fireEvent(item: table, eventName: string, ...: any)
w.menu.fireAllLevelsEvent(eventName: string, ...: any)
```

Side: client

Parameters:

- `item` (table, required, `fireEvent` only): a menu or item table; `nil` is ignored.
- `eventName` (string, required): handler key, for example `"onClick"`.
- `...` (any, optional): extra arguments appended after `currentData`.

Returns: nothing.

`fireEvent` is the dispatch used by the library itself: if `item[eventName .. "ClientEvent"]` is set, `TriggerEvent(thatName, currentData, ...)`; if `item[eventName .. "ServerEvent"]` is set, `TriggerServerEvent(thatName, currentData, ...)`; then `item[eventName](currentData, ...)` if it is set. This is the mechanism that lets handlers be event names instead of functions. `fireAllLevelsEvent` calls `fireEvent` on the current menu, then on the current item.

```lua
w.menu.fireEvent(w.menu.getCurrentItem(), "onClick")
w.menu.fireAllLevelsEvent("onExit")
```

### w.menu.runRefreshEvents

```lua
w.menu.runRefreshEvents(menuEvent?: boolean, itemEvent?: boolean)
```

Side: client

Parameters:

- `menuEvent` (boolean, optional, default false): force the menu `onExit` / `onEnter` pair.
- `itemEvent` (boolean, optional, default false): force the item `onExit` / `onActive` pair.

Returns: nothing.

Re-runs the event dispatch for the current menu and index as if the NUI had reported it; `refresh()` calls it with `itemEvent = true`. Errors when no menu is current.

```lua
w.menu.runRefreshEvents(false, true)
```

### w.menu.forceBack

```lua
w.menu.forceBack()
```

Side: client

Parameters: none.

Returns: nothing.

Asks the NUI to navigate back as if the back key was pressed (fires `onBack` of the current menu through the NUI callback).

```lua
w.menu.forceBack()
```

### w.menu.softHide / w.menu.isSoftHidden

```lua
w.menu.softHide(cb: function, playMenuAnimation?: boolean, keepBackground?: boolean)
w.menu.isSoftHidden(): boolean
```

Side: client

Parameters:

- `cb` (function, required): synchronous action run while the menu is hidden (may `Wait`); nothing happens when `nil`.
- `playMenuAnimation` (boolean, optional, default true): animate hide/show.
- `keepBackground` (boolean, optional, default false): keep the menu background panel visible while hidden.

Returns: `softHide` returns nothing; `isSoftHidden` returns `true` while a `softHide` callback is running.

Temporarily hides the menu and releases NUI focus, runs `cb`, then restores focus and shows the menu again.

```lua
w.menu.softHide(function()
  playCutsceneCamera()
  Wait(2000)
end)
if w.menu.isSoftHidden() then return end
```

### w.menu.displayLoader / w.menu.hideLoader

```lua
w.menu.displayLoader(value?: boolean)
w.menu.hideLoader()
```

Side: client

Parameters:

- `value` (boolean, optional, default true): `true` to show, `false` to hide.

Returns: nothing.

Shows or hides the NUI loading indicator over the menu. `hideLoader()` is `displayLoader(false)`.

```lua
w.menu.displayLoader()
local stock = w.callback.triggerServer("myshop:getStock")
w.menu.hideLoader()
```

### w.menu.updateLang

```lua
w.menu.updateLang(lang: table)
```

Side: client

Parameters:

- `lang` (table, required): translated NUI strings.
  - `of` (string, optional, default `"%1 of %2"`): bottom-right item counter.
  - `selection` (string, optional, default `"Selection"`).
  - `devise` (string, optional, default `"$"`): currency symbol.
  - `number` (string, optional, default `"Number %1"`).
  - `free` (string, optional, default `"Free"`).
  - `variation` (string, optional, default `"Variation"`).

Returns: nothing.

Sends replacement labels to the menu NUI.

```lua
w.menu.updateLang({ of = "%1 / %2", free = "Gratis", devise = "$" })
```

### w.menu.updateVolume / w.menu.playAudio

```lua
w.menu.updateVolume(volume: number)
w.menu.playAudio(sound: string)
```

Side: client

Parameters:

- `volume` (number, required): 0.0 to 1.0.
- `sound` (string, required): file name without extension from the NUI sounds folder: `"button"`, `"coins"`, `"menu_close"`, `"menu_open"`, `"selected"`.

Returns: nothing.

`updateVolume` sets the volume of the menu sound effects; `playAudio` plays one of the menu NUI sounds at the menu volume.

```lua
w.menu.updateVolume(0.3)
w.menu.playAudio("coins")
```

### Menu price helpers (formatPrice, formatPrices, isPriceFree, mergePrices, tax)

```lua
w.menu.formatPrice(price: PriceInput): Cost[]
w.menu.formatPrices(prices: PriceGroupInput|PriceInput|nil): table
w.menu.isPriceFree(price: PriceInput): boolean
w.menu.mergePrices(...: PriceInput): Cost[]
w.menu.tax(price: PriceInput, percentage?: number, roundUpItems?: boolean): Cost[]
```

Side: shared

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| `w.menu.formatPrice(price)` | `price` (number, table, PriceClass or nil, optional): any `w.pricing.new` input; `nil` is treated as 0 | canonical cost array with inventory item data merged into item costs | `w.framework:addItemDataToPrice(w.pricing.new(price):getCosts())`. Used by `menu:updateValue` for `"price"` keys. |
| `w.menu.formatPrices(prices)` | `prices` (table, number or nil, optional): a price group (a `PriceGroupClass`, or a table with `.prices` or `.operator`) or any single-price input | `{ operator = "and"|"or", [1] = Cost[], [2] = Cost[], ... }` | Normalises a group of alternative/combined prices for the NUI; a single price (or nil, or a number) becomes `{ operator = "and", costs }`. |
| `w.menu.isPriceFree(price)` | `price` (any, optional) | `true` when the formatted group has exactly one entry and that entry is free | Wrapper over `formatPrices` + `PriceClass:isFree`. |
| `w.menu.mergePrices(...)` | any number of price inputs (required) | one canonical cost array with all inputs added together | Builds an "and" group from the arguments and compacts it into one `PriceClass`. |
| `w.menu.tax(price, percentage, roundUpItems)` | `price` (PriceInput, required); `percentage` (number, optional, default 0): multiplier for the tax part (0.1 = 10 %); `roundUpItems` (boolean, optional, default false): round item quantities up instead of down | the tax part only, as a cost array | Calls `w.pricing.tax` and returns the first result's costs. |

```lua
local costs = w.menu.formatPrice({ money = 5, item = "bread", quantity = 2 })
local g = w.menu.formatPrices({ operator = "or", { money = 10 }, { gold = 1 } })
if w.menu.isPriceFree(item.price) then print("free") end
local total = w.menu.mergePrices({ money = 5 }, { money = 3, gold = 1 })  -- money 8, gold 1
local taxCosts = w.menu.tax({ money = 100 }, 0.15)  -- { { money = 15 } }
```

### exports.<resource>:w_menu_get / w_menu_get_current_data

```lua
exports.<resource>:w_menu_get(): table
exports.<resource>:w_menu_get_current_data(): table
```

Side: client

Parameters: none.

Returns: `w_menu_get` returns the `w.menu` table of the resource that registered the export; `w_menu_get_current_data` returns that resource's `currentData` `{ menu, index, item }` as copied through the export boundary.

Registered by every resource that loads the menu module, under that resource's name. w_lib's manifest does not list the menu module, so `exports.w_lib:w_menu_get` is not available unless something in w_lib loaded it. Functions obtained through `w_menu_get` run inside the owning resource, so menus you create with them belong to that resource, and you must use the `ClientEvent` / `ServerEvent` string fields instead of function handlers.

```lua
local remoteMenu = exports.w_gunsmith:w_menu_get()
print(remoteMenu.isOpen())
local data = exports.w_gunsmith:w_menu_get_current_data()
```

### w.pricing.new

```lua
w.pricing.new(data?: PriceInput, reuseExisting?: boolean): PriceClass
```

Side: shared

Parameters:

- `data` (number, table, PriceClass or nil, optional): price input. Accepted shapes: a number (money); `{ money = n }` / `{ gold = n }` / `{ rol = n }` (several keys in one table become several costs); `{ item = "name", quantity = n (default 1), keep = boolean (default false) }`; an array of any of these fragments; `{ costs = { ... } }` (canonical); a mixed table with direct fields plus array fragments; an existing `PriceClass` (copied cost by cost); `nil` or `{}` for an empty price.
- `reuseExisting` (boolean, optional, default false): when `true` and `data` is already a `PriceClass`, return it as-is instead of copying.

Returns: `PriceClass` with `.costs` (canonical array) and `.isProcessing`.

Constructor. Currency costs are merged by currency, item costs merged when item and keep match; item costs receive every field of the framework inventory record that is not already set (unknown names print an error and get label `"Not exist"`; the first lookup may fetch the item list and yield). Throws on invalid shapes (two currencies or a currency plus item in one fragment, non-number amounts, non-string item names).

```lua
local price = w.pricing.new({ money = 12, item = "bread", quantity = 2 })
print(price:getMoney(), #price:getItems())
```

### w.pricing.newGroup

```lua
w.pricing.newGroup(data?: PriceGroupInput, reuseExisting?: boolean): PriceGroupClass
```

Side: shared

Parameters:

- `data` (table, number, PriceClass, PriceGroupClass or nil, optional): group input: `{ operator = "or"|"and" (default "or"), prices = { PriceInput, ... } }`; or an array of PriceInputs (each one an alternative; `operator` may be set as a key on the array); or a flat `{ money = 5, gold = 1 }` which is split into separate alternatives; or a number / `PriceClass` (one entry); or an existing group (deep-copied).
- `reuseExisting` (boolean, optional, default false): return the same `PriceGroupClass` instance if `data` already is one.

Returns: `PriceGroupClass` with `.operator` and `.prices` (array of `PriceClass`).

Constructor for alternative ("or") or combined ("and") prices. Throws if `operator` is not `"and"` / `"or"`.

```lua
local group = w.pricing.newGroup({ operator = "or", prices = { { money = 10 }, { gold = 1 } } })
print(group:count())  -- 2
```

### w.pricing.getCosts

```lua
w.pricing.getCosts(price: PriceInput): Cost[]
```

Side: shared

Parameters:

- `price` (PriceInput, required): any price input.

Returns: canonical cost array.

Shortcut for `w.pricing.new(price):getCosts()`. `w.pricing.get` is an alias.

```lua
local costs = w.pricing.getCosts(25)  -- { { money = 25 } }
```

### w.pricing.tax

```lua
w.pricing.tax(price: PriceInput, percentage?: number, roundUpItems?: boolean): PriceClass, PriceClass
```

Side: shared

Parameters:

- `price` (PriceInput, required): base price.
- `percentage` (number, optional, default 0): multiplier applied to the base price to get the tax part.
- `roundUpItems` (boolean, optional, default false): item quantities in the tax part are rounded up (`math.ceil`) instead of down.

Returns: `taxPrice, remainingPrice` (base minus tax).

Splits a price into a tax part and the remainder without mutating the input.

```lua
local tax, rest = w.pricing.tax({ money = 100 }, 0.2)
print(tax:getMoney(), rest:getMoney())  -- 20  80
```

### w.pricing.isPrice / w.pricing.isPriceGroup

```lua
w.pricing.isPrice(value: any): boolean
w.pricing.isPriceGroup(value: any): boolean
```

Side: shared

Parameters:

- `value` (any, required): value to test.

Returns: `true` when `value` is a `PriceClass` / `PriceGroupClass` instance (metatable check).

A price that travelled through an event or export loses its metatable and returns `false` here.

```lua
if w.pricing.isPrice(p) then p = p:getCosts() end
print(w.pricing.isPriceGroup(group))
```

### PriceClass methods

```lua
price:getCosts(): Cost[]
price:copy(): PriceClass
price:equals(other: PriceInput): boolean
price:add(other: PriceInput): PriceClass
price:clear(): PriceClass
price:isFree(): boolean
price:isCurrencyOnly(): boolean
price:isItemOnly(): boolean
price:getMoney(): number|nil ; price:getGold(): number|nil ; price:getRol(): number|nil
price:hasCurrency(key: "money"|"gold"|"rol"): boolean
price:removeCurrency(key: "money"|"gold"|"rol"): PriceClass
price:getItems(): ItemCost[]
price:getItem(item: string, keep: boolean): ItemCost|nil
price:hasItem(item: string, keep: boolean): boolean
price:removeItem(item: string, keep: boolean): PriceClass
```

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `price:getCosts()` | none | the canonical costs array (the live table, not a copy) | Use this to transport a price to the server, to an export, or to the NUI. `PriceClass:get()` is a deprecated alias. |
| `price:copy()` | none | independent copy | Equivalent to `w.pricing.new(price)`. |
| `price:equals(other)` | `other` (PriceInput, required): invalid input yields `false` instead of an error | `true` when both have the same set of costs (order-independent) | Value comparison; the `==` operator also works between two `PriceClass` instances. |
| `price:add(other)` | `other` (PriceInput, required): price to merge into this one | self (mutated) | Merges costs in place (currencies summed, matching items summed). The `+` operator returns a new price instead of mutating. |
| `price:clear()` | none | self | Removes every cost. |
| `price:isFree()` | none | `true` when every currency amount is 0 and every item quantity is 0 (an empty price is free) | Free check. |
| `price:isCurrencyOnly()` | none | `true` when there is at least one cost and none is an item | Shape check. |
| `price:isItemOnly()` | none | `true` when there is at least one cost and all are items | Shape check. |
| `price:getMoney()` / `getGold()` / `getRol()` | none | the amount for that currency, `nil` when absent | Currency accessors. |
| `price:hasCurrency(key)` | `key` (string, required): currency key; anything else throws `"Currency key must be money, gold or rol"` | `true` when a cost with that currency exists | Presence check. |
| `price:removeCurrency(key)` | `key` (string, required, validated) | self | Removes the cost entry for that currency. |
| `price:getItems()` | none | array of item costs `{ item, quantity, keep, ...inventory item data }` | Item accessor. |
| `price:getItem(item, keep)` | `item` (string, required); `keep` (boolean, required, explicit: `false` = consumed, `true` = required but kept) | the matching item cost or `nil` | Both arguments are validated and throw otherwise. |
| `price:hasItem(item, keep)` | `item` (string, required); `keep` (boolean, required) | `true` when present | `getItem(item, keep) ~= nil`. |
| `price:removeItem(item, keep)` | `item` (string, required); `keep` (boolean, required) | self | Removes the matching item cost. |

```lua
local price = w.pricing.new({ money = 12, item = "bread", quantity = 2 })
price:add({ gold = 1 }):add(5)
print(price:equals({ money = 17, gold = 1, item = "bread", quantity = 2 }))
local money = price:getMoney() or 0
if price:hasCurrency("gold") then print("gold price") end
for _, it in ipairs(price:getItems()) do print(it.item, it.quantity, it.keep) end
local c = price:getItem("bread", false)
price:removeItem("bread", false)
price:removeCurrency("rol")
if price:isFree() then label = "Free" end
TriggerServerEvent("myshop:buy", price:getCosts())
```

### PriceClass operators (+, *, /, #, ==)

```lua
a + b : PriceClass ; price * n / n * price : PriceClass ; price / n : PriceClass ; #price : integer ; a == b : boolean
```

Side: shared

Parameters:

- operands (PriceClass, PriceInput or number, required): `+` accepts any price inputs on either side and returns a new merged price; `*` needs one `PriceClass` and one number (item quantities rounded to nearest); `/` needs a `PriceClass` and a non-zero number; `#` returns the number of cost entries; `==` compares two `PriceClass` instances by value.

Returns: see signature.

Metamethods; none mutate the operands.

```lua
local doubled = price * 2
local total = price + { gold = 1 }
print(#total, total == price)
```

### PriceGroupClass methods

```lua
group:copy(): PriceGroupClass
group:isEmpty(): boolean ; group:count(): integer ; group:clear(): PriceGroupClass
group:get(index: integer): PriceClass|nil
group:getCosts(index: integer): Cost[]
group:set(index: integer, price: PriceInput): PriceGroupClass
group:insert(price: PriceInput, index?: integer): PriceGroupClass
group:remove(index: integer): PriceClass|nil
group:compact(): PriceClass
```

Side: shared

| Method | Parameters | Returns | Notes |
|---|---|---|---|
| `group:copy()` | none | deep copy (prices copied too) | Constructor-based copy. |
| `group:isEmpty()` / `count()` / `clear()` | none | `isEmpty`: `true` when no prices; `count`: number of prices (also `#group`); `clear`: self | Basic container operations. `group * n` multiplies every price (new group). |
| `group:get(index)` | `index` (integer, required): 1-based; non-number throws | the `PriceClass` at that index | Accessor. |
| `group:getCosts(index)` | `index` (integer, required): 1-based; out of bounds throws | costs of the price at that index | Unlike `PriceClass:getCosts`, the index is mandatory. |
| `group:set(index, price)` | `index` (integer, required): existing index (1..count), otherwise throws; `price` (PriceInput, required) | self | Replaces an alternative. |
| `group:insert(price, index)` | `price` (PriceInput, required); `index` (integer, optional, default append) | self | Adds an alternative. |
| `group:remove(index)` | `index` (integer, required; non-number throws) | the removed `PriceClass` | `table.remove` on the prices array. |
| `group:compact()` | none | a single `PriceClass` with all prices added together | Only allowed when `operator == "and"`; throws for "or" groups. |

```lua
local group = w.pricing.newGroup({ operator = "or", prices = { { money = 10 }, { gold = 1 } } })
if not group:isEmpty() then print(group:count()) end
local first = group:get(1)
local costs = group:getCosts(2)
group:set(1, { money = 8 })
group:insert({ gold = 2 })
group:remove(2)
local g2 = group:copy()
local total = w.pricing.newGroup({ operator = "and", { money = 5 }, { money = 3 } }):compact()  -- money 8
```

### w.component (consumer bridge) and exports.w_lib:w_component_get

```lua
w.component = exports.w_lib:w_component_get()
exports.w_lib:w_component_get(): table
```

Side: shared

Parameters: none.

Returns: w_lib's `w.component` table (data tables copied, functions callable as export proxies).

In any resource other than w_lib, loading the component module (`w_module 'component'`, `w.require("component")` or first access of `w.component`) replaces the local table with w_lib's exported component table. Every function call is a cross-resource export call executed inside w_lib: arguments and results are copied, `w.component.data.*` is a snapshot, `w.cache.component` is not reachable, and functions cannot be passed as arguments. w_creators waits for `w.component.getFullPedComponentList` to exist before using it. The export is registered on both client and server of w_lib once the component module's global files are loaded (a consumer's `w.require` triggers that). Call it yourself only if you do not use the w_lib module loader.

```lua
while not (w and w.component and w.component.apply) do Wait(50) end
w.component.apply(PlayerPedId(), "hats", { hash = `CLOTHING_ITEM_M_HAT_000_TINT_001` })

-- without the module loader:
local component = exports.w_lib:w_component_get()
print(component.getCategoryHash("hats"))
```

### w.component.apply

```lua
w.component.apply(ped: integer, category: string|integer, data: table|integer|string)
```

Side: client

Parameters:

- `ped` (integer, required): entity id (player or NPC/horse ped).
- `category` (string or integer, required): category name or hash. Some pairs are mutually exclusive and the other one is removed: neckwear/neckerchiefs, ponchos/cloaks, coats/coats_closed, skirts removes pants. Pass the name for ponchos, cloaks, coats, coats_closed, skirts, hats, masks and horse_bridles: those checks compare the raw argument as a string.
- `data` (table, integer or string, required): component data; a bare hash (number or string name) is accepted, as are the array and VORP shapes of `formatComponentData`. hash `0` or `false` removes the category. `nil` also ends up removing the category (no hash, no palette).
  - `hash` (integer or string): shop item hash or name; values 0, 1 and -1 count as unset.
  - `drawable` (integer, optional): metatag drawable; 0/1/-1 count as unset.
  - `albedo` (integer, optional): metatag albedo; when present (or for hats/masks) the item is converted to a metatag so pieces can be mixed.
  - `normal` (integer, optional): metatag normal.
  - `material` (integer, optional): metatag material.
  - `palette` (string or integer, optional): tint palette name/hash from `data.palettes`; 0 means none.
  - `tint0` / `tint1` / `tint2` (integer, optional): tint indexes in the palette.
  - `wearableState` (string or integer, optional): state name from `data.wearableStates` (or its hash) applied after equipping and saved in the ped state bag; if absent, a state previously saved by the library for that category is reapplied. A table with only `wearableState` changes the state of the currently equipped piece.

Returns: nothing (prints a debug message on wrong data or unknown hash).

Equips a component: resolves the real category and MP flag from the hash, removes the conflicting tag, applies the shop item (or metatag), applies the wearable state, then schedules a delayed refresh that reapplies every cached tint and saved non-base state on the ped (so the tint you pass survives). `palette` / tints without `hash` only recolour the equipped piece. The branch meant to auto-save a pre-existing wearable state references an undefined variable and never runs, so only states set through the library are preserved. Runs inside w_lib through the export.

```lua
local ped = PlayerPedId()
w.component.apply(ped, "hats", { hash = `CLOTHING_ITEM_M_HAT_000_TINT_001`, palette = "metaped_tint_hat", tint0 = 5, tint1 = 0, tint2 = 0 })
w.component.apply(ped, "shirts_full", { hash = 0x1234ABCD, wearableState = "open_collar_rolled_sleeve" })
```

### w.component.remove

```lua
w.component.remove(ped: integer, category: string|integer)
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required): category to strip.

Returns: nothing.

`apply(ped, category, 0)`. w_creators wraps it in `pcall` because a bad argument makes the export throw.

```lua
pcall(w.component.remove, ped, "hats")
```

### w.component.removeAllClothes

```lua
w.component.removeAllClothes(ped: integer)
```

Side: client

Parameters:

- `ped` (integer, required): entity id.

Returns: nothing.

Sets bodies_lower/bodies_upper wearable state to base (stored in the state bag), then removes every category in `data.pedClothes` (keeps head, body, hair, beard, eyes, teeth).

```lua
w.component.removeAllClothes(PlayerPedId())
```

### w.component.applyComponents

```lua
w.component.applyComponents(ped: integer, components: table)
```

Side: client

Parameters:

- `ped` (integer, required): entity id; must exist.
- `components` (table, required): `{ [categoryName] = componentData }` where `componentData` is anything `apply()` accepts; keys are looked up by name from `data.pedClothes`, plus `bodies_lower` and `bodies_upper` which are applied last after waiting for the ped.

Returns: nothing.

`removeAllClothes` then `apply` each clothes category present in the table, in catalogue order. Yields (waits for the ped); call from a thread.

```lua
w.component.applyComponents(PlayerPedId(), {
  hats = { hash = `CLOTHING_ITEM_M_HAT_000_TINT_001` },
  pants = 0x5A2E4C1B,
  boots = { hash = 0x2B7C9D10, palette = "metaped_tint_leather", tint0 = 2, tint1 = 0, tint2 = 0 },
})
```

### w.component.applySkin

```lua
w.component.applySkin(ped: integer, skin: table)
```

Side: client

Parameters:

- `ped` (integer, required): entity id; model swap only works for the local player ped (other peds print an error and continue).
- `skin` (table, required): skin definition.
  - `model` (string, optional): `"mp_male"` / `"mp_female"`; swaps the player model when different (`SetPlayerModel`); also selects which beard fields are applied.
  - `headHash` (integer or string, optional): head component; otherwise built from `headIndex` / `skinTone`.
  - `headIndex` (integer, optional): head number for `getHeadFromSkinTone`.
  - `skinTone` (integer, optional): skin tone used for head and bodies.
  - `bodyUpperHash` / `bodyLowerHash` (integer or string, optional): body components; otherwise built from `bodiesIndex` / `skinTone`.
  - `bodiesIndex` (integer, optional): body index.
  - `bodyType` (integer, optional): `EquipMetaPedOutfit` preset for body type.
  - `bodyWeight` (integer, optional): `EquipMetaPedOutfit` preset for weight.
  - `expressions` (table, optional): `{ [expressionName] = -1.0..1.0 }` using `data.expressions` ids, clamped; unknown names error.
  - `eyesHash` / `eyesIndex` (optional): eyes component or index (default index 1).
  - `teethHash` / `teethIndex` (optional): teeth component or index (default index 1).
  - `hair` (component data): applied to `"hair"`; when absent the hair category is removed.
  - `beards_complete`, `beards_mustache`, `beards_chops`, `beards_chin` (component data): applied only when `model == "mp_male"`; absent ones are removed.
  - `beards`, `hair_bonnet` (component data): applied only when `model == "mp_female"`; absent ones are removed.
  - `overlays` (table, optional): passed unchanged to `w.pedTexture.overwriteBodyPart(ped, "heads", overlays, true)` when the ped is networked (the default-merging loop discards its result, so no defaults are added).
  - `bodyScale` (number): passed to `SetPedScale` unconditionally; pass `1.0` when you do not want scaling.

Returns: nothing.

Full character build: default body parts preset, head/bodies from skin tone, outfit presets, expressions, eyes, teeth, hair, beards, overlays, scale; waits for the ped to be ready between phases (yields). Marked "todo verify" in the source; the field set is what the code reads.

```lua
w.component.applySkin(PlayerPedId(), {
  model = "mp_male", headIndex = 3, skinTone = 2, bodiesIndex = 1,
  eyesIndex = 2, teethIndex = 1,
  hair = { hash = 0x1F2E3D4C, palette = "metaped_tint_hair", tint0 = 12, tint1 = 0, tint2 = 0 },
  expressions = { noseSize = 0.2, jawWidth = -0.3 },
  bodyScale = 1.0,
})
```

### w.component.setWearableState

```lua
w.component.setWearableState(ped: integer, category: string|integer, data: table|integer|nil, state: string|integer): boolean|nil
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required): category (shirts_full, neckwear, boots, vests, loadouts, hair, bodies_upper, bodies_lower).
- `data` (table, integer or nil, optional): component data of the equipped piece; when `nil` or without hash, the currently equipped hash is used.
- `state` (string or integer, required): state name (see `data.wearableStates`) or hash. The integer `0` clears the saved state and, when a hash is known, removes and re-applies the component; any other value (`"base"` included) is hashed, stored in the ped state bag and applied with the game native.

Returns: `false` when `state` is the same integer hash the game already reports (a string name never short-circuits), otherwise nothing.

Applies a wearable state, stores it in the ped state bag (`wearableState:<category>`) so later `apply()` calls keep it, restores the previous tint and schedules the cached reapply. Has special handling for neckwear (beard/armor fix) and boots (pants tint).

```lua
w.component.setWearableState(PlayerPedId(), "neckwear", nil, "mask_up")
```

### w.component.getWearableState

```lua
w.component.getWearableState(ped: integer, category: string|integer): string, integer|nil
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required): category.

Returns: state name and state hash: `("not_equiped", 0)` when the category is empty; `("no hash", nil)` when the game reports 0 and nothing is saved in the state bag; `("unknown", hash)` for an unnamed hash; otherwise `(name, hash)`.

Reads the game state, falling back to the state bag entry when the game reports 0.

```lua
local name, hash = w.component.getWearableState(PlayerPedId(), "shirts_full")
```

### Wearable state queries and shirt state setters

```lua
w.component.neckwearIsUp(ped) ; sleeveIsRolled(ped) ; collarIsOpened(ped) ; bootsAreUnderPant(ped) ; vestIsUnderPant(ped) ; loadoutIsOnRight(ped) ; hairIsPomade(ped) : boolean
w.component.sleeveRoll(ped, data?) ; sleeveUnroll(ped, data?) ; collarOpen(ped, data?) ; collarClose(ped, data?)
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `data` (table, integer or nil, optional, setters only): component data/hash of the shirts_full piece (`nil` uses the equipped one).

Returns: the queries return a boolean; the setters return nothing.

| Function | Meaning |
|---|---|
| `neckwearIsUp(ped)` | neckwear state is `"mask_up"` (alias `isNeckweaUp`) |
| `sleeveIsRolled(ped)` | shirts_full state name contains `"rolled"` (alias `isSleeveRolled`) |
| `collarIsOpened(ped)` | shirts_full state name contains `"open"` (alias `isCollarOpened`) |
| `bootsAreUnderPant(ped)` | boots state is `"under_pants"` (alias `isBootsUnderPant`) |
| `vestIsUnderPant(ped)` | vests state is `"under_pants"` (alias `isVestUnderPant`) |
| `loadoutIsOnRight(ped)` | loadouts state is `"base_right"` (alias `isLoadoutOnRight`) |
| `hairIsPomade(ped)` | hair state is `"pomade"` |
| `sleeveRoll(ped, data)` | sets `open_collar_rolled_sleeve` or `closed_collar_rolled_sleeve` depending on the current collar (alias `rollSleeve`) |
| `sleeveUnroll(ped, data)` | sets `open_collar_full_sleeve` or `base` (alias `unrollSleeve`) |
| `collarOpen(ped, data)` | sets `open_collar_rolled_sleeve` or `open_collar_full_sleeve` (alias `openCollar`) |
| `collarClose(ped, data)` | sets `closed_collar_rolled_sleeve` or `base` (alias `closeCollar`) |

The queries are convenience checks over `getWearableState`. The setters combine the current collar/sleeve state into the right shirts_full state and call `setWearableState`.

```lua
if w.component.neckwearIsUp(PlayerPedId()) then print("masked") end
w.component.sleeveRoll(PlayerPedId())
w.component.collarOpen(PlayerPedId())
```

### w.component.restoreHairState

```lua
w.component.restoreHairState(ped?: integer): boolean
```

Side: client

Parameters:

- `ped` (integer, optional): entity id (default `PlayerPedId()`).

Returns: `true` when the hair's state was changed (refresh the ped afterwards), `false` otherwise.

Puts the hair back in its own wearable state (the one set with `setWearableState`, e.g. `"pomade"`, else `"base"`) unless a hat is worn. The long MP hair styles have `*_TUCKED` states that the game switches through other garments' triggers, and the tucked hair is drawn without its crown. Which garment tucks it is inferred, not proven: a raised bandana, or a hat that has since left the head. Lowering the bandana, taking a garment off or the game knocking the hat off does not switch it back. The delayed refresh that follows every `apply` / `remove` / `setWearableState` runs this rule too, before and after its commit. Call it yourself when you need the ped right at once, or after a hat left the head without `w.component` (the game knocked it off). Under a hat the tucked hair is left alone.

```lua
if w.component.restoreHairState(PlayerPedId()) then w.component.refreshPed(PlayerPedId()) end
```

### w.component.getComponentEquiped

```lua
w.component.getComponentEquiped(ped: integer, category: string|integer): integer|false, table
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required): category.

Returns: the component hash (`false` and `{}` when the category has no slot; the hash can be `0` when the game cannot resolve it, and `0` is truthy in Lua) and a Component record `{ category, categoryHash, hash, index, palette, tint0, tint1, tint2, wearableState (name), wearableStateHash, drawable, albedo, normal, material }`.

Reads one slot. The record can be fed back to `apply()` to restore the piece.

```lua
local hash, comp = w.component.getComponentEquiped(ped, "coats")
if hash and hash ~= 0 then saved.coats = comp end
```

### w.component.getComponentsEquiped

```lua
w.component.getComponentsEquiped(ped: integer): table
```

Side: client

Parameters:

- `ped` (integer, required): entity id.

Returns: `{ [categoryHash] = Component record }` for every slot.

Snapshot of everything worn (clothes and body parts), keyed by category hash; use `data.categoryName` to get names.

```lua
local worn = w.component.getComponentsEquiped(PlayerPedId())
for hash, comp in pairs(worn) do print(comp.category, comp.hash) end
```

### w.component.getCategoriesEquiped / isCategoryEquiped

```lua
w.component.getCategoriesEquiped(ped: integer): table
w.component.isCategoryEquiped(ped: integer, category: string|integer): boolean, integer
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required for `isCategoryEquiped`): category.

Returns: `getCategoriesEquiped` returns `{ [categoryHash] = { index = integer, category = string, categoryHash = integer } }`; neckwear/neckerchiefs and ponchos/cloaks are mirrored onto each other. `isCategoryEquiped` returns `true` and the component index, or `false` and `-1`.

`getCategoriesEquiped` enumerates the ped's component slots by category; `isCategoryEquiped` is a native check plus index lookup.

```lua
for hash, info in pairs(w.component.getCategoriesEquiped(PlayerPedId())) do print(info.category, info.index) end
local worn, index = w.component.isCategoryEquiped(ped, "hats")
```

### w.component.getCategoryTint

```lua
w.component.getCategoryTint(ped: integer, category: string|integer, inTable?: boolean): table | integer, integer, integer, integer | false
```

Side: client

Parameters:

- `ped` (integer, required): entity id.
- `category` (string or integer, required): category.
- `inTable` (boolean, optional, default false): `true` gives `{ palette, tint0, tint1, tint2 }`; `false` gives four values.

Returns: palette hash and three tints, or `false` when the category is not equipped.

Reads the current tint of a slot.

```lua
local tint = w.component.getCategoryTint(ped, "hats", true)
```

### w.component.refreshPed / waitPedLoaded

```lua
w.component.refreshPed(ped?: integer)
w.component.waitPedLoaded(ped: integer)
```

Side: client

Parameters:

- `ped` (integer, optional for `refreshPed` with default `PlayerPedId()`; required for `waitPedLoaded`): entity id.

Returns: nothing (`waitPedLoaded` returns early with a debug print if the ped never becomes ready).

`refreshPed` flushes any pending delayed reapply for the ped immediately, then forces the metaped update natives; call it after a batch of `apply()` calls when you need the result now. `waitPedLoaded` waits 30 ms then until the ped is ready to render (`w.waiter` timeout); it yields, so call it from a thread.

```lua
w.component.apply(ped, "coats", coat)
w.component.waitPedLoaded(ped)
w.component.refreshPed(ped)
```

### w.component.getComponentCategory / isMpComponent / getBaseLayer

```lua
w.component.getComponentCategory(ped: integer, hash: string|integer): integer|nil, boolean
w.component.isMpComponent(ped: integer, hash: string|integer): boolean
w.component.getBaseLayer(ped: integer, hash: string|integer, inTable?: boolean): table | drawable, albedo, normal, material, paletteName, tint0, tint1, tint2
```

Side: client

Parameters:

- `ped` (integer, required): entity id (its metaped type is used; must exist for `getComponentCategory`); `isMpComponent` and `getBaseLayer` also accept a metaped type number when the entity does not exist.
- `hash` (string or integer, required): shop item hash or name.
- `inTable` (boolean, optional, default false, `getBaseLayer` only): return a table instead of eight values.

Returns:

- `getComponentCategory`: category hash (`nil` or `0` if the hash is unknown for this ped type) and `true` when it is an MP (multiplayer) component.
- `isMpComponent`: `true` for MP components.
- `getBaseLayer`: metatag layers of the shop item (`nil` for unset values); palette is returned as a name (`"unknown"` / `"no hash"` when unresolvable), falling back to the `tintShopItems` data.

`getComponentCategory` resolves which category a shop item belongs to; `isMpComponent` returns the MP flag only; `getBaseLayer` is used to convert a shop item into a metatag (hats/masks mixing).

```lua
local catHash, isMp = w.component.getComponentCategory(ped, hash)
print(w.component.getCategoryNameFromHash(catHash), isMp)
print(w.component.isMpComponent(PlayerPedId(), hash))
local layers = w.component.getBaseLayer(PlayerPedId(), `CLOTHING_ITEM_M_HAT_000_TINT_001`, true)
```

### w.component.getPaletteNameFromHash / getCategoryNameFromHash / getWearableStateNameFromHash

```lua
w.component.getPaletteNameFromHash(hash): string
w.component.getCategoryNameFromHash(category): string
w.component.getWearableStateNameFromHash(state): string
```

Side: client

Parameters:

- `value` (integer or string, required): hash to convert; strings are returned unchanged; `nil` returns `"no hash"`.

Returns: name, or `"unknown"` when not in the data tables.

Reverse lookups over `data.palettesName`, `data.categoryName` and `data.wearableStatesName`. Defined in `g_client.lua`, so client only.

```lua
print(w.component.getCategoryNameFromHash(`coats_closed`))
```

### w.component.getCategoryHash / isCategoryAClothes

```lua
w.component.getCategoryHash(category: string|integer): integer
w.component.isCategoryAClothes(category: string|integer): boolean
```

Side: shared

Parameters:

- `category` (string or integer, required): category name (for example `"hats"`) or an already-hashed integer (returned unchanged by `getCategoryHash`).

Returns: `getCategoryHash` returns the joaat hash of the category (`"horse_feathers"` is special-cased to `-287556490`); `isCategoryAClothes` returns `true` for clothes categories (not body parts, hair, beards, teeth, eyes).

Every component function that takes a category accepts either form through `getCategoryHash`. `isCategoryAClothes` is a lookup in `data.clothesCategories`.

```lua
local hash = w.component.getCategoryHash("coats")
print(w.component.isCategoryAClothes("hair"))  -- false
```

### w.component.formatComponentData

```lua
w.component.formatComponentData(data: string|number|table, hashData?: boolean): table
```

Side: shared

Parameters:

- `data` (string, number or table, required): a hash (number/string) becomes `{ hash = data }`; an array `{ hash, drawable, albedo, normal, material, palette, tint0, tint1, tint2 }` becomes named fields (hash defaults to 0); a VORP shape `{ hash = { ... } }` yields the inner table; a named table is copied as-is.
- `hashData` (boolean, optional, default false): when `true`, every value is passed through `GetHashFromString`.

Returns: named component table `{ hash, drawable, albedo, normal, material, palette, tint0, tint1, tint2, ... }`.

Normaliser used by `apply()`; useful to convert stored skins before sending them.

```lua
local d = w.component.formatComponentData({ `CLOTHING_ITEM_M_HAT_000_TINT_001`, nil, nil, nil, nil, "metaped_tint_hat", 3, 0, 0 })
```

### Component name builders (getHeadFromSkinTone, getBodiesUpperFromSkinTone, getBodiesLowerFromSkinTone, getEyesFromIndex, getTeethFromIndex)

```lua
w.component.getHeadFromSkinTone(ped: integer|string, headIndex?: integer, skinTone?: integer): string
w.component.getBodiesUpperFromSkinTone(ped: integer|string, bodiesIndex?: integer, skinTone?: integer): string
w.component.getBodiesLowerFromSkinTone(ped: integer|string, bodiesIndex?: integer, skinTone?: integer): string
w.component.getEyesFromIndex(ped: integer|string, index?: integer): string
w.component.getTeethFromIndex(ped: integer|string, index?: integer): string
```

Side: shared

Parameters:

- `ped` (integer or string, required): entity id (sex via `IsPedMale`, client only) or model name `"mp_male"` / `"mp_female"`; for `getHeadFromSkinTone`, `nil` falls back to `PlayerPedId()`.
- `headIndex` / `bodiesIndex` / `index` (integer, optional, default 1): head number, body index, eyes tint index or teeth index.
- `skinTone` (integer, optional, default 1): skin tone number.

Returns:

| Builder | Result |
|---|---|
| `getHeadFromSkinTone` | `"CLOTHING_ITEM_<M|F>_HEAD_<index>_V_<tone>"` (zero-padded to 3 digits) |
| `getBodiesUpperFromSkinTone` | `"CLOTHING_ITEM_<sex>_BODIES_UPPER_%03d_V_%03d"` |
| `getBodiesLowerFromSkinTone` | `"CLOTHING_ITEM_<sex>_BODIES_LOWER_%03d_V_%03d"` |
| `getEyesFromIndex` | `"CLOTHING_ITEM_<sex>_EYES_001_TINT_%03d"` |
| `getTeethFromIndex` | `"CLOTHING_ITEM_<sex>_TEETH_%03d"` |

Defined in the shared global file, so they exist on the server too, but only the model-name form works there. `applySkin` uses the bodies builders when `bodyUpperHash` / `bodyLowerHash` are absent.

```lua
local head = w.component.getHeadFromSkinTone("mp_female", 4, 2)  -- CLOTHING_ITEM_F_HEAD_004_V_002
w.component.apply(PlayerPedId(), "heads", head)
w.component.apply(ped, "bodies_upper", w.component.getBodiesUpperFromSkinTone(ped, 1, 3))
w.component.apply(ped, "eyes", w.component.getEyesFromIndex(ped, 5))
```

### Catalogue loaders (getFullPedComponentList, getFullHorseComponentList, getFullShopItemTintsList, getShopItemTint)

```lua
w.component.getFullPedComponentList(): table
w.component.getFullHorseComponentList(): table
w.component.getFullShopItemTintsList(): table
w.component.getShopItemTint(shopItem: string|integer): table|nil
```

Side: shared

Parameters:

- `shopItem` (string or integer, required, `getShopItemTint` only): shop item hash or name (hashed with `GetHashFromString`).

Returns:

| Function | Returns |
|---|---|
| `getFullPedComponentList()` | `{ female = { [CATEGORY] = { { variations = { { hash = integer, hashname = string }, ... } }, ... } }, male = { ... } }` loaded from `modules/component/data/playerComponents.lua` (categories in upper case such as `BODIES_LOWER`, `VEST`) |
| `getFullHorseComponentList()` | `{ [horseCategory] = { { variations = { { hash = integer, hashname? = string, albedo?, normal?, material?, palette?, tint0?, tint1?, tint2? }, ... } }, ... } }` from `modules/component/data/horseComponents.lua` |
| `getFullShopItemTintsList()` | `{ [shopItemHash] = { p = paletteName, t0 = integer, t1 = integer, t2 = integer } }` from `modules/component/data/tintShopItems.lua` |
| `getShopItemTint(shopItem)` | `{ p, t0, t1, t2 }` or `nil` |

`getFullPedComponentList` is a large data file (about 1 MB, the clothing shop catalogue). It is loaded lazily and cached inside w_lib; through the export the whole table is copied to you, so call it once and keep the result. Only the outer shape was read from the file; per-category details may vary. `getFullHorseComponentList` is loaded and copied the same way; some variations carry metatag fields instead of a shop hash name (seen for horse hair entries). `getFullShopItemTintsList` holds default tints per shop item; `getBaseLayer` falls back to it when the game returns no palette; `p` is a palette name string (for example `"metaped_tint_combined_leather"`). `getShopItemTint` looks up the tints list (loading it on first use).

Not confirmed from source; treat as best effort. (This applies to the record shapes of `getFullPedComponentList` and `getFullHorseComponentList`.)

```lua
local list = w.component.getFullPedComponentList()
for _, group in ipairs(list.male.HATS or {}) do print(group.variations[1].hashname) end
local horses = w.component.getFullHorseComponentList()
print(#horses.horse_saddles)
local tints = w.component.getFullShopItemTintsList()
local t = w.component.getShopItemTint("CLOTHING_ITEM_M_HAT_000_TINT_001")
```

### w.component.data tables

```lua
w.component.data.pedCategories: string[]
w.component.data.horseCategories: string[]
w.component.data.order: string[]
w.component.data.pedClothes: string[]
w.component.data.clothesCategories: { [hash] = name }
w.component.data.categoryName: { [hash] = name }
w.component.data.wearableStates: { [category] = { [code] = stateName }, others = string[] }
w.component.data.wearableStatesName: { [hash] = name }
w.component.data.palettes: string[]
w.component.data.palettesName: { [hash] = name }
w.component.data.expressions: { [name] = faceFeatureId }
```

Side: shared

Parameters: none (data tables; snapshots in a consumer resource).

Returns: n/a

| Table | Content |
|---|---|
| `pedCategories` | Ordered list of the human metaped category names: heads, eyes, teeth, bodies_upper, bodies_lower, hair, hair_bonnet, beards, beards_chin, beards_chops, beards_mustache, beards_complete, ponchos, cloaks, hair_accessories, dresses, shawls, chemises, knickers, gloves, coats, coats_closed, coat_accessories, coats_heavy, vests, vest_accessories, corsets, suspenders, neckties, shirts_full, shirts_full_overpants, unionsuit_legs, unionsuits_full, spats, gunbelts, gauntlets, wrist_bindings, holsters_left/right/center/crossdraw/knife/quivers, loadouts, outfits, belt_buckles, belts, skirts, boots, pants, pants_accessories, overalls_full, overalls_modular_uppers/lowers, boot_accessories, ankle_bindings, accessories, satchels, satchel_straps, jewelry_rings_right/left, jewelry_rings, jewelry_bracelets, jewelry_earrings, jewelry_necklaces, aprons, chaps, badges, gunbelt_accs, eyewear, masks, masks_large, hats, hat_accessories, headwear, then hair, beards_complete and teeth a second time (duplicates in the source), neckwear, neckerchiefs, armor. |
| `horseCategories` | horse_heads, horse_bodies, horse_feathers, horse_blankets, saddle_horns, saddle_stirrups, saddle_lanterns, horse_saddlebags, horse_bedrolls, horse_tails, horse_shoes, horse_mustache, horse_manes, horse_accessories, horse_outfits, horse_saddles, horse_bridles. |
| `order` | `pedCategories` followed by `horseCategories` (the order tints are reapplied in). |
| `pedClothes` | `pedCategories` minus the body parts (hair, beards, beards_chin, beards_chops, beards_mustache, beards_complete, hair_bonnet, teeth, heads, bodies_lower, bodies_upper, eyes); `removeAllClothes` / `applyComponents` iterate it. |
| `clothesCategories` | Maps the hash of each clothes category to its name. |
| `categoryName` | Maps every ped and horse category hash to its name. |
| `wearableStates` | Named wearable states per category: `shirts_full { [0]="base", [1]="closed_collar_rolled_sleeve", [10]="open_collar_full_sleeve", [11]="open_collar_rolled_sleeve" }`; `neckwear { [0]="base", [1]="mask_up" }`; `boots { [0]="base", [1]="under_pants" }`; `loadouts { [0]="base", [1]="base_right" }`; `vests { [0]="base", [1]="under_pants" }`; `hair { [0]="base", [1]="pomade" }`; plus an `others` list of every other state string the game knows (base_coat_open, gown, base_tucked, hidden, ...). `w.component.wearableStates` is a deprecated alias. |
| `wearableStatesName` | Maps each state hash back to its name. |
| `palettes` | The tint palette names accepted by `apply()` / palette sliders (metaped_tint_hair, metaped_tint_generic, metaped_tint_leather, metaped_tint_horse, metaped_tint_hat, metaped_tint_skirt_clean, metaped_tint_eye, metaped_tint_makeup, metaped_tint_teeth, metaped_tint_swatch_000..003, generic_wagon_palette, generic_skinned_pal, metaped_tint_combined_leather..6, ...). `w.component.palettes` is a deprecated alias. |
| `palettesName` | Maps each palette hash to its name. |
| `expressions` | Face/body feature ids used by `applySkin`'s `skin.expressions` (cheekbonesDepth, chinWidth, eyesAngle = 53862, eyesDepth = 60996, noseSize = 13425, mouthWidth, upperLipHeight, arms, chest, hip, waist, shoulders, calves, thighs, ...). `w.component.expressions` is a deprecated alias. |

```lua
for _, cat in ipairs(w.component.data.pedCategories) do print(cat) end
print(#w.component.data.horseCategories)
print(w.component.data.categoryName[`hats`])  -- "hats"
for code, name in pairs(w.component.data.wearableStates.shirts_full) do print(code, name) end
print(w.component.data.palettesName[GetHashKey("metaped_tint_hair")])
SetCharExpression(ped, w.component.data.expressions.noseSize, 0.5)
```

### HorseComponents (deprecated global)

```lua
HorseComponents: { [horseCategory] = { { title?: string, variations: integer[] }, ... } }
```

Side: client

Parameters: none.

Returns: n/a

Deprecated static table of horse component hashes grouped by category (horse_saddles, saddle_horns, horse_shoes, horse_manes, saddle_stirrups, horse_mustache, horse_tails, horse_bridles, horse_blankets, horse_bedrolls, horse_outfits (entries carry a title such as `"skinBears"`, `"skinFox"`, `"workerLoadout"`), horse_accessories, horse_saddlebags, saddle_lanterns). The file is listed in w_lib's `files` but the module loader only loads shared/client/server and `g_` files, so it is never executed by w_lib: read it with `LoadResourceFile("w_lib", "modules/component/horseComponents.lua")` and `load()` it if you need it. Prefer `w.component.getFullHorseComponentList()`.

```lua
local src = LoadResourceFile("w_lib", "modules/component/horseComponents.lua")
load(src)()
print(#HorseComponents.horse_saddles)
```

### Manifest metadata for the version checker (version, package_id, dependencies_version_min)

```lua
version '3.38.0' ; package_id '1234' ; dependencies_version_min 'w_lib:3.38.0,other_res:1.0.0'
```

Side: server

Parameters:

- `version` (string, required): semantic version of your resource; compared with `compareVersionWith` against the API's `vX.Y.Z`.
- `package_id` (number, required): Jump On Studios package id (`tonumber` is applied); below 1000 points the download hint to GitHub, otherwise to the Cfx portal.
- `dependencies_version_min` (string, optional): comma-separated `resource:minVersion` pairs; each is checked with `w.resource.isConvarMatching('resource>=minVersion')` against that resource's manifest version.

Returns: n/a

Metadata read by `w.versionChecker.checkUpdate`. Without both `version` and `package_id` the check is skipped entirely.

```lua
version '1.0.0'
package_id '42'
dependencies_version_min 'w_lib:3.38.0'
```

### w.versionChecker.checkUpdate

```lua
w.versionChecker.checkUpdate()
```

Side: server

Parameters: none.

Returns: nothing (runs in a thread).

Reads the calling resource's manifest metadata `version` and `package_id` (both required, otherwise it returns before doing anything, dependencies included), asks `https://jumpon-studios.com/api/checkScriptVersion?package=<id>` and prints up-to-date / update-found messages. Then parses `dependencies_version_min` (`"res:1.2.0,other:2.0.0"`): each entry becomes `"res>=1.2.0"` and is checked with `w.resource.isConvarMatching`, which requires the resource to be starting/started and compares its manifest `version` metadata (default 1) with `compareVersionWith`; a missing resource prints an error, a running resource with an older version prints an error and stops the calling resource through w_lib's internal `w_lib:kill:resource` event. It is invoked automatically by `w.ready()` when the module is loaded, so listing `'version-checker'` in `w_module` is enough.

```lua
-- fxmanifest.lua of your resource
-- version '1.4.0'
-- package_id '1234'
-- dependencies_version_min 'w_lib:3.38.0'
-- w_module { 'version-checker' }
-- (nothing to call; runs on start)
```

### w.versionChecker.GetScriptVersion

```lua
w.versionChecker.GetScriptVersion(): string|integer
```

Side: server

Parameters: none.

Returns: the `version` manifest metadata of the current resource, or `1` when missing.

Reads `GetResourceMetadata(GetCurrentResourceName(), "version", 0)`.

```lua
print("running", w.versionChecker.GetScriptVersion())
```

### w.versionChecker.StopAddon

```lua
w.versionChecker.StopAddon(resource: string): boolean
```

Side: server

Parameters:

- `resource` (string, required): resource name to stop.

Returns: `true` immediately; the `StopResource` runs in a new thread.

Asynchronous `StopResource`.

```lua
w.versionChecker.StopAddon("my_old_addon")
```

### exports.w_lib:StopAddon

Documented under "Loading the library, globals and lifecycle". In this build the export is registered twice and the second registration wraps a nil function, so calling it raises an error; use `w.versionChecker.StopAddon` or `TriggerEvent('w_lib:kill:resource', name)` instead.

### Events

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| `<event>ClientEvent` (consumer-named, for example `onClickClientEvent = "myshop:buyClicked"`) | client | `(currentData, ...)` where `currentData = { menu, index, item }` | Triggered by `w.menu.fireEvent` with `TriggerEvent` before the function handler of the same event; the name is whatever string the consumer resource put on the menu or item table. Register with `RegisterNetEvent` / `AddEventHandler`. |
| `<event>ServerEvent` (consumer-named, for example `onClickServerEvent = "myshop:sv:buy"`) | server (triggered from the client) | `(currentData, ...)` | Triggered by `w.menu.fireEvent` with `TriggerServerEvent` before the function handler. |
| `w_lib:kill:resource` | server | internal | Local-only event used by the version checker to stop a consumer resource whose dependency is too old. Not a consumer API; do not trigger or listen to it. |

### Convars

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| none | | | These modules read no convars. |

### Commands

| Name | Side | Payload or value | Meaning |
|---|---|---|---|
| none | | | These modules register no commands. |

## Packaging the library with Cfx escrow

The library loads most of its own code at runtime with `LoadResourceFile` followed by `load`: `init.lua` (read by every consumer resource), `w_init.lua`, every file under `imports/`, every file under `modules/`, and `resource/settings.lua` (read through `require 'resource.settings'`). Cfx escrow encrypts every Lua file that is not listed in `escrow_ignore`, and `LoadResourceFile` returns the encrypted bytes unchanged, so an encrypted copy of any of those files fails at start with

```
Error importing module (imports/require): @w_lib/require/server.lua:1: syntax error near '<\1>'
Error importing module (modules/print/shared.lua): ... syntax error near '<\1>'
```

and the same message for `imports/class`, `imports/print`, `imports/array`, `imports/hook` and every other dynamically loaded file.

Only files that the manifest lists as `client_scripts`, `server_scripts` or `shared_scripts` are decrypted by the runtime. In this library that is the `resource/` tree, which is also the part written by Wraith Studio; `imports/` and `modules/` are derived from ox_lib and jo_libs and stay LGPL-3.0, which requires their source to remain available anyway.

The manifest therefore needs this block before the package is uploaded:

```lua
escrow_ignore {
    'init.lua',
    'w_init.lua',
    'imports/**/*.lua',
    'modules/**/*.lua',
    'resource/settings.lua',
    'locales/*.json',
    'locales_modules/*.json',
    'web/build/**/*',
    'html/dist/**/*',
    'README.md',
}
```

Everything under `resource/` except `settings.lua` stays encrypted. Consumer resources are not affected by the encryption of that tree: they reach it only through exports and the `lib.<name>` proxies described in this document.

Two further points about the package itself:

- The `nui/` directory (the pre-3.x jo_libs pages: menu, input, prompt, gizmo, minigame, notify, clipboard) is not listed in the manifest's `files` block and `w.nui.load` is a no-op in this version, so nothing loads from it at runtime. It is roughly 170 MB of assets and can be left out of the upload.
- `html/dist` is listed in the manifest's `files` block, but neither the Lua code nor the built app references it; it can be left out of the upload as well.
- `web/src`, `web/node_modules` and the build tooling are not needed at runtime; ship `web/build` only.

## Known limitations in this version

These behaviours were confirmed against the source of version 3.38.0. They are listed so that a consumer does not spend time looking for a mistake on its own side.

| Item | Behaviour | Workaround |
| --- | --- | --- |
| `w_lib { 'locale' }` manifest entry | Does not initialise locales: `init.lua` pre-loads `lib.locale` before it reads the metadata, and the metadata loop skips names that are already loaded. | Call `lib.locale()` once from a shared or client script. |
| `exports.w_lib:StopAddon` | Registered twice inside the library; the second registration wraps a nil function, so the export raises `attempt to call a nil value`. | `TriggerEvent('w_lib:kill:resource', resourceName)` on the server, or `w.versionChecker.StopAddon(resourceName)` in a resource that loaded the `version-checker` module. |
| `w.nui.load`, `w.nui.forceFocus` | `load` is a no-op and `forceFocus` always reports "This nui is not loaded". Every interface lives in the single built app. | Set `ui_page 'nui://w_lib/web/build/index.html'` in the consumer resource; do not call these. |
| `w.dataview` | The `dataview` module defines the global `DataView` only; `w.dataview` is nil. | Use `DataView` directly, or `lib.dataview` for the shared implementation. |
| Server-side `cache` | Only `cache.game` and `cache.resource` exist on the server; reading any other key there errors because it calls a client-only export. | Read player state on the server through the framework bridge. |
