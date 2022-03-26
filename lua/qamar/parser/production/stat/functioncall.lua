local precedence = require 'qamar.parser.precedence'
local n = require 'qamar.parser.types'

local expression = require 'qamar.parser.production.expression'

return function(self)
    self:begin()
    local ret = expression(self, precedence.literal)
    if ret and ret.type == n.functioncall then
        self:commit()
        return ret
    end
    self:undo()
end
