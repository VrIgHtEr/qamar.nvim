local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return '::' .. self.name .. '::'
    end,
}

return function(self)
    local left = self:peek()
    if not left or left.type ~= token.doublecolon then
        return
    end
    self:begin()
    self:take()

    local name = self:take()
    if not name or name.type ~= token.name then
        self:undo()
        return
    end

    local right = self:take()
    if not right or right.type ~= token.doublecolon then
        self:undo()
        return
    end

    self:commit()
    return setmetatable { { name = name.value, type = n.label, pos = { left = left.pos.left, right = right.pos.right } }, mt }
end
