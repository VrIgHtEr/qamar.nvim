local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'repeat', self.body, 'until', self.condition }
    end,
}

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local block = require 'qamar.parser.production.block'
local expression = require 'qamar.parser.production.expression'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_repeat then
        local kw_repeat = begintake(self)

        local body = block(self)
        if body then
            tok = take(self)
            if tok and tok.type == token.kw_until then
                local condition = expression(self)
                if condition then
                    commit(self)
                    return setmetatable({
                        body = body,
                        condition = condition,
                        type = n.stat_repeat,
                        pos = { left = kw_repeat.pos.left, right = condition.pos.right },
                    }, mt)
                end
            end
        end
        undo(self)
    end
end
