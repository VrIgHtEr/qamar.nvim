local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local mt = {
    __tostring = function(self)
        local ret = {}
        for _, x in ipairs(self) do
            tinsert(ret, x)
        end
        return tconcat(ret)
    end,
}

return function(self)
    local ret = setmetatable({ type = n.block, pos = {} }, mt)
    local idx = 0
    while true do
        local stat = self:stat()
        if not stat then
            break
        end
        idx = idx + 1
        ret[idx] = stat
    end
    local retstat = self:retstat()
    if retstat then
        idx = idx + 1
        ret[idx] = retstat
    end
    if #ret == 0 then
        ret.pos.left = self:pos()
        ret.pos.right = ret.pos.left
    else
        ret.pos.left = ret[1].pos.left
        ret.pos.right = ret[#ret].pos.right
    end
    return ret
end
