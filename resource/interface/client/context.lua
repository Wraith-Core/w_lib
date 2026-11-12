--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local contextMenus = {}
local openContextMenu = nil

---@class ContextMenuItem
---@field title? string
---@field menu? string
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string
---@field image? string
---@field progress? number
---@field onSelect? fun(args: any)
---@field arrow? boolean
---@field description? string
---@field metadata? string | { [string]: any } | string[]
---@field disabled? boolean
---@field readOnly? boolean
---@field event? string
---@field serverEvent? string
---@field args? any
---@field where? string 4.5.0: a place line under the row ("فالنتاين · 12 م منك")
---@field whereMiss? boolean 4.5.0: draw the place line as missing
---@field coords? vector3|{x:number,y:number,z?:number} 4.5.0: a place; turned into `where` (lib.place) when no `where`

---@class ContextMenuArrayItem : ContextMenuItem
---@field title string

---@class ContextMenuProps
---@field id string
---@field title string
---@field menu? string
---@field onExit? fun()
---@field onBack? fun()
---@field canClose? boolean
---@field options { [string]: ContextMenuItem } | ContextMenuArrayItem[]
---@field subtitle? string 4.5.0: a quiet line at the top of the card
---@field keys? { key: string, label?: string }[] 4.5.0: the keys row at the bottom (default: Esc close, Backspace back)

local function closeContext(_, cb, onExit)
    if cb then cb(1) end

    lib.resetNuiFocus()

    if not openContextMenu then return end

    if (cb or onExit) and contextMenus[openContextMenu].onExit then contextMenus[openContextMenu].onExit() end

    if not cb then SendNUIMessage({ action = 'hideContext' }) end

    openContextMenu = nil
end

--- 4.5.0: an option that names a place (`coords`) and no `where` gets the place in words. The option is copied for
--- the page (the registered menu keeps its own table) and `coords` stays out of the message (a vector does not
--- encode as JSON).
local function forPage(options)
    if type(options) ~= 'table' then return options end
    local out, changed = {}, false
    for k, opt in pairs(options) do
        if type(opt) == 'table' and opt.coords ~= nil then
            local copy = {}
            for f, v in pairs(opt) do copy[f] = v end
            copy.coords = nil
            if copy.where == nil then
                local ok, d = pcall(function() return lib.place.describe(opt.coords) end)
                if ok and type(d) == 'table' then copy.where = d.text end
            end
            out[k], changed = copy, true
        else
            out[k] = opt
        end
    end
    return changed and out or options
end

---@param id string
function lib.showContext(id)
    if not contextMenus[id] then error('No context menu of such id found.') end

    local data = contextMenus[id]
    openContextMenu = id

    lib.setNuiFocus(false)

    SendNuiMessage(json.encode({
        action = 'showContext',
        data = {
            title = data.title,
            canClose = data.canClose,
            menu = data.menu,
            options = forPage(data.options),
            subtitle = data.subtitle,
            keys = data.keys,
        }
    }, { sort_keys = true }))
end

---@param context ContextMenuProps | ContextMenuProps[]
function lib.registerContext(context)
    for k, v in pairs(context) do
        if type(k) == 'number' then
            contextMenus[v.id] = v
        else
            contextMenus[context.id] = context
            break
        end
    end
end

---@return string?
function lib.getOpenContextMenu() return openContextMenu end

---@param onExit boolean?
function lib.hideContext(onExit) closeContext(nil, nil, onExit) end

RegisterNUICallback('openContext', function(data, cb)
    if data.back and contextMenus[openContextMenu].onBack then contextMenus[openContextMenu].onBack() end
    cb(1)
    lib.showContext(data.id)
end)

RegisterNUICallback('clickContext', function(id, cb)
    cb(1)

    if math.type(tonumber(id)) == 'float' then
        id = math.tointeger(id)
    elseif tonumber(id) then
        id += 1
    end

    local data = contextMenus[openContextMenu].options[id]

    if not data.event and not data.serverEvent and not data.onSelect then return end

    openContextMenu = nil

    SendNUIMessage({ action = 'hideContext' })
    lib.resetNuiFocus()

    if data.onSelect then data.onSelect(data.args) end
    if data.event then TriggerEvent(data.event, data.args) end
    if data.serverEvent then TriggerServerEvent(data.serverEvent, data.args) end
end)

RegisterNUICallback('closeContext', closeContext)



