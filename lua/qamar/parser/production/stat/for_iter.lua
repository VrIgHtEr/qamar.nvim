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

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_for then
        local kw_for = begintake(self)
        local names = namelist(self)
        if names then
            tok = take(self)
            if tok and tok.type == token.kw_in then
                local iterators = explist(self)
                if iterators then
                    tok = take(self)
                    if tok and tok.type == token.kw_do then
                        local body = block(self)
                        if body then
                            tok = take(self)
                            if tok and tok.type == token.kw_end then
                                commit(self)
                                return setmetatable({
                                    type = n.stat_for_iter,
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
