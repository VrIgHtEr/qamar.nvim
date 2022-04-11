local qamar = {}
local util = require 'qamar.util'
local parser = require 'qamar.parser'

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
local idir = vim.fn.stdpath 'data' .. '/site/pack'
local cfg = require 'qamar.config'
local print = cfg.print
local dbg = require 'qdbg'

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local p = math.random(i)
        tbl[i], tbl[p] = tbl[p], tbl[i]
    end
end

local types = require 'qamar.parser.types'
local function tostring_tree(tree)
    return vim.inspect(tree, {
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
    })
end

local function parse_everything()
    os.execute("rm -rf '" .. odir .. "'")
    local files = scandir(idir)
    shuffle(files)
    os.execute("mkdir -p '" .. odir .. "'")
    cfg.set_path(logpath .. '/out')
    local ofile = assert(dbg.create_fifo(logpath .. '/err'))
    ofile:write '\n'
    ofile:flush()
    cfg.print '\n'

    local starttime = os.clock()
    local co = coroutine.create(function()
        dbg.stats = {}
        local counter = 0
        local tlen = 0
        for _, filename in ipairs(files) do
            if true or filename:match '^.*/test.lua' then
                print '-----------------------------------------------------------------------------------'
                print('PARSING FILE ' .. (counter + 1) .. ': ' .. filename)
                local txt = util.read_file(filename)
                coroutine.yield()
                if txt then
                    local success, tree = pcall(parser.parse, txt)
                    if success and tree then
                        local ok, str
                        if cfg.debug_to_string then
                            ok, str = pcall(tostring, tree)
                        else
                            ok, str = true, nil
                        end
                        if not ok then
                            ofile:write('TOSTRING: ' .. filename .. '\n')
                            if str ~= nil then
                                ofile:write(tostring(str) .. '\n')
                            end
                            ofile:flush()
                        else
                            counter = counter + 1
                            if cfg.debug_to_string then
                                local outpath = filename:gsub('^/home/', odir .. '/')
                                outpath = vim.fn.fnamemodify(outpath, ':p')
                                local outdir = vim.fn.fnamemodify(outpath, ':p:h')
                                os.execute("mkdir -p '" .. outdir .. "'")
                                util.write_file(outpath, str)
                                if false then
                                    print(tostring_tree(tree))
                                end
                                tlen = tlen + string.len(str)
                                print(str)
                            end
                        end
                    else
                        ofile:write(filename .. '\n')
                        if tree ~= nil then
                            local str = tostring(tree)
                            local idx = str:find ': '
                            if idx then
                                str = str:sub(idx + 2)
                            end
                            ofile:write(str .. '\n')
                        end
                        ofile:flush()
                    end
                end
            end
        end

        ofile:write('total length: ' .. tlen .. '\n')
        ofile:flush()
        local total = 0
        for _, v in pairs(dbg.stats) do
            total = total + v
        end
        if total > 0 then
            local stats = {}
            for k, v in pairs(dbg.stats) do
                table.insert(stats, { name = k, frequency = v / total })
            end
            table.sort(stats, function(a, b)
                return a.frequency > b.frequency
            end)
            print ''
            for _, x in ipairs(stats) do
                print(x.name .. ': ' .. (x.frequency * 100) .. '%')
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
