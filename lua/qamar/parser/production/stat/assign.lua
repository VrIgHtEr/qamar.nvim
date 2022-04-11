---@class node_assign:node
---@field target node_varlist
---@field value node_explist

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    ---@param self node_assign
    ---@return string
    __tostring = function(self)
        return tconcat { self.target, '=', self.value }
    end,
}
local varlist = require('qamar.parser.production.varlist').parser
local explist = require('qamar.parser.production.explist').parser

local p = require 'qamar.parser'
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin
local tassignment = token.assignment
local nstat_assign = n.stat_assign
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua assignment statement
---@param self parser
---@return node_assign|nil
function M:parser()
    local target = varlist(self)
    if target then
        local tok = take(self)
        if tok and tok.type == tassignment then
            begin(self)
            local value = explist(self)
            if value then
                commit(self)
                local ret = N(nstat_assign, range(target.pos.left, value.pos.right), mt)
                ret.target = target
                ret.value = value
                return ret
            end
            undo(self)
        end
    end
end

return M
