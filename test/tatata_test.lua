-- Test cases for tatata_core.lua
return {

    -- ═══════════ contains ═══════════
    {
        name = "c1. 她-踏-他",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她是", "踏实", "他是" },
        expected = { "他是", "她是", "踏实" },
    },
    {
        name = "c2. 他已在前面（不动）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他是", "踏实", "她是", "它是" },
        expected = { "他是", "踏实", "她是", "它是" },
    },
    {
        name = "c3. 它-踏-她-他",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "它是", "踏实", "她是", "他是" },
        expected = { "他是", "她是", "它是", "踏实" },
    },
    {
        name = "c4. lookahead 超5",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她是", "A", "B", "C", "D", "E", "他是" },
        expected = { "她是", "A", "B", "C", "D", "E", "他是" },
    },
    {
        name = "c5. 他们说（rest分组）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "她说", "他做", "它说", "他说" },
        expected = { "他说", "她说", "他做", "它说" },
    },
    {
        name = "c6. 把ta（在第二音节）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "把它", "把他", "把她" },
        expected = { "把他", "把她", "把它" },
    },
    {
        name = "c7. 他们它们她们 + 大门",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他们", "它们", "她们", "大门" },
        expected = { "他们", "她们", "它们", "大门" },
    },
    {
        name = "c8. 有前缀（去X）",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "去她是", "去踏实", "去他是" },
        expected = { "去他是", "去她是", "去踏实" },
    },
    {
        name = "c9. 有前缀3字",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "去它是", "去踏实", "去她是", "去他是" },
        expected = { "去他是", "去她是", "去它是", "去踏实" },
    },

    -- ═══════════ starts_with ═══════════
    {
        name = "s1. 那个人-哪个人",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "哪个人", "那个人", "别的" },
        expected = { "那个人", "哪个人", "别的" },
    },
    {
        name = "s2. 那在第一位（不动）",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "那个人", "哪个人" },
        expected = { "那个人", "哪个人" },
    },
    {
        name = "s3. 那不在词首（不匹配）",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "看那个", "瞧哪个" },
        expected = { "看那个", "瞧哪个" },
    },
    {
        name = "s4. 那组 + 单字混排",
        groups = { { words = { "那", "哪" }, typ = "starts_with" } },
        candidates = { "哪", "那个", "哪个", "那" },
        expected = { "哪", "那个", "哪个", "那" },
    },

    -- ═══════════ ends_with ═══════════
    {
        name = "e1. 的你-的妳",
        groups = { { words = { "你", "妳" }, typ = "ends_with" } },
        candidates = { "的妳", "的你", "算了" },
        expected = { "的你", "的妳", "算了" },
    },
    {
        name = "e2. 你在第一位（不匹配ends_with）",
        groups = { { words = { "你", "妳" }, typ = "ends_with" } },
        candidates = { "你的", "妳的" },
        expected = { "你的", "妳的" },
    },

    -- ═══════════ exact ═══════════
    {
        name = "x1. 他-她-它（单字不参与排序）",
        groups = { { words = { "他", "她", "它" }, typ = "exact" } },
        candidates = { "她", "他", "它" },
        expected = { "她", "他", "它" },
    },
    {
        name = "x2. 含他/她的多字词（exact不匹配）",
        groups = { { words = { "他", "她" }, typ = "exact" } },
        candidates = { "他来了", "她来了" },
        expected = { "他来了", "她来了" },
    },

    -- ═══════════ 多字词 ═══════════
    {
        name = "mw1. 那个人-哪个人（双字starts_with）",
        groups = { { words = { "那个", "哪个" }, typ = "starts_with" } },
        candidates = { "哪个人", "那个人", "别的" },
        expected = { "那个人", "哪个人", "别的" },
    },
    {
        name = "mw2. 他们-她们（双字contains）",
        groups = { { words = { "他们", "她们" }, typ = "contains" } },
        candidates = { "她们在", "他们在", "别人" },
        expected = { "他们在", "她们在", "别人" },
    },
    {
        name = "mw3. 我的-你的（双字ends_with）",
        groups = { { words = { "我的", "你的" }, typ = "ends_with" } },
        candidates = { "看你的", "看我的", "他来了" },
        expected = { "看我的", "看你的", "他来了" },
    },
    {
        name = "mw4. 那个-哪个 exact（精准不匹配多字词）",
        groups = { { words = { "那个", "哪个" }, typ = "exact" } },
        candidates = { "那个", "哪个" },
        expected = { "那个", "哪个" },
    },
    {
        name = "mw5. starts_with 多字（那个人 vs 那个谁）",
        groups = { { words = { "那个", "哪" }, typ = "starts_with" } },
        candidates = { "那个人", "那个谁", "哪个人" },
        expected = { "那个人", "那个谁", "哪个人" },
    },

    -- ═══════════ 多组混排 ═══════════
    {
        name = "m1. contains + starts_with",
        groups = {
            { words = { "他", "她", "它" }, typ = "contains" },
            { words = { "那", "哪" }, typ = "starts_with" },
        },
        candidates = { "她是", "哪个人", "踏实", "那个人", "他是" },
        expected = { "他是", "她是", "那个人", "哪个人", "踏实" },
    },
    {
        name = "m2. 同组contains + 跨组不干扰",
        groups = {
            { words = { "他", "她", "它" }, typ = "contains" },
            { words = { "那", "哪" }, typ = "starts_with" },
        },
        candidates = { "哪个人", "踏实", "那个人", "她是", "他是" },
        expected = { "那个人", "哪个人", "踏实", "他是", "她是" },
    },
    {
        name = "m3. contains + starts_with + ends_with",
        groups = {
            { words = { "他", "她", "它" }, typ = "contains" },
            { words = { "那", "哪" }, typ = "starts_with" },
            { words = { "你", "妳" }, typ = "ends_with" },
        },
        candidates = { "哪个人", "踏实", "那个人", "她来了", "他来了", "你好", "妳好" },
        expected = { "那个人", "哪个人", "踏实", "他来了", "她来了", "你好", "妳好" },
    },
    {
        name = "m4. 多字starts_with + 单字contains混合",
        groups = {
            { words = { "那个", "哪个" }, typ = "starts_with" },
            { words = { "他", "她" }, typ = "contains" },
        },
        candidates = { "哪个人", "她是", "那个人", "他是" },
        expected = { "那个人", "哪个人", "他是", "她是" },
    },
    {
        name = "m5. contains组先抢走匹配 + starts_with组后处理",
        groups = {
            { words = { "他", "她" }, typ = "contains" },
            { words = { "那个", "哪个" }, typ = "starts_with" },
        },
        candidates = { "哪个里", "那里", "她那里", "他那里", "那个人" },
        expected = { "哪个里", "那里", "他那里", "她那里", "那个人" },
    },
    {
        name = "m6. 跨组冲突：contains单字抢走多字starts_with",
        groups = {
            { words = { "他", "她" }, typ = "contains" },
            { words = { "那边", "这边" }, typ = "starts_with" },
        },
        candidates = { "这边走", "那边走", "他那边", "她这边", "他们走" },
        expected = { "那边走", "这边走", "他那边", "她这边", "他们走" },
    },

    -- ═══════════ 边界 ═══════════
    {
        name = "edge1. 空优先组",
        groups = {},
        candidates = { "他是", "她是", "它是" },
        expected = { "他是", "她是", "它是" },
    },
    {
        name = "edge2. 空候选",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = {},
        expected = {},
    },
    {
        name = "edge3. 全单字候选",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "他", "她", "它" },
        expected = { "他", "她", "它" },
    },
    {
        name = "edge4. 优先字不在 group 中",
        groups = { { words = { "他", "她", "它" }, typ = "contains" } },
        candidates = { "那谁", "哪谁" },
        expected = { "那谁", "哪谁" },
    },
    {
        name = "edge5. 旧兼容：字符串格式",
        groups = { { words = "他她它", typ = "contains" } },
        candidates = { "她是", "踏实", "他是" },
        expected = { "他是", "她是", "踏实" },
    },
}
