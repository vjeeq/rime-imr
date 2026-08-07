-- dynamic_phrase_core.lua
-- 自造词存储层：基于 LevelDb（userdb），可被 Rime 用户资料同步跨设备合并。
--
-- 存储格式（与 librime 官方 userdb 快照格式一致，user_db.cc:67-92）：
--   key   ::= 编码 + " \t" + 词        （编码后空格+Tab，前缀查询天然区分同码词）
--   value ::= "c=<±时间戳> d=0 t=<时间戳>"（UserDbValue.Pack 格式，user_db.cc:22-26）
--   c > 0 表示词条存在（添加于该时间戳）；c < 0 表示标记删除（删除于该时间戳）
--
-- 跨设备合并语义（关键设计）：
--   librime 同步合并规则是 abs(commits) 大者胜（user_db.cc:219），
--   因此把「操作时间戳」作为 c 的绝对值、符号表示加/删，
--   合并结果 = 最新操作胜出：后添加的保留、后删除的传播到其他设备。
--
-- 注意：t 字段只凑官方格式，不用来判新旧（官方合并会把 t 覆盖为
-- 本地 /tick 元数据，见 UserDbMerger::Put，对我们的逻辑无影响）。

local M = {}

M.default_db_name = "imr_KT6_dz_self"

local function trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_code_like(s)
    return type(s) == "string" and s:match("^[A-Za-z0-9']+$") ~= nil
end

local function normalize_commit_history(source)
    if type(source) == "table" then
        local out = {}
        for _, item in ipairs(source) do
            local s = trim(tostring(item or ""))
            if s ~= "" then
                out[#out + 1] = s
            end
        end
        return out
    end

    local s = trim(source)
    if s == "" then return {} end
    return { s }
end

function M.recent_commit_text(source, count)
    local history = normalize_commit_history(source)
    count = tonumber(count) or 1
    count = math.floor(count)
    if count < 1 then return "" end
    if #history == 0 then return "" end
    if count > #history then count = #history end

    local start = #history - count + 1
    local parts = {}
    for i = start, #history do
        parts[#parts + 1] = history[i]
    end
    return table.concat(parts)
end

local function get_timestamp()
    -- 秒级时间戳（os.time）。跨设备可比，用作 c 的绝对值。
    -- 注意：librime-lua 的 rime_api.get_time_ms 是 steady_clock（单调钟），
    -- 跨设备不可比，不能用于合并排序，故用系统时钟。
    return math.floor(os.time())
end

local function path_separator()
    local cfg = package.config or "/"
    return cfg:sub(1, 1) == "\\" and "\\" or "/"
end

local function join_path(dir, name)
    if not dir or dir == "" then return name end
    local sep = path_separator()
    if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then
        return dir .. name
    end
    return dir .. sep .. name
end

-- Resolve a plain file path under the Rime user data dir (used by
-- candidate_order cleanup; the phrase store itself lives in LevelDb).
function M.store_path(filename)
    filename = filename or M.default_filename
    if rime_api and rime_api.get_user_data_dir then
        local ok, dir = pcall(rime_api.get_user_data_dir)
        if ok and dir and dir ~= "" then
            return join_path(dir, filename)
        end
    end
    return filename
end

-- db helpers ---------------------------------------------------------------

-- 从 schema 配置读取 userdb 名（dynamic_phrase/db_name），缺省用默认名。
function M.db_name_from_env(env)
    local name = nil
    if env and env.engine and env.engine.schema and env.engine.schema.config then
        name = env.engine.schema.config:get_string("dynamic_phrase/db_name")
    end
    if not name or name == "" then
        name = M.default_db_name
    end
    return name
end

-- 打开一个 LevelDb userdb（文件在 user_data_dir 下，如 imr_KT6_dz_self.userdb）。
-- 返回 db 对象，调用方负责 :close()。
-- 注意：LevelDb 有文件锁，同一文件同时只能有一个实例打开，
-- 因此上层用 _G.__dynamic_phrase_db 缓存单例，避免每次按键都 open/close。
function M.open_db(db_name, readonly)
    db_name = db_name or M.default_db_name
    local ok, db = pcall(LevelDb, db_name)
    if not ok or not db then
        return nil
    end
    local opened = readonly and db:open_read_only() or db:open()
    if not opened then
        db:close()
        return nil
    end
    return db
end

-- 组装 key：编码 + 空格 + Tab + 词（官方 userdb 快照格式要求，user_db.cc:67-92）
local function entry_key(code, text)
    return code .. " \t" .. text
end

-- 组装 value：c=±时间戳 d=0 t=时间戳（官方 UserDbValue.Pack 格式，user_db.cc:22-26）
-- sign=1 添加/恢复；sign=-1 标记删除（保留 key，同步快照里才有删除记录可传播）
local function pack_value(sign, ts)
    return "c=" .. (sign < 0 and "-" or "") .. ts .. " d=0 t=" .. ts
end

-- 解析 value "c=1 d=0 t=5" → commits（c 字段）、tick（t 字段）
local function unpack_value(value)
    local commits = 0
    local tick = 0
    for k, v in string.gmatch(value or "", "([%w_]+)=([^%s]+)") do
        local n = tonumber(v)
        if n then
            if k == "c" then commits = n
            elseif k == "t" then tick = n end
        end
    end
    return commits, tick
end

local function is_deleted(commits)
    return commits < 0
end

-- 按 key 前缀查询词条（prefix="" 查全部），跳过已删除（c<0）的条目。
-- key 解析：优先匹配「编码+空格+Tab+词」，兼容无空格的旧格式。
-- 注意：LevelDb 前缀查询是 starts_with 匹配，prefix 用「编码+空格+Tab」
-- 可精确限定编码，避免误匹配更长编码（如 wyy 不匹配 wyyx）。
local function query_entries(db, prefix)
    local entries = {}
    if not db then return entries end
    local ok, acc = pcall(function()
        local iter = db:query(prefix or "")
        if not iter then return {} end
        local out = {}
        for key, value in iter:iter() do
            local code, text = key:match("^([^%s]+[^%t]*) \t(.*)$")
            if not code then
                code, text = key:match("^([^%t]+)\t(.*)$")
            end
            if code and text and text ~= "" then
                code = trim(code)
                local commits = unpack_value(value)
                if not is_deleted(commits) then
                    out[#out + 1] = { text = text, code = code }
                end
            end
        end
        return out
    end)
    if ok then return acc end
    return entries
end

function M.is_dynamic_command(input)
    if type(input) ~= "string" then return false end
    -- Must start with ' (add) or '' (del). Bare ' alone is not a command.
    if input == "'" or input == "''" then return true end
    if input:sub(1, 2) == "''" then return true end
    if input:sub(1, 1) == "'" then return true end
    return false
end

function M.parse_command(input)
    if type(input) ~= "string" then
        return nil, "命令为空"
    end

    -- Determine action by leading apostrophes: '' = del, ' = add.
    local is_del = input:sub(1, 2) == "''"
    local is_add = not is_del and input:sub(1, 1) == "'"
    if not is_del and not is_add then
        return nil, "未知命令"
    end

    -- Strip the prefix ('' or ') to get the argument portion.
    local arg = is_del and input:sub(3) or input:sub(2)

    if is_add then
        -- ADD syntax (separator is '):
        --   '编码            → add last commit to code
        --   '词'编码         → add text with code
        if arg == "" then
            return nil, "用法：'编码 或 '词'编码"
        end

        -- Try: text'code  (explicit text add)
        -- Use the first ' as separator; text is before it, code is after.
        local sep_pos = arg:find("'")
        if sep_pos and sep_pos > 1 then
            local text = trim(arg:sub(1, sep_pos - 1))
            local code = trim(arg:sub(sep_pos + 1))
            if text == "" then return nil, "词不能为空" end
            if code == "" then return nil, "编码不能为空" end
            return { action = "add", text = text, code = code }
        end

        -- No separator: treat entire arg as code, use last commit text
        local code = trim(arg)
        if code == "" then return nil, "编码不能为空" end
        return { action = "add", code = code, needs_last_commit = true }
    end

    -- DEL syntax (separator is '):
    --   ''编码           → delete all entries with this code
    --   ''词             → delete all entries for this text
    --   ''词'编码        → delete exact text+code pair
    if arg == "" then
        return nil, "用法：''编码 或 ''词 或 ''词'编码"
    end

    -- Try: text'code  (exact delete)
    local sep_pos = arg:find("'")
    if sep_pos and sep_pos > 1 then
        local text = trim(arg:sub(1, sep_pos - 1))
        local code = trim(arg:sub(sep_pos + 1))
        if text == "" then return nil, "词不能为空" end
        if code == "" then return nil, "编码不能为空" end
        return { action = "del", text = text, code = code }
    end

    -- No separator: could be code (if code-like) or text
    local single = trim(arg)
    if single == "" then return nil, "词或编码不能为空" end

    if is_code_like(single) then
        -- ''code → delete by code
        return { action = "del", code = single, by_code = true }
    end

    -- ''text → delete by text (all codes)
    return { action = "del", text = single, single_arg = true }
end

local function cleanup_candidate_order_for_deleted_texts(texts, candidate_order_path, codes)
    if type(texts) ~= "table" then texts = {} end
    local has_any = false
    for text, present in pairs(texts) do
        if present and trim(text) ~= "" then
            has_any = true
            break
        end
    end
    local has_code = false
    if type(codes) == "string" and trim(codes) ~= "" then
        has_code = true
    elseif type(codes) == "table" then
        for _, code in pairs(codes) do
            if trim(code) ~= "" then
                has_code = true
                break
            end
        end
    end
    if not has_any and not has_code then return 0 end

    local ok_core, candidate_order_core = pcall(require, "candidate_order_core")
    if not ok_core or not candidate_order_core or not candidate_order_core.remove_records_for_texts then
        return 0
    end

    local path = candidate_order_path
    if not path or path == "" then
        path = candidate_order_core.store_path(candidate_order_core.default_filename)
    end
    local ok, _, removed = pcall(candidate_order_core.remove_records_for_texts, texts, path, codes)
    if ok then return tonumber(removed) or 0 end
    return 0
end

local function append_candidate_order_cleanup_message(message, removed)
    removed = tonumber(removed) or 0
    if removed > 0 then
        return message .. "；同步清理调频" .. tostring(removed) .. "条"
    end
    return message
end

function M.add_phrase(text, code, db)
    text = trim(text)
    code = trim(code)
    if text == "" then return false, "词不能为空" end
    if code == "" then return false, "编码不能为空" end
    if not db then return false, "无法打开词库" end

    -- 添加：写 c=+当前时间戳。若已存在（含曾被标记删除的），
    -- 新的正时间戳 abs 更大，同步合并后恢复为存在状态。
    local ts = get_timestamp()
    local key = entry_key(code, text)
    local existed = false
    local value = db:fetch(key)
    if value then
        local commits = unpack_value(value)
        existed = not is_deleted(commits)
    end
    if not db:update(key, pack_value(1, ts)) then
        return false, "写入失败"
    end
    if existed then
        return true, "已存在：" .. text .. " / " .. code, 0
    end
    return true, "已添加：" .. text .. " / " .. code, 1
end

function M.delete_phrase(text, code, db, candidate_order_path)
    text = trim(text)
    code = code and trim(code) or nil
    if text == "" then return false, "词不能为空" end
    if code == "" then return false, "编码不能为空" end
    if not db then return false, "无法打开词库" end

    -- 删除：不 erase，而是写 c=-当前时间戳「标记删除」。
    -- 保留 key 是关键——同步快照里才有这条删除记录，
    -- 另一台设备合并时 abs(负时间戳) 更大 → 删除传播过去。
    local ts = get_timestamp()
    local removed = 0
    local deleted_texts = {}
    local prefix = code and (code .. " \t") or ""
    local iter = db:query(prefix)
    if iter then
        for key in iter:iter() do
            local c, t = key:match("^([^%t]+)\t(.*)$")
            if c and t and trim(t) == text then
                if not db:update(key, pack_value(-1, ts)) then
                    return false, "写入失败", removed
                end
                removed = removed + 1
                deleted_texts[text] = true
            end
        end
    end

    local cleanup_texts = deleted_texts
    cleanup_texts[text] = true
    local co_removed = cleanup_candidate_order_for_deleted_texts(cleanup_texts, candidate_order_path, code)
    if removed == 0 then
        return true, append_candidate_order_cleanup_message(
            "未找到：" .. text .. (code and (" / " .. code) or ""),
            co_removed
        ), 0
    end
    return true, append_candidate_order_cleanup_message(
        "已删除" .. removed .. "条：" .. text .. (code and (" / " .. code) or ""),
        co_removed
    ), removed
end

function M.delete_by_code(code, db, candidate_order_path)
    code = trim(code)
    if code == "" then return false, "编码不能为空" end
    if not db then return false, "无法打开词库" end

    -- 按编码标记删除该码下全部未删除词条（同样保留 key，写负时间戳）
    local ts = get_timestamp()
    local removed = 0
    local deleted_texts = {}
    local iter = db:query(code .. " \t")
    if iter then
        for key, value in iter:iter() do
            local _, text = key:match("^([^%t]+)\t(.*)$")
            local commits = unpack_value(value)
            if not is_deleted(commits) then
                if not db:update(key, pack_value(-1, ts)) then
                    return false, "写入失败", removed
                end
                removed = removed + 1
                if text then deleted_texts[text] = true end
            end
        end
    end

    local co_removed = cleanup_candidate_order_for_deleted_texts(deleted_texts, candidate_order_path, code)
    if removed == 0 then
        return true, append_candidate_order_cleanup_message("未找到编码：" .. code, co_removed), 0
    end
    return true, append_candidate_order_cleanup_message(
        "已删除" .. removed .. "条编码：" .. code,
        co_removed
    ), removed
end

-- 解析命令输入为可执行结构；'编码 简写需结合 commit_history 取最近上屏文本
function M.resolve_command(input, commit_history)
    local cmd, err = M.parse_command(input)
    if not cmd then
        return nil, err or "命令格式错误"
    end
    if cmd.action == "add" and cmd.needs_last_commit then
        local text = M.recent_commit_text(commit_history, 1)
        if text == "" then
            return nil, "先打出要加的词，再输入 '编码"
        end
        cmd.text = text
        cmd.from_last_commit = true
    end
    return cmd
end

-- 执行已解析的命令：add → add_phrase；del → delete_by_code / delete_phrase
function M.apply_resolved_command(cmd, db, candidate_order_path)
    if not cmd then
        return false, "命令格式错误", 0
    end
    if cmd.action == "add" then
        return M.add_phrase(cmd.text, cmd.code, db)
    elseif cmd.action == "del" then
        if cmd.by_code then
            return M.delete_by_code(cmd.code, db, candidate_order_path)
        end
        return M.delete_phrase(cmd.text, cmd.code, db, candidate_order_path)
    end
    return false, "未知命令", 0
end

-- 精确查询：列出编码恰好为 code 的未删除词条（编码+空格+Tab 前缀限定）
function M.lookup(code, db)
    code = trim(code)
    if code == "" then return {} end
    if not db then return {} end
    return query_entries(db, code .. " \t")
end

-- 前缀查询：列出编码以 prefix 开头的未删除词条（用于输入过程中的自造词候选提示）
function M.lookup_prefix(prefix, db, limit)
    prefix = trim(prefix)
    if prefix == "" then return {} end
    limit = limit or 50
    if not db then return {} end

    local entries = query_entries(db, "")
    local matches = {}
    for _, entry in ipairs(entries) do
        if entry.code:sub(1, #prefix) == prefix then
            matches[#matches + 1] = entry
            if #matches >= limit then break end
        end
    end
    return matches
end

local function pair_key(text, code)
    return tostring(text or "") .. "\t" .. tostring(code or "")
end

local function normalize_codes(codes)
    if not codes then return nil end
    local out = {}
    local has_any = false
    for key, value in pairs(codes) do
        local code = nil
        if type(key) == "number" then
            code = value
        elseif value then
            code = key
        end
        code = trim(code)
        if code ~= "" then
            out[code] = true
            has_any = true
        end
    end
    if not has_any then return nil end
    return out
end

function M.load_occupied_for_codes(db, codes, exclude_pairs)
    local target_codes = normalize_codes(codes)
    local occupied = {}
    if not db then return occupied end

    local function add(text, code)
        text = trim(text)
        code = trim(code)
        if text == "" or code == "" then return end
        if exclude_pairs and exclude_pairs[pair_key(text, code)] then return end
        local bucket = occupied[code]
        if not bucket then
            bucket = {}
            occupied[code] = bucket
        end
        bucket[text] = true
    end

    if target_codes then
        for code in pairs(target_codes) do
            for _, entry in ipairs(query_entries(db, code .. " \t")) do
                add(entry.text, entry.code)
            end
        end
    else
        for _, entry in ipairs(query_entries(db, "")) do
            add(entry.text, entry.code)
        end
    end

    return occupied
end

-- 命令预览：候选窗中显示将要执行的操作（如「添加刚上屏：xxx / wyy」）
function M.command_preview(input, last_commit_text)
    local cmd, err = M.resolve_command(input, last_commit_text)
    if not cmd then
        return nil, err
    end
    if cmd.action == "add" then
        local prefix = cmd.from_last_commit and "添加刚上屏：" or "添加词："
        return prefix .. cmd.text, cmd.code
    elseif cmd.action == "del" then
        if cmd.by_code then
            return "删除编码：" .. cmd.code, "全部自造词"
        end
        local prefix = cmd.from_last_commit and "删除刚上屏：" or "删除词："
        return prefix .. cmd.text, cmd.code or "全部编码"
    end
    return nil, "未知命令"
end

return M
