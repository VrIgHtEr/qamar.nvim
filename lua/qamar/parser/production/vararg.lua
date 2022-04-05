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

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.tripledot then
        take(self)
        return setmetatable({ type = n.vararg, pos = tok.pos }, mt)
    end
end
