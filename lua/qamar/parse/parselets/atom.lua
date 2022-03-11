local token_types = require 'qamar.token.types'
local nodetypes = require 'qamar.parse.types'

local token_node_mapping = {
    [token_types.name] = nodetypes.name,
    [token_types.number] = nodetypes.number,
}

return function(self, _, token)
    return setmetatable({
        value = token.value,
        type = token_node_mapping[token.type],
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = token.pos,
    }, {
        __tostring = function(node)
            return node.value
        end,
    })
end
