"""Comprehensive lupa unit tests for w_lib M1a Door* unified doorlock bridge."""
from pathlib import Path
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]


def build_door_runtime(started_provider="w_doorlock", is_server=True):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.globals()._STARTED_PROVIDER = started_provider
    lua.globals()._IS_SERVER = is_server

    lua.execute(
        """
        function IsDuplicityVersion() return _IS_SERVER end

        STATES = {
            w_lib = 'started',
        }
        if _STARTED_PROVIDER and _STARTED_PROVIDER ~= '' then
            STATES[_STARTED_PROVIDER] = 'started'
        end
        function GetResourceState(name) return STATES[name] or 'missing' end

        CONVARS = {
            ['w_lib:doorlock'] = 'auto',
            ['w_lib:activeDoorlock'] = '',
        }
        function GetConvar(k, def) return CONVARS[k] ~= nil and CONVARS[k] or def end
        function SetConvarReplicated(k, v) CONVARS[k] = tostring(v or '') end

        INVOKER = 'w_heists'
        function GetInvokingResource() return INVOKER end
        function GetCurrentResourceName() return 'w_lib' end

        EVENTS = {}
        NET_EVENTS = {}
        CLIENT_EVENTS = {}
        function AddEventHandler(name, fn)
            EVENTS[name] = EVENTS[name] or {}
            table.insert(EVENTS[name], fn)
        end
        function RegisterNetEvent(name, fn)
            if fn then
                NET_EVENTS[name] = NET_EVENTS[name] or {}
                table.insert(NET_EVENTS[name], fn)
            end
        end
        function TriggerEvent(name, ...)
            for _, fn in ipairs(EVENTS[name] or {}) do fn(...) end
            for _, fn in ipairs(NET_EVENTS[name] or {}) do fn(...) end
        end
        function TriggerClientEvent(name, target, ...)
            table.insert(CLIENT_EVENTS, { name = name, target = target, args = table.pack(...) })
        end

        THREADS = {}
        function CreateThread(fn)
            local co = coroutine.create(fn)
            coroutine.resume(co)
            table.insert(THREADS, co)
        end
        function Wait(ms)
            coroutine.yield(ms)
        end

        function vector3(x, y, z)
            return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
        end

        DOORS_DB = {
            [7] = { id = 7, name = 'valentine_vault', state = 1, coords = { x = -307.5, y = 776.2, z = 118.7 }, maxDistance = 2.0 },
            [8] = { id = 8, name = 'rhodes_vault', state = 0, coords = { x = 1292.1, y = -1303.4, z = 77.0 }, maxDistance = 2.5 },
        }

        CLOSEST_DOOR = { id = 7, name = 'valentine_vault', state = 1, coords = { x = -307.5, y = 776.2, z = 118.7 }, distance = 1.1 }

        local function makeOxProvider(isStrictOx)
            return {
                getDoor = function(id)
                    local k = isStrictOx and id or (tonumber(id) or id)
                    return DOORS_DB[k] or false
                end,
                getAllDoors = function()
                    local out = {}
                    for _, d in pairs(DOORS_DB) do out[#out + 1] = d end
                    return out
                end,
                getDoorFromName = function(name)
                    for _, d in pairs(DOORS_DB) do
                        if d.name == name then return d end
                    end
                    return nil
                end,
                setDoorState = function(id, state)
                    local k = isStrictOx and id or (tonumber(id) or id)
                    local d = DOORS_DB[k]
                    if not d then return false end
                    d.state = state
                    return true
                end,
                editDoor = function(id, data)
                    local k = isStrictOx and id or (tonumber(id) or id)
                    local d = DOORS_DB[k]
                    if not d then return isStrictOx and nil or false end
                    if data.throwError then error('type mismatch') end
                    for field, val in pairs(data) do d[field] = val end
                    if isStrictOx then return nil end
                    return true
                end,
                useClosestDoor = function()
                    if not CLOSEST_DOOR then return false end
                    return isStrictOx and nil or true
                end,
                pickClosestDoor = function()
                    if not CLOSEST_DOOR then return isStrictOx and nil or false end
                    return isStrictOx and nil or true
                end,
                getClosestDoor = function() return CLOSEST_DOOR end,
                getClosestDoorId = function() return CLOSEST_DOOR and CLOSEST_DOOR.id or nil end,
                getDoorIdFromEntity = function(ent) return ent == 555 and 7 or nil end,
            }
        end

        EXPORTS = {
            w_doorlock = makeOxProvider(false),
            ox_doorlock = makeOxProvider(true),
            ['rsg-doorlock'] = {},
            vorp_doorlocks = not _IS_SERVER and {
                getDoorIdByDistance = function() return CLOSEST_DOOR and CLOSEST_DOOR.id or nil end,
                getDoorState = function(id) return DOORS_DB[id] and DOORS_DB[id].state or 1 end,
                setDoorState = function(id, st)
                    if DOORS_DB[id] then DOORS_DB[id].state = st; return true end
                    return false
                end,
            } or {},
        }

        RESOURCE_FILES = {
            ['vorp_doorlocks:config.lua'] = [[
                Config = {}
                Config.Doors = {
                    [2642457609] = {
                        Name = 'Front Door 1 (Left)',
                        Pos = vector3(-300.0, 800.0, 118.0),
                        DoorState = 1,
                        DoubleDoor = 2642457610,
                    },
                    [2642457610] = {
                        Name = 'Front Door 1 (Right)',
                        Pos = vector3(-301.0, 800.0, 118.0),
                        DoorState = 1,
                        DoubleDoor = 2642457609,
                    },
                }
                return { CONFIG = Config }
            ]]
        }
        function LoadResourceFile(res, file)
            return RESOURCE_FILES[ tostring(res) .. ':' .. tostring(file) ]
        end

        MySQL = {
            query = {
                await = function(q, params)
                    if q:find('FROM rsg_doorlocks') then
                        return {
                            { id = 10, name = 'rsg_bank', locked = 1, text_coords = '{"x":1,"y":2,"z":3}', distance = 2.0 }
                        }
                    end
                    return {}
                end
            },
            update = {
                await = function() return 1 end
            }
        }

        json = {
            decode = function(s)
                if s == '{"x":1,"y":2,"z":3}' then return { x = 1, y = 2, z = 3 } end
                return nil
            end
        }

        exports = setmetatable({}, {
            __call = function(_, name, fn)
                EXPORTS[name] = fn
            end,
            __index = function(_, resName)
                local tbl = EXPORTS[resName]
                return setmetatable({}, {
                    __index = function(_, fnName)
                        return function(_, ...)
                            local fn = tbl and tbl[fnName]
                            if not fn then error('missing export ' .. tostring(resName) .. ':' .. tostring(fnName)) end
                            return fn(...)
                        end
                    end
                })
            end
        })
        """
    )

    lua.execute((ROOT / "resource/doorbridge/shared.lua").read_text(encoding="utf-8"))
    if is_server:
        lua.execute((ROOT / "resource/doorbridge/server.lua").read_text(encoding="utf-8"))
    else:
        lua.execute((ROOT / "resource/doorbridge/client.lua").read_text(encoding="utf-8"))
    return lua


class TestDoorBridge(unittest.TestCase):
    def test_w_doorlock_and_ox_doorlock_server_parity(self):
        for provider in ("w_doorlock", "ox_doorlock"):
            lua = build_door_runtime(started_provider=provider, is_server=True)
            self.assertEqual(lua.eval("EXPORTS['DoorName']()"), provider)
            self.assertTrue(lua.eval("EXPORTS['DoorReady']()"))

            # String ID coerced to numeric so ox_doorlock works
            d7 = lua.eval("EXPORTS['DoorGet']('7')")
            self.assertEqual(d7.id, 7)
            self.assertEqual(d7.name, "valentine_vault")
            self.assertEqual(d7.state, 1)
            self.assertTrue(d7.locked)
            self.assertEqual(d7.coords.x, -307.5)

            # Missing door returns nil (not false)
            self.assertIsNone(lua.eval("EXPORTS['DoorGet'](999)"))
            self.assertIsNone(lua.eval("EXPORTS['DoorGetFromName']('missing')"))
            self.assertEqual(lua.eval("EXPORTS['DoorGetFromName']('rhodes_vault').id"), 8)
            self.assertEqual(lua.eval("#EXPORTS['DoorGetAll']()"), 2)

            # Strict state normalization
            self.assertFalse(lua.eval("EXPORTS['DoorSetState'](7, 'invalid_state')"))
            self.assertEqual(lua.eval("EXPORTS['DoorGetState'](7)"), 1)
            self.assertTrue(lua.eval("EXPORTS['DoorSetState']('7', false)"))
            self.assertEqual(lua.eval("EXPORTS['DoorGetState'](7)"), 0)
            self.assertTrue(lua.eval("EXPORTS['DoorSetState'](7, 'locked')"))
            self.assertEqual(lua.eval("EXPORTS['DoorGetState'](7)"), 1)

            # Edit normalizes ox_doorlock nil return and catches errors
            self.assertTrue(lua.eval("EXPORTS['DoorEdit']('7', { name = 'new_vault' })"))
            self.assertEqual(lua.eval("EXPORTS['DoorGet'](7).name"), "new_vault")
            self.assertFalse(lua.eval("EXPORTS['DoorEdit'](7, { throwError = true })"))
            self.assertFalse(lua.eval("EXPORTS['DoorEdit'](999, { name = 'ghost' })"))

    def test_rsg_and_vorp_fallbacks_and_events(self):
        # RSG DB fallback
        lua_rsg = build_door_runtime(started_provider="rsg-doorlock", is_server=True)
        self.assertEqual(lua_rsg.eval("EXPORTS['DoorName']()"), "rsg-doorlock")
        all_rsg = lua_rsg.eval("EXPORTS['DoorGetAll']()")
        self.assertEqual(all_rsg[1].id, 10)
        self.assertEqual(all_rsg[1].state, 1)
        self.assertTrue(lua_rsg.eval("EXPORTS['DoorSetState'](10, 0)"))
        self.assertEqual(lua_rsg.eval("EXPORTS['DoorGetState'](10)"), 0)

        # VORP config.lua fallback + exact name match (with parentheses!) + DoubleDoor state sync
        lua_vorp = build_door_runtime(started_provider="vorp_doorlocks", is_server=True)
        self.assertEqual(lua_vorp.eval("EXPORTS['DoorName']()"), "vorp_doorlocks")
        d_left = lua_vorp.eval("EXPORTS['DoorGetFromName']('Front Door 1 (Left)')")
        self.assertEqual(d_left.id, 2642457609)
        self.assertTrue(lua_vorp.eval("EXPORTS['DoorSetState'](2642457609, 0)"))
        self.assertEqual(lua_vorp.eval("EXPORTS['DoorGetState'](2642457609)"), 0)
        self.assertEqual(lua_vorp.eval("EXPORTS['DoorGetState'](2642457610)"), 0)

        # DoorOnStateChanged funcref + cleanup
        lua_ev = build_door_runtime(started_provider="w_doorlock", is_server=True)
        lua_ev.execute(
            """
            GOT_STATE = {}
            local fref = setmetatable({}, {
                __call = function(_, src, id, locked, item)
                    table.insert(GOT_STATE, { src = src, id = id, locked = locked, item = item })
                end
            })
            INVOKER = 'w_heists'
            EXPORTS['DoorOnStateChanged'](fref)
            TriggerEvent('w_doorlock:stateChanged', 1, 7, false, 'lockpick')
            TriggerEvent('ox_doorlock:stateChanged', 1, 7, true, false) -- ignored because w_doorlock is active
            """
        )
        self.assertEqual(lua_ev.eval("#GOT_STATE"), 1)
        self.assertEqual(lua_ev.eval("GOT_STATE[1].id"), 7)
        self.assertFalse(lua_ev.eval("GOT_STATE[1].locked"))
        self.assertEqual(lua_ev.eval("GOT_STATE[1].item"), "lockpick")

        lua_ev.execute("TriggerEvent('onResourceStop', 'w_heists'); TriggerEvent('w_doorlock:stateChanged', 1, 7, true, false)")
        self.assertEqual(lua_ev.eval("#GOT_STATE"), 1)

    def test_client_exports_across_providers(self):
        for provider in ("w_doorlock", "ox_doorlock", "vorp_doorlocks"):
            lua_cli = build_door_runtime(started_provider=provider, is_server=False)
            self.assertEqual(lua_cli.eval("EXPORTS['DoorName']()"), provider)
            self.assertEqual(lua_cli.eval("EXPORTS['DoorGetClosestId']()"), 7)
            self.assertTrue(lua_cli.eval("EXPORTS['DoorUseClosest']()"))
            if provider in ("w_doorlock", "ox_doorlock"):
                self.assertTrue(lua_cli.eval("EXPORTS['DoorPickClosest']()"))
                self.assertEqual(lua_cli.eval("EXPORTS['DoorGetIdFromEntity'](555)"), 7)
                self.assertIsNone(lua_cli.eval("EXPORTS['DoorGetIdFromEntity'](0)"))


if __name__ == "__main__":
    unittest.main()
