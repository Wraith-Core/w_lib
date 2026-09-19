--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

lib.raycast = {}

local StartShapeTestLosProbe = StartShapeTestLosProbe
local GetShapeTestResultIncludingMaterial = GetShapeTestResultIncludingMaterial
local glm_sincos = require 'glm'.sincos
local glm_rad = require 'glm'.rad
local math_abs = math.abs
local GetFinalRenderedCamCoord = GetFinalRenderedCamCoord
local GetFinalRenderedCamRot = GetFinalRenderedCamRot

---@alias ShapetestIgnore
---| 1 GLASS
---| 2 SEE_THROUGH
---| 3 GLASS | SEE_THROUGH
---| 4 NO_COLLISION
---| 7 GLASS | SEE_THROUGH | NO_COLLISION

---@alias ShapetestFlags integer
---| 1 INCLUDE_MOVER
---| 2 INCLUDE_VEHICLE
---| 4 INCLUDE_PED
---| 8 INCLUDE_RAGDOLL
---| 16 INCLUDE_OBJECT
---| 32 INCLUDE_PICKUP
---| 64 INCLUDE_GLASS
---| 128 INCLUDE_RIVER
---| 256 INCLUDE_FOLIAGE
---| 511 INCLUDE_ALL

---@param coords vector3
---@param destination vector3
---@param flags ShapetestFlags? Defaults to 511.
---@param ignore ShapetestIgnore? Defaults to 4.
---@return boolean hit
---@return number entityHit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return number materialHash
function lib.raycast.fromCoords(coords, destination, flags, ignore)
    local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y,
        destination.z, flags or 511, cache.ped, ignore or 4)

    while true do
        Wait(0)
        local retval, hit, endCoords, surfaceNormal, material, entityHit = GetShapeTestResultIncludingMaterial(handle)

        if retval ~= 1 then
            return hit, entityHit, endCoords, surfaceNormal, material
        end
    end
end

local function getForwardVector()
    local sin, cos = glm_sincos(glm_rad(GetFinalRenderedCamRot(2)))
    return vec3(-sin.z * math_abs(cos.x), cos.z * math_abs(cos.x), sin.x)
end

---@param flags ShapetestFlags? Defaults to 511.
---@param ignore ShapetestIgnore? Defaults to 4.
---@param distance number? Defaults to 10.
function lib.raycast.fromCamera(flags, ignore, distance)
    local coords = GetFinalRenderedCamCoord()
    local destination = coords + getForwardVector() * (distance or 10)

    return lib.raycast.fromCoords(GetFinalRenderedCamCoord(), destination, flags, ignore)
end

---@deprecated
lib.raycast.cam = lib.raycast.fromCamera

-- ════════════════════════════════════════════════════════════════════════════
-- w_lib: which part of a ped a screen point lands on (the creator's click-to-focus).
--   The ray leaves the rendered camera through the screen point; the ped's bones are
--   projected onto it and the closest one names the part. No shape test: a bone-distance
--   pick is what a "click the head, zoom on the head" camera wants, and it works while the
--   ped is frozen in a scripted scene where collision probes are unreliable.
-- ════════════════════════════════════════════════════════════════════════════
local glm = require 'glm'
local glm_quatEulerAngleZYX = glm.quatEulerAngleZYX
local glm_up = glm.up()
local glm_forward = glm.forward()
local glm_right = glm.right and glm.right() or vec3(1.0, 0.0, 0.0)

-- bone id -> part, in the order the tie is broken (the head wins over the neck)
local PED_PARTS = {
    { part = 'eyes', bones = { 21030 } },                    -- SKEL_Head (tight radius, see below)
    { part = 'head', bones = { 21030, 39317 } },             -- SKEL_Head, SKEL_Neck_1
    { part = 'body', bones = { 23553, 24816, 24817, 11816 } }, -- SKEL_Spine3, SKEL_Spine2, SKEL_Spine1, SKEL_Pelvis
    { part = 'pant', bones = { 58271, 51826, 63931, 36864 } }, -- thighs and calves
    { part = 'boot', bones = { 14201, 52301 } },             -- SKEL_L_Foot, SKEL_R_Foot
}
local PART_RADIUS = { eyes = 0.09, head = 0.22, body = 0.42, pant = 0.32, boot = 0.22 }

--- The part of `ped` under the screen point (x, y in 0..1 from the top-left corner, as a NUI
--- click reports them). `aspect` is the frame's width / height when it is not the screen's.
--- Returns 'eyes' | 'head' | 'body' | 'pant' | 'boot', or nil when the click misses the ped.
---@param ped number
---@param x number
---@param y number
---@param aspect? number
---@return string? part
---@return number? distance (metres between the ray and the bone that won)
function lib.raycast.pedPartFromScreen(ped, x, y, aspect)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    x, y = tonumber(x) or 0.5, tonumber(y) or 0.5
    if not aspect or aspect <= 0 then
        local sw, sh = GetActiveScreenResolution()
        aspect = (sw and sh and sh > 0) and (sw / sh) or (16 / 9)
    end

    local origin = GetFinalRenderedCamCoord()
    local rot = glm_rad(GetFinalRenderedCamRot(2))
    local q = glm_quatEulerAngleZYX(rot.z, rot.y, rot.x)
    local forward, up = q * glm_forward, q * glm_up
    local right = q * glm_right
    local tanHalf = math.tan(glm_rad(GetFinalRenderedCamFov()) / 2)
    -- screen (0..1, y down) -> camera plane offsets at unit distance
    local dir = forward + right * ((x * 2 - 1) * tanHalf * aspect) - up * ((y * 2 - 1) * tanHalf)
    local len = #dir
    if len == 0 then return nil end
    dir = dir / len

    local bestPart, bestDist
    for _, entry in ipairs(PED_PARTS) do
        local radius = PART_RADIUS[entry.part]
        for _, bone in ipairs(entry.bones) do
            local at = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
            if at and (at.x ~= 0.0 or at.y ~= 0.0 or at.z ~= 0.0) then
                local toBone = at - origin
                local along = toBone.x * dir.x + toBone.y * dir.y + toBone.z * dir.z
                if along > 0 then
                    local closest = origin + dir * along
                    local d = #(at - closest)
                    -- the score is the miss relative to the part's size: a click just off a
                    -- small part still means that part, not the big one behind it
                    local score = d / radius
                    if d <= radius and (not bestDist or score < bestDist) then
                        bestPart, bestDist = entry.part, score
                    end
                end
            end
        end
    end
    return bestPart, bestDist
end

return lib.raycast
