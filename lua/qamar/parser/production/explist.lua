local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local expression = require 'qamar.parser.production.expression'

local mt = {
    __tostring = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}

return function(self)
    local v = expression(self)
    if v then
        local ret = setmetatable({ v, type = n.explist, pos = { left = v.pos.left } }, mt)
        local idx = 0
        while true do
            local t = self:peek()
            if not t or t.type ~= token.comma then
                break
            end
            self:begin()
            self:take()
            v = expression(self)
            if v then
                self:commit()
                idx = idx + 1
                ret[idx] = v
            else
                self:undo()
                break
            end
        end

        ret.pos.right = ret[#ret].pos.right
        return ret
    end
end
