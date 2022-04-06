local p = require 'qamar.parser'
local peek = p.peek
local block = require 'qamar.parser.production.block'
local setmetatable = setmetatable

return function(self)
    if peek(self) then
        self.cache = {}
        local ret = block(self)
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
        return setmetatable({}, {
            __tostring = function()
                return ''
            end,
        })
    end
end
