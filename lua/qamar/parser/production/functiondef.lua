local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begin = p.begin

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_function then
        begin(self)
        local ret = expression(self)
        if ret and ret.type == n.functiondef then
            commit(self)
            return ret
        end
        undo(self)
    end
end
