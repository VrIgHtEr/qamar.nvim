local cfg = require 'qamar.config'
local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local MT = {
    __tostring = function(self)
        return tconcat { self.table, '.', self.key }
    end,
}

return function(self, parser, left, tok)
    cfg.itrace 'ENTER'
    if
        left.type == node.name
        or left.type == node.table_nameaccess
        or left.type == node.table_rawaccess
        or left.type == node.functioncall
        or left.type == node.subexpression
    then
        local l = left.pos.left
        tok = parser:peek()
        if tok and tok.type == token.name then
            parser:take()
            local ret = setmetatable({
                table = left,
                key = tok,
                type = node.table_nameaccess,
                precedence = self.precedence,
                right_associative = self.right_associative,
                pos = { left = l, right = tok.pos.right },
            }, MT)
            cfg.dtrace('EXIT: ' .. tostring(ret))
            return ret
        end
    end
    cfg.dtrace 'EXIT'
end
