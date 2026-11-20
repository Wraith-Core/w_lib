"""Comprehensive lupa unit tests for w_lib M1c vorp_inventory.SetMetadata fix & Inv* extensions."""
from pathlib import Path
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]


def build_inv_runtime(active_inv="vorp_inventory", is_server=True):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.globals()._ACTIVE_INV = active_inv
    lua.globals()._IS_SERVER = is_server

    lua.execute(
        """
        function IsDuplicityVersion() return _IS_SERVER end

        STATES = {
            w_lib = 'started',
        }
        if _ACTIVE_INV and _ACTIVE_INV ~= '' then
            STATES[_ACTIVE_INV] = 'started'
        end
        function GetResourceState(name) return STATES[name] or 'missing' end

        CONVARS = {
            ['w_lib:inventory'] = 'auto',
            ['w_lib:activeInventory'] = '',
            ['w_lib:locale'] = 'ar',
        }
        function GetConvar(k, def) return CONVARS[k] ~= nil and CONVARS[k] or def end
        function SetConvarReplicated(k, v) CONVARS[k] = tostring(v or '') end

        INVOKER = 'w_farming'
        function GetInvokingResource() return INVOKER end
        function GetCurrentResourceName() return 'w_lib' end

        EVENTS = {}
        NET_EVENTS = {}
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
        function TriggerClientEvent() end

        function SetTimeout(ms, fn) end
        function CreateThread(fn)
            local co = coroutine.create(fn)
            coroutine.resume(co)
        end
        function Wait(ms) coroutine.yield(ms) end

        promise = {
            new = function()
                local obj = { val = nil }
                function obj:resolve(v) self.val = v end
                return obj
            end
        }
        Citizen = {
            Await = function(p) return p.val end
        }

        VORP_ITEMS = {
            [101] = { id = 101, name = 'farm_bucket', label = 'Bucket', count = 1, weight = 0.5, metadata = { water = 50, _vorp = 'internal' } },
            [102] = { id = 102, name = 'bread', label = 'Bread', count = 3, weight = 0.1, metadata = {} },
        }
        VORP_SET_META_CALLS = {}
        STASH_CALLS = {}

        SHARED_ITEMS = {
            bread = { name = 'bread', label = 'Bread', label_ar = 'خبز', image = 'bread.png' },
            farm_bucket = { name = 'farm_bucket', label = 'Bucket', label_ar = 'سطل', image = 'farm_bucket.png' },
        }
        SHARED_WEAPONS = {
            weapon_revolver_cattleman = { name = 'weapon_revolver_cattleman', label = 'Cattleman', label_ar = 'كاتلمان' }
        }

        EXPORTS = {
            CompatItems = function() return SHARED_ITEMS end,
            FwGetSharedItems = function() return SHARED_ITEMS end,
            FwGetSharedItem = function(n) return SHARED_ITEMS[n] end,
            FwGetSharedWeapons = function() return SHARED_WEAPONS end,
            FwGetSharedWeapon = function(n) return SHARED_WEAPONS[n] end,
            FwGetPlayerData = function()
                return {
                    items = {
                        [1] = { slot = 1, name = 'bread', amount = 4, info = {} },
                    }
                }
            end,
            w_inventory = {
                Items = function(name)
                    if name == nil then return SHARED_ITEMS end
                    return SHARED_ITEMS[name]
                end,
                Search = function(a, b, c, d)
                    if _IS_SERVER then
                        return b == 'count' and 5 or nil
                    else
                        return a == 'count' and 5 or nil
                    end
                end,
                GetItemCount = function(src, item, meta, strict) return 2 end,
                CanCarryItem = function() return true end,
                CanCarryItems = function(target, lines) return true end,
                AddItem = function(target, item, count, meta)
                    table.insert(STASH_CALLS, { op = 'AddItem', target = target, item = item, count = count })
                    return true
                end,
                AddItems = function(target, lines)
                    table.insert(STASH_CALLS, { op = 'AddItems', target = target, lines = lines })
                    return true
                end,
                RemoveItem = function() return true end,
                RegisterStash = function(id, label, slots, maxW, owner, groups, coords)
                    table.insert(STASH_CALLS, { id = id, owner = owner, groups = groups, coords = coords })
                    return true
                end,
                SetMetadata = function(src, slot, meta) return true end,
                GetSlotWithItem = function(src, item) return { slot = 3, name = item, count = 1, metadata = {} } end,
                GetSlotIdWithItem = function(src, item) return 3 end,
                GetSlotsWithItem = function(src, item) return { { slot = 3, name = item, count = 1, metadata = {} } } end,
                GetInventory = function(id) return { id = id, items = {} } end,
                GetInventoryItems = function(id) return { { slot = 1, name = 'bread', count = 2 } } end,
                RemoveInventory = function(id) return true end,
                SetMaxWeight = function(id, w) return w == 50000 end,
                RegisterShop = function(id, cfg) return true end,
                forceOpenInventory = function(src, t, d) return true end,
                openInventory = function(t, d) return true end,
                displayMetadata = function(k, l) return true end,
                registerHook = function(ev, fn, opts) return 99 end,
                removeHooks = function(id) REMOVED_HOOK = id end,
                getWeaponWheelState = function() return { active = true } end,
                selectWeaponSlot = function(s) return s == 2 end,
                BeginDebtAssetStorage = function() return true, 'tok1' end,
            },
            vorp_inventory = {
                getUserInventoryItems = function(src, cb)
                    local list = {}
                    for _, v in pairs(VORP_ITEMS) do list[#list + 1] = v end
                    if cb then cb(list) end
                    return list
                end,
                getUserInventoryWeapons = function(src, cb)
                    local w = { { id = 77, name = 'WEAPON_REVOLVER_CATTLEMAN', serial_number = 'S1', ammo = {}, components = {} } }
                    if cb then cb(w) end
                    return w
                end,
                getItemById = function(src, id, cb)
                    local row = VORP_ITEMS[tonumber(id)]
                    if cb then cb(row) end
                    return row
                end,
                setItemMetadata = function(src, id, meta, amount, cb)
                    local row = VORP_ITEMS[tonumber(id)]
                    if not row then
                        if cb then cb(false) end
                        return false
                    end
                    row.metadata = meta
                    table.insert(VORP_SET_META_CALLS, { src = src, id = id, meta = meta, amount = amount })
                    if cb then cb(true) end
                    return true
                end,
                getItemDB = function(name) return SHARED_ITEMS[name] end,
                getItemCount = function(a, b, c)
                    if not _IS_SERVER then return 3 end
                    if type(b) == 'function' then b(3) end
                    return 3
                end,
                canCarryItem = function(src, item, count, cb) if cb then cb(true) end; return true end,
                addItem = function(src, item, count, meta, cb) if cb then cb(true) end; return true end,
                subItem = function(src, item, count, meta, cb) if cb then cb(true) end; return true end,
                subItemById = function(src, id, cb) if cb then cb(true) end; return true end,
                registerInventory = function() end,
                addItemsToCustomInventory = function() end,
            },
            ['rsg-core'] = {
                GetCoreObject = function()
                    return {
                        Shared = { Items = SHARED_ITEMS },
                        Functions = {
                            GetPlayer = function(src)
                                return {
                                    PlayerData = {
                                        items = {
                                            [1] = { slot = 1, name = 'farm_bucket', amount = 1, info = { water = 50, _w_rsg = 1 } },
                                        }
                                    },
                                    Functions = { SetInventory = function() end },
                                }
                            end
                        }
                    }
                end
            },
            ['rsg-inventory'] = {},
        }

        exports = setmetatable({}, {
            __call = function(_, name, fn)
                EXPORTS[name] = fn
            end,
            __index = function(_, resName)
                if resName == 'w_lib' then
                    return setmetatable({}, {
                        __index = function(_, fnName)
                            return function(_, ...)
                                local fn = EXPORTS[fnName]
                                if not fn then error('missing w_lib export: ' .. tostring(fnName)) end
                                return fn(...)
                            end
                        end
                    })
                end
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

    if is_server:
        lua.execute((ROOT / "resource/invbridge/server.lua").read_text(encoding="utf-8"))
    else:
        lua.execute((ROOT / "resource/invbridge/client.lua").read_text(encoding="utf-8"))
    return lua


class TestInvBridgeExtensions(unittest.TestCase):
    def test_vorp_set_metadata_and_partial_meta_matching(self):
        lua = build_inv_runtime("vorp_inventory", is_server=True)
        self.assertEqual(lua.eval("EXPORTS['InvName']()"), "vorp_inventory")

        # Reject synthetic weapon slot 'w77'
        self.assertFalse(lua.eval("EXPORTS['InvSetMetadata'](1, 'w77', { custom = 1 })"))
        self.assertEqual(lua.eval("#VORP_SET_META_CALLS"), 0)

        # Numeric item slot delegates to getItemById + setItemMetadata with stack count
        self.assertTrue(lua.eval("EXPORTS['InvSetMetadata'](1, 102, { fresh = true })"))
        self.assertEqual(lua.eval("#VORP_SET_META_CALLS"), 1)
        self.assertEqual(lua.eval("VORP_SET_META_CALLS[1].id"), 102)
        self.assertEqual(lua.eval("VORP_SET_META_CALLS[1].amount"), 3)
        self.assertTrue(lua.eval("VORP_ITEMS[102].metadata.fresh"))

        # Partial metadata matching ignores _vorp internal key even in strict mode
        self.assertEqual(lua.eval("EXPORTS['InvGetItemCount'](1, 'farm_bucket', { water = 50 }, true)"), 1)
        self.assertEqual(lua.eval("EXPORTS['InvGetItemCount'](1, 'farm_bucket', { water = 99 }, true)"), 0)
        self.assertEqual(lua.eval("EXPORTS['InvGetSlotIdWithItem'](1, 'farm_bucket', { water = 50 })"), 101)

        # No-arg InvItems() returns full catalogue on vorp_inventory too
        self.assertEqual(lua.eval("EXPORTS['InvItems']().bread.label_ar"), "خبز")
        self.assertEqual(lua.eval("EXPORTS['InvImageBase']()"), "nui://vorp_inventory/html/img/items/")
        self.assertEqual(lua.eval("EXPORTS['InvItemImage']('bread')"), "nui://vorp_inventory/html/img/items/bread.png")

    def test_w_inventory_stash_positional_coords_hooks_and_passthroughs(self):
        lua = build_inv_runtime("w_inventory", is_server=True)
        # 7-arg positional InvRegisterStash(id, label, slots, maxWeight, owner, groups, coords)
        self.assertTrue(lua.eval("EXPORTS['InvRegisterStash']('house_1', 'House', 50, 100000, 'CID1', { police = 0 }, { x = 1, y = 2, z = 3 })"))
        self.assertEqual(lua.eval("STASH_CALLS[1].owner"), "CID1")
        self.assertEqual(lua.eval("STASH_CALLS[1].coords.x"), 1)

        # Stash target in InvCanCarryItems / InvAddItems
        self.assertTrue(lua.eval("EXPORTS['InvCanCarryItems']('tribe_stash_1', { { item = 'bread', count = 2 } })"))
        self.assertTrue(lua.eval("EXPORTS['InvAddItems']('tribe_stash_1', { { item = 'bread', count = 2 } })"))

        # Hooks & ItemAdded listener cleanup
        lua.execute(
            """
            ADDED_ITEMS = {}
            INVOKER = 'w_level'
            EXPORTS['InvOnItemAdded'](function(src, item, count)
                table.insert(ADDED_ITEMS, { src, item, count })
            end)
            HOOK_ID = EXPORTS['InvRegisterHook']('swapItems', function() return true end, {})
            TriggerEvent('w_inventory:server:itemAdded', 1, 'bread', 3, {})
            """
        )
        self.assertEqual(lua.eval("HOOK_ID"), 99)
        self.assertEqual(lua.eval("#ADDED_ITEMS"), 1)
        self.assertEqual(lua.eval("ADDED_ITEMS[1][2]"), "bread")

        lua.execute("TriggerEvent('onResourceStop', 'w_level'); TriggerEvent('w_inventory:server:itemAdded', 1, 'bread', 3, {})")
        self.assertEqual(lua.eval("REMOVED_HOOK"), 99)
        self.assertEqual(lua.eval("#ADDED_ITEMS"), 1)

        # Specialized passthrough returns multiple values
        ok_debt, tok = lua.eval("EXPORTS['InvBeginDebtAssetStorage']('CID1')")
        self.assertTrue(ok_debt)
        self.assertEqual(tok, "tok1")

    def test_client_inv_extensions_and_weapon_wheel(self):
        lua_cli = build_inv_runtime("w_inventory", is_server=False)
        self.assertTrue(lua_cli.eval("EXPORTS['InvReady']()"))
        self.assertEqual(lua_cli.eval("EXPORTS['InvItems']('bread').label_ar"), "خبز")
        self.assertEqual(lua_cli.eval("EXPORTS['InvWeapons']('weapon_revolver_cattleman').label_ar"), "كاتلمان")
        self.assertEqual(lua_cli.eval("EXPORTS['InvGetItemCount']('bread')"), 5)
        self.assertTrue(lua_cli.eval("EXPORTS['InvHasItem']('bread', 3)"))
        self.assertTrue(lua_cli.eval("EXPORTS['InvDisplayMetadata']('stars', 'Stars')"))
        self.assertTrue(lua_cli.eval("EXPORTS['InvGetWeaponWheelState']().active"))
        self.assertTrue(lua_cli.eval("EXPORTS['InvSelectWeaponSlot'](2)"))

        lua_rsg_cli = build_inv_runtime("rsg-inventory", is_server=False)
        self.assertEqual(lua_rsg_cli.eval("EXPORTS['InvGetItemCount']('bread')"), 4)
        self.assertEqual(lua_rsg_cli.eval("EXPORTS['InvImageBase']()"), "nui://rsg-inventory/html/images/")


if __name__ == "__main__":
    unittest.main()
