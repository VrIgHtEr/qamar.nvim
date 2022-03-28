local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return self.value
    end,
}
return function(self)
    local tok = self:peek()
    if tok and tok.type == token.name then
        cfg.itrace 'ENTER'
        local ret = setmetatable({ value = tok.value, type = n.name, pos = tok.pos }, mt)
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
end
