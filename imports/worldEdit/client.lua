--[[
    w_lib · imports/worldEdit/client.lua (4.5.0) -- build in the world: the builders' world mode, shared

    The world mode of w_missions / w_jobs / w_heists (owner 2026-11-12: «ماذا يحدث هنا؟» everywhere), as one loop any
    admin board can run. The board stays the caller's (its own page or a lib.showPanel); this draws what the board
    holds where it stands, and turns the keys pressed in the world into the caller's callbacks. Nothing is saved
    here: every change is a callback, the caller keeps its data (and its undo).

        local edit = lib.worldEdit.start({
            key      = 'farm',                          -- the pins set (default: the resource name)
            title    = 'ماذا يحدث هنا؟',                -- the ground menu's title (default: w_lib's words)
            subtitle = 'مزرعة كاليغا' | function() end, -- a quiet line in that menu
            items    = { ... },                         -- or edit:setItems(items) later
            ground   = function(at) return { { title, description?, icon?, onSelect = function(at) end }, ... } end,
            onMove   = function(item, spot) end,        -- spot: vector4 from the w_lib placer (J places)
            onTurn   = function(item, heading) end,     -- the wheel (±15°) and «لفّه نحوي»
            onRadius = function(item, radius) end,      -- Q / Z (±1 m)
            onRemove = function(item) end,              -- DELETE and «احذفه»
            onOpen   = function(item) end,              -- «افتح الخطوة»: the caller shows the step (world mode ends)
            pinMenu  = function(item, options) return options end,   -- change the J-on-a-pin menu (optional)
            onUndo   = function() end,                  -- Ctrl+Z
            onBoard  = function() end,                  -- TAB in the world: world mode ended, show the board again
            onStop   = function(reason) end,
            range = 150, ghostRange = 120, maxGhosts = 24, near = 60,
        })
        edit:setItems(items)   edit:setWorld(true|false)   edit:isWorld()   edit:stop()

    items: { { id = 'npc', n? = 1, label = 'بائع الجرائد', x, y, z?, h?, r? = 2.5, model? = 'u_m_m_...',
               kind? = 'ped' | 'object' | 'vehicle' | 'point', state? = 'cur' | 'miss', turn? = true, move? = true } }
      a ped / object / vehicle with a model stands as a see-through local ghost (within ghostRange, at most maxGhosts)
      r draws a ring on the ground (lib.glow, polygons); state 'miss' (no x / y) floats in front of the camera
      turn = the wheel turns it, move = «حرّكه» in its menu (default: true when onMove is given)

    Board mode (setWorld(false), the default after start): pins, ghosts and rings are drawn; the keys are the board's.
    World mode (setWorld(true)): the game gets the controls back (the caller drops its NUI focus); the w_lib placer
    look: key cards bottom-right (w.prompt.createGroup) + a line bottom-centre (lib.showTextUI), the walk-up claim,
    and these keys (fire, aim and the weapon wheel are off):
        J on the ground      the context menu «ماذا يحدث هنا؟» with the caller's `ground` options
        J on a pin           حرّكه · لفّه نحوي · احذفه · افتح الخطوة (each only when its callback is given)
        the mouse wheel      turns the aimed thing · Q / Z its circle · DELETE removes it · Ctrl+Z undo · TAB board
    ★ The interaction key is J, never E (E grabs the nearby player in RDR2).
    ★ Menu rows carry an event name (the context menu draws in w_lib's frame); the picked row's function runs here.
    ★ Ends by itself when the resource stops; edit:stop() removes the pins, ghosts, cards and the line.
]]

local worldEdit = {}

local KEY = { J = 0xF3830D8E, Q = 0xDE794E3E, Z = 0x26E9DC00, DEL = 0x4AF4D473 }
local BLOCK = { 0xAC4BD4F1, 0x07CE1E61, 0xF84FA74F, KEY.J, KEY.Q, KEY.Z, KEY.DEL }   -- the weapon wheel, fire, aim, ours
local TAB_GAP_MS = 300
local KINDS = { ped = true, object = true, vehicle = true, wagon = true, point = true }

local resName = GetCurrentResourceName()
local live = {}          -- every running edit of this resource (stopped on resource stop)
local seq = 0

local DISABLE_NATIVE_PROMPTS = 0xF1622CE88A1946FB   -- _UI_PROMPT_DISABLE_PROMPTS_THIS_FRAME (as the placer)

local function yes(v) return v == true or v == 1 end
local function now() return GetGameTimer() end

-- a module of the w layer (w.prompt, w.placer), or nil (never an export wrapper function)
local function mod(name)
    local ok, m = pcall(function()
        local W = rawget(_G, 'w')
        return W and W[name]
    end)
    return (ok and type(m) == 'table') and m or nil
end

-- w_lib's own words (locales "worldedit"), read once from its export; English when missing
local EN = {
    what = 'What happens here?', key_here = 'Put here', key_edit = 'Edit', key_board = 'Board',
    key_bigger = 'Bigger circle', key_smaller = 'Smaller circle', key_remove = 'Remove',
    line = 'Look at a spot and press J, or look at a marker to edit it',
    line_pin = 'Wheel turns, Q and Z change the circle, DELETE removes, J for options',
    move = 'Move it', move_d = 'Put it somewhere new', face = 'Turn it to me', face_d = 'It will face you',
    remove = 'Remove it', remove_d = 'It goes from here', open = 'Open the step', open_d = 'Back to the board on this step',
    pin = 'Marker', place = 'Put here',
}
local words
local function word(k)
    if not words then
        local ok, got = pcall(function() return exports.w_lib:worldEditWords() end)
        words = (ok and type(got) == 'table') and got or {}
    end
    local v = words[k]
    if type(v) ~= 'string' or v == '' or v == k then v = EN[k] or k end
    return v
end
AddEventHandler('w_lib:setLocale', function() words = nil end)

local function exists(e) return e ~= nil and e ~= 0 and yes(DoesEntityExist(e)) end

local function me()
    local ok, c = pcall(function() return GetEntityCoords(PlayerPedId()) end)
    return ok and c or nil
end

local function dist2(a, x, y) return math.sqrt((a.x - x) ^ 2 + (a.y - y) ^ 2) end

local function headingTo(fromX, fromY, toX, toY)
    return (math.deg(math.atan(-(toX - fromX), toY - fromY)) % 360.0)
end

-- ── the camera's aim: the ground spot looked at (map collision), up to 60 m ─────────────
local function camDir()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local flat = math.abs(math.cos(rx))
    return cam, vector3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx))
end

local function newAim()
    local probe, hitAt = nil, nil
    return function()
        local ok, cam, dir = pcall(camDir)
        if not ok or not cam then return nil end
        if probe then
            local okR, status, hit, endCoords = pcall(GetShapeTestResult, probe)
            if not okR then
                probe = nil
            elseif status ~= 1 then
                probe = nil
                hitAt = (status == 2 and yes(hit) and endCoords) or false
            end
        end
        if not probe then
            local to = cam + dir * 60.0
            local okP, h = pcall(StartShapeTestLosProbe, cam.x, cam.y, cam.z, to.x, to.y, to.z, 1, PlayerPedId(), 7)
            probe = okP and h or nil
        end
        return hitAt or nil
    end
end

-- ── the items ──────────────────────────────────────────────────────────────
local function cleanItems(list)
    local out, byId = {}, {}
    if type(list) ~= 'table' then return out, byId end
    for _, it in ipairs(list) do
        if #out >= 150 then break end
        if type(it) == 'table' and it.id ~= nil then
            local id = tostring(it.id)
            local x, y = tonumber(it.x), tonumber(it.y)
            local row = {
                id = id, n = tonumber(it.n), label = type(it.label) == 'string' and it.label or '',
                x = x, y = y, z = tonumber(it.z), h = tonumber(it.h) or 0.0, r = tonumber(it.r),
                model = it.model, kind = KINDS[it.kind] and it.kind or 'point',
                state = (it.state == 'cur' or it.state == 'miss') and it.state or (it.miss and 'miss' or (it.cur and 'cur' or nil)),
                turn = it.turn == true, move = it.move, data = it.data, lift = tonumber(it.lift),
            }
            if row.kind == 'wagon' then row.kind = 'vehicle' end
            if not row.lift then
                row.lift = row.kind == 'ped' and 2.1 or row.kind == 'vehicle' and 2.6 or row.kind == 'object' and 1.2 or 1.0
            end
            if not byId[id] then
                out[#out + 1] = row
                byId[id] = row
            end
        end
    end
    return out, byId
end

-- ── the ghosts: local, see-through, frozen, no collision ──────────────────────────────
local function modelHash(m)
    if type(m) == 'number' then return m end
    if type(m) == 'string' and m ~= '' then return joaat(m) end
    return nil
end

local function makeGhost(it)
    local hash = modelHash(it.model)
    if not hash or not yes(IsModelInCdimage(hash)) then return nil end
    RequestModel(hash)
    local t = now()
    while not yes(HasModelLoaded(hash)) do
        if now() - t > 3000 then return nil end
        Wait(50)
    end
    local x, y, z, h = it.x + 0.0, it.y + 0.0, (it.z or 0.0) + 0.0, (it.h or 0.0) + 0.0
    local e
    if it.kind == 'ped' then
        e = CreatePed(hash, x, y, z, h, false, false, false, false)
    elseif it.kind == 'vehicle' then
        e = CreateVehicle(hash, x, y, z, h, false, false, true, false)
    else
        e = CreateObject(hash, x, y, z, false, false, false, false, false)
    end
    local tries = 0
    while not exists(e) and tries < 20 do Wait(50) tries = tries + 1 end
    SetModelAsNoLongerNeeded(hash)
    if not exists(e) then return nil end
    if it.kind == 'ped' then pcall(Citizen.InvokeNative, 0x283978A15512B2FE, e, true) end   -- a random outfit
    pcall(SetEntityCoordsNoOffset, e, x, y, z, false, false, false)
    pcall(SetEntityHeading, e, h)
    pcall(FreezeEntityPosition, e, true)
    pcall(SetEntityInvincible, e, true)
    pcall(SetEntityCollision, e, false, false)
    pcall(SetEntityAlpha, e, 150, false)
    if it.kind == 'ped' then pcall(SetBlockingOfNonTemporaryEvents, e, true) end
    return e
end

local function dropEntity(e)
    if exists(e) then
        pcall(SetEntityAsMissionEntity, e, true, true)
        pcall(DeleteEntity, e)
    end
end

-- ── one edit ───────────────────────────────────────────────────────────────
local Edit = {}
Edit.__index = Edit

function Edit:_pins()
    local pins = {}
    for _, it in ipairs(self.items) do
        pins[#pins + 1] = {
            id = it.id, n = it.n, label = it.label, x = it.state ~= 'miss' and it.x or nil,
            y = it.state ~= 'miss' and it.y or nil, z = it.z, state = it.state, lift = it.lift,
        }
    end
    pcall(lib.setPins, self.key, pins, { range = self.range, near = self.near, aim = true })
end

function Edit:setItems(list)
    if self.stopped then return end
    self.items, self.byId = cleanItems(list)
    self:_pins()
end

function Edit:isWorld() return self.world == true end
--- true while a queued setWorld(true) waits for the 300 ms gap
function Edit:isPending() return self.pending == true end

function Edit:_hideCards()
    if self.group then
        pcall(self.group.hide)
        pcall(self.group.delete)
        self.group = nil
    end
    if self.textShown then
        pcall(lib.hideTextUI)
        self.textShown = nil
    end
end

function Edit:_showCards(it)
    local kind = it and ('pin:' .. it.id) or 'ground'
    local prompt = mod('prompt')
    if not self.group or self.group.kind ~= kind then
        if self.group then pcall(self.group.hide) pcall(self.group.delete) end
        self.group = nil
        if prompt and prompt.createGroup then
            local ok, g = pcall(prompt.createGroup, false, 'bottom-right')
            if ok and type(g) == 'table' then
                self.group = g
                g.kind = kind
                if it then
                    pcall(g.addPrompt, 'J', word('key_edit'), false)
                    if self.o.onRadius and it.r then
                        pcall(g.addPrompt, 'Q', word('key_bigger'), false)
                        pcall(g.addPrompt, 'Z', word('key_smaller'), false)
                    end
                    if self.o.onRemove then pcall(g.addPrompt, 'DELETE', word('key_remove'), false) end
                else
                    pcall(g.addPrompt, 'J', word('key_here'), false)
                end
                pcall(g.addPrompt, 'TAB', word('key_board'), false)
                pcall(g.display)
                g.at = now()
            end
        end
    elseif now() - (self.group.at or 0) > 400 then
        self.group.at = now()
        local okV, visible = pcall(self.group.isVisible)
        if not okV or not visible then pcall(self.group.display) end
    end
    local text = word(it and 'line_pin' or 'line')
    if text ~= self.textShown or now() - (self.textAt or 0) > 1000 then
        self.textShown, self.textAt = text, now()
        pcall(lib.showTextUI, text, { position = 'bottom-center' })
    end
end

--- World mode on / off. Off keeps the pins, ghosts and rings (the board is shown beside them).
function Edit:setWorld(on, opts)
    if self.stopped then return false end
    on = on == true
    if not on then self.pending = nil end
    if on == self.world then return self.world end
    if on and now() - (self.since or 0) < TAB_GAP_MS then
        -- too soon after the last switch: refused (old callers read false = stay on the board), or queued when the
        -- caller asked for it (opts.queue / start's queueWorld) - it then turns on by itself and calls onWorld(true)
        if (type(opts) == 'table' and opts.queue) or self.o.queueWorld then self.pending = true end
        return self.world
    end
    self.world = on
    self.since = now()
    if not on then
        self:_hideCards()
    end
    return on
end

-- the context menu (w_lib's frame): rows carry this edit's event; the picked row's function runs here
function Edit:_menu(title, subtitle, rows, ctx)
    local opts = {}
    self.rows = {}
    self.rowCtx = ctx
    for i, r in ipairs(rows) do
        if type(r) == 'table' and r.title then
            self.rows[i] = { fn = r.onSelect, id = r.id }
            opts[#opts + 1] = { title = r.title, description = r.description, icon = r.icon, disabled = r.disabled,
                coords = r.coords, where = r.where, event = self.event, args = { e = self.token, i = i } }
        end
    end
    if #opts == 0 then return false end
    local ok = pcall(function()
        lib.registerContext({ id = self.menuId, title = title, subtitle = subtitle, options = opts })
        lib.showContext(self.menuId)
    end)
    if not ok then return false end
    self.menuOpen = true
    self:_hideCards()
    return true
end

function Edit:_groundMenu(at)
    if not self.o.ground then return end
    local pos = me()
    local spot = vector4(at.x, at.y, at.z, pos and headingTo(at.x, at.y, pos.x, pos.y) or 0.0)
    local ok, rows = pcall(self.o.ground, spot)
    if not ok or type(rows) ~= 'table' then return end
    local wrapped = {}
    for i, r in ipairs(rows) do
        if type(r) == 'table' then
            local fn = r.onSelect
            wrapped[i] = { id = r.id, title = r.title, description = r.description, icon = r.icon, disabled = r.disabled,
                coords = r.coords, where = r.where, onSelect = fn and function(_, id) fn(spot, id) end or nil }
        end
    end
    local sub = self.o.subtitle
    if type(sub) == 'function' then
        local okS, s = pcall(sub, spot)
        sub = okS and s or nil
    end
    if sub == nil then
        local okP, d = pcall(function() return lib.place.describe(spot) end)
        sub = okP and d and d.text or nil
    end
    self:_menu(self.o.title or word('what'), sub, wrapped, spot)
end

function Edit:_pinMenu(it)
    local o = self.o
    local rows = {}
    if o.onMove and it.move ~= false then
        rows[#rows + 1] = { id = 'move', title = word('move'), description = word('move_d'), onSelect = function() self:_move(it) end }
    end
    if o.onTurn and it.turn then
        rows[#rows + 1] = { id = 'turn', title = word('face'), description = word('face_d'), onSelect = function()
            local pos = me()
            if pos and it.x then pcall(o.onTurn, it, headingTo(it.x, it.y, pos.x, pos.y)) end
        end }
    end
    if o.onRemove then
        rows[#rows + 1] = { id = 'delete', title = word('remove'), description = word('remove_d'), onSelect = function() pcall(o.onRemove, it) end }
    end
    if o.onOpen then
        rows[#rows + 1] = { id = 'open', title = word('open'), description = word('open_d'), onSelect = function()
            self:setWorld(false)
            pcall(o.onOpen, it)
        end }
    end
    if o.pinMenu then
        local ok, changed = pcall(o.pinMenu, it, rows)
        if ok and type(changed) == 'table' then rows = changed end
    end
    local sub
    if it.x then
        local okP, d = pcall(function() return lib.place.describe(vector3(it.x, it.y, it.z or 0.0)) end)
        sub = okP and d and d.text or nil
    end
    self:_menu(it.label ~= '' and it.label or word('pin'), sub, rows, it)
end

--- «حرّكه»: the w_lib placer for that one spot (J places, its own cards); world mode comes back after it
function Edit:_move(it)
    local placer = mod('placer')
    if not (placer and placer.run) or self.moving then return end
    self.moving = true
    local wasWorld = self.world
    self:setWorld(false)
    CreateThread(function()
        local step = { id = 'spot', kind = it.kind == 'point' and 'point' or it.kind, model = it.model,
            text = word('place'), ring = it.r }
        if it.x then step.current = vector4(it.x, it.y, it.z or 0.0, it.h or 0.0) end
        local ok, values = pcall(placer.run, { title = it.label ~= '' and it.label or false, confirm = false,
            maxDistance = 0, steps = { step } })
        self.moving = false
        if ok and type(values) == 'table' and values.spot and self.o.onMove then
            local v = values.spot
            local spot = type(v) == 'vector4' and v or vector4(v.x, v.y, v.z, it.h or 0.0)
            pcall(self.o.onMove, it, spot)
        end
        if wasWorld and not self.stopped then
            self.since = 0
            self:setWorld(true)
        end
    end)
end

function Edit:_onPick(args)
    if type(args) ~= 'table' or args.e ~= self.token then return end
    self.menuOpen = false
    local row = self.rows and self.rows[tonumber(args.i) or 0]
    local ctx = self.rowCtx
    self.rows, self.rowCtx = nil, nil
    if not row then return end
    -- a row's function gets (item | ground spot, row id); onRow(id, item | spot) tells the caller which row ran
    if row.fn then
        local ok, err = pcall(row.fn, ctx, row.id)
        if not ok then print(('^1w_lib worldEdit: a menu row failed: %s^0'):format(tostring(err))) end
    end
    if row.id ~= nil and self.o.onRow then pcall(self.o.onRow, row.id, ctx) end
end

-- the rings (lib.glow polygons) and the ghosts
function Edit:_rings(pos)
    local glow = lib.glow
    for _, it in ipairs(self.items) do
        if it.state ~= 'miss' and it.x and it.r and it.r > 0 and dist2(pos, it.x, it.y) <= self.range then
            pcall(glow.frame, ('we:%s:%s'):format(self.token, it.id), 'circle', vector3(it.x, it.y, (it.z or pos.z) + 0.0),
                math.min(it.r, 200.0) + 0.0, { range = self.range, solid = { shape = 'ring', alpha = it.state == 'cur' and 200 or 120 } })
        end
    end
end

function Edit:_ghostPass()
    local pos = me()
    local want = {}
    if pos and not self.stopped then
        local n = 0
        for _, it in ipairs(self.items) do
            if it.state ~= 'miss' and it.x and it.model and it.kind ~= 'point' and n < self.maxGhosts
                and dist2(pos, it.x, it.y) <= self.ghostRange then
                n = n + 1
                want[it.id] = it
            end
        end
    end
    for id, g in pairs(self.ghosts) do
        local it = want[id]
        if not it or it.model ~= g.model or not exists(g.ent) then
            dropEntity(g.ent)
            self.ghosts[id] = nil
        end
    end
    for id, it in pairs(want) do
        local g = self.ghosts[id]
        if not g then
            local e = makeGhost(it)
            if e then
                if self.stopped or self.byId[id] ~= it then dropEntity(e) else
                    self.ghosts[id] = { ent = e, model = it.model, x = it.x, y = it.y, z = it.z, h = it.h }
                end
            end
        elseif g.x ~= it.x or g.y ~= it.y or g.z ~= it.z or g.h ~= it.h then
            pcall(SetEntityCoordsNoOffset, g.ent, it.x + 0.0, it.y + 0.0, (it.z or 0.0) + 0.0, false, false, false)
            pcall(SetEntityHeading, g.ent, (it.h or 0.0) + 0.0)
            g.x, g.y, g.z, g.h = it.x, it.y, it.z, it.h
        end
    end
end

local wheelNext, wheelPrev
local function wheels()
    if not wheelNext then
        local ok1, a = pcall(joaat, 'INPUT_SELECT_NEXT_WEAPON')
        local ok2, b = pcall(joaat, 'INPUT_SELECT_PREV_WEAPON')
        wheelNext, wheelPrev = ok1 and a or 0, ok2 and b or 0
    end
    return wheelNext, wheelPrev
end

local function pressed(c) return yes(IsDisabledControlJustPressed(0, c)) end

function Edit:_frame()
    if self.pending and not self.world and now() - (self.since or 0) >= TAB_GAP_MS then
        self.pending = nil
        self.world, self.since = true, now()
        if self.o.onWorld then pcall(self.o.onWorld, true) end
    end
    local pos = me()
    if not pos then return end
    self:_rings(pos)
    if not self.world or self.menuOpen or self.moving then return end
    local nxt, prv = wheels()
    for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
    if nxt ~= 0 then DisableControlAction(0, nxt, true) end
    if prv ~= 0 then DisableControlAction(0, prv, true) end
    pcall(Citizen.InvokeNative, DISABLE_NATIVE_PROMPTS)
    pcall(function() exports.w_lib:WalkupClaim(0) end)
    if now() - (self.aimedAt or 0) > 60 then
        self.aimedAt = now()
        local okA, id = pcall(lib.getAimedPin, self.key)
        self.aimedId = okA and id or nil
    end
    local it = self.aimedId and self.byId[self.aimedId] or nil
    self:_showCards(it)
    local o = self.o
    if pressed(KEY.J) then
        if it then
            self:_pinMenu(it)
        else
            local at = self.aim()
            if at then self:_groundMenu(at) end
        end
        return
    end
    if it then
        if it.turn and o.onTurn then
            if nxt ~= 0 and pressed(nxt) then pcall(o.onTurn, it, ((it.h or 0.0) - 15.0) % 360.0) end
            if prv ~= 0 and pressed(prv) then pcall(o.onTurn, it, ((it.h or 0.0) + 15.0) % 360.0) end
        end
        if it.r and o.onRadius then
            if pressed(KEY.Q) then pcall(o.onRadius, it, it.r + 1.0) end
            if pressed(KEY.Z) and not self.ctrl then pcall(o.onRadius, it, math.max(0.5, it.r - 1.0)) end
        end
        if o.onRemove and pressed(KEY.DEL) then pcall(o.onRemove, it) end
    end
    self.aim()
end

function Edit:stop(reason)
    if self.stopped then return end
    self.stopped = true
    self.world = false
    self:_hideCards()
    pcall(lib.clearPins, self.key)
    for id, g in pairs(self.ghosts) do dropEntity(g.ent) self.ghosts[id] = nil end
    if self.menuOpen then
        local ok, open = pcall(lib.getOpenContextMenu)
        if ok and open == self.menuId then pcall(lib.hideContext, false) end
    end
    for _, id in ipairs(self.listeners) do pcall(lib.rawKeys.removeListener, id) end
    if self.handler then RemoveEventHandler(self.handler) end
    live[self.token] = nil
    if self.o.onStop then pcall(self.o.onStop, reason or 'stopped') end
end

---@param o table see the header
---@return table edit
function worldEdit.start(o)
    o = type(o) == 'table' and o or {}
    seq = seq + 1
    local token = ('%s:%d'):format(resName, seq)
    local self = setmetatable({
        o = o, token = token, key = type(o.key) == 'string' and o.key or resName,
        range = tonumber(o.range) or 150.0, near = tonumber(o.near) or 60.0,
        ghostRange = tonumber(o.ghostRange) or 120.0, maxGhosts = tonumber(o.maxGhosts) or 24,
        items = {}, byId = {}, ghosts = {}, world = false, since = 0, listeners = {},
        menuId = 'w_lib:worldEdit:' .. token, event = 'w_lib:worldEdit:' .. resName,
        aim = newAim(),
    }, Edit)
    live[token] = self
    self.handler = AddEventHandler(self.event, function(args) self:_onPick(args) end)
    local okK = pcall(function()
        self.listeners[#self.listeners + 1] = lib.rawKeys.listen('TAB', function(down)
            if not down or not self.world or self.menuOpen or self.moving then return end
            if now() - self.since < TAB_GAP_MS then return end
            self:setWorld(false)
            if o.onBoard then pcall(o.onBoard) end
        end)
        self.listeners[#self.listeners + 1] = lib.rawKeys.listen('ctrl', function(down) self.ctrl = down == true end)
        self.listeners[#self.listeners + 1] = lib.rawKeys.listen('Z', function(down)
            if down and self.world and self.ctrl and not self.menuOpen and o.onUndo then pcall(o.onUndo) end
        end)
    end)
    if not okK then print('^1w_lib worldEdit: the raw keys failed (TAB / Ctrl+Z will not work)^0') end
    if o.items then self:setItems(o.items) end
    CreateThread(function()
        while not self.stopped do
            local ok, err = pcall(self._frame, self)
            if not ok then print(('^1w_lib worldEdit: the frame failed: %s^0'):format(tostring(err))) Wait(500) end
            if self.menuOpen then
                local okM, open = pcall(lib.getOpenContextMenu)
                if not okM or open ~= self.menuId then self.menuOpen = false end
            end
            Wait(0)
        end
    end)
    CreateThread(function()
        while not self.stopped do
            pcall(self._ghostPass, self)
            Wait(500)
        end
    end)
    return self
end

--- Every running edit of this resource
function worldEdit.active()
    local out = {}
    for _, e in pairs(live) do out[#out + 1] = e end
    return out
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= resName then return end
    for _, e in pairs(live) do pcall(e.stop, e, 'resource') end
end)

return worldEdit
