local node_types = require 'qamar.parser.types'
local token_types = require 'qamar.tokenizer.types'

local display_modes = require 'qamar.display_mode'

local token_node_mapping = {
    [token_types.kw_or] = node_types.lor,
    [token_types.kw_and] = node_types.land,
    [token_types.lt] = node_types.lt,
    [token_types.gt] = node_types.gt,
    [token_types.leq] = node_types.leq,
    [token_types.geq] = node_types.geq,
    [token_types.neq] = node_types.neq,
    [token_types.eq] = node_types.eq,
    [token_types.bitor] = node_types.bor,
    [token_types.bitnot] = node_types.bxor,
    [token_types.bitand] = node_types.band,
    [token_types.lshift] = node_types.lshift,
    [token_types.rshift] = node_types.rshift,
    [token_types.concat] = node_types.concat,
    [token_types.add] = node_types.add,
    [token_types.sub] = node_types.sub,
    [token_types.mul] = node_types.mul,
    [token_types.div] = node_types.div,
    [token_types.fdiv] = node_types.fdiv,
    [token_types.mod] = node_types.mod,
    [token_types.exp] = node_types.exp,
}

return function(self, parser, left, token)
    local right = parser.expression(self.precedence - (self.right_associative and 1 or 0))
    if not right then
        return nil
    end
    return setmetatable({
        type = token_node_mapping[token.type],
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
