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

function M.get_script_path()
    local info = debug.getinfo(1, 'S')
    local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
    return script_path
end

return M