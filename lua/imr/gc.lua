local function gc()
    collectgarbage("step")
end
return gc
