local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local setmetatable = setmetatable

local nname = node.name
local ntable_nameaccess = node.table_nameaccess
local ntable_rawaccess = node.table_rawaccess
local nfunctioncall = node.functioncall
local nsubexpression = node.subexpression
local tname = token.name

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '.', self.key }
    end,
}

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take

return function(self, parser, left, tok)
    if left.type == nname or left.type == ntable_nameaccess or left.type == ntable_rawaccess or left.type == nfunctioncall or left.type == nsubexpression then
        local l = left.pos.left
        tok = peek(parser)
        if tok and tok.type == tname then
            take(parser)
            local ret = setmetatable({
                table = left,
                key = tok,
                type = ntable_nameaccess,
                precedence = self.precedence,
                right_associative = self.right_associative,
                pos = { left = l, right = tok.pos.right },
            }, MT)
            return ret
        end
    end
end
