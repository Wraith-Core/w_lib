local activeTexts = {}
local active2DText = false
-- a 2D text is on screen: only then does the sweeper below have one to take away (it sent removeText2D ten
-- times a second for ever, with nothing drawn)
local shown2DText = false


function DrawText3D(x, y, z, text, customId)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        local id = customId or (tostring(x) .. tostring(y) .. tostring(z))
        -- إرسال البيانات إلى NUI
        SendNUIMessage({
            action = "drawText3D",
            data = {
                id = id, -- معرّف فريد لكل نص
                x = _x,
                y = _y,
                text = text
            }
        })
        activeTexts[id] = true
    end
end

-- عرض النص ثنائي الأبعاد
function DrawText2D(text)
    -- إرسال النص إلى NUI ليتم عرضه
    SendNUIMessage({
        action = "drawText2D",
        data = { text = text }
    })
    active2DText = true
    shown2DText = true
end

--- الصوت الافتراضي للإشعار — من أصوات اللعبة نفسها
--
-- ★ RDR2's own notice chime, not a file we ship. Ledger_Sounds/INFO_SHOW is what the game
--   plays for the small tip that appears at the side of the screen -- the very thing this
--   notice is. bln_notify's TIP template pairs the same two values with useBackground = false
--   and placement = 'middle-right', which is this notice exactly.
--
-- ⚠️ It has to be played from LUA, not from the NUI frame. An <audio> element in the browser
--    is mixed by CEF and ignores the player's in-game audio settings, so it stays loud when
--    they have turned the game down -- and it would mean shipping someone else's mp3. The
--    native reads the sound out of the game's own audio bank at the player's own volume.
local NOTIFY_SOUND, NOTIFY_SOUNDSET = 'INFO_SHOW', 'Ledger_Sounds'

--- لافتة القانون (مطلوب / شاهد) — صوت أشدّ
--
-- ★ A bounty is not an item of news, so it does not get the news chime. Objective_Sounds/FAIL
--   is the game's own "this went against you" sting and is in the confirmed soundset list.
--
-- ⚠️ Still overridable per call: pass `sound`/`soundSet` to pick another, or `sound = false`
--    to silence one. This is only the default when the caller says nothing.
local LAW_SOUND, LAW_SOUNDSET = 'FAIL', 'Objective_Sounds'

--- لافتة البلدة — صوت فتح القائمة نفسه
--
-- ★ HUD_PLAYER_MENU/MENU_ENTER is the game's own menu-open sound -- the same one the player
--   hears every time an interface comes up, which is what a place announcing itself should
--   sound like. The plain notice keeps the quieter Ledger chime: a tip is not an arrival.
local BANNER_SOUND, BANNER_SOUNDSET = 'MENU_ENTER', 'HUD_PLAYER_MENU'

--- ⚠️ السطر الثالث من المستدعي لا من هنا
--
-- ★ The library DRAWS the readings line; it does not decide what is in it. w_zonenotify builds
--   the clock, the temperature and the wind because it owns the settings for them -- which of
--   the three to show, the cold threshold, the colours. Building a second copy here would mean
--   two places deciding what a banner says, and they would drift.
--
-- A caller that sends no `meta` simply gets a banner without a third line, which is a perfectly
-- good banner.


-- ════════════════════════════════════════════════════════════════════════════
-- One place on the screen for every notice
--
-- ★ The server runs a dozen notification systems (VORP's natives, rakan_notify, bln,
--   hawk, rsd, ox_lib ...) and each picked its own corner: left, top, bottom-right.
--   The order was: everything through THIS renderer, everything at the right-centre.
--   So the placement a caller asks for is overruled here, once, rather than in every
--   caller. Set FORCED_PLACEMENT = nil to honour callers again.
--
--   The bridges at the bottom of this file catch the old systems' events and exports'
--   callers cannot be edited (escrowed scripts), so their notices arrive here too.
-- ════════════════════════════════════════════════════════════════════════════
local FORCED_PLACEMENT = 'middle-right'

--- Text in the game's ~COLOR_X~ / ~#hex~ / ~e~ markup would show as raw tildes in the
--- HTML frame: strip the tokens, keep the words.
local function plain(text)
    text = tostring(text or '')
    text = text:gsub('~key:([%w_]+)[^~]*~', '[%1]') -- bln's key chip: keep the key the player must press
    text = text:gsub('~[^~%s]+~', '')                 -- every other ~token~: colours, ~e~, ~img:x~, ~size:..~
    return text
end

-- ★ 2026-09-18: the frame draws an icon by name from its own texture list (web/build/tex/ui);
--   a name it does not have falls back to `menu_bar` -- a horizontal LINE. 'warning' was not in
--   that list, so every info / warning notice (the default style, and everything VORP and the
--   SIREC scripts send) showed "text ———" instead of a state icon. warning.png and info.png
--   were added to the frame, and every name that reaches Notify is checked against the list.
local STYLE_ICON  = { success = 'tick', error = 'cross', info = 'info', warning = 'warning', inform = 'info', primary = 'info' }
-- ⚠️ Monochrome by request (paper, never #fff -- w_lib/nui/theme/tokens.css): the notice is text in paper, so a per-style hue
--    (blue/green/red/orange) was the only colour left on it and read as noise. The STYLE word still
--    picks the ICON, which is what distinguishes success from error now.
local STYLE_COLOR = { success = '#f2f2f2', error = '#f2f2f2', info = '#f2f2f2', warning = '#f2f2f2', inform = '#f2f2f2', primary = '#f2f2f2' }

--- The frame's texture names (web/build/assets/index-*.js, `nl["tex/ui"]` + `nl["tex/blips"]`).
--- Keep in step with that list when a texture is added to web/build/tex.
local KNOWN_ICON = {}
for _, name in ipairs({
    'crafting_highlight_t', 'crafting_highlight_b', 'crafting_highlight_l', 'crafting_highlight_r', 'crafting_highlight_tl',
    'crafting_highlight_tr', 'crafting_highlight_bl', 'crafting_highlight_br', 'crafting_outline', 'divider_line', 'title_divider',
    'vertical_divider_line', 'list_item_h_line_narrow', 'menu_header_1a', 'selection_box_bg_1a', 'selection_box_bg_1c', 'toast_bg',
    'help_text_bg', 'lock', 'menu_icon_rank', 'star', 'rating_star', 'cross', 'tick', 'selection_arrow_left', 'selection_arrow_right',
    'weapon_stats_bar', 'weapon_stats_bar_mask', 'menu_bar', 'swatch_bg_1a', 'counter_bg_1a', 'warning', 'info',
    'blip_campfire', 'blip_shop_blacksmith', 'blip_ammo_bullets', 'blip_shop_gunsmith', 'blip_camp_tent', 'blip_camp', 'blip_time_of_day',
}) do KNOWN_ICON[name] = true end

--- The game's own texture names callers pass (VORP's NotifyLeft dict/icon pairs, bln, rakan...)
--- mapped onto what the frame can draw; anything else becomes the state icon.
local ICON_ALIAS = {
    check = 'tick', checkmark = 'tick', tick_box = 'tick', accept = 'tick',
    x = 'cross', cancel = 'cross', close = 'cross', fail = 'cross', deny = 'cross',
    alert = 'warning', caution = 'warning', danger = 'warning', exclamation = 'warning',
    information = 'info', question = 'info', help = 'info', tip = 'info', message = 'info', mail = 'info', telegram = 'info',
    dollar = 'menu_icon_rank', money = 'menu_icon_rank', cash = 'menu_icon_rank', rank = 'menu_icon_rank',
    stars = 'star', award = 'star', medal = 'star', rating = 'rating_star',
    warning_icon = 'warning',
}

--- An icon the frame can draw, or the style's own: never a name that ends as the fallback line.
local function drawableIcon(icon, style)
    local fallback = STYLE_ICON[tostring(style or 'info'):lower()] or 'info'
    if type(icon) ~= 'string' or icon == '' then return fallback end
    local lower = icon:lower()
    if lower:find('://', 1, true) or lower:find('.png', 1, true) or lower:find('.webp', 1, true) then return icon end -- an image path
    if KNOWN_ICON[lower] then return lower end
    return ICON_ALIAS[lower] or fallback
end

--- The shape every legacy bridge below builds: title + message + a style word.
---@param title string|nil
---@param message string|nil
---@param style string|nil  success | error | info | warning
---@param duration number|nil
local function styled(title, message, style, duration)
    style = tostring(style or 'info'):lower()
    Notify({
        title            = plain(title),
        description      = plain(message),
        icon             = STYLE_ICON[style] or 'info',
        style            = style,
        duration         = tonumber(duration) or 5000,
        titleColor       = STYLE_COLOR[style] or '#f2f2f2',
        isRTL            = true,
        contentAlignment = 'center',
        useBackground    = false,
    })
end

-- إنشاء إشعار
function Notify(data)
    if type(data) ~= 'table' then data = { description = tostring(data or '') } end
    -- ⚠️ Notices only. A town banner (useBackground) is not a notice: the game draws its own
    --    location feed at the top-left, and ours is meant to stand in for it, so it keeps the
    --    placement the caller chose (w_zonenotify Config.Placement) instead of the notice corner.
    if FORCED_PLACEMENT and not data.useBackground then data.placement = FORCED_PLACEMENT end
    -- every notice carries a state icon the frame can draw: a given name is checked against the
    -- frame's list, a plain notice with none gets its style's icon; a town banner (its own plate,
    -- no icon by design), the law banner and a notice with an item image are left as they are
    if not data.image then
        if type(data.icon) == 'string' and data.icon ~= '' then
            data.icon = drawableIcon(data.icon, data.style)
        elseif not data.useBackground and data.variant ~= 'law' then
            data.icon = drawableIcon(nil, data.style)
        end
    end
    -- `sound = false` silences one notice; a string picks another from the game's banks.
    local law = data.variant == 'law'
    local banner = data.useBackground and not law

    if data.sound ~= false then
        local sound, soundSet = NOTIFY_SOUND, NOTIFY_SOUNDSET

        if law then
            sound, soundSet = LAW_SOUND, LAW_SOUNDSET
        elseif banner then
            sound, soundSet = BANNER_SOUND, BANNER_SOUNDSET
        end

        PlaySoundFrontend(data.sound or sound, data.soundSet or soundSet, true, 0)
    end

    -- The caller's readings line, if it sent one.
    local meta = data.meta

    --[[
        ⚠️ الحمولة تحت `data`، لا مسطّحة بجانب `action`.

           ★ The NUI app's message hook is  const {action, data} = event.data  -- it hands the
             handler event.data.DATA, never the message itself. A payload written flat beside
             `action` arrives as `undefined`, and the notify handler pushes {...undefined} = {}
             into the list: a note with no title, no description and no plate. `.wn-note` has no
             background of its own, so that empty note renders as NOTHING.

           ⚠️ And the sound still plays, because PlaySoundFrontend above is Lua and never asked
              the frame anything. Chime with no banner is exactly what a flat payload looks like
              from the player's seat -- which is why this reads as "w_lib is broken" rather than
              as a message that was never delivered.

        This module came from the standalone w_notify, whose own frame read the flat fields.
        Every other w_lib module already nests: locale, alert, clipboard, input.
    ]]
    SendNUIMessage({
        action = "showNotification",
        data = {
            title = data.title or "",
            description = data.description or "",
            icon = data.icon or "",
            placement = data.placement or "middle-right",
            duration = data.duration or 5000,
            useBackground = data.useBackground or false,
            -- صورة الايتم بدل الأيقونة عند الحاجة (nui://<resource>/...png)؛ الواجهة تُخفيها لو تعذّر تحميلها
            image = data.image or nil,
            -- 'law' → لافتة المطلوب: اسم أحمر فوق خطّ أبيض
            variant = data.variant,
            meta = meta or nil,
            contentAlignment = data.contentAlignment or "center",
            isRTL = data.isRTL or false,
            titleColor = data.titleColor or "#f2f2f2",
            -- ⚠️ This default was pushed INLINE by index.tsx, so it beat every stylesheet rule and
            --    made the body text 80% white on a transparent notice — the "باهت" the player saw.
            --    Full white now; the stylesheet (.wn-desc) still owns the look when a caller sends none.
            descriptionColor = data.descriptionColor or "#f2f2f2"
        }
    })
end

-- إزالة النصوص غير النشطة
CreateThread(function()
    while true do
        Wait(100)
        for id, active in pairs(activeTexts) do
            if not active then
                SendNUIMessage({
                    action = "removeText3D",
                    data = { id = id }
                })
                activeTexts[id] = nil
            else
                activeTexts[id] = false
            end
        end

        if not active2DText and shown2DText then
            SendNUIMessage({
                action = "removeText2D"
            })
            shown2DText = false
        end
        active2DText = false
    end
end)

-- RegisterNetEvent("RK-text:DrawText3D")
-- AddEventHandler("RK-text:DrawText3D", function(x, y, z, text)
--     exports['w_notify']:DrawText3D(x, y, z, text)
-- end)

-- RegisterNetEvent("RK-text:DrawText2D")
-- AddEventHandler("RK-text:DrawText2D", function(text)
--     DrawText2D(text)
-- end)

-- exports['w_notify']:DrawText3D(x, y, z, text)

-- TriggerEvent('RK-text:DrawText2D', text)

-- تعريف الحدث
RegisterNetEvent("RK-text:send")
AddEventHandler("RK-text:send", function(data)
    Notify(data)
end)


-- exports['w_notify']:DrawText2D()
-- exports['w_notify']:DrawText3D()
-- exports['w_notify']:Notify()


exports("DrawText2D", DrawText2D)
exports("DrawText3D", DrawText3D)
exports("NotifyStyled", styled)

-- ════════════════════════════════════════════════════════════════════════════
-- The old systems' doors, kept open, all leading here
--
--   rakan_notify   TriggerEvent('rakan_notify', 'notify', text, style, duration, position, icon)
--   hawk           TriggerEvent('hawk_sp_noti', message, style)
--   ox_lib style   TriggerEvent('ox_lib:notify', { title, description, type, duration })
--                  (only when the ox_lib resource itself is not running; it forwards here otherwise)
--   VORP           vorp:Tip / vorp:TipRight / ... are answered inside vorp_core, which forwards here.
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('rakan_notify', function(kind, text, style, duration, _position, _icon)
    if kind ~= nil and type(kind) ~= 'string' then return end
    if kind and kind ~= 'notify' and text == nil then text, kind = kind, 'notify' end
    styled(nil, text, style, duration)
end)

RegisterNetEvent('hawk_sp_noti', function(message, style)
    styled(nil, message, style, 5000)
end)

RegisterNetEvent('ox_lib:notify', function(data)
    if GetResourceState('ox_lib') == 'started' then return end -- ox_lib forwards to us itself
    if type(data) ~= 'table' then return end
    styled(data.title, data.description, data.type, data.duration)
end)
-- منخفض المستوى (data table) — يستدعيه w.notify؛ اسم Notify محجوز لصيغة w_lib المريحة
exports("NotifyRaw", Notify)
