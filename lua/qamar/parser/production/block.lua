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

local p = require 'qamar.parser'
local spos = p.pos
local st, rst
st = function(self)
    st = require 'qamar.parser.production.stat'
    return st(self)
end
rst = function(self)
    rst = require 'qamar.parser.production.retstat'
    return rst(self)
end

return function(self)
    local ret = setmetatable({ type = n.block, pos = {} }, mt)
    local idx = 0
    while true do
        local stat = st(self)
        if not stat then
            break
        end
        idx = idx + 1
        ret[idx] = stat
    end
    local retstat = rst(self)
    if retstat then
        idx = idx + 1
        ret[idx] = retstat
    end
    if idx == 0 then
        ret.pos.left = spos(self)
        ret.pos.right = ret.pos.left
    else
        ret.pos.left = ret[1].pos.left
        ret.pos.right = ret[idx].pos.right
    end
    return ret
end
