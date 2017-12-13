--[[
Log arbitrary arguments. Used by the mocks in mock. Allows testing for regression
by recording a set of correct calls.
]]

local module = {}

module.log = {}

function module.record(...)
    table.insert(module.log, table.pack(...))
end

return module
