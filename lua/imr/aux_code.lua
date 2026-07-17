local function char_at(s, n)
    if n <= 0 then return nil end
    local start = utf8.offset(s, n)
    if not start then return nil end
    local next_start = utf8.offset(s, n + 1)
    if not next_start then
        next_start = #s + 1
    end
    return s:sub(start, next_start - 1)
end
local AuxFilter = {}

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

local function escape_lua_pattern(text)
    return text:gsub("%W", "%%%1")
end

local function parse_aux_input(input_code, env)
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

function AuxFilter.init(env)
    -- log.info("** AuxCode filter", env.name_space)
    local engine = env.engine
    local config = engine.schema.config

    env.db = ReverseLookup(config:get_string('db/aux'))

    env.learn_trigger = config:get_string("aux/trigger") or ";"
    env.no_learn_trigger = config:get_string("aux/no_learn_trigger") or ""

    if env.no_learn_trigger == env.learn_trigger then
        env.no_learn_trigger = ""
    end

    env.triggers = {
        { mode = "no_learn", token = env.no_learn_trigger },
        { mode = "learn",    token = env.learn_trigger },
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

    -- 设定是否显示辅助码，默认为显示
    env.show_comment = config:get_bool("aux/show_comment")
    if env.show_comment == nil then env.show_comment = true end
    env.normal_comment = config:get_bool("aux/normal_comment") or false
    if env.show_comment or env.normal_comment then
        env.comment_db = ReverseLookup(config:get_string('db/aux_comment'))
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
        local trigger_pattern = escape_lua_pattern(trigger_token)
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
        else
            -- 剩下的直接上屏
            ctx:commit()
        end
    end)

end

----------------
-- 辅码匹配辅助函数 --
----------------

local function char_matches_aux(env, char, auxStr)
    if auxStr == "" then
        return false
    end

    local code = env.db:lookup(char)
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
local function find_phrase_match(env, word, _auxStr, length)
    local auxStr = _auxStr

    if auxStr == "" or not word or word == "" then
        return nil
    end

    local match_count = 0
    for _, codePoint in utf8.codes(word) do
        local char = utf8.char(codePoint)
        local this_aux = length == 0 and auxStr or auxStr:sub(1, length)
        auxStr = auxStr:sub(#this_aux + 1)
        if not char_matches_aux(env, char, this_aux) then
            return 0
        end
        match_count = match_count + 1
        if #auxStr == 0 then
            return match_count
        end
    end
    -- return match_count -- 持续上屏，因此如果输入的辅码比候选多，还是会保留候选（应处理，选完保留剩余辅码（现在做不到））
    return 0 -- 不持续上屏，因此如果输入的辅码比候选多，则不显示这个候选（uiui;yuyu，只匹配uiui不会匹配ui'ui的第一个ui）
end

local function is_phrase_candidate(cand)
    return cand.type == 'user_phrase' or cand.type == 'phrase' or cand.type == 'simplified'
end

local function append_comment(cand, auxCodes, char)
    local comment = auxCodes:gsub(' ', ',')
    -- if char ~= '' then
        -- comment = char .. ':' .. comment
    -- end
    -- 处理 simplifier
    if cand:get_dynamic_type() == 'Shadow' then
        local shadow_cand = cand
        local original_cand = cand:get_genuine()
        if not original_cand then
            cand.comment = merge_comment(cand.comment, comment)
            return cand
        end
        return ShadowCandidate(
            original_cand,
            original_cand.type, shadow_cand.text,
            (original_cand.comment or '') .. shadow_cand.comment .. comment
        )
    end
    cand.comment = merge_comment(cand.comment, comment)
    return cand
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
            if env.normal_comment and cand.type ~= "hub" then
                local lookup_char = char_at(cand.text, utf8.len(cand.text))
                if lookup_char and cand._end == #inputCode then  -- 需要完全匹配
                    local auxCodes = env.comment_db:lookup(lookup_char)
                    cand = append_comment(cand, auxCodes, lookup_char)
                end
            end
            yield(cand)
        end
        return
    end

    local function to_yield_candidate(cand)
        if mode == "no_learn" then
            return to_commit_only_candidate(cand)
        end
        return cand
    end

    -- 遍歷每一個待選項
    for _cand in input:iter() do
        local cand = _cand
        if #auxStr == 0 then
            if env.show_comment then
                local lookup_char = char_at(cand.text, 1)
                if lookup_char then
                    cand = append_comment(cand, env.comment_db:lookup(lookup_char), lookup_char)
                end
            end
            yield(to_yield_candidate(cand))
        elseif #auxStr > 0 and is_phrase_candidate(cand) then
            local matched_count = find_phrase_match(env, cand.text, auxStr, env.length)
            if matched_count > 0 then
                if env.show_comment then
                    local next_idx = matched_count
                    if #auxStr % env.length == 0 then next_idx = next_idx + 1 end
                    local lookup_char = char_at(cand.text, next_idx)
                    if lookup_char then
                        cand = append_comment(cand, env.comment_db:lookup(lookup_char), lookup_char)
                    end
                end
                yield(to_yield_candidate(cand))
            end
        end
    end
end

function AuxFilter.fini(env)
    env.notifier:disconnect()
    collectgarbage('collect')
end

return AuxFilter

-- Local Variables:
-- lua-indent-level: 4
-- End:
