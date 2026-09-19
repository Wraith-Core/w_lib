local call = w.voice._call

--- Attach a registered character to a ped (the ped's model must match the profile).
function w.voice.bind(ped, id)
  return call("bindCharacter", false, ped, id) == true
end

function w.voice.unbind(ped)
  return call("unbindCharacter", false, ped) == true
end

--- The character bound to a ped: id, profile (nil when none).
function w.voice.character(ped)
  return call("getBoundCharacter", nil, ped)
end

--- The character the player is currently facing / talking to.
function w.voice.target()
  return call("getTarget", nil)
end

function w.voice.speak(ped, text, opts)
  return call("speak", nil, ped, text, opts)
end

function w.voice.silence(id)
  return call("silence", false, id)
end

function w.voice.registerAction(def)
  return call("registerAction", nil, def)
end

function w.voice.unregisterAction(name)
  return call("unregisterAction", false, name)
end

function w.voice.setActionEnabled(target, enabled)
  return call("setActionEnabled", false, target, enabled)
end

function w.voice.registerLayer(def)
  return call("registerLayer", nil, def)
end

function w.voice.enterLayer(name)
  return call("enterLayer", false, name)
end

function w.voice.exitLayer(name)
  return call("exitLayer", false, name)
end
