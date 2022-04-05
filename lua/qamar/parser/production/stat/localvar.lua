local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local mt = {
    __tostring = function(self)
        local ret = { 'local', self.names }
        if self.values then
            tinsert(ret, '=', self.values)
        end
        return tconcat(ret)
    end,
}

local attnamelist = require 'qamar.parser.production.attnamelist'
local explist = require 'qamar.parser.production.explist'

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local tok = peek(self)
    if tok and tok.type == token.kw_local then
        begintake(self)
        local names = attnamelist(self)
        if names then
            local ret = setmetatable({ names = names, type = n.stat_localvar, pos = { left = tok.pos.left } }, mt)
            commit(self)
            tok = peek(self)
            if tok and tok.type == token.assignment then
                begintake(self)
                ret.values = explist(self)
                if ret.values then
                    commit(self)
                    ret.pos.right = ret.values.pos.right
                else
                    undo(self)
                    ret.pos.right = names.pos.right
                end
            else
                ret.pos.right = names.pos.right
            end
            return ret
        end
        undo(self)
    end
end
