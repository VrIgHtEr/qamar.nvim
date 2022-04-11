---@class node_func:node
---@field name node_funcname
---@field body node_funcbody

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require('qamar.parser.production.funcname').parser
local funcbody = require('qamar.parser.production.funcbody').parser

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_function = token.kw_function
local nstat_func = n.stat_func
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param s node_func
    ---@return string
    __tostring = function(s)
        return tconcat { 'function', s.name, s.body }
    end,
}

local M = {}

---try to consume a lua function statement
---@param self parser
---@return node_func|nil
function M:parser()
    local kw_function = peek(self)
    if kw_function and kw_function.type == tkw_function then
        begintake(self)
        local funcname = name(self)
        if funcname then
            local body = funcbody(self)
            if body then
                commit(self)
                local ret = N(nstat_func, range(kw_function.pos.left, body.pos.right), mt)
                ret.name = funcname
                ret.body = body
                return ret
            end
        end
        undo(self)
    end
end

return M
