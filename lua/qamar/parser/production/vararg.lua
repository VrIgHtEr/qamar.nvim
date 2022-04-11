---@class node_vararg:node

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return '...'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local ttripledot = token.tripledot
local nvararg = n.vararg
local N = require 'qamar.parser.node'

local M = {}

---try to consume a vararg token
---@param self parser
---@return node_vararg|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == ttripledot then
        take(self)
        return N(nvararg, tok.pos, mt)
    end
end

return M
