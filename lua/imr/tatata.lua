-- 多字词首字优先级排序。不影响词频记录。
-- 保持 "x他x" "x她x" "x它x" 按 "他" "她" "它" 的顺序排列。
--
-- 用法：在 schema 的 filters 中添加：
--       lua_filter@*imr.tatata
--
-- 配置：tatata: ["他她它"]  或默认 "他她它"

local M = {}

local function utf8_chars(s)
    local t = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(t, ch)
    end
    return t
end

local function char_rank(pri, ch)
    for i, c in ipairs(pri) do if ch == c then return i end end
    return 0
end

local function best_rank(pri, s)
    local best = 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local r = char_rank(pri, ch)
        if r > 0 and (best == 0 or r < best) then best = r end
    end
    return best
end

local function strip_priority(s, target, pri)
    local out = {}
    local found = false
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if not found and char_rank(pri, ch) == target then found = true
        else table.insert(out, ch) end
    end
    return table.concat(out)
end

local function word_len(s)
    return #utf8_chars(s)
end

function M.init(env)
    M.engine = env.engine
    local list = env.engine.schema.config:get_list("tatata")
    local item = list and list.size > 0 and list:get_at(0)
    local val  = item and item:get_value()
    local str  = (val and val:get_string()) or "他她它"
    M.pri = {}
    for c in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(M.pri, c)
    end
end

-- 非优先项打头：全体优先项按 rest 分组排序，各组在首次出现处全部输出
local function flush_non_head(buf, n, pri)
    local groups, owner = {}, {}
    for i = 1, n do
        local r = best_rank(pri, buf[i].text)
        if r > 0 and word_len(buf[i].text) >= 2 then
            local rs = strip_priority(buf[i].text, r, pri)
            owner[i] = rs
            if not groups[rs] then groups[rs] = {} end
            table.insert(groups[rs], { c = buf[i], r = r })
        end
    end
    for _, g in pairs(groups) do
        table.sort(g, function(a, b) return a.r < b.r end)
    end
    local done = {}
    for i = 1, n do
        local rs = owner[i]
        if rs then
            if not done[rs] then done[rs] = true; for _, x in ipairs(groups[rs]) do yield(x.c) end end
        else
            yield(buf[i])
        end
    end
end

-- 优先项打头：提取 rank 更高的同 rest 项提到最前面，同 rest 内部按 rank 冒泡
local function flush_head(buf, n, pri)
    local trigger_rest = strip_priority(buf[1].text, best_rank(pri, buf[1].text), pri)
    local higher = {}
    for i = 1, n do
        local r = best_rank(pri, buf[i].text)
        if r > 0 and r < best_rank(pri, buf[1].text) and word_len(buf[i].text) >= 2
            and strip_priority(buf[i].text, r, pri) == trigger_rest then
            table.insert(higher, { c = buf[i], r = r })
            buf[i] = nil
        end
    end
    table.sort(higher, function(a, b) return a.r < b.r end)
    local compact = {}
    for i = 1, n do if buf[i] then table.insert(compact, buf[i]) end end
    buf, n = compact, #compact
    for i = 1, n do
        local ri = best_rank(pri, buf[i].text)
        if ri > 0 and word_len(buf[i].text) >= 2
            and strip_priority(buf[i].text, ri, pri) == trigger_rest then
            for j = i + 1, n do
                local rj = best_rank(pri, buf[j].text)
                if rj > 0 and word_len(buf[j].text) >= 2
                    and strip_priority(buf[j].text, rj, pri) == trigger_rest and ri > rj then
                    buf[i], buf[j] = buf[j], buf[i]; break
                end
            end
        end
    end
    for _, x in ipairs(higher) do yield(x.c) end
    for i = 1, n do yield(buf[i]) end
end

function M.func(input)
    local pri = M.pri
    local it = input:iter()
    local buf, n = {}, 0

    local function flush()
        if n == 0 then return end
        if best_rank(pri, buf[1].text) == 0 then
            flush_non_head(buf, n, pri)
        else
            flush_head(buf, n, pri)
        end
        n = 0
    end

    while true do
        local cand = it(input)
        if not cand then break end

        local r = best_rank(pri, cand.text)
        local l = word_len(cand.text)

        if l < 2 then
            if n == 0 then yield(cand) else n = n + 1; buf[n] = cand end
        elseif r == 0 then
            if n == 0 then yield(cand) else n = n + 1; buf[n] = cand end
        else
            n = n + 1; buf[n] = cand
        end
        if n >= 5 then flush() end
    end
    flush()
end

return M
