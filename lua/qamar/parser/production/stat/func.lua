local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.funcname'
local funcbody = require 'qamar.parser.production.funcbody'

local p = require 'qamar.parser'
local peek = p.peek
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tkw_function = token.kw_function
local setmetatable = setmetatable
local nstat_func = n.stat_func

return function(self)
    local kw_function = peek(self)
    if kw_function and kw_function.type == tkw_function then
        begintake(self)
        local funcname = name(self)
        if funcname then
            local body = funcbody(self)
            if body then
                commit(self)
                return setmetatable({ name = funcname, body = body, type = nstat_func, pos = { left = kw_function.pos.left, right = body.pos.right } }, {
                    __tostring = function(s)
                        return tconcat { 'function', s.name, s.body }
                    end,
                })
            end
        end
        undo(self)
    end
end
