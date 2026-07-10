local convert = require("imr.hub._util").convert
local digits = require("imr.hub._util").digits

local month_names_short = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local month_names_long = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December" }

local M = {}
local keys = {}

function M.setup(config, prefix)
    keys.date = config:get_string(prefix .. "/date") or "date"
    keys.time = config:get_string(prefix .. "/time") or "time"
    keys.week = config:get_string(prefix .. "/week") or "week"
    keys.datetime = config:get_string(prefix .. "/datetime") or "datetime"
    keys.timestamp = config:get_string(prefix .. "/timestamp") or "timestamp"
    keys.date_zh = config:get_string(prefix .. "/datezh") or "datezh"
    keys.date_en = config:get_string(prefix .. "/dateen") or "dateen"
end

function M.match(input)
    for _, v in pairs(keys) do
        if input == v then return true end
    end
    return false
end

function M.translate(input, seg)
    local t = os.time()
    local r = {}
    local k = keys

    if input == k.date then
        table.insert(r, { os.date("%Y-%m-%d", t) })
        table.insert(r, { os.date("%Y/%m/%d", t) })
        table.insert(r, { os.date("%Y.%m.%d", t) })
        table.insert(r, { os.date("%Y%m%d", t) })
        table.insert(r, { string.gsub(string.gsub(os.date("%Y年%m月%d日", t), "年0", "年"), "月0", "月") })

    elseif input == k.time then
        local h = tonumber(os.date("%H", t))
        local period
        if h >= 5 and h < 11 then period = "早上"
        elseif h >= 11 and h < 13 then period = "中午"
        elseif h >= 13 and h < 18 then period = "下午"
        elseif h >= 18 and h < 24 then period = "晚上"
        else period = "凌晨" end
        table.insert(r, { os.date("%H:%M", t) })
        table.insert(r, { os.date("%H:%M:%S", t) })
        table.insert(r, { period .. " " .. os.date("%I:%M", t) })
        table.insert(r, { os.date("%I:%M %p", t) })

    elseif input == k.week then
        local wk = { "日", "一", "二", "三", "四", "五", "六" }
        local w = wk[tonumber(os.date("%w", t) + 1)]
        table.insert(r, { "星期" .. w })
        table.insert(r, { "礼拜" .. w })
        table.insert(r, { "周" .. w })

    elseif input == k.datetime then
        local tz = os.date("%z", t)
        local iso_tz = (tz == "+0000" or tz == "-0000") and "Z" or string.gsub(tz, "(%d%d)$", ":%1")
        table.insert(r, { os.date("%Y-%m-%dT%H:%M:%S", t) .. iso_tz })
        table.insert(r, { os.date("%Y-%m-%d %H:%M:%S", t) })
        table.insert(r, { os.date("%Y%m%d%H%M%S", t) })

    elseif input == k.timestamp then
        table.insert(r, { string.format("%d", t) })

    elseif input == k.date_zh then
        local yo = digits(tonumber(os.date("%Y", t)), true)
        local yz = digits(tonumber(os.date("%Y", t)), false)
        local m = convert(tonumber(os.date("%m", t)))
        local d = convert(tonumber(os.date("%d", t)))
        table.insert(r, { string.format("%s年%s月%s日", yo, m, d) })
        table.insert(r, { string.format("%s年%s月%s日", yz, m, d) })
        table.insert(r, { string.gsub(string.gsub(os.date("%Y年%m月%d日", t), "年0", "年"), "月0", "月") })

    elseif input == k.date_en then
        local day = tonumber(os.date("%d", t))
        local month = tonumber(os.date("%m", t))
        local year = os.date("%Y", t)
        table.insert(r, { string.format("%d %s %s", day, month_names_long[month], year) })
        table.insert(r, { string.format("%s %d, %s", month_names_long[month], day, year) })
    end

    return r
end

return M
