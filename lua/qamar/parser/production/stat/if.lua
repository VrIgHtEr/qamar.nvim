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

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

local tkw_if = token.kw_if
local tkw_then = token.kw_then
local tkw_elseif = token.kw_elseif
local tkw_else = token.kw_else
local tkw_end = token.kw_end
local setmetatable = setmetatable
local nstat_if = n.stat_if

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_if then
        local kw_if = begintake(self)
        local condition = expression(self)
        if condition then
            tok = take(self)
            if tok and tok.type == tkw_then then
                local body = block(self)
                if body then
                    local conditions, bodies = { condition }, { body }
                    local cidx, bidx = 1, 1
                    while true do
                        tok = peek(self)
                        if not tok or tok.type ~= tkw_elseif then
                            break
                        end
                        begintake(self)
                        condition = expression(self)
                        if condition then
                            tok = take(self)
                            if tok and tok.type == tkw_then then
                                body = block(self)
                                if body then
                                    commit(self)
                                    cidx = cidx + 1
                                    conditions[cidx] = condition
                                    bidx = bidx + 1
                                    bodies[bidx] = body
                                else
                                    undo(self)
                                    break
                                end
                            else
                                undo(self)
                                break
                            end
                        else
                            undo(self)
                            break
                        end
                    end

                    tok = peek(self)
                    if tok and tok.type == tkw_else then
                        begintake(self)
                        body = block(self)
                        if body then
                            commit(self)
                            bidx = bidx + 1
                            bodies[bidx] = body
                        else
                            undo(self)
                        end
                    end

                    tok = take(self)
                    if tok and tok.type == tkw_end then
                        commit(self)
                        return setmetatable({
                            conditions = conditions,
                            bodies = bodies,
                            type = nstat_if,
                            pos = { left = kw_if.pos.left, right = bodies[#bodies].pos.right },
                        }, mt)
                    end
                end
            end
        end
        undo(self)
    end
end
