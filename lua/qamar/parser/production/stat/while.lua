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

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_while then
        local kw_while = begintake(self)
        local condition = expression(self)
        if condition then
            tok = take(self)
            if tok and tok.type == token.kw_do then
                local body = block(self)
                if body then
                    tok = take(self)
                    if tok and tok.type == token.kw_end then
                        commit(self)
                        return setmetatable({
                            condition = condition,
                            body = body,
                            type = n.stat_while,
                            pos = { left = kw_while.pos.left, right = tok.pos.right },
                        }, mt)
                    end
                end
            end
        end
        undo(self)
    end
end
