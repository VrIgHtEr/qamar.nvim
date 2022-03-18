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

local util = require 'toolshed.util'

local function parse_everything()
    local co = coroutine.create(function()
        local counter = 0
        for _, dir in ipairs(vim.api.nvim_get_runtime_file('*/', true)) do
            for _, filename in ipairs(scandir(dir)) do
                if filename ~= '/home/cedric/.local/share/nvim/env/share/nvim/runtime/lua/man.lua' then
                    print('PARSING FILE ' .. (counter + 1) .. ': ' .. filename)
                    local txt = require('toolshed.util').read_file(filename)
                    coroutine.yield()
                    if txt then
                        local p = create_parser(txt)
                        local tree = p.chunk()
                        if tree then
                            counter = counter + 1
                            local str = tostring(tree)
                            local outpath = filename:gsub('^/home/', '/mnt/c/luaparse/')
                            outpath = vim.fn.fnamemodify(outpath, ':p')
                            local outdir = vim.fn.fnamemodify(outpath, ':p:h')
                            os.execute("mkdir -p '" .. outdir .. "'")
                            util.write_file(outpath, str)
                            --print(str)
                        else
                            print 'ERROR!!!!!'
                            return counter
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
                print('PARSED ' .. tostring(err) .. ' FILES')
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
end

return qamar
