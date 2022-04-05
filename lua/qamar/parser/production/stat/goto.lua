local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.name'

local mt = {
    __tostring = function(self)
        return tconcat { 'goto', self.label }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local kw_goto = peek(self)
    if kw_goto and kw_goto.type == token.kw_goto then
        begintake(self)
        local label = name(self)
        if label then
            commit(self)
            return setmetatable({ type = n.stat_goto, label = label, pos = { left = kw_goto.pos.left, right = label.pos.right } }, mt)
        end
        undo(self)
    end
end
