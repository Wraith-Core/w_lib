--[[
    w_lib — dataview
    مخزن بايتات ثنائيّ (ArrayBuffer / Buffer) — كتابتنا الأصليّة عبر Lua 5.4
    (string.pack / string.unpack / string.blob). بديل وحدة dataview الأصلية.
    الاستخدام الأساسيّ في الحقيبة: مخزن GUID للأسلحة تكتب فيه النتيفات (out:Buffer()).

    الواجهة:
        local v = DataView.ArrayBuffer(size)   -- إنشاء مخزن قابل للتعديل
        v:Buffer()                             -- المخزن الخام (يُمرَّر للنتيفات كإخراج)
        v:GetInt64(offset) / v:SetInt64(offset, value)  -- قراءة/كتابة (وأنواع أخرى)
]]

-- string.blob (امتداد CfxLua) ينشئ سلسلة قابلة للتعديل تكتب فيها النتيفات.
-- عند غيابه نسقط إلى string.rep (للقراءة/الكتابة في Lua فقط).
local sblob = string.blob or function(len) return string.rep('\0', math.max(41, len or 0)) end

local DataView = {}
DataView.__index = DataView

--- إنشاء مخزن بطول length بايت.
---@param length number
---@return table view
function DataView.ArrayBuffer(length)
    length = length or 0
    return setmetatable({ length = length, blob = sblob(length) }, DataView)
end

--- المخزن الخام (يُمرَّر للنتيفات كمعامل إخراج GUID).
function DataView:Buffer()
    return self.blob
end

--- طول المخزن بالبايت.
function DataView:ByteLength()
    return self.length
end

-- ── قراءة/كتابة الأنواع (Little-Endian افتراضيًّا؛ مرّر littleEndian=false لـ Big-Endian) ──
local function reader(fmt)
    return function(self, offset, littleEndian)
        local e = littleEndian == false and '>' or '<'
        return (string.unpack(e .. fmt, self.blob, (offset or 0) + 1))
    end
end

local function writer(fmt, bytes)
    return function(self, offset, value, littleEndian)
        local e = littleEndian == false and '>' or '<'
        offset = offset or 0
        local packed = string.pack(e .. fmt, value)
        self.blob = self.blob:sub(1, offset) .. packed .. self.blob:sub(offset + bytes + 1)
        return self
    end
end

DataView.GetInt8    = reader('i1');  DataView.SetInt8    = writer('i1', 1)
DataView.GetUint8   = reader('I1');  DataView.SetUint8   = writer('I1', 1)
DataView.GetInt16   = reader('i2');  DataView.SetInt16   = writer('i2', 2)
DataView.GetUint16  = reader('I2');  DataView.SetUint16  = writer('I2', 2)
DataView.GetInt32   = reader('i4');  DataView.SetInt32   = writer('i4', 4)
DataView.GetUint32  = reader('I4');  DataView.SetUint32  = writer('I4', 4)
DataView.GetInt64   = reader('i8');  DataView.SetInt64   = writer('i8', 8)
DataView.GetUint64  = reader('I8');  DataView.SetUint64  = writer('I8', 8)
DataView.GetFloat32 = reader('f');   DataView.SetFloat32 = writer('f', 4)
DataView.GetFloat64 = reader('d');   DataView.SetFloat64 = writer('d', 8)

-- كائن عامّ (كما كان DataView سابقًا) — تعمل DataView.ArrayBuffer(...) مباشرة.
_ENV.DataView = DataView

return DataView
