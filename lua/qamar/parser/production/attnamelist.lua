local token = require 'qamar.tokenizer.types'
local node = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'
local attribute = require 'qamar.parser.production.attrib'

local ipairs = ipairs
local mt = {
    __tostring = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x.name)
            if x.attrib then
                tinsert(ret, x.attrib)
            end
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local begin = p.begin
local take = p.take
local commit = p.commit
local undo = p.undo
local setmetatable = setmetatable
local nattname = node.attname
local nattnamelist = node.attnamelist
local tcomma = token.comma

return function(self)
    local n = name(self)
    if n then
        local a = attribute(self)
        local ret = setmetatable({
            {
                name = n,
                attrib = a,
                type = nattname,
                pos = { left = n.pos.left, right = (a and a.pos.right or n.pos.right) },
            },
            type = nattnamelist,
            pos = { left = n.pos.left },
        }, mt)
        local idx = 1
        while true do
            local t = peek(self)
            if not t or t.type ~= tcomma then
                break
            end
            begin(self)
            take(self)
            n = name(self)
            if n then
                a = attribute(self)
                commit(self)
                idx = idx + 1
                ret[idx] = {
                    name = n,
                    attrib = a,
                    type = nattname,
                    pos = { left = n.pos.left, right = (a and a.pos.right or n.pos.right) },
                }
            else
                undo(self)
                break
            end
        end

        local last = ret[idx]
        ret.pos.right = (last.attrib and last.attrib or last.name).pos.right
        return ret
    end
end
