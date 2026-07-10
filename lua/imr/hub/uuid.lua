local fmt = string.format
local rand = math.random

local M = {}

function M.setup(config, prefix)
    M.trigger = config:get_string(prefix) or "uuid"
    math.randomseed(math.floor(os.time() + os.clock() * 1000))
end

function M.match(input)
    return input == M.trigger
end

function M.translate(input, seg)
    local uuid = fmt(
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        rand(0, 255), rand(0, 255), rand(0, 255), rand(0, 255),
        rand(0, 255), rand(0, 255),
        (rand(0, 255) % 16) + 64, rand(0, 255),
        (rand(0, 255) % 64) + 128, rand(0, 255),
        rand(0, 255), rand(0, 255), rand(0, 255), rand(0, 255),
        rand(0, 255), rand(0, 255)
    )
    return { { uuid, 100 } }
end

return M
