local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local field = require 'qamar.parser.production.field'
local ipairs = ipairs
local setmetatable = setmetatable
local nfieldlist = n.fieldlist
local tcomma = token.comma
local tsemicolon = token.semicolon

local mt = {
    __tostring = function(self)
        local ret, idx = {}, 1
        for i, x in ipairs(self) do
            if i > 1 then
                ret[idx], idx = ',', idx + 1
            end
            ret[idx], idx = x, idx + 1
        end
        return tconcat(ret)
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin

return function(self)
    local f = field(self)
    if f then
        local pos = { left = f.pos.left, right = f.pos.right }
        local ret, idx = setmetatable({ f, type = nfieldlist, pos = pos }, mt), 1
        while true do
            local tok = peek(self)
            if tok and (tok.type == tcomma or tok.type == tsemicolon) then
                begin(self)
                take(self)
                f = field(self)
                if not f then
                    undo(self)
                    break
                end
                idx = idx + 1
                ret[idx] = f
                commit(self)
            else
                break
            end
        end
        local tok = peek(self)
        if tok and (tok.type == tcomma or tok.type == tsemicolon) then
            take(self)
        end
        return ret
    end
end
