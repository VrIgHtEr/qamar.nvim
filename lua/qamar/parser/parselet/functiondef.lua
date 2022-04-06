---@class node_functiondef:node
---@field value node
---@field precedence number
---@field right_associative boolean

local N = require 'qamar.parser.node'
local node = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local range = require 'qamar.util.range'
local nfunctiondef = node.functiondef

local MT = {
    ---@param self node_functiondef
    ---@return string
    __tostring = function(self)
        return tconcat { 'function', self.value }
    end,
}
local funcbody = require 'qamar.parser.production.funcbody'

---parselet to consume a function definition
---@param self parselet
---@param parser parser
---@param tok token
---@return node_functiondef|nil
return function(self, parser, tok)
    local body = funcbody(parser)
    if body then
        local ret = N(nfunctiondef, range(tok.pos.left, body.pos.right), MT)
        ret.value = body
        ret.precedence = self.precedence
        ret.right_associative = self.right_associative
        return ret
    end
end
