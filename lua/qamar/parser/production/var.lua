local n = require 'qamar.parser.types'
local expression = require 'qamar.parser.production.expression'

local p = require 'qamar.parser'
local commit = p.commit
local undo = p.undo
local begin = p.begin

return function(self)
    begin(self)
    local ret = expression(self)
    if ret and (ret.type == n.name or ret.type == n.table_nameaccess or ret.type == n.table_rawaccess) then
        commit(self)
        return ret
    end
    undo(self)
end
