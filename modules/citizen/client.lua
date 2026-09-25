-------------
-- citizen (client) — the local player's own citizen id, and the one input row every form uses
-- to ask for someone's citizen id (same label, placeholder and help text in every resource).
-- Who an id IS is a server question: see server.lua.
-------------
local citizen = w.createModule("citizen")

--- The local character's citizen id ('12'), or nil before a character is in play and on cores
--- that keep no player data on the client (VORP). Reads the core's player data each call:
--- fine for a menu, not for every frame.
---@return string|nil
function citizen.myId()
  local ok, data = pcall(function() return exports.w_lib:FwGetPlayerData() end)
  local id = ok and type(data) == "table" and data.citizenid or nil
  if id == nil then return nil end
  return citizen.normalize(id) or tostring(id)
end

--- A lib.inputDialog / w.input row asking for a citizen id, labelled in the player's language
--- ("Citizen ID" / "رقم المواطن", with the '#<server id>' hint). `overrides` replaces any field.
---   local input = w.inputDialog(title, { w.citizen.inputRow() })
---   local kind = input and w.citizen.parse(input[1])   -- refuse a malformed id before asking
---@param overrides? table
---@return table
function citizen.inputRow(overrides)
  local row = {
    type = "input",
    label = citizen.text("label"),
    placeholder = citizen.text("placeholder"),
    description = citizen.text("help"),
    required = true,
  }
  if type(overrides) == "table" then
    for key, value in pairs(overrides) do row[key] = value end
  end
  return row
end

return citizen
