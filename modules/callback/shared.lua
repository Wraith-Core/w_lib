w.require("emit")

local function isAFunction(cb)
  local cbType = type(cb)
  if cbType == "function" then return true end
  if cbType == "table" and getmetatable(cb) and getmetatable(cb).__call then return true end
  return false
end

if w.resourceName ~= "w_lib" then
  local api = exports.w_lib:getCallbackAPI()
  if type(api) == "table" then
    w.callback = setmetatable(api, {
      __call = function(self, name, arg2, arg3, ...)
        if w.isClientSide() then
          if isAFunction(arg2) then
            return self.triggerServer(name, arg2, arg3, ...)
          elseif isAFunction(arg3) then
            return self.triggerServer(name, arg3, ...)
          else
            return self.await(name, arg2, arg3, ...)
          end
        else
          if isAFunction(arg2) then
            return self.triggerServer(name, arg2, arg3, ...)
          elseif type(arg2) == "number" or (type(arg2) == "string" and tonumber(arg2)) then
            return self.triggerClient(name, tonumber(arg2), arg3, ...)
          else
            return self.triggerServer(name, arg2, arg3, ...)
          end
        end
      end
    })
  else
    w.callback = api
  end
end
