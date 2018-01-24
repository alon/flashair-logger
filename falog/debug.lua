local module = {}

function module.set_debug(state)
    if state then
        _G.DEBUGP = function (f) print(string.format('DEBUG: %s', f())) end
    else
        _G.DEBUGP = function (f) end -- do nothing
    end
end

return module
