local module = {}

function get_sorted_keys(o)
    local keys = {}
    for k, v in pairs(o) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end


function serialize_helper(f, o)
	if type(o) == "number" then
		f:write(o)
	elseif type(o) == "string" then
		f:write(string.format("%q", o))
	elseif type(o) == "table" then
		f:write("{\n")
        local k
        local v
        -- serialize sorted values to make serialization deterministic for testing
        local sorted_keys = get_sorted_keys(o)
		for i, k in ipairs(sorted_keys) do
            local v = o[k]
			f:write('["' .. k .. '"] = ')
            DEBUGP(function () return string.format("serializing field %s", k) end)
			serialize_helper(f, v)
			f:write(",\n")
		end
		f:write("}\n")
	else
		error("cannot serialize a " .. type(o))
	end
end

function serialize(f, o)
    f:write("local data = ")
    serialize_helper(f, o)
    f:write("return data;\n")
end


function module.Syncer(sync_dir)
    local syncer = {sync_dir=sync_dir}
    -- Return true if the file has been synced to the target, checked via a local file
    -- that includes the expected file size and date
    function syncer.synced(self, filename, date, time)
        local sync_path = self.sync_dir .. "/" .. filename
        local f = io.open(sync_path, "r+")
        if not f then
            DEBUGP(function () return string.format("no sync file %s", sync_path) end)
            return false
        end
        function loader()
            local ret = f:read('*a')
            DEBUGP(function () return string.format('loader = %s', ret:gsub('\n', '\\n')) end)
            return ret
        end
        local saved = load(loader())()
        DEBUGP(function () return string.format("saved date = %s, time = %s", saved.date, saved.time) end)
        return saved.date == date and saved.time == time
    end

    function syncer.update(self, filename, date, time)
        local sync_path = self.sync_dir .. "/" .. filename
        local f = io.open(sync_path, "w+")
        -- TODO: check for f nil (open failure - ran out of disk space in production, permissions in test), fallback to syncing everything
        local data = {["date"] = date, ["time"] = time}
        serialize(f, data)
        f:close()
    end

    return syncer
end

return module
