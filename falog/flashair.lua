--[[
Talk to Flashair v3 (~) Toshiba cards via the HTTP interface.

TODO: add API documentation link

Note:
http (socket.http) produces "Malformed request" errors with the sd httpd server,
so just use socket directly.
--]]

local socket = require('socket')

local module = {}


-- Compatibility: Lua-5.1
function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

-- The socket.http module isn't liked by the Air card httpd, so just copy the headers
-- from wget.
function sdget_stream(path)
	s = socket.connect(SDCARD_HOST, SDCARD_PORT)
    assert(s ~= nil, "failed to connect to sd card")
    request = ('GET ' .. path .. ' HTTP/1.1\r\n' ..
               'User-Agent: curl/7.40.0\r\n' ..
               'Host: ' .. SDCARD_HOST .. '\r\n' ..
               'Accept: */*\r\n' ..
               --'Connection: Keep-Alive\r\n' ..
               '\r\n')
    -- print(request .. '\n\n')
	s:send(request)
    return s
end

-- Skip HTTP headers. exercise in writing a state machine in lua.
--
-- Could be replaced with
-- the following if you have the memory for the whole HTTP response:
--
-- _, header_end = body:find('\r\n\r\n')
-- return body:sub(header_end + 1)
function skip_headers(s)
    local found = 0
    local headers = {}
    local state = 0
    local marker = {'\r', '\n', '\r', '\n'}
    local ind = 0
    while ind ~= #marker do
        -- print("state: " .. state .. "; reading 1")
        body = s:receive(1)
        if body == nil then
            break
        end
        if body == marker[ind + 1] then
            ind = ind + 1
        else
            ind = 0
        end
        headers[#headers + 1] = body
    end
    return table.concat(headers, "")
end


function module.sdget(path)
    s = sdget_stream(path)
    headers = skip_headers(s)
    -- print(headers)
	body = s:receive("*a")
    -- print(body)
	return body
end

-- Parse the SD Air card's http server directory listing. It contains name, size, date and time for
-- each file. date & time are not actually those, they are the top and bottom 16 bits of the seconds
-- since epoch of the file. They are only used comparitavely, so it doesn't matter.
function module.dir_read(path)
    -- Uses command.cgi: https://www.flashair-developers.com/en/documents/api/commandcgi/
	body = module.sdget('/command.cgi?op=100&DIR=' .. path)
	files = {}
	for k, v in ipairs((split(body, '\n'))) do
        -- print(k .. ': ' .. v)
        if k > 1 then
            parts = split(v, ',')
            root, filename, size, whatever, date, time = parts[1], parts[2], parts[3], parts[4], parts[5], string.format('%d', parts[6])
            -- print(root .. ', ' .. filename .. ', ' .. size .. ', ' .. date .. ', ' .. time)
            if filename then
                print(filename)
                table.insert(files, {["filename"] = filename,
                    ["size"] = size, ["date"] = date, ["time"] = time})
            end
        end
	end
	return files
end


return module
