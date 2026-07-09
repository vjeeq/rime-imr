-- tatata.lua 的 测试用例

local tests = {

    {
        name       = "1. 逆序三字",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "她是", "踏实", "他是" },
        expected   = { "他是", "她是", "踏实" },
        -- 她是 在 踏实 前面，所以结果应该也是 她是 在 踏实前面
    },

    {
        name       = "2. 他已在前面",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "他是", "踏实", "她是", "它是" },
        expected   = { "他是", "踏实", "她是", "它是" },
        -- taui 应该 是 他是 她是 没有 他 她
    },

    {
        name       = "3. 纯单字",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "他", "她", "它" },
        expected   = { "他", "她", "它" },
    },

    {
        name       = "4. 无规则匹配",
        input_code = "ni",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "你是", "你好", "你们" },
        expected   = { "你是", "你好", "你们" },
    },

    {
        name       = "5. 它是找高优",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "它是", "踏实", "她是", "他是" },
        expected   = { "他是", "她是", "它是", "踏实" },
        -- 它是 在 踏实 前面，所以应该是 他是她是(因为需要在它是前面) 它是(因为本来就是第一个，所以在踏实前面) 踏实
    },

    {
        name       = "6. lookahead 超5",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "她是", "A", "B", "C", "D", "E", "他是" },
        expected   = { "她是", "A", "B", "C", "D", "E", "他是" },
        -- 超5个就不应该有 他是 了啊
    },

    {
        name       = "7. lookahead 内没他",
        input_code = "ta",
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "她是", "踏实", "它是", "其他" },
        expected   = { "她是", "踏实", "它是", "其他" },
    },
    {
        name       = '8. ta说 可能出现单独的 ta',
        input_code = 'tauo',
        priority   = { ta = { "他", "她", "它" } },
        candidates = { "她说", "他硕", "它说", "他", '他说' },
        expected   = { "他说", "她说", "他硕", "它说", '他' },
    }


}

return tests
