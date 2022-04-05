local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'
local ipairs = ipairs
local setmetatable = setmetatable
local nnamelist = n.namelist
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
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin

return function(self)
    local v = name(self)
    if v then
        local ret = setmetatable({ v, type = nnamelist, pos = { left = v.pos.left } }, mt)
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tcomma then
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

        ret.pos.right = ret[idx].pos.right
        return ret
    end
end
