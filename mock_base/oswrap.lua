--[[
mock of os
]]

local module = {}

local log = require 'calllog'

function module.execute(s)
    log.record('oswrap.execute', s)
    return 0,   -- success
        nil,    -- reason
        0       -- status
end

return module
