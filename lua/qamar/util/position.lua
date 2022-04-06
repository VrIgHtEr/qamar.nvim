local function nullfunc() end
local setmetatable = setmetatable

---@class position
---@field row number
---@field col number
---@field byte number
---@field file_char number
---@field file_byte number
local position = {
    __metatable = nullfunc,
    __tostring = function(self)
        return self.row .. ':' .. self.col
    end,
}

---create a new position object
---@param row number
---@param col number
---@param byte number
---@param file_char number
---@param file_byte number
---@return position
return function(row, col, byte, file_char, file_byte)
    return setmetatable({
        row = row,
        col = col,
        byte = byte,
        file_char = file_char,
        file_byte = file_byte,
    }, position)
end
