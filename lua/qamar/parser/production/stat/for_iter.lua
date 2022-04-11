---@class node_for_iter:node
---@field names node_namelist
---@field iterators node_explist
---@field body node_block

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    ---@param self node_for_iter
    ---@return string
    __tostring = function(self)
        return tconcat { 'for', self.names, 'in', self.iterators, 'do', self.body, 'end' }
    end,
}

local namelist = require('qamar.parser.production.namelist').parser
local explist = require('qamar.parser.production.explist').parser
local block = require('qamar.parser.production.block').parser

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_for = token.kw_for
local tkw_in = token.kw_in
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local nstat_for_iter = n.stat_for_iter
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua iterator for loop
---@param self parser
---@return node_for_iter|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_for then
        local kw_for = begintake(self)
        local names = namelist(self)
        if names then
            tok = take(self)
            if tok and tok.type == tkw_in then
                local iterators = explist(self)
                if iterators then
                    tok = take(self)
                    if tok and tok.type == tkw_do then
                        local body = block(self)
                        if body then
                            tok = take(self)
                            if tok and tok.type == tkw_end then
                                commit(self)
                                local ret = N(nstat_for_iter, range(kw_for.pos.left, tok.pos.right), mt)
                                ret.names = names
                                ret.iterators = iterators
                                ret.body = body
                                return ret
                            end
                        end
                    end
                end
            end
        end
        undo(self)
    end
end

return M
