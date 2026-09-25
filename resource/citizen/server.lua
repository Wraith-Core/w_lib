-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · the citizen id resolver as exports
--
-- w.citizen (modules/citizen) runs inside the resource that uses it. A resource that does not
-- load '@w_lib/init.lua' (bp_mdt keeps its own bridge) still has to take the citizen id like
-- every other script, so the same functions answer here, in w_lib's VM:
--   exports.w_lib:CitizenResolve('12')         -> target | nil, 'invalid_id' | 'not_found'
--   exports.w_lib:CitizenRequireOnline('#7')   -> target | nil, reason [, offlineTarget]
--   exports.w_lib:CitizenFromSource(7)         -> target | nil, reason
--   exports.w_lib:CitizenIdOf(7)               -> '12' | nil
--   exports.w_lib:CitizenNormalize(' 12 ')     -> '12' | nil
--   exports.w_lib:CitizenLabel(target)         -> 'John Doe (12)'
--   exports.w_lib:CitizenReasonKey(reason)     -> 'citizen.not_found'
--   exports.w_lib:CitizenReasonText(reason, src) / CitizenText(name, src) -> the locale string
-- The module is loaded on first use, like any w.* module.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

local function module() return w.citizen end

exports('CitizenResolve', function(input, opts) return module().resolve(input, opts) end)
exports('CitizenRequireOnline', function(input, opts) return module().requireOnline(input, opts) end)
exports('CitizenFromSource', function(serverId) return module().fromSource(serverId) end)
exports('CitizenIdOf', function(serverId) return module().idOf(serverId) end)
exports('CitizenNormalize', function(value) return module().normalize(value) end)
exports('CitizenLabel', function(target) return module().label(target) end)
exports('CitizenReasonKey', function(reason) return module().reasonKey(reason) end)
exports('CitizenReasonText', function(reason, src) return module().reasonText(reason, src) end)
exports('CitizenText', function(name, src) return module().text(name, src) end)
