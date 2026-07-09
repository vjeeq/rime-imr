-- imr_script_translator — 包装原生 ScriptTranslator，复用 translator: 配置块。
--
-- 当前功能：单独上屏的单字不记录词频（c=-1）。
--
-- 干预 Memorize 回调以实现自定义词频规则。
--
-- 机制：env.tran（shared_ptr）捕获于闭包，绕过 callback 中 self（裸指针）的類型限制。
-- 回调：清空 callback → 原生 Memorize（合并条目/UpdateElements/语法模型）→ 恢复 callback。
--
-- 用法：在 schema 的 engine/translators 中替换 script_translator：
--       lua_translator@*imr.imr_script_translator@translator

local M = {}

function M.init(env)
    env.tran = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
    local tran = env.tran

    local function memorize_callback(self, commits)
        tran:set_memorize_callback(nil)
        tran:memorize(commits)
        tran:set_memorize_callback(memorize_callback)

        -- ━━━ 词频规则 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- ★ 不记录单独上屏的单字词频（压回 c=-1）
        --   以后加其他规则也放在这个 block 里
        local entries = commits:get()
        if #entries == 1 and utf8.len(entries[1].text) == 1 then
            commits:update_entry(entries[1], -1, "")
        end
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
