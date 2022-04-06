local nullfunc = function() end
local setmetatable = setmetatable

---@class token
---@field value string
---@field type token_type
---@field pos range

local token = {
    __metatable = nullfunc,
    ---@param self token
    ---@return string
    __tostring = function(self)
        return self.value
    end,
}

---creates a new token
---@param type token_type
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
