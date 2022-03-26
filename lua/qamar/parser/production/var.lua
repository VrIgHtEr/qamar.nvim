local cfg = require 'qamar.config'
local precedence = require 'qamar.parser.precedence'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    cfg.itrace 'ENTER'
    self:begin()
    local ret = expression(self, precedence.atom)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        self:commit()
        cfg.dtrace('EXIT: ' .. tostring(ret))
        return ret
    end
    self:undo()
    cfg.dtrace 'EXIT'
end
