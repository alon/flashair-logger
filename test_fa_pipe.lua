#!/usr/bin/env lua

local fa_debug = require('fa_debug')

fa_debug.set_debug()

DEBUGP(function () return 'test sshpipe' end)

local sshpipe = require('sshpipe')

--local ret = sshpipe.pipe_simple('hello', 'cat')

local ret = sshpipe.pipe_simple('hello', 'cat', true)
assert(ret == 'hello')

