local n = require 'qamar.parser.types'

local expression = require('qamar.parser.production.expression').parser

local p = require 'qamar.parser'
local commit = p.commit
local undo = p.undo
local begin = p.begin
local nfunctioncall = n.functioncall

local M = {}

---try to consume a lua function call
---@param self parser
---@return node_functioncall|nil
function M:parser()
    begin(self)
    local ret = expression(self)
    if ret and ret.type == nfunctioncall then
        commit(self)
        return ret
    end
    undo(self)
end

return M
