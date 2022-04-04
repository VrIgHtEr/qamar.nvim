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
        local kw_if = self:begintake()
        local condition = expression(self)
        if condition then
            tok = self:take()
            if tok and tok.type == token.kw_then then
                local body = block(self)
                if body then
                    local conditions, bodies = { condition }, { body }
                    local cidx, bidx = 1, 1
                    while true do
                        tok = self:peek()
                        if not tok or tok.type ~= token.kw_elseif then
                            break
                        end
                        self:begintake()
                        condition = expression(self)
                        if condition then
                            tok = self:take()
                            if tok and tok.type == token.kw_then then
                                body = block(self)
                                if body then
                                    self:commit()
                                    cidx = cidx + 1
                                    conditions[cidx] = condition
                                    bidx = bidx + 1
                                    bodies[bidx] = body
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
                            bidx = bidx + 1
                            bodies[bidx] = body
                        else
                            self:undo()
                        end
                    end

                    tok = self:take()
                    if tok and tok.type == token.kw_end then
                        self:commit()
                        return setmetatable({
                            conditions = conditions,
                            bodies = bodies,
                            type = n.stat_if,
                            pos = { left = kw_if.pos.left, right = bodies[#bodies].pos.right },
                        }, mt)
                    end
                end
            end
        end
        self:undo()
    end
end
