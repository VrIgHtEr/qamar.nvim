local node_types = require 'qamar.parse.types'
local infix_token_type_mappings = require 'qamar.parse.infix_token_type_mappings'
local display_modes = require 'qamar.display_mode'

return function(self, parser, left, token)
    local right = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
    if not right then
        return nil
    end
    return setmetatable({
        type = infix_token_type_mappings[token.type],
        left = left,
        right = right,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = left.pos.left, right = right.pos.right },
    }, {
        __tostring = function(node)
            if display_modes.selected_print_mode == display_modes.print_modes.infix then
                local ret = {}
                local paren
                if node.left.precedence < node.precedence then
                    paren = true
                elseif node.left.precedence == node.precedence then
                    paren = node.left.type == node.type and node.right_associative
                else
                    paren = false
                end
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.left))
                if paren then
                    table.insert(ret, ')')
                end
                table.insert(ret, ' ')
                table.insert(ret, node_types[node.type])
                table.insert(ret, ' ')
                if node.right.precedence < node.precedence then
                    paren = true
                elseif node.right.precedence == node.precedence then
                    paren = node.right.type == node.type and not node.right_associative
                else
                    paren = false
                end
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.right))
                if paren then
                    table.insert(ret, ')')
                end
                return table.concat(ret)
            elseif display_modes.selected_print_mode == display_modes.print_modes.prefix then
                return node_types[node.type] .. ' ' .. tostring(node.left) .. ' ' .. tostring(node.right)
            elseif display_modes.selected_print_mode == display_modes.print_modes.postfix then
                return tostring(node.left) .. ' ' .. tostring(node.right) .. ' ' .. node_types[node.type]
            end
        end,
    })
end
