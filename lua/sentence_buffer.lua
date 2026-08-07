-- Sentence-mode separator injector.
-- Space and topup append an apostrophe boundary while preserving the complete
-- composition. A second space on an empty segment commits the composition.
local M = {}
local kAccepted, kNoop = 1, 2
local function current_chunk(input, separator)
  local sep = separator or "'"
  local pattern = "([^" .. sep .. "]*)$"
  return input:match(pattern) or ''
end
function M.processor(key,env)
  if not key or (key.release and key:release()) then return kNoop end
  local ctx=env and env.engine and env.engine.context
  if not ctx or not ctx:get_option('sentence_mode_enabled') then return kNoop end
  local input=tostring(ctx.input or '')
  -- Read the configured sentence-mode prefix from schema config.
  local config = env and env.engine and env.engine.schema and env.engine.schema.config
  local prefix = "'"
  if config and type(config.get_string) == "function" then
    local ok, value = pcall(function() return config:get_string('sentence_mode/prefix') end)
    if ok and type(value) == "string" and #value == 1 then prefix = value end
  end
  if input:sub(1,1) ~= prefix then return kNoop end
  -- input 恰好是前缀本身时（如单独的 a），不拦截，让主词库翻译出候选
  if #input <= #prefix then return kNoop end
  local repr=key.repr and key:repr() or ''
  local chunk=current_chunk(input, "'")  -- separator inside chunks stays as '
  if repr=='space' then
    if chunk=='' then if ctx.commit then ctx:commit(); return kAccepted end; return kNoop end
    ctx.input=input.."'"; return kAccepted  -- append ' as the internal separator
  end
  return kNoop
end
function M.init(env) end
function M.func(a,b) return M.processor(a,b) end
return M
