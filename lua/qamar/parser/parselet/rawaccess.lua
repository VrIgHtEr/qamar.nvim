local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '[', self.key, ']' }
    end,
}

local setmetatable = setmetatable
local nname = node.name
local ntable_nameaccess = node.table_nameaccess
local ntable_rawaccess = node.table_rawaccess
local nfunctioncall = node.functioncall
local nsubexpression = node.subexpression
local trbracket = token.rbracket
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
    if left.type == nname or left.type == ntable_nameaccess or left.type == ntable_rawaccess or left.type == nfunctioncall or left.type == nsubexpression then
        local l = left.pos.left
        begin(parser)
        local exp = expression(parser)
        if not exp then
            undo(parser)
            return nil
        end
        tok = peek(parser)
        if not tok or tok.type ~= trbracket then
            undo(parser)
            return nil
        end
        take(parser)
        commit(parser)
        return setmetatable({
            table = left,
            key = exp,
            type = ntable_rawaccess,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = { left = l, right = tok.pos.right },
        }, MT)
    end
end
