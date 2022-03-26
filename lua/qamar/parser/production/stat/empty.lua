local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'

local mt = {
    __tostring = function()
        return ';'
    end,
}

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local tok = self:peek()
    if tok and tok.type == token.semicolon then
        self:take()
        return setmetatable({ type = n.stat_empty, pos = tok.pos }, mt)
    end
end
