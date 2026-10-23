--[[
    w_lib · imports/glow/client.lua -- the game's own glitter drawn as shapes (w_lib 4.1.0, the owner 2026-10-23)

    The owner tried five of the game's glitter effects on a farm's border (w_farming 2.3.0 /farmfx 1-5) and chose to
    use them INSTEAD of DrawMarker everywhere, each look with its own job, through the library:

        look 1  eagle_eye/eagle_eye_trail                        paths, routes                 lib.glow.line
        look 2  eagle_eye/eagle_eye_clue                         a point to use (board, door)  lib.glow.point
        look 3  eagle_eye/eagle_eye_entity                       arrows                        lib.glow.arrow
        look 4  eagle_eye/eagle_eye_lootable_plant               circles on the ground         lib.glow.circle
        look 5  scr_net_fire_smoke/scr_mp_item_pickup_highlight  walls, borders (his pick)     lib.glow.wall

    (the names: femga/rdr3_discoveries graphics/ptfx/ptfx_assets_looped.lua). Any shape takes any look: opts.look.

    A shape is a set of SPOTS, one looped particle each. Every 200 ms the spots nearest the camera (within `range`, at
    most `budget` of them in this resource) burn, the rest are put out, so a long border costs the same as a short one.
    Spots on the ground (`ground`, the default for walls, lines and circles) read the ground height once it is loaded.
    A look the game refuses is drawn with DrawMarker instead (a small flat ring), so nothing disappears.

    Two ways to use it:
      kept:  local id = lib.glow.wall(points, opts) ... lib.glow.remove(id)   (opts.id = redraw that shape in place)
      frame: lib.glow.frame(key, 'circle', center, radius, opts) every frame, like DrawMarker: the shape lives while it
             is drawn and goes 350 ms after the last call; a moved shape keeps its particles and moves them.

      lib.glow.wall(points, { closed = true, step = 0.5, rows = { 0.0, 0.8, 1.6 }, look = 5 })   a wall along a border
      lib.glow.line(points, { step = 2.0, look = 1 })                 a path (open unless closed = true)
      lib.glow.circle(center, radius, { step = 0.8, look = 4 })        a ring on the ground
      lib.glow.point(at, { look = 2, ground = false })                 one spot
      lib.glow.arrow(at, { heading = nil, size = 1.2, look = 3 })      down at `at`; with a heading: flat, pointing it
      lib.glow.remove(id) · lib.glow.clear() · lib.glow.looks (the table above) · lib.glow.count()
      common opts: look (1-5), color {r,g,b} 0-255 (a tint; not every effect takes it), alpha 0-1, scale, lift
                   (metres above the point / ground), range (metres, default 60), ground (true/false), id
    Budget: convar `w_lib:glowBudget` (default 300 spots per resource), range `w_lib:glowRange` (60).
    4.1.1 (the owner 2026-10-23: "all of them: taller, denser, bigger"): a wall has three rows (0, 0.8, 1.6 m), a spot
    every 0.5 m, look 5 drawn 1.5 times its size; the budget went 150 -> 300 so about 50 m of such a wall stands round
    the camera (6 spots a metre).

    ★ natives (hashes for when the name is missing): REQUEST_NAMED_PTFX_ASSET 0xF2B2353BBC0D4E8F,
      HAS_NAMED_PTFX_ASSET_LOADED 0x65BB72F29138F5D6, USE_PARTICLE_FX_ASSET 0xA10DB07FC234DD12,
      START_PARTICLE_FX_LOOPED_AT_COORD 0xBA32867E86125D3A, STOP_PARTICLE_FX_LOOPED 0x22970F3A088B133B,
      SET_PARTICLE_FX_LOOPED_COLOUR 0x239879FC61C610CC, SET_PARTICLE_FX_LOOPED_ALPHA 0x88786E76234F7054,
      SET_PARTICLE_FX_LOOPED_OFFSETS 0xD3A4A95FC94FE83B (a moved spot), SET_PARTICLE_FX_LOOPED_FAR_CLIP_DIST
      0x9B04D471DA0AD7AA (a shape with a range past the default is seen that far: an editor from above);
      alloc8or/rdr3-nativedb-data natives.json. Proven in game: w_farming 2.3.0 client/landfx.lua.
]]

lib.glow = {}
local Glow = lib.glow

Glow.looks = {
    { dict = 'eagle_eye', name = 'eagle_eye_trail', job = 'line', scale = 1.0 },
    { dict = 'eagle_eye', name = 'eagle_eye_clue', job = 'point', scale = 1.0 },
    { dict = 'eagle_eye', name = 'eagle_eye_entity', job = 'arrow', scale = 1.0 },
    { dict = 'eagle_eye', name = 'eagle_eye_lootable_plant', job = 'circle', scale = 1.0 },
    { dict = 'scr_net_fire_smoke', name = 'scr_mp_item_pickup_highlight', job = 'wall', scale = 1.5 },
}
local LOOK_OF = { line = 1, point = 2, arrow = 3, circle = 4, wall = 5 }

local TICK = 200
local FRAME_LIFE = 350
local BUDGET = math.max(1, GetConvarInt('w_lib:glowBudget', 300))
local RANGE = math.max(5, GetConvarInt('w_lib:glowRange', 60))
local RING = 0x6903B113   -- the fallback: a flat ground cylinder (modules/placer MARKER_GROUND)

local shapes = {}    -- id -> { id, spots = { { x, y, z, lift, ground, look, scale, color, ckey, alpha, gz }, ... }, range, frame, at, sig }
local active = {}    -- spot key -> { h, x, y, z, look, scale, ckey }
local assets = {}    -- look number -> 'loading' | 'ready' | 'failed'
local fallback = {}  -- spot key -> { x, y, z }: drawn with DrawMarker (a look the game refused)
local nextId, running, drawing = 0, false, false

local function native(name, hash, ...)
    local fn = _G[name]
    if type(fn) == 'function' then return fn(...) end
    if hash then return Citizen.InvokeNative(hash, ...) end
end

local function yes(v) return v == true or v == 1 end

local function num(v, d)
    v = tonumber(v)
    if v == nil or v ~= v then return d end
    return v
end

local function vec(p)
    local t = type(p)
    if t ~= 'table' and t ~= 'vector3' and t ~= 'vector4' then return nil end
    local x, y = num(p.x or p[1], nil), num(p.y or p[2], nil)
    if not x or not y then return nil end
    return { x = x, y = y, z = num(p.z or p[3], 0.0) }
end

local function points(list)
    local out = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do out[#out + 1] = vec(p) end
    return out
end

-- ── the looks ─────────────────────────────────────────────────────────────────
local function lookOf(kind, opts)
    local n = math.floor(num(opts.look, LOOK_OF[kind] or 2))
    return Glow.looks[n] and n or LOOK_OF[kind] or 2
end

local function asset(n)
    if assets[n] then return assets[n] end
    assets[n] = 'loading'
    CreateThread(function()
        local hash = joaat(Glow.looks[n].dict)
        native('RequestNamedPtfxAsset', 0xF2B2353BBC0D4E8F, hash)
        local t = GetGameTimer()
        while not yes(native('HasNamedPtfxAssetLoaded', 0x65BB72F29138F5D6, hash)) and GetGameTimer() - t < 5000 do Wait(50) end
        assets[n] = yes(native('HasNamedPtfxAssetLoaded', 0x65BB72F29138F5D6, hash)) and 'ready' or 'failed'
        if assets[n] == 'failed' then
            print(('^3w_lib glow: the particle asset %s failed to load, look %d falls back to a marker^7'):format(Glow.looks[n].dict, n))
        end
    end)
    return 'loading'
end

-- ── the spots of each shape ───────────────────────────────────────────────────
local function spot(list, x, y, z, lift, ground, look, opts)
    local c = type(opts.color) == 'table' and opts.color or nil
    local r, g, b = c and num(c.r or c[1], nil), c and num(c.g or c[2], nil), c and num(c.b or c[3], nil)
    local color = (r and g and b) and { r / 255.0, g / 255.0, b / 255.0 } or nil
    list[#list + 1] = {
        x = x, y = y, z = z, lift = lift or 0.0, ground = ground, look = look,
        scale = num(opts.scale, Glow.looks[look].scale or 1.0), alpha = tonumber(opts.alpha),
        color = color, ckey = color and ('%d,%d,%d'):format(r, g, b) or '',
    }
end

--- Spots every `step` metres along a polyline (closed: back to the first point), one per height in `rows`
local function along(list, pts, closed, step, rows, ground, look, opts)
    local n = #pts
    for i = 1, closed and n or n - 1 do
        local a, b = pts[i], pts[i % n + 1]
        local len = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
        local count = math.max(1, math.floor(len / step + 0.5))
        -- each side owns its start; an open line's last side also owns its end
        local last = (not closed and i == n - 1) and count or count - 1
        for k = 0, last do
            local t = k / count
            local x, y, z = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t
            for _, h in ipairs(rows) do spot(list, x, y, z, num(h, 0.0), ground, look, opts) end
        end
    end
end

local BUILD = {}

function BUILD.wall(pointsIn, _, opts)
    local pts = points(pointsIn)
    if #pts < 2 then return nil end
    local list = {}
    local closed = opts.closed
    if closed == nil then closed = #pts >= 3 end
    local rows = type(opts.rows) == 'table' and #opts.rows > 0 and opts.rows or { 0.0, 0.8, 1.6 }
    along(list, pts, closed, math.max(0.3, num(opts.step, 0.5)), rows, opts.ground ~= false, lookOf('wall', opts), opts)
    return list
end

function BUILD.line(pointsIn, _, opts)
    local pts = points(pointsIn)
    if #pts < 2 then return nil end
    local list = {}
    along(list, pts, opts.closed == true, math.max(0.3, num(opts.step, 2.0)), { num(opts.lift, 0.0) }, opts.ground ~= false,
        lookOf('line', opts), opts)
    return list
end

function BUILD.circle(center, radius, opts)
    local c = vec(center)
    radius = num(radius, 1.0)
    if not c or radius <= 0 then return nil end
    local list, look = {}, lookOf('circle', opts)
    local n = math.max(6, math.ceil(2 * math.pi * radius / math.max(0.2, num(opts.step, 0.8))))
    for i = 0, n - 1 do
        local a = 2 * math.pi * i / n
        spot(list, c.x + math.cos(a) * radius, c.y + math.sin(a) * radius, c.z, num(opts.lift, 0.0), opts.ground ~= false, look, opts)
    end
    return list
end

function BUILD.point(at, _, opts)
    local p = vec(at)
    if not p then return nil end
    local list = {}
    spot(list, p.x, p.y, p.z, num(opts.lift, 0.0), opts.ground == true, lookOf('point', opts), opts)
    return list
end

--- An arrow pointing DOWN at `at` (a shaft above a cone of four strokes, seen from every side); with opts.heading
--- (degrees, the game's: forward = -sin h, cos h) a flat arrow on the ground whose tip is `at`
function BUILD.arrow(at, _, opts)
    local p = vec(at)
    if not p then return nil end
    local list, look = {}, lookOf('arrow', opts)
    local size = math.max(0.3, num(opts.size, 1.2))
    local gap = math.max(0.1, num(opts.step, size / 5))
    local h = tonumber(opts.heading)
    if h then
        local ground = opts.ground ~= false
        local r = math.rad(h)
        local fx, fy = -math.sin(r), math.cos(r)
        for d = 0, size + 0.001, gap do spot(list, p.x - fx * d, p.y - fy * d, p.z, 0.0, ground, look, opts) end
        for _, side in ipairs({ 1, -1 }) do
            local a = r + side * math.rad(145)
            local sx, sy = -math.sin(a), math.cos(a)
            for d = gap, math.max(gap, size * 0.45) + 0.001, gap do spot(list, p.x + sx * d, p.y + sy * d, p.z, 0.0, ground, look, opts) end
        end
    else
        for d = 0, size + 0.001, gap do spot(list, p.x, p.y, p.z, d, false, look, opts) end
        for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            for d = gap, math.max(gap, size * 0.35) + 0.001, gap do spot(list, p.x + dir[1] * d, p.y + dir[2] * d, p.z, d, false, look, opts) end
        end
    end
    return list
end

-- ── the particles ─────────────────────────────────────────────────────────────
--- Where a spot burns: on the ground under it once the ground is loaded (kept), else at its own height
local function heightOf(s)
    if s.ground then
        if not s.gz then
            local ok, found, gz = pcall(GetGroundZFor_3dCoord, s.x + 0.0, s.y + 0.0, s.z + 25.0, false)
            if ok and yes(found) and type(gz) == 'number' and math.abs(gz - s.z) < 25.0 then s.gz = gz end
        end
        return (s.gz or s.z) + s.lift
    end
    return s.z + s.lift
end

local function stop(a)
    if a and a.h then pcall(native, 'StopParticleFxLooped', 0x22970F3A088B133B, a.h, false) end
end

local function start(s, z)
    local look = Glow.looks[s.look]
    native('UseParticleFxAsset', 0xA10DB07FC234DD12, look.dict)   -- good for one start only
    local h = native('StartParticleFxLoopedAtCoord', 0xBA32867E86125D3A, look.name, s.x + 0.0, s.y + 0.0, z + 0.0,
        0.0, 0.0, 0.0, s.scale + 0.0, false, false, false, false)
    if type(h) ~= 'number' or h == 0 then return nil end
    if s.color then pcall(native, 'SetParticleFxLoopedColour', 0x239879FC61C610CC, h, s.color[1] + 0.0, s.color[2] + 0.0, s.color[3] + 0.0, false) end
    if s.alpha then pcall(native, 'SetParticleFxLoopedAlpha', 0x88786E76234F7054, h, s.alpha + 0.0) end
    if s.far then pcall(native, 'SetParticleFxLoopedFarClipDist', 0x9B04D471DA0AD7AA, h, s.far + 0.0) end
    return h
end

--- Where the eye is: the camera (an editor's camera high above the land), else the player
local function eye()
    local ok, c = pcall(GetFinalRenderedCamCoord)
    if ok and c and c.x then return c end
    return GetEntityCoords(PlayerPedId())
end

local function drawFallback()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while next(fallback) do
            for _, f in pairs(fallback) do
                DrawMarker(RING, f.x, f.y, f.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.12,
                    242, 242, 242, 170, false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        end
        drawing = false
    end)
end

local function tick()
    local now = GetGameTimer()
    for id, sh in pairs(shapes) do
        if sh.frame and now - sh.at > FRAME_LIFE then shapes[id] = nil end
    end
    local at = eye()
    local cand = {}
    for id, sh in pairs(shapes) do
        local r2 = sh.range * sh.range
        for i, s in ipairs(sh.spots) do
            local dx, dy = s.x - at.x, s.y - at.y
            local d2 = dx * dx + dy * dy
            if d2 <= r2 then cand[#cand + 1] = { key = id .. ':' .. i, d2 = d2, s = s } end
        end
    end
    table.sort(cand, function(a, b) return a.d2 < b.d2 end)
    local keep, fb = {}, {}
    for i = 1, math.min(#cand, BUDGET) do
        local key, s = cand[i].key, cand[i].s
        local state = asset(s.look)
        local z = heightOf(s)
        if state == 'failed' then
            fb[key] = { x = s.x, y = s.y, z = z }
        elseif state == 'ready' then
            local a = active[key]
            if a and (a.look ~= s.look or a.scale ~= s.scale or a.ckey ~= s.ckey) then stop(a) a = nil active[key] = nil end
            if a and (math.abs(a.x - s.x) > 0.02 or math.abs(a.y - s.y) > 0.02 or math.abs(a.z - z) > 0.02) then
                -- a moved spot (a frame shape drawn somewhere else): move it, or light it again there
                if pcall(native, 'SetParticleFxLoopedOffsets', 0xD3A4A95FC94FE83B, a.h, s.x + 0.0, s.y + 0.0, z + 0.0, 0.0, 0.0, 0.0) then
                    a.x, a.y, a.z = s.x, s.y, z
                else
                    stop(a) a = nil active[key] = nil
                end
            end
            if not a then
                local h = start(s, z)
                if h then active[key] = { h = h, x = s.x, y = s.y, z = z, look = s.look, scale = s.scale, ckey = s.ckey } end
            end
            if active[key] then keep[key] = true end
        end
    end
    for key, a in pairs(active) do
        if not keep[key] then stop(a) active[key] = nil end
    end
    fallback = fb
    if next(fallback) then drawFallback() end
end

local function run()
    if running then return end
    running = true
    CreateThread(function()
        while next(shapes) do
            local ok, err = pcall(tick)
            if not ok then print(('^1w_lib glow: tick error %s^7'):format(tostring(err))) end
            Wait(TICK)
        end
        for key, a in pairs(active) do stop(a) active[key] = nil end
        fallback = {}
        running = false
    end)
end

--- Makes (or remakes in place: opts.id) one shape
local function put(kind, a, b, opts)
    opts = type(opts) == 'table' and opts or {}
    local spots = BUILD[kind](a, b, opts)
    if not spots then return nil end
    local id = opts.id
    if id == nil then
        nextId = nextId + 1
        id = 'g' .. nextId
    end
    id = tostring(id)
    local range = math.max(1.0, num(opts.range, RANGE))
    if range > RANGE then
        for _, s in ipairs(spots) do s.far = range end
    end
    shapes[id] = { id = id, spots = spots, range = range, frame = opts.frame == true, at = GetGameTimer() }
    run()
    return id
end

function Glow.wall(pts, opts) return put('wall', pts, nil, opts) end
function Glow.line(pts, opts) return put('line', pts, nil, opts) end
function Glow.circle(center, radius, opts) return put('circle', center, radius, opts) end
function Glow.point(at, opts) return put('point', at, nil, opts) end
function Glow.arrow(at, opts) return put('arrow', at, nil, opts) end

function Glow.remove(id)
    if id ~= nil then shapes[tostring(id)] = nil end
end

function Glow.clear()
    shapes = {}
end

--- How many particles burn now (this resource)
function Glow.count()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

--- What a frame shape is: when it is the same as last frame only its life is renewed
local function signature(kind, a, b, opts)
    local parts = { kind }
    local p = vec(a)
    if p then
        parts[#parts + 1] = ('%.2f,%.2f,%.2f'):format(p.x, p.y, p.z)
    elseif type(a) == 'table' then
        parts[#parts + 1] = #a
        for _, q in ipairs(a) do
            local v = vec(q)
            if v then parts[#parts + 1] = ('%.2f,%.2f,%.2f'):format(v.x, v.y, v.z) end
        end
    end
    parts[#parts + 1] = tostring(b)
    for _, k in ipairs({ 'look', 'scale', 'size', 'heading', 'step', 'lift', 'range', 'closed', 'ground', 'alpha' }) do
        parts[#parts + 1] = tostring(opts[k])
    end
    local c = opts.color
    if type(c) == 'table' then parts[#parts + 1] = tostring(c.r or c[1]) .. ',' .. tostring(c.g or c[2]) .. ',' .. tostring(c.b or c[3]) end
    if type(opts.rows) == 'table' then parts[#parts + 1] = table.concat(opts.rows, ',') end
    return table.concat(parts, '|')
end

--- Drawn every frame, like DrawMarker: lib.glow.frame(key, kind, ...the kind's own arguments...)
---   lib.glow.frame('cursor', 'point', coords, { look = 2 }) · lib.glow.frame(k, 'circle', center, radius, opts)
function Glow.frame(key, kind, a, b, c)
    if not BUILD[kind] then return nil end
    local opts
    if kind == 'circle' then opts = c else opts, b = b, nil end
    opts = type(opts) == 'table' and opts or {}
    local id = 'f:' .. tostring(key)
    local sig = signature(kind, a, b, opts)
    local sh = shapes[id]
    if sh and sh.sig == sig then
        sh.at = GetGameTimer()
        return id
    end
    local o = setmetatable({ id = id, frame = true }, { __index = opts })
    if not put(kind, a, b, o) then return nil end
    shapes[id].sig = sig
    -- a moved frame shape (a cursor): its burning spots off the ground follow at once, not at the next tick
    if sh then
        for i, s in ipairs(shapes[id].spots) do
            local act = active[id .. ':' .. i]
            if act and not s.ground and act.look == s.look and act.scale == s.scale and act.ckey == s.ckey then
                local z = s.z + s.lift
                if pcall(native, 'SetParticleFxLoopedOffsets', 0xD3A4A95FC94FE83B, act.h, s.x + 0.0, s.y + 0.0, z + 0.0, 0.0, 0.0, 0.0) then
                    act.x, act.y, act.z = s.x, s.y, z
                end
            end
        end
    end
    return id
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key, a in pairs(active) do stop(a) active[key] = nil end
end)

return lib.glow
