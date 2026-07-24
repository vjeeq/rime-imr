-- 优先级排序。不影响词频记录。
-- 支持多组 × 4 种匹配模式，支持多字优先项。
-- 规则按数组顺序执行（串联）：每组只排序匹配自己的候选，
-- 非匹配项原位不动，组间不交叉。
--
-- 配置：
--   order:
--     - words: ['他','她','它']
--       type: contains      # 左右模糊
--     - words: ['那', '哪']
--       type: starts_with   # 右模糊 ( 那个 > 哪个, 避免 ...那X 一定 > ...哪X (可能语言模型会给出更准全的选项?) )
--     - words: ['的', '地', '得']
--       type: ends_with     # 左模糊 ( XX的 > XX地 > XX得, 避免 XX的YY 一定 > XX地YY (可能语言模型会给出更准全的选项?) )
--     - words: ['哥伦比娅', '哥伦比亚']
--       type: exact         # 精准 ( 避免 '哥伦比娅大学' > '哥伦比亚大学' )
--
-- 默认：{ words = {"他", "她", "它"}, type = "contains" }

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
-- 后面规则先做。组内：遍历每个 word 的出现位置作锚点，
-- 从后往前比 better words，逐级拉高优同 rest 项到锚前。
local function sort_one_group(group, items)
    for wi = #group.words, 2, -1 do
        local anchor = 1
        while anchor <= #items do
            if match_word(group.typ, items[anchor], group.words[wi]) then
                local anchor_rest = strip_group(group, items[anchor])
                for bi = 1, wi - 1 do
                    local found = nil
                    for i = anchor + 1, #items do
                        if match_word(group.typ, items[i], group.words[bi])
                           and strip_group(group, items[i]) == anchor_rest then
                            found = i
                            break
                        end
                    end
                    if found then
                        local new_items = {}
                        for i = 1, anchor - 1 do table.insert(new_items, items[i]) end
                        table.insert(new_items, items[found])
                        for i = anchor, #items do
                            if i ~= found then table.insert(new_items, items[i]) end
                        end
                        items = new_items
                        anchor = anchor + 1
                    end
                end
            end
            anchor = anchor + 1
        end
    end
    return items
end

-- ── Rime filter ──
local M = {}

function M.init(env)
    local config = env.engine.schema.config
    local top = config:get_list("order")
    if top == nil then
        M.groups = { { words = { "他", "她", "它" }, typ = "contains" } }
        return
    end
    M.groups = {}
    local i = 0
    while true do
        local base = "order/@" .. i
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
        local l = utf8.len(cand.text)

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
