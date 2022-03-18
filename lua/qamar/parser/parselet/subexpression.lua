local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { '(', self.value, ')' }
    end,
}

return function(self, parser, tok)
    local left = tok.pos.left
    parser.tokenizer.begin()
    local exp = parser.expression()
    if not exp then
        parser.tokenizer.undo()
        return nil
    end
    tok = parser.tokenizer.peek()
    if not tok or tok.type ~= token.rparen then
        parser.tokenizer.undo()
        return nil
    end
    parser.tokenizer.take()
    parser.tokenizer.commit()
    return setmetatable({
        value = exp,
        type = node.subexpression,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = left, right = tok.pos.right },
    }, MT)
end
