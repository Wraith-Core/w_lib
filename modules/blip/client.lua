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
---@return integer|false blip The blip ID on success, or `false` if the entity does not exist
function w.blip.create(locationOrEntity, name, sprite, blipHash, color)
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
  if color then
    BlipAddModifier(blip, GetHashFromString(color))
  end
  Blips[#Blips + 1] = blip

  Known[blip] = { name = name, sprite = sprite, color = color }
  announce(blip, Known[blip])

  return blip
end
