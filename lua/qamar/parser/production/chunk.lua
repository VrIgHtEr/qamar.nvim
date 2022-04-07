local p = require 'qamar.parser'
local peek = p.peek
local block = require 'qamar.parser.production.block'
local N = require 'qamar.parser.node'
local nblock = require('qamar.parser.types').block
local range = require 'qamar.util.range'
local spos = p.pos

local empty_mt = {
    __tostring = function()
        return ''
    end,
}
---try to parse a lua chunk
---@param self parser
---@return node_block
return function(self)
    if peek(self) then
        self.cache = {}
        local ret = block(self)
        self.cache = nil
        local nxt = self.la[self.la.size()] or nil
        if ret then
            if nxt then
                error('UNMATCHED TOKEN: ' .. tostring(nxt) .. ' at line ' .. nxt.pos.left.row .. ', col ' .. nxt.pos.left.col)
            end
            return ret
        elseif nxt then
            error('UNMATCHED TOKEN: ' .. tostring(nxt) .. ' at line ' .. nxt.pos.left.row .. ', col ' .. nxt.pos.left.col)
        else
            error('PARSE_FAILURE' .. ' at line ' .. nxt.pos.left.row .. ', col ' .. nxt.pos.left.col)
        end
    else
        return N(nblock, range(spos(self), spos(self)), empty_mt)
    end
end
