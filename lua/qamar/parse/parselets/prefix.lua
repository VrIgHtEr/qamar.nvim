local display_modes = require 'qamar.display_mode'

local node_types = require 'qamar.parse.types'
local token_types = require 'qamar.token.types'

local token_node_mapping = {
    [token_types.name] = node_types.name,
    [token_types.number] = node_types.number,
    [token_types.kw_not] = node_types.lnot,
    [token_types.len] = node_types.len,
    [token_types.sub] = node_types.neg,
    [token_types.bitnot] = node_types.bnot,
}

return function(self, parser, token)
    local operand = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
    if not operand then
        return nil
    end
    return setmetatable({
        type = token_node_mapping[token.type],
        operand = operand,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = token.pos.left, right = operand.pos.right },
    }, {
        __tostring = function(node)
            if display_modes.selected_print_mode == display_modes.print_modes.infix then
                local ret = { node_types[node.type], ' ' }
                local paren
                if node.operand.precedence > node.precedence then
                    paren = false
                else
                    paren = true
                end
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.operand))
                if paren then
                    table.insert(ret, ')')
                end
                return table.concat(ret)
            elseif display_modes.selected_print_mode == display_modes.print_modes.prefix then
                return '$' .. node_types[node.type] .. ' ' .. tostring(node.operand)
            elseif display_modes.selected_print_mode == display_modes.print_modes.postfix then
                return tostring(node.operand) .. ' $' .. node_types[node.type]
            end
        end,
    })
end
