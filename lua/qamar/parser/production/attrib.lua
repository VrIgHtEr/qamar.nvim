local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return '<' .. self.name .. '>'
    end,
}

return function(self)
    local less = self:peek()
    if not less or less.type ~= token.less then
        return
    end
    self:begin()
    self:take()

    local name = self:take()
    if not name or name.type ~= token.name then
        self:undo()
        return
    end

    local greater = self:take()
    if not greater or greater.type ~= token.greater then
        self:undo()
        return
    end

    self:commit()
    return setmetatable { { name = name.value, type = n.attrib, pos = { left = less.pos.left, right = greater.pos.right } }, mt }
end
