local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return self.value
    end,
}
return function(self)
    local tok = self:peek()
    if tok and tok.type == token.name then
        self:take()
        return setmetatable({ value = tok.value, type = n.name, pos = tok.pos }, mt)
    end
end
