local util = require 'qamar.util'
local cfg = require 'qamar.config'
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

return function(self)
    cfg.itrace 'ENTER'
    local retkw = self:peek()
    if retkw and retkw.type == token.kw_return then
        self:take()
        local ret = setmetatable({ explist = explist(self), type = n.retstat, pos = { left = retkw.pos.left } }, mt)
        local tok = self:peek()
        if tok and tok.type == token.semicolon then
            self:take()
            ret.pos.right = tok.pos.right
        else
            ret.pos.right = ret.explist and ret.explist.pos.right or retkw.pos.right
        end
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
    cfg.dtrace 'EXIT'
end
