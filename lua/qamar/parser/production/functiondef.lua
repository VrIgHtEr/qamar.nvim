local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_function then
        cfg.itrace 'ENTER'
        self:begin()
        local ret = expression(self)
        if ret and ret.type == n.functiondef then
            self:commit()
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
        self:undo()
        cfg.dtrace 'EXIT'
    end
end
