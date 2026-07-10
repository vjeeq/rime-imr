local M = {}

local calcPlugin = {
    e = math.exp(1),
    pi = math.pi,
}

local function random(...) return math.random(...) end
calcPlugin["rdm"] = random
calcPlugin["random"] = random

calcPlugin["sin"] = function(x) return math.sin(x) end
calcPlugin["sinh"] = function(x) return math.sinh(x) end
calcPlugin["asin"] = function(x) return math.asin(x) end
calcPlugin["cos"] = function(x) return math.cos(x) end
calcPlugin["cosh"] = function(x) return math.cosh(x) end
calcPlugin["acos"] = function(x) return math.acos(x) end
calcPlugin["tan"] = function(x) return math.tan(x) end
calcPlugin["tanh"] = function(x) return math.tanh(x) end
calcPlugin["atan"] = function(x) return math.atan(x) end
calcPlugin["atan2"] = function(y, x) return math.atan2(y, x) end
calcPlugin["deg"] = function(x) return math.deg(x) end
calcPlugin["rad"] = function(x) return math.rad(x) end
calcPlugin["ldexp"] = function(x, y) return math.ldexp(x, y) end
calcPlugin["exp"] = function(x) return math.exp(x) end
calcPlugin["sqrt"] = function(x) return math.sqrt(x) end
calcPlugin["log"] = function(y, x)
    if x <= 0 or y <= 0 then return nil end
    return math.log(x) / math.log(y)
end
calcPlugin["loge"] = function(x)
    if x <= 0 then return nil end
    return math.log(x)
end
calcPlugin["log10"] = function(x)
    if x <= 0 then return nil end
    return math.log10(x)
end
calcPlugin["avg"] = function(...)
    local data = { ... }
    local n = #data
    if n == 0 then return nil end
    local sum = 0
    for _, v in ipairs(data) do sum = sum + v end
    return sum / n
end
calcPlugin["var"] = function(...)
    local data = { ... }
    local n = #data
    if n == 0 then return nil end
    local sum = 0
    for _, v in ipairs(data) do sum = sum + v end
    local mean = sum / n
    local ssd = 0
    for _, v in ipairs(data) do ssd = ssd + (v - mean) ^ 2 end
    return ssd / n
end
calcPlugin["fact"] = function(x)
    if x < 0 then return nil end
    if x == 0 or x == 1 then return 1 end
    local result = 1
    for i = 1, x do result = result * i end
    return result
end
calcPlugin["frexp"] = function(x)
    local m, e = math.frexp(x)
    return m .. " * 2^" .. e
end

function M.setup(config, prefix)
    M.prefix = config:get_string(prefix) or "cC"
end

function M.match(input)
    return string.sub(input, 1, string.len(M.prefix)) == M.prefix
end

function M.translate(input, seg)
    local r = {}
    local express = string.sub(input, string.len(M.prefix) + 1)
    if express == "" then return r end
    express = string.gsub(express, " ", "")
    local code = string.gsub(express, "([0-9]+)!", "fact(%1)")
    code = code .. " "
    code = string.gsub(code, "(%b())%%(%D)", function(block, tail) return "(" .. block .. "/100)" .. tail end)
    code = string.gsub(code, "(%d+%.?%d*)%%(%D)", function(num, tail) return "(" .. num .. "/100)" .. tail end)
    code = string.sub(code, 1, -2)
    local fn = load("return " .. code, "calculate", "t", calcPlugin)
    if not fn then
        r[#r + 1] = { express, 99999, "解析失败" }
        return r
    end
    local success, result = pcall(fn)
    if success and result and (type(result) == "string" or type(result) == "number") and #tostring(result) > 0 then
        r[#r + 1] = { result, 99999 }
        r[#r + 1] = { express .. "=" .. result, 99999 }
    else
        r[#r + 1] = { express, 99999, "解析失败" }
    end
    return r
end

return M
