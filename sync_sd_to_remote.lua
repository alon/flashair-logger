#!/usr/bin/lua

--[[
 Written by Alon Levy

 This file is in the public domain. It's been mostly a learning experience with
 lua and it is not very pretty. I hope it will be some help to someone
 nontheless!

TODO:
 - all file writing must be checked for errors (open, write, read)
 - if card is not accessed, send server a notification
  - ssh echo "could not read card <DATE> - not seeing wifi/http error/other reason" > TARGET_PATH/logger_error.txt
 - if any fails, fallback to syncing all files without caching test
 - use a single file for all cache, write a line per file in it (can sort it and then can do search on it)

]]


local socket = require("socket")
local posix = require("posix")
local os = require('oswrap') -- cannot require os, it is a hard coded module, not looked up in package.path (could fix this with a C written tester)
local io = require('iowrap')
local fa_sync = require('fa_sync')
local fa_pipe = require('fa_pipe')
local fa_debug = require('fa_debug')
local flashair = require('fa_flashair')

local module = {}

-- Development defaults, use sdcardemul.py as the server.
SDCARD_HOST = "127.0.0.1"
SDCARD_PORT = 8000
TARGET_PATH = "/home/flashair/data-logger"
SYNC_DIR = "/tmp/sync"
SSH_OPTS = ""
SSH_USER = 'flashair'
SSH_HOST = 'localhost'
DEBUG = false


-- ssh file to remote, using ssh and not scp to use local stdin for the contents,
-- avoiding a temporary file (sd can be much larger then the local storage on the openwrt)
function sync(filename, contents)
    local cmd = 'ssh ' .. SSH_OPTS .. ' -l ' .. SSH_USER .. ' ' .. SSH_HOST .. ' "cat > ' .. TARGET_PATH .. '/' .. filename .. '"'
    DEBUGP(function () return cmd end)
    return fa_pipe.pipe_simple(contents, cmd)
end

function module.main()
    -- Load config file
    if arg[1] then
        dofile(arg[1])
    end

    if DEBUG then
        fa_debug.set_debug()
    else
        fa_debug.set_no_debug()
    end
    print("Welcome to sync sd to remote")
    print("SD:         " .. SDCARD_HOST .. ':' .. SDCARD_PORT)
    print("SSH:        " .. SSH_USER .. ' at ' .. SSH_HOST)
    print("SSH_OPTS:   " .. SSH_OPTS)
    print("SYNC dir:   " .. SYNC_DIR)
    print("TARGET path: " .. TARGET_PATH)
    if DEBUG then
        print("!!! DEBUG !!!")
    end

	print("starting sync")
    os.execute('mkdir -p ' .. SYNC_DIR)
	files = flashair.dir_read("/CSVFILES/LOG")

    local syncer = fa_sync.Syncer(SYNC_DIR)

    local k
    local v
	for k, v in ipairs(files) do
		if not syncer:synced(v.filename, v.date, v.time) then
            print("syncing " .. v.filename .. ' (' .. v.size .. ')')
			file_body = flashair.csvfile_get(v.filename)
            if sync(v.filename, file_body) ~= 0 then
                print("ERROR syncing " .. v.filename .. ", skipping it (not updating sync file)")
            else
                syncer:update(v.filename, v.date, v.time)
            end
        end
	end
	print("ended sync")
end

return module
