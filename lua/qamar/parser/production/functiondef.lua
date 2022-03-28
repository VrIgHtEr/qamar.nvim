local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_function then
        self:begin()
        local ret = expression(self)
        if ret and ret.type == n.functiondef then
            self:commit()
            return ret
        end
        self:undo()
    end
end
