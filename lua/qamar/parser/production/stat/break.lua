local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return 'break'
    end,
}

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_break then
        self:take()
        return setmetatable({ type = n.stat_break, pos = tok.pos }, mt)
    end
end
