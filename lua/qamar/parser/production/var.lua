local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    self:begin()
    local ret = expression(self)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        self:commit()
        return ret
    end
    self:undo()
end
