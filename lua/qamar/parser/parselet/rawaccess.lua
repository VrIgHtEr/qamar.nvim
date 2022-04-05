local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '[', self.key, ']' }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local begin = p.begin
local undo = p.undo
local commit = p.commit
local expression
expression = function(self)
    expression = require 'qamar.parser.production.expression'
    return expression(self)
end

return function(self, parser, left, tok)
    if
        left.type == node.name
        or left.type == node.table_nameaccess
        or left.type == node.table_rawaccess
        or left.type == node.functioncall
        or left.type == node.subexpression
    then
        local l = left.pos.left
        begin(parser)
        local exp = expression(parser)
        if not exp then
            undo(parser)
            return nil
        end
        tok = peek(parser)
        if not tok or tok.type ~= token.rbracket then
            undo(parser)
            return nil
        end
        take(parser)
        commit(parser)
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
