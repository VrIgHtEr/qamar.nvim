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
    local proc = popen('find "' .. directory .. '" -maxdepth 1 -type f -name "*.lua"')
    for filename in proc:lines() do
        i = i + 1
        t[i] = filename
    end
    proc:close()
    return t
end

local function parse_everything()
    local co = coroutine.create(function()
        local counter = 0
        for _, dir in ipairs(vim.api.nvim_get_runtime_file('*/', true)) do
            for _, filename in ipairs(scandir(dir)) do
                if true or filename == '/home/cedric/.local/share/nvim/site/pack/windwp/opt/nvim-autopairs/tests/fastwrap_spec.lua' then
                    counter = counter + 1
                    print('PARSING FILE ' .. counter .. ': ' .. filename)
                    local txt = require('toolshed.util').read_file(filename)
                    coroutine.yield()
                    if txt then
                        local p = create_parser(txt)
                        local tree = p.chunk()
                        if tree then
                            --local str = tostring(tree)
                            --print(str)
                        else
                            print 'ERROR!!!!!'
                            return
                        end
                    end
                end
            end
        end
        return counter
    end)
    local function step()
        local success, err = coroutine.resume(co)
        if success then
            local stat = coroutine.status(co)
            if stat == 'dead' then
                print('PARSED ' .. err .. ' FILES')
            else
                vim.schedule(step)
            end
        else
            print('ERROR: ' .. tostring(err))
        end
    end
    step()
end

function qamar.run()
    parse_everything()
    --require('toolshed.util').write_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/test.lua', roundtripstr)
end

return qamar
