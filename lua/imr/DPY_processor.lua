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
            -- 声调快速修改：6=一声 7=二声 8=三声 9=四声 0=轻声
            if key_repr:match('^[67890]$') then
                local text = context.input
                if not text:match(';') then
                    local last = text:sub(-1)
                    if last:match('^[67890]$') then
                        if last == key_repr then
                            context.input = text:sub(1, -2)
                        else
                            context.input = text:sub(1, -2) .. key_repr
                        end
                        return 1
                    elseif text:match('[a-z][a-z]$') then
                        context.input = text .. key_repr
                        return 1
                    end
                end
            end
            -- 辅码模式处理，允许输入/删除辅码
            if context.input:match(';') then
                if key_repr:match('^[a-z]$') then
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
