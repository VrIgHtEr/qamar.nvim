local field_raw = require 'qamar.parser.production.field.raw'
local field_name = require 'qamar.parser.production.field.name'
local expression = require 'qamar.parser.production.expression'

return function(self)
    return field_raw(self) or field_name(self) or expression(self)
end
