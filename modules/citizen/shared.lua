-------------
-- citizen — the ONE id that names another player: the citizen id (players.citizenid).
--
-- Why this module exists: a server id changes on every connection and, since the citizen id
-- became plain digits (1, 2, 777), the two collide. A form that asked for "the player's id"
-- either answered "player not found" to a citizen id or hit whoever held that server id.
-- The owner's rule: every input that targets a player takes the citizen id. If he is in the
-- game his server id is found here, nobody has to look it up; if he is not, the feature takes
-- its offline path (or says clearly that he must be online).
--
--   '12', ' 12 ', 12, '١٢'   a citizen id (a Lua number given to resolve() is a citizen id too)
--   'omg95204'               the old random form (3 letters + 5 digits), until the migration ran
--   '#7'                     an explicit SERVER id: the character in play on server id 7
--   'me'                     the caller himself, only when resolve() is told who that is
--
-- This file is shared: parsing, labels and the locale strings work on both sides, so a client
-- dialog can refuse a malformed id before asking the server. Who the id IS (online or not) is
-- answered by server.lua.
-------------
local citizen = w.createModule("citizen")

-- Same rules as w_core's C.Normalize (server/citizen.lua): the id is a string of 1..9 digits
-- with no leading zero, or the old random form, upper-cased. Kept here rather than asked of
-- w_core so a client dialog can check what was typed, and so the library still works when
-- another core runs.
local OLD_FORMAT = "^%u%u%u%d%d%d%d%d$"
local MAX_DIGITS = 9
local MAX_SERVER_ID = 65535

-- An Arabic keyboard types Arabic-Indic digits, and a copy from chat or a web page carries
-- invisible bidi marks, zero-width characters or no-break spaces. The id "looks right" and
-- still failed, so they are folded to ASCII digits / removed before anything else.
local FOLD = {}
for i = 0, 9 do
  FOLD[utf8.char(0x0660 + i)] = tostring(i) -- ٠..٩
  FOLD[utf8.char(0x06F0 + i)] = tostring(i) -- ۰..۹ (Persian / Urdu keyboards)
end
for _, cp in ipairs({ 0x00A0, 0x061C, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C,
  0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069, 0xFEFF }) do
  FOLD[utf8.char(cp)] = ""
end
FOLD[utf8.char(0xFF03)] = "#" -- a full-width '#' from an IME still means "server id"

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clean(text)
  text = tostring(text):gsub("[\xC2-\xF4][\x80-\xBF]+", function(ch)
    return FOLD[ch] or ch
  end)
  return trim(text)
end

--- The canonical citizen id of what was typed or sent ('12', 'OMG95204'), or nil when it
--- cannot be one. Leading zeros are dropped ('007' -> '7': no citizen id starts with 0).
---@param value any
---@return string|nil
function citizen.normalize(value)
  if type(value) == "number" then
    if value ~= value or value < 1 or value >= 10 ^ MAX_DIGITS or value % 1 ~= 0 then return nil end
    return ("%d"):format(value)
  end
  if type(value) ~= "string" then return nil end
  value = clean(value)
  if value:match("^%d+$") then
    value = value:gsub("^0+", "")
    if value ~= "" and #value <= MAX_DIGITS then return value end
    return nil
  end
  local up = value:upper()
  if up:match(OLD_FORMAT) then return up end
  return nil
end

--- What kind of id was typed, without asking anyone who it is.
---   "citizen", "<citizenid>"  |  "server", <server id>  |  "self"  |  nil (not an id)
---@param input any
---@return string|nil kind
---@return string|integer|nil value
function citizen.parse(input)
  if type(input) == "number" then
    local id = citizen.normalize(input)
    if id then return "citizen", id end
    return nil
  end
  if type(input) ~= "string" then return nil end
  local text = clean(input)
  local server = text:match("^#%s*(%d+)$")
  if server then
    local n = tonumber(server)
    if n and n >= 1 and n <= MAX_SERVER_ID then return "server", math.tointeger(n) end
    return nil
  end
  if text:lower() == "me" then return "self" end
  local id = citizen.normalize(text)
  if id then return "citizen", id end
  return nil
end

--- "Name (citizenid)" for a notification or a log line; just the id when the character has no
--- name, "" when there is no target.
---@param target table|nil (a target from resolve / requireOnline / fromSource)
---@return string
function citizen.label(target)
  if type(target) ~= "table" or target.citizenid == nil then return "" end
  local id = tostring(target.citizenid)
  local name = type(target.name) == "string" and trim(target.name) or ""
  if name == "" then return id end
  return ("%s (%s)"):format(name, id)
end

-------------
-- Locale strings. They live in w_lib's own locales/<lang>.json under "citizen", so every
-- resource shows the same words for the same failure, in the player's language.
-------------
local REASONS = {
  invalid_id = "citizen.invalid_id",
  not_found = "citizen.not_found",
  offline = "citizen.offline",
}

--- The w_lib locale key of a failure reason ('invalid_id' | 'not_found' | 'offline').
--- An unknown reason reads as not found.
---@param reason string|nil
---@return string
function citizen.reasonKey(reason)
  return REASONS[reason] or REASONS.not_found
end

local strings = {} -- [lang] = the "citizen" table of locales/<lang>.json, false when it has none

local function stringsOf(lang)
  if strings[lang] == nil then
    local raw = LoadResourceFile("w_lib", ("locales/%s.json"):format(lang))
    local ok, data = pcall(json.decode, raw or "")
    strings[lang] = ok and type(data) == "table" and type(data.citizen) == "table" and data.citizen or false
  end
  return strings[lang] or nil
end

-- server + src: the language that player chose; otherwise the language of this side
local function languageOf(src)
  local ok, key
  if src and IsDuplicityVersion() then
    ok, key = pcall(function() return exports.w_lib:getPlayerLocaleKey(src) end)
  else
    ok, key = pcall(function() return exports.w_lib:getLocaleKey() end)
  end
  if ok and type(key) == "string" and key ~= "" then return key:lower() end
  return "en"
end

--- A w_lib citizen string: 'label', 'placeholder', 'help', 'invalid_id', 'not_found',
--- 'offline' (with or without the 'citizen.' prefix). On the server `src` picks that player's
--- language. Falls back to English, then to the name itself.
---@param name string
---@param src? integer
---@return string
function citizen.text(name, src)
  name = tostring(name or ""):gsub("^citizen%.", "")
  local lang = languageOf(src)
  for _, key in ipairs({ lang, lang:match("^(%a%a)"), "en" }) do
    local t = key and stringsOf(key)
    if t and type(t[name]) == "string" then return t[name] end
  end
  return name
end

--- The message for a failure reason, in `src`'s language (server) or this side's language.
---@param reason string|nil
---@param src? integer
---@return string
function citizen.reasonText(reason, src)
  return citizen.text(citizen.reasonKey(reason), src)
end

return citizen
