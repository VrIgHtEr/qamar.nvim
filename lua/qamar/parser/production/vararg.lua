local cfg = require 'qamar.config'
local precedence = require 'qamar.parser.precedence'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    cfg.itrace 'ENTER'
    local tok = self:peek()
    if tok and tok.type == token.tripledot then
        local ret = expression(self, precedence.literal)
        if ret and ret.type == n.vararg then
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
    end
    cfg.dtrace 'EXIT'
end
