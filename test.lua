#!/usr/bin/env lua

--[[ Note: if you do a first require the result gets cached, so require+path_update+require is no good for testing
local socket_orig = require 'socket'
print(socket_orig.connect)
]]

package.path = 'mock/?.lua;' .. package.path .. ';' .. os.getenv('HOME') .. '/.luarocks/share/lua/5.3/?.lua'

local Spy = require 'test.mock.Spy'

local io_orig = require 'io'

package.loaded.io = Spy(io_orig)

local orig_os = require 'os'

local os = require 'oswrap'
print(string.format('os.execute: %s', os.execute))

sync_sd_to_remote = require 'sync_sd_to_remote'

DEBUG=true

sync_sd_to_remote.main()

log = require('calllog')

local replay_filename = 'replay.txt'
success, it = pcall(function () return io.lines(replay_filename) end)
if not success then
    print("no replay file. log:")
    print("--------------------")
    for i, v in ipairs(log.log) do
        print(table.concat(v, ' | '))
    end
else
    lines = {}
    for line in it do
        table.insert(lines, line)
    end
    for i=1, #log.log, 1 do
        expected = table.concat(log.log[i], ' | ')
        actual = lines[i]
        if expected ~= actual then
            print(string.format("mismatch in line %s: expected %s != %s\n", i, expected, actual))
            orig_os.exit(-1)
        end
    end
end
