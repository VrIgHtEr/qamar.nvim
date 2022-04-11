---@class node_goto:node
---@field label node_name

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require('qamar.parser.production.name').parser

local mt = {
    ---@param self node_goto
    ---@return string
    __tostring = function(self)
        return tconcat { 'goto', self.label }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_goto = token.kw_goto
local nstat_goto = n.stat_goto
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua goto statement
---@param self parser
---@return node_goto|nil
function M:parser()
    local kw_goto = peek(self)
    if kw_goto and kw_goto.type == tkw_goto then
        begintake(self)
        local label = name(self)
        if label then
            commit(self)
            local ret = N(nstat_goto, range(kw_goto.pos.left, label.pos.right), mt)
            ret.label = label
            return ret
        end
        undo(self)
    end
end

return M
