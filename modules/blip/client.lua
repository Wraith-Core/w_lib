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
