--[[ mock of posix ]]

local module = {}

local log = require 'calllog'

function module.fork(s)
    -- not simulating actual fork, but we can mock the result (basically this means we fail to check some of the code - on the path where this function returns 0
    log.record("posix.fork", s)
    return 1
end

function module.wait(pid)
    log.record("posix.wait", pid)
    return 0
end

return module
