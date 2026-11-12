--[[
    w_lib · resource/interface/client/pins.lua (4.5.0) -- numbered labels over the world, drawn in this frame

    The builders' pins (w_missions / w_jobs / w_heists: «1 بائع الجرائد» over the spot), shared. Arabic cannot be
    drawn with the game's font, so the label is NUI: Lua projects each spot (GetScreenCoordFromWorldCoord) ~25 times
    a second and the page places the tag. Exported (the page is w_lib's own, a consumer needs no ui_page):

        lib.setPins(key, pins, opts?)   show / replace one set of pins
            pins  { { id = 'npc', x =, y =, z? =, n? = 2, label = 'بائع الجرائد', sub? = '12 م',
                      state? = 'cur' | 'miss', lift? = 1.0 }, ... }   at most 150 a set
                  a pin with no x / y floats in front of the camera, side by side (a place still missing)
                  z missing = the ground under x / y; lift = metres over z (a ped 2.1, a wagon 2.6, a box 1.2)
            opts  { range = 150 (metres from the camera), near = 60 (farther ones are faded), aim = true }
        lib.clearPins(key)              remove the set
        lib.getAimedPin(key) -> id?     the pin nearest the screen's centre (aim sets only), for "J on a pin"

    ★ A set belongs to the calling resource (GetInvokingResource()) and goes when that resource stops.
    ★ Only what changed is sent; nothing runs while no set is shown.
]]

local sets = {}          -- [owner .. ':' .. key] = { owner, key, pins, range, near, aim, aimed }
local PIN_MS = 40
local MAX_PINS = 150

local function ownerOf()
    local r = GetInvokingResource()
    return (type(r) == 'string' and r ~= '') and r or cache.resource
end

local function num(v) return tonumber(v) end

local function clean(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, p in ipairs(list) do
        if #out >= MAX_PINS then break end
        if type(p) == 'table' and p.id ~= nil then
            local x, y = num(p.x), num(p.y)
            local c = p.coords
            if (not x or not y) and c ~= nil then
                local t = type(c)
                if t == 'vector3' or t == 'vector4' or t == 'table' then x, y = num(c.x), num(c.y) end
            end
            out[#out + 1] = {
                id = tostring(p.id):sub(1, 64),
                x = x, y = y, z = num(p.z) or (type(c) ~= 'nil' and num(c.z)) or nil,
                n = num(p.n) and math.floor(num(p.n)) or nil,
                label = type(p.label) == 'string' and p.label:sub(1, 80) or '',
                sub = type(p.sub) == 'string' and p.sub:sub(1, 40) or nil,
                state = (p.state == 'cur' or p.state == 'miss') and p.state or nil,
                lift = num(p.lift) or 1.0,
            }
        end
    end
    return out
end

---@param key string
---@param pins table[]
---@param opts? { range?: number, near?: number, aim?: boolean }
function lib.setPins(key, pins, opts)
    if type(key) ~= 'string' or key == '' then return end
    local owner = ownerOf()
    opts = type(opts) == 'table' and opts or {}
    local id = owner .. ':' .. key
    local old = sets[id]
    sets[id] = {
        owner = owner, key = key, pins = clean(pins),
        range = math.min(num(opts.range) or 150.0, 500.0),
        near = num(opts.near) or 60.0,
        aim = opts.aim ~= false,
        aimed = old and old.aimed or nil,
    }
end

---@param key string
function lib.clearPins(key)
    if type(key) ~= 'string' then return end
    sets[ownerOf() .. ':' .. key] = nil
end

---@param key string
---@return string?
function lib.getAimedPin(key)
    if type(key) ~= 'string' then return nil end
    local s = sets[ownerOf() .. ':' .. key]
    return s and s.aimed or nil
end

AddEventHandler('onResourceStop', function(resource)
    for id, s in pairs(sets) do
        if s.owner == resource then sets[id] = nil end
    end
end)

-- ── the frame ────────────────────────────────────────────────────────────────
local function yes(v) return v == true or v == 1 end

local function camera()
    local okC, cam = pcall(GetFinalRenderedCamCoord)
    local okR, rot = pcall(GetFinalRenderedCamRot, 2)
    if not okC or not cam or not okR or not rot then return nil end
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local flat = math.abs(math.cos(rx))
    return cam, vector3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx))
end

local function project(x, y, z)
    local ok, on, sx, sy = pcall(GetScreenCoordFromWorldCoord, x + 0.0, y + 0.0, z + 0.0)
    if not ok or not yes(on) or not sx or not sy then return nil end
    if sx < -0.05 or sx > 1.05 or sy < -0.05 or sy > 1.05 then return nil end
    return sx, sy
end

local function ground(p)
    if p.gz ~= nil then return p.gz end
    local ok, found, gz = pcall(GetGroundZFor_3dCoord, p.x + 0.0, p.y + 0.0, 1000.0, false)
    p.gz = (ok and yes(found) and gz) or false
    return p.gz
end

local function round(v) return math.floor(v * 1000 + 0.5) / 1000 end

local function pass()
    local cam, dir = camera()
    if not cam then return {} end
    local out = {}
    for setId, s in pairs(sets) do
        local floating, best, bestD = 0, nil, 0.06
        for _, p in ipairs(s.pins) do
            local sx, sy, far
            if not p.x or not p.y then
                floating = floating + 1
                local side = ((floating % 2 == 0) and 1 or -1) * math.ceil(floating / 2) * 1.6
                local px = cam.x + dir.x * 7.0 - dir.y * side
                local py = cam.y + dir.y * 7.0 + dir.x * side
                sx, sy = project(px, py, cam.z + dir.z * 7.0 - 0.6 - (floating % 3) * 0.35)
            else
                local d = math.sqrt((p.x - cam.x) ^ 2 + (p.y - cam.y) ^ 2)
                if d <= s.range then
                    local z = p.z or ground(p)
                    if not z then z = cam.z - 1.6 end
                    sx, sy = project(p.x, p.y, z + p.lift)
                    far = d > s.near
                    if sx and s.aim then
                        local c = math.sqrt((sx - 0.5) ^ 2 + ((sy - 0.5) * 0.6) ^ 2)
                        if c < bestD then best, bestD = p.id, c end
                    end
                end
            end
            if sx then
                out[#out + 1] = { k = setId .. ':' .. p.id, id = p.id, x = round(sx), y = round(sy), n = p.n,
                    label = p.label, sub = p.sub, st = p.state, far = far or nil }
            end
        end
        s.aimed = s.aim and best or nil
        if best then
            for i = #out, 1, -1 do
                local o = out[i]
                if o.id == best and o.k == setId .. ':' .. best then o.aim = true break end
            end
        end
    end
    return out
end

CreateThread(function()
    local last = ''
    while true do
        if next(sets) then
            local ok, pins = pcall(pass)
            if ok then
                local sig = json.encode(pins)
                if sig ~= last then
                    last = sig
                    SendNUIMessage({ action = 'wl:pins', data = { pins = pins } })
                end
            end
            Wait(PIN_MS)
        else
            if last ~= '' and last ~= '[]' then
                last = '[]'
                SendNUIMessage({ action = 'wl:pins', data = { pins = {} } })
            end
            Wait(400)
        end
    end
end)
