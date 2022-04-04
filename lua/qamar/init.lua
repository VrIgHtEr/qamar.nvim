local qamar = {}
local util = require 'qamar.util'
local utf8 = require('qamar.util.string').utf8
local parser = require 'qamar.parser'
local char_stream = require 'qamar.tokenizer.char_stream'

local function create_parser(str)
    return parser.new(char_stream.new(utf8(str)))
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

local logpath = vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim'
local odir = vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/parsed'
--odir = '/mnt/c/luaparse'
local idir = vim.fn.stdpath 'data' .. '/site/pack/vrighter'
local cfg = require 'qamar.config'
local print = cfg.print
local dbg = require 'qdbg'

local function parse_everything()
    local starttime = os.clock()
    os.execute("rm -rf '" .. odir .. "'")
    local files = scandir(idir)
    os.execute("mkdir -p '" .. odir .. "'")
    cfg.set_path(logpath .. '/out')
    local ofile = assert(dbg.create_fifo(logpath .. '/err'))
    ofile:write '\n'
    ofile:flush()
    cfg.print '\n'

    local types = require 'qamar.parser.types'

    local co = coroutine.create(function()
        local counter = 0
        for _, filename in ipairs(files) do
            if true or filename:match '^.*/test.lua' then
                print '-----------------------------------------------------------------------------------'
                print('PARSING FILE ' .. (counter + 1) .. ': ' .. filename)
                local txt = util.read_file(filename)
                coroutine.yield()
                if txt then
                    local p = create_parser(txt)
                    local success, tree = pcall(p.chunk, p)
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
                            --[[
                            print(vim.inspect(tree, {
                                process = function(item, path)
                                    local x = path[#path]
                                    if x ~= 'precedence' and x ~= 'right_associative' and tostring(x) ~= 'inspect.METATABLE' then
                                        if x == 'type' then
                                            return types[item] or item
                                        end
                                        if x == 'pos' then
                                            return item.left.row .. ':' .. item.left.col .. ' - ' .. item.right.row .. ':' .. item.right.col
                                        end
                                        return item
                                    end
                                end,
                            }))
                            ]]
                            print(tree)
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
        end
        return counter, #files
    end)
    local function step()
        local success, parsed, total = coroutine.resume(co)
        if success then
            local stat = coroutine.status(co)
            if stat == 'dead' then
                local time = os.clock() - starttime
                local message = 'PARSED ' .. tostring(parsed) .. ' OF ' .. total .. ' FILES IN ' .. tostring(time) .. ' seconds'
                print(message)
                ofile:write(message .. '\n')
                ofile:flush()
            else
                vim.schedule(step)
            end
        else
            print('ERROR: ' .. tostring(parsed))
            ofile:write('ERROR: ' .. tostring(parsed) .. '\n')
            ofile:flush()
        end
    end
    step()
end

function qamar.run()
    parse_everything()
end

return qamar
