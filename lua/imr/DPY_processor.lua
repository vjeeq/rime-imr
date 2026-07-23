local Processor = {
    init = function(env)
        local engine = env.engine
        local notifier = engine.context.update_notifier:connect(function(ctx)
            local input = ctx.input
            if input == "" then return end

            local new_input = input:gsub("([a-z]+)([7890]+)$", function(letters, tones)
                if #tones == 1 then return letters .. tones end
                if #tones == 2 and tones:sub(1, 1) == tones:sub(2, 2) then
                    return letters
                end
                return letters .. tones:sub(-1)
            end)

            if new_input ~= input then
                ctx:pop_input(#input)
                ctx:push_input(new_input)
            end
        end)
        env.tone_notifier = notifier
    end,
    func = function(key, env)
        local engine = env.engine
        local context = engine.context
        if
            not key:release()
            and (context:is_composing() or context:has_menu())
        then
            local key_repr = key:repr()
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
    end,
    fini = function(env)
        env.tone_notifier:disconnect()
    end,
}

return Processor
