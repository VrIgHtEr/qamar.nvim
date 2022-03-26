local util = require 'qamar.util'
local cfg = require 'qamar.config'
local precedence = require 'qamar.parser.precedence'
local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    self:begin()
    local ret = expression(self, precedence.atom)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        self:commit()
        return ret
    end
    self:undo()
end
