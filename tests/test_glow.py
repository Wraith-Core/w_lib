"""imports/glow (4.2.0): polygons by default, the game's glitter only with opts.particle = true. Natives are mocked."""
from pathlib import Path
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]

RING, SPHERE, ARROW = 0x6903B113, 0x50638AB9, 0x07DCE236

HARNESS = r'''
lib = {}
NOW = 0; CAM = { x = 0.0, y = 0.0, z = 0.0 }
CALLS = { poly = 0, line = 0, fx = 0, stop = 0, ground = 0 }
MARKERS = {}
THREADS = {}
function GetConvarInt(_, d) return d end
function GetGameTimer() return NOW end
function joaat(s) return #s end
function CreateThread(fn) THREADS[#THREADS + 1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function AddEventHandler() end
function GetCurrentResourceName() return 'test' end
function GetFinalRenderedCamCoord() return CAM end
function PlayerPedId() return 1 end
function GetEntityCoords() return CAM end
GROUND = 5.0
function GetGroundZFor_3dCoord(x, y, z) CALLS.ground = CALLS.ground + 1; if GROUND and GROUND <= z then return true, GROUND end return false, 0.0 end
function DrawPoly() CALLS.poly = CALLS.poly + 1 end
function DrawMarker(kind, x, y, z, a, b, c, d, e, f, sx, sy, sz, r, g, bl, al)
    MARKERS[#MARKERS + 1] = { kind = kind, x = x, y = y, z = z, sx = sx, sy = sy, sz = sz, r = r, g = g, b = bl, a = al }
end
function RequestNamedPtfxAsset() end
function HasNamedPtfxAssetLoaded() return true end
function UseParticleFxAsset() end
function StartParticleFxLoopedAtCoord() CALLS.fx = CALLS.fx + 1; return CALLS.fx end
function StopParticleFxLooped() CALLS.stop = CALLS.stop + 1 end
function SetParticleFxLoopedOffsets() return true end
Citizen = { InvokeNative = function() CALLS.line = CALLS.line + 1 end }
function vector3(x, y, z) return { x = x, y = y, z = z } end

-- one frame: every thread runs once (a thread that waited longer than the frame waits on)
function frame(ms)
    NOW = NOW + (ms or 16)
    local list = THREADS
    THREADS = {}
    for _, co in ipairs(list) do
        if coroutine.status(co) ~= 'dead' then
            local ok, err = coroutine.resume(co)
            assert(ok, err)
            if coroutine.status(co) ~= 'dead' then THREADS[#THREADS + 1] = co end
        end
    end
end
function reset() MARKERS = {}; CALLS.poly = 0; CALLS.line = 0 end
function count(kind) local n = 0 for _, m in ipairs(MARKERS) do if m.kind == kind then n = n + 1 end end return n end
'''


class Glow(unittest.TestCase):
    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(HARNESS)
        src = (ROOT / 'imports' / 'glow' / 'client.lua').read_text(encoding='utf-8')
        self.lua.execute(src)
        self.G = self.lua.globals()

    def run_frames(self, n=5, ms=16):
        for _ in range(n):
            self.G.frame(ms)

    def last(self, kind):
        ms = [m for m in self.G.MARKERS.values() if m.kind == kind]
        return ms[-1] if ms else None

    def test_point_is_a_sphere_without_particles(self):
        self.lua.execute("ID = lib.glow.point(vector3(1, 1, 10), { look = 2, scale = 1.6 })")
        self.run_frames(20)
        self.assertEqual(self.G.CALLS.fx, 0, 'no particle by default')
        m = self.last(SPHERE)
        self.assertIsNotNone(m, 'a sphere marker')
        self.assertAlmostEqual(m.sx, 0.4, places=5)
        self.assertEqual((m.r, m.g, m.b), (242, 242, 242), 'paper by default')
        self.assertEqual(self.lua.eval('lib.glow.count()'), 0)

    def test_explicit_solid_point_keeps_the_ring(self):
        self.lua.execute("lib.glow.point(vector3(1, 1, 10), { look = 2, lift = 0.05, solid = { color = { 203, 1, 1 }, alpha = 160, size = 0.5 } })")
        self.run_frames(3)
        m = self.last(RING)
        self.assertIsNotNone(m, '4.1.2 callers with solid keep their flat ring')
        self.assertEqual((m.r, m.g, m.b, m.a), (203, 1, 1, 160))
        self.assertAlmostEqual(m.sx, 1.0, places=5)
        self.assertEqual(count_kind(self.G, SPHERE), 0)

    def test_particle_opt_in(self):
        self.lua.execute("lib.glow.point(vector3(1, 1, 10), { look = 2, particle = true })")
        self.run_frames(30, 50)
        self.assertGreater(self.G.CALLS.fx, 0, 'particle = true burns the glitter')
        self.assertEqual(len(list(self.G.MARKERS.values())), 0, 'and draws no polygon unless solid is given')

    def test_particle_with_solid_draws_both(self):
        self.lua.execute("lib.glow.circle(vector3(1, 1, 10), 2.0, { particle = true, solid = true, ground = false })")
        self.run_frames(30, 50)
        self.assertGreater(self.G.CALLS.fx, 0)
        self.assertGreater(count_kind(self.G, RING), 0)

    def test_circle_sits_on_the_ground(self):
        self.lua.execute("lib.glow.circle(vector3(3, 3, 6.0), 1.5, { look = 4 })")
        self.run_frames(3)
        m = self.last(RING)
        self.assertAlmostEqual(m.z, 5.03, places=5)
        self.assertAlmostEqual(m.sx, 3.0, places=5)
        self.lua.execute("reset(); lib.glow.clear(); lib.glow.circle(vector3(3, 3, 6.0), 1.5, { ground = false })")
        self.run_frames(3)
        self.assertAlmostEqual(self.last(RING).z, 6.03, places=5, msg='ground = false keeps its own height')

    def test_wide_circle_is_a_ring_wall(self):
        self.lua.execute("lib.glow.circle(vector3(0, 0, 6.0), 30.0, { look = 4, color = { 203, 1, 1 }, range = 150.0 })")
        self.lua.execute("reset()")
        self.G.frame(16)
        self.assertEqual(count_kind(self.G, RING), 0, 'no disc over the whole zone')
        self.assertEqual(self.G.CALLS.poly, 95 * 4, 'a wall of 95 pieces round it (2 m each)')
        self.lua.execute("lib.glow.clear(); reset(); lib.glow.circle(vector3(0, 0, 6.0), 5.0, { ground = false, solid = { shape = 'ring', alpha = 60 } })")
        self.G.frame(16)
        self.assertEqual(count_kind(self.G, RING), 1, "shape = 'ring' keeps the flat ring (the placer's reach)")

    def test_arrow_is_the_game_arrow(self):
        self.lua.execute("lib.glow.frame('drop', 'arrow', vector3(2, 2, 8), { look = 3, size = 0.4 })")
        self.G.frame(16)
        m = self.last(ARROW)
        self.assertIsNotNone(m)
        self.assertAlmostEqual(m.sx, 0.3, places=5)
        self.assertAlmostEqual(m.sy, 0.2, places=5)
        self.assertAlmostEqual(m.sz, 0.15, places=5)
        self.assertEqual(m.a, 222)
        # a colour with an alpha (w_farming's care arrows)
        self.lua.execute("reset(); lib.glow.clear(); lib.glow.frame('care', 'arrow', vector3(2, 2, 8), { size = 0.5, color = { 70, 150, 255, 220 } })")
        self.G.frame(16)
        m = self.last(ARROW)
        self.assertEqual((m.r, m.g, m.b, m.a), (70, 150, 255, 220))

    def test_flat_arrow_with_heading_is_polygons(self):
        self.lua.execute("lib.glow.arrow(vector3(2, 2, 8), { heading = 90.0, size = 1.0 })")
        self.G.frame(16)
        self.assertEqual(self.G.CALLS.poly, 6, 'head + shaft, both faces')

    def test_wall_follows_ground_and_budget(self):
        # a 20 x 20 m square on the ground: cut every 2 m -> 40 pieces, 4 polygons + 2 lines each
        self.lua.execute("lib.glow.wall({ vector3(0,0,6), vector3(20,0,6), vector3(20,20,6), vector3(0,20,6) }, { range = 100.0 })")
        self.lua.execute("reset()")
        self.G.frame(16)
        self.assertEqual(self.G.CALLS.poly, 40 * 4)
        self.assertEqual(self.G.CALLS.line, 40 * 2)
        self.assertEqual(self.G.CALLS.fx, 0)
        # a huge wall: only the budget (150 pieces) nearest the eye
        self.lua.execute("lib.glow.clear(); lib.glow.wall({ vector3(0,0,6), vector3(2000,0,6) }, { range = 5000.0 })")
        self.run_frames(15, 20)
        self.lua.execute("reset()")
        self.G.frame(16)
        self.assertEqual(self.G.CALLS.poly, 150 * 4)

    def test_out_of_range_is_not_drawn(self):
        self.lua.execute("lib.glow.point(vector3(500, 0, 10), {})")
        self.run_frames(5)
        self.assertEqual(len(list(self.G.MARKERS.values())), 0)
        self.lua.execute("CAM = { x = 495.0, y = 0.0, z = 10.0 }")
        self.run_frames(20, 20)
        self.assertGreater(count_kind(self.G, SPHERE), 0, 'drawn once the eye comes near')

    def test_frame_shape_stops_when_not_drawn(self):
        self.lua.execute("lib.glow.frame('aim', 'point', vector3(1, 1, 10), { scale = 0.5 })")
        self.G.frame(16)
        self.assertGreater(count_kind(self.G, SPHERE), 0)
        self.lua.execute("reset()")
        self.run_frames(12, 16)   # about 200 ms without a new call
        self.lua.execute("reset()")
        self.G.frame(16)
        self.assertEqual(count_kind(self.G, SPHERE), 0, 'gone like DrawMarker once the caller stops')

    def test_moving_frame_shape_is_drawn_where_it_is(self):
        for x in (1, 2, 3):
            self.lua.execute(f"reset(); lib.glow.frame('cursor', 'point', vector3({x}, 1, 10), {{}})")
            self.G.frame(16)
            self.assertAlmostEqual(self.last(SPHERE).x, x, places=5)

    def test_bad_input_is_refused(self):
        self.assertIsNone(self.lua.eval("lib.glow.wall({ vector3(0,0,0) })"))
        self.assertIsNone(self.lua.eval("lib.glow.point('x')"))
        self.assertIsNone(self.lua.eval("lib.glow.circle(vector3(0,0,0), -1)"))
        self.assertIsNone(self.lua.eval("lib.glow.frame('k', 'nope', vector3(0,0,0))"))


def count_kind(G, kind):
    return sum(1 for m in G.MARKERS.values() if m.kind == kind)


if __name__ == '__main__':
    unittest.main()
