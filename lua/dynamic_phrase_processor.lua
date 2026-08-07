-- dynamic_phrase_processor.lua
-- 自造词命令执行器：在空格/回车确认键时解析并执行 '/'' 命令。
-- 依赖 dynamic_phrase.lua 提供的候选（命令预览、''编码 词条列表），
-- 选中哪个候选就执行对应的添加/删除。

local core = require("dynamic_phrase_core")

local kAccepted = 1
local kNoop = 2

-- 跨组件共享状态（translator 也读 commit_history）
_G.__dynamic_phrase_state = _G.__dynamic_phrase_state or {}
local state = _G.__dynamic_phrase_state

-- 获取共享 userdb 单例（与 dynamic_phrase.lua 一致，缓存在 _G，
-- 本组件的 fini 负责关闭）。见 dynamic_phrase_core.lua 的 open_db 注释。
local function get_db(env)
    local db = _G.__dynamic_phrase_db
    if db then return db end
    local db_name = core.db_name_from_env(env)
    db = core.open_db(db_name, false)
    _G.__dynamic_phrase_db = db
    return db
end

local function get_candidate_order_store_path(env)
    local file = nil
    if env and env.engine and env.engine.schema and env.engine.schema.config then
        file = env.engine.schema.config:get_string("candidate_order/store_file")
    end
    return core.store_path(file or "candidate_order.txt")
end

-- 确认键：空格 / 回车 / 小键盘回车（不再支持分号）
local function is_confirm_key(key)
    if not key then return false end
    if key.keycode == 0x20 or key.keycode == 0x0d or key.keycode == 0x0a then
        return true
    end
    local repr = key.repr and key:repr() or ""
    return repr == "space" or repr == "Return" or repr == "KP_Enter"
end

local function get_commit_history()
    return state.commit_history or (state.last_commit_text and { state.last_commit_text }) or {}
end

-- 记录最近上屏文本（供 '编码 用刚上屏的词造词），最多保留 8 条
local function remember_commit_text(committed)
    if type(committed) ~= "string" or committed == "" then
        return
    end
    -- Do not let helper/status text replace the user's real phrase history.
    if committed:match("^已添加") or committed:match("^已删除") or committed:match("^未找到") then
        return
    end

    state.last_commit_text = committed
    state.commit_history = state.commit_history or {}
    state.commit_history[#state.commit_history + 1] = committed
    while #state.commit_history > 8 do
        table.remove(state.commit_history, 1)
    end
end

local function processor(key, env)
    if not key or key:release() or key:ctrl() or key:alt() or key:super() then
        return kNoop
    end
    if not is_confirm_key(key) then
        return kNoop
    end

    local context = env and env.engine and env.engine.context
    if not context then
        return kNoop
    end

    local input = context.input or ""
    if not core.is_dynamic_command(input) then
        return kNoop
    end

    -- 纯引号（' 或 ''）按空格/回车：放行给 selector/express_editor，
    -- 有候选则提交高亮候选，无候选则上屏字面引号
    local cmd = core.resolve_command(input, get_commit_history())
    if not cmd then
        if input == "'" or input == "''" then
            return kNoop
        end
        -- 命令不完整：吞掉确认键，保持输入可编辑
        return kAccepted
    end

    -- ''编码 选择删除：只删用户选中的那个词条（候选由 dynamic_phrase.lua 列出），
    -- 不删该编码下全部词条
    if cmd.action == "del" and cmd.by_code then
        local cand = context:get_selected_candidate()
        if cand and cand.type == "dynamic_phrase" and cand.text and cand.text ~= "" then
            local db = get_db(env)
            if db then
                core.delete_phrase(cand.text, cmd.code, db, get_candidate_order_store_path(env))
            end
            context:clear()
            return kAccepted
        end
        -- 未找到/提示候选：吞掉确认键，保留输入供修改
        return kAccepted
    end

    -- 普通命令（'编码 添加 / ''词 删除等）：执行
    local db = get_db(env)
    local ok = db and core.apply_resolved_command(cmd, db, get_candidate_order_store_path(env))
    if not ok then
        -- 保存失败：保留命令输入
        return kAccepted
    end

    -- 显式指定词的命令（'词'码）执行后把词上屏一次；
    -- 用最近上屏的简写（'码）不重复上屏
    if cmd.action == "add" and not cmd.from_last_commit and cmd.text and cmd.text ~= "" then
        env.engine:commit_text(cmd.text)
    end
    context:clear()
    return kAccepted
end

-- init：监听 commit_notifier 记录最近上屏文本
local function init(env)
    local context = env and env.engine and env.engine.context
    if not context or not context.commit_notifier then
        return
    end

    env.dynamic_phrase_commit_connection = context.commit_notifier:connect(function(ctx)
        local ok, committed = pcall(function() return ctx:get_commit_text() end)
        if ok then
            remember_commit_text(committed)
        end
    end)
end

-- fini：关闭共享 userdb 单例（释放 LevelDb 文件锁，保证部署/同步可重新打开），
-- 并断开 commit_notifier
local function fini(env)
    if _G.__dynamic_phrase_db then
        pcall(function() _G.__dynamic_phrase_db:close() end)
        _G.__dynamic_phrase_db = nil
    end
    if env and env.dynamic_phrase_commit_connection then
        pcall(function() env.dynamic_phrase_commit_connection:disconnect() end)
        env.dynamic_phrase_commit_connection = nil
    end
end

return { init = init, func = processor, fini = fini }
