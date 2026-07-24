-- 单字前置。不影响词频记录。
-- pin 中的单字按顺序提到候选列表第一位（仅扫描前 10 个候选）。
--
-- 配置：
--   pin: ['吧', '呢']

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    local list = config:get_list("pin")
    M.words = {}
    M.lookup = {}
    if not list or list.size == 0 then return end

    for i = 0, list.size - 1 do
        local v = list:get_value_at(i)
        local w = v and v.value
        if w and #w > 0 then
            M.words[#M.words + 1] = w
            M.lookup[w] = true
        end
    end
end

function M.func(input, env)
    local words = M.words
    if #words == 0 then
        for cand in input:iter() do yield(cand) end
        return
    end

    local lookup = M.lookup
    local firsts = {}
    local rest = {}
    local it = input:iter()

    for _ = 1, 10 do
        local cand = it(input)
        if not cand then break end
        if lookup[cand.text] then
            firsts[cand.text] = cand
        else
            rest[#rest + 1] = cand
        end
    end

    for _, w in ipairs(words) do
        if firsts[w] then yield(firsts[w]) end
    end
    for _, c in ipairs(rest) do yield(c) end

    while true do
        local cand = it(input)
        if not cand then break end
        yield(cand)
    end
end

return M
