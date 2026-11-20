"""Comprehensive lupa unit tests for w_lib M1a Econ* unified economy/banking bridge."""
from pathlib import Path
import json
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]


def build_econ_runtime(central_started=True, fw_backend="vorp", is_server=True):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.globals()._CENTRAL_STARTED = central_started
    lua.globals()._FW_BACKEND = fw_backend
    lua.globals()._IS_SERVER = is_server

    def _dec(s):
        val = json.loads(s)
        if isinstance(val, (dict, list)):
            return lua.table_from(val, recursive=True)
        return val

    lua.globals()._JSON_DECODE = _dec

    lua.execute(
        """
        function IsDuplicityVersion() return _IS_SERVER end

        json = {
            decode = function(s)
                local ok, r = pcall(_JSON_DECODE, s)
                return ok and r or nil
            end
        }

        STATES = {
            w_lib = 'started',
            w_centralbank = _CENTRAL_STARTED and 'started' or 'missing',
            w_core = (_FW_BACKEND == 'wcore') and 'started' or 'missing',
        }
        function GetResourceState(name) return STATES[name] or 'missing' end

        INVOKER = 'consumer_res'
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

        EXPORTS = {}
        CENTRAL_CALLS = {}
        FW_CALLS = {}

        CENTRAL_READY = true
        CENTRAL_ACCOUNTS = {
            ['player:CID1:cash'] = 100.50,
            ['player:CID1:bank'] = 500.00,
            ['player:CID1:gold'] = 10.00,
            ['society:police'] = 2500.00,
        }

        FW_READY = true
        FW_PLAYERS = {
            CID1 = {
                src = 1,
                cash = 120.00,
                gold = 5.00,
                bank = (_FW_BACKEND == 'rsg' or _FW_BACKEND == 'qbr') and 300.00 or nil,
            },
            CID2 = {
                src = 2,
                cash = 50.00,
                gold = 2.00,
                bank = (_FW_BACKEND == 'rsg' or _FW_BACKEND == 'qbr') and 80.00 or nil,
            },
        }

        EXPORTS['w_centralbank'] = {
            IsReady = function()
                table.insert(CENTRAL_CALLS, 'IsReady')
                return CENTRAL_READY
            end,
            EnsureAccount = function(id, owner, kind)
                table.insert(CENTRAL_CALLS, 'EnsureAccount')
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                CENTRAL_ACCOUNTS[id] = CENTRAL_ACCOUNTS[id] or 0
                return true
            end,
            SetAccountOwner = function(id, owner)
                table.insert(CENTRAL_CALLS, 'SetAccountOwner')
                return CENTRAL_READY and type(owner) == 'string'
            end,
            GetBalance = function(id)
                table.insert(CENTRAL_CALLS, 'GetBalance')
                if not CENTRAL_READY then return nil end
                return CENTRAL_ACCOUNTS[id]
            end,
            HydratePlayer = function(cid, isNew)
                table.insert(CENTRAL_CALLS, 'HydratePlayer')
                if not CENTRAL_READY then return nil end
                return { cash = 100.5, bank = 500.0, gold = 10.0, bloodmoney = 10.0 }
            end,
            AdjustPlayer = function(cid, kind, delta, reason, key)
                table.insert(CENTRAL_CALLS, 'AdjustPlayer')
                if CENTRAL_THROW then error('db_timeout') end
                if CENTRAL_UNKNOWN then return nil, 'commit_unknown' end
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                local k = 'player:' .. tostring(cid) .. ':' .. (kind == 'bloodmoney' and 'gold' or kind)
                local cur = CENTRAL_ACCOUNTS[k] or 0
                if cur + delta < 0 then return false, 'insufficient_funds' end
                CENTRAL_ACCOUNTS[k] = cur + delta
                return true
            end,
            AdjustAccount = function(id, delta, reason, key)
                table.insert(CENTRAL_CALLS, 'AdjustAccount')
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                CENTRAL_ACCOUNTS[id] = (CENTRAL_ACCOUNTS[id] or 0) + delta
                return true
            end,
            SetPlayerBalance = function(cid, kind, amount, reason, key)
                table.insert(CENTRAL_CALLS, 'SetPlayerBalance')
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                CENTRAL_ACCOUNTS['player:' .. cid .. ':' .. kind] = amount
                return true
            end,
            Transfer = function(from, to, amount, reason, key)
                table.insert(CENTRAL_CALLS, 'Transfer')
                if CENTRAL_UNKNOWN then return nil, 'commit_unknown' end
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                local fb = CENTRAL_ACCOUNTS[from] or 0
                if from ~= 'central:reserve' and fb < amount then return false, 'insufficient_funds' end
                if from ~= 'central:reserve' then CENTRAL_ACCOUNTS[from] = fb - amount end
                if to ~= 'central:reserve' then CENTRAL_ACCOUNTS[to] = (CENTRAL_ACCOUNTS[to] or 0) + amount end
                return true
            end,
            TransferMany = function(moves, reason, key)
                table.insert(CENTRAL_CALLS, 'TransferMany')
                if not CENTRAL_READY then return false, 'economy_not_ready' end
                return true
            end,
            GetBanks = function()
                table.insert(CENTRAL_CALLS, 'GetBanks')
                return { { id = 'valentine', name = 'Valentine Bank', taxRate = 2 } }
            end,
            TaxRate = function(branch)
                table.insert(CENTRAL_CALLS, 'TaxRate')
                return branch == 'valentine' and 2 or 0
            end,
            BankTransfer = function(src, branch, from, to, amount, reason, key)
                table.insert(CENTRAL_CALLS, 'BankTransfer')
                return true, nil, 2.50
            end,
            PlayerOutflows = function(cid, limit, beforeId)
                return { { id = 1, amount = 50 } }, nil
            end,
            RefundOutflow = function(cid, id, idx, by)
                return true, { amount = 50, kind = 'cash' }
            end,
            ListDebtAssets = function(cid)
                return { { id = 'horse:1' } }, nil
            end,
            SeizeDebtAsset = function(cid, assetId, caseId)
                return true
            end,
            Open = function()
                table.insert(CENTRAL_CALLS, 'Open')
                return true
            end,
        }

        EXPORTS['FwReady'] = function() return FW_READY end
        EXPORTS['FwBackend'] = function() return _FW_BACKEND end
        EXPORTS['FwGetSource'] = function(cid)
            local p = FW_PLAYERS[tostring(cid)]
            return p and p.src or nil
        end
        EXPORTS['FwGetMoney'] = function(src)
            table.insert(FW_CALLS, 'FwGetMoney')
            for _, p in pairs(FW_PLAYERS) do
                if p.src == tonumber(src) then return p.cash end
            end
            return nil
        end
        EXPORTS['FwGetGold'] = function(src)
            table.insert(FW_CALLS, 'FwGetGold')
            for _, p in pairs(FW_PLAYERS) do
                if p.src == tonumber(src) then return p.gold end
            end
            return nil
        end
        EXPORTS['FwAddCurrency'] = function(src, curType, amt)
            table.insert(FW_CALLS, 'FwAddCurrency')
            for _, p in pairs(FW_PLAYERS) do
                if p.src == tonumber(src) then
                    if curType == 1 then p.gold = p.gold + amt else p.cash = p.cash + amt end
                    return true
                end
            end
            return false
        end
        EXPORTS['FwRemoveCurrency'] = function(src, curType, amt)
            table.insert(FW_CALLS, 'FwRemoveCurrency')
            for _, p in pairs(FW_PLAYERS) do
                if p.src == tonumber(src) then
                    if curType == 1 then p.gold = p.gold - amt else p.cash = p.cash - amt end
                    return true
                end
            end
            return false
        end
        EXPORTS['FwAddCurrencyOffline'] = function(cid, curType, amt)
            table.insert(FW_CALLS, 'FwAddCurrencyOffline')
            if cid == 'OFF_OK' then return true end
            return false, 'player_offline'
        end
        EXPORTS['FwRemoveCurrencyOffline'] = function(cid, curType, amt)
            table.insert(FW_CALLS, 'FwRemoveCurrencyOffline')
            if cid == 'OFF_OK' then return true end
            return false, 'player_offline'
        end
        EXPORTS['FwGetUser'] = function(src)
            for cid, p in pairs(FW_PLAYERS) do
                if p.src == tonumber(src) and p.bank ~= nil then
                    return {
                        PlayerData = { citizenid = cid, money = { cash = p.cash, gold = p.gold, bank = p.bank } },
                        Functions = {
                            AddMoney = function(kind, amt)
                                table.insert(FW_CALLS, 'RSG.AddMoney:' .. kind)
                                p[kind] = (p[kind] or 0) + amt
                                return true
                            end,
                            RemoveMoney = function(kind, amt)
                                table.insert(FW_CALLS, 'RSG.RemoveMoney:' .. kind)
                                if (p[kind] or 0) < amt then return false end
                                p[kind] = p[kind] - amt
                                return true
                            end,
                        }
                    }
                end
            end
            return nil
        end
        EXPORTS['FwGetPlayerData'] = function()
            return { citizenid = 'CID1', money = { cash = 120, bank = 300, gold = 5 } }
        end

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
                            return tbl[fnName](...)
                        end
                    end
                })
            end
        })
        """
    )

    lua.execute((ROOT / "resource/econbridge/shared.lua").read_text(encoding="utf-8"))
    if is_server:
        lua.execute((ROOT / "resource/econbridge/server.lua").read_text(encoding="utf-8"))
    else:
        lua.execute((ROOT / "resource/econbridge/client.lua").read_text(encoding="utf-8"))
    return lua


class TestEconBridge(unittest.TestCase):
    def test_provider_detection_and_zero_double_charge(self):
        lua = build_econ_runtime(central_started=True, fw_backend="wcore", is_server=True)
        self.assertEqual(lua.eval("EXPORTS['EconProvider']()"), "w_centralbank")
        self.assertEqual(lua.eval("EXPORTS['EconName']()"), "w_centralbank")
        self.assertTrue(lua.eval("EXPORTS['EconReady']()"))

        ok = lua.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', 12.50, 'reward', 'k1')")
        self.assertTrue(ok)
        self.assertEqual(lua.eval("EXPORTS['EconGetBalance']('player:CID1:cash')"), 113.0)
        self.assertEqual(lua.eval("#FW_CALLS"), 0)

        # When w_centralbank is started but IsReady() is false, NEVER fall back to Fw*
        lua.execute("CENTRAL_READY = false")
        self.assertFalse(lua.eval("EXPORTS['EconIsReady']()"))
        ok2, why2 = lua.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', 10, 'r', 'k2')")
        self.assertFalse(ok2)
        self.assertEqual(why2, "economy_not_ready")
        self.assertEqual(lua.eval("#FW_CALLS"), 0)

    def test_3state_commit_unknown_and_bank_transfer_tuple(self):
        lua = build_econ_runtime(central_started=True, fw_backend="wcore", is_server=True)
        lua.execute("CENTRAL_UNKNOWN = true")
        ok, why = lua.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', -10, 'buy', 'k3')")
        self.assertIsNone(ok)
        self.assertEqual(why, "commit_unknown")

        lua.execute("CENTRAL_UNKNOWN = false; CENTRAL_THROW = true")
        ok_t, why_t = lua.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', -10, 'buy', 'k4')")
        self.assertIsNone(ok_t)
        self.assertEqual(why_t, "commit_unknown")

        lua.execute("CENTRAL_THROW = false")
        ok_bt, why_bt, tax_bt = lua.eval("EXPORTS['EconBankTransfer'](1, 'valentine', 'player:CID1:bank', 'player:CID2:bank', 100, 'wire', 'k5')")
        self.assertTrue(ok_bt)
        self.assertIsNone(why_bt)
        self.assertEqual(tax_bt, 2.50)

    def test_framework_fallback_vorp_and_rsg(self):
        # VORP fallback: bank maps to cash, pre-checks insufficient_funds
        lua_vorp = build_econ_runtime(central_started=False, fw_backend="vorp", is_server=True)
        self.assertEqual(lua_vorp.eval("EXPORTS['EconProvider']()"), "framework")
        self.assertTrue(lua_vorp.eval("EXPORTS['EconReady']()"))

        # Insufficient funds refused before calling FwRemoveCurrency
        ok_ins, why_ins = lua_vorp.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', -500, 'too_much')")
        self.assertFalse(ok_ins)
        self.assertEqual(why_ins, "insufficient_funds")

        # Bank maps to cash on VORP
        self.assertTrue(lua_vorp.eval("EXPORTS['EconAdjustPlayer']('CID1', 'bank', -20, 'fee')"))
        self.assertEqual(lua_vorp.eval("FW_PLAYERS.CID1.cash"), 100.0)

        # Transfer player <-> reserve & player <-> player
        self.assertTrue(lua_vorp.eval("EXPORTS['EconTransfer']('central:reserve', 'player:CID1:cash', 25, 'grant')"))
        self.assertEqual(lua_vorp.eval("FW_PLAYERS.CID1.cash"), 125.0)
        self.assertTrue(lua_vorp.eval("EXPORTS['EconTransfer']('player:CID1:cash', 'player:CID2:cash', 25, 'p2p')"))
        self.assertEqual(lua_vorp.eval("FW_PLAYERS.CID1.cash"), 100.0)
        self.assertEqual(lua_vorp.eval("FW_PLAYERS.CID2.cash"), 75.0)

        # Institution accounts refused cleanly
        ok_soc, why_soc = lua_vorp.eval("EXPORTS['EconTransfer']('player:CID1:cash', 'society:police', 10, 'fine')")
        self.assertFalse(ok_soc)
        self.assertEqual(why_soc, "centralbank_unavailable")
        ok_ens, why_ens = lua_vorp.eval("EXPORTS['EconEnsureAccount']('society:police', '', 'society')")
        self.assertFalse(ok_ens)
        self.assertEqual(why_ens, "centralbank_unavailable")

        # Offline fallback
        self.assertTrue(lua_vorp.eval("EXPORTS['EconAdjustPlayer']('OFF_OK', 'cash', 15, 'off')"))

        # RSG fallback: uses real bank account
        lua_rsg = build_econ_runtime(central_started=False, fw_backend="rsg", is_server=True)
        self.assertEqual(lua_rsg.eval("EXPORTS['EconGetBalance']('player:CID1:bank')"), 300.0)
        self.assertTrue(lua_rsg.eval("EXPORTS['EconAdjustPlayer']('CID1', 'bank', -50, 'rsg_bank')"))
        self.assertEqual(lua_rsg.eval("FW_PLAYERS.CID1.bank"), 250.0)
        self.assertEqual(lua_rsg.eval("FW_PLAYERS.CID1.cash"), 120.0)

        # w_core without w_centralbank refuses mutations
        lua_wc = build_econ_runtime(central_started=False, fw_backend="wcore", is_server=True)
        self.assertFalse(lua_wc.eval("EXPORTS['EconReady']()"))
        ok_wc, why_wc = lua_wc.eval("EXPORTS['EconAdjustPlayer']('CID1', 'cash', 10, 'no_cb')")
        self.assertFalse(ok_wc)
        self.assertEqual(why_wc, "centralbank_unavailable")

    def test_events_funcref_and_client_exports(self):
        lua_srv = build_econ_runtime(central_started=False, fw_backend="vorp", is_server=True)
        lua_srv.execute(
            """
            BAL_EVENTS = {}
            local funcref = setmetatable({}, {
                __call = function(_, acc, bal)
                    table.insert(BAL_EVENTS, { acc = acc, bal = bal })
                end
            })
            INVOKER = 'res_temp'
            EXPORTS['EconOnBalanceChanged'](funcref)
            EXPORTS['EconAdjustPlayer']('CID1', 'cash', 10, 'test')
            """
        )
        self.assertEqual(lua_srv.eval("#BAL_EVENTS"), 1)
        self.assertEqual(lua_srv.eval("BAL_EVENTS[1].acc"), "player:CID1:cash")
        self.assertEqual(lua_srv.eval("BAL_EVENTS[1].bal"), 130.0)

        lua_srv.execute("TriggerEvent('onResourceStop', 'res_temp'); EXPORTS['EconAdjustPlayer']('CID1', 'cash', 10, 'test2')")
        self.assertEqual(lua_srv.eval("#BAL_EVENTS"), 1)

        # Client side
        lua_cli = build_econ_runtime(central_started=False, fw_backend="vorp", is_server=False)
        ok_open, why_open = lua_cli.eval("EXPORTS['EconOpen']()")
        self.assertFalse(ok_open)
        self.assertEqual(why_open, "centralbank_unavailable")
        lua_cli.execute(
            """
            CLI_BAL = {}
            EXPORTS['EconOnBalanceChanged'](function(acc, bal) table.insert(CLI_BAL, { acc, bal }) end)
            TriggerEvent('vorp:updateUi', '{"moneyquanty":88,"goldquanty":4}')
            """
        )
        self.assertEqual(lua_cli.eval("CLI_BAL[1][1]"), "player:local:cash")
        self.assertEqual(lua_cli.eval("CLI_BAL[1][2]"), 88)


if __name__ == "__main__":
    unittest.main()
