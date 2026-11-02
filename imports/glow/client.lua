--[[
    w_lib · imports/glow/client.lua -- shapes on the world: polygons by default, the game's glitter on request
    (w_lib 4.1.0, the owner 2026-10-23; 4.2.0 the owner 2026-11-02)

    ★ 4.2.0 (the owner 2026-11-02: "I get particles instead of polygons. I want polygons, not particles. Particles only
      for the waypoint, as an arrow -- not for marking places or for placing positions / NPCs"): every shape is drawn as
      a POLYGON by default (the `solid` look of 4.1.2: DrawPoly walls, DrawMarker rings / spheres / arrows), with NO
      particle. The game's glitter burns only when the caller asks for it with `opts.particle = true` (w_map's waypoint
      trail does). Same API, same arguments: no resource that calls lib.glow needed a change.

    The polygon of each shape (`opts.solid`: true | { shape, color = {r,g,b}, alpha = 0-255, height, size, step }):
        wall    a see-through wall along the border (DrawPoly both faces, a line at its foot and top), `height` default
                the top row + 0.8 (2.4 m); on the ground it is cut every `step` (2 m) so it follows the land
        line    the same, low (0.8 m over its row)
        circle  a flat ring on the ground (DrawMarker 0x6903B113), its radius; wider than 3 m (a zone) a see-through
                wall round it instead, `height` 1 m (shape = 'ring' keeps the flat ring: the placer's reach)
        point   a small sphere (DrawMarker 0x50638AB9), radius `size` (default 0.125 x scale); a flat ring instead
                when `shape = 'ring'`, when opts.ground = true, or when the caller passed `solid` itself (4.1.2's ring)
        arrow   the game's arrow marker pointing down at `at` (DrawMarker 0x07DCE236, w_inventory's drop arrow before
                4.1.0), `size` its length (1.2); with opts.heading a flat arrow on the ground (DrawPoly) whose tip is `at`
    Colour: solid.color, else opts.color, else the theme's paper (242); a 4th colour value is the alpha.
    Cost: every 200 ms the pieces nearest the camera within `range` are chosen, at most convar `w_lib:solidBudget`
    (default 150) a resource (a wall piece = 4 polygons + 2 lines; a point / ring / arrow = 1 marker); they are drawn
    every frame. A frame shape that was not drawn again in the last 150 ms is not drawn (like DrawMarker).

    The glitter (opts.particle = true), the looks the owner chose 2026-10-23 (w_farming 2.3.0 /farmfx 1-5):

        look 1  eagle_eye/eagle_eye_trail                        paths, routes                 lib.glow.line
        look 2  eagle_eye/eagle_eye_clue                         a point to use (board, door)  lib.glow.point
        look 3  eagle_eye/eagle_eye_entity                       arrows                        lib.glow.arrow
        look 4  eagle_eye/eagle_eye_lootable_plant               circles on the ground         lib.glow.circle
        look 5  scr_net_fire_smoke/scr_mp_item_pickup_highlight  walls, borders (his pick)     lib.glow.wall

    (the names: femga/rdr3_discoveries graphics/ptfx/ptfx_assets_looped.lua). Any shape takes any look: opts.look.
    A particle shape is a set of SPOTS, one looped particle each. Every 200 ms the spots nearest the camera (within
    `range`, at most `budget` of them in this resource) burn, the rest are put out. Spots on the ground (`ground`, the
    default for walls, lines and circles) read the ground height once it is loaded. A look the game refuses is drawn
    with DrawMarker instead (a small flat ring). With particle = true the polygon is drawn too only if `solid` is given
    (4.1.2), so the glitter alone stays possible.

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
      common opts: particle (true = the game's glitter, 4.2.0), solid (see above), look (1-5), color {r,g,b} 0-255,
                   alpha 0-1 (the glitter's), scale, lift (metres above the point / ground), range (metres, default 60),
                   ground (true/false), id
    Budget: convar `w_lib:glowBudget` (default 300 spots per resource), range `w_lib:glowRange` (60).
    4.1.2 (2026-10-24): `solid` beside the glitter for the editors from above (the glitter is not seen from high up).
    4.1.1 (2026-10-23): a wall has three rows (0, 0.8, 1.6 m), a spot every 0.5 m, look 5 drawn 1.5 times its size.

    ★ natives (hashes for when the name is missing): REQUEST_NAMED_PTFX_ASSET 0xF2B2353BBC0D4E8F,
      HAS_NAMED_PTFX_ASSET_LOADED 0x65BB72F29138F5D6, USE_PARTICLE_FX_ASSET 0xA10DB07FC234DD12,
      START_PARTICLE_FX_LOOPED_AT_COORD 0xBA32867E86125D3A, STOP_PARTICLE_FX_LOOPED 0x22970F3A088B133B,
      SET_PARTICLE_FX_LOOPED_COLOUR 0x239879FC61C610CC, SET_PARTICLE_FX_LOOPED_ALPHA 0x88786E76234F7054,
      SET_PARTICLE_FX_LOOPED_OFFSETS 0xD3A4A95FC94FE83B (a moved spot), SET_PARTICLE_FX_LOOPED_FAR_CLIP_DIST
      0x9B04D471DA0AD7AA (a shape with a range past the default is seen that far: an editor from above);
      alloc8or/rdr3-nativedb-data natives.json. Proven in game: w_farming 2.3.0 client/landfx.lua.
      The polygons: DrawPoly (4.1.2 walls, w_farming livestock/client/guide.lua), DRAW_LINE 0x6B7256074AE34680, and
      DrawMarker with the marker hashes used in game before 4.1.0: 0x6903B113 flat ground ring (essentials teleports,
      the placer), 0x50638AB9 sphere (the placer's camera spots, w_doorlock's aim, modules/debugger), 0x07DCE236 the
      arrow (w_inventory's drops, w_farming's care arrows; arguments as w_inventory: rotate = true).
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
local FRAME_DRAW = 150       -- 4.2.0: a frame shape's polygon is drawn only while it was drawn again this recently
local BUDGET = math.max(1, GetConvarInt('w_lib:glowBudget', 300))
local SOLID_BUDGET = math.max(1, GetConvarInt('w_lib:solidBudget', 150))
local RANGE = math.max(5, GetConvarInt('w_lib:glowRange', 60))
local PROBES = 64            -- ground reads a tick for the polygons' corners
local RING = 0x6903B113      -- a flat ground cylinder (modules/placer MARKER_GROUND)
local SPHERE = 0x50638AB9    -- a sphere (modules/placer MARKER_SPHERE)
local ARROW = 0x07DCE236     -- the arrow down (w_inventory's drop arrow before 4.1.0)
local DRAW_LINE = 0x6B7256074AE34680
local PAPER = { 242, 242, 242 }

local shapes = {}    -- id -> { id, spots (particle shapes only), solid, range, frame, at, sig, vis }
local active = {}    -- spot key -> { h, x, y, z, look, scale, ckey }
local assets = {}    -- look number -> 'loading' | 'ready' | 'failed'
local fallback = {}  -- spot key -> { x, y, z }: drawn with DrawMarker (a look the game refused)
local nextId, running, drawing, solidRunning = 0, false, false, false

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

-- ── the spots of each particle shape ──────────────────────────────────────────
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

-- ── the polygons (4.1.2 `solid`; since 4.2.0 the default look) ───────────────
--- The ground under a corner: probed just above it first (an interior's roof is not taken), then from 25 m up
local function probe(x, y, z)
    local ok, found, gz = pcall(GetGroundZFor_3dCoord, x + 0.0, y + 0.0, z + 1.5, false)
    if ok and yes(found) and type(gz) == 'number' and gz <= z + 1.5 and z - gz < 6.0 then return gz end
    ok, found, gz = pcall(GetGroundZFor_3dCoord, x + 0.0, y + 0.0, z + 25.0, false)
    if ok and yes(found) and type(gz) == 'number' and math.abs(gz - z) < 25.0 then return gz end
    return nil
end

--- A corner of a polygon: { x, y, z, ground, gz }; its height is the ground once read, else its own
local function corner(x, y, z, ground) return { x = x, y = y, z = z, ground = ground } end
local function baseZ(v) return v.ground and (v.gz or v.z) or v.z end

local function settle(v, budget)
    if v.ground and not v.gz and budget.n > 0 then
        budget.n = budget.n - 1
        v.gz = probe(v.x, v.y, v.z)
    end
end

local function colourOf(s, opts)
    local c = (type(s.color) == 'table' and s.color) or (type(opts.color) == 'table' and opts.color) or PAPER
    local r, g, b = num(c.r or c[1], nil), num(c.g or c[2], nil), num(c.b or c[3], nil)
    if not (r and g and b) then r, g, b = PAPER[1], PAPER[2], PAPER[3] end
    return { r, g, b }, num(c.a or c[4], nil)
end

--- What the polygon of a shape is (nil = none / bad input). `asked` = the caller passed `solid` himself.
local function solidOf(kind, a, b, opts)
    local asked = opts.solid ~= nil and opts.solid ~= false
    local s = type(opts.solid) == 'table' and opts.solid or {}
    local c, ca = colourOf(s, opts)
    local out = { c = c }
    local lift = num(opts.lift, 0.0)
    if kind == 'wall' or kind == 'line' then
        local pts = points(a)
        if #pts < 2 then return nil end
        local rows = type(opts.rows) == 'table' and #opts.rows > 0 and opts.rows or (kind == 'wall' and { 0.0, 0.8, 1.6 } or { 0.0 })
        local top = 0.0
        for _, h in ipairs(rows) do top = math.max(top, num(h, 0.0)) end
        local closed = opts.closed
        if closed == nil then closed = kind == 'wall' and #pts >= 3 end
        local ground = opts.ground ~= false
        -- on the ground each side is cut every `step` metres so the wall follows the land between two corners
        local step = math.max(0.5, num(s.step, 2.0))
        local v = {}
        local n = #pts
        for i = 1, closed and n or n - 1 do
            local p, q = pts[i], pts[i % n + 1]
            local count = ground and math.max(1, math.floor(math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2) / step + 0.5)) or 1
            for k = 0, count - 1 do
                local t = k / count
                v[#v + 1] = corner(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t, p.z + (q.z - p.z) * t, ground)
            end
        end
        if not closed then v[#v + 1] = corner(pts[n].x, pts[n].y, pts[n].z, ground) end
        out.kind, out.v, out.closed = 'wall', v, closed == true
        out.segs = closed and #v or #v - 1
        out.h = num(s.height, top + 0.8)
        out.a = math.floor(num(s.alpha, ca or 60))
        return out
    end
    local p = vec(a)
    if not p then return nil end
    if kind == 'circle' then
        local r = num(b, 1.0)
        if r <= 0 then return nil end
        if r > 3.0 and s.shape ~= 'ring' then
            -- a wide circle (a zone) is a low see-through wall round it, not a disc over the whole land
            local ground, v = opts.ground ~= false, {}
            local n = math.max(16, math.min(96, math.ceil(2 * math.pi * r / math.max(0.5, num(s.step, 2.0)))))
            for i = 0, n - 1 do
                local t = 2 * math.pi * i / n
                v[#v + 1] = corner(p.x + math.cos(t) * r, p.y + math.sin(t) * r, p.z, ground)
            end
            out.kind, out.v, out.closed, out.segs = 'wall', v, true, n
            out.h = num(s.height, 1.0)
            out.a = math.floor(num(s.alpha, ca or 60))
            return out
        end
        out.kind, out.r = 'ring', r
        out.at = corner(p.x, p.y, p.z, opts.ground ~= false)
        out.a = math.floor(num(s.alpha, ca or 170))
    elseif kind == 'point' then
        local shape = s.shape
        if shape ~= 'ring' and shape ~= 'sphere' then
            shape = (asked or opts.ground == true) and 'ring' or 'sphere'
        end
        out.kind = shape
        out.at = corner(p.x, p.y, p.z, opts.ground == true)
        out.r = num(s.size, shape == 'ring' and 0.5 or 0.125 * math.max(0.1, num(opts.scale, 1.0)))
        out.a = math.floor(num(s.alpha, ca or (shape == 'ring' and 170 or 160)))
    else -- arrow
        local h = tonumber(opts.heading)
        out.size = math.max(0.1, num(s.size, num(opts.size, 1.2)))
        if h then
            out.kind, out.heading = 'flatArrow', math.rad(h)
            out.at = corner(p.x, p.y, p.z, opts.ground ~= false)
            out.a = math.floor(num(s.alpha, ca or 170))
        else
            out.kind = 'arrow'
            out.at = corner(p.x, p.y, p.z, false)
            out.a = math.floor(num(s.alpha, ca or 222))
        end
    end
    out.lift = lift
    return out
end

local function poly2(x1, y1, z1, x2, y2, z2, x3, y3, z3, c, al)
    -- both faces (a face is drawn from one side only)
    DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, c[1], c[2], c[3], al)
    DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, c[1], c[2], c[3], al)
end

local function drawPiece(s, i)
    local c, al = s.c, s.a
    if s.kind == 'wall' then
        local v = s.v
        local p, q = v[i], v[i % #v + 1]
        local pz, qz = baseZ(p), baseZ(q)
        local az, bz, at, bt = pz - 0.2, qz - 0.2, pz + s.h, qz + s.h
        poly2(p.x, p.y, az, q.x, q.y, bz, q.x, q.y, bt, c, al)
        poly2(p.x, p.y, az, q.x, q.y, bt, p.x, p.y, at, c, al)
        Citizen.InvokeNative(DRAW_LINE, p.x + 0.0, p.y + 0.0, pz + 0.1, q.x + 0.0, q.y + 0.0, qz + 0.1, c[1], c[2], c[3], 235)
        Citizen.InvokeNative(DRAW_LINE, p.x + 0.0, p.y + 0.0, at + 0.0, q.x + 0.0, q.y + 0.0, bt + 0.0, c[1], c[2], c[3], 235)
        return
    end
    local x, y, z = s.at.x, s.at.y, baseZ(s.at) + s.lift
    if s.kind == 'ring' then
        local d = s.r * 2.0
        DrawMarker(RING, x, y, z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 0.2, c[1], c[2], c[3], al,
            false, false, 2, false, nil, nil, false)
    elseif s.kind == 'sphere' then
        local d = s.r * 2.0
        DrawMarker(SPHERE, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, d, c[1], c[2], c[3], al,
            false, false, 2, false, nil, nil, false)
    elseif s.kind == 'arrow' then
        local L = s.size
        DrawMarker(ARROW, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, L * 0.75, L * 0.5, L * 0.375, c[1], c[2], c[3], al,
            false, false, 0, true, nil, nil, false)
    else -- a flat arrow on the ground, its tip at `at`, pointing along the heading
        local L, r = s.size, s.heading
        local fx, fy = -math.sin(r), math.cos(r)
        local rx, ry = fy, -fx
        local hl, hw, sw = L * 0.45, L * 0.3, L * 0.08
        local zz = z + 0.05
        local bx, by = x - fx * hl, y - fy * hl
        local ex, ey = x - fx * L, y - fy * L
        poly2(x, y, zz, bx + rx * hw, by + ry * hw, zz, bx - rx * hw, by - ry * hw, zz, c, al)
        poly2(bx + rx * sw, by + ry * sw, zz, ex + rx * sw, ey + ry * sw, zz, ex - rx * sw, ey - ry * sw, zz, c, al)
        poly2(bx + rx * sw, by + ry * sw, zz, ex - rx * sw, ey - ry * sw, zz, bx - rx * sw, by - ry * sw, zz, c, al)
    end
end

--- How far (squared, flat) the eye is from piece i of a polygon
local function pieceD2(s, i, at)
    if s.kind == 'wall' then
        local v = s.v
        local p, q = v[i], v[i % #v + 1]
        local dx, dy = q.x - p.x, q.y - p.y
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and math.max(0.0, math.min(1.0, ((at.x - p.x) * dx + (at.y - p.y) * dy) / len2)) or 0.0
        local ex, ey = p.x + dx * t - at.x, p.y + dy * t - at.y
        return ex * ex + ey * ey
    end
    local dx, dy = s.at.x - at.x, s.at.y - at.y
    local d = math.max(0.0, math.sqrt(dx * dx + dy * dy) - (s.r or s.size or 0.0))
    return d * d
end

--- The pieces of every polygon in range, nearest first, at most SOLID_BUDGET in all -> sh.vis = { piece index, ... }
local function cull(list, at)
    local cand = {}
    for _, sh in ipairs(list) do
        local s = sh.solid
        local r2 = sh.range * sh.range
        for i = 1, s.kind == 'wall' and s.segs or 1 do
            local d2 = pieceD2(s, i, at)
            if d2 <= r2 then cand[#cand + 1] = { sh = sh, i = i, d2 = d2 } end
        end
        sh.vis = {}
    end
    table.sort(cand, function(x, y) return x.d2 < y.d2 end)
    local probes = { n = PROBES }
    for k = 1, math.min(#cand, SOLID_BUDGET) do
        local e = cand[k]
        local s = e.sh.solid
        e.sh.vis[#e.sh.vis + 1] = e.i
        if s.kind == 'wall' then
            settle(s.v[e.i], probes)
            settle(s.v[e.i % #s.v + 1], probes)
        else
            settle(s.at, probes)
        end
    end
end

--- Every frame while a shape with a polygon exists: draws its pieces chosen by the last cull
local function runSolid()
    if solidRunning then return end
    solidRunning = true
    CreateThread(function()
        while true do
            local any, drew = false, false
            local now = GetGameTimer()
            for _, sh in pairs(shapes) do
                if sh.solid then
                    any = true
                    if sh.vis and #sh.vis > 0 and (not sh.frame or now - sh.at <= FRAME_DRAW) then
                        drew = true
                        local s = sh.solid
                        for _, i in ipairs(sh.vis) do
                            local ok, err = pcall(drawPiece, s, i)
                            if not ok then sh.solid = nil print(('^1w_lib glow: polygon draw error %s^7'):format(tostring(err))) break end
                        end
                    end
                end
            end
            if not any then break end
            Wait(drew and 0 or 100)
        end
        solidRunning = false
    end)
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
    local cand, solids = {}, {}
    for id, sh in pairs(shapes) do
        if sh.solid then solids[#solids + 1] = sh end
        local r2 = sh.range * sh.range
        for i, s in ipairs(sh.spots or {}) do
            local dx, dy = s.x - at.x, s.y - at.y
            local d2 = dx * dx + dy * dy
            if d2 <= r2 then cand[#cand + 1] = { key = id .. ':' .. i, d2 = d2, s = s } end
        end
    end
    cull(solids, at)
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

--- Makes (or remakes in place: opts.id) one shape. 4.2.0: a polygon unless opts.particle = true (then the glitter,
--- with its polygon too only when `solid` is given).
local function put(kind, a, b, opts)
    opts = type(opts) == 'table' and opts or {}
    local particle = opts.particle == true
    local spots = particle and BUILD[kind](a, b, opts) or nil
    if particle and not spots then return nil end
    local solid = (not particle or (opts.solid ~= nil and opts.solid ~= false)) and solidOf(kind, a, b, opts) or nil
    if not spots and not solid then return nil end
    local id = opts.id
    if id == nil then
        nextId = nextId + 1
        id = 'g' .. nextId
    end
    id = tostring(id)
    local range = math.max(1.0, num(opts.range, RANGE))
    if spots and range > RANGE then
        for _, s in ipairs(spots) do s.far = range end
    end
    local sh = { id = id, spots = spots, range = range, frame = opts.frame == true, at = GetGameTimer(), solid = solid }
    shapes[id] = sh
    if solid then
        -- seen at once (a moving cursor is drawn where it is now, not after the next tick)
        local ok, err = pcall(cull, { sh }, eye())
        if not ok then sh.vis = {} print(('^1w_lib glow: polygon error %s^7'):format(tostring(err))) end
        runSolid()
    end
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
    for _, k in ipairs({ 'look', 'scale', 'size', 'heading', 'step', 'lift', 'range', 'closed', 'ground', 'alpha', 'particle' }) do
        parts[#parts + 1] = tostring(opts[k])
    end
    local sd = opts.solid
    if type(sd) == 'table' then
        local sc = type(sd.color) == 'table' and sd.color or {}
        parts[#parts + 1] = ('solid:%s,%s,%s,%s,%s,%s,%s,%s,%s'):format(tostring(sc.r or sc[1]), tostring(sc.g or sc[2]),
            tostring(sc.b or sc[3]), tostring(sc.a or sc[4]), tostring(sd.alpha), tostring(sd.height), tostring(sd.size),
            tostring(sd.shape), tostring(sd.step))
    elseif sd ~= nil then
        parts[#parts + 1] = 'solid:' .. tostring(sd)
    end
    local c = opts.color
    if type(c) == 'table' then
        parts[#parts + 1] = tostring(c.r or c[1]) .. ',' .. tostring(c.g or c[2]) .. ',' .. tostring(c.b or c[3]) .. ',' .. tostring(c.a or c[4])
    end
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
    if sh and shapes[id].spots then
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
