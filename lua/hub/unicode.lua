local M = {}

function M.setup(config, prefix)
    M.prefix = config:get_string(prefix) or "U"
end

function M.match(input)
    return string.sub(input, 1, 1) == M.prefix and string.find(string.sub(input, 2), "^[a-fA-F0-9]+$") ~= nil
end

function M.translate(input, seg)
    local r = {}
    local hex = string.sub(input, 2)
    if #hex < 2 then return r end
    local code = tonumber(hex, 16)
    if not code or code > 0x10FFFF then
        r[#r + 1] = { "数值超限！", 1 }
        return r
    end
    local text = utf8.char(code)
    r[#r + 1] = { text, 1, string.format("U%x", code) }
    if code < 0x10000 then
        for i = 0, 15 do
            local next_text = utf8.char(code * 16 + i)
            r[#r + 1] = { next_text, 1, string.format("U%x~%x", code, i) }
        end
    end
    return r
end

return M
