local util = require 'qamar.util'
local cfg = require 'qamar.config'
local field_raw = require 'qamar.parser.production.field.raw'
local field_name = require 'qamar.parser.production.field.name'
local expression = require 'qamar.parser.production.expression'

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    return field_raw(self) or field_name(self) or expression(self)
end
