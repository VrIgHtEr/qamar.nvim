local cfg = require 'qamar.config'
local n = require 'qamar.parser.types'

local expression = require 'qamar.parser.production.expression'

return function(self)
    cfg.itrace 'ENTER'
    self:begin()
    local ret = expression(self)
    if ret and ret.type == n.functioncall then
        self:commit()
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
    self:undo()
    cfg.dtrace 'EXIT'
end
