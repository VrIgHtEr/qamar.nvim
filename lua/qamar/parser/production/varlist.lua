---@class node_varlist:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local var = require('qamar.parser.production.var').parser
local ipairs = ipairs
local nvarlist = n.varlist
local tcomma = token.comma

local mt = {
    ---@param self node_varlist
    ---@return string
    __tostring = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
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
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua varlist
---@param self parser
---@return node_varlist|nil
function M:parser()
    local v = var(self)
    if v then
        local pos = range(v.pos.left)
        local ret = N(nvarlist, pos, mt)
        ret[1] = v
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tcomma then
                break
            end
            begin(self)
            take(self)
            v = var(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
            else
                undo(self)
                break
            end
        end
        pos.right = ret[idx].pos.right
        return ret
    end
end

return M
