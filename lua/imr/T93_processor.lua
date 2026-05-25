---@param text string
---@return boolean is_word
---@return string rest_text
local function is_word(text)
    if text:match('^[1-9][0-9][0-9][a-e]') then
        return true, text:sub(5)
    end
    if text:match('^[1-9][0-9][0-9]') then
        return true, text:sub(4)
    end
    return false, text
end
---@param _text string
---@return string rest_text
local function ignore_word(_text)
    local flag, text = true, _text
    while flag do
        flag, text = is_word(text)
    end
    return text
end
local Processor = {
    init = function(env) end,
    func = function(key, env)
        local engine = env.engine
        local context = engine.context
        if
            not key:release()
            and (context:is_composing() or context:has_menu())
        then
            local key_repr = key:repr()
            -- 前面是完整拼音，后面输入的第一个0视为`
            if key_repr == '0' then
                local text = ignore_word(context.input:sub(1, context.caret_pos))
                if text == '' or text == '`' then
                    -- 在最后加`
                    local caret_pos = context.caret_pos == #context.input and #context.input + 1 or context.caret_pos
                    context.input = context.input .. '`'
                    context.caret_pos = caret_pos
                    return 1
                end
            end
            -- 输入的是声调，如果前面的拼音不完整，自动补零
            if key_repr:match('^[a-e]$') then
                local text = ignore_word(context.input:sub(1, context.caret_pos))
                if text:match('^[1-9]$') then
                    context:push_input('00')
                    context:push_input(key_repr)
                    return 1
                end
                if text:match('^[1-9][0-9]$') then
                    context:push_input('0')
                    context:push_input(key_repr)
                    return 1
                end
                -- 如果前面是声调，这次输入就是更改声调
                if text == '' and context.input:sub(context.caret_pos, context.caret_pos):match('[a-e]') then
                    -- 声调一致，取消声调
                    if context.input:sub(context.caret_pos, context.caret_pos) == key_repr then
                        context:pop_input(1)
                        return 1
                    end
                    context:pop_input(1)
                    context:push_input(key_repr)
                    return 1
                end
            end

            -- 辅码模式处理，允许tab后输入/删除辅码
            if context.input:match('`') then
                if key_repr:match('^[0-9]$') then
                    local caret_pos = context.caret_pos == #context.input and #context.input + 1 or context.caret_pos
                    context.input = context.input .. key_repr
                    context.caret_pos = caret_pos
                    return 1
                end
                if key_repr == 'BackSpace' then
                    local caret_pos = context.caret_pos == #context.input and #context.input + 1 or context.caret_pos
                    context.input = context.input:sub(1, #context.input - 1)
                    context.caret_pos = caret_pos
                    return 1
                end
            end
        end
        return 2
    end
}

return Processor
