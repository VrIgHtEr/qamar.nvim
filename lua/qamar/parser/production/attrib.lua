---@class node_attrib:node
---@field name string

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_attrib
    ---@return string
    __tostring = function(self)
        return '<' .. self.name .. '>'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tless = token.less
local tname = token.name
local tgreater = token.greater
local nattrib = n.attrib

local M = {}

---try to consume a lua variable attribute
---@param self parser
---@return node_attrib|nil
function M:parser()
    local less = peek(self)
    if not less or less.type ~= tless then
        return
    end
    begintake(self)

    local name = take(self)
    if not name or name.type ~= tname then
        undo(self)
        return
    end

    local greater = take(self)
    if not greater or greater.type ~= tgreater then
        undo(self)
        return
    end

    commit(self)
    local ret = N(nattrib, range(less.pos.left, greater.pos.right), mt)
    ret.name = name.value
    return ret
end

return M
