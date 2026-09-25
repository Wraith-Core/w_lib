-- ============================================================
--  w_lib/resource/dbtrace  —  كل خطأ SQL مبتلَع يصير سطراً في الكونسول
--
--  ⚠️ oxmysql يطلق 'oxmysql:error' ثم — على مسار MySQL.*.await تحديداً — يسلّم النصّ
--     إلى الـ callback بدل console.error (dist/build.js:26848-26869). فإذا غلّف المورد
--     النداء بـ pcall (وهو النمط الشائع) ابتُلع الخطأ مرّتين: لا استثناء ولا سطر كونسول،
--     ويرى اللاعب رسالة عامّة بلا أي أثر. حدث واحد هنا يكفي لكل موارد السيرفر.
--
--  لا يغيّر سلوك أي استعلام: يقرأ حمولة الحدث ويطبع فقط.
-- ============================================================

local MAX = 400 -- لا نُغرق الكونسول باستعلام ضخم

local function cut(text)
    text = tostring(text or '')
    if #text <= MAX then return text end
    return text:sub(1, MAX) .. ('… (+%d)'):format(#text - MAX)
end

AddEventHandler('oxmysql:error', function(info)
    if type(info) ~= 'table' then return end
    local params = ''
    if info.parameters ~= nil then
        local ok, encoded = pcall(json.encode, info.parameters)
        params = ok and (' | params: ' .. cut(encoded)) or ''
    end
    print(('^1[db]^7 %s: query failed — %s\n       query: %s%s'):format(
        tostring(info.resource or '?'), cut(info.message), cut(info.query), params))
end)
