--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@diagnostic disable: duplicate-set-field

---@private
---@param model string | number
---@param x number
---@param y number
---@param z number
---@param heading? number
---@return Ped
---@see CreatePed
---`server`
function lib.ped.create(model, x, y, z, heading)
    -- FXServer's generated CREATE_PED RPC uses the GTA pedType-first
    -- signature. RedM's client native is model-first with two additional
    -- trailing arguments, so the RPC can return a positive surrogate handle
    -- that never becomes an entity. Consumers must delegate RedM creation to
    -- a ticket-bound client and validate the resulting network entity.
    local gameName = ''
    if type(GetConvar) == 'function' then
        local ok, value = pcall(GetConvar, 'gamename', '')
        if ok then gameName = tostring(value or ''):lower() end
    end
    if gameName == '' and type(GetGameName) == 'function' then
        local ok, value = pcall(GetGameName)
        if ok then gameName = tostring(value or ''):lower() end
    end
    if gameName == 'rdr3' or gameName == 'redm' then
        return lib.ped:new(0), 'server_create_ped_unsupported'
    end

    local handle = CreatePed(0, model, x, y, z, heading or 0, true, true)

    -- Server-side entity creation is asynchronous under OneSync.  In
    -- particular, RedM can return a positive creation handle one or more
    -- scheduler ticks before that handle is safe to pass to
    -- NetworkGetNetworkIdFromEntity (which lib.ped:new does in setHandle).
    -- Bound the wait so a failed model/artifact cannot stall its caller
    -- indefinitely or produce an invalid-entity exception on every retry.
    if not handle or handle <= 0 then return lib.ped:new(0) end

    local deadline = GetGameTimer() + 2500
    local stableChecks = 0

    repeat
        local ok, exists = pcall(DoesEntityExist, handle)
        stableChecks = ok and exists == true and (stableChecks + 1) or 0
        if stableChecks < 2 then Wait(10) end
    until stableChecks >= 2 or GetGameTimer() >= deadline

    if stableChecks < 2 then return lib.ped:new(0) end

    -- DoesEntityExist and network-id lookup are separate server operations;
    -- the entity can still disappear between them.  Keep that last race from
    -- escaping the generic bridge.  Callers receive the normal zero wrapper
    -- and can apply their own retry/backoff policy.
    local ok, ped = pcall(function() return lib.ped:new(handle) end)
    if not ok then return lib.ped:new(0) end

    return ped
end

return lib.ped
