local p = require 'qamar.parser'
local peek = p.peek
local block = require 'qamar.parser.production.block'
local N = require 'qamar.parser.node'
local nblock = require('qamar.parser.types').block
local range = require 'qamar.util.range'
local spos = p.pos
local deque = require 'qamar.util.deque'

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
        local cache = {}
        self.cache = cache
        local cache_mapping = deque()
        self.cache_mapping = cache_mapping
        self.on_flush = function(id)
            while true do
                local f = self.cache_mapping.peek_front()
                if not f or f >= id then
                    break
                end
                cache[f] = nil
                self.cache_mapping.pop_front()
            end
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
