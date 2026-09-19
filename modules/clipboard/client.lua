w.createModule("clipboard")


--- Copy a string to the user clipboard
---@param value string (The string to copy)
w.clipboard.copy = function(value)
    return exports.w_lib:clipboard_copy(value)
end
