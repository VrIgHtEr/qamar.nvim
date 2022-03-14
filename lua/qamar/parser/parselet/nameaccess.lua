local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'

local MT = {
    __tostring = function(self)
        return '(' .. tostring(self.value) .. ')'
    end,
}

return function(self, parser, left, tok)
    local l = left.pos.left
    tok = parser.tokenizer.peek()
    if tok and tok.type == token.name then
        parser.tokenizer.take()
        return setmetatable({
            table = left,
            key = tok,
            type = node.table_nameaccess,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = { left = l, right = tok.pos.right },
        }, MT)
    end
end
