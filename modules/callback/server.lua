w.createModule("callback")

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
