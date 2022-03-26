local cfg = require 'qamar.config'
local precedence = require 'qamar.parser.precedence'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    cfg.itrace 'ENTER'
    local tok = self:peek()
    if tok and tok.type == token.name then
        self:begintake()
        local ret = expression(self, precedence.literal)
        if ret and ret.type == n.name then
            self:commit()
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
        self:undo()
    end
    cfg.dtrace 'EXIT'
end
