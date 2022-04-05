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
local tkw_local = token.kw_local
local setmetatable = setmetatable
local nstat_localvar = n.stat_localvar
local tassignment = token.assignment

return function(self)
    local tok = peek(self)
    if tok and tok.type == tkw_local then
        begintake(self)
        local names = attnamelist(self)
        if names then
            local ret = setmetatable({ names = names, type = nstat_localvar, pos = { left = tok.pos.left } }, mt)
            commit(self)
            tok = peek(self)
            if tok and tok.type == tassignment then
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
