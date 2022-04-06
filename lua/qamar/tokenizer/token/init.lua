local nullfunc = function() end
local setmetatable = setmetatable

---@class token
---@field value string
---@field type number
---@field pos range
---@field id number

local token = {
    __metatable = nullfunc,
    ---@param self token
    ---@return string
    __tostring = function(self)
        return self.value
    end,
}

---creates a new token
---@param type number
---@param value string
---@param pos range
---@param MT table|nil
---@return token
return function(type, value, pos, MT)
    return setmetatable({
        type = type,
        value = value,
        pos = pos,
    }, MT or token)
end
