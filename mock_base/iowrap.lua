local module = {}

local log = require 'calllog'

function dump_table(t)
    if not type(t) == 'table' then
        return
    end
    for k, v in pairs(t) do
        print(string.format("DUMP %s=%s", k, v))
    end
end


function module.open(filename)
    local ret = {}
    log.record('io.open', filename)
    function ret.read(self, options)
        local date = '123' -- TODO use same that sdcardemul returns
        local time = '123' -- TODO use same that sdcardemul returns
        local ret = string.format("local data = {['date']=%s, ['time']=%s}; return data;", date, time)
        log.record("io.read", filename, options, ret)
        return ret
    end
    function ret.write(self, stuff)
        log.record("io.write", filename, stuff:gsub('\n', '\\n'))
        return #stuff
    end
    function ret.close(self)
        log.record("io.close", filename)
        return 0
    end
    return ret
end

return module
