local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return '::' .. tostring(self.name) .. '::'
    end,
}

local name = require 'qamar.parser.production.name'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local left = peek(self)
    if not left or left.type ~= token.doublecolon then
        return
    end
    begintake(self)

    local nam = name(self)
    if not nam then
        undo(self)
        return
    end

    local right = take(self)
    if not right or right.type ~= token.doublecolon then
        undo(self)
        return
    end

    commit(self)
    return setmetatable({ name = nam.value, type = n.label, pos = { left = left.pos.left, right = right.pos.right } }, mt)
end
