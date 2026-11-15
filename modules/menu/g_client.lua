-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- w.menu host -- the half of the menu module that runs inside w_lib itself.
--
-- ★ WHY THIS FILE EXISTS
--   modules/menu/client.lua runs inside every resource that uses w.menu (or jo.menu), and a
--   resource's SendNUIMessage / SetNuiFocus / RegisterNUICallback only ever reach ITS OWN frame.
--   jo_libs solved that by making every consumer set `ui_page "nui://jo_libs/nui/index.html"`.
--   We do not: the menu is drawn by w_lib's one frame (web/src/features/jomenu), so a consumer
--   needs nothing in its fxmanifest. This host is the only bridge:
--     consumer --exports.w_lib:w_menu_nui-->  host --SendNUIMessage--> w_lib frame
--     w_lib frame --fetch wmenu:<name>--> host --handler funcref--> consumer
--   Focus is taken and released here too, because focus belongs to the frame that asked.
--
-- ⚠️ Every message carries its owner. Two resources can both create a menu called "main";
--    the frame keeps one store per owner, so they never see each other's menus.
-- ═══════════════════════════════════════════════════════════════════════════════════════════

local handlers = {}      -- owner resource -> function(name, data)
local queue = {}         -- messages sent before the frame answered
local frameReady = false

-- Focus is a stack: the menu shown last owns the keys; when it closes, the one under it gets
-- them back with its own settings. Only an empty stack hands the game its input mode back.
local focusStack = {}
local keepBefore = false

local function deliver(owner, msg)
  local packet = { action = "wmenu", data = { owner = owner, msg = msg } }
  if not frameReady then
    queue[#queue + 1] = packet
    return
  end
  SendNUIMessage(packet)
end

local function applyTop()
  local top = focusStack[#focusStack]
  if top then
    SetNuiFocus(true, not top.hideCursor)
    SetNuiFocusKeepInput(top.keepInput)
    SendNUIMessage({ action = "wl:focus", data = true })
  else
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(keepBefore)
    SendNUIMessage({ action = "wl:focus", data = false })
  end
end

local function dropFocus(owner)
  for i = #focusStack, 1, -1 do
    if focusStack[i].owner == owner then
      table.remove(focusStack, i)
      return true
    end
  end
  return false
end

--- The consumer hands over the function that receives the frame's callbacks.
---@param owner string the consumer's resource name
---@param handler function(name: string, data: table)
exports("w_menu_attach", function(owner, handler)
  handlers[owner] = handler
end)

--- Forward one menu message (the jo wire format: { event = ..., ... }) to the frame.
exports("w_menu_nui", function(owner, msg)
  if type(owner) ~= "string" or type(msg) ~= "table" then return end
  deliver(owner, msg)
end)

--- Take or release the keys for a menu.
---@param owner string
---@param on boolean
---@param keepInput? boolean
---@param hideCursor? boolean
exports("w_menu_focus", function(owner, on, keepInput, hideCursor)
  if on then
    if #focusStack == 0 then keepBefore = IsNuiFocusKeepingInput() end
    dropFocus(owner)
    focusStack[#focusStack + 1] = { owner = owner, keepInput = keepInput and true or false, hideCursor = hideCursor and true or false }
    applyTop()
  elseif dropFocus(owner) then
    applyTop()
  end
end)

--- Whether the frame keeps the game's input while this owner's menu has the keys.
exports("w_menu_keeping_input", function(owner)
  for i = #focusStack, 1, -1 do
    if focusStack[i].owner == owner then return focusStack[i].keepInput end
  end
  return IsNuiFocusKeepingInput()
end)

-- ── the frame's callbacks, relayed to the owner ──────────────────────────────────────────────

local function relay(name, data)
  local owner = type(data) == "table" and data.owner
  local handler = owner and handlers[owner]
  if not handler then return end
  data.owner = nil
  local ok, err = pcall(handler, name, data)
  if not ok then
    eprint(("menu: the %s callback of %s failed: %s"):format(name, owner, err))
  end
end

-- ★ onBeforeEnter answers only after the owner ran its handler: the frame waits for that answer
--   before it opens the child menu, so the handler can still rebuild what is about to be shown.
RegisterNUICallback("wmenu:onBeforeEnter", function(data, cb)
  relay("onBeforeEnter", data)
  cb("ok")
end)

for _, name in ipairs({ "click", "backMenu", "missingMenu", "updatePreview" }) do
  RegisterNUICallback("wmenu:" .. name, function(data, cb)
    cb("ok")
    relay(name, data)
  end)
end

-- The frame answers a ping (or announces itself on mount): from then on nothing is queued.
RegisterNUICallback("wmenu:ready", function(_, cb)
  cb("ok")
  if frameReady then return end
  frameReady = true
  for i = 1, #queue do SendNUIMessage(queue[i]) end
  queue = {}
end)

CreateThread(function()
  -- The app may have mounted before this module loaded (it is loaded on first use), in which
  -- case its mount announcement found no callback. Ask until it answers.
  while not frameReady do
    SendNUIMessage({ action = "wmenu:ping" })
    Wait(500)
  end
end)

-- ── an owner that stops takes its menus (and the keys) with it ──────────────────────────────

AddEventHandler("onResourceStop", function(resource)
  if resource == GetCurrentResourceName() then return end
  if handlers[resource] then
    handlers[resource] = nil
    deliver(resource, { event = "dropOwner" })
  end
  if dropFocus(resource) then applyTop() end
end)
