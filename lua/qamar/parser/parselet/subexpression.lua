---@class node_subexpression:node_expression
---@field value node_expression

local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'

local MT = {
    ---@param self node_subexpression
    ---@return string
    __tostring = function(self)
        return tconcat { '(', self.value, ')' }
    end,
}

local trparen = token.rparen
local nsubexpression = node.subexpression

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

---parselet that consumes a subexpression
---@param self parselet
---@param parser parser
---@param tok token
---@return node_subexpression|nil
return function(self, parser, tok)
    local left = tok.pos.left
    begin(parser)
    local exp = expression(parser)
    if not exp then
        undo(parser)
        return nil
    end
    tok = peek(parser)
    if not tok or tok.type ~= trparen then
        undo(parser)
        return nil
    end
    take(parser)
    commit(parser)
    local ret = N(nsubexpression, range(left, tok.pos.right), self.precedence, self.right_associative, MT)
    ret.value = exp
    return ret
end
