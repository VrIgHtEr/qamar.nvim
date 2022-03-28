local util = require 'qamar.util'
local cfg = require 'qamar.config'
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
return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_while then
        cfg.itrace 'ENTER'
        local kw_while = self:begintake()
        local condition = expression(self)
        if condition then
            tok = self:take()
            if tok and tok.type == token.kw_do then
                local body = block(self)
                if body then
                    tok = self:take()
                    if tok and tok.type == token.kw_end then
                        self:commit()
                        local ret = setmetatable({
                            condition = condition,
                            body = body,
                            type = n.stat_while,
                            pos = { left = kw_while.pos.left, right = tok.pos.right },
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
