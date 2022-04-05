local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local expression = require 'qamar.parser.production.expression'

local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo
local tlbracket = token.lbracket
local trbracket = token.rbracket
local tassignment = token.assignment
local nfield_raw = n.field_raw
local setmetatable = setmetatable

local mt = {
    __tostring = function(self)
        return tconcat { '[', self.key, ']', '=', self.value }
    end,
}
return function(self)
    local tok = peek(self)
    if tok and tok.type == tlbracket then
        begin(self)
        local left = take(self).pos.left
        local key = expression(self)
        if key then
            tok = take(self)
            if tok and tok.type == trbracket then
                tok = take(self)
                if tok and tok.type == tassignment then
                    local value = expression(self)
                    if value then
                        commit(self)
                        return setmetatable({ key = key, value = value, pos = { left = left, right = value.pos.right }, type = nfield_raw }, mt)
                    end
                end
            end
        end
        undo(self)
    end
end
