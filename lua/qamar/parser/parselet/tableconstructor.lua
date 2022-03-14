local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

return function(self, parser, tok)
    local fieldlist = parser.fieldlist()
    if fieldlist and parser.tokenizer.peek() and parser.tokenizer.take().type == token.rbrace then
        return setmetatable({
            value = fieldlist,
            type = node.tableconstructor,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = tok.pos,
        }, MT)
    end
end
