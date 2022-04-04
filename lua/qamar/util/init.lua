local M = {}

function M.read_file(path)
    local file, err, data = io.open(path, 'rb')
    if not file then
        return nil, err
    end
    data, err = file:read '*a'
    file:close()
    return data, err
end

function M.write_file(path, data)
    local file, err = io.open(path, 'wb')
    if not file then
        return nil, err
    end
    data, err = file:write(data)
    file:close()
    return data, err
end

function M.reverse(tbl)
    local amt = #tbl
    for i = 1, amt / 2 do
        tbl[i], tbl[amt - i + 1] = tbl[amt - i + 1], tbl[i]
    end
    return tbl
end

function M.error(...)
    local p = { ... }
    for i, x in ipairs(p) do
        p[i] = tostring(x):gsub('\\\\', '\\\\'):gsub(':', '\\:')
    end
    return nil, table.concat(p, ':')
end

function M.get_script_path(level)
    local info = debug.getinfo(1 + (level or 1), 'S')
    return info and info.source
    --    local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
    --    return script_path
end

function M.get_stack_level_string(level)
    local info = debug.getinfo(level, 'Sn')
    if info then
        local line = {}
        if info.what == 'Lua' then
            line[1] = tostring(info.name)
            line[2] = ':'
            line[3] = tostring(info.linedefined)
        end
        return table.concat(line)
    end
end

function M.print_call_stack()
    local level = 1
    print 'STACK TRACE:'
    while true do
        level = level + 1
        local str = M.get_stack_level_string(level)
        if not str then
            break
        end
        print('    ' .. level .. ': ' .. str)
    end
end

return M
