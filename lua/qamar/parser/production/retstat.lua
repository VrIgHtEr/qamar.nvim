local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local explist = require 'qamar.parser.production.explist'

local mt = {
    __tostring = function(self)
        local ret = { 'return' }
        if self.explist then
            tinsert(ret, self.explist)
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take

return function(self)
    local retkw = peek(self)
    if retkw and retkw.type == token.kw_return then
        take(self)
        local ret = setmetatable({ explist = explist(self), type = n.retstat, pos = { left = retkw.pos.left } }, mt)
        local tok = peek(self)
        if tok and tok.type == token.semicolon then
            take(self)
            ret.pos.right = tok.pos.right
        else
            ret.pos.right = ret.explist and ret.explist.pos.right or retkw.pos.right
        end
        return ret
    end
end
