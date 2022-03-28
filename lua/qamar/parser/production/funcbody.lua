local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local parlist = require 'qamar.parser.production.parlist'
local block = require 'qamar.parser.production.block'

local mt = {
    __tostring = function(self)
        local ret = { '(' }
        if self.parameters then
            tinsert(ret, self.parameters)
        end
        tinsert(ret, ')', self.body, 'end')
        return tconcat(ret)
    end,
}

return function(self)
    local lparen = self:peek()
    if lparen and lparen.type == token.lparen then
        self:begintake()
        local pars = parlist(self)
        local tok = self:take()
        if tok and tok.type == token.rparen then
            local body = block(self)
            if body then
                tok = self:take()
                if tok and tok.type == token.kw_end then
                    self:commit()
                    return setmetatable({ parameters = pars, body = body, type = n.funcbody, pos = { left = lparen.pos.left, right = tok.pos.right } }, mt)
                end
            end
        end
        self:undo()
    end
end
