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

local p = require 'qamar.parser'
local peek = p.peek
local begintake = p.begintake
local commit = p.commit
local undo = p.undo

return function(self)
    local v = vararg(self)
    if v then
        return setmetatable({ v, type = n.parlist, pos = v.pos }, mt)
    else
        v = namelist(self)
        if v then
            local ret = setmetatable({ type = n.parlist, pos = { left = v.pos.left } }, mt)
            local idx = 0
            for i, x in ipairs(v) do
                ret[i] = x
            end
            v = peek(self)
            if v and v.type == token.comma then
                begintake(self)
                v = vararg(self)
                if v then
                    commit(self)
                    idx = idx + 1
                    ret[idx] = v
                else
                    undo(self)
                end
            end
            ret.pos.right = ret[#ret].pos.right
            return ret
        end
    end
end
