-------------
-- language — the one place a resource asks "which language am I speaking?"
--
-- The library owns the language: the player's own choice on the client (settings.locale),
-- the server convar `w_lib:locale` (then `w_lib:i18n:locale`) on the server. This module
-- reads it through exports.w_lib:getLocaleKey() so a consumer never touches convars, and
-- gives configs the three helpers they use: key(), select(), bind() / bindLabels().
--
-- Shared: a config file is loaded on both sides and calls these before anything else.
-------------
-- Also returned at the end, so a test harness can `execute` this file and get the module
-- without w_lib's loader.
local language = (type(w) == "table" and w.createModule) and w.createModule("language") or {}
if type(w) == "table" and rawget(w, "language") == nil then rawset(w, "language", language) end

local DEFAULT = "en"
local RTL = { ar = true, he = true, fa = true, ur = true }

--- Two lower-case letters, whatever the source wrote ("ar-SA", "AR", "arabic" -> "ar")
---@param key any
---@return string
local function normalize(key)
  key = tostring(key or ""):lower():match("^%s*([a-z][a-z])") or DEFAULT
  return key
end

local function fromLibrary()
  local ok, key = pcall(function() return exports.w_lib:getLocaleKey() end)
  if ok and type(key) == "string" and key ~= "" then return key end
  return GetConvar("w_lib:locale", GetConvar("w_lib:i18n:locale", DEFAULT))
end

--- The current language key. On the server `src` asks for THAT player's language (his own
--- choice from /w_lib, mirrored into Player(src).state['w_lib:locale']); without it, or on
--- the client, the language of this side.
---@param src? number (server only: a player's server id)
---@return string (Return `"ar"`, `"en"`, ... always two lower-case letters)
function language.key(src)
  if src and IsDuplicityVersion() then
    local ok, key = pcall(function() return exports.w_lib:getPlayerLocaleKey(src) end)
    if ok and type(key) == "string" and key ~= "" then return normalize(key) end
  end
  return normalize(fromLibrary())
end

--- The language a piece of text is written in, from its script: Arabic letters -> "ar",
--- Latin letters -> "en", anything else (digits, emoji, empty) -> `fallback` or the current
--- language. Counts letters, so "ok شكرا" is Arabic and "شكرا ok thanks" is English.
---@param text any
---@param fallback? string
---@return string
function language.fromText(text, fallback)
  local default = normalize(fallback or language.key())
  if type(text) ~= "string" or text == "" then return default end
  local arabic, latin = 0, 0
  for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local b = ch:byte(1)
    if #ch == 2 and b >= 0xD8 and b <= 0xDD then
      -- U+0600..U+077F: Arabic, Arabic supplement (lead bytes D8..DD)
      arabic = arabic + 1
    elseif #ch == 3 and b == 0xEF then
      -- U+FB50..U+FDFF and U+FE70..U+FEFF: the Arabic presentation forms
      local b2 = ch:byte(2)
      if (b2 >= 0xAD and b2 <= 0xB7) or (b2 >= 0xB9 and b2 <= 0xBB) then arabic = arabic + 1 end
    elseif #ch == 1 and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122)) then
      latin = latin + 1
    end
  end
  if arabic == 0 and latin == 0 then return default end
  if arabic > latin then return "ar" end
  if latin > arabic then return "en" end
  return default
end

--- Is the current (or given) language written right to left?
---@param key? string
---@return boolean
function language.isRTL(key)
  return RTL[normalize(key or language.key())] == true
end

--- Picks the current language's entry out of a table keyed by locale.
--- Falls back to English, then to whatever entry exists, so a config never ends up nil.
---@param byLocale table ({ ar = ..., en = ... })
---@param key? string (Force a locale instead of the current one)
---@return any
function language.select(byLocale, key)
  if type(byLocale) ~= "table" then return byLocale end
  key = normalize(key or language.key())
  local value = byLocale[key]
  if value == nil then value = byLocale[DEFAULT] end
  if value == nil then
    for _, first in pairs(byLocale) do value = first break end
  end
  return value
end

--- Is this a `{ ar = ..., en = ... }` style table (every key a two-letter locale)?
---@param value any
---@return boolean
local function isLocaleTable(value)
  if type(value) ~= "table" or next(value) == nil then return false end
  for k in pairs(value) do
    if type(k) ~= "string" or not k:match("^[a-z][a-z]$") then return false end
  end
  return value[DEFAULT] ~= nil or value.ar ~= nil
end

--- Writes the language into a config table:
---   `Locale`   the key ('ar' | 'en' ...) -- a value other than 'auto' already there is kept,
---   `IsRTL`    the direction,
---   `Language` the key too, unless the config already set it to something.
---@param config table
---@return table (The same table)
function language.bind(config)
  if type(config) ~= "table" then return config end
  local forced = config.Locale
  if type(forced) ~= "string" or forced:lower() == "auto" then forced = nil end
  local key = forced and normalize(forced) or language.key()
  config.Locale = key
  config.IsRTL = language.isRTL(key)
  if config.Language == nil or config.Language == "auto" then config.Language = key end
  return config
end

--- bind() plus: every top-level `{ ar = ..., en = ... }` field of the config is replaced by
--- its entry for the current language, so the rest of the resource reads plain labels.
---@param config table
---@return table (The same table)
function language.bindLabels(config)
  if type(config) ~= "table" then return config end
  language.bind(config)
  local key = config.Locale
  for name, value in pairs(config) do
    if isLocaleTable(value) then
      config[name] = language.select(value, key)
    end
  end
  return config
end

return language
