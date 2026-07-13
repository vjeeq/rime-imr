-- - 触发：把选中词拆成单字候选，按数字选。
--
-- 用法：
--   processors:  lua_processor@*imr.select_char*Processor
--   translators: lua_translator@*imr.select_char*Translator
--   filters:     lua_filter@*imr.select_char*Filter

local state = { text = "" }

local Processor = {
    init = function(env) end,
    func = function(key, env)
        local context = env.engine.context

        if key:release() then
            return 2
        end

        if not context:is_composing() and not context:has_menu() then
            state.text = ""
            return 2
        end

        local cand = context:get_selected_candidate()
        if key:repr() == "minus" and state.text == "" and cand then
            state.text = cand.text
            context:refresh_non_confirmed_composition()
            return 1
        end

        return 2
    end
}

local Translator = {
    init = function(env) end,
    func = function(input, seg, env)
        if state.text ~= "" then
            for i = 1, utf8.len(state.text) do
                local char = state.text:sub(
                    utf8.offset(state.text, i),
                    utf8.offset(state.text, i + 1) - 1
                )
                yield(Candidate("imr_select_char", seg.start, seg._end, char, ""))
            end
        end
    end
}

local Filter = {
    init = function(env) end,
    func = function(input, env)
        for cand in input:iter() do
            if state.text == "" or cand.type == "imr_select_char" then
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
