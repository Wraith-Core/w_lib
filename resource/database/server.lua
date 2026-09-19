-- Generic server-only database bridge.
--
-- Consumers should not need to know which SQL driver w_lib uses. All methods
-- return `result, nil` on success and `nil/false, error` on failure, where the
-- error is a small serialisable table. Query parameters are never interpolated
-- here; they are forwarded to oxmysql's prepared parameter handling.

local ready = false
local readyError

local function dbError(operation, code, message)
    return {
        operation = operation,
        code = code,
        message = tostring(message or code):sub(1, 1024),
    }
end

local function caller()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function report(operation, err)
    local message = ('database %s failed for %s [%s]: %s')
        :format(operation, caller(), err.code, err.message)

    if lib.print and lib.print.error then
        lib.print.error(message)
    else
        print(('^1[w_lib] %s^0'):format(message))
    end
end

local function validSql(operation, sql)
    if type(sql) ~= 'string' then
        return nil, dbError(operation, 'invalid_query', 'query must be a string')
    end

    sql = sql:match('^%s*(.-)%s*$') or ''

    if sql == '' then
        return nil, dbError(operation, 'invalid_query', 'query cannot be empty')
    end

    if #sql > 1024 * 1024 then
        return nil, dbError(operation, 'query_too_large', 'query exceeds 1 MiB')
    end

    if sql:find('\0', 1, true) then
        return nil, dbError(operation, 'invalid_query', 'query contains a NUL byte')
    end

    return sql
end

local function validParameters(operation, parameters)
    if parameters == nil then return {} end

    if type(parameters) ~= 'table' then
        return nil, dbError(operation, 'invalid_parameters', 'parameters must be a table')
    end

    local seen = {}

    local function visit(value, depth)
        local valueType = type(value)

        if valueType == 'number' then
            if value ~= value or value == math.huge or value == -math.huge then
                return false, 'numeric parameter must be finite'
            end
            return true
        end

        if valueType == 'nil' or valueType == 'string' or valueType == 'boolean' then
            return true
        end

        if valueType ~= 'table' then
            return false, ('unsupported parameter type %s'):format(valueType)
        end

        if seen[value] then return false, 'cyclic parameter table' end
        if depth > 8 then return false, 'parameter nesting exceeds 8 levels' end

        seen[value] = true
        local count = 0

        for key, nested in pairs(value) do
            count = count + 1
            if count > 10000 then
                seen[value] = nil
                return false, 'parameter table exceeds 10000 entries'
            end

            local keyType = type(key)
            if keyType ~= 'string' and keyType ~= 'number' then
                seen[value] = nil
                return false, ('unsupported parameter key type %s'):format(keyType)
            end

            local ok, reason = visit(nested, depth + 1)
            if not ok then
                seen[value] = nil
                return false, reason
            end
        end

        seen[value] = nil
        return true
    end

    local ok, reason = visit(parameters, 1)
    if not ok then
        return nil, dbError(operation, 'invalid_parameters', reason)
    end

    return parameters
end

local function execute(operation, method, sql, parameters)
    local query, queryError = validSql(operation, sql)
    if not query then return nil, queryError end

    local values, parameterError = validParameters(operation, parameters)
    if not values then return nil, parameterError end

    if not ready then
        return nil, readyError or dbError(operation, 'not_ready', 'database is not ready')
    end

    local ok, result = pcall(method, query, values)
    if not ok then
        local err = dbError(operation, 'query_failed', result)
        report(operation, err)
        return nil, err
    end

    return result, nil
end

CreateThread(function()
    local ok, result = pcall(MySQL.ready.await)

    if not ok then
        readyError = dbError('ready', 'connection_failed', result)
        report('ready', readyError)
        return
    end

    local pingOk, pingResult = pcall(MySQL.scalar.await, 'SELECT 1', {})
    if not pingOk or tonumber(pingResult) ~= 1 then
        readyError = dbError('ready', 'healthcheck_failed', pingOk and 'SELECT 1 returned an unexpected result' or pingResult)
        report('ready', readyError)
        return
    end

    ready = true
    readyError = nil
end)

exports('DbReady', function(timeoutMs)
    timeoutMs = tonumber(timeoutMs) or 0
    timeoutMs = math.max(0, math.min(math.floor(timeoutMs), 60000))

    local deadline = GetGameTimer() + timeoutMs
    while not ready and not readyError and GetGameTimer() < deadline do
        Wait(25)
    end

    if ready then return true, nil end
    return false, readyError or dbError('ready', 'timeout', ('database was not ready within %d ms'):format(timeoutMs))
end)

exports('DbQuery', function(sql, parameters)
    return execute('query', MySQL.query.await, sql, parameters)
end)

exports('DbSingle', function(sql, parameters)
    return execute('single', MySQL.single.await, sql, parameters)
end)

exports('DbScalar', function(sql, parameters)
    return execute('scalar', MySQL.scalar.await, sql, parameters)
end)

exports('DbInsert', function(sql, parameters)
    return execute('insert', MySQL.insert.await, sql, parameters)
end)

exports('DbUpdate', function(sql, parameters)
    return execute('update', MySQL.update.await, sql, parameters)
end)

exports('DbTransaction', function(queries, sharedParameters)
    local operation = 'transaction'

    if type(queries) ~= 'table' or #queries == 0 or #queries > 256 then
        return false, dbError(operation, 'invalid_queries', 'queries must be a non-empty array with at most 256 entries')
    end

    local normalized = {}

    for index = 1, #queries do
        local entry = queries[index]

        if type(entry) == 'string' then
            local query, err = validSql(operation, entry)
            if not query then
                err.index = index
                return false, err
            end
            normalized[index] = query
        elseif type(entry) == 'table' then
            local query, err = validSql(operation, entry.query)
            if not query then
                err.index = index
                return false, err
            end

            local values, parameterError = validParameters(operation, entry.values or entry.parameters)
            if not values then
                parameterError.index = index
                return false, parameterError
            end

            normalized[index] = { query = query, values = values }
        else
            local err = dbError(operation, 'invalid_query', ('query %d must be a string or table'):format(index))
            err.index = index
            return false, err
        end
    end

    local parameters, parameterError = validParameters(operation, sharedParameters)
    if not parameters then return false, parameterError end

    if not ready then
        return false, readyError or dbError(operation, 'not_ready', 'database is not ready')
    end

    local ok, result = pcall(MySQL.transaction.await, normalized, parameters)
    if not ok then
        local err = dbError(operation, 'transaction_failed', result)
        report(operation, err)
        return false, err
    end

    if result ~= true then
        local err = dbError(operation, 'transaction_rolled_back', 'database rejected or rolled back the transaction')
        report(operation, err)
        return false, err
    end

    return true, nil
end)
