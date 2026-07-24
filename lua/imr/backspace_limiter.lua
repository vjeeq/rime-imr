--- 防止长按退格键在删完拼音后继续删除已上屏文字。
--- 放开退格后再按可正常删除文字。

local Processor = {}

function Processor.init(env)
    env.bs_deleting_preedit = false
end

function Processor.func(key, env)
    if key.keycode ~= 0xFF08 then
        return 2 -- kNoop
    end
    if key:release() then
        env.bs_deleting_preedit = false
        return 2
    end

    local input = env.engine.context.input
    if input ~= "" then
        env.bs_deleting_preedit = true
        return 2
    end

    if env.bs_deleting_preedit then
        return 1 -- kAccepted: 拦截
    end
    return 2
end

return Processor
