local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local expression = require 'qamar.parser.production.expression'

local mt = {
    __tostring = function(self)
        return tconcat { '[', self.key, ']', '=', self.value }
    end,
}
return function(self)
    cfg.itrace 'ENTER'
    local tok = self:peek()
    if tok and tok.type == token.lbracket then
        self:begin()
        local left = self:take().pos.left
        local key = expression(self)
        if key then
            tok = self:take()
            if tok and tok.type == token.rbracket then
                tok = self:take()
                if tok and tok.type == token.assignment then
                    local value = expression(self)
                    if value then
                        self:commit()
                        local ret = setmetatable({ key = key, value = value, pos = { left = left, right = value.pos.right }, type = n.field_raw }, mt)
                        cfg.dtrace('EXIT: ' .. tostring(ret))
                        return ret
                    end
                end
            end
        end
        self:undo()
    end
    cfg.dtrace 'EXIT'
end
