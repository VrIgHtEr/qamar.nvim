local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { self.target, '=', self.value }
    end,
}
local varlist = require 'qamar.parser.production.varlist'
local explist = require 'qamar.parser.production.explist'

local p = require 'qamar.parser'
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin
local tassignment = token.assignment
local nstat_assign = n.stat_assign
local setmetatable = setmetatable

return function(self)
    local target = varlist(self)
    if target then
        local tok = take(self)
        if tok and tok.type == tassignment then
            begin(self)
            local value = explist(self)
            if value then
                commit(self)
                return setmetatable({
                    target = target,
                    value = value,
                    type = nstat_assign,
                    pos = { left = target.pos.left, right = value.pos.right },
                }, mt)
            end
            undo(self)
        end
    end
end
