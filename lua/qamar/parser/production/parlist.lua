---@class node_parlist:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local namelist = require('qamar.parser.production.namelist').parser
local vararg = require('qamar.parser.production.vararg').parser
local ipairs = ipairs
local nparlist = n.parlist
local tcomma = token.comma
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_parlist
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
local begintake = p.begintake
local commit = p.commit
local undo = p.undo

local M = {}

---try to consume a lua parameter list
---@param self parser
---@return node_parlist|nil
function M:parser()
    local v = vararg(self)
    if v then
        local ret = N(nparlist, v.pos, mt)
        ret[1] = v
        return ret
    else
        v = namelist(self)
        if v then
            local pos = range(v.pos.left)
            local ret = N(nparlist, pos, mt)
            local idx = 0
            for _, x in ipairs(v) do
                idx = idx + 1
                ret[idx] = x
            end
            v = peek(self)
            if v and v.type == tcomma then
                begintake(self)
                v = vararg(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                end
            end
            pos.right = ret[idx].pos.right
            return ret
        end
    end
end

return M
