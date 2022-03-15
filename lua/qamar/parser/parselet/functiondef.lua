local node = require 'qamar.parser.types'

local MT = {
    __tostring = function(self)
        return 'function' .. tostring(self.value)
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
            pos = { left = tok.pos.left, right = body.pos.right },
        }, MT)
    end
end
