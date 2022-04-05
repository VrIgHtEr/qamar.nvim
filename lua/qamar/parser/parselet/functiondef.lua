local node = require 'qamar.parser.types'

local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { 'function', self.value }
    end,
}
local funcbody = require 'qamar.parser.production.funcbody'

return function(self, parser, tok)
    local body = funcbody(parser)
    if body then
        return setmetatable({
            value = body,
            type = node.functiondef,
            precedence = self.precedence,
            right_associative = self.right_associative,
            pos = { left = tok.pos.left, right = body.pos.right },
        }, MT)
    end
end
