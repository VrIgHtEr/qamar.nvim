local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.lbrace then
        self:begin()
        local ret = expression(self)
        if ret and ret.type == n.tableconstructor then
            self:commit()
            return ret
        end
        self:undo()
    end
end
