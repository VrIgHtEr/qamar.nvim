local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return ';'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local tsemicolon = token.semicolon
local setmetatable = setmetatable
local nstat_empty = n.stat_empty

return function(self)
    local tok = peek(self)
    if tok and tok.type == tsemicolon then
        take(self)
        return setmetatable({ type = nstat_empty, pos = tok.pos }, mt)
    end
end
