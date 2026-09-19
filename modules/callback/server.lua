w.createModule("callback")

--- Server mirror of the client's w.callback.await: ask a client and wait for its answer.
--- w.callback.await(name, source, ...) == w.callback.triggerClient(name, source, nil, ...)
---@param name string (The name of the client callback)
---@param source integer (The player to ask)
---@param ... any (The arguments)
---@return any (The values the client callback returned; nil after the 5 s timeout)
function w.callback.await(name, source, ...)
  return w.callback.triggerClient(name, source, nil, ...)
end

w.callback.register = setmetatable({},
  {
    __index = function(_, key)
      if key == "latent" then
        return w.callback.registerLatentCallback
      end
      return w.callback["register" .. key]
    end,
    __call = function(_, ...)
      w.callback.registerCallback(...)
    end,
  }
)
