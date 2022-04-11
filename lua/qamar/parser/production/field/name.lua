---@class node_field_name:node
---@field key string
---@field value node_expression

local tconcat = require('qamar.util.table').tconcat
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require('qamar.parser.production.expression').parser
local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo

local tname = token.name
local tassignment = token.assignment
local nfield_name = n.field_name
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_field_name
    ---@return string
    __tostring = function(self)
        return tconcat { self.key, '=', self.value }
    end,
}

---try to consume a lua table field with a name
---@param self parser
---@return node_field_name|nil
return function(self)
    local key = peek(self)
    if key and key.type == tname then
        begin(self)
        local left = take(self).pos.left
        local tok = take(self)
        if tok and tok.type == tassignment then
            local value = expression(self)
            if value then
                commit(self)
                local ret = N(nfield_name, range(left, value.pos.right), mt)
                ret.key = key.value
                ret.value = value
                return ret
            end
        end
        undo(self)
    end
end
