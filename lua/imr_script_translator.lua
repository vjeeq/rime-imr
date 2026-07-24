-- 包装原生 ScriptTranslator，拦截词频记录回调。
-- 在此添加自定义词频规则：
--   - 单字上屏不记词频（当前）
--   - 特定词条强制固定频率
--   - 条件性高低频调整
-- 用法：lua_translator@*imr.imr_script_translator@translator

local M = {}

function M.init(env)
    env.tran = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
    local tran = env.tran

    local function memorize_callback(self, commits)
        -- 先禁用原生 memorize 处理，独占执行自定义词频规则
        tran:set_memorize_callback(function() end)
        local ok = pcall(tran.memorize, tran, commits)
        tran:set_memorize_callback(memorize_callback)
        if not ok then return end

        -- ━━━ 词频规则 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- 单字不记录词频(c=-1) (无论是单字上屏还是多字上屏)
        -- 后续规则追加在此
        local items = commits:get()
        for i = 1, #items do
            local item = items[i]
            if item and utf8.len(item.text) == 1 then
                commits:update_entry(item, -1, "")
            end
        end
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
