local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'

local mt = {
    __tostring = function(self)
        local ret = {}
        local max = #self
        local objectaccess = self.objectaccess
        for i, x in ipairs(ret) do
            if i > 1 then
                tinsert(ret, i == max and objectaccess and ':' or '.')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}

return function(self)
    local v = name(self)
    if v then
        local ret = setmetatable({ v, type = n.funcname, pos = { left = v.pos.left } }, mt)
        while true do
            local t = self:peek()
            if not t or t.type ~= token.dot then
                break
            end
            self:begin()
            self:take()
            v = name(self)
            if v then
                self:commit()
                table.insert(ret, v)
            else
                self:undo()
                break
            end
        end

        local tok = self:peek()
        if tok and tok.type == token.colon then
            self:begin()
            self:take()
            v = name(self)
            if v then
                self:commit()
                table.insert(ret, v)
                ret.objectaccess = true
            else
                self:undo()
            end
        end

        ret.pos.right = ret[#ret].pos.right
        return ret
    end
end
