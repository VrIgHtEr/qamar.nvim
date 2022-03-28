local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local expression = require 'qamar.parser.production.expression'
local block = require 'qamar.parser.production.block'
local mt = {
    __tostring = function(self)
        local ret = { 'if', self.conditions[1], 'then', self.bodies[1] }
        for i = 2, #self.conditions do
            tinsert(ret, 'elseif', self.conditions[i], 'then', self.bodies[i])
        end
        for i = #self.conditions + 1, #self.bodies do
            tinsert(ret, 'else', self.bodies[i])
        end
        tinsert(ret, 'end')
        return tconcat(ret)
    end,
}

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_if then
        cfg.itrace 'ENTER'
        local kw_if = self:begintake()
        local condition = expression(self)
        if condition then
            tok = self:take()
            if tok and tok.type == token.kw_then then
                local body = block(self)
                if body then
                    local conditions, bodies = { condition }, { body }
                    while true do
                        tok = self:peek()
                        if not tok or tok.type ~= token.kw_elseif then
                            break
                        end
                        self:begintake()
                        condition = expression()
                        if condition then
                            tok = self:take()
                            if tok and tok.type == token.kw_then then
                                body = block(self)
                                if body then
                                    self:commit()
                                    table.insert(conditions, condition)
                                    table.insert(bodies, body)
                                else
                                    self:undo()
                                    break
                                end
                            else
                                self:undo()
                                break
                            end
                        else
                            self:undo()
                            break
                        end
                    end

                    tok = self:peek()
                    if tok and tok.type == token.kw_else then
                        self:begintake()
                        body = block(self)
                        if body then
                            self:commit()
                            table.insert(bodies, body)
                        else
                            self:undo()
                        end
                    end

                    tok = self:take()
                    if tok and tok.type == token.kw_end then
                        self:commit()
                        local ret = setmetatable({
                            conditions = conditions,
                            bodies = bodies,
                            type = n.stat_if,
                            pos = { left = kw_if.pos.left, right = bodies[#bodies].pos.right },
                        }, mt)
                        cfg.dtrace('EXIT: ' .. tostring(ret))
                        return ret
                    end
                end
            end
        end
        self:undo()
        cfg.dtrace 'EXIT'
    end
end
