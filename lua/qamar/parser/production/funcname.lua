---@class node_funcname:node
---@field objectaccess boolean|nil

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local name = require('qamar.parser.production.name').parser
local ipairs = ipairs

local mt = {
    ---@param self node_funcname
    ---@return string
    __tostring = function(self)
        local ret = {}
        local max = #self
        local objectaccess = self.objectaccess
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, i == max and objectaccess and ':' or '.')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin
local begintake = p.begintake
local nfuncname = n.funcname
local tdot = token.dot
local tcolon = token.colon

local M = {}

---try to consume a lua funcname
---@param self parser
---@return node_funcname
function M:parser()
    local v = name(self)
    if v then
        local pos = range(v.pos.left)
        local ret = N(nfuncname, pos, mt)
        ret[1] = v
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tdot then
                break
            end
            begin(self)
            take(self)
            v = name(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
            else
                undo(self)
                break
            end
        end

        local tok = peek(self)
        if tok and tok.type == tcolon then
            begintake(self)
            v = name(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
                ret.objectaccess = true
            else
                undo(self)
            end
        end

        pos.right = ret[idx].pos.right
        return ret
    end
end

return M
