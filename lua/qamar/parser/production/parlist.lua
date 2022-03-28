local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local namelist = require 'qamar.parser.production.namelist'
local vararg = require 'qamar.parser.production.vararg'

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
    cfg.itrace 'ENTER'
    local v = vararg(self)
    if v then
        local ret = setmetatable({ v, type = n.parlist, pos = v.pos }, mt)
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    else
        v = namelist(self)
        if v then
            local ret = setmetatable({ type = n.parlist, pos = { left = v.pos.left } }, mt)
            for i, x in ipairs(v) do
                ret[i] = x
            end
            v = self:peek()
            if v and v.type == token.comma then
                self:begintake()
                v = vararg(self)
                if v then
                    self:commit()
                    table.insert(ret, v)
                else
                    self:undo()
                end
            end
            ret.pos.right = ret[#ret].pos.right
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
    end
    cfg.dtrace 'EXIT'
end
