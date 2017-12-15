local fa_pipe = require('fa_pipe')


function string:split(sep)
    -- http://lua-users.org/wiki/SplitJoin
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end


function Syncer(ssh_opts, ssh_user, ssh_host, target_dir)
    local syncer = {
        ssh_opts=ssh_opts,
        ssh_user=ssh_user,
        ssh_host=ssh_host,
        target_dir=target_dir,
    }
    function syncer.need_updating(self, files)
        --[[
        Connect by ssh to host, check which of the given files need updating, based
        on same filename, different date or size
        --]]
        
		local txt = {}
        local ins = function (l) table.insert(txt, l) end
        ins('files = []')
        ins('import os')
        ins(string.format('os.chdir("%s")', self.target_dir))
        for i, v in ipairs(files) do
            table.insert(txt, string.format('files.append(["%s", "%s", "%s", "%s"])',
                         v.filename, v.size, v.date, v.time))
        end
        -- TODO: use date & time as well. right now we just assume size is good enough
        ins('ret = []')
        ins('for filename, size, date, time in files:')
        ins('    if not os.path.exists(filename):')
        ins('        ret.append(filename)')
        ins('        continue')
        ins('    s = os.stat(filename)')
        ins('    if str(s.st_size) != size:')
        ins('        ret.append(filename)')
        ins('print(",".join(ret))')
        local input = table.concat(txt, '\n')
        DEBUGP(function () return input end)
        local output = fa_pipe.pipe_simple(
            input,
            string.format('ssh %s -l %s %s python3', self.ssh_opts, self.ssh_user, self.ssh_host),
            true)
        -- TODO - check for error (output nil)
        return ipairs(output:split(','))
    end

    return syncer
end


return {Syncer=Syncer}
