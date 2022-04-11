---@class node_empty:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local N = require 'qamar.parser.node'

local mt = {
    __tostring = function()
        return ';'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tsemicolon = token.semicolon
local nstat_empty = n.stat_empty

local M = {}

---try to consume a lua empty statement
---@param self parser
---@return node_empty|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tsemicolon then
        take(self)
        return N(nstat_empty, tok.pos, mt)
    end
end

return M
