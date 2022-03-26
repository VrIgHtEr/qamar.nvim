local empty = require 'qamar.parser.production.stat.empty'
local localvar = require 'qamar.parser.production.stat.localvar'
local label = require 'qamar.parser.production.label'
local stat_break = require 'qamar.parser.production.stat.break'
local stat_goto = require 'qamar.parser.production.stat.goto'
local localfunc = require 'qamar.parser.production.stat.localfunc'
local func = require 'qamar.parser.production.stat.func'
local for_num = require 'qamar.parser.production.stat.for_num'
local functioncall = require 'qamar.parser.production.stat.functioncall'
local assign = require 'qamar.parser.production.stat.assign'
local stat_repeat = require 'qamar.parser.production.stat.repeat'
local stat_while = require 'qamar.parser.production.stat.while'
local for_iter = require 'qamar.parser.production.stat.for_iter'

return function(self)
    return empty(self)
        or localvar(self)
        or label(self)
        or stat_break(self)
        or stat_goto(self)
        or localfunc(self)
        or func(self)
        or for_num(self)
        or for_iter(self)
        or stat_while(self)
        or stat_repeat(self)
        or assign(self)
        or functioncall(self)
end
