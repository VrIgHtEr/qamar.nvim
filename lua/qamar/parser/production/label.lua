local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return '::' .. tostring(self.name) .. '::'
    end,
}

local name = require 'qamar.parser.production.name'

return function(self)
    local left = self:peek()
    if not left or left.type ~= token.doublecolon then
        return
    end
    cfg.itrace 'ENTER'
    self:begintake()

    local nam = name(self)
    if not nam then
        self:undo()
        cfg.dtrace 'EXIT'
        return
    end

    local right = self:take()
    if not right or right.type ~= token.doublecolon then
        self:undo()
        cfg.dtrace 'EXIT'
        return
    end

    self:commit()
    local ret = setmetatable({ name = nam.value, type = n.label, pos = { left = left.pos.left, right = right.pos.right } }, mt)
    cfg.dtrace('EXIT: ' .. tostring(ret))
    return ret
end
