---@class node_while:node
---@field body node_block
---@field condition node_expression

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    ---@param self node_while
    ---@return string
    __tostring = function(self)
        return tconcat { 'while', self.condition, 'do', self.body, 'end' }
    end,
}

local expression = require('qamar.parser.production.expression').parser
local block = require('qamar.parser.production.block').parser

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_while = token.kw_while
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local nstat_while = n.stat_while
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua while statement
---@param self parser
---@return node_while|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_while then
        local kw_while = begintake(self)
        local condition = expression(self)
        if condition then
            tok = take(self)
            if tok and tok.type == tkw_do then
                local body = block(self)
                if body then
                    tok = take(self)
                    if tok and tok.type == tkw_end then
                        commit(self)
                        local ret = N(nstat_while, range(kw_while.pos.left, tok.pos.right), mt)
                        ret.condition = condition
                        ret.body = body
                        return ret
                    end
                end
            end
        end
        undo(self)
    end
end

return M
