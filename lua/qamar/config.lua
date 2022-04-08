local M = {}
local util = require 'qamar.util'
local dbg = require 'qdbg'

M.expression_display_modes = { prefix = 'prefix', infix = 'infix', postfix = 'postfix' }
M.expression_display_mode = M.expression_display_modes.infix
M.force_unload = true
M.debug_to_string = true

local file = nil

function M.set_path(p)
    if file then
        return
    end
    file = dbg.create_fifo(p)
end

local il = 0
function M.reset()
    il = 0
end

M.indent = function()
    il = il + 1
    return M
end
M.dedent = function()
    il = il - 1
    return M
end
function M.indentlevel()
    return il
end

M.print = function(str)
    if file then
        file:write(tostring(str))
        file:write '\n'
        file:flush()
    end
    --return print(str)
end

M.space = function()
    local ret = {}
    for i = 1, il do
        ret[i] = '  '
    end
    return table.concat(ret)
end

M.trace = function(str, level)
    local s = util.get_stack_level_string(3 + (level or 0))
    return M.print(M.space() .. tostring(s) .. ': ' .. str)
end
M.itrace = function(str)
    M.trace(str, 1)
    return M.indent()
end
M.dtrace = function(str)
    M.dedent()
    return M.trace(str)
end
return M
