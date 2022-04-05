local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'while', self.condition, 'do', self.body, 'end' }
    end,
}

local expression = require 'qamar.parser.production.expression'
local block = require 'qamar.parser.production.block'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_while = token.kw_while
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local setmetatable = setmetatable
local nstat_while = n.stat_while

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_while then
        local kw_while = begintake(self)
        local condition = expression(self)
        if condition then
            tok = take(self)
            if tok and tok.type == tkw_do then
                local body = block(self)
                if body then
                    tok = take(self)
                    if tok and tok.type == tkw_end then
                        commit(self)
                        return setmetatable({
                            condition = condition,
                            body = body,
                            type = nstat_while,
                            pos = { left = kw_while.pos.left, right = tok.pos.right },
                        }, mt)
                    end
                end
            end
        end
        undo(self)
    end
end
