local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function(self)
        return '<' .. self.name .. '>'
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local less = peek(self)
    if not less or less.type ~= token.less then
        return
    end
    begintake(self)

    local name = take(self)
    if not name or name.type ~= token.name then
        undo(self)
        return
    end

    local greater = take(self)
    if not greater or greater.type ~= token.greater then
        undo(self)
        return
    end

    commit(self)
    return setmetatable({ name = name.value, type = n.attrib, pos = { left = less.pos.left, right = greater.pos.right } }, mt)
end
