local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.funcname'
local funcbody = require 'qamar.parser.production.funcbody'

return function(self)
    cfg.itrace 'ENTER'
    local kw_function = self:peek()
    if kw_function and kw_function.type == token.kw_local then
        self:begintake()
        local funcname = name(self)
        if funcname then
            local body = funcbody(self)
            if body then
                self:commit()
                local ret = setmetatable({ name = funcname, body = body, type = n.stat_func, pos = { left = kw_function.pos.left, right = body.pos.right } }, {
                    __tostring = function(s)
                        return tconcat { 'function', s.name, s.body }
                    end,
                })
                cfg.dtrace('EXIT: ' .. tostring(ret))
                return ret
            end
        end
        self:undo()
    end
    cfg.dtrace 'EXIT'
end
