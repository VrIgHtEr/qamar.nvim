---@class node_name:node
---@field value string

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local N = require 'qamar.parser.node'

local mt = {
    ---@param self node_name
    ---@return string
    __tostring = function(self)
        return self.value
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tname = token.name
local nname = n.name

local M = {}

---try to consume a lua name
---@param self parser
---@return node_name|nil
function M:parser()
    local tok = peek(self)
    if tok and tok.type == tname then
        take(self)
        local ret = N(nname, tok.pos, mt)
        ret.value = tok.value
        return ret
    end
end

return M
