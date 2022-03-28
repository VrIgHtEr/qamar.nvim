local cfg = require 'qamar.config'
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

return function(self)
    local tok = self:peek()
    if tok and tok.type == token.kw_for then
        cfg.itrace 'ENTER'
        local kw_for = self:begintake()
        local names = namelist(self)
        if names then
            tok = self:take()
            if tok and tok.type == token.kw_in then
                local iterators = explist(self)
                if iterators then
                    tok = self:take()
                    if tok and tok.type == token.kw_do then
                        local body = block(self)
                        if body then
                            tok = self:take()
                            if tok and tok.type == token.kw_end then
                                self:commit()
                                local ret = setmetatable({
                                    type = n.stat_for_iter,
                                    names = names,
                                    iterators = iterators,
                                    body = body,
                                    pos = { left = kw_for.pos.left, right = tok.pos.right },
                                }, mt)
                                cfg.dtrace('EXIT: ' .. tostring(ret))
                                return ret
                            end
                        end
                    end
                end
            end
        end
        self:undo()
        cfg.dtrace 'EXIT'
    end
end
