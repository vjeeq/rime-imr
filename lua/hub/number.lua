local M = {}

local function splitNumPart(str)
    local part = {}
    part.int, part.dot, part.dec = string.match(str, "^(%d*)(%.?)(%d*)")
    return part
end

local function decimal_func(str, posMap, valMap)
    local dec
    posMap = posMap or { [1] = "角", [2] = "分", [3] = "厘", [4] = "毫" }
    valMap = valMap or { [0] = "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
    if #str > 4 then dec = string.sub(tostring(str), 1, 4) else dec = tostring(str) end
    dec = string.gsub(dec, "0+$", "")
    if dec == "" then return "整" end
    local result = ""
    for pos = 1, #dec do
        local val = tonumber(string.sub(dec, pos, pos))
        if val ~= 0 then result = result .. valMap[val] .. posMap[pos] else result = result .. valMap[val] end
    end
    result = string.gsub(string.gsub(result, valMap[0] .. valMap[0], valMap[0]), valMap[0] .. valMap[0], valMap[0])
    return result
end

local function formatNum(num, t)
    local digitUnit, wordFigure
    local result = ""
    num = tostring(num)
    if tonumber(t) < 1 then digitUnit = { "", "十", "百", "千" } else digitUnit = { "", "拾", "佰", "仟" } end
    if tonumber(t) < 1 then
        wordFigure = { "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
    else
        wordFigure = { "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
    end
    if string.len(num) > 4 or tonumber(num) == 0 then return wordFigure[1] end
    local lens = string.len(num)
    for i = 1, lens do
        local n = wordFigure[tonumber(string.sub(num, -i, -i)) + 1]
        if n ~= wordFigure[1] then result = n .. digitUnit[i] .. result else result = n .. result end
    end
    result = string.gsub(result, wordFigure[1] .. wordFigure[1], wordFigure[1])
    result = string.gsub(result, wordFigure[1] .. "$", "")
    result = string.gsub(result, wordFigure[1] .. "$", "")
    return result
end

local function number2cnChar(num, flag, digitUnit, wordFigure)
    if tonumber(flag) < 1 then
        digitUnit = digitUnit or { [1] = "万", [2] = "亿" }
        wordFigure = wordFigure or { [1] = "〇", [2] = "一", [3] = "十", [4] = "元" }
    else
        digitUnit = digitUnit or { [1] = "万", [2] = "亿" }
        wordFigure = wordFigure or { [1] = "零", [2] = "壹", [3] = "拾", [4] = "元" }
    end
    local lens = string.len(num)
    local result
    if lens < 5 then
        result = formatNum(num, flag)
    elseif lens < 9 then
        result = formatNum(string.sub(num, 1, -5), flag) .. digitUnit[1] .. formatNum(string.sub(num, -4, -1), flag)
    elseif lens < 13 then
        result = formatNum(string.sub(num, 1, -9), flag) ..
            digitUnit[2] .. formatNum(string.sub(num, -8, -5), flag) ..
            digitUnit[1] .. formatNum(string.sub(num, -4, -1), flag)
    else
        result = ""
    end
    result = string.gsub(result, "^" .. wordFigure[1], "")
    result = string.gsub(result, wordFigure[1] .. digitUnit[1], "")
    result = string.gsub(result, wordFigure[1] .. digitUnit[2], "")
    result = string.gsub(result, wordFigure[1] .. wordFigure[1], wordFigure[1])
    result = string.gsub(result, wordFigure[1] .. "$", "")
    if lens > 4 then result = string.gsub(result, "^" .. wordFigure[2] .. wordFigure[3], wordFigure[3]) end
    if result ~= "" then result = result .. wordFigure[4] else result = "数值超限！" end
    return result
end

local function number2zh(num, t)
    local result, wordFigure
    result = ""
    if tonumber(t) < 1 then
        wordFigure = { "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
    else
        wordFigure = { "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
    end
    if tostring(num) == nil then return "" end
    for pos = 1, string.len(num) do
        result = result .. wordFigure[tonumber(string.sub(num, pos, pos) + 1)]
    end
    result = string.gsub(result, wordFigure[1] .. wordFigure[1], wordFigure[1])
    return string.gsub(result, wordFigure[1] .. wordFigure[1], wordFigure[1])
end

local function number_translatorFunc(num)
    local numberPart = splitNumPart(num)
    local result = {}
    if numberPart.dot ~= "" then
        table.insert(result, {
            number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "点" })
                .. number2zh(numberPart.dec, 0),
            "〔数字小写〕",
        })
        table.insert(result, {
            number2cnChar(numberPart.int, 1, { "萬", "億" }, { "〇", "一", "十", "点" })
                .. number2zh(numberPart.dec, 1),
            "〔数字大写〕",
        })
    else
        table.insert(result, { number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "" }), "〔数字小写〕" })
        table.insert(result, { number2cnChar(numberPart.int, 1, { "萬", "億" }, { "零", "壹", "拾", "" }), "〔数字大写〕" })
    end
    table.insert(result, {
        number2cnChar(numberPart.int, 0)
            .. decimal_func(numberPart.dec, { [1] = "角", [2] = "分", [3] = "厘", [4] = "毫" },
                { [0] = "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" }),
        "〔金额小写〕",
    })
    local number2cnCharInt = number2cnChar(numberPart.int, 1)
    local number2cnCharDec = decimal_func(numberPart.dec,
        { [1] = "角", [2] = "分", [3] = "厘", [4] = "毫" },
        { [0] = "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
    )
    if string.len(numberPart.int) > 4
        and string.find(number2cnCharInt, "^拾[壹贰叁肆伍陆柒捌玖]?")
        and string.find(number2cnCharInt, "[万亿]")
    then
        local var = string.gsub(number2cnCharInt, "^拾", "壹拾")
        table.insert(result, { var .. number2cnCharDec, "〔金额大写〕" })
    else
        table.insert(result, { number2cnCharInt .. number2cnCharDec, "〔金额大写〕" })
    end
    return result
end

function M.setup(config, prefix)
    M.prefix = config:get_string(prefix) or "R"
end

function M.match(input)
    return string.sub(input, 1, 1) == M.prefix
end

function M.translate(input, seg)
    local r = {}
    local str = string.gsub(input, "^(%a+)", "")
    local parts = number_translatorFunc(str)
    if str and #str > 0 and #parts > 0 then
        for i = 1, #parts do
            r[#r + 1] = { parts[i][1], 1, parts[i][2] }
        end
    end
    return r
end

return M
