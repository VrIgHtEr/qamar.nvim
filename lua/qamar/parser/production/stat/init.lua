local empty = require 'qamar.parser.production.stat.empty'
local localvar = require 'qamar.parser.production.stat.localvar'
local label = require 'qamar.parser.production.label'
local stat_break = require 'qamar.parser.production.stat.break'
local stat_goto = require 'qamar.parser.production.stat.goto'

return function(self)
    return empty(self) or localvar(self) or label(self) or stat_break(self) or stat_goto(self)
end
