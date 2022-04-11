---@class node_attnamelist:node

---@class node_attname:node
---@field name node_name
---@field attrib node_attrib

local token = require 'qamar.tokenizer.types'
local node = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require('qamar.parser.production.name').parser
local attribute = require('qamar.parser.production.attrib').parser

local ipairs = ipairs
local mt = {
    ---@param self node_attnamelist
    ---@return string
    __tostring = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x.name)
            if x.attrib then
                tinsert(ret, x.attrib)
            end
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo
local nattname = node.attname
local nattnamelist = node.attnamelist
local tcomma = token.comma
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local M = {}

---try to consume a lua name attribute list
---@param self parser
---@return node_attnamelist|nil
function M:parser()
    local n = name(self)
    if n then
        local a = attribute(self)
        local tmp = N(nattname, range(n.pos.left, (a and a.pos.right or n.pos.right)))
        tmp.name, tmp.attrib = n, a
        local ret = N(nattnamelist, range(n.pos.left), mt)
        ret[1] = tmp
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tcomma then
                break
            end
            begin(self)
            take(self)
            n = name(self)
            if n then
                a = attribute(self)
                commit(self)
                idx = idx + 1
                local item = N(nattname, range(n.pos.left, (a and a.pos.right or n.pos.right)))
                item.name, item.attrib = n, a
                ret[idx] = item
            else
                undo(self)
                break
            end
        end

        local last = ret[idx]
        ret.pos.right = (last.attrib and last.attrib or last.name).pos.right
        return ret
    end
end

return M
