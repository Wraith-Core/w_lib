-------------
-- Client Side — Wraith Core (w_core)
-- ⚠️ This file is executed in all resources that load the framework module ⚠️
-------------
if not w.framework:getCore() then
  local ok, core = pcall(function() return exports.w_core:GetCoreObject() end)
  if ok and type(core) == "table" then w.framework.core = core end
end
