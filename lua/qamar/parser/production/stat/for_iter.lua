local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'for', self.names, 'in', self.iterators, 'do', self.body, 'end' }
    end,
}

local namelist = require 'qamar.parser.production.namelist'
local explist = require 'qamar.parser.production.explist'
local block = require 'qamar.parser.production.block'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_for = token.kw_for
local tkw_in = token.kw_in
local tkw_do = token.kw_do
local tkw_end = token.kw_end
local setmetatable = setmetatable
local nstat_for_iter = n.stat_for_iter

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_for then
        local kw_for = begintake(self)
        local names = namelist(self)
        if names then
            tok = take(self)
            if tok and tok.type == tkw_in then
                local iterators = explist(self)
                if iterators then
                    tok = take(self)
                    if tok and tok.type == tkw_do then
                        local body = block(self)
                        if body then
                            tok = take(self)
                            if tok and tok.type == tkw_end then
                                commit(self)
                                return setmetatable({
                                    type = nstat_for_iter,
                                    names = names,
                                    iterators = iterators,
                                    body = body,
                                    pos = { left = kw_for.pos.left, right = tok.pos.right },
                                }, mt)
                            end
                        end
                    end
                end
            end
        end
        undo(self)
    end
end
