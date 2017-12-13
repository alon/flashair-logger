local module = {}

function module.set_debug()
    _G.DEBUGP = function (f) print(string.format('DEBUG: %s', f())) end
end

function module.set_no_debug()
    _G.DEBUGP = function (f) end -- do nothing
end

return module
