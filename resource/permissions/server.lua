-- Generic logical permission nodes for Wraith resources.
-- Supports exact ACEs and hierarchical wildcard ACEs without coupling callers
-- to any framework's group implementation.

local function normalizeNode(node)
    if type(node) ~= 'string' then return nil, 'permission node must be a string' end

    node = node:lower():match('^%s*(.-)%s*$') or ''

    if node == '' or #node > 96 then
        return nil, 'permission node must contain between 1 and 96 characters'
    end

    if node:sub(1, 1) == '.' or node:sub(-1) == '.' or node:find('..', 1, true) then
        return nil, 'permission node must be dot-delimited lowercase identifiers'
    end
    for segment in node:gmatch('[^.]+') do
        if not segment:match('^[a-z][a-z0-9_%-]*$') then
            return nil, 'permission node must be dot-delimited lowercase identifiers'
        end
    end

    return node
end

local function isFrameworkAdmin(source)
    local ok, allowed = pcall(function()
        return exports.w_lib:IsAdmin(source)
    end)

    return ok and allowed == true
end

local function hasPermissionNode(source, node)
    source = tonumber(source)
    local normalized, reason = normalizeNode(node)

    if not normalized then return false, reason end
    if source == 0 then return true, 'console' end

    if not source or source < 1 or not GetPlayerName(source) then
        return false, 'invalid source'
    end

    if isFrameworkAdmin(source) then return true, 'admin' end
    if IsPlayerAceAllowed(source, normalized) then return true, normalized end

    local parts = {}
    for part in normalized:gmatch('[^.]+') do parts[#parts + 1] = part end

    for index = #parts - 1, 1, -1 do
        local wildcard = table.concat(parts, '.', 1, index) .. '.*'
        if IsPlayerAceAllowed(source, wildcard) then return true, wildcard end
    end

    if IsPlayerAceAllowed(source, '*') then return true, '*' end
    return false, 'forbidden'
end

exports('HasPermissionNode', hasPermissionNode)
