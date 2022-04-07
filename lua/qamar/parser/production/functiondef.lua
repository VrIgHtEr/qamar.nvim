local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begin = p.begin
local tkw_function = token.kw_function
local nfunctiondef = n.functiondef

---try to consume a lua functiondef
---@param self parser
---@return node_functiondef
return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_function then
        begin(self)
        local ret = expression(self)
        if ret and ret.type == nfunctiondef then
            commit(self)
            return ret
        end
        undo(self)
    end
end
