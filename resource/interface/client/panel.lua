--[[
    لوحة عامّة — قالب الكرافتنج لكلّ السكربتات

    ★ THE POINT: every interface on this server is the same shape -- a titled panel, a list of
      things, the selected thing in detail, and a row of actions. w_crafting already draws that
      well. Rather than each resource building its own React app, its own build step and its own
      NUI frame, a resource describes what it wants and gets that interface.

    ⚠️ The description crosses the NUI boundary, so it can carry no functions -- the same limit
       that makes the context menu use `event` + `args`. Every action is an id, and it comes back
       through onAction. Anything that changes while the panel is open is sent as a new
       description with lib.showPanel again; the UI keeps the player's place in the list.
]]

local panel = nil

--- Run a handler that may be a function OR the name of an event.
---
--- ★ WHY BOTH: this file runs inside w_lib. A resource that calls lib.showPanel is calling an
---   EXPORT, and exports serialise their arguments -- a function does not survive that trip, so
---   `onAction = function() end` written in another resource arrives here as nil and every
---   button in the panel is dead with nothing printed to say why. The context menu already hit
---   this and answered it the same way (`event` beside `onSelect`), so a panel described from
---   w_crafting passes 'w_crafting:admin:action' and keeps its handler where it was written.
---
--- ⚠️ A function still works, and is still the right thing for a caller inside w_lib itself.
---    The type check is what lets one field serve both without the caller thinking about it.
local function fire(handler, ...)
    local kind = type(handler)

    if kind == 'function' then return handler(...) end
    if kind == 'string' then return TriggerEvent(handler, ...) end
end

---@class PanelMeta
---@field label string
---@field value? string|number
---@field progress? number   0-100, drawn as a bar instead of a value

---@class PanelItem
---@field id string|number
---@field title string
---@field description? string
---@field icon? string        a texture name, a blip, or an image url
---@field image? string
---@field disabled? boolean
---@field group? string       consecutive items sharing a group sit under one heading
---@field meta? PanelMeta[]
---@field detail? { title?: string, image?: string, description?: string, stats?: PanelMeta[], rows?: PanelMeta[] }

---@class PanelAction
---@field id string
---@field label string
---@field icon? string
---@field primary? boolean    Enter runs this one
---@field disabled? boolean

---@class PanelNavItem
---@field id string
---@field label string
---@field icon? string
---@field image? string
---@field description? string   a second line under the label
---@field count? number|string
---@field disabled? boolean

---@class PanelNavGroup
---@field id? string            fold state is keyed on this; falls back to label
---@field label? string
---@field private? boolean      🔒 on the heading and a red edge down its side
---@field levelLabel? string    printed beside the count — 'المستوى 15'
---@field scope? string         which of `tabs` shows this group; unscoped shows under all
---@field expanded? boolean     open on arrival (default: the first group)
---@field items PanelNavItem[]

---@class PanelProps
---@field id? string
---@field title? string
---@field subtitle? string
---@field icon? string
---@field logo? string
---@field theme? string
---@field search? boolean
---@field searchPlaceholder? string
---@field items? PanelItem[]
---@field actions? PanelAction[]
---@field hints? { key: string, label: string }[]
---@field nav? PanelNavGroup[]
---@field activeNav? string
---@field navCountLabel? string  the unit tallied under the tabs — 'وصفة'; omitted, no tally
---@field aside? string
---@field emptyText? string
--- ★ Every handler below takes a FUNCTION or AN EVENT NAME. A caller inside w_lib passes a
---   function; a caller in another resource passes an event name, because lib.showPanel reaches
---   this file as an export and exports serialise their arguments -- a function would arrive nil
---   and the control would be silently dead. See `fire` above.
---@field onSelect? fun(itemId: string|number)|string
---@field onAction? fun(actionId: string, itemId: string|number|nil, amount: number|nil)|string
---@field onTab? fun(tabId: string)|string
---@field onNav? fun(navId: string)|string
---@field onField? fun(fieldId: string, value: any)|string
---@field onCancel? fun()|string
--- onAction receives the amount when the action asked for one.
---@field onClose? fun()|string

---Open the panel, or replace what is in it.
---@param data PanelProps
function lib.showPanel(data)
    if type(data) ~= 'table' then
        error('lib.showPanel expects a table')
    end

    panel = data
    -- TEMP TRACE (the open sound heard every few minutes): who draws a panel
    print(('[w_lib trace] showPanel id=%s from %s'):format(tostring(data.id), tostring(GetInvokingResource())))

    -- ⚠️ The callbacks are stripped before the table crosses to the frame. json.encode turns a
    --    function into null and the UI would receive three dead keys; keeping them here means
    --    the description that travels is only data.
    SendNUIMessage({
        action = 'showPanel',
        data = {
            id = data.id,
            title = data.title,
            subtitle = data.subtitle,
            icon = data.icon,
            logo = data.logo,
            theme = data.theme,
            search = data.search,
            searchPlaceholder = data.searchPlaceholder,
            items = data.items or {},
            actions = data.actions,
            hints = data.hints,
            aside = data.aside,
            emptyText = data.emptyText,
            statsLabel = data.statsLabel,
            tabs = data.tabs,
            activeTab = data.activeTab,
            progress = data.progress,
            -- ★ العدّ التنازليّ — ثوانٍ، تعدّها الواجهة وحدها
            --
            -- ⚠️ Send it ONCE. The frame ticks it down itself, so a script must not push a new
            --    description every second to move the digits -- with twenty auction lots that is
            --    twenty redraws a second and the list rebuilds while the player reads it. Send a
            --    fresh description when something REAL changes: a new bid, a lot sold, stock gone.
            countdown = data.countdown,

            -- ★ التركيب — القائمة الجانبيّة والكتل
            --
            -- `nav` turns the browser column into grouped navigation; `blocks` replaces the
            -- fixed detail pane with whatever the script composes. Together they are what let
            -- one panel be an admin console, a marketplace, a cinema desk or a kingdom ledger
            -- without any of them shipping a frame of its own.
            -- ★ nav هو متصفّح w_crafting نفسه — تبويبات، عدّاد، مجموعات تنطوي
            --
            -- A nav group is a crafting category: `label`, and `private` for the lock and the
            -- red edge, `levelLabel` for the level printed beside the count, `scope` to put it
            -- behind one of `tabs`, `expanded` to have it open on arrival.
            --
            -- ⚠️ Folding and tab-switching are answered in the frame, NOT here. A round trip per
            --    fold would put a frame of lag on a control the reader drags their eye down, and
            --    the description already said what the sections are. `onTab` still fires for a
            --    script that wants to load a tab's rows on demand; ignoring it is normal.
            nav = data.nav,
            navFit = data.navFit,   -- the side column only as wide as its widest row
            activeNav = data.activeNav,
            navCountLabel = data.navCountLabel,
            blocks = data.blocks,
        }
    })

    -- ⚠️ lib.setNuiFocus, not the raw native: it remembers whether input was being kept
    --    before the panel opened, which is what lib.resetNuiFocus restores on the way out.
    --    Calling SetNuiFocus directly leaves that state stale and the next resource to
    --    close a frame hands the player back the wrong input mode.
    lib.setNuiFocus(false, false)
end

---Close it from script, without the player having asked.
function lib.hidePanel()
    if not panel then return end

    panel = nil
    SendNUIMessage({ action = 'hidePanel' })
    lib.resetNuiFocus()
end

---@return boolean
function lib.panelActive() return panel ~= nil end

RegisterNUICallback('panelSelect', function(itemId, cb)
    cb(1)
    if panel then fire(panel.onSelect, itemId) end
end)

RegisterNUICallback('panelAction', function(data, cb)
    cb(1)
    if panel then fire(panel.onAction, data.action, data.item, data.amount) end
end)

RegisterNUICallback('panelTab', function(tabId, cb)
    cb(1)
    if panel then fire(panel.onTab, tabId) end
end)

RegisterNUICallback('panelNav', function(navId, cb)
    cb(1)
    if panel then fire(panel.onNav, navId) end
end)

--- ⚠️ Fires on EVERY keystroke in a text field. Use it to keep your own state, not to send
---    the panel back -- rebuilding the description on each character would take the field out
---    from under the player's cursor mid-word.
RegisterNUICallback('panelField', function(data, cb)
    cb(1)
    if panel then fire(panel.onField, data.id, data.value) end
end)

RegisterNUICallback('panelCancel', function(_, cb)
    cb(1)
    if panel then fire(panel.onCancel) end
end)

RegisterNUICallback('panelClose', function(_, cb)
    cb(1)

    -- ★ Read and cleared BEFORE the handler runs. A close handler that opens another panel is a
    --   normal thing to write, and it must not be undone by this function tidying up after it.
    local closing = panel

    panel = nil
    lib.resetNuiFocus()

    if closing then fire(closing.onClose) end
end)
