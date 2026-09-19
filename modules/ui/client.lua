w.createModule("ui")

--- Updates the rank element on the top left of weapon wheel
---@param level integer (The level printed in the left of the element)
---@param xp integer (The current xp amount)
---@param xpRequired integer (The amount of XP required to level up)
function w.ui.updateRank(level, xp, xpRequired)
    local container = DatabindingAddDataContainerFromPath("", "mp_rank_bar")
    DatabindingAddDataString(container, "rank_text", tostring(level))
    DatabindingAddDataString(container, "rank_header_text", xp .. "/" .. xpRequired)
    DatabindingAddDataInt(container, "rank_header_text_alpha", 100)
    DatabindingAddDataInt(container, "xp_bar_minimum", 0)
    DatabindingAddDataInt(container, "xp_bar_maximum", xpRequired)
    DatabindingAddDataInt(container, "xp_bar_value", xp)
end

-- Formats time in minutes:seconds format
--@param seconds number (The time in seconds to format)
--@return string (Formatted time in "MM:SS" format)
local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

--- Initializes the timer's UI
---@return number (The state machine identifier)
function w.ui.initTimer()
    w.ui.TimerUI = {}
    w.ui.TimerUI.data = {}
    w.ui.TimerUI.data.uiFlowblock = InvokeNative(0xC0081B34E395CE48, -119209833)

    local temp = 0
    while not UiflowblockIsLoaded(w.ui.TimerUI.data.uiFlowblock) do
        temp = temp + 1
        if temp > 10000 then
            return
        end
        Citizen.Wait(1)
    end

    if not InvokeNative(0x10A93C057B6BD944, w.ui.TimerUI.data.uiFlowblock) then
        return
    end

    w.ui.TimerUI.data.container = DatabindingAddDataContainerFromPath("", "centralInfoDatastore")
    DatabindingAddDataString(w.ui.TimerUI.data.container, "timerMessageString", "")
    w.ui.TimerUI.data.timer = DatabindingAddDataString(w.ui.TimerUI.data.container, "timerString", "")
    w.ui.TimerUI.data.show = DatabindingAddDataBool(w.ui.TimerUI.data.container, "isVisible", false)

    UiflowblockEnter(w.ui.TimerUI.data.uiFlowblock, `cTimer`)

    if UiStateMachineExists(1546991729) == 0 then
        w.ui.TimerUI.data.stateMachine = UiStateMachineCreate(1546991729, w.ui.TimerUI.data.uiFlowblock)
    end

    w.ui.TimerUI.data.time = 0
    return w.ui.TimerUI.data.stateMachine
end

--- Stops the Timer's UI before it finishes naturally
function w.ui.stopTimer()
    if not w.ui.TimerUI then return end
    w.ui.TimerUI.data.time = 0
    DatabindingWriteDataBool(w.ui.TimerUI.data.show, false)
end

--- Starts the timer's UI
---@param time integer (The time in seconds for the timer)
---@param low? integer (The threshold in seconds at which the timer color will turn red)
function w.ui.startTimer(time, low)
    if not w.ui.TimerUI or UiStateMachineExists(1546991729) == 0 then return end
    DatabindingWriteDataBool(w.ui.TimerUI.data.show, true)
    w.ui.TimerUI.data.time = time or 60

    local function updateTimer()
        if w.ui.TimerUI.data.time >= 0 then
            DatabindingWriteDataString(w.ui.TimerUI.data.timer, formatTime(w.ui.TimerUI.data.time))
            w.ui.TimerUI.data.time = w.ui.TimerUI.data.time - 1
            if low and w.ui.TimerUI.data.time <= low then
                DatabindingAddDataBool(w.ui.TimerUI.data.container, "isTimerLow", true)
            end
            w.timeout.delay("updateTimer", 1000, updateTimer)
        else
            w.ui.finishTimer()
        end
    end

    updateTimer()
end

--- Terminates the Timer's UI and destroys associated resources
function w.ui.finishTimer()
    if not w.ui.TimerUI then return end
    UiStateMachineDestroy(1546991729)
    if DatabindingIsEntryValid(w.ui.TimerUI.data.container) then
        DatabindingRemoveDataEntry(w.ui.TimerUI.data.container)
    end
    if DatabindingIsEntryValid(w.ui.TimerUI.data.timer) then
        DatabindingRemoveDataEntry(w.ui.TimerUI.data.timer)
    end
    if DatabindingIsEntryValid(w.ui.TimerUI.data.show) then
        DatabindingRemoveDataEntry(w.ui.TimerUI.data.show)
    end
end
