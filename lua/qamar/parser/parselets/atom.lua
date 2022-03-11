local token_types = require 'qamar.tokenizer.types'
local node_types = require 'qamar.parser.types'

local token_node_mapping = {
    [token_types.name] = node_types.name,
    [token_types.number] = node_types.number,
}

local MT = {
    __tostring = function(node)
        return node.value
    end,
}

return function(self, _, token)
    return setmetatable({
        value = token.value,
        type = token_node_mapping[token.type],
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = token.pos,
    }, MT)
end
