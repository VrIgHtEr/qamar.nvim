---@class node_localvar:node
---@field names node_attnamelist
---@field values node_explist|nil

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local mt = {
    ---@param self node_localvar
    ---@return string
    __tostring = function(self)
        local ret = { 'local', self.names }
        if self.values then
            tinsert(ret, '=', self.values)
        end
        return tconcat(ret)
    end,
}

local attnamelist = require('qamar.parser.production.attnamelist').parser
local explist = require('qamar.parser.production.explist').parser

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_local = token.kw_local
local nstat_localvar = n.stat_localvar
local tassignment = token.assignment
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua local variable declaration
---@param self parser
---@return node_localvar|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_local then
        begintake(self)
        local names = attnamelist(self)
        if names then
            local pos = range(tok.pos.left)
            local ret = N(nstat_localvar, pos, mt)
            ret.names = names
            commit(self)
            tok = peek(self)
            if tok and tok.type == tassignment then
                begintake(self)
                ret.values = explist(self)
                if ret.values then
                    commit(self)
                    pos.right = ret.values.pos.right
                else
                    undo(self)
                    pos.right = names.pos.right
                end
            else
                pos.right = names.pos.right
            end
            return ret
        end
        undo(self)
    end
end

return M
