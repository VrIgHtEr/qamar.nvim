local util = require 'qamar.util'
local cfg = require 'qamar.config'
local tconcat = require('qamar.util.table').tconcat

local mt = {
    __tostring = function(self)
        return tconcat { 'repeat', self.body, 'until', self.condition }
    end,
}

local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local block = require 'qamar.parser.production.block'
local expression = require 'qamar.parser.production.expression'

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local tok = self:peek()
    if tok and tok.type == token.kw_repeat then
        local kw_repeat = self:begintake()

        local body = block(self)
        if body then
            tok = self:take()
            if tok and tok.type == token.kw_until then
                local condition = expression(self)
                if condition then
                    self:commit()
                    return setmetatable({
                        body = body,
                        condition = condition,
                        type = n.stat_repeat,
                        pos = { left = kw_repeat.pos.left, right = condition.pos.right },
                    }, mt)
                end
            end
        end
        self:undo()
    end
end
