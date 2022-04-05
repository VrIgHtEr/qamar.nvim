local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.name'
local funcbody = require 'qamar.parser.production.funcbody'
local mt = {
    __tostring = function(s)
        return tconcat { 'local function', s.name, s.body }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_local = token.kw_local
local tkw_function = token.kw_function
local setmetatable = setmetatable
local nstat_localfunc = n.stat_localfunc

return function(self)
    local kw_local = peek(self)
    if kw_local and kw_local.type == tkw_local then
        begintake(self)
        local kw_function = take(self)
        if kw_function and kw_function.type == tkw_function then
            local funcname = name(self)
            if funcname then
                local body = funcbody(self)
                if body then
                    commit(self)
                    return setmetatable(
                        { name = funcname, body = body, type = nstat_localfunc, pos = { left = kw_local.pos.left, right = body.pos.right } },
                        mt
                    )
                end
            end
        end
        undo(self)
    end
end
