---@class node_break:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local N = require 'qamar.parser.node'

local mt = {
    __tostring = function()
        return 'break'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tkw_break = token.kw_break
local nstat_break = n.stat_break

local M = {}

---try to consume a lua break statement
---@param self parser
---@return node_break|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tkw_break then
        take(self)
        return N(nstat_break, tok.pos, mt)
    end
end

return M
