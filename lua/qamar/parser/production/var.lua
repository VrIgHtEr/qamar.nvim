local n = require 'qamar.parser.types'
local expression = require('qamar.parser.production.expression').parser

local p = require 'qamar.parser'
local commit = p.commit
local undo = p.undo
local begin = p.begin
local nname = n.name
local ntable_nameaccess = n.table_nameaccess
local ntable_rawaccess = n.table_rawaccess

local M = {}

---try to consume a lua variable
---@param self parser
---@return node_name|node_table_nameaccess|node_table_rawaccess
function M:parser()
    begin(self)
    local ret = expression(self)
    if ret and (ret.type == nname or ret.type == ntable_nameaccess or ret.type == ntable_rawaccess) then
        commit(self)
        return ret
    end
    undo(self)
end

return M
