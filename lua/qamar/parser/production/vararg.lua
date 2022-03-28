local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return '...'
    end,
}
return function(self)
    local tok = self:peek()
    if tok and tok.type == token.tripledot then
        cfg.itrace 'ENTER'
        local ret = setmetatable({ type = n.vararg, pos = tok.pos }, mt)
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
end
