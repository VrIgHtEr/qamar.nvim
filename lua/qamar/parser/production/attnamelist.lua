local token = require 'qamar.tokenizer.types'
local node = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'
local attrib = require 'qamar.parser.production.attrib'

local mt = {
    __tostring = function(self)
        local ret = {}
        for i, x in ipairs(self) do
            if i > 1 then
                tinsert(ret, ',')
            end
            tinsert(ret, x[1], x[2])
        end
        return tconcat(ret)
    end,
}

return function(self)
    local n = name(self)
    if n then
        local a = attrib(self)
        local ret = setmetatable({
            {
                name = n,
                attrib = a,
                type = node.attname,
                pos = { left = n.pos.left, right = (a and a.pos.right or n.pos.right) },
            },
            type = node.attnamelist,
            pos = { left = n.pos.left },
        }, mt)
        while true do
            local t = self:peek()
            if not t or t.type ~= token.comma then
                break
            end
            self:begin()
            self:take()
            n = name(self)
            if n then
                a = attrib(self)
                self:commit()
                table.insert(ret, {
                    name = n,
                    attrib = a,
                    type = node.attname,
                    pos = { left = n.pos.left, right = (a and a.pos.right or n.pos.right) },
                })
            else
                self:undo()
                break
            end
        end

        local last = ret[#ret]
        ret.pos.right = last[#last].pos.right
        return ret
    end
end
