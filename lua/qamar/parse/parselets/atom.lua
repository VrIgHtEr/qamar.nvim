local prefix_token_type_mappings = require 'qamar.parse.prefix_token_type_mappings'
return function(self, _, token)
    return setmetatable({
        value = token.value,
        type = prefix_token_type_mappings[token.type],
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = token.pos,
    }, {
        __tostring = function(node)
            return node.value
        end,
    })
end
