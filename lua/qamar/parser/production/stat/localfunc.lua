local util = require 'qamar.util'
local cfg = require 'qamar.config'
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

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local kw_local = self:peek()
    if kw_local and kw_local.type == token.kw_local then
        self:begintake()
        local kw_function = self:take()
        if kw_function and kw_function.type == token.kw_function then
            local funcname = name(self)
            if funcname then
                local body = funcbody(self)
                if body then
                    self:commit()
                    return setmetatable(
                        { name = funcname, body = body, type = n.stat_localfunc, pos = { left = kw_local.pos.left, right = body.pos.right } },
                        mt
                    )
                end
            end
        end
        self:undo()
    end
end
