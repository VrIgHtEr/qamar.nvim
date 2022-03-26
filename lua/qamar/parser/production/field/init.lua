local cfg = require 'qamar.config'
local field_raw = require 'qamar.parser.production.field.raw'
local field_name = require 'qamar.parser.production.field.name'
local expression = require 'qamar.parser.production.expression'

return function(self)
    cfg.itrace 'ENTER'
    local ret = field_raw(self) or field_name(self) or expression(self)
    if ret then
        cfg.dtrace 'EXIT'
    else
        cfg.dtrace('EXIT: ' .. tostring(ret))
    end
    return ret
end
