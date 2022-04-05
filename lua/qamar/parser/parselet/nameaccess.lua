local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '.', self.key }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take

return function(self, parser, left, tok)
    if
        left.type == node.name
        or left.type == node.table_nameaccess
        or left.type == node.table_rawaccess
        or left.type == node.functioncall
        or left.type == node.subexpression
    then
        local l = left.pos.left
        tok = peek(parser)
        if tok and tok.type == token.name then
            take(parser)
            local ret = setmetatable({
                table = left,
                key = tok,
                type = node.table_nameaccess,
                precedence = self.precedence,
                right_associative = self.right_associative,
                pos = { left = l, right = tok.pos.right },
            }, MT)
            return ret
        end
    end
end
