w.createModule("database")

w.file.load("@oxmysql.lib.MySQL")

-- The module is oxmysql's own surface plus the helpers below. Anything not defined here
-- (query / single / scalar / insert / update / prepare / transaction / rawExecute / ready,
-- each with its .await) is answered by MySQL directly, so a resource writes
-- `w.database.query.await(sql, params)` and never loads the driver itself.
setmetatable(w.database, {
  __index = function(_, key)
    local mysql = rawget(_G, "MySQL")
    return mysql and mysql[key] or nil
  end,
})

--- A function to create a table if not exist
---@param tableName string (The name of the table)
---@param definition string (The definition of the table)
---@return boolean (Return `true` if the table is created, `false` otherwise)
function w.database.addTable(tableName, definition)
  local isExist = w.database.doesTableExist(tableName)
  if isExist then
    return false
  end

  -- the collation is named: without it the table takes the database default (utf8_general_ci on
  -- some installs), and an id column compared with players.citizenid (utf8mb4_general_ci) in a
  -- JOIN fails with "Illegal mix of collations"
  MySQL.update.await("CREATE TABLE IF NOT EXISTS " .. tableName .. " (" .. definition .. ") DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci")
  gprint("Database table created: " .. tableName)
  return true
end

--- A function to create a trigger if not exist
---@param triggerName string (The name of the trigger)
---@param definition string (The definition of the trigger)
---@return boolean (Return `true` if the trigger is created, `false` otherwise)
function w.database.addTrigger(triggerName, definition)
  local isExist = MySQL.single.await("SHOW TRIGGERS WHERE `Trigger` = ?", { triggerName })
  if isExist then
    return false
  end
  MySQL.query.await("CREATE TRIGGER `" .. triggerName .. "` " .. definition)
  gprint("Database trigger created: " .. triggerName)
  return true
end

--- A function to create a column in a specific table if not exist
---@param tableName string (The name of the table)
---@param name string (The name of the column)
---@param definition string (The definition of the column)
---@return boolean (Return `true` if the column is created, `false` otherwise)
function w.database.addColumn(tableName, name, definition)
  local tableExists = MySQL.single.await("SHOW TABLES LIKE ?", { tableName })
  if not tableExists then
    error("Table " .. tableName .. " does not exist")
    return false
  end

  local isExist = MySQL.single.await("SHOW COLUMNS FROM " .. tableName .. " LIKE ?", { name })
  if isExist then
    return false
  end

  gprint("Database column " .. name .. " added to " .. tableName)
  MySQL.update.await("ALTER TABLE `" .. tableName .. "` ADD `" .. name .. "` " .. definition)
  return true
end

--- A function to check if a table exists
---@param tableName string (The name of the table)
---@return boolean (Return `true` if the table exists, `false` otherwise)
function w.database.doesTableExist(tableName)
  local isExist = MySQL.single.await("SHOW TABLES LIKE ?", { tableName })
  if isExist then
    return true
  end
  return false
end
