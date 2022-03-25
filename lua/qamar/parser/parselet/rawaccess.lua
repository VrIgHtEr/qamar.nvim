local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '[', self.key, ']' }
    end,
}

return function(self, parser, left, tok)
    if
        left.type == node.name
        or left.type == node.table_nameaccess
        or left.type == node.table_rawaccess
        or left.type == node.functioncall
        or left.type == node.subexpression
    then
        local l = left.pos.left
        parser.tokenizer:begin()
        local exp = parser.expression()
        if not exp then
            parser.tokenizer:undo()
            return nil
        end
        tok = parser.tokenizer:peek()
        if not tok or tok.type ~= token.rbracket then
            parser.tokenizer:undo()
            return nil
        end
        parser.tokenizer:take()
        parser.tokenizer:commit()
        return setmetatable({
            table = left,
            key = exp,
            type = node.table_rawaccess,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = { left = l, right = tok.pos.right },
        }, MT)
    end
end
