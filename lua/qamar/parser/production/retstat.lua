---@class node_retstat:node
---@field explist node_explist|nil

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local explist = require('qamar.parser.production.explist').parser

local mt = {
    ---@param self node_retstat
    ---@return string
    __tostring = function(self)
        local ret = { 'return' }
        if self.explist then
            tinsert(ret, self.explist)
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tkw_return = token.kw_return
local nretstat = n.retstat
local tsemicolon = token.semicolon
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'
local M = {}

---try to consume a lua return statement
---@param self parser
---@return node_retstat|nil
function M:parser()
    local retkw = peek(self)
    if retkw and retkw.type == tkw_return then
        take(self)
        local pos = range(retkw.pos.left)
        local ret = N(nretstat, pos, mt)
        ret.explist = explist(self)
        local tok = peek(self)
        if tok and tok.type == tsemicolon then
            take(self)
            pos.right = tok.pos.right
        else
            pos.right = ret.explist and ret.explist.pos.right or retkw.pos.right
        end
        return ret
    end
end

return M
