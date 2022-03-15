local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'

local MT = {
    __tostring = function(self)
        return '{' .. tostring(self.value) .. '}'
    end,
}

return function(self, parser, tok)
    local fieldlist = parser.fieldlist() or setmetatable({}, {
        __tostring = function()
            return ''
        end,
    })
    if parser.tokenizer.peek() then
        local rbrace = parser.tokenizer.take()
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
