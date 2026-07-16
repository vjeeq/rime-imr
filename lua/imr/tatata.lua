-- 多字词首字优先级排序。不影响词频记录。
-- 支持多组 × 4 种匹配模式，支持多字优先项。
-- 规则按数组顺序执行（串联）：每组只排序匹配自己的候选，
-- 非匹配项原位不动，组间不交叉。
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
local function word_len(s)
    local n = 0
    for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
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
-- 从 text 中去掉该组所有匹配过的 word，返回 rest
local function strip_group(group, text)
    local typ = group.typ
    if typ == "contains" then
        local r = text
        for _, w in ipairs(group.words) do
            local pos = r:find(w, 1, true)
            while pos do
                r = r:sub(1, pos - 1) .. r:sub(pos + #w)
                pos = r:find(w, 1, true)
            end
        end
        return r
    elseif typ == "starts_with" then
        for _, w in ipairs(group.words) do
            if text:sub(1, #w) == w then return text:sub(#w + 1) end
        end
    elseif typ == "ends_with" then
        for _, w in ipairs(group.words) do
            if text:sub(-#w) == w then return text:sub(1, -(#w + 1)) end
        end
    elseif typ == "exact" then
        return ""
    end
    return text
end

-- ── 串联：一组排序 ──
-- 后面规则先做。组内：从差优先到好优先，锚点往后扫，更高优同 rest 拉到头前。
local function sort_one_group(group, items)
    for wi = #group.words, 2, -1 do
        local anchor = nil
        for i = 1, #items do
            if match_word(group.typ, items[i], group.words[wi]) then
                anchor = i
                break
            end
        end
        if not anchor then goto continue end
        local anchor_rest = strip_group(group, items[anchor])

        local pulled, tail = {}, {}
        for i = anchor + 1, #items do
            local better = false
            for bi = 1, wi - 1 do
                if match_word(group.typ, items[i], group.words[bi]) then
                    better = true; break
                end
            end
            if better and strip_group(group, items[i]) == anchor_rest then
                table.insert(pulled, items[i])
            else
                table.insert(tail, items[i])
            end
        end

        local new_items = {}
        for i = 1, anchor - 1 do table.insert(new_items, items[i]) end
        for _, v in ipairs(pulled) do table.insert(new_items, v) end
        table.insert(new_items, items[anchor])
        for _, v in ipairs(tail) do table.insert(new_items, v) end
        items = new_items

        ::continue::
    end
    return items
end

-- ── Rime filter ──
local M = {}

function M.init(env)
    local config = env.engine.schema.config
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

-- 候选是否命中任一 group
local function hit_any(groups, text)
    for _, g in ipairs(groups) do
        for _, w in ipairs(g.words) do
            if match_word(g.typ, text, w) then return true end
        end
    end
    return false
end

function M.func(input, env)
    local groups = M.groups
    local it = input:iter()
    local buf, n = {}, 0

    local function flush()
        if n == 0 then return end
        -- 提取 texts，逐组串行排序
        local texts = {}
        local by_text = {}
        for i = 1, n do
            local t = buf[i].text
            texts[i] = t
            by_text[t] = buf[i]
        end
        for gi = #groups, 1, -1 do
            texts = sort_one_group(groups[gi], texts)
        end
        for _, t in ipairs(texts) do
            yield(by_text[t])
        end
        n = 0
    end

    while true do
        local cand = it(input)
        if not cand then break end

        local hit = hit_any(groups, cand.text)
        local l = word_len(cand.text)

        if hit and l >= 2 then
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
