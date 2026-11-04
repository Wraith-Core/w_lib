--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local input

---@class InputDialogRowProps
---@field type 'input' | 'number' | 'checkbox' | 'select' | 'slider' | 'multi-select' | 'date' | 'date-range' | 'time' | 'textarea' | 'color'
---@field label string
---@field options? { value: string, label: string, default?: string }[]
---@field password? boolean
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string
---@field placeholder? string
---@field default? string | number
---@field disabled? boolean
---@field checked? boolean
---@field min? number
---@field max? number
---@field step? number
---@field autosize? boolean
---@field required? boolean
---@field format? string
---@field returnString? boolean
---@field clearable? boolean
---@field searchable? boolean
---@field description? string
---@field maxSelectedValues? number
---@field minLength? number
---@field maxLength? number
---@field allow? string the only characters a text field takes, as a character class body ('A-Za-z0-9 \'-'): anything else is dropped as it is typed or pasted

---@class InputDialogOptionsProps
---@field allowCancel? boolean
---@field size? 'xs' | 'sm' | 'md' | 'lg' | 'xl'

---@param heading string
---@param rows string[] | InputDialogRowProps[]
---@param options InputDialogOptionsProps[]?
---@return string[] | number[] | boolean[] | nil
function lib.inputDialog(heading, rows, options)
    if input then return end
    input = promise.new()

    -- Backwards compat with string tables (build a normalized copy, don't mutate caller's rows)
    local normalized = table.create(#rows, 0)

    for i = 1, #rows do
        local row = rows[i]
        normalized[i] = type(row) == 'string'
            and { type = 'input', label = row --[[@as string]] }
            or row
    end

    lib.setNuiFocus(false)
    -- قشرة w تكدّس عدّة iframes ملء الشاشة؛ الإطار الأعلى (wnotify) يلتقط النقر
    -- ويعيد توجيهه لإطار الواجهة (wui) كحدث اصطناعي — والأحداث الاصطناعية لا
    -- تُركّز حقول <input> (التركيز يحتاج حدثًا حقيقيًّا). فبلا رفع wui وتثبيت
    -- التركيز عليه لا تعمل الكتابة في حقول الإدخال. يُلغى عند الإغلاق/الإرسال.
    SendNUIMessage({ action = 'w_nui_force_focus', uiName = 'wui' })
    SendNUIMessage({
        action = 'openDialog',
        data = {
            heading = heading,
            rows = normalized,
            options = options
        }
    })

    return Citizen.Await(input)
end

function lib.closeInputDialog()
    if not input then return end

    lib.resetNuiFocus()
    SendNUIMessage({ action = 'w_nui_reset_focus' })
    SendNUIMessage({
        action = 'closeInputDialog'
    })

    input:resolve(nil)
    input = nil
end

RegisterNUICallback('inputData', function(data, cb)
    cb(1)
    lib.resetNuiFocus()
    SendNUIMessage({ action = 'w_nui_reset_focus' })

    local promise = input
    input = nil

    promise:resolve(data)
end)
