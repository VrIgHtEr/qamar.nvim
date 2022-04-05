local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return '...'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local ttripledot = token.tripledot
local setmetatable = setmetatable
local nvararg = n.vararg

return function(self)
    local tok = peek(self)
    if tok and tok.type == ttripledot then
        take(self)
        return setmetatable({ type = nvararg, pos = tok.pos }, mt)
    end
end
