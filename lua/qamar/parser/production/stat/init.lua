local empty = require('qamar.parser.production.stat.empty').parser
local localvar = require('qamar.parser.production.stat.localvar').parser
local label = require('qamar.parser.production.label').parser
local stat_break = require('qamar.parser.production.stat.break').parser
local stat_goto = require('qamar.parser.production.stat.goto').parser
local localfunc = require('qamar.parser.production.stat.localfunc').parser
local func = require('qamar.parser.production.stat.func').parser
local for_num = require('qamar.parser.production.stat.for_num').parser
local functioncall = require('qamar.parser.production.stat.functioncall').parser
local assign = require('qamar.parser.production.stat.assign').parser
local stat_repeat = require('qamar.parser.production.stat.repeat').parser
local stat_while = require('qamar.parser.production.stat.while').parser
local for_iter = require('qamar.parser.production.stat.for_iter').parser
local stat_do = require('qamar.parser.production.stat.do').parser
local stat_if = require('qamar.parser.production.stat.if').parser

local M = {}

---try to consume a lua statement
---@param self parser
---@return node_localvar|node_functioncall|node_assign|node_if|node_func|node_for_iter|node_for_num|node_do|node_break|node_while|node_goto|node_empty|node_repeat|node_label
function M:parser()
    return localvar(self)
        or functioncall(self)
        or assign(self)
        or stat_if(self)
        or func(self)
        or localfunc(self)
        or for_iter(self)
        or for_num(self)
        or stat_do(self)
        or stat_break(self)
        or stat_while(self)
        or stat_goto(self)
        or empty(self)
        or stat_repeat(self)
        or label(self)
end

return M
