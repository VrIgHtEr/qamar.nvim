local qamar = {}
local util = require 'qamar.util'
local utf8 = require('qamar.util.string').utf8
local parser = require 'qamar.parser'
local tokenizer = require 'qamar.tokenizer'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser(tokenizer(char_stream(utf8(str))))
end

local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local proc = popen('find "' .. directory .. '" -type f -name "*.lua"')
    for filename in proc:lines() do
        i = i + 1
        t[i] = filename
    end
    proc:close()
    return t
end

--while [[ true ]] ; do echo -n "\e[G\e[K" && bash -c 'find /home/cedric/luaparse/cedric -type f | wc -l' && echo -n "\e[F" && sleep 1 ; done
local odir = '/home/cedric/luaparse'

local function parse_everything()
    local starttime = os.clock()
    local co = coroutine.create(function()
        local counter = 0
        local errors = {}
        for _, filename in ipairs(scandir(vim.fn.stdpath 'data' .. '/')) do
            print('PARSING FILE ' .. (counter + 1) .. ': ' .. filename)
            local txt = util.read_file(filename)
            coroutine.yield()
            if txt then
                local p = create_parser(txt)
                local success, tree = pcall(p.chunk)
                if success and tree then
                    local ok, str = pcall(tostring, tree)
                    if not ok then
                        table.insert(errors, 'TOSTRING: ' .. filename)
                        table.insert(errors, tostring(str))
                    else
                        counter = counter + 1
                        local outpath = filename:gsub('^/home/', odir .. '/')
                        outpath = vim.fn.fnamemodify(outpath, ':p')
                        local outdir = vim.fn.fnamemodify(outpath, ':p:h')
                        os.execute("mkdir -p '" .. outdir .. "'")
                        util.write_file(outpath, str)
                    end
                else
                    table.insert(errors, filename)
                    table.insert(errors, tostring(tree))
                end
            end
        end
        return counter, errors
    end)
    local function step()
        local success, parsed, errors = coroutine.resume(co)
        if success then
            local stat = coroutine.status(co)
            if stat == 'dead' then
                for _, x in ipairs(errors) do
                    print('ERROR: ' .. x)
                end
                util.write_file(odir .. '/errors.txt', table.concat(errors, '\n'))
                local time = os.clock() - starttime
                print('PARSED ' .. tostring(parsed) .. ' FILES IN ' .. tostring(time) .. ' seconds')
            else
                vim.schedule(step)
            end
        else
            print('ERROR: ' .. tostring(parsed))
        end
    end
    step()
end

function qamar.run()
    parse_everything()
end

return qamar
