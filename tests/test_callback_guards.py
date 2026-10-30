"""Exercise the real callback module without a server or player data."""
from pathlib import Path
import json
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]


class CallbackGuards(unittest.TestCase):
    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            w={callback={},require=function()end,createModule=function()end}
            EVENTS={}; HANDLERS={}; TIMERS={}; SENT={}; WAITS=0; CLOCK=0
            promise={new=function() return {resolve=function(self,value) self.value=value end} end}
            function AddEventHandler(name,fn)
                EVENTS[name]=EVENTS[name] or {}; table.insert(EVENTS[name],fn)
            end
            function RegisterNetEvent(name,fn) HANDLERS[name]=fn;return name end
            function RegisterServerEvent(name,fn) SERVER_HANDLER=fn end
            function RemoveEventHandler(id) HANDLERS[id]=nil end
            function GetPlayerIdentifier()return 'fixture' end
            function generateEventName(kind,id)return kind..':'..id end
            function TriggerClientEvent(...)table.insert(SENT,table.pack(...))end
            function GetInvokingResource()return 'fixture' end
            function GetConvarInt(_,default)return default end
            function GetGameTimer()return CLOCK end
            function SetTimeout(ms,fn)table.insert(TIMERS,{ms=ms,dueAt=CLOCK+ms,fn=fn})end
            function runDueTimers()
                local due={}
                for _,timer in ipairs(TIMERS)do
                    if not timer.fired and timer.dueAt<=CLOCK then
                        timer.fired=true;table.insert(due,timer.fn)
                    end
                end
                for _,fn in ipairs(due)do fn()end
            end
            function Wait()WAITS=WAITS+1 end
            function Await(p)
                if p.value then return p.value end
                return coroutine.yield('pending')
            end
            function exports()end
            function dprint()end
            function eprint()end
            function emit(name,...) for _,fn in ipairs(EVENTS[name] or {})do fn(...)end end
            source=1
        ''')
        source = (ROOT/'modules/callback/g_server.lua').read_text(encoding='utf-8')
        source = source.replace('getmetatable(cb)?.__call','(getmetatable(cb) or {}).__call')
        self.lua.execute(source)

    def test_unknown_names_are_immediate_and_budgeted(self):
        self.lua.execute("for n=1,200 do SERVER_HANDLER('unknown',n,'fixture')end")
        self.assertEqual(self.lua.eval('WAITS'),0)
        self.assertEqual(self.lua.eval('#SENT'),120)

    def test_bad_metadata_and_numbers_never_reach_callback(self):
        self.lua.execute('''
            CALLED=0; w.callback.register('known',function()CALLED=CALLED+1 end)
            for _,id in ipairs({-1,65536,1.5,0/0,math.huge,'3'})do SERVER_HANDLER('known',id,'fixture')end
            SERVER_HANDLER({},1,'fixture'); SERVER_HANDLER('known',1,{})
            SERVER_HANDLER('known',1,'bad resource'); SERVER_HANDLER('known',1,string.rep('x',129))
            SERVER_HANDLER('known',0,'fixture')
        ''')
        self.assertEqual(self.lua.eval('CALLED'),1)

    def test_budget_recovers_and_is_cleared_when_player_leaves(self):
        self.lua.execute('''
            CALLED=0;w.callback.register('known',function()CALLED=CALLED+1;return true end)
            for n=1,200 do SERVER_HANDLER('known',n,'fixture')end
            CLOCK=1000;SERVER_HANDLER('known',201,'fixture')
            emit('playerDropped');SERVER_HANDLER('known',202,'fixture')
        ''')
        self.assertEqual(self.lua.eval('CALLED'),122)

    def test_in_flight_and_duplicate_request_are_bounded(self):
        self.lua.execute('''
            CALLED=0; w.callback.register('slow',function()CALLED=CALLED+1;coroutine.yield()end)
            THREADS={}
            for n=1,40 do
                local co=coroutine.create(function()SERVER_HANDLER('slow',n,'fixture')end)
                table.insert(THREADS,co);assert(coroutine.resume(co))
            end
            SERVER_HANDLER('slow',1,'fixture')
        ''')
        self.assertEqual(self.lua.eval('CALLED'),32)
        self.lua.execute("assert(coroutine.resume(THREADS[1]));local co=coroutine.create(function()SERVER_HANDLER('slow',41,'fixture')end);assert(coroutine.resume(co))")
        self.assertEqual(self.lua.eval('CALLED'),33)

    def test_failure_releases_request_slot(self):
        self.lua.execute('''
            CALLED=0; w.callback.register('fails',function()CALLED=CALLED+1;error('fixture')end)
            for n=1,20 do SERVER_HANDLER('fails',n,'fixture')end
        ''')
        self.assertEqual(self.lua.eval('CALLED'),20)

    def start_client_request(self):
        self.lua.execute("ANSWERS=0;w.callback.triggerClient('confirm',1,function(...)ANSWERS=ANSWERS+1;ANSWER=table.pack(...)end)")

    def test_timeout_settles_and_cleans_once(self):
        self.start_client_request()
        self.assertEqual(self.lua.eval('TIMERS[1].ms'),15000)
        self.lua.execute('TIMERS[1].fn();TIMERS[1].fn()')
        self.assertEqual(self.lua.eval('ANSWERS'),1)
        self.assertIsNone(self.lua.eval("HANDLERS['response:0']"))

    def test_default_deadline_fires_only_at_fifteen_seconds(self):
        self.start_client_request()
        self.lua.execute('CLOCK=5000;runDueTimers();CLOCK=14999;runDueTimers()')
        self.assertEqual(self.lua.eval('ANSWERS'),0)
        self.assertIsNotNone(self.lua.eval("HANDLERS['response:0']"))
        self.lua.execute('CLOCK=15000;runDueTimers();runDueTimers()')
        self.assertEqual(self.lua.eval('ANSWERS'),1)
        self.assertIsNone(self.lua.eval('ANSWER[1]'))
        self.assertIsNone(self.lua.eval("HANDLERS['response:0']"))

    def test_legitimate_eight_second_reply_wins_deadline(self):
        self.start_client_request()
        self.lua.execute('CLOCK=8000;runDueTimers()')
        self.assertEqual(self.lua.eval('ANSWERS'),0)
        self.assertIsNotNone(self.lua.eval("HANDLERS['response:0']"))
        self.lua.execute("source=1;HANDLERS['response:0']('fixture',true)")
        self.assertEqual(self.lua.eval('ANSWERS'),1)
        self.assertTrue(self.lua.eval('ANSWER[1]'))
        self.lua.execute('CLOCK=15000;runDueTimers()')
        self.assertEqual(self.lua.eval('ANSWERS'),1)
        self.assertTrue(self.lua.eval('ANSWER[1]'))
        self.assertIsNone(self.lua.eval("HANDLERS['response:0']"))

    def test_forged_reply_is_ignored_and_real_reply_wins_timeout(self):
        self.start_client_request()
        self.lua.execute("source=2;HANDLERS['response:0']('fixture',true)")
        self.assertEqual(self.lua.eval('ANSWERS'),0)
        self.lua.execute("source=1;HANDLERS['response:0']('fixture',true);TIMERS[1].fn()")
        self.assertEqual(self.lua.eval('ANSWERS'),1)
        self.assertTrue(self.lua.eval('ANSWER[1]'))

    def test_disconnect_and_caller_stop_finish_pending(self):
        for event,args in [('playerDropped',''),('onResourceStop',",'fixture'")]:
            self.setUp();self.start_client_request()
            self.lua.execute(f"emit('{event}'{args});TIMERS[1].fn()")
            self.assertEqual(self.lua.eval('ANSWERS'),1)
            self.assertIsNone(self.lua.eval("HANDLERS['response:0']"))

    def test_await_resolves_nil_after_timeout(self):
        self.lua.execute("co=coroutine.create(function()return w.callback.await('confirm',1)end);assert(coroutine.resume(co));TIMERS[1].fn();assert(coroutine.resume(co))")
        self.assertEqual(self.lua.eval('coroutine.status(co)'),'dead')

    def test_cleanup_is_safe_when_a_consumer_starts_another_client_request(self):
        for event,args in [('playerDropped',''),('onResourceStop',",'fixture'")]:
            self.setUp()
            self.lua.execute("for n=1,50 do w.callback.triggerClient('first',1,function()w.callback.triggerClient('next',2,function()end)end)end")
            self.lua.execute(f"emit('{event}'{args})")
            self.assertTrue(self.lua.eval("(function()for n=0,49 do if HANDLERS['response:'..n] then return false end end return true end)()"))
            self.assertTrue(self.lua.eval("(function()for n=50,99 do if not HANDLERS['response:'..n] then return false end end return true end)()"))

    def test_validation_reply_uses_import_channel(self):
        source=(ROOT/'resource/callbacks/shared.lua').read_text(encoding='utf-8')
        source=source.replace('`FORMAT_STACK_TRACE`','0')
        self.lua.execute("cache={resource='w_lib',game='fxserver'};lib={print={verbose=function()end}}")
        self.lua.execute(source)
        self.lua.execute("HANDLERS['w_lib:validateCallback']('missing','fixture','key')")
        self.assertEqual(self.lua.eval('SENT[1][1]'),'__ox_cb_fixture')
        self.assertEqual(self.lua.eval('SENT[1][4]'),'cb_invalid')
        self.lua.execute("HANDLERS['w_lib:validateCallback']('missing',{},'key');lib.setValidCallback('registered',true);HANDLERS['w_lib:validateCallback']('registered','fixture','key')")
        self.assertEqual(self.lua.eval('#SENT'),1)

    def test_arabic_settings_title(self):
        self.assertEqual(json.loads((ROOT/'locales/ar.json').read_text(encoding='utf-8'))['settings'],'الإعدادات')


if __name__=='__main__':
    unittest.main()
