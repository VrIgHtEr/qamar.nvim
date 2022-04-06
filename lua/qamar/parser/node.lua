local setmetatable = setmetatable

---@class node
---@field pos range
---@field type number
local node = {}

---creates a new node object
---@param type number
---@param pos range
---@return node
return function(type, pos)
    return setmetatable({ type = type, pos = pos }, node)
end
