local setmetatable = setmetatable
local N = require 'qamar.parser.node'

---@class node_expression:node
---@field precedence number
---@field right_associative boolean
local node_expression = {}

local MTMT = {
    __index = node_expression,
}
setmetatable(node_expression, MTMT)

---creates a new node object
---@param type number
---@param pos range
---@param MT table|nil
---@return node_expression
return function(type, pos, precedence, right_associative, MT)
    local ret = N(type, pos, MT and setmetatable(MT, MTMT) or node_expression)
    ret.precedence = precedence
    ret.right_associative = right_associative
    return ret
end
