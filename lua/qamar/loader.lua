local utf8 = require('qamar.util.string').utf8
local parser = require 'qamar.parser'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser(tokenizer(char_stream.new(utf8(str))))
end

local function get_runtime_paths()
    local delimiter = ','
    local ret = {}
    for path in vim.o.runtimepath:gmatch('([^,]*)' .. delimiter) do
        table.insert(ret, path)
    end
    return ret
end

return function(modulename)
    modulename = string.gsub(modulename, '%.', '/')
    for _, runtimepath in ipairs(get_runtime_paths()) do
        local path = runtimepath .. '/lua/' .. modulename
        local path2 = runtimepath .. '/lua/' .. modulename .. '/init.qamar'
        path = path .. '.qamar'
        local file = io.open(path, 'rb')
        if not file then
            path = path2
            file = io.open(path, 'rb')
        end
        if file then
            local str = file:read '*a'
            file:close()
            local chunk = create_parser(str).chunk()
            if chunk then
                local chunkstr = tostring(chunk)
                if chunkstr then
                    local loaded = load(chunkstr, path)
                    if loaded then
                        return loaded
                    end
                end
            end
        end
    end
    return ''
end
