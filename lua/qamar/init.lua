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

local odir = vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/parsed'

local function parse_everything()
    local starttime = os.clock()
    os.execute("mkdir -p '" .. odir .. "'")
    local ofile = assert(io.open(odir .. '/err', 'wb'))

    local co = coroutine.create(function()
        local counter = 0
        for _, filename in ipairs(scandir(vim.fn.stdpath 'data' .. '/site')) do
            print('PARSING FILE ' .. (counter + 1) .. ': ' .. filename)
            local txt = util.read_file(filename)
            coroutine.yield()
            if txt then
                local p = create_parser(txt)
                local success, tree = pcall(p.chunk)
                if success and tree then
                    local ok, str = pcall(tostring, tree)
                    if not ok then
                        ofile:write('TOSTRING: ' .. filename .. '\n')
                        if str ~= nil then
                            ofile:write(tostring(str) .. '\n')
                        end
                        ofile:flush()
                    else
                        counter = counter + 1
                        local outpath = filename:gsub('^/home/', odir .. '/')
                        outpath = vim.fn.fnamemodify(outpath, ':p')
                        local outdir = vim.fn.fnamemodify(outpath, ':p:h')
                        os.execute("mkdir -p '" .. outdir .. "'")
                        util.write_file(outpath, str)
                    end
                else
                    ofile:write(filename .. '\n')
                    if tree ~= nil then
                        ofile:write(tostring(tree) .. '\n')
                    end
                    ofile:flush()
                end
            end
        end
        return counter
    end)
    local function step()
        local success, parsed = coroutine.resume(co)
        if success then
            local stat = coroutine.status(co)
            if stat == 'dead' then
                local time = os.clock() - starttime
                print('PARSED ' .. tostring(parsed) .. ' FILES IN ' .. tostring(time) .. ' seconds')
                ofile:close()
            else
                vim.schedule(step)
            end
        else
            ofile:close()
            print('ERROR: ' .. tostring(parsed))
        end
    end
    step()
end

function qamar.run()
    parse_everything()
end

return qamar
