local p = require 'qamar.parser'
local peek = p.peek
local block = require('qamar.parser.production.block').parser
local N = require 'qamar.parser.node'
local nblock = require('qamar.parser.types').block
local range = require 'qamar.util.range'
local spos = p.pos

local empty_mt = {
    __tostring = function()
        return ''
    end,
}

local chunk = {}

---try to parse a lua chunk
---@param self parser
---@return node_block
function chunk:parser()
    if peek(self) then
        self.cache = {}
        self.on_flush = function()
            self.cache = {}
        end
        local success, ret = pcall(block, self)
        self.on_flush = nil
        self.cache = nil
        self.cache_mapping = nil
        if not success then
            error(ret)
        end
        local nxt = self.la[self.la.size()] or nil
        if ret then
            if nxt then
                error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
            end
            return ret
        elseif nxt then
            error(tostring(nxt.pos.left) .. ':UNMATCHED_TOKEN: ' .. tostring(nxt))
        else
            error(tostring(nxt.pos.left) .. ':PARSE_FAILURE')
        end
    else
        return N(nblock, range(spos(self), spos(self)), empty_mt)
    end
end

return chunk
