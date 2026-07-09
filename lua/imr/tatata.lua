-- 多字词首字优先级排序。不影响词频记录。
--
-- 让 "x他x" "x她x" "x它x" 保持 "他" "她" "它" 的顺序
--
-- 全词扫描：词中任一字符在优先级列表内就参与排序。
-- 按 rest（去掉优先字符后剩余部分）分组，组内 rank 低者在前。
-- 不配则默认 "他她它"；配则覆盖：tatata: ["他她它"]

local M = {}

local function rank(pri, ch)
    for i, c in ipairs(pri) do if ch == c then return i end end
    return 0
end

-- 词中最优先字符的 rank；无命中的返回 0
local function best_rank(pri, s)
    local best = 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local r = rank(pri, ch)
        if r > 0 and (best == 0 or r < best) then best = r end
    end
    return best
end

-- 词中去掉第一个 rank==target 的字符，返回余下部分
local function rest(s, target, pri)
    local out = {}
    local found = false
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if not found and rank(pri, ch) == target then found = true
        else table.insert(out, ch) end
    end
    return table.concat(out)
end

local function word_len(s)
    local n = 0
    for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end

function M.init(env)
    M.engine = env.engine
    local list = env.engine.schema.config:get_list("tatata")
    local str = list and list.size > 0 and list:get_at(0)
    str = str and str:get_value()
    str = (str and str:get_string()) or "他她它"
    M.pri = {}
    for c in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(M.pri, c)
    end
end

function M.func(input)
    local pri = M.pri
    local it = input:iter()
    local buf, n = {}, 0

    local function bk(i) return best_rank(pri, buf[i].text) end
    local function br(i) return rest(buf[i].text, bk(i), pri) end

    -- 冲刷缓冲区
    local function flush()
        if n == 0 then return end

        if bk(1) == 0 then
            -- 非优先打头：全体优先项按 rest 分组、组内排序，组在首次出现处全部输出
            local groups, owner = {}, {}
            for i = 1, n do
                local r = bk(i)
                if r > 0 and word_len(buf[i].text) >= 2 then
                    local rs = br(i); owner[i] = rs
                    if not groups[rs] then groups[rs] = {} end
                    table.insert(groups[rs], {c = buf[i], r = r})
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
        else
            -- 优先项打头：提取 rank 更高的同 rest 项提到最前面，
            -- 余下同 rest 项内部按 rank 交换（不跨非优先项）
            local trigger_rest = br(1)
            local higher = {}
            for i = 1, n do
                local r = bk(i)
                if r > 0 and r < bk(1) and word_len(buf[i].text) >= 2 and br(i) == trigger_rest then
                    table.insert(higher, {c = buf[i], r = r}); buf[i] = nil
                end
            end
            table.sort(higher, function(a, b) return a.r < b.r end)
            -- 压缩空洞
            local cpt = {}
            for i = 1, n do if buf[i] then table.insert(cpt, buf[i]) end end
            buf, n = cpt, #cpt
            -- 同 rest 内部冒泡排序
            for i = 1, n do
                local ri = bk(i)
                if ri > 0 and word_len(buf[i].text) >= 2 and br(i) == trigger_rest then
                    for j = i + 1, n do
                        local rj = bk(j)
                        if rj > 0 and word_len(buf[j].text) >= 2 and br(j) == trigger_rest and ri > rj then
                            buf[i], buf[j] = buf[j], buf[i]; break
                        end
                    end
                end
            end
            for _, x in ipairs(higher) do yield(x.c) end
            for i = 1, n do yield(buf[i]) end
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
