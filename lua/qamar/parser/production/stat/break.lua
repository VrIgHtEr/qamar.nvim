local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return 'break'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_break then
        take(self)
        return setmetatable({ type = n.stat_break, pos = tok.pos }, mt)
    end
end
