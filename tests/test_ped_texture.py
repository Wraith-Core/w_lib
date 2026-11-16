"""A streamed ped can disappear or be replaced while a head texture is loading."""
from pathlib import Path
import unittest

from lupa import lua54

MODULES = Path(__file__).resolve().parents[1] / 'modules'

HARNESS = '''
local function noop() end
w = {require = noop, createModule = function(name) w[name] = {} end}
Citizen = {ResultAsInteger = noop, PointerValueInt = noop}
json = {encode = function() return '{}' end}
exports, dprint, eprint = noop, noop, noop
function table.copy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end
function table.type(t) return type(t) == 'table' and #t > 0 and 'array' or type(t) end
function IsDuplicityVersion() return false end
function IsScreenFadedOut() return false end
function IsLoadingScreenVisible() return false end
function IsPedMale() return true end
function GetHashFromString(value) return value end
function GetNumberOfMicrosecondsSinceLastCall() return 0 end

ped, netId, ready, networked = 42, 101, true, true
allocated, released, rendered, saved = 0, 0, {}, {}
function DoesEntityExist(handle) return handle == ped and netId ~= nil end
function NetworkGetEntityIsNetworked(handle) return DoesEntityExist(handle) and networked end
function NetworkGetNetworkIdFromEntity() return netId end
function IsPedReadyToRender(handle)
    assert(DoesEntityExist(handle), 'polled a removed ped')
    return ready
end
function Entity(handle)
    assert(NetworkGetEntityIsNetworked(handle), 'state bag of a removed or unnetworked ped')
    return {state = {set = function(_, key)
        assert(key == 'w_pedTexture')
        table.insert(saved, netId)
    end}}
end

-- refreshNow forces the real timeout immediately. Each test can change the
-- streamed entity at the next frame boundary inside that callback.
local now = 0
function SetTimeout() end
function CreateThreadNow(fn) fn() end
function CreateThread(fn) fn() end
function GetGameTimer() return now end
function Wait(ms)
    now = now + math.max(ms, 16)
    if nextFrame then
        local change = nextFrame
        nextFrame = nil
        change()
    end
end

local handles = {}
function InvokeNative(hash, arg)
    if hash == 0x90403E8107B60E81 then return 1 end                 -- component count
    if hash == 0x9B90842304C938A7 then return 'heads' end            -- component category
    if hash == 0xA9C28516A6DC9D56 then return 1, 2, 3, 4 end         -- base texture assets
    if hash == 0xC5E7204F322E49EB then                              -- request texture
        allocated = allocated + 1
        handles[allocated] = true
        return allocated
    end
    if hash == 0x31DC8D3F216D8509 then return handles[arg] end      -- texture valid
    if hash == 0x86BB5FF45F193A02 then return 0 end                 -- layer index
    if hash == 0x6BEFAA907B076859 then                              -- release texture
        assert(handles[arg], 'released an unknown or already released texture')
        handles[arg] = nil
        released = released + 1
    elseif hash == 0x0B46E25761519058 then                          -- apply texture
        assert(DoesEntityExist(arg), 'applied to a removed ped')
        table.insert(rendered, netId)
    elseif hash == 0xCC8CA3E88256E58F and afterVariation then       -- update ped variation
        afterVariation()
    end
end
function draw()
    w.pedTexture.overwriteBodyPart(ped, 'heads', {freckles = {id = 0}}, true)
    w.pedTexture.refreshNow(ped)
end
'''


class PedTexture(unittest.TestCase):
    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        for module in ('timeout/shared.lua', 'waiter/shared.lua', 'ped-texture/g_client.lua'):
            source = (MODULES / module).read_text(encoding='utf-8')
            # The stock Lua runtime does not support the Cfx compound assignment.
            source = source.replace('currentUpdate += 1', 'currentUpdate = currentUpdate + 1')
            self.lua.execute(source, name='@' + module)
        self.world = self.lua.globals()

    def assert_draws(self, expected_ids):
        self.assertEqual(list(self.world.rendered.values()), expected_ids)
        self.assertEqual(list(self.world.saved.values()), expected_ids)
        self.assertEqual(self.world.released, self.world.allocated)

    def test_live_ped_draws_and_releases(self):
        self.world.draw()
        self.assert_draws([101])
        self.assertEqual(self.world.allocated, 1)

    def test_despawn_while_waiting_for_ped_skips_texture_request(self):
        self.lua.execute('ready = false; nextFrame = function() netId = nil end')
        self.world.draw()
        self.assert_draws([])
        self.assertEqual(self.world.allocated, 0)

    def test_despawn_after_layer_creation_releases_texture(self):
        self.lua.execute('nextFrame = function() netId = nil end')
        self.world.draw()
        self.assert_draws([])
        self.assertEqual(self.world.allocated, 1)

    def test_recycled_ped_handle_only_receives_its_own_update(self):
        self.lua.execute('nextFrame = function() netId = 102 end')
        self.world.draw()
        self.assert_draws([])
        self.world.draw()
        self.assert_draws([102])
        self.assertEqual(self.world.allocated, 2)

    def test_network_loss_before_state_write_still_releases_texture(self):
        self.lua.execute('afterVariation = function() networked = false end')
        self.world.draw()
        self.assertEqual(list(self.world.rendered.values()), [101])
        self.assertEqual(list(self.world.saved.values()), [])
        self.assertEqual(self.world.released, 1)


if __name__ == '__main__':
    unittest.main()
