local token = require 'qamar.tokenizer.types'
local node = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'
local attribute = require 'qamar.parser.production.attrib'

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

return function(self)
    local n = name(self)
    if n then
        local a = attribute(self)
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
                a = attribute(self)
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
        ret.pos.right = (last.attrib and last.attrib or last.name).pos.right
        return ret
    end
end
