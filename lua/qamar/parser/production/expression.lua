local parselet = require 'qamar.parser.parselet'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local begin = p.begin
local undo = p.undo
local commit = p.commit
local next_id = p.next_id
local take_until = p.take_until

---gets the precedence of the next available token
---@param self parser
---@return number
local function get_precedence(self)
    local next = peek(self)
    if next then
        local infix = parselet.infix[next.type]
        if infix then
            return infix.precedence
        end
    end
    return 0
end

local M = {}

---try to consume a lua expression
---@param self parser
---@param precedence number|nil
---@return node_expression|nil
function M:parser(precedence)
    precedence = precedence or 0
    local id = next_id(self)
    if precedence == 0 then
        local item = self.cache[id]
        if item then
            take_until(self, item.last)
            return item.value
        elseif item ~= nil then
            return
        end
    end
    local tok = peek(self)
    if tok then
        local prefix = parselet.prefix[tok.type]
        if prefix then
            begin(self)
            take(self)
            local left = prefix:parse(self, tok)
            if not left then
                if precedence == 0 then
                    self.cache[id] = { last = next_id(self), value = false }
                end
                undo(self)
                return
            end
            while precedence < get_precedence(self) do
                tok = peek(self)
                if not tok then
                    commit(self)
                    if precedence == 0 then
                        self.cache[id] = { last = next_id(), value = left }
                    end
                    return left
                end
                local infix = parselet.infix[tok.type]
                if not infix then
                    commit(self)
                    if precedence == 0 then
                        self.cache[id] = { last = next_id(), value = left }
                    end
                    return left
                end
                begin(self)
                take(self)
                local right = infix:parse(self, left, tok)
                if not right then
                    undo(self)
                    undo(self)
                    if precedence == 0 then
                        self.cache[id] = { last = next_id(self), value = left }
                    end
                    return left
                else
                    commit(self)
                    left = right
                end
            end
            commit(self)
            if precedence == 0 then
                self.cache[id] = { last = next_id(self), value = left }
            end
            return left
        elseif precedence == 0 then
            self.cache[id] = { last = next_id(self), value = false }
        end
    elseif precedence == 0 then
        self.cache[id] = { last = next_id(self), value = false }
    end
end

return M
