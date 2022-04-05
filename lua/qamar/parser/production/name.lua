local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return self.value
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tname = token.name
local setmetatable = setmetatable
local nname = n.name

return function(self)
    local tok = peek(self)
    if tok and tok.type == tname then
        take(self)
        return setmetatable({ value = tok.value, type = nname, pos = tok.pos }, mt)
    end
end
