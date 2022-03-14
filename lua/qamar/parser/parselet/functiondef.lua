local node = require 'qamar.parser.types'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

return function(self, parser, tok)
    local body = parser.funcbody()
    if body then
        return setmetatable({
            value = body,
            type = node.functiondef,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = tok.pos,
        }, MT)
    end
end
