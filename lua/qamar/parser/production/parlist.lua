local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local namelist = require 'qamar.parser.production.namelist'
local vararg = require 'qamar.parser.production.vararg'
local ipairs = ipairs
local setmetatable = setmetatable
local nparlist = n.parlist
local tcomma = token.comma

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
        return setmetatable({ v, type = nparlist, pos = v.pos }, mt)
    else
        v = namelist(self)
        if v then
            local ret = setmetatable({ type = nparlist, pos = { left = v.pos.left } }, mt)
            local idx = 0
            for _, x in ipairs(v) do
                idx = idx + 1
                ret[idx] = x
            end
            v = peek(self)
            if v and v.type == tcomma then
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
            ret.pos.right = ret[idx].pos.right
            return ret
        end
    end
end
