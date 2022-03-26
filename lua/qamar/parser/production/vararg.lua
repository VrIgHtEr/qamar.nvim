local precedence = require 'qamar.parser.precedence'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.tripledot then
        local ret = expression(self, precedence.literal)
        if ret and ret.type == n.vararg then
            return ret
        end
    end
end