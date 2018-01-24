#!/usr/bin/env lua

local fa_debug = require('fa_debug')

fa_debug.set_debug(true)

DEBUGP(function () return 'test fa_pipe' end)

local fa_pipe = require('fa_pipe')

--local ret = fa_pipe.pipe_simple('hello', 'cat')

print("test 1")
local ret = fa_pipe.pipe_simple('hello', 'cat', true)
assert(ret == 'hello')

-- this fails - cat hangs on open /dev/stdin - since it is already open? and is a fifo?
--[[print("test 2")
local ret = fa_pipe.pipe_simple('hello', 'cat /dev/stdin', true)
assert(ret == 'hello')
]]

print("test 2")
local ret = fa_pipe.pipe_simple('print(5)', 'python', true)
assert(ret == "5")

print("test 3")
local ret = fa_pipe.pipe_simple('print(7)', 'ssh -l flashair localhost python', true)
assert(ret == "7")

--[[ see that sleep is not a problem - it isn't, but it takes a long time, so disable.
print("test 4")
local ret = fa_pipe.pipe_simple('import time; time.sleep(5); print(7)', 'ssh -l flashair localhost python', true)
assert(ret == "7")
]]


