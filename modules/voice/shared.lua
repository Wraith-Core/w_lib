-- ════════════════════════════════════════════════════════════════════════════
-- w.voice — talking characters (w_voiceintract) through the library. The exports are
-- called from the consumer's own VM so w_voiceintract sees the consumer as the owner
-- (registrations die with the owning resource; handlers never leave the server).
--
--   shared: w.voice.register(id, profile, handlers) -> owned id | nil, reason
--           w.voice.unregister(id)                   -> boolean
--           w.voice.isAvailable()                    -> w_voiceintract started?
--   client: w.voice.bind(ped, id) / unbind(ped) / character(ped) / target()
--           w.voice.speak(ped, text, opts) / silence(id)
--           w.voice.registerAction(def) / unregisterAction(name) / setActionEnabled(target, on)
--           w.voice.registerLayer(def) / enterLayer(name) / exitLayer(name)
--   server: w.voice.chat(messages, schema) -> the dialogue model's answer | nil
-- ════════════════════════════════════════════════════════════════════════════
w.createModule("voice")

local RESOURCE = "w_voiceintract"

local function available()
  return GetResourceState(RESOURCE) == "started"
end

--- Call an export of w_voiceintract; `fallback` when the resource is down or the call fails.
local function call(name, fallback, ...)
  if not available() then return fallback end
  local packed = table.pack(pcall(function(...) return exports[RESOURCE][name](nil, ...) end, ...))
  if not packed[1] then
    eprint(("w.voice.%s failed: %s"):format(name, tostring(packed[2])))
    return fallback
  end
  return table.unpack(packed, 2, packed.n)
end

w.voice._call = call

function w.voice.isAvailable()
  return available()
end

--- Register a talking character. `profile` = { name = { ar, en }, age, opened, background,
--- manner, occupation, scope, model, coords | networkId, radius, kind, voice, products }.
--- `handlers` (server only) = { getProducts, onOrder, onCart, onTalk }.
function w.voice.register(id, profile, handlers)
  return call("registerCharacter", nil, id, profile, handlers)
end

function w.voice.unregister(id)
  return call("unregisterCharacter", false, id) == true
end
