local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local field = require 'qamar.parser.production.field'

local mt = {
    __tostring = function(self)
        local ret, idx = {}, 1
        for i, x in ipairs(self) do
            if i > 1 then
                ret[idx], idx = ',', idx + 1
            end
            ret[idx], idx = x, idx + 1
        end
        return tconcat(ret)
    end,
}

return function(self)
    cfg.itrace 'ENTER'
    local f = field(self)
    if f then
        local pos = { left = f.pos.left, right = f.pos.right }
        local ret, idx = setmetatable({ f, type = n.fieldlist, pos = pos }, mt), 2
        while true do
            local tok = self:peek()
            if tok and (tok.type == token.comma or tok.type == token.semicolon) then
                self:begin()
                self:take()
                f = field(self)
                if not f then
                    self:undo()
                    break
                end
                ret[idx], idx = f, idx + 1
                self:commit()
            else
                break
            end
        end
        local tok = self:peek()
        if tok and (tok.type == token.comma or tok.type == token.semicolon) then
            self:take()
        end
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
    cfg.dtrace 'EXIT'
end
