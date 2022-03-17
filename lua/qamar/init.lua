local qamar = {}
local codepoints = require('toolshed.util.string').codepoints
local parser = require 'qamar.parser'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser(tokenizer(char_stream(codepoints(str))))
end

local function get_script_path()
    local info = debug.getinfo(1, 'S')
    local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
    return script_path
end

local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('find "' .. directory .. '" -maxdepth 1 -type f -name "*.lua"'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end

local function parse_everything()
    local co = coroutine.create(function()
        for _, dir in ipairs(vim.api.nvim_get_runtime_file('*/', true)) do
            for _, filename in ipairs(scandir(dir)) do
                if filename == '/home/cedric/.local/share/nvim/site/pack/windwp/opt/nvim-autopairs/tests/fastwrap_spec.lua' then
                    print('PARSING: ' .. filename)
                    local txt = require('toolshed.util').read_file(filename)
                    print(txt)
                    coroutine.yield()
                    if txt then
                        local p = create_parser(txt)
                        local tree = p.chunk()
                        if tree then
                            print(tostring(tree))
                        else
                            print 'ERROR!!!!!'
                            return
                        end
                    end
                end
            end
        end
    end)
    local function step()
        local success = coroutine.resume(co)
        if success and coroutine.status(co) ~= 'dead' then
            vim.schedule(step)
        end
    end
    step()
end

function qamar.run()
    parse_everything()
    --require('toolshed.util').write_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/test.lua', roundtripstr)
end

return qamar
