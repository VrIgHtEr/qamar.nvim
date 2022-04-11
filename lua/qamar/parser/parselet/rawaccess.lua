---@class node_table_rawaccess:node_expression
---@field table node_expression
---@field key node_expression

local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'

local MT = {
    ---@param self node_table_rawaccess
    ---@return string
    __tostring = function(self)
        return tconcat { self.table, '[', self.key, ']' }
    end,
}

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
    expression = require('qamar.parser.production.expression').parser
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
        local ret = N(ntable_rawaccess, range(l, tok.pos.right), self.precedence, self.right_associative, MT)
        ret.table = left
        ret.key = exp
        return ret
    end
end
