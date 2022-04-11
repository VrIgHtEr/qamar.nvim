---@class node_field_raw:node
---@field key node_expression
---@field value node_expression

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local expression = require('qamar.parser.production.expression').parser

local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo
local tlbracket = token.lbracket
local trbracket = token.rbracket
local tassignment = token.assignment
local nfield_raw = n.field_raw
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_field_raw
    ---@return string
    __tostring = function(self)
        return tconcat { '[', self.key, ']', '=', self.value }
    end,
}

---try to consume a lua raw table access
---@param self parser
---@return node_field_raw|nil
return function(self)
    local tok = peek(self)
    if tok and tok.type == tlbracket then
        begin(self)
        local left = take(self).pos.left
        local key = expression(self)
        if key then
            tok = take(self)
            if tok and tok.type == trbracket then
                tok = take(self)
                if tok and tok.type == tassignment then
                    local value = expression(self)
                    if value then
                        commit(self)
                        local ret = N(nfield_raw, range(left, value.pos.right), mt)
                        ret.key = key
                        ret.value = value
                        return ret
                    end
                end
            end
        end
        undo(self)
    end
end
