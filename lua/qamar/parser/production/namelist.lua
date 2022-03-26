local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'

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
    if cfg.trace then
        print(util.get_script_path())
    end
    local v = name(self)
    if v then
        local ret = setmetatable({ v, type = n.namelist, pos = { left = v.pos.left } }, mt)
        while true do
            local t = self:peek()
            if not t or t.type ~= token.comma then
                break
            end
            self:begin()
            self:take()
            v = name(self)
            if v then
                self:commit()
                table.insert(ret, v)
            else
                self:undo()
                break
            end
        end

        ret.pos.right = ret[#ret].pos.right
        return ret
    end
end
