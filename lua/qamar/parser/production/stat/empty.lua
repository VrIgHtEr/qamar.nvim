local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return ';'
    end,
}

return function(self)
    cfg.itrace 'ENTER'
    local tok = self:peek()
    if tok and tok.type == token.semicolon then
        self:take()
        local ret = setmetatable({ type = n.stat_empty, pos = tok.pos }, mt)
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
    cfg.dtrace 'EXIT'
end
