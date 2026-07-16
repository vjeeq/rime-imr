-- 多字词首字优先级排序。不影响词频记录。
-- 支持多组 × 4 种匹配模式，支持多字优先项。
--
-- 配置：
--   tatata:
--     - words: ['他','她','它']
--       type: contains      # 左右模糊
--     - words: ['那个','哪个']
--       type: starts_with   # 右模糊
--     - words: ['你','妳']
--       type: ends_with     # 左模糊
--     - words: ['他']
--       type: exact         # 精准
--
-- 默认：{ words = {"他", "她", "它"}, type = "contains" }

-- ── UTF-8 ──
local function utf8_chars(s)
    local t = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(t, ch)
    end
    return t
end

local function word_len(s)
    return #utf8_chars(s)
end

-- ── Match (byte-level, supports multi-char words) ──
local function match_word(typ, text, word)
    if typ == "contains" then
        return text:find(word, 1, true) ~= nil
    elseif typ == "starts_with" then
        return text:sub(1, #word) == word
    elseif typ == "ends_with" then
        return text:sub(-#word) == word
    elseif typ == "exact" then
        return text == word
    end
    return false
end

-- ── Strip ──
-- contains: 去掉文本中所有该组的 word
-- starts_with / ends_with / exact: 去匹配位置
local function strip_word(groups, group_idx, text)
    local g = groups[group_idx]
    local typ = g.typ

    if typ == "contains" then
        local r = text
        for _, w in ipairs(g.words) do
            local pos = r:find(w, 1, true)
            while pos do
                r = r:sub(1, pos - 1) .. r:sub(pos + #w)
                pos = r:find(w, 1, true)
            end
        end
        return r
    elseif typ == "starts_with" then
        for _, w in ipairs(g.words) do
            if text:sub(1, #w) == w then return text:sub(#w + 1) end
        end
        local c = utf8_chars(text)
        if #c >= 1 then table.remove(c, 1) end
        return table.concat(c)
    elseif typ == "ends_with" then
        for _, w in ipairs(g.words) do
            if text:sub(-#w) == w then return text:sub(1, -(#w + 1)) end
        end
        local c = utf8_chars(text)
        if #c >= 1 then table.remove(c) end
        return table.concat(c)
    elseif typ == "exact" then
        return ""
    end
    return text
end

-- ── Rank ──
-- 返回 group_idx, word_idx（数字越小越优先）
local function best_rank(groups, text)
    for group_idx = 1, #groups do
        local g = groups[group_idx]
        for word_idx = 1, #g.words do
            if match_word(g.typ, text, g.words[word_idx]) then
                return group_idx, word_idx
            end
        end
    end
    return nil
end

-- ── Sort by groups ──
local function sort_by_groups(groups, items)
    local n = #items
    if n == 0 then return {} end

    local rank_of = {}
    for i = 1, n do
        local gid, wid = best_rank(groups, items[i])
        if gid then
            local rs = strip_word(groups, gid, items[i])
            local key = gid .. "|" .. rs
            if not rank_of[key] then rank_of[key] = {} end
            rank_of[key][i] = wid
        end
    end

    local result = {}
    for i = 1, n do result[i] = items[i] end

    for _, pos_map in pairs(rank_of) do
        local entries = {}
        for pos, rank in pairs(pos_map) do
            table.insert(entries, { pos = pos, text = result[pos], rank = rank })
        end
        table.sort(entries, function(a, b) return a.rank < b.rank end)
        local sorted_pos = {}
        for _, e in ipairs(entries) do table.insert(sorted_pos, e.pos) end
        table.sort(sorted_pos)
        for i, e in ipairs(entries) do
            result[sorted_pos[i]] = e.text
        end
    end

    return result
end

-- ── Rime filter ──
local M = {}

function M.init(env)
    local config = env.engine.schema.config
    -- 先查 tatata 键是否存在，区分「没写」和「写了空列表」
    local top = config:get_list("tatata")
    if top == nil then
        M.groups = { { words = { "他", "她", "它" }, typ = "contains" } }
        return
    end
    M.groups = {}
    local i = 0
    while true do
        local base = "tatata/@" .. i
        local wlist = config:get_list(base .. "/words")
        local words = {}
        if wlist and wlist.size > 0 then
            for j = 0, wlist.size - 1 do
                local v = wlist:get_value_at(j)
                local w = v and v.value
                if w and #w > 0 then table.insert(words, w) end
            end
        else
            local str = config:get_string(base .. "/words") or ""
            for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                table.insert(words, ch)
            end
        end
        if #words == 0 then break end
        local typ = config:get_string(base .. "/type") or "contains"
        table.insert(M.groups, { words = words, typ = typ })
        i = i + 1
    end
end

function M.func(input, env)
    local groups = M.groups
    local it = input:iter()
    local buf, n = {}, 0

    local function flush()
        if n == 0 then return end
        local texts = {}
        local by_text = {}
        for i = 1, n do
            local t = buf[i].text
            texts[i] = t
            by_text[t] = buf[i]
        end

        local head_gid, head_wid = best_rank(groups, texts[1])
        if head_gid then
            local trigger_rest = strip_word(groups, head_gid, texts[1])
            local higher, mark = {}, {}
            for i = 1, n do
                local gid, wid = best_rank(groups, texts[i])
                if gid and wid < head_wid then
                    local rs = strip_word(groups, gid, texts[i])
                    if gid == head_gid and rs == trigger_rest then
                        table.insert(higher, texts[i])
                        mark[i] = true
                    end
                end
            end

            local compact = {}
            for i = 1, n do
                if not mark[i] then table.insert(compact, texts[i]) end
            end

            compact = sort_by_groups(groups, compact)

            for _, t in ipairs(higher) do yield(by_text[t]) end
            for _, t in ipairs(compact) do yield(by_text[t]) end
        else
            local sorted = sort_by_groups(groups, texts)
            for _, t in ipairs(sorted) do yield(by_text[t]) end
        end
        n = 0
    end

    while true do
        local cand = it(input)
        if not cand then break end

        local gid = best_rank(groups, cand.text)
        local l = word_len(cand.text)

        if gid and l >= 2 then
            n = n + 1; buf[n] = cand
        elseif n == 0 then
            yield(cand)
        else
            n = n + 1; buf[n] = cand
        end
        if n >= 5 then flush() end
    end
    flush()
end

return M
