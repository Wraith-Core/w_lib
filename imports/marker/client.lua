--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@diagnostic disable: param-type-mismatch
lib.marker = {}

---@enum (key) MarkerType
local markerTypes = {
  UpsideDownCone = 0,
  VerticalCylinder = 1,
  ThickChevronUp = 2,
  ThinChevronUp = 3,
  CheckeredFlagRect = 4,
  CheckeredFlagCircle = 5,
  VerticleCircle = 6,
  PlaneModel = 7,
  LostMCTransparent = 8,
  LostMC = 9,
  Number0 = 10,
  Number1 = 11,
  Number2 = 12,
  Number3 = 13,
  Number4 = 14,
  Number5 = 15,
  Number6 = 16,
  Number7 = 17,
  Number8 = 18,
  Number9 = 19,
  ChevronUpx1 = 20,
  ChevronUpx2 = 21,
  ChevronUpx3 = 22,
  HorizontalCircleFat = 23,
  ReplayIcon = 24,
  HorizontalCircleSkinny = 25,
  HorizontalCircleSkinny_Arrow = 26,
  HorizontalSplitArrowCircle = 27,
  DebugSphere = 28,
  DollarSign = 29,
  HorizontalBars = 30,
  WolfHead = 31,
  QuestionMark = 32,
  PlaneSymbol = 33,
  HelicopterSymbol = 34,
  BoatSymbol = 35,
  CarSymbol = 36,
  MotorcycleSymbol = 37,
  BikeSymbol = 38,
  TruckSymbol = 39,
  ParachuteSymbol = 40,
  Unknown41 = 41,
  SawbladeSymbol = 42,
  Unknown43 = 43,
}

---@class MarkerProps
---@field type? MarkerType | integer
---@field coords { x: number, y: number, z: number }
---@field width? number
---@field height? number
---@field color? { r: integer, g: integer, b: integer, a: integer }
---@field rotation? { x: number, y: number, z: number }
---@field direction? { x: number, y: number, z: number }
---@field bobUpAndDown? boolean
---@field faceCamera? boolean
---@field rotate? boolean
---@field textureDict? string
---@field textureName? string
---@field invert? boolean

local vector3_zero = vector3(0, 0, 0)

-- ★ Ink, paper and one red on every interface (w_lib/nui/theme/tokens.css): a marker is drawn in the
--   paper step nearest in lightness to the colour it was given, its alpha kept. The caller's table
--   is not touched; the marker keeps its own copy.
local PAPER_STEPS = { { 242, 242, 242 }, { 180, 180, 180 }, { 122, 122, 122 } }

local function toPaper(c)
  local r, g, b = tonumber(c.r) or 242, tonumber(c.g) or 242, tonumber(c.b) or 242
  local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
  local best, dist = PAPER_STEPS[1], math.huge
  for i = 1, #PAPER_STEPS do
    local t = PAPER_STEPS[i]
    local d = math.abs(0.2126 * t[1] + 0.7152 * t[2] + 0.0722 * t[3] - y)
    if d < dist then best, dist = t, d end
  end
  return { r = best[1], g = best[2], b = best[3], a = tonumber(c.a) or 100 }
end

local marker_mt = {
  type = 0,
  width = 2.,
  height = 1.,
  color = {r = 242, g = 242, b = 242, a = 100}, -- paper (tokens.css), was orange
  rotation = vector3_zero,
  direction = vector3_zero,
  bobUpAndDown = false,
  faceCamera = false,
  rotate = false,
  invert = false,
}
marker_mt.__index = marker_mt

-- ★ w_lib 4.1.0 (the owner 2026-10-23): the game's glitter instead of DrawMarker (imports/glow), in its own colour
--   (the paper rule above: no hue). A wide marker is a ring of look 4 (its width = the ring), a small one a point of
--   look 2. Same call every frame as before.
-- ★ 4.2.0 (the owner 2026-11-02: polygons, not particles, to mark places): a marker given one of the game's marker
--   hashes (e.g. w_baloot's seat arrow 0x07DCE236) is drawn with DrawMarker again, as before 4.1.0; the others go
--   through lib.glow, which draws its polygon look (a flat ring / a sphere) since 4.2.0.
function marker_mt:draw()
  local c = self.coords
  local kind = self.type
  if type(kind) == 'number' and (kind > 43 or kind < 0) then
    local col = self.color
    DrawMarker(
      kind,
      c.x, c.y, c.z,
      self.direction.x, self.direction.y, self.direction.z,
      self.rotation.x, self.rotation.y, self.rotation.z,
      self.width, self.width, self.height,
      col.r, col.g, col.b, col.a,
      self.bobUpAndDown, self.faceCamera, 2, self.rotate, self.textureDict, self.textureName, self.invert)
    return
  end
  local col = self.color
  local solid = { color = { col.r, col.g, col.b }, alpha = col.a, size = self.width / 2.0 }
  if self.width >= 0.6 then
    lib.glow.frame(self, 'circle', c, self.width / 2.0, { look = 4, ground = false, solid = solid })
  else
    solid.shape = 'sphere'
    lib.glow.frame(self, 'point', c, { look = 2, solid = solid })
  end
end

---@param options MarkerProps
function lib.marker.new(options)
  local self = setmetatable(table.clone(options), marker_mt)

  self.type =
    type(self.type) == 'string' and markerTypes[self.type]
    or type(self.type) == 'number' and self.type or nil

  if type(rawget(self, 'color')) == 'table' then self.color = toPaper(self.color) end

  self.width += .0
  self.height += .0

  return self
end

return lib.marker
