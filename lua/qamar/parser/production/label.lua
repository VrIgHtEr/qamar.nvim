---@class node_label:node
---@field name string

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local N = require 'qamar.parser.node'
local range = require 'qamar.util.range'

local mt = {
    ---@param self node_label
    ---@return string
    __tostring = function(self)
        return '::' .. self.name .. '::'
    end,
}

local name = require('qamar.parser.production.name').parser

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tdoublecolon = token.doublecolon
local nlabel = n.label

local M = {}

---try to consume a lua label
---@param self parser
---@return node_label|nil
function M:parser()
    local left = peek(self)
    if not left or left.type ~= tdoublecolon then
        return
    end
    begintake(self)

    local nam = name(self)
    if not nam then
        undo(self)
        return
    end

    local right = take(self)
    if not right or right.type ~= tdoublecolon then
        undo(self)
        return
    end

    commit(self)
    local ret = N(nlabel, range(left.pos.left, right.pos.right), mt)
    ret.name = nam.value
    return ret
end

return M
