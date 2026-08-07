-- dynamic_phrase.lua
-- 自造词 translator：为输入串提供自造词候选、命令预览、''编码 删除候选。
-- 命令语法（分隔符 '，空格/回车确认执行）：
--   '词'编码   add phrase with explicit code
--   '编码      add last commit text to code
--   ''编码     delete all entries with this code
--   ''词       delete all entries for this text
--   ''词'编码  delete exact text+code pair
--
-- 存储后端为 LevelDb userdb（见 dynamic_phrase_core.lua），可随 Rime
-- 用户资料同步跨设备合并。

local core = require("dynamic_phrase_core")

local function get_commit_history()
    local state = _G.__dynamic_phrase_state
    if not state then return {} end
    return state.commit_history or (state.last_commit_text and { state.last_commit_text }) or {}
end

-- 获取共享的 userdb 单例（缓存在 _G，由 dynamic_phrase_processor 的 fini 统一关闭）。
-- 不能用每次 open/close：LevelDb 打开开销大，且每次按键都会触发 translator，
-- 反复开关会导致打字卡顿；同时 LevelDb 有文件锁，也不能多个实例并存。
local function get_db(env)
    local db = _G.__dynamic_phrase_db
    if db then return db end
    local db_name = core.db_name_from_env(env)
    db = core.open_db(db_name, false)
    _G.__dynamic_phrase_db = db
    return db
end

-- 生成自造词候选。cand_type="dynamic_phrase" 表示可删词条；
-- 其它类型（如提示信息）不会被删除处理器误删。
local function make_candidate(seg, text, comment, quality, cand_type)
    local cand = Candidate(cand_type or "dynamic_phrase", seg.start, seg._end, text, comment or "")
    cand.quality = quality or 200000
    return cand
end

-- 命令预览候选：如「添加刚上屏：xxx / wyy」「删除编码：wyy / 全部自造词」
local function command_candidate(input, seg)
    local preview, comment = core.command_preview(input, get_commit_history())
    if preview then
        return make_candidate(seg, preview, (comment or "") .. "  空格/回车执行", 300000)
    end

    if core.is_dynamic_command(input) then
        local _, err = core.parse_command(input)
        -- When input is bare ' or '', the candidate text should be the literal
        -- input so that space/enter commits the apostrophe(s), not the hint.
        -- The hint text goes into the comment instead.
        if input == "'" or input == "''" then
            return make_candidate(seg, input, err or "动态词命令", 300000)
        end
        return make_candidate(seg, err or "动态词命令", "'码 空格/回车执行", 300000)
    end

    return nil
end

local function translator(input, seg, env)
    if type(input) ~= "string" or input == "" then
        return
    end

    -- ''编码：列出该编码下全部词条供选择删除
    if input:sub(1, 2) == "''" then
        local cmd, err = core.parse_command(input)
        if cmd and cmd.action == "del" and cmd.by_code then
            local db = get_db(env)
            local entries = db and core.lookup(cmd.code, db) or {}
            if #entries == 0 then
                yield(make_candidate(seg, "未找到编码：" .. cmd.code, "无此编码自造词", 300000, "dynamic_phrase_hint"))
                return
            end
            for i, entry in ipairs(entries) do
                yield(make_candidate(seg, entry.text, entry.code .. "〔自造·删〕", 250000 - i))
            end
            return
        end
    end

    local cmd_cand = command_candidate(input, seg)
    if cmd_cand then
        yield(cmd_cand)
        return
    end

    -- Do not treat non-code special commands as dynamic phrase codes.
    local first = input:sub(1, 1)
    if first == "=" or first == "\\" or first == "&" or first == "/" then
        return
    end
    -- Skip when input is just apostrophes (sentence-mode input).
    if first == "'" and not core.is_dynamic_command(input) then
        return
    end

    local db = get_db(env)
    local matches = db and core.lookup(input, db) or {}
    for i, entry in ipairs(matches) do
        local cand = make_candidate(seg, entry.text, entry.code .. "〔自造〕", 250000 - i)
        yield(cand)
    end
end

return translator
