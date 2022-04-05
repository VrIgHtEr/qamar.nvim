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

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin

return function(self)
    local v = expression(self)
    if v then
        local ret = setmetatable({ v, type = n.explist, pos = { left = v.pos.left } }, mt)
        local idx = 0
        while true do
            local t = peek(self)
            if not t or t.type ~= token.comma then
                break
            end
            begin(self)
            take(self)
            v = expression(self)
            if v then
                commit(self)
                idx = idx + 1
                ret[idx] = v
            else
                undo(self)
                break
            end
        end

        ret.pos.right = ret[#ret].pos.right
        return ret
    end
end
