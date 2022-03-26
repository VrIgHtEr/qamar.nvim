local util = require 'qamar.util'
local cfg = require 'qamar.config'
local tconcat = require('qamar.util.table').tconcat
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

local mt = {
    __tostring = function(self)
        return tconcat { self.key, '=', self.value }
    end,
}

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local key = self:peek()
    if key and key.type == token.name then
        self:begin()
        local left = self:take().pos.left
        local tok = self:take()
        if tok and tok.type == token.assignment then
            local value = expression(self)
            if value then
                self:commit()
                return setmetatable({ key = key.value, value = value, type = n.field_name, pos = { left = left, right = value.pos.right } }, mt)
            end
        end
        self:undo()
    end
end
