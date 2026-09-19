if GetCurrentResourceName() == "w_lib" then return end

w.player = setmetatable({}, {
  __call = function()
    return w.player
  end
})

local instanceChangedCallbacks = {}

-------------
-- FUNCTIONS
-------------

--- A function fired when a player's routing bucket (instance) changes
---@param cb function (function called with `(source, newInstance, oldInstance)`)
function w.player.instanceChanged(cb)
  if not cb then return eprint("The callback function is nil") end
  instanceChangedCallbacks[#instanceChangedCallbacks + 1] = cb
end

AddEventHandler("w_lib:player:instanceChanged", function(source, newInstance, oldInstance)
  for i = 1, #instanceChangedCallbacks do
    local status, err = pcall(instanceChangedCallbacks[i], source, newInstance, oldInstance)
    if not status then
      log("Error in w.player.instanceChanged callback: %s", err)
    end
  end
end)

-------------
-- Shortcut
-------------
w.pl = w.player
