-- 抑制单字词频。仅当单独上屏且为单字时压回 c=-1。
-- 多字词、自造词一切正常——原生 ScriptTranslator::Memorize 完整执行。
--
-- 机制：
--   env.tran（shared_ptr）捕获于闭包，绕过 callback 中 self（裸指针）的 Lua 类型限制。
--   回调三步：清空 callback → 调原生 Memorize → 恢复 callback。
--   原生 Memorize 创建合并条目、处理 UpdateElements、更新语法模型。
--   回调只在末尾对 total==1 且 len==1 的条目追加一次 commits:update_entry(-1)。
--
-- 用法：在 schema 的 engine/translators 中将 script_translator 替换为
--       lua_translator@*imr.hold_single_freq@translator

local M = {}

function M.init(env)
    env.tran = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
    local tran = env.tran

    local function memorize_callback(self, commits)
        tran:set_memorize_callback(nil)
        tran:memorize(commits)
        tran:set_memorize_callback(memorize_callback)

        local entries = commits:get()
        if #entries == 1 and utf8.len(entries[1].text) == 1 then
            commits:update_entry(entries[1], -1, "")
        end
    end

    tran:set_memorize_callback(memorize_callback)
end

function M.fini(env)
    if env.tran then
        env.tran:disconnect()
    end
end

function M.func(inp, seg, env)
    local t = env.tran:query(inp, seg)
    if not t then return end
    for cand in t:iter() do
        yield(cand)
    end
end

return M
