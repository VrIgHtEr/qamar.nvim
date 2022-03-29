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

    local id = self:next_id()
    if precedence == 0 then
        if not self.cache then
            self.cache = {}
        end
        local item = self.cache[id]
        if item then
            self:take_until(item.last)
            return item.value
        end
    end
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
            if precedence == 0 then
                self.cache[id] = { last = self:next_id(), value = left }
            end
            return left
        end
        local infix = parselet.infix[tok.type]
        if not infix then
            self:commit()
            if precedence == 0 then
                self.cache[id] = { last = self:next_id(), value = left }
            end
            return left
        end
        self:begin()
        self:take()
        local right = infix:parse(self, left, tok)
        if not right then
            self:undo()
            self:undo()
            if precedence == 0 then
                self.cache[id] = { last = self:next_id(), value = left }
            end
            return left
        else
            self:commit()
            left = right
        end
    end
    self:commit()
    if precedence == 0 then
        self.cache[id] = { last = self:next_id(), value = left }
    end
    return left
end
