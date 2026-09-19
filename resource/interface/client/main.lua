--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@alias IconProp 'fas' | 'far' | 'fal' | 'fat' | 'fad' | 'fab' | 'fak' | 'fass'

local keepInput = IsNuiFocusKeepingInput()

function lib.setNuiFocus(allowInput, disableCursor)
    keepInput = IsNuiFocusKeepingInput()
    SetNuiFocus(true, not disableCursor)
    SetNuiFocusKeepInput(allowInput)
end

function lib.resetNuiFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(keepInput)
end

--- ═══════════════════════════════════════════════════════════════════════════════════════════
--- الصوت — نغمات الإطار، بالاسم
---
--- ★ The library's own interfaces ring these as they go. A resource DRIVING the library's frame
---   -- a bench described with lib.showPanel -- has no way to, and has cues of its own for
---   moments the panel knows nothing about: a craft starting, a craft completing. Naming one
---   here is what keeps such a resource from shipping a second audio layer over the same files.
---
--- ⚠️ A NAME, never a path. The bundle's five sounds are the whole vocabulary; accepting a URL
---    would let any resource play anything into the player's ears.
---@param name 'open'|'close'|'hover'|'select'|'deny'|'finish'
function lib.playSound(name)
    if type(name) ~= 'string' then return end

    SendNUIMessage({ action = 'playSound', data = name })
end

--- ═══════════════════════════════════════════════════════════════════════════════════════════
--- شريط تقدّم يقوده السكربت
---
--- ★ WHY, BESIDE lib.progressBar: that one takes a duration, times itself, blocks until it is
---   done and tells you whether it was cancelled -- right for work whose length is known up
---   front. It is wrong for work something else is already timing. w_crafting's bench runs its
---   own clock (it drives the animation and decides when the server is told), and handing the
---   frame a duration there would start a SECOND clock a frame later: the ring would empty
---   before, or after, the item actually landed.
---
---   So: the script says start, pushes a percentage as often as it likes, and says stop.
---
--- ⚠️ Nothing times out. A script that opens one of these and forgets it leaves a ring on the
---    player's screen until the resource restarts. lib.progressBar is the safer default; reach
---    for this only when you already own a clock.

local driven = false

---@param data { label?: string, position?: 'middle'|'bottom' }
function lib.showProgress(data)
    data = data or {}
    driven = true

    SendNUIMessage({
        action = 'progress',
        data = {
            label = data.label,
            position = data.position or 'bottom',
            duration = 0,
            driven = true,
        }
    })
end

--- @param value number 0-100
function lib.setProgress(value)
    if not driven then return end

    SendNUIMessage({ action = 'progressValue', data = math.max(0, math.min(100, tonumber(value) or 0)) })
end

function lib.hideProgress()
    if not driven then return end

    driven = false
    SendNUIMessage({ action = 'progressCancel' })
end

---@return boolean
function lib.drivenProgressActive() return driven end
