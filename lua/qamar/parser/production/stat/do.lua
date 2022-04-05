local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'do', self.body, 'end' }
    end,
}

local block = require 'qamar.parser.production.block'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local setmetatable = setmetatable
local nstat_do = n.stat_do

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_do then
        local kw_do = begintake(self)
        local body = block(self)
        if body then
            tok = take(self)
            if tok and tok.type == tkw_end then
                commit(self)
                return setmetatable({
                    body = body,
                    type = nstat_do,
                    pos = { left = kw_do.pos.left, right = tok.pos.right },
                }, mt)
            end
        end
        undo(self)
    end
end
