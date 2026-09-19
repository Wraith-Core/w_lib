-------------
-- VARIABLES
-------------
local myIdentifiers = {}

-------------
-- CORE
-------------
w.framework:loadCoreFiles("client")

--- A function to get the user identifiers
function w.framework:getMyIdentifiers()
  if table.isEmpty(myIdentifiers) then
    myIdentifiers = w.callback.triggerServer(w.resourceName .. ":server:framework:getPlayerIdentifiers")
  end
  return myIdentifiers
end

-------------
-- Inventories
-------------
w.framework:loadInventoryFiles("client")
