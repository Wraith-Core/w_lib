w.require("emit")

if w.resourceName ~= "w_lib" then
  w.callback = exports.w_lib:getCallbackAPI()
end
