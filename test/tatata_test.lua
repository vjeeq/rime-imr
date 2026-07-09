-- tatata.lua 测试用例

local tests = {

    {
        name       = "1. 逆序：她-踏-他",
        priority   = { "他", "她", "它" },
        candidates = { "她是", "踏实", "他是" },
        expected   = { "他是", "她是", "踏实" },
    },

    {
        name       = "2. 他已在前面（不动）",
        priority   = { "他", "她", "它" },
        candidates = { "他是", "踏实", "她是", "它是" },
        expected   = { "他是", "踏实", "她是", "它是" },
    },

    {
        name       = "3. 纯单字（不动）",
        priority   = { "他", "她", "它" },
        candidates = { "他", "她", "它" },
        expected   = { "他", "她", "它" },
    },

    {
        name       = "4. 词内无优先字符（不动）",
        priority   = { "他", "她", "它" },
        candidates = { "你是", "你好", "你们" },
        expected   = { "你是", "你好", "你们" },
    },

    {
        name       = "5. 它-踏-她-他",
        priority   = { "他", "她", "它" },
        candidates = { "它是", "踏实", "她是", "他是" },
        expected   = { "他是", "她是", "它是", "踏实" },
    },

    {
        name       = "6. lookahead 超 5（ 他是超出窗口不动）",
        priority   = { "他", "她", "它" },
        candidates = { "她是", "A", "B", "C", "D", "E", "他是" },
        expected   = { "她是", "A", "B", "C", "D", "E", "他是" },
    },

    {
        name       = "7. lookahead 内没更高优（不动）",
        priority   = { "他", "她", "它" },
        candidates = { "她是", "踏实", "它是", "其他" },
        expected   = { "她是", "踏实", "它是", "其他" },
    },

    {
        name       = "8. 她说 + 单字他 + 他硕（rest 不匹配不动）",
        priority   = { "他", "她", "它" },
        candidates = { "她说", "他硕", "它说", "他", "他说" },
        expected   = { "他说", "她说", "他硕", "它说", "他" },
    },

    {
        name       = "9. 把 ta — 优先字符在第二音节",
        priority   = { "他", "她", "它" },
        candidates = { "把它", "把他", "把她", "把", "吧" },
        expected   = { "把他", "把她", "把它", "把", "吧" },
    },

    {
        name       = "10. 踏实 + 她是他是它是",
        priority   = { "他", "她", "它" },
        candidates = { "踏实", "她是", "他是", "它是", "它使" },
        expected   = { "踏实", "他是", "她是", "它是", "它使" },
    },

    {
        name       = "11. 他们它们她们 + 塔门",
        priority   = { "他", "她", "它" },
        candidates = { "他们", "它们", "她们", "塔门", "他" },
        expected   = { "他们", "她们", "它们", "塔门", "他" },
    },

}

return tests
