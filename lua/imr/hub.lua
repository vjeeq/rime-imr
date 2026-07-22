local modules = {
    date   = require("imr.hub.date"),
    lunar  = require("imr.hub.lunar"),
    uuid   = require("imr.hub.uuid"),
    unicode = require("imr.hub.unicode"),
    number = require("imr.hub.number"),
    calculator = require("imr.hub.calculator"),
}

local order = { "date", "lunar", "uuid", "unicode", "number", "calculator" }

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    for _, name in ipairs(order) do
        local mod = modules[name]
        if mod and mod.setup then
            mod.setup(config, "hub/" .. name)
        end
    end
end

function M.func(input, seg)
    for _, name in ipairs(order) do
        local mod = modules[name]
        if mod.match and mod.match(input) then
            local cands = mod.translate(input, seg)
            if cands then
                for _, c in ipairs(cands) do
                    local cand = Candidate("hub", seg.start, seg._end, c[1], c[3] or "")
                    cand.quality = tonumber(c[2]) or 100
                    if c[4] then cand.preedit = c[4] end
                    yield(cand)
                end
            end
            break
        end
    end
end

return M
