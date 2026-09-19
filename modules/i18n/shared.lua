w.require("hook")

local dict = {}
local initialized = false
local currentLocale = GetConvar("w_lib:i18n:locale", "en")
local useGlobalLocales = false
local metaKey = "w_lib_extra"
for i = 0, GetNumResourceMetadata(GetCurrentResourceName(), metaKey) - 1 do
  local key = GetResourceMetadata(GetCurrentResourceName(), metaKey, i)
  if key == '["i18n:i18n:useGlobalLocales:true"]' or key == '["i18n:i18n:useGlobalLocales"]' or key == "i18n:i18n:useGlobalLocales" then
    useGlobalLocales = true
  end
end

w.createModule("i18n")

if w.isClientSide() then
  local playerLocale = GetExternalKvpString("w_lib", "locale")
  if playerLocale and playerLocale ~= "" then
    currentLocale = playerLocale
  end
end

local function formatKeys(source, target, prefix)
  for key, value in pairs(source) do
    local fullKey = prefix and (prefix .. "." .. key) or key

    if type(value) == "table" then
      formatKeys(value, target, fullKey)
    else
      target[fullKey] = GetConvar("w_lib:i18n:translations:" .. fullKey, value)
    end
  end

  return target
end

local function loadLocale(locale)
  local path = ("@%s.locales_modules.%s"):format(w.resourceName, locale)

  -- ⚠️ Asked for quietly first, then loaded.
  --
  --    w.resourceName is the **consuming** resource, not w_lib -- the module is load()ed into
  --    whoever requires it. Almost no resource ships a locales_modules folder, so loadJson
  --    printed
  --        Impossible to load. File doesn't exist: @<resource>.locales_modules.<locale>.json
  --    on every boot, twice over for each of them: once for English, once for the player's
  --    own locale. It reads as a broken install and it is not one.
  --
  --    And it fires for w_lib itself on any locale outside the five translated in
  --    locales_modules (de/en/es/fr/it), while locales/ carries thirty-three -- Arabic among
  --    them. A language with no module strings is the ordinary case.
  --
  --    Nothing is lost by staying quiet: the caller merges English underneath every locale,
  --    so an absent file leaves the English string in place, which is the documented fallback.
  if not w.file.readJson(path) then return {} end

  local strings = w.file.loadJson(path)
  if not strings then return {} end

  return formatKeys(strings, {})
end

--- Returns the current locale
---@return string (The current locale)
function w.i18n.getLocale()
  return currentLocale
end

--- Load a locale
---@param locale string (The locale to load)
function w.i18n.loadLocale(locale)
  table.wipe(dict)
  if w.resourceName ~= "w_lib" and useGlobalLocales then
    dict = exports.w_lib:w_i18n_getEntries()
  end
  local strings = table.merge(dict, loadLocale("en"))
  if locale ~= "en" then
    table.merge(strings, loadLocale(locale))
  end
  dict = strings
end

--- Initialize the i18n module
function w.i18n.init()
  w.i18n.loadLocale(currentLocale)
  initialized = true
end

--- Set the current locale
---@param locale string (The locale to set)
function w.i18n.setLocale(locale)
  currentLocale = locale
  w.i18n.loadLocale(currentLocale)

  -- ⚠️ "w_i18n_locale_change", not "..._changed". onLocaleChange below registers on the first
  --    spelling and this fired the second, so no callback ever ran -- a one-letter typo that
  --    made the whole hook look like a feature nobody used.
  w.hook.doActions("w_i18n_locale_change", locale)

  --[[
      ★ AND THE OTHER HALF OF THE LIBRARY IS TOLD TOO.

        w_lib carries two locale systems: this one, and imports/locale, which every resource
        using lib.locale() depends on. Only the second listens for 'w_lib:setLocale'. Without
        this line, switching language here reloaded the menus and left every consumer's
        dictionary on the old language until the resource restarted.
  ]]
  TriggerEvent('w_lib:setLocale', locale)
end

--- Register a callback to be called when the locale changes
---@param callback function (The callback to register)
---@param priority number (The priority of the callback)
function w.i18n.onLocaleChange(callback, priority)
  w.hook.registerAction("w_i18n_locale_change", callback, priority)
end
exports("onLocaleChange", w.i18n.onLocaleChange)

--- Find missing keys in a locale
---@param locale string (The locale to check)
function w.i18n.findMissingKeys(locale)
  local refStrings = loadLocale("en")
  if locale == "en" then return print("Cannot compare 'en' with 'en'") end
  local strings = loadLocale(locale)

  for key, _ in pairs(refStrings) do
    if not strings[key] then
      print(("Missing key '%s' in '%s'"):format(key, locale))
    end
  end
end

--- Add a single entry to the i18n dictionary
---@param key string (The key to add)
---@param value string (The value to add)
function w.i18n.addEntry(key, value)
  dict[key] = value
end
exports("w_i18n_addEntry", w.i18n.addEntry)

--- Add multiple entries to the i18n dictionary
---@param entries table (The entries to add)
function w.i18n.addEntries(entries)
  local strings = formatKeys(entries, {})
  table.merge(dict, strings)
end
exports("w_i18n_addEntries", w.i18n.addEntries)

--- Get all entries
---@return table (The entries)
function w.i18n.getEntries()
  if not initialized then
    w.i18n.init()
  end
  return dict
end
exports("w_i18n_getEntries", w.i18n.getEntries)

--- Translate a key
---@param key string (The key to translate)
---@return string (The translated key)
function w.i18n.__(key)
  if not initialized then
    w.i18n.init()
  end
  return dict[key] or ("#%s"):format(key)
end
exports("w_i18n___", w.i18n.__)

--- Export the i18n module
_G.__ = w.i18n.__

w.ready(w.i18n.init)
