local call = w.voice._call

--- Ask the dialogue model (messages = { { role, content }, ... }, schema = optional JSON schema).
function w.voice.chat(messages, schema)
  return call("chatCharacter", nil, messages, schema)
end
