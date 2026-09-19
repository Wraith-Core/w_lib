# توافق الأنظمة — w_lib 4.0

المكتبة تعمل في اتجاهين:

1. **سكربتات `w_*` على أي نواة** (VORP / RSG / QBR / Wraith Core): جسر الفريمورك
   `w.framework` (modules/framework-bridge) و `exports.w_lib:Fw*` / `Inv*` (resource/fwbridge,
   resource/invbridge). السكربت يكتب مرة واحدة ويعمل على الكل.
2. **سكربتات VORP / RSG / QBR / ox_lib على Wraith Core**: `w_core` يعلن في المانيفست
   `provide 'rsg-core'` و`'qbr-core'` و`'vorp_core'` و`'vorp_menu'` و`'vorp_inputs'`
   و`'vorp_progressbar'` و`'ox_lib'`، والمكتبة تركّب عقود هذه الأسماء داخل VM النواة نفسها
   (`compat/host_*.lua`، تُحمَّل تلقائيًا من `init.lua` عندما يكون المورد الحالي يقدّم أحد الأسماء).

> لماذا داخل النواة؟ `provide` يمنح الاسم البديل لـ `GetResourceState` والتبعيّات فقط، ولا
> يمنحه للـexports: نداء `exports['rsg-core']:GetCoreObject()` يبحث عن الحدث
> `__cfx_export_rsg-core_GetCoreObject`، ولا يستطيع تسجيله إلا كود يعمل داخل المورد المقدِّم.

## ما الذي يراه سكربت مكتوب لـ RSG / QBR على Wraith Core

| النداء | الجواب |
|---|---|
| `exports['rsg-core']:GetCoreObject()` | كائن `WCore` (نفس عقد RSG: `Functions.GetPlayer`, `PlayerData.citizenid/charinfo/job/money`, `Shared.Items/Jobs/Gangs/Weapons`) |
| `exports['qbr-core']:GetCoreObject()` / `GetPlayer(src)` / `GetPlayers()` / `GetPlayerData()` / `GetItems()` / `GetJobs()` / `GetGangs()` / `GetWeapons()` | من `WCore` |
| أحداث `RSGCore:*` | مرايا لأحداث `WCore:*` (w_core/compat) |
| `exports['rsg-inventory']:*` | تقدّمها `w_inventory` |
| `Core.Shared.Items` | نسخة بشكل RSG من كتالوج `w_inventory/data/items.lua` + الأسلحة (`exports.w_lib:CompatItems()`) |

## ما الذي يراه سكربت مكتوب لـ VORP على Wraith Core

الواجهة `exports.vorp_core:GetCore()` (وأيضًا `TriggerEvent('getCore', cb)`) — `compat/host_server.lua` و`host_client.lua`:

- **خادم**: `Core.getUser(src)` → `User.getUsedCharacter` (حقول: `identifier`, `charIdentifier`,
  `firstname`, `lastname`, `money`, `gold`, `rol`, `job`, `jobGrade`, `jobLabel`, `gender`, `age`, `xp`,
  `isdead`, `playerName`، ودوال: `addCurrency(type, amount)`, `removeCurrency`, `setCurrency`,
  `getCurrency`, `setJob`, `setJobGrade`, `setJobLabel`, `setGroup`, `addXp`, `removeXp`, `setXp`,
  `setDead`, `setFirstname`, `setLastname`). `Core.getUsers()`, `Core.maxCharacters`.
  `Core.Callback.Register(name, function(source, cb, ...) end)`, `Core.Callback.TriggerAsync(src, name, cb, ...)`,
  `Core.NotifyRightTip/NotifyTip/NotifyLeft/NotifyObjective/NotifySimpleTop/NotifyAvanced/NotifyCenter/
  NotifyBottomRight/NotifyFail/NotifyDead/NotifyUpdate/NotifyWarning`, `Core.AddWebhook` (→ w_logs).
  أحداث قديمة: `vorp:addMoney/removeMoney/addGold/removeGold/setJob/setJobGrade/setGroup/addXp/removeXp/getCharacter/getUser`.
  تُطلق: `vorp:SelectedCharacter (src, character)` و`vorp_core:Server:OnPlayerReady` عند تحميل الشخصية،
  `vorp:PlayerLogout` عند الخروج.
- **عميل**: `Core.Callback.TriggerAsync(name, cb, ...)`, `Core.Callback.TriggerAwait(name, ...)`,
  `Core.Callback.Register`, `Core.RpcCall`، كل دوال `Notify*`، أحداث `vorp:TipRight/TipBottom/Tip/NotifyLeft/
  ShowAdvancedRightNotification/ShowTopNotification/ShowSimpleCenterText/ShowObjective/ShowBottomRight/
  NotifyFail/NotifyDead/NotifyUpdate/NotifyWarning`، `Core.Player.GetPlayerData()`.
  تُطلق: `vorp:SelectedCharacter (charId, character)` و`vorp_core:Client:OnPlayerReady`.
- `exports.vorp_inputs:advancedInput(cb, config)` → حوار إدخال المكتبة.
- `exports.vorp_progressbar:initiate(cb, ms, label)` → شريط تقدّم المكتبة.
- `exports.vorp_menu:GetMenuData()` → `MenuData.Open(type, namespace, name, data, submit, cancel, change, close)`
  (`data.elements` = خيارات قائمة سياق المكتبة؛ `data.current` عند الاختيار، `menu.close/setElements/setTitle/refresh/update`),
  `MenuData.Close`, `CloseAll`, `IsOpen`, `GetOpened`.
- `exports.ox_lib:<fn>` → يُحوَّل إلى `exports.w_lib:<fn>` لكل أسماء ox_lib الشائعة (notify، الحوارات، القوائم، التقدّم، textUI، skillCheck، radial، locale، ACL…).
  `'@ox_lib/init.lua'` في مانيفست سكربت خارجي يصل إلى `w_core/init.lua` الذي يحمّل مكتبتنا.

### حدود معروفة
- المظهر (`updateSkin` / `updateComps` / جداول skins) ملك `w_creators`؛ دوال VORP لها لا تفعل شيئًا.
- عملة `rol` غير موجودة في Wraith Core (تُقرأ 0 ولا تُعدَّل).
- `vorp_menu` مُترجم إلى قائمة سياق: عناصر `slider` تدور بالنقر، ولا يوجد `itemHeight` أو محاذاة.
- `vorp_inventory` / `vorp_character` / `vorp_utils` ليست مُقدَّمة؛ الحقيبة الوحيدة هي `w_inventory` (تقدّم `rsg-inventory` و`qbr-inventory` و`vorp_inventory`).

## الحالة والاستعلام

- `exports.w_lib:CompatStatus()` → `{ host = 'w_core', dialect = 'rsg', inboundAliases = {...} }` أو `false`
  على سيرفر VORP/RSG حقيقي. `w_inventory` و`w_creators` يقرآنها ليعرفا أنهما على Wraith Core.
- `exports.w_lib:FwName()` → `'rsgcore'` على Wraith Core (يوافق `w_hud`)، `exports.w_lib:FwBackend()` → `'wcore'`,
  `exports.w_lib:FwHost()` → `'w_core'`.
- `w.framework:get()` → `'rsg'`، `w.framework:isWraith()` → `true`، `w.framework:getCoreObject()` → `WCore` (الجانبان).
