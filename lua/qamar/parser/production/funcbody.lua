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

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tlparen = token.lparen
local trparen = token.rparen
local tkw_end = token.kw_end
local setmetatable = setmetatable
local nfuncbody = n.funcbody

return function(self)
    local lparen = peek(self)
    if lparen and lparen.type == tlparen then
        begintake(self)
        local pars = parlist(self)
        local tok = take(self)
        if tok and tok.type == trparen then
            local body = block(self)
            if body then
                tok = take(self)
                if tok and tok.type == tkw_end then
                    commit(self)
                    return setmetatable({ parameters = pars, body = body, type = nfuncbody, pos = { left = lparen.pos.left, right = tok.pos.right } }, mt)
                end
            end
        end
        undo(self)
    end
end
