local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.name'

local mt = {
    __tostring = function(self)
        return tconcat { 'goto', self.label }
    end,
}

return function(self)
    local kw_goto = self:peek()
    if kw_goto and kw_goto.type == token.kw_goto then
        cfg.itrace 'ENTER'
        self:begintake()
        local label = name(self)
        if label then
            self:commit()
            local ret = setmetatable({ type = n.stat_goto, label = label, pos = { left = kw_goto.pos.left, right = label.pos.right } }, mt)
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
        self:undo()
        cfg.dtrace 'EXIT'
    end
end
