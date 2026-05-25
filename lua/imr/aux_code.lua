utf8.char_at = function(s, n)
    if n <= 0 then return nil end
    local start = utf8.offset(s, n)      -- 第 n 个字符的起始字节位置
    if not start then return nil end     -- n 超出字符串长度
    local next_start = utf8.offset(s, n + 1)  -- 下一个字符起始位置
    if not next_start then
        next_start = #s + 1              -- 最后一个字符截取到结尾
    end
    return s:sub(start, next_start - 1)
end
local function to_string(x, seen)
    seen = seen or {} -- 用于检测循环引用
    local t = type(x)

    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return x and "true" or "false"
    elseif t == "number" then
        return tostring(x)
    elseif t == "string" then
        return string.format("%q", x) -- 加双引号并转义内部字符
    elseif t == "table" then
        if seen[x] then
            return "<循环引用>"
        end
        seen[x] = true
        local parts = {}
        for k, v in pairs(x) do
            -- 键的表示：字符串加引号，其他直接 tostring
            local key_str = (type(k) == "string") and string.format("%q", k) or tostring(k)
            local val_str = to_string(v, seen)
            table.insert(parts, key_str .. " = " .. val_str)
        end
        seen[x] = nil -- 清理，避免影响同级其他分支（可选）
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        -- function, thread, userdata 等类型
        return "<" .. t .. ": " .. tostring(x) .. ">"
    end
end
local AuxFilter = {}
local parse_aux_input

local function normalize_trigger(token, fallback)
    if token == nil or token == "" then
        return fallback
    end
    return token
end

local function merge_comment(origin, message)
    if not origin or origin == "" then
        return message
    end
    if origin:find(message, 1, true) then
        return origin
    end
    return origin .. " | " .. message
end

-- local log = require 'log'
-- log.outfile = "aux_code.log"

function AuxFilter.init(env)
    -- log.info("** AuxCode filter", env.name_space)
    local engine = env.engine
    local config = engine.schema.config

    AuxFilter.db = ReverseLookup(config:get_string('aux/db'))

    -- 双触发键：learn 与 no_learn
    env.learn_trigger = normalize_trigger(config:get_string("aux/trigger/default"), nil)
        or normalize_trigger(config:get_string("aux/trigger/learn"), nil)
        or ";"
    env.no_learn_trigger = normalize_trigger(config:get_string("aux/trigger/no_learn"), "")

    if env.no_learn_trigger == env.learn_trigger then
        env.no_learn_trigger = ""
    end

    env.triggers = {
        { mode = "no_learn", token = env.no_learn_trigger },
        { mode = "learn", token = env.learn_trigger },
    }
    env.length = config:get_int('aux/length') or 2

    local active_triggers = {}
    for _, item in ipairs(env.triggers) do
        if item.token ~= "" then
            table.insert(active_triggers, item)
        end
    end
    env.triggers = active_triggers

    table.sort(env.triggers, function(a, b)
        return #a.token > #b.token
    end)

    -- 兼容旧逻辑，后续任务会替换为 parse 模式
    env.trigger_key = env.learn_trigger
    -- 设定是否显示辅助码，默认为显示
    env.show_comment = config:get_string("aux/comment/enable") or 'true'
    if env.show_comment == "false" then
        env.show_comment = false
    else
        env.show_comment = true
        AuxFilter.comment_db = ReverseLookup(config:get_string('aux/comment/db'))
    end

    ----------------------------
    -- 持續選詞上屏，保持輔助碼分隔符存在 --
    ----------------------------
    env.notifier = engine.context.select_notifier:connect(function(ctx)
        local input = ctx.input
        local mode, _, trigger_token = parse_aux_input(input, env)
        if mode == "none" then
            return
        end

        local preedit = ctx:get_preedit()
        local trigger_pattern = trigger_token:gsub("%W", "%%%1")
        local removeAuxInput = input:match("([^,]+)" .. trigger_pattern)
        local reeditTextFront = preedit.text:match("([^,]+)" .. trigger_pattern)

        if not removeAuxInput then
            return
        end

        -- ctx.text 隨著選字的進行，oaoaoa； 有如下的輸出：
        -- ---- 有輔助碼 ----
        -- >>> 啊 oaoa；au
        -- >>> 啊吖 oa；au
        -- >>> 啊吖啊；au
        -- ---- 無輔助碼 ----
        -- >>> 啊 oaoa；
        -- >>> 啊吖 oa；
        -- >>> 啊吖啊；
        -- 這邊把已經上屏的字段 (preedit:text) 進行分割；
        -- 如果已經全部選完了，分割後的結果就是 nil，否則都是 吖卡 a 這種字符串
        -- 驗證方式：
        -- log.info('select_notifier', ctx.input, removeAuxInput, preedit.text, reeditTextFront)

        -- 當最終不含有任何字母時 (候選)，就跳出分割模式，並把輔助碼分隔符刪掉
        ctx.input = removeAuxInput
        if reeditTextFront and reeditTextFront:match("[a-z0-9]") then
            -- 給詞尾自動添加分隔符，上面的 re.match 會把分隔符刪掉
            ctx.input = ctx.input .. trigger_token

            -- -- 保留剩余辅码
            -- 无法获取本次消耗的辅码，暂时取消这个功能
            -- -- trigger前是 选中的字+剩余的字母，提取 选中的字 到cn_char
            -- local cn_char = reeditTextFront:gsub('[a-z0-9]', '')
            -- -- 选中的字对应的辅码长度，aux_count是消耗的辅码的数量
            -- local aux_count = utf8.len(cn_char) * env.length
            -- -- 匹配分隔符后的内容，应是辅码（本次消耗的辅码+剩余的辅码）
            -- local right_text = input:match('[^,]+' .. trigger_pattern .. '([^,]+)')
            -- ctx.input = ctx.input .. right_text:sub(aux_count + 1)
        else
            -- 剩下的直接上屏
            ctx:commit()
        end
    end)
-- AuxFilter.aux_code { ["啊"] = ka,["阿"] = ek,} 
end

----------------
-- 閱讀輔碼文件 --
----------------

-- local function getUtf8CharLength(byte)
--     if byte < 128 then
--         return 1
--     elseif byte < 224 then
--         return 2
--     elseif byte < 240 then
--         return 3
--     else
--         return 4
--     end
-- end

-- 预处理辅码索引，避免在候选循环中重复拆分字符串。
-- k1: 记录每个字可命中的首键；k12: 记录前两键完整命中。

local function char_matches_aux(char, auxStr)
    if auxStr == "" then
        return false
    end

    local code = AuxFilter.db:lookup(char)
    if not code or #code == 0 then
        return false
    end
    for part in code:gmatch('%S+') do
        if part:find(auxStr) == 1 then return true end
    end
    return false
end

-- 词组匹配按字位逐个检查，命中即返回。
-- 这样只允许同一个字完整命中，避免旧逻辑跨字混拼误命中。
local function find_phrase_match(word, _auxStr, length)
    local auxStr = _auxStr

    if auxStr == "" or not word or word == "" then
        return nil
    end

    local match_count = 0
    for _, codePoint in utf8.codes(word) do
        local char = utf8.char(codePoint)
        local this_aux = length == 0 and auxStr or auxStr:sub(1, length)
        auxStr = auxStr:sub(#this_aux + 1)
        if not char_matches_aux(char, this_aux) then
            return 0
        end
        match_count = match_count + 1
        if #auxStr == 0 then
            return match_count
        end
    end
    -- return match_count -- 持续上屏，因此如果输入的辅码比候选多，还是会保留候选（应处理，选完保留剩余辅码（现在做不到））
    return 0  -- 不持续上屏，因此如果输入的辅码比候选多，则不显示这个候选（uiui`yuyu，只匹配uiui不会匹配ui'ui的第一个ui）
end

local function is_phrase_candidate(cand)
    return cand.type == 'user_phrase' or cand.type == 'phrase' or cand.type == 'simplified'
end

local function is_multi_char_text(text)
    if not text or text == "" then
        return false
    end

    local count = 0
    for _ in utf8.codes(text) do
        count = count + 1
        if count > 1 then
            return true
        end
    end

    return false
end

local function append_comment(cand, auxCodes, char)
    local comment = auxCodes:gsub(' ', ',')
    if char ~= '' then
        comment = char .. ':' .. comment
    end
    -- comment = '(' .. comment .. ')'
    -- 处理 simplifier
    if cand:get_dynamic_type() == 'Shadow' then
        local shandow_cand = cand
        local original_cand = cand:get_genuine()
        if not original_cand then
            cand.comment = merge_comment(cand.comment, comment)
            return
        end
        return ShadowCandidate(
            original_cand,
            original_cand.type, shandow_cand.text,
            (original_cand.comment or '') .. shandow_cand.comment .. comment
        )
    end
    cand.comment = merge_comment(cand.comment, comment)
    return cand
end

local function escape_lua_pattern(text)
    return text:gsub("%W", "%%%1")
end

parse_aux_input = function(input_code, env)
    if input_code == "" then
        return "none", "", ""
    end

    for _, item in ipairs(env.triggers) do
        local token = item.token
        if token ~= "" then
            local token_pattern = escape_lua_pattern(token)
            if input_code:find(token, 1, true) then
                local local_split = input_code:match(token_pattern .. "([^,]+)")
                if not local_split then
                    return item.mode, "", token
                end
                return item.mode, local_split, token
            end
        end
    end

    return "none", "", ""
end

local function to_commit_only_candidate(cand)
    local rebuilt = Candidate(cand.type, cand.start, cand._end, cand.text, cand.comment)
    rebuilt.preedit = cand.preedit
    rebuilt.quality = cand.quality
    return rebuilt
end

------------------
-- filter 主函數 --
------------------
function AuxFilter.func(input, env)
    local context = env.engine.context
    local inputCode = context.input

    local mode, auxStr, _ = parse_aux_input(inputCode, env)

    -- 判断字符串中是否包含輔助碼分隔符
    if mode == "none" then
        -- 没有输入辅助码引导符，则直接yield所有待选项，不进入后续迭代，提升性能
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local first_exact_bucket = {}
    local full_aux_bucket = {}

    local function to_yield_candidate(cand)
        if mode == "no_learn" then
            return to_commit_only_candidate(cand)
        end
        return cand
    end

    -- 遍歷每一個待選項
    for _cand in input:iter() do
        local cand = _cand

        -- 過濾輔助碼
        if #auxStr == 0 then
            -- 没有辅助码，加一下提示，直接返回
            if env.show_comment then
                local hint_char, lookup_char
                if is_multi_char_text(cand.text) then
                    lookup_char = utf8.char(utf8.codepoint(cand.text, 1))
                    hint_char = lookup_char
                else
                    lookup_char = cand.text
                    hint_char = ''
                end
                local auxCodes = AuxFilter.comment_db:lookup(lookup_char)
                cand = append_comment(cand, auxCodes, hint_char)
            end
            yield((to_yield_candidate(cand)))
        elseif #auxStr > 0 and is_phrase_candidate(cand) then
            local matched_count = find_phrase_match(cand.text, auxStr, env.length)
            -- 仅词组候选显示命中提示，单字继续沿用“显示全部辅码”。
            if matched_count > 0 then
                if env.show_comment then
                    local lookup_char = utf8.char_at(cand.text, matched_count)
                    assert(lookup_char)
                    local auxCodes = AuxFilter.comment_db:lookup(lookup_char)
                    local hint_char = ''
                    if is_multi_char_text(cand.text) then
                        hint_char = lookup_char
                    end
                    cand = append_comment(cand, auxCodes, hint_char)
                end
                table.insert(first_exact_bucket, cand)
            end

            -- if matched and matched.pos == 1 then
            -- elseif matched then
                -- table.insert(full_aux_bucket, cand)
            -- end
        else
            -- 待选项字词 没有 匹配到当前的辅助码，插入到列表中，最后插入到候选框里( 获得靠后的位置 )
            -- table.insert(insertLater, cand)
            -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
        end
    end

    local seen = {}
    local function yield_bucket(bucket)
        for _, cand in ipairs(bucket) do
            local key = cand.type .. "\t" .. cand.start .. "\t" .. cand._end .. "\t" .. cand.text
            if not seen[key] then
                seen[key] = true
                yield(to_yield_candidate(cand))
            end
        end
    end

    yield_bucket(first_exact_bucket)
    yield_bucket(full_aux_bucket)

    -- 把沒有匹配上的待選給添加上
    -- for _, cand in ipairs(insertLater) do
    --     yield(cand)
    -- end
    -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
end

function AuxFilter.fini(env)
    env.notifier:disconnect()
end

return AuxFilter

-- Local Variables:
-- lua-indent-level: 4
-- End: