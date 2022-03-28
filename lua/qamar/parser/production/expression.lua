local parselet = require 'qamar.parser.parselet'

local function get_precedence(self)
    local next = self:peek()
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            return infix.precedence
        end
    end
    return 0
end

return function(self, precedence)
    precedence = precedence or 0

    local tok = self:peek()
    if not tok then
        return
    end
    local prefix = parselet.prefix[tok.type]
    if not prefix then
        return
    end
    self:begin()
    self:take()
    local left = prefix:parse(self, tok)
    if not left then
        self:undo()
        return
    end
    while precedence < get_precedence(self) do
        tok = self:peek()
        if not tok then
            self:commit()
            return left
        end
        local infix = parselet.infix[tok.type]
        if not infix then
            self:commit()
            return left
        end
        self:begin()
        self:take()
        local right = infix:parse(self, left, tok)
        if not right then
            self:undo()
            self:undo()
            return left
        else
            self:commit()
            left = right
        end
    end
    self:commit()
    return left
end
