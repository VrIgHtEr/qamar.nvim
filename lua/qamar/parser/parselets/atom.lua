local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'

local token_node_mapping = {
    [token.name] = node.name,
    [token.number] = node.number,
}

local MT = {
    __tostring = function(self)
        return self.value
    end,
}

return function(self, _, tok)
    return setmetatable({
        value = tok.value,
        type = token_node_mapping[tok.type],
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = tok.pos,
    }, MT)
end
