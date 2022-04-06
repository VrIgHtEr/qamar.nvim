local setmetatable = setmetatable

---@class node
---@field pos range
---@field type number
local node = {}

local MTMT = {
    __index = node,
}
setmetatable(node, MTMT)

---creates a new node object
---@param type number
---@param pos range
---@param MT table|nil
---@return node
return function(type, pos, MT)
    return setmetatable({ type = type, pos = pos }, MT and setmetatable(MT, MTMT) or node)
end
