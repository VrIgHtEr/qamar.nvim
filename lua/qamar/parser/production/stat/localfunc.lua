---@class node_localfunc:node
---@field name node_name
---@field body node_funcbody

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require('qamar.parser.production.name').parser
local funcbody = require('qamar.parser.production.funcbody').parser
local mt = {
    ---@param s node_localfunc
    ---@return string
    __tostring = function(s)
        return tconcat { 'local function', s.name, s.body }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_local = token.kw_local
local tkw_function = token.kw_function
local nstat_localfunc = n.stat_localfunc
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua local function definition
---@param self parser
---@return node_localfunc|nil
function M:parser()
    local kw_local = peek(self)
    if kw_local and kw_local.type == tkw_local then
        begintake(self)
        local kw_function = take(self)
        if kw_function and kw_function.type == tkw_function then
            local funcname = name(self)
            if funcname then
                local body = funcbody(self)
                if body then
                    commit(self)
                    local ret = N(nstat_localfunc, range(kw_local.pos.left, body.pos.right), mt)
                    ret.name = funcname
                    ret.body = body
                    return ret
                end
            end
        end
        undo(self)
    end
end

return M
