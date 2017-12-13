local posix = require('posix')
local iowrap = require('iowrap')

local module = {}

-- TODO: use pipes instead of system files for this - just seems ugly (/tmp is a tmpfs, target hw has 16MB memory, so not a memory issue)
local IN_FIFO = '/tmp/flashair_in_fifo'
local OUT_FIFO = '/tmp/flashair_out_fifo'


function ensure_fifo_exists(fifo)
    os.execute('[ ! -e ' .. fifo .. ' ] && mkfifo ' .. fifo)
end


-- We open a fifo so we must background it or be blocked.
function background_write(filename, text)
    local pid, err = posix.fork()
    assert(pid ~= nil, "fork() failed")
    if pid == 0 then
        DEBUGP(function () return string.format('if parent; filename = %s', filename) end)
        local f = io.open(filename, "w")
        f:write(text)
        f:close()
        posix._exit(0)
        return
    end
    return pid
end

-- Note: previous version used popen3, avoiding the need for the fifo. But the
-- openwrt's luaposix package doesn't support popen and dup2. This works just as well.
function module.pipe_simple(input, cmd, get_output)
    
    ensure_fifo_exists(IN_FIFO)
    ensure_fifo_exists(OUT_FIFO)

    local pid = background_write(IN_FIFO, input)
    local full_cmd
    if get_output then
        full_cmd = string.format('%s < %s > %s &', cmd, IN_FIFO, OUT_FIFO)
    else
        full_cmd = string.format('%s < %s', cmd, IN_FIFO)
    end
    DEBUGP(function () return string.format("cmd = %s, get_output = %s", full_cmd, get_output) end)
    local ret
    local success, reason, status = os.execute(full_cmd)
    if get_output then
        local f = iowrap.open(OUT_FIFO)
        ret = f:read()
        DEBUGP(function () return string.format("read %s bytes", #ret) end)
    end
    DEBUGP(function () return string.format("pid = %s", pid) end)
    posix.wait(pid)
    DEBUGP(function () return string.format("status = %s; success = %s; reason = %s", status, success, reason) end)
    if get_output then
        return ret
    end
    if success == 0 then
        return 0
    else
        return status
    end
end

return module
