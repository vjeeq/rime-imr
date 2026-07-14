-- - 触发：把选中词拆成单字候选，按数字选，或打码筛选。
--
-- 用法：
--   processors:  lua_processor@*imr.select_char*Processor
--   translators: lua_translator@*imr.select_char*Translator
--   filters:     lua_filter@*imr.select_char*Filter

local state = { mode = "", text = "" }

local Processor = {
    init = function(env) end,
    func = function(key, env)
        local ctx = env.engine.context

        if key:release() then
            return 2
        end

        if not ctx:is_composing() and not ctx:has_menu() then
            state = { mode = "", text = "" }
            return 2
        end

        -- 筛选模式下 Backspace：code 清空后退出
        if state.mode == "code" and key:repr() == "BackSpace" then
            local input = ctx.input or ""
            if not string.find(input, "-", 1, true) then
                state = { mode = "", text = "" }
            end
            return 2
        end

        -- 已进入模式但按键不是 Backspace → 放行给 speller/T93
        if state.mode == "code" then
            return 2
        end

        local cand = ctx:get_selected_candidate()
        if not cand then return 2 end

        -- - 触发筛选模式
        if key:repr() == "minus" then
            state.mode = "code"
            state.text = cand.text
            ctx.input = ctx.input .. "-"
            ctx:refresh_non_confirmed_composition()
            return 1
        end

        return 2
    end
}

local Translator = {
    init = function(env)
        local config = env.engine.schema.config
        env.aux_db = ReverseLookup(config:get_string("aux/db"))
        env.pinyin_db = ReverseLookup(config:get_string("select_char/pinyin_db"))
    end,
    func = function(input, seg, env)
        if state.mode == "" or state.text == "" then return end

        local ctx = env.engine.context
        local full_input = ctx.input or ""
        local pos = string.find(full_input, "-", 1, true)
        local code = pos and string.sub(full_input, pos + 1) or ""

        local chars = {}
        for _, cp in utf8.codes(state.text) do
            table.insert(chars, utf8.char(cp))
        end

        if code == "" then
            for _, c in ipairs(chars) do
                yield(Candidate("imr_select_char", seg.start, seg._end, c, ""))
            end
            return
        end

        for _, ch in ipairs(chars) do
            local clean_raw = env.pinyin_db:lookup(ch) or ""
            local aux_raw   = env.aux_db:lookup(ch) or ""

            local matched = false
            for cv in string.gmatch(clean_raw, "%S+") do
                cv = string.sub(cv, 1, -2)
                if string.sub(cv, 1, #code) == code then
                    matched = true; break
                end
                for av in string.gmatch(aux_raw, "%S+") do
                    if string.sub(cv .. av, 1, #code) == code then
                        matched = true; break
                    end
                end
                if matched then break end
            end

            if matched then
                yield(Candidate("imr_select_char", seg.start, seg._end, ch, ""))
            end
        end
    end
}

local Filter = {
    init = function(env) end,
    func = function(input, env)
        local active = state.mode ~= ""
        for cand in input:iter() do
            if not active or cand.type == "imr_select_char" then
                yield(cand)
            end
        end
    end
}

return {
    Processor = Processor,
    Translator = Translator,
    Filter = Filter,
}
