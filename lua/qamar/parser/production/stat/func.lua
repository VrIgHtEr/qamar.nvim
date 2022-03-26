local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local name = require 'qamar.parser.production.funcname'
local funcbody = require 'qamar.parser.production.funcbody'

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local kw_function = self:peek()
    if kw_function and kw_function.type == token.kw_local then
        self:begintake()
        local funcname = name(self)
        if funcname then
            local body = funcbody(self)
            if body then
                self:commit()
                return setmetatable({ name = funcname, body = body, type = n.stat_func, pos = { left = kw_function.pos.left, right = body.pos.right } }, {
                    __tostring = function(s)
                        return tconcat { 'function', s.name, s.body }
                    end,
                })
            end
        end
        self:undo()
    end
end
