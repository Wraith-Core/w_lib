local Blips = {}
w.createModule("blip")

w.stopped(function()
  for _, blip in pairs(Blips) do
    RemoveBlip(blip)
  end
end)

-- ★ w_map draws its own map screen and RDR3 gives it no way to read a blip's
--   sprite or name back from the engine (no GET_BLIP_SPRITE / GET_BLIP_NAME).
--   Every blip made here is announced to it, and remembered so that a w_map
--   that starts (or restarts) *after* this resource still learns about them.
local Known = {}   -- handle -> { name, sprite, color }

local function announce(blip, data)
  if GetResourceState('w_map') ~= 'started' then return end
  pcall(function() exports.w_map:Register(blip, data) end)
end

AddEventHandler('onClientResourceStart', function(resource)
  if resource ~= 'w_map' then return end
  CreateThread(function()
    Wait(1000)
    for blip, data in pairs(Known) do
      if DoesBlipExist(blip) then announce(blip, data) else Known[blip] = nil end
    end
  end)
end)

--- Create a new blip
--- This function adds a blip at the specified location or on an entity with customizable properties.
---@param locationOrEntity vector3|integer The world coordinates or entity handle to attach the blip to
---@param name string The label displayed on the map for this blip
---@param sprite string|integer The sprite name or its hash ([Non exhaustive list](https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures/blips))
---@param blipHash? integer The blip type hash - default: `1664425300`
---@param color? string The color modifier name applied to the blip (resolved via `GetHashFromString`)
---@param scale? number The blip scale (default 1.0)
---@return integer|false blip The blip ID on success, or `false` if the entity does not exist
function w.blip.create(locationOrEntity, name, sprite, blipHash, color, scale)
  if not blipHash then blipHash = 1664425300 end
  if type(sprite) == "string" then sprite = joaat(sprite) end

  local blip
  if type(locationOrEntity) == "number" then
    if not DoesEntityExist(locationOrEntity) then
      return false
    end
    blip = BlipAddForEntity(blipHash, locationOrEntity)
  else
    blip = BlipAddForCoords(blipHash, locationOrEntity.x, locationOrEntity.y, locationOrEntity.z)
  end

  SetBlipSprite(blip, sprite)
  SetBlipName(blip, name)
  -- ★ A '#rrggbb' colour is w_map's only (any colour, drawn on its map screen): the game's own map knows its fixed
  --   BLIP_MODIFIER colours alone, so the engine's blip keeps its plain look and w_map gets the hex below.
  if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
    -- nothing for the engine
  elseif color then
    BlipAddModifier(blip, GetHashFromString(color))
  end
  if tonumber(scale) and tonumber(scale) > 0 then
    SetBlipScale(blip, tonumber(scale) + 0.0)
  end
  Blips[#Blips + 1] = blip

  -- exact: a hex colour is the script's own choice, so w_map draws it as it is (not toned to its black and white)
  local exact = type(color) == "string" and color:match("^#%x%x%x%x%x%x$") ~= nil or nil
  Known[blip] = { name = name, sprite = sprite, color = color, scale = scale, exact = exact }
  announce(blip, Known[blip])

  return blip
end

-- The area styles a radius blip is tried with, in order (the game refuses some styles on some builds)
local RADIUS_STYLES = { joaat("BLIP_STYLE_AREA"), -1282792512, joaat("BLIP_STYLE_DANGEROUS_AREA") }

--- An area on the game's own map and radar: a circle of `radius` metres (2026-11-05: w_kingdoms' war fronts called
--- this before it existed; w_tribes' camps when w_map is off). It is the engine's only area: a circle, never a polygon.
--- Not announced to w_map, which draws its own zones (exports.w_map:UpsertTerritories).
---@param coords vector3 its middle
---@param radius number metres
---@param name? string
---@param color? string a BLIP_MODIFIER name (a '#rrggbb' colour has no engine equivalent: the area keeps its own)
---@param style? string|integer the radius blip's style (default: the area styles above)
---@return integer|false blip
function w.blip.radius(coords, radius, name, color, style)
  radius = tonumber(radius)
  if not coords or not radius or radius <= 0 then return false end
  local tries = {}
  if style then tries[1] = type(style) == "string" and joaat(style) or style end
  for _, s in ipairs(RADIUS_STYLES) do tries[#tries + 1] = s end
  local blip
  for _, s in ipairs(tries) do
    blip = BlipAddForRadius(s, coords.x + 0.0, coords.y + 0.0, (coords.z or 0.0) + 0.0, radius + 0.0)
    if blip and blip ~= 0 then break end
    blip = nil
  end
  if not blip then return false end
  if name then SetBlipName(blip, name) end
  if type(color) == "string" and color ~= "" and not color:match("^#") then
    BlipAddModifier(blip, GetHashFromString(color))
  end
  Blips[#Blips + 1] = blip
  return blip
end

-- ── the game's blip pictures, for every Wraith script (2026-11-05) ─────────────────────────────────────────────
-- w_lib ships all 631 (web/build/tex/blips/<name>.png, with index.json: { { name, hash }, ... }), so a script's menu
-- or page shows a blip's picture without w_map or a copy of its own.
local PICTURES = "nui://w_lib/web/build/tex/blips/"

--- The picture of a blip sprite, as a URL any NUI page can show (nil for a name w_lib has no picture of).
---@param name string a sprite name, e.g. 'blip_camp'
---@return string|nil
function w.blip.picture(name)
  if type(name) ~= "string" or not name:match("^[%w_]+$") then return nil end
  return PICTURES .. name .. ".png"
end

local spriteList
--- Every blip sprite w_lib has a picture of: { { name, hash }, ... } sorted by name (read once).
---@return table
function w.blip.sprites()
  if not spriteList then
    local ok, list = pcall(json.decode, LoadResourceFile("w_lib", "web/build/tex/blips/index.json") or "")
    if not ok or type(list) ~= "table" then return {} end   -- not kept: read again next time
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    spriteList = list
  end
  return spriteList
end

--- Rename a blip made with w.blip.create (w_map learns the new name too).
---@param blip integer
---@param name string
---@return boolean
function w.blip.setName(blip, name)
  if not blip or not DoesBlipExist(blip) then return false end
  SetBlipName(blip, name)
  if Known[blip] then
    Known[blip].name = name
    announce(blip, Known[blip])
  end
  return true
end

--- Change the sprite of a blip made with w.blip.create.
---@param blip integer
---@param sprite string|integer
---@return boolean
function w.blip.setSprite(blip, sprite)
  if not blip or not DoesBlipExist(blip) then return false end
  if type(sprite) == "string" then sprite = joaat(sprite) end
  SetBlipSprite(blip, sprite)
  if Known[blip] then
    Known[blip].sprite = sprite
    announce(blip, Known[blip])
  end
  return true
end

--- Move a coordinate blip.
---@param blip integer
---@param coords vector3
---@return boolean
function w.blip.setCoords(blip, coords)
  if not blip or not DoesBlipExist(blip) or not coords then return false end
  SetBlipCoords(blip, coords.x + 0.0, coords.y + 0.0, (coords.z or 0.0) + 0.0)
  return true
end

--- Change the scale of a blip.
---@param blip integer
---@param scale number
---@return boolean
function w.blip.setScale(blip, scale)
  if not blip or not DoesBlipExist(blip) then return false end
  SetBlipScale(blip, (tonumber(scale) or 1.0) + 0.0)
  return true
end

--- Remove a blip made with w.blip.create.
---@param blip integer
---@return boolean
function w.blip.remove(blip)
  if not blip then return false end
  if DoesBlipExist(blip) then RemoveBlip(blip) end
  Known[blip] = nil
  for i = #Blips, 1, -1 do
    if Blips[i] == blip then table.remove(Blips, i) end
  end
  if GetResourceState('w_map') == 'started' then
    pcall(function() exports.w_map:Unregister(blip) end)
  end
  return true
end

w.blip.delete = w.blip.remove
