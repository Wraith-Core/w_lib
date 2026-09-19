w.createModule("nui")
local nuiLoaded = {}

--- Loads a NUI interface
---@param uiName string (The name of the NUI to load)
---@param url string (The URL of the NUI to load)
function w.nui.load(uiName, url)
  -- سكربت بواجهة مخصّصة (ui_page ليست قشرة w_lib) يستخدم منطق w (menu/prompt) دون واجهة w:
  -- لا نُجبره على القشرة ولا نُغرق الكونسول بخطأ — نتخطّى بصمت.
  -- الواجهة المرئيّة له تأتي إمّا عبر واجهته الخاصّة، أو عبر API المركزيّ (exports.w_lib).
  -- ★ Always a no-op now. This guarded "am I running under w_lib's shell?", and the shell is
  --   gone: every interface lives in the one built app, so there is nothing left to load into.
  --   Kept as a function rather than deleted because modules still call it, and a silent skip
  --   is what they already expected on a resource with its own ui_page.
  if true then
    return
  end
  if (url:sub(1, 1) == "@") then url = url:sub(2) end
  if (not url:find("://")) then url = "nui://" .. url end
  if nuiLoaded[uiName] then return eprint("This nui is already loaded:", uiName) end

  nuiLoaded[uiName] = true
  SendNUIMessage({
    action = "w_nui_loadNUI",
    url = url,
    uiName = uiName,
  })
end

--- Forces focus on a specific NUI interface and don't spread events to other NUIs
---@param uiName string (The name of the NUI to focus on)
function w.nui.forceFocus(uiName)
  if not nuiLoaded[uiName] then return eprint("This nui is not loaded:", uiName) end
  SendNUIMessage({
    action = "w_nui_force_focus",
    uiName = uiName
  })
end

--- Resets the focus from any NUI interface and spread events
function w.nui.resetFocus()
  SendNUIMessage({
    action = "w_nui_reset_focus"
  })
end

--- A function to know if a nui is loaded
---@param uiName string (The name of the NUI)
---@return boolean (`true` if the nui is already loaded)
function w.nui.isLoaded(uiName)
  return nuiLoaded[uiName] and true or false
end

--- A function to know if the mouse is hovering over a NUI
--- The NUI has to be start with the nui module to be detected
---@return boolean (`true` if the mouse is hovering over a NUI)
local hovering
local function isHovering()
  hovering = nil
  SendNUIMessage({
    action = "w_nui_is_hovering"
  })
  while hovering == nil do Wait(0) end
  return hovering
end

RegisterNUICallback("w_nui_is_hovering", function(data, cb)
  hovering = data.hovering
  cb("ok")
end)

function w.nui.isHovering(global)
  global = GetValue(global, true)
  if not global then
    return isHovering()
  end
  return exports.w_lib:w_nui_is_global_hovering()
end

exports("w_nui_is_hovering", function()
  return isHovering()
end)


w.ready(function()
  exports.w_lib:w_nui_init()
end)
