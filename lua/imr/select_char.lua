--
local Processor = {}
local Translator = {}
function Processor.init(env)
end

function Processor.func(key, env)
    local engine = env.engine
    local context = env.engine.context
    if
        not key:release()
        and (context:is_composing() or context:has_menu())
    then
        local key_repr = key:repr()
        if key_repr == 'semicolon'
            and context:get_property('imr_select_char') == ''
            and context:get_selected_candidate() ~= nil then
            context:set_property(
                'imr_select_char',
                context:get_selected_candidate().text
            )
            -- 触发一次
            local input = context.input
            context:clear()
            -- 辅码触发
            if input:match('(.*)`') ~= nil then
                input = input:match('(.*)`')
            end
            context:push_input(input)
            return 1
        end
    end
    context:set_property('imr_select_char', '')
    return 2
end

function Translator.func(input, seg, env)
    local chars = env.engine.context:get_property('imr_select_char')
    if chars ~= '' then
        for i = 1, utf8.len(chars) do
            local char = chars:sub(
                utf8.offset(chars, i),
                utf8.offset(chars, i + 1) - 1
            )
            yield(Candidate('imr_select_char', seg.start, seg._end, char, ''))
        end
    end
end


local Filter = {
    init = function(env) end,
    func = function(input, env)
        local count = 0
        local chars = env.engine.context:get_property('imr_select_char')
        for cand in input:iter() do
            if chars == '' or cand.type == 'imr_select_char' then
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
