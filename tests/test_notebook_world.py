"""4.5.0 notebook pieces for the next waves: lib.place (a place in words), lib.setPins (numbered labels over the
world) and lib.worldEdit (the builders' world mode). Natives are mocked; the real files run in Lua 5.4 (lupa)."""
import json
from pathlib import Path
import re
import unittest

from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]

HARNESS = r'''
lib = {}
cache = { resource = 'w_lib' }
NOW = 1000
CAM = { x = 0.0, y = 0.0, z = 2.0 }
ROT = { x = 0.0, y = 0.0, z = 0.0 }
PED = { x = 0.0, y = 0.0, z = 0.0 }
HIT = { x = 3.0, y = 12.0, z = 0.5 }
INVOKER = nil
TOWN, DISTRICT = 0, 0
SENT = {}
PRESSED = {}
DISABLED = {}
HANDLERS = {}
NEXT_HANDLE = 0
ENTS = {}
NEXT_ENT = 100
DELETED = {}
THREADS = {}

local noop = function() end
setmetatable(_G, { __index = function(_, k)
    if type(k) == 'string' and k:match('^%u') and k:match('%l') then return noop end   -- natives (CamelCase) only
end })

local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b) if type(a) == 'number' then a, b = b, a end return vector3(a.x * b, a.y * b, a.z * b) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
function GetGameTimer() return NOW end
function GetCurrentResourceName() return 'w_test' end
function GetInvokingResource() return INVOKER end
function PlayerPedId() return 1 end
function GetEntityCoords() return PED end
function GetMapZoneAtCoords(x, y, z, kind) if kind == 1 then return TOWN end return DISTRICT end
function joaat(s)
    if s == 'INPUT_SELECT_NEXT_WEAPON' then return 1001 end
    if s == 'INPUT_SELECT_PREV_WEAPON' then return 1002 end
    return #s
end

function CreateThread(fn) THREADS[#THREADS + 1] = { co = coroutine.create(fn), wake = 0 } end
function Wait(ms) coroutine.yield(ms or 0) end
function frame(ms)
    NOW = NOW + (ms or 16)
    local list = THREADS
    THREADS = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if NOW >= t.wake then
                local ok, waited = coroutine.resume(t.co)
                assert(ok, waited)
                t.wake = NOW + (tonumber(waited) or 0)
            end
            if coroutine.status(t.co) ~= 'dead' then THREADS[#THREADS + 1] = t end
        end
    end
    PRESSED = {}
end
function frames(n, ms) for _ = 1, n do frame(ms) end end

function AddEventHandler(name, fn)
    NEXT_HANDLE = NEXT_HANDLE + 1
    HANDLERS[NEXT_HANDLE] = { name = name, fn = fn }
    return NEXT_HANDLE
end
function RemoveEventHandler(h) HANDLERS[h] = nil end
function TriggerEvent(name, ...)
    for _, h in pairs(HANDLERS) do if h.name == name then h.fn(...) end end
end

function SendNUIMessage(m) SENT[#SENT + 1] = m end
function lastPins()
    for i = #SENT, 1, -1 do if SENT[i].action == 'wl:pins' then return SENT[i].data.pins end end
end

-- a camera looking north (+y): on screen when in front, x and z move the spot from the centre
function GetFinalRenderedCamCoord() return CAM end
function GetFinalRenderedCamRot() return ROT end
function GetGameplayCamCoord() return CAM end
function GetGameplayCamRot() return ROT end
function GetScreenCoordFromWorldCoord(x, y, z)
    if y <= CAM.y then return false, 0.0, 0.0 end
    return true, 0.5 + (x - CAM.x) / 50.0, 0.5 - (z - CAM.z) / 50.0
end
function GetGroundZFor_3dCoord() return true, 0.0 end
function StartShapeTestLosProbe() return 7 end
function GetShapeTestResult() return 2, true, HIT, nil, 0 end

function IsDisabledControlJustPressed(_, c) return PRESSED[c] == true end
function DisableControlAction(_, c) DISABLED[c] = true end
function IsModelInCdimage() return true end
function HasModelLoaded() return true end
local function ent(kind, model) NEXT_ENT = NEXT_ENT + 1; ENTS[NEXT_ENT] = { kind = kind, model = model }; return NEXT_ENT end
function CreatePed(m) return ent('ped', m) end
function CreateVehicle(m) return ent('vehicle', m) end
function CreateObject(m) return ent('object', m) end
function DoesEntityExist(e) return ENTS[e] ~= nil end
function DeleteEntity(e) DELETED[#DELETED + 1] = e; ENTS[e] = nil end
Citizen = { InvokeNative = noop }

local function sortedKeys(t) local k = {} for key in pairs(t) do k[#k + 1] = key end table.sort(k, function(a, b) return tostring(a) < tostring(b) end) return k end
local function enc(v)
    local t = type(v)
    if t == 'table' then
        local parts = {}
        for _, k in ipairs(sortedKeys(v)) do parts[#parts + 1] = tostring(k) .. '=' .. enc(v[k]) end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return tostring(v)
end
json = { encode = enc }
'''

WORLD = r'''
GLOW = {}
lib.glow = { frame = function(key, kind, at, r, opts) GLOW[key] = { kind = kind, r = r, opts = opts, at = NOW } end }
KEYS, NEXT_KEY = {}, 0
lib.rawKeys = {
    listen = function(key, cb) NEXT_KEY = NEXT_KEY + 1; KEYS[NEXT_KEY] = { key = key:upper(), cb = cb }; return NEXT_KEY end,
    removeListener = function(id) KEYS[id] = nil end,
}
function rawKey(name, down) for _, l in pairs(KEYS) do if l.key == name then l.cb(down) end end end
MENU, OPEN, MENUS = nil, nil, {}
lib.registerContext = function(m) MENUS[m.id] = m end
lib.showContext = function(id) MENU = MENUS[id]; OPEN = id end
lib.getOpenContextMenu = function() return OPEN end
lib.hideContext = function() OPEN = nil end
TEXT = nil
lib.showTextUI = function(t) TEXT = t end
lib.hideTextUI = function() TEXT = nil end
GROUPS = {}
w = {
    prompt = { createGroup = function(title, pos)
        local g = { title = title, pos = pos, keys = {}, shown = false, deleted = false }
        g.addPrompt = function(key, label) g.keys[#g.keys + 1] = key .. ':' .. label end
        g.display = function() g.shown = true end
        g.hide = function() g.shown = false end
        g.isVisible = function() return g.shown end
        g.delete = function() g.deleted = true end
        GROUPS[#GROUPS + 1] = g
        return g
    end },
    placer = { run = function(o) PLACER = o; return { spot = vector4(5.0, 6.0, 0.0, 90.0) } end },
}
exports = { w_lib = {
    worldEditWords = function() return lib.worldEditWords() end,
    WalkupClaim = function() CLAIMS = (CLAIMS or 0) + 1 end,
} }
function pick(i)
    local opt = MENU.options[i]
    OPEN = nil
    TriggerEvent(opt.event, opt.args)
end
'''


def flat(d, prefix=''):
    out = {}
    for k, v in d.items():
        key = prefix + k
        if isinstance(v, dict):
            out.update(flat(v, key + '.'))
        else:
            out[key] = v
    return out


def words(lang):
    return flat(json.loads((ROOT / 'locales' / f'{lang}.json').read_text(encoding='utf-8')))


class Base(unittest.TestCase):
    LANG = 'ar'

    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        self.G = self.lua.globals()
        table = self.lua.table_from(words(self.LANG))
        self.G.WORDS = table
        self.lua.execute("function locale(k) return WORDS[k] or k end")
        self.load_file('resource/interface/client/place.lua')
        self.G.lib.place = self.load_file('imports/place/client.lua')

    def load_file(self, rel):
        return self.lua.execute((ROOT / rel).read_text(encoding='utf-8'))


class Place(Base):
    def test_distance_words(self):
        d = self.G.lib.place.distance
        self.assertEqual(d(12.4), '12 م')
        self.assertEqual(d(456), '460 م')
        self.assertEqual(d(1234), '1.2 كم')
        self.assertEqual(d(3000), '3 كم')

    def test_town_then_district_then_wild(self):
        self.lua.execute('TOWN = 459833523')
        r = self.lua.eval('lib.place.describe({ x = 0.0, y = 12.0, z = 0.0 })')
        self.assertEqual(r.zone, 'valentine')
        self.assertEqual(r.text, 'فالنتاين · 12 م منك')
        self.assertEqual(r.meters, 12)
        self.lua.execute('TOWN = 0; DISTRICT = 2025841068')
        self.assertEqual(self.lua.eval('lib.place.describe({ x = 900.0, y = 1.0 }).name'), 'بايو نوا')
        self.lua.execute('DISTRICT = 0')
        self.assertEqual(self.lua.eval('lib.place.describe({ x = 5000.0, y = 1.0 }).name'), 'البرية')

    def test_here_within_three_metres(self):
        self.lua.execute('TOWN = 2046780049')
        self.assertEqual(self.lua.eval('lib.place.describe(vector3(1.0, 1.0, 0.0)).text'), 'رودس · هنا')

    def test_cell_cache(self):
        self.lua.execute('TOWN = 459833523')
        self.assertEqual(self.lua.eval('lib.place.zone({ x = 1.0, y = 1.0 })'), 'valentine')
        self.lua.execute('TOWN = 2046780049')
        self.assertEqual(self.lua.eval('lib.place.zone({ x = 2.0, y = 2.0 })'), 'valentine', 'same 8 m cell')
        self.assertEqual(self.lua.eval('lib.place.zone({ x = 40.0, y = 2.0 })'), 'rhodes')

    def test_not_a_place(self):
        self.assertIsNone(self.lua.eval("lib.place.describe('x')"))


class PlaceEnglish(Base):
    LANG = 'en'

    def test_english_text(self):
        self.lua.execute('TOWN = 459833523')
        self.assertEqual(self.lua.eval('lib.place.describe({ x = 0.0, y = 12.0 }).text'), 'Valentine · 12 m away')


class Pins(Base):
    def setUp(self):
        super().setUp()
        self.load_file('resource/interface/client/pins.lua')

    def test_projected_aimed_and_floating(self):
        self.lua.execute('''
            INVOKER = 'w_jobs'
            lib.setPins('job', {
                { id = 'npc', n = 1, label = string.rep('ب', 100), x = 0.0, y = 10.0, z = 0.0, lift = 2.1 },
                { id = 'box', n = 2, label = 'صندوق', x = 20.0, y = 10.0, z = 0.0 },
                { id = 'gone', n = 3, label = 'ناقص', state = 'miss' },
                { id = 'behind', label = 'خلفك', x = 0.0, y = -10.0, z = 0.0 },
            })
        ''')
        self.lua.execute('frames(4)')
        pins = {p.id: p for p in self.lua.eval('lastPins()').values()}
        self.assertEqual(set(pins), {'npc', 'box', 'gone'}, 'the one behind the camera is not drawn')
        self.assertTrue(pins['npc'].aim)
        self.assertIsNone(pins['box'].aim)
        self.assertEqual(pins['gone'].st, 'miss')
        self.assertEqual(len(pins['npc'].label), 80, 'labels are cut at 80')
        self.assertEqual(self.lua.eval("lib.getAimedPin('job')"), 'npc')

    def test_sent_only_on_change_and_cleaned_on_stop(self):
        self.lua.execute("INVOKER = 'w_jobs'; lib.setPins('job', { { id = 'a', x = 0.0, y = 10.0, z = 0.0 } })")
        self.lua.execute('frames(6)')
        n = len(self.G.SENT)
        self.lua.execute('frames(6)')
        self.assertEqual(len(self.G.SENT), n, 'nothing moved, nothing sent')
        self.lua.execute("TriggerEvent('onResourceStop', 'w_jobs'); frames(40, 16)")
        self.assertEqual(len(self.lua.eval('lastPins()')), 0, 'the set went with its resource')
        self.assertIsNone(self.lua.eval("lib.getAimedPin('job')"))

    def test_sets_belong_to_their_resource(self):
        self.lua.execute("INVOKER = 'a'; lib.setPins('k', { { id = 'x', x = 0.0, y = 10.0 } })")
        self.lua.execute("INVOKER = 'b'; lib.clearPins('k')")
        self.lua.execute('frames(4)')
        self.assertEqual(len(self.lua.eval('lastPins()')), 1)

    def test_far_pins_fade_and_range_drops(self):
        self.lua.execute("lib.setPins('k', { { id = 'mid', x = 0.0, y = 100.0, z = 0.0 }, { id = 'out', x = 0.0, y = 400.0 } }, { range = 150, near = 60 })")
        self.lua.execute('frames(4)')
        pins = {p.id: p for p in self.lua.eval('lastPins()').values()}
        self.assertEqual(set(pins), {'mid'})
        self.assertTrue(pins['mid'].far)


class WorldEdit(Base):
    def setUp(self):
        super().setUp()
        self.load_file('resource/interface/client/pins.lua')
        self.lua.execute(WORLD)
        self.G.lib.worldEdit = self.load_file('imports/worldEdit/client.lua')
        self.lua.execute('''
            CALLS = {}
            local function log(name) return function(...) CALLS[#CALLS + 1] = { name = name, args = { ... } } end end
            EDIT = lib.worldEdit.start({
                key = 'build',
                items = {
                    { id = 'npc', n = 1, label = 'بائع الجرائد', x = 0.0, y = 10.0, z = 0.0, kind = 'ped', model = 'u_m_m_x', turn = true, r = 2.5 },
                    { id = 'box', n = 2, label = 'صندوق', x = 20.0, y = 10.0, z = 0.0 },
                },
                ground = function(at) return {
                    { title = 'ضع البائع هنا', onSelect = function(spot) GROUND_AT = spot end },
                } end,
                onMove = log('move'), onTurn = log('turn'), onRadius = log('radius'), onRemove = log('remove'),
                onOpen = log('open'), onUndo = log('undo'), onBoard = log('board'), onStop = log('stop'),
            })
        ''')

    def calls(self, name):
        return [c for c in self.G.CALLS.values() if c.name == name]

    def test_board_mode_draws_but_takes_no_keys(self):
        self.lua.execute('frames(40, 16)')
        pins = {p.id for p in self.lua.eval('lastPins()').values()}
        self.assertEqual(pins, {'npc', 'box'})
        self.assertEqual([e.kind for e in self.G.ENTS.values()], ['ped'], 'one ghost (the ped)')
        self.assertIn('we:', ''.join(self.G.GLOW.keys()), 'the ring of the radius')
        self.lua.execute('PRESSED[0xF3830D8E] = true; frame()')
        self.assertIsNone(self.G.MENU, 'J does nothing on the board')
        self.assertIsNone(self.G.TEXT)

    def test_world_mode_pin_menu_and_keys(self):
        self.lua.execute('EDIT:setWorld(true); frames(10)')
        self.assertTrue(self.G.DISABLED[0xAC4BD4F1], 'the weapon wheel is off')
        self.assertTrue(self.G.TEXT, 'the instruction line')
        group = list(self.G.GROUPS.values())[-1]
        self.assertTrue(group.shown)
        self.assertIn('J:عدّل', list(group['keys'].values()))
        self.lua.execute('PRESSED[0xF3830D8E] = true; frame()')
        titles = [o.title for o in self.G.MENU.options.values()]
        self.assertEqual(titles, ['حرّكه', 'لفّه نحوي', 'احذفه', 'افتح الخطوة'])
        self.assertEqual(self.G.MENU.title, 'بائع الجرائد')
        self.lua.execute('pick(3); frames(3)')
        self.assertEqual(self.calls('remove')[0].args[1].id, 'npc')
        self.lua.execute('frames(6); PRESSED[0xDE794E3E] = true; frame()')
        self.assertEqual(self.calls('radius')[0].args[2], 3.5)
        self.lua.execute('PRESSED[1001] = true; frame()')
        self.assertEqual(self.calls('turn')[0].args[2], 345.0)
        self.lua.execute('PRESSED[0x4AF4D473] = true; frame()')
        self.assertEqual(len(self.calls('remove')), 2)

    def test_move_runs_the_placer_then_returns(self):
        self.lua.execute('EDIT:setWorld(true); frames(10); PRESSED[0xF3830D8E] = true; frame(); pick(1); frames(5)')
        self.assertEqual(self.G.PLACER.steps[1].kind, 'ped')
        mv = self.calls('move')[0]
        self.assertEqual((mv.args[2].x, mv.args[2].y), (5.0, 6.0))
        self.assertTrue(self.lua.eval('EDIT:isWorld()'), 'back in world mode after the move')

    def test_ground_menu_what_happens_here(self):
        self.lua.execute('TOWN = 459833523; CAM.x = 100.0; EDIT:setWorld(true); frames(10)')
        self.lua.execute('PRESSED[0xF3830D8E] = true; frame()')
        self.assertEqual(self.G.MENU.title, 'ماذا يحدث هنا؟')
        self.assertTrue(self.G.MENU.subtitle.startswith('فالنتاين · '))
        self.lua.execute('pick(1)')
        self.assertEqual((self.G.GROUND_AT.x, self.G.GROUND_AT.y), (3.0, 12.0))

    def test_tab_ctrl_z_and_stop(self):
        self.lua.execute('EDIT:setWorld(true); frames(30)')
        self.lua.execute("rawKey('CTRL', true); rawKey('Z', true); rawKey('CTRL', false)")
        self.assertEqual(len(self.calls('undo')), 1)
        self.lua.execute("rawKey('TAB', true)")
        self.assertFalse(self.lua.eval('EDIT:isWorld()'))
        self.assertEqual(len(self.calls('board')), 1)
        self.lua.execute('frames(40, 16); EDIT:stop(); frames(40, 16)')
        self.assertEqual(len(self.lua.eval('lastPins()')), 0)
        self.assertEqual(len(list(self.G.ENTS.values())), 0, 'the ghost is deleted')
        self.assertEqual(len(list(self.G.KEYS.values())), 0, 'the key listeners are removed')
        self.assertEqual(self.calls('stop')[0].args[1], 'stopped')

    def test_rows_carry_ids(self):
        self.lua.execute("""
            ROWS = {}
            EDIT.o.onRow = function(id, ctx) ROWS[#ROWS + 1] = { id = id, ctx = ctx } end
            EDIT.o.ground = function(at) return {
                { id = 'seller', title = 'ضع البائع هنا', onSelect = function(spot, id) GROUND_ID = id end },
            } end
            EDIT:setWorld(true); frames(10)
        """)
        self.lua.execute('PRESSED[0xF3830D8E] = true; frame(); pick(3); frames(3)')
        self.assertEqual(self.G.ROWS[1].id, 'delete')
        self.assertEqual(self.G.ROWS[1].ctx.id, 'npc', 'onRow gets the item')
        self.lua.execute('frames(6); TOWN = 459833523; CAM.x = 100.0; frames(10); PRESSED[0xF3830D8E] = true; frame(); pick(1)')
        self.assertEqual(self.G.GROUND_ID, 'seller', 'a ground row gets its own id')
        self.assertEqual(self.G.ROWS[2].id, 'seller')

    def test_pin_menu_ids_for_pinmenu(self):
        self.lua.execute("""
            IDS = {}
            EDIT.o.pinMenu = function(it, rows) for _, r in ipairs(rows) do IDS[#IDS + 1] = r.id end return rows end
            EDIT:setWorld(true); frames(10); PRESSED[0xF3830D8E] = true; frame()
        """)
        self.assertEqual(list(self.G.IDS.values()), ['move', 'turn', 'delete', 'open'])
        titles = [o.title for o in self.G.MENU.options.values()]
        self.assertEqual(titles, ['حرّكه', 'لفّه نحوي', 'احذفه', 'افتح الخطوة'], 'titles and order unchanged')

    def test_set_world_too_soon_is_refused_or_queued(self):
        self.lua.execute("EDIT:setWorld(true); frames(30); rawKey('TAB', true)")
        self.assertFalse(self.lua.eval('EDIT:isWorld()'))
        self.assertFalse(self.lua.eval('EDIT:setWorld(true)'), 'too soon: old callers read false')
        self.assertFalse(self.lua.eval('EDIT:isPending()'), 'not queued unless asked')
        self.lua.execute('WORLD_ON = 0; EDIT.o.onWorld = function(on) if on then WORLD_ON = WORLD_ON + 1 end end')
        self.assertFalse(self.lua.eval('EDIT:setWorld(true, { queue = true })'))
        self.assertTrue(self.lua.eval('EDIT:isPending()'))
        self.lua.execute('frames(40, 16)')
        self.assertTrue(self.lua.eval('EDIT:isWorld()'), 'the queued switch applied after the gap')
        self.assertEqual(self.G.WORLD_ON, 1)
        self.lua.execute("frames(30); rawKey('TAB', true); EDIT:setWorld(true, { queue = true }); EDIT:setWorld(false); frames(40, 16)")
        self.assertFalse(self.lua.eval('EDIT:isWorld()'), 'setWorld(false) cancels the queue')

    def test_resource_stop_ends_it(self):
        self.lua.execute("frames(40, 16); TriggerEvent('onResourceStop', 'w_test'); frames(3)")
        self.assertEqual(self.calls('stop')[0].args[1], 'resource')


class Locales(unittest.TestCase):
    def test_same_keys_in_both_languages(self):
        ar, en = words('ar'), words('en')
        for prefix in ('ui.', 'place.', 'worldedit.'):
            a = {k for k in ar if k.startswith(prefix)}
            e = {k for k in en if k.startswith(prefix)}
            self.assertEqual(a, e, prefix)

    def test_every_zone_has_words(self):
        src = (ROOT / 'imports' / 'place' / 'client.lua').read_text(encoding='utf-8')
        keys = set(re.findall(r"\] = '([a-z_]+)'", src))
        ar = words('ar')
        for k in keys:
            self.assertIn('place.zone.' + k, ar)
        listed = set(re.findall(r"'([a-z_]+)'", (ROOT / 'resource/interface/client/place.lua').read_text(encoding='utf-8').split('local function word')[0]))
        self.assertTrue(keys <= listed, 'resource/interface/client/place.lua lists every zone')

    def test_world_words_listed(self):
        src = (ROOT / 'resource/interface/client/place.lua').read_text(encoding='utf-8')
        listed = set(re.findall(r"'([a-z_]+)'", src.split('WORLD_KEYS = {')[1].split('}')[0]))
        ar = {k.split('.', 1)[1] for k in words('ar') if k.startswith('worldedit.')}
        self.assertEqual(listed, ar)


if __name__ == '__main__':
    unittest.main()
