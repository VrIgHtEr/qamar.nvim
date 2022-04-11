---@class node_do:node
---@field body node_block

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_do
    ---@return string
    __tostring = function(self)
        return tconcat { 'do', self.body, 'end' }
    end,
}

local block = require('qamar.parser.production.block').parser

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local nstat_do = n.stat_do

local M = {}

---try to consume a lue do...end statement
---@param self parser
---@return node_do|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_do then
        local kw_do = begintake(self)
        local body = block(self)
        if body then
            tok = take(self)
            if tok and tok.type == tkw_end then
                commit(self)
                local ret = N(nstat_do, range(kw_do.pos.left, tok.pos.right), mt)
                ret.body = body
                return ret
            end
        end
        undo(self)
    end
end

return M
