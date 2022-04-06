---@class node_table_nameaccess:node_expression
---@field table node_expression
---@field key string

local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'
local nname = node.name
local ntable_nameaccess = node.table_nameaccess
local ntable_rawaccess = node.table_rawaccess
local nfunctioncall = node.functioncall
local nsubexpression = node.subexpression
local tname = token.name

local MT = {
    ---@param self node_table_nameaccess
    ---@return string
    __tostring = function(self)
        return tconcat { self.table, '.', self.key }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take

---parselet that consumes a named table access
---@param self parselet
---@param parser parser
---@param left node_expression
---@param tok token
---@return node_table_nameaccess
return function(self, parser, left, tok)
    if left.type == nname or left.type == ntable_nameaccess or left.type == ntable_rawaccess or left.type == nfunctioncall or left.type == nsubexpression then
        local l = left.pos.left
        tok = peek(parser)
        if tok and tok.type == tname then
            take(parser)
            local ret = N(ntable_nameaccess, range(l, tok.pos.right), self.precedence, self.right_associative, MT)
            ret.table = left
            ret.key = tok.value
            return ret
        end
    end
end
