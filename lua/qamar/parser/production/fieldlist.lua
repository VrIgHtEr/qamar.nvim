---@class node_fieldlist:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local field = require 'qamar.parser.production.field'
local ipairs = ipairs
local nfieldlist = n.fieldlist
local tcomma = token.comma
local tsemicolon = token.semicolon
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_fieldlist
    ---@return string
    __tostring = function(self)
        local ret, idx = {}, 1
        for i, x in ipairs(self) do
            if i > 1 then
                ret[idx], idx = ',', idx + 1
            end
            ret[idx], idx = x, idx + 1
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

---try to consume a lua field list
---@param self parser
---@return node_fieldlist|nil
function M:parser()
    local f = field(self)
    if f then
        local pos = range(f.pos.left)
        local ret = N(nfieldlist, pos, mt)
        ret[1] = f
        local idx = 1
        while true do
            local tok = peek(self)
            if tok and (tok.type == tcomma or tok.type == tsemicolon) then
                begin(self)
                take(self)
                f = field(self)
                if not f then
                    undo(self)
                    break
                end
                idx = idx + 1
                ret[idx] = f
                commit(self)
            else
                break
            end
        end
        local tok = peek(self)
        if tok and (tok.type == tcomma or tok.type == tsemicolon) then
            take(self)
            pos.right = tok.pos.right
        else
            pos.right = ret[idx].pos.right
        end
        return ret
    end
end

return M
