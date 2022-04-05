local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return 'break'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tkw_break = token.kw_break
local nstat_break = n.stat_break
local setmetatable = setmetatable

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_break then
        take(self)
        return setmetatable({ type = nstat_break, pos = tok.pos }, mt)
    end
end
