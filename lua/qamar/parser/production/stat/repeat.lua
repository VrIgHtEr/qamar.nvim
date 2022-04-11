---@class node_repeat:node
---@field body node_block
---@field condition node_expression

local tconcat = require('qamar.util.table').tconcat

local mt = {
    ---@param self node_repeat
    ---@return string
    __tostring = function(self)
        return tconcat { 'repeat', self.body, 'until', self.condition }
    end,
}

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local block = require('qamar.parser.production.block').parser
local expression = require('qamar.parser.production.expression').parser

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_repeat = token.kw_repeat
local tkw_until = token.kw_until
local nstat_repeat = n.stat_repeat
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua repeat statement
---@param self parser
---@return node_repeat|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_repeat then
        local kw_repeat = begintake(self)

        local body = block(self)
        if body then
            tok = take(self)
            if tok and tok.type == tkw_until then
                local condition = expression(self)
                if condition then
                    commit(self)
                    local ret = N(nstat_repeat, range(kw_repeat.pos.left, condition.pos.right), mt)
                    ret.body = body
                    ret.condition = condition
                    return ret
                end
            end
        end
        undo(self)
    end
end

return M
