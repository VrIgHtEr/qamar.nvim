---@class node_for_num:node
---@field name node_name
---@field start node_expression
---@field finish node_expression
---@field increment node_expression|nil
---@field body node_block

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require('qamar.parser.production.name').parser
local expression = require('qamar.parser.production.expression').parser
local block = require('qamar.parser.production.block').parser
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param s node_for_num
    ---@return string
    __tostring = function(s)
        local ret = { 'for', s.name, '=', s.start, ',', s.finish }
        if s.increment then
            tinsert(ret, ',', s.increment)
        end
        tinsert(ret, 'do', s.body, 'end')
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_for = token.kw_for
local tassignment = token.assignment
local tcomma = token.comma
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local nstat_for_num = n.stat_for_num

local M = {}

---try to consume a lua for loop
---@param self parser
---@return node_for_num|nil
function M:parser()
    local kw_for = peek(self)
    if kw_for and kw_for.type == tkw_for then
        begintake(self)
        local varname = name(self)
        if varname then
            local tok = take(self)
            if tok and tok.type == tassignment then
                local start = expression(self)
                if start then
                    tok = take(self)
                    if tok and tok.type == tcomma then
                        local finish = expression(self)
                        if finish then
                            local increment = nil
                            tok = peek(self)
                            if tok and tok.type == tcomma then
                                begintake(self)
                                increment = expression(self)
                                if increment then
                                    commit(self)
                                else
                                    undo(self)
                                end
                            end
                            tok = take(self)
                            if tok and tok.type == tkw_do then
                                local body = block(self)
                                tok = take(self)
                                if tok and tok.type == tkw_end then
                                    commit(self)
                                    local ret = N(nstat_for_num, range(kw_for.pos.left, tok.pos.right), mt)
                                    ret.name = varname
                                    ret.start = start
                                    ret.finish = finish
                                    ret.increment = increment
                                    ret.body = body
                                    return ret
                                end
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
