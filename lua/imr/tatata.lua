-- tatata — 多字词首字优先级排序。
-- 让 "他x" "她x" "它x" 保持 "他" "她" "它" 的顺序
-- 不影响词频记录，仅在显示时把"他说"排在"她说"前面。
--
-- 机制：
--   候选首字命中优先级列表（rank>1）时，向前 lookahead 最多 5 个候选，
--   找 rest（去掉首字后其余部分）相同且 rank 更小的词，提到前面。
--   单字（len<2）不参与 lookahead。非匹配候选保持词频原序。
--
-- 配置（imr_DPY.schema.yaml）：
--   tatata:
--     ta: "他她它"        # 默认已有，可覆盖
--     ui: "是时事"       # 可选

local M = {}

-- 默认优先级，不配 tatata: 也能直接用 ta
local DEFAULTS = {
    ta = {"他", "她", "它"},
}

function M.init(env)
    M.engine = env.engine
    M.pri = {}
    for k, v in pairs(DEFAULTS) do
        M.pri[k] = {}
        for _, c in ipairs(v) do table.insert(M.pri[k], c) end
    end
    local config = env.engine.schema.config
    local map = config:get_map("tatata")
    if map then
        for _, key in ipairs(map:keys()) do
            local str = map:get_value(key)
            if str then
                local s = str:get_string()
                if s and #s > 0 then
                    local chars = {}
                    for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                        table.insert(chars, c)
                    end
                    if #chars > 0 then M.pri[key] = chars end
                end
            end
        end
    end
end

-- 工具函数
local function rank(pri, ch)
    for i, c in ipairs(pri) do if ch == c then return i end end
    return 0
end

local function first(s)  -- 首字
    return s:match("[%z\1-\127\194-\244][\128-\191]*") or ""
end

local function rest(s)   -- 去掉首字后的剩余部分（用于严格匹配）
    local f = first(s)
    if f == "" or #f >= #s then return "" end
    return s:sub(#f + 1)
end

local function text_len(s)  -- UTF-8 字数
    local n = 0
    for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end

function M.func(input)
    local code = M.engine.context.input or ""
    local pri = nil
    for k, v in pairs(M.pri) do
        if code:sub(1, #k) == k then pri = v; break end
    end
    if not pri then
        for cand in input:iter() do yield(cand) end
        return
    end

    local it = input:iter()
    local buf, buf_n = {}, 0

    local function buf_rank(i) return rank(pri, first(buf[i].text)) end
    local function buf_len(i)  return text_len(buf[i].text) end
    local function buf_rest(i) return rest(buf[i].text) end

    -- 冲刷缓冲区：找出 rest 相同且 rank 更小的，提到前面
    local function flush()
        if buf_n == 0 then return end
        local trigger_r = buf_rank(1)
        local trigger_rest = buf_rest(1)
        local higher, rest_items = {}, {}
        for i = 1, buf_n do
            local r = buf_rank(i)
            if r > 0 and r < trigger_r and buf_len(i) >= 2 and buf_rest(i) == trigger_rest then
                table.insert(higher, {cand = buf[i], rank = r})
            else
                table.insert(rest_items, buf[i])
            end
        end
        table.sort(higher, function(a, b) return a.rank < b.rank end)
        for _, item in ipairs(higher) do yield(item.cand) end
        for _, cand in ipairs(rest_items) do yield(cand) end
        buf_n = 0
    end

    while true do
        local cand = it(input)
        if not cand then break end

        local r = rank(pri, first(cand.text))
        local l = text_len(cand.text)

        -- rank≤1（最高优先/非匹配）或单字 → 无活跃缓冲则直接出
        if r <= 1 or l < 2 then
            if buf_n == 0 then
                yield(cand)
            else
                buf_n = buf_n + 1; buf[buf_n] = cand
                if buf_n >= 5 then flush() end
            end
        else
            -- rank>1 的多字词 → 启动/继续 lookahead
            if buf_n == 0 then
                buf_n = 1; buf[1] = cand
            else
                buf_n = buf_n + 1; buf[buf_n] = cand
            end
            if buf_n >= 5 then flush() end
        end
    end
    flush()
end

return M
