---@class node_namelist:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local name = require('qamar.parser.production.name').parser
local ipairs = ipairs
local nnamelist = n.namelist
local tcomma = token.comma

local mt = {
    ---@param self node_namelist
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

local M = {}

---try to consume a lua name list
---@param self parser
---@return node_namelist|nil
function M:parser()
    local v = name(self)
    if v then
        local pos = range(v.pos.left)
        local ret = N(nnamelist, pos, mt)
        ret[1] = v
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tcomma then
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
        pos.right = ret[idx].pos.right
        return ret
    end
end

return M
