local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'do', self.body, 'end' }
    end,
}

local block = require 'qamar.parser.production.block'

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_do then
        local kw_do = self:begintake()
        local body = block(self)
        if body then
            tok = self:take()
            if tok and tok.type == token.kw_end then
                self:commit()
                return setmetatable({
                    body = body,
                    type = n.stat_do,
                    pos = { left = kw_do.pos.left, right = tok.pos.right },
                }, mt)
            end
        end
        self:undo()
    end
end
