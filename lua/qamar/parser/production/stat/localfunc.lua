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

return function(self)
    local kw_local = peek(self)
    if kw_local and kw_local.type == token.kw_local then
        begintake(self)
        local kw_function = take(self)
        if kw_function and kw_function.type == token.kw_function then
            local funcname = name(self)
            if funcname then
                local body = funcbody(self)
                if body then
                    commit(self)
                    return setmetatable(
                        { name = funcname, body = body, type = n.stat_localfunc, pos = { left = kw_local.pos.left, right = body.pos.right } },
                        mt
                    )
                end
            end
        end
        undo(self)
    end
end
