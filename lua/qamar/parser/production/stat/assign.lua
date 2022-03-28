local util = require 'qamar.util'
local cfg = require 'qamar.config'
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
return function(self)
    local target = varlist(self)
    if target then
        local tok = self:take()
        if tok and tok.type == token.assignment then
            cfg.itrace 'ENTER'
            self:begin()
            local value = explist(self)
            if value then
                self:commit()
                local ret = setmetatable({
                    target = target,
                    value = value,
                    type = n.stat_assign,
                    pos = { left = target.pos.left, right = value.pos.right },
                }, mt)
                cfg.dtrace('EXIT: ' .. tostring(ret))
                return ret
            end
            self:undo()
            cfg.dtrace 'EXIT'
        end
    end
end
