local cfg = require 'qamar.config'
local parselet = require 'qamar.parser.parselet'

local function get_precedence(self)
    local next = self:peek()
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            cfg.trace('PRECEDENCE ' .. infix.precedence)
            return infix.precedence
        end
    end
    cfg.trace 'PRECEDENCE 0'
    return 0
end

local types = require 'qamar.parser.types'

return function(self, precedence)
    precedence = precedence or 0
    cfg.itrace('ENTER ' .. tostring(precedence))

    local tok = self:peek()
    if not tok then
        cfg.dtrace 'EXIT 1'
        return
    end
    local prefix = parselet.prefix[tok.type]
    if not prefix then
        cfg.dtrace 'EXIT 2'
        return
    end
    self:begin()
    self:take()
    local left = prefix:parse(self, tok)
    if not left then
        self:undo()
        cfg.dtrace 'EXIT 3'
        return
    end
    while precedence < get_precedence(self) do
        tok = self:peek()
        if not tok then
            self:commit()
            cfg.dtrace('EXIT 4:' .. types[left.type] .. ': ' .. tostring(left))
            return left
        end
        local infix = parselet.infix[tok.type]
        if not infix then
            self:commit()
            cfg.dtrace('EXIT 5:' .. types[left.type] .. ': ' .. tostring(left))
            return left
        end
        self:begin()
        self:take()
        local right = infix:parse(self, left, tok)
        if not right then
            self:undo()
            self:undo()
            cfg.dtrace('EXIT 6:' .. types[left.type] .. ': ' .. tostring(left))
            return left
        else
            self:commit()
            left = right
        end
    end
    self:commit()
    cfg.dtrace('EXIT 7:' .. types[left.type] .. ': ' .. tostring(left))
    return left
end
