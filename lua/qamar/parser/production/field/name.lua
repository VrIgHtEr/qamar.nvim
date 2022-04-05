local tconcat = require('qamar.util.table').tconcat
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'
local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo

local mt = {
    __tostring = function(self)
        return tconcat { self.key, '=', self.value }
    end,
}

return function(self)
    local key = peek(self)
    if key and key.type == token.name then
        begin(self)
        local left = take(self).pos.left
        local tok = take(self)
        if tok and tok.type == token.assignment then
            local value = expression(self)
            if value then
                commit(self)
                local ret = setmetatable({ key = key.value, value = value, type = n.field_name, pos = { left = left, right = value.pos.right } }, mt)
                return ret
            end
        end
        undo(self)
    end
end
