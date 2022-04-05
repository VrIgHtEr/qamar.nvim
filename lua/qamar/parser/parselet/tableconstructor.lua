local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local pfieldlist
pfieldlist = function(self)
    pfieldlist = require 'qamar.parser.production.fieldlist'
    return pfieldlist(self)
end

local MT = {
    __tostring = function(self)
        return tconcat { '{', self.value, '}' }
    end,
}

return function(self, parser, tok)
    local fieldlist = pfieldlist(parser) or setmetatable({}, {
        __tostring = function()
            return ''
        end,
    })
    if peek(parser) then
        local rbrace = take(parser)
        if rbrace.type == token.rbrace then
            return setmetatable({
                value = fieldlist,
                type = node.tableconstructor,
                precedence = self.precedence,
                right_associative = self.right_associative,
                pos = { left = tok.pos.left, right = rbrace.pos.right },
            }, MT)
        end
    end
end
