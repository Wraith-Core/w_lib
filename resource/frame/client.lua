-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · resource/frame/client.lua
-- إطارٌ واحدٌ للاستوديو كلّه: حجبُ تحكُّمٍ وقراءةُ ضغطته.
--
-- ★ لماذا هنا لا في كلِّ مورد؟
--   حجبُ مفتاحٍ في RAGE لا يدوم إلا إطارًا واحدًا، فمن أراد أن يأخذ مفتاحًا من
--   اللعبة اضطُرَّ إلى ‎while true do Wait(0)‎ أبديّ. كلُّ مورد يفعلها يدفع نحو
--   ‎0.01–0.04 ms‎ من كلِّ إطار، مفتوحةً كانت واجهته أو مغلقة — وهي وحدَها ما
--   يمنع resmon من قراءة 0.00 عند السكون.
--
--   فصار الحلقةُ واحدةً هنا: يُسجّل المورد ما يريد حجبه، ولا يدفع إطارًا. ولا
--   تُبعث إليه رسالةٌ كلَّ إطار — بل حدثٌ واحدٌ لحظةَ الضغط فقط.
--
-- ★ الاستعمال من أيّ مورد:
--     AddEventHandler('w_map:key:map', function() ... end)
--     exports.w_lib:blockControl(`INPUT_MAP`, 'w_map:key:map')
--     exports.w_lib:unblockControl(`INPUT_MAP`, 'w_map:key:map')   -- عند الحاجة
--
--   والحلقة لا تعمل أصلًا ما لم يسجّل أحد، وتتوقّف حين يخلو السجلّ. والتسجيلُ
--   يُطوى تلقائيًّا حين يتوقّف المورد الذي سجّله.
-- ════════════════════════════════════════════════════════════════════════════

local DisableControlAction = DisableControlAction
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local TriggerEvent = TriggerEvent
local pairs = pairs

---@type table<number, { n: integer, press: table<string, string> }>
local blocked = {}
local live = 0
local running = false

-- ---- the radar (below) shares this one frame thread --------------------------
local DisplayRadar = DisplayRadar
local radarOwners, radarOwnerCount = {}, 0   -- resources drawing their own minimap
local radarVisible = true                    -- the HUD's wish for the native radar
local radarMode    = 'map'                   -- 'map' | 'compass' | 'off'

local function radarReplaced() return radarOwnerCount > 0 end

-- * How a replaced radar is hidden.
--     'display' (default)  DisplayRadar(false): the radar is down while a resource draws its own.
--     'type'               the radar stays on with its TYPE set to 0 (off), its own type put back afterwards.
--   ! 2026-11-03: 'type' was tried as the default to keep the game's health and stamina rings - and it does not:
--     in RedM radar type 0 takes the rings down too (the owner's test: with the type left at 0 no rings, and no
--     radar). And a type that was already 0 when the radar was taken was never put back, so stopping w_map left the
--     game with no radar at all. Back to 'display'; 'type' stays for a test, now always putting a type back.
--   Set with   setr w_lib:radarHide type   in server.cfg to try it.
local hideByType = GetConvar('w_lib:radarHide', 'display') == 'type'
local SetMinimapType, GetMinimapType = SetMinimapType, GetMinimapType
local typeBefore = nil   -- the radar type to put back (nil: we did not change it)
local lastType = 1       -- the last type other than 0 the radar had (1 = regular: never left at 0 by us)
do local ok, t = pcall(GetMinimapType); if ok and type(t) == 'number' and t ~= 0 then lastType = t end end

--- The radar's type off while it is replaced, its own type back once it is not.
local function holdType(replaced)
    if not hideByType then return end
    if replaced then
        local t = GetMinimapType()
        -- another script set a type while we hold it (VORP on mounting): that is the type to put back later
        if t ~= 0 then typeBefore, lastType = t, t; SetMinimapType(0)
        elseif typeBefore == nil then typeBefore = lastType end   -- it was 0 already: a type goes back anyway
    elseif typeBefore ~= nil then
        SetMinimapType(typeBefore)
        typeBefore = nil
    end
end

--- What the native radar should show right now, and show it.
local function applyRadar()
    local replaced = radarReplaced()
    if hideByType then
        DisplayRadar(radarVisible and radarMode ~= 'off')
        holdType(replaced)
    else
        DisplayRadar(radarVisible and radarMode ~= 'off' and not replaced)
    end
end

local function pump()
    if running or (live == 0 and not radarReplaced()) then return end
    running = true

    CreateThread(function()
        while live > 0 or radarReplaced() do
            Wait(0)
            for control, e in pairs(blocked) do
                DisableControlAction(0, control, true)
                if IsDisabledControlJustPressed(0, control) then
                    for event in pairs(e.press) do TriggerEvent(event, control) end
                end
            end
            -- a custom minimap owns the screen: the native one stays down whatever
            -- another script switched on this frame (by its type: the rings stay; or the old way, all of it)
            if radarReplaced() then
                if hideByType then holdType(true) else DisplayRadar(false) end
            end
        end
        running = false
    end)
end

--- احجب تحكُّمًا عن اللعبة، واسمع ضغطته.
---@param control number هاش التحكُّم، مثل `INPUT_MAP`
---@param pressEvent? string حدثٌ يُبعث لحظةَ الضغط (اختياريّ: بلا حدثٍ يكون حجبًا صرفًا)
function lib.blockControl(control, pressEvent)
    control = tonumber(control)
    if not control then return false end

    local e = blocked[control]
    if not e then
        e = { n = 0, press = {} }
        blocked[control] = e
        live = live + 1
    end
    e.n = e.n + 1
    if pressEvent then e.press[pressEvent] = GetInvokingResource() or 'w_lib' end

    pump()
    return true
end

--- ارفع الحجب. يُرفع فعلًا حين لا يبقى طالبٌ له.
---@param control number
---@param pressEvent? string
function lib.unblockControl(control, pressEvent)
    control = tonumber(control)
    local e = control and blocked[control]
    if not e then return false end

    if pressEvent then e.press[pressEvent] = nil end
    e.n = e.n - 1
    if e.n <= 0 then
        blocked[control] = nil
        live = live - 1
    end
    return true
end

--- هل التحكُّم محجوبٌ الآن؟ (للتشخيص)
---@param control number
function lib.isControlBlocked(control)
    return blocked[tonumber(control) or 0] ~= nil
end

-- ★ المورد الذي سجّل قد يتوقّف دون أن يرفع حجبه — فيُطوى عنه هنا، وإلّا بقي
--   المفتاح محجوبًا عن اللاعب إلى أن يعيد تشغيل اللعبة.
-- ════════════════════════════════════════════════════════════════════════════
-- The radar: one authority for the native minimap
--
-- ★ Three resources used to switch DisplayRadar on and off behind each other's back:
--   w_hud (hide the HUD, mount = compass), w_map (draws its own minimap and wants the
--   native one gone), the wheel (pins it visible while open). Whoever ran last in the
--   frame won, and the map flickered or vanished. So the decision is made here once:
--
--     replaceRadar(on)      a resource takes / releases the radar (it draws its own).
--                           While any owner holds it the native radar is kept down.
--     setRadarVisible(v)    the HUD's wish (hidden HUD = false). Honoured only when
--                           nobody replaced the radar and the mode is not 'off'.
--     setRadarMode(m)       'map' | 'compass' | 'off' -- announced once per change as
--                           the event w_lib:radarMode, so a custom minimap follows it.
--     setMinimapVisible(v)  / setMinimapExpanded(v) / setMinimapRotation(r)
--                           requests forwarded to the custom minimap as events
--                           (w_lib:minimap:visibility | expanded | rotation).
--
--   Owners are counted per resource, so a second map cannot release the first, and a
--   stopping owner releases itself. Stopping w_lib hands the native radar back.
-- ════════════════════════════════════════════════════════════════════════════

local function caller() return GetInvokingResource() or GetCurrentResourceName() end

--- Take (true) or give back (false) the radar for the calling resource.
---@param on boolean
---@return boolean replaced -- whether any owner remains
function lib.replaceRadar(on)
    local owner = caller()
    if on then
        if not radarOwners[owner] then
            radarOwners[owner] = true
            radarOwnerCount = radarOwnerCount + 1
        end
    elseif radarOwners[owner] then
        radarOwners[owner] = nil
        radarOwnerCount = radarOwnerCount - 1
    end
    applyRadar()
    pump()
    return radarReplaced()
end

function lib.isRadarReplaced() return radarReplaced() end

--- The HUD's wish for the native radar. false while the HUD is hidden.
---@param visible boolean
function lib.setRadarVisible(visible)
    radarVisible = visible ~= false
    applyRadar()
    return radarVisible
end

function lib.getRadarMode() return radarMode end

--- 'map' | 'compass' | 'off'. Unknown values are refused and change nothing.
---@param mode string
---@return boolean accepted
function lib.setRadarMode(mode)
    if mode ~= 'map' and mode ~= 'compass' and mode ~= 'off' then return false end
    if radarMode ~= mode then
        radarMode = mode
        TriggerEvent('w_lib:radarMode', mode)
    end
    applyRadar()
    return true
end

--- Ask the custom minimap to hide (false) / show (true) on behalf of the caller.
function lib.setMinimapVisible(visible)
    TriggerEvent('w_lib:minimap:visibility', caller(), visible ~= false)
    return true
end

function lib.setMinimapExpanded(expanded)
    TriggerEvent('w_lib:minimap:expanded', expanded == true)
    return true
end

--- 'camera' | 'player' | 'north'
function lib.setMinimapRotation(rotation)
    if rotation ~= 'camera' and rotation ~= 'player' and rotation ~= 'north' then return false end
    TriggerEvent('w_lib:minimap:rotation', rotation)
    return true
end

AddEventHandler('onClientResourceStop', function(resource)
    for control, e in pairs(blocked) do
        for event, owner in pairs(e.press) do
            if owner == resource then
                e.press[event] = nil
                e.n = e.n - 1
            end
        end
        if e.n <= 0 then
            blocked[control] = nil
            live = live - 1
        end
    end

    -- a stopping owner gives the radar back; the library stopping hands it to the game
    if resource == GetCurrentResourceName() then
        radarOwners, radarOwnerCount = {}, 0
        holdType(false)   -- its own type back
        DisplayRadar(true)
    elseif radarOwners[resource] then
        radarOwners[resource] = nil
        radarOwnerCount = radarOwnerCount - 1
        applyRadar()
    end
end)

-- The three above, as exports: the header of this file documents them that way, and a
-- resource that does not load @w_lib/init.lua has no `lib` to reach them through.
exports('blockControl', function(control, pressEvent) return lib.blockControl(control, pressEvent) end)
exports('unblockControl', function(control, pressEvent) return lib.unblockControl(control, pressEvent) end)
exports('isControlBlocked', function(control) return lib.isControlBlocked(control) end)

-- The radar API as exports too: a consumer's `w.setRadarVisible(...)` reaches w_lib through
-- init.lua's export proxy, and an unregistered export throws "No such export".
exports('replaceRadar',        function(on) return lib.replaceRadar(on) end)
exports('isRadarReplaced',     function() return lib.isRadarReplaced() end)
exports('setRadarVisible',     function(visible) return lib.setRadarVisible(visible) end)
exports('getRadarMode',        function() return lib.getRadarMode() end)
exports('setRadarMode',        function(mode) return lib.setRadarMode(mode) end)
exports('setMinimapVisible',   function(visible) return lib.setMinimapVisible(visible) end)
exports('setMinimapExpanded',  function(expanded) return lib.setMinimapExpanded(expanded) end)
exports('setMinimapRotation',  function(rotation) return lib.setMinimapRotation(rotation) end)
