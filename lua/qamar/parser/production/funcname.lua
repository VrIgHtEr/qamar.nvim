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
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, i == max and objectaccess and ':' or '.')
            end
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin
local begintake = p.begintake

return function(self)
    local v = name(self)
    if v then
        local ret = setmetatable({ v, type = n.funcname, pos = { left = v.pos.left } }, mt)
        local idx = 0
        while true do
            local t = peek(self)
            if not t or t.type ~= token.dot then
                break
            end
            begin(self)
            take(self)
            v = name(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
            else
                undo(self)
                break
            end
        end

        local tok = peek(self)
        if tok and tok.type == token.colon then
            begintake(self)
            v = name(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
                ret.objectaccess = true
            else
                undo(self)
            end
        end

        ret.pos.right = ret[#ret].pos.right
        return ret
    end
end
