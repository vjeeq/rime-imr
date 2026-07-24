-- Test for order_filter.lua core functions
-- Run: lua test\order_filter_test.lua

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

local function hit_any(groups, text)
    for _, g in ipairs(groups) do
        for _, w in ipairs(g.words) do
            if match_word(g.typ, text, w) then return true end
        end
    end
    return false
end

local function process(candidates, groups)
    local result = {}
    local buf, n = {}, 0

    local function flush()
        if n == 0 then return end
        local texts = {}
        for i = 1, n do texts[i] = buf[i] end
        for gi = #groups, 1, -1 do
            texts = sort_one_group(groups[gi], texts)
        end
        for _, t in ipairs(texts) do
            result[#result + 1] = t
        end
        n = 0
    end

    for _, text in ipairs(candidates) do
        local hit = hit_any(groups, text)
        local l = utf8.len(text)
        if hit and l >= 2 then
            n = n + 1; buf[n] = text
        elseif n == 0 then
            result[#result + 1] = text
        else
            n = n + 1; buf[n] = text
        end
        if n >= 5 then flush() end
    end
    flush()
    return result
end

local tests = {
    { name = "c1. 她-踏-他",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她是", "踏实", "他是" },
        expected = { "他是", "她是", "踏实" } },
    { name = "c2. 他已在前面（不动）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他是", "踏实", "她是", "它是" },
        expected = { "他是", "踏实", "她是", "它是" } },
    { name = "c3. 它-踏-她-他",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "它是", "踏实", "她是", "他是" },
        expected = { "他是", "她是", "它是", "踏实" } },
    { name = "c4. lookahead 超5",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她是", "A", "B", "C", "D", "E", "他是" },
        expected = { "她是", "A", "B", "C", "D", "E", "他是" } },
    { name = "c5. 他们说（rest分组）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她说", "他做", "它说", "他说" },
        expected = { "他说", "她说", "他做", "它说" } },
    { name = "c6. 把ta（在第二音节）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "把它", "把他", "把她" },
        expected = { "把他", "把她", "把它" } },
    { name = "c7. 他们它们她们 + 大门",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他们", "它们", "她们", "大门" },
        expected = { "他们", "她们", "它们", "大门" } },
    { name = "c8. 有前缀（去X）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "去她是", "去踏实", "去他是" },
        expected = { "去他是", "去她是", "去踏实" } },
    { name = "c9. 有前缀3字",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "去它是", "去踏实", "去她是", "去他是" },
        expected = { "去他是", "去她是", "去它是", "去踏实" } },
    { name = "c10. 同字多次出现",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "它是", "它的", "她的", "他的" },
        expected = { "它是", "他的", "她的", "它的" } },
    { name = "s1. 那个人-哪个人",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "哪个人", "那个人", "别的" },
        expected = { "那个人", "哪个人", "别的" } },
    { name = "s2. 那在第一位（不动）",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "那个人", "哪个人" },
        expected = { "那个人", "哪个人" } },
    { name = "s3. 那不在词首（不匹配）",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "看那个", "瞧哪个" },
        expected = { "看那个", "瞧哪个" } },
    { name = "s4. 那组 + 单字混排",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "哪", "那个", "哪个", "那" },
        expected = { "哪", "那个", "哪个", "那" } },
    { name = "e1. 的你-的妳",
        groups = { { words = { "你", "妳" }, typ = "ends_with" } },
        candidates = { "的妳", "的你", "算了" },
        expected = { "的你", "的妳", "算了" } },
    { name = "e2. 你在第一位（不匹配ends_with）",
        groups = { { words = { "你", "妳" }, typ = "ends_with" } },
        candidates = { "你的", "妳的" },
        expected = { "你的", "妳的" } },
    { name = "x1. 单字不参与排序",
        groups = { { words = { "他", "她", "它" }, typ = "exact" } },
        candidates = { "她", "他", "它" },
        expected = { "她", "他", "它" } },
    { name = "x2. 含他/她的多字词",
        groups = { { words = { "他", "她" }, typ = "exact" } },
        candidates = { "他来了", "她来了" },
        expected = { "他来了", "她来了" } },
    { name = "mw1. 双字starts_with",
        groups = { { words = { "那个", "哪个" }, typ = "starts_with" } },
        candidates = { "哪个人", "那个人", "别的" },
        expected = { "那个人", "哪个人", "别的" } },
    { name = "mw2. 双字contains",
        groups = { { words = { "他们", "她们" }, typ = "contains" } },
        candidates = { "她们在", "他们在", "别人" },
        expected = { "他们在", "她们在", "别人" } },
    { name = "mw3. 双字ends_with",
        groups = { { words = { "我的", "你的" }, typ = "ends_with" } },
        candidates = { "看你的", "看我的", "他来了" },
        expected = { "看我的", "看你的", "他来了" } },
    { name = "mw4. 那个-哪个 exact",
        groups = { { words = { "那个", "哪个" }, typ = "exact" } },
        candidates = { "那个", "哪个" },
        expected = { "那个", "哪个" } },
    { name = "mw5. 多字starts_with",
        groups = { { words = { "那个", "哪" }, typ = "starts_with" } },
        candidates = { "那个人", "那个谁", "哪个人" },
        expected = { "那个人", "那个谁", "哪个人" } },
    { name = "m1. contains + starts_with",
        groups = { { words = { "他", "她", "它" }, typ = "contains" }, { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "她是", "哪个人", "踏实", "那个人", "他是" },
        expected = { "他是", "她是", "那个人", "哪个人", "踏实" } },
    { name = "m2. contains + 跨组不干扰",
        groups = { { words = { "他", "她", "它" }, typ = "contains" }, { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "哪个人", "踏实", "那个人", "她是", "他是" },
        expected = { "那个人", "哪个人", "踏实", "他是", "她是" } },
    { name = "m3. contains + starts_with + ends_with",
        groups = { { words = { "他", "她", "它" }, typ = "contains" }, { words = { "那", "哪" }, typ = "starts_with" }, { words = { "你", "妳" }, typ = "ends_with" } },
        candidates = { "哪个人", "踏实", "那个人", "她来了", "他来了", "你好", "妳好" },
        expected = { "那个人", "哪个人", "踏实", "他来了", "她来了", "你好", "妳好" } },
    { name = "m4. 多字starts_with + 单字contains混合",
        groups = { { words = { "那个", "哪个" }, typ = "starts_with" }, { words = { "他", "她" }, typ = "contains" } },
        candidates = { "哪个人", "她是", "那个人", "他是" },
        expected = { "那个人", "哪个人", "他是", "她是" } },
    { name = "m5. contains组先抢走匹配 + starts_with后处理",
        groups = { { words = { "他", "她" }, typ = "contains" }, { words = { "那个", "哪个" }, typ = "starts_with" } },
        candidates = { "哪个里", "那里", "她那里", "他那里", "那个人" },
        expected = { "哪个里", "那里", "他那里", "她那里", "那个人" } },
    { name = "m6. 跨组冲突",
        groups = { { words = { "他", "她" }, typ = "contains" }, { words = { "那边", "这边" }, typ = "starts_with" } },
        candidates = { "这边走", "那边走", "他那边", "她这边", "他们走" },
        expected = { "那边走", "这边走", "他那边", "她这边", "他们走" } },
    { name = "edge1. 空优先组",
        groups = {}, candidates = { "他是", "她是", "它是" },
        expected = { "他是", "她是", "它是" } },
    { name = "edge2. 空候选",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = {}, expected = {} },
    { name = "edge3. 全单字候选",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他", "她", "它" }, expected = { "他", "她", "它" } },
    { name = "edge4. 优先字不在 group",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "那谁", "哪谁" }, expected = { "那谁", "哪谁" } },
    { name = "edge5. 旧兼容：字符串格式",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她是", "踏实", "他是" }, expected = { "他是", "她是", "踏实" } },
}

local passed, failed = 0, 0
for _, test in ipairs(tests) do
    local result = process(test.candidates, test.groups)
    local ok = #result == #test.expected
    if ok then
        for i = 1, #result do
            if result[i] ~= test.expected[i] then ok = false; break end
        end
    end
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print(("FAIL: %s"):format(test.name))
        print(("  got:      %s"):format(table.concat(result, " | ")))
        print(("  expected: %s"):format(table.concat(test.expected, " | ")))
    end
end
print(("===== %d passed, %d failed ====="):format(passed, failed))
if failed > 0 then os.exit(1) end
