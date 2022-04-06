local nullfunc = function() end
local setmetatable = setmetatable
---@class range
---@field left position
---@field right position
local range = {
    __metatable = nullfunc,
    __tostring = function(self)
        return self.left .. ' - ' .. self.right
    end,
}

---create a new range object
---@param left position
---@param right position
---@return range
return function(left, right)
    return setmetatable({
        left = left,
        right = right,
    }, range)
end
