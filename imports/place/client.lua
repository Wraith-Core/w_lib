--[[
    w_lib · imports/place/client.lua (4.5.0) -- a place in words: the town (else the district) and how far it is

    The builders' «فالنتاين · 12 م منك» (w_missions / w_jobs / w_heists), shared: a board never shows a raw coordinate.

        lib.place.describe(coords[, from]) -> {
            zone   = 'valentine',              -- the key (a town, else a district, else 'wild')
            name   = 'فالنتاين',               -- the zone in the player's language
            meters = 12,                       -- from `from` (default: the player's ped)
            far    = '12 م منك',               -- 'هنا' within 3 m
            text   = 'فالنتاين · 12 م منك',    -- name + far
        }
        lib.place.zone(coords)      -> 'valentine' | 'bayou_nwa' | ... | 'wild'
        lib.place.name(key)         -> the zone's words ('فالنتاين')
        lib.place.distance(meters)  -> '12 م' / '450 م' / '1.2 كم'

    coords / from: a vector3 / vector4, or { x =, y =, z? = }. Returns nil for something that is not a place.

    ★ The words are w_lib's own (locales/<lang>.json "place"), read once through exports.w_lib:placeWords() and read
      again when the player changes the language. The town / district hashes are w_zonenotify's (the builders' copy):
      GetMapZoneAtCoords type 1 = town, 10 = district.
    ★ A zone is remembered per 8 m cell (at most 1024 cells, then the memory starts over): a board that describes
      every one of its places each second asks the game once per place.
]]

local place = {}

local TOWNS = {
    [459833523] = 'valentine', [2046780049] = 'rhodes', [-765540529] = 'saint_denis', [427683330] = 'strawberry',
    [1053078005] = 'blackwater', [-744494798] = 'armadillo', [-1524959147] = 'tumbleweed', [7359335] = 'annesburg',
    [2126321341] = 'van_horn', [201158410] = 'manicato', [1463094051] = 'manzanita_post',
}
local DISTRICTS = {
    [2025841068] = 'bayou_nwa', [822658194] = 'big_valley', [1308232528] = 'bluewater_marsh',
    [1835499550] = 'cumberland_forest', [476637847] = 'great_plains', [1645618177] = 'grizzlies',
    [-120156735] = 'grizzlies', [-512529193] = 'guarma', [131399519] = 'heartlands', [178647645] = 'roanoke_ridge',
    [-864275692] = 'scarlett_meadows', [1684533001] = 'tall_trees', [-2066240242] = 'gaptooth_ridge',
    [-2145992129] = 'rio_bravo', [-108848014] = 'cholla_springs', [892930832] = 'hennigans_stead',
}
local ZONE_TOWN, ZONE_DISTRICT = 1, 10

local FALLBACK = { zones = {}, wild = 'the wilds', here = 'here', m = '%s m', km = '%s km', away = '%s away', sep = ' · ' }

local words
local function W()
    if words then return words end
    local ok, got = pcall(function() return lib.placeWords() end)
    words = (ok and type(got) == 'table') and got or FALLBACK
    if type(words.zones) ~= 'table' then words.zones = {} end
    return words
end
AddEventHandler('w_lib:setLocale', function() words = nil end)

--- x, y, z of a vector or a table, or nil
local function xyz(c)
    local t = type(c)
    if t == 'vector3' or t == 'vector4' then return c.x, c.y, c.z end
    if t == 'table' then
        local x, y = tonumber(c.x or c[1]), tonumber(c.y or c[2])
        if x and y then return x, y, tonumber(c.z or c[3]) end
    end
    return nil
end

local cells, cellCount = {}, 0

---@param coords vector3|vector4|table
---@return string zone 'valentine' | 'bayou_nwa' | ... | 'wild' (nil when coords is not a place)
function place.zone(coords)
    local x, y, z = xyz(coords)
    if not x then return nil end
    local cell = ('%d:%d'):format(math.floor(x / 8), math.floor(y / 8))
    local hit = cells[cell]
    if hit then return hit end
    local zone = 'wild'
    local okT, town = pcall(GetMapZoneAtCoords, x + 0.0, y + 0.0, (z or 100.0) + 0.0, ZONE_TOWN)
    if okT and TOWNS[town] then
        zone = TOWNS[town]
    else
        local okD, district = pcall(GetMapZoneAtCoords, x + 0.0, y + 0.0, (z or 100.0) + 0.0, ZONE_DISTRICT)
        if okD and DISTRICTS[district] then zone = DISTRICTS[district] end
    end
    if cellCount >= 1024 then cells, cellCount = {}, 0 end
    cells[cell], cellCount = zone, cellCount + 1
    return zone
end

---@param key string
---@return string
function place.name(key)
    local w = W()
    if key == 'wild' or key == nil then return w.wild or FALLBACK.wild end
    return w.zones[key] or key
end

---@param meters number
---@return string
function place.distance(meters)
    local w = W()
    local m = tonumber(meters) or 0
    if m < 1000 then
        local n = m < 100 and math.floor(m + 0.5) or math.floor(m / 10 + 0.5) * 10
        return (w.m or FALLBACK.m):format(n)
    end
    local km = ('%.1f'):format(m / 1000):gsub('%.0$', '')
    return (w.km or FALLBACK.km):format(km)
end

---@param coords vector3|vector4|table
---@param from? vector3|table the point the distance is counted from (default: the player's ped)
---@return { zone: string, name: string, meters: number, far: string, text: string }?
function place.describe(coords, from)
    local x, y, z = xyz(coords)
    if not x then return nil end
    local zone = place.zone(coords)
    local name = place.name(zone)
    local fx, fy = xyz(from)
    if not fx then
        local ok, c = pcall(function() return GetEntityCoords(PlayerPedId()) end)
        if ok and c then fx, fy = c.x, c.y end
    end
    local w = W()
    local meters = fx and math.sqrt((x - fx) ^ 2 + (y - fy) ^ 2) or 0
    local far = meters < 3 and (w.here or FALLBACK.here) or (w.away or FALLBACK.away):format(place.distance(meters))
    return {
        zone = zone,
        name = name,
        meters = math.floor(meters + 0.5),
        far = far,
        text = name .. (w.sep or FALLBACK.sep) .. far,
    }
end

return place
