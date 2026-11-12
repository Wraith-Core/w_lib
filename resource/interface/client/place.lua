--[[
    w_lib · resource/interface/client/place.lua (4.5.0) -- the place words in the player's language

    lib.placeWords() (exported) -> { zones = { valentine = 'فالنتاين', ... }, wild, here, m, km, away, sep }
    Read by imports/place/client.lua (lib.place.describe) inside every consumer, once and again on a language change,
    so the zone names live in ONE place: w_lib's locales/<lang>.json "place".
    lib.worldEditWords() (exported) -> the "worldedit" words for imports/worldEdit/client.lua (lib.worldEdit).
]]

local ZONES = {
    'valentine', 'rhodes', 'saint_denis', 'strawberry', 'blackwater', 'armadillo', 'tumbleweed', 'annesburg',
    'van_horn', 'manicato', 'manzanita_post', 'bayou_nwa', 'big_valley', 'bluewater_marsh', 'cumberland_forest',
    'great_plains', 'grizzlies', 'guarma', 'heartlands', 'roanoke_ridge', 'scarlett_meadows', 'tall_trees',
    'gaptooth_ridge', 'rio_bravo', 'cholla_springs', 'hennigans_stead',
}

local function word(key, fallback)
    local ok, v = pcall(locale, key)
    if ok and type(v) == 'string' and v ~= key then return v end
    return fallback
end

---@return { zones: table<string, string>, wild: string, here: string, m: string, km: string, away: string, sep: string }
function lib.placeWords()
    local zones = {}
    for i = 1, #ZONES do
        local k = ZONES[i]
        zones[k] = word('place.zone.' .. k, k)
    end
    return {
        zones = zones,
        wild = word('place.wild', 'the wilds'),
        here = word('place.here', 'here'),
        m = word('place.m', '%s m'),
        km = word('place.km', '%s km'),
        away = word('place.away', '%s away'),
        sep = word('place.sep', ' · '),
    }
end

-- the world-edit words (locales "worldedit"), read by imports/worldEdit/client.lua inside every consumer
local WORLD_KEYS = {
    'what', 'key_here', 'key_edit', 'key_board', 'key_turn', 'key_bigger', 'key_smaller', 'key_remove', 'key_undo',
    'line', 'line_pin', 'move', 'move_d', 'face', 'face_d', 'remove', 'remove_d', 'open', 'open_d', 'go', 'go_d',
    'pin', 'place', 'save', 'cancel',
}

---@return table<string, string>
function lib.worldEditWords()
    local out = {}
    for i = 1, #WORLD_KEYS do
        local k = WORLD_KEYS[i]
        out[k] = word('worldedit.' .. k, k)
    end
    return out
end
