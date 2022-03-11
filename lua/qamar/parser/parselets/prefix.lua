local display_modes = require 'qamar.display_mode'

local node_types = require 'qamar.parser.types'
local token_types = require 'qamar.tokenizer.types'

local token_node_mapping = {
    [token_types.name] = node_types.name,
    [token_types.number] = node_types.number,
    [token_types.kw_not] = node_types.lnot,
    [token_types.len] = node_types.len,
    [token_types.sub] = node_types.neg,
    [token_types.bitnot] = node_types.bnot,
}

local MT = {
    __tostring = function(self)
        if display_modes.selected_print_mode == display_modes.print_modes.infix then
            local ret = { node_types[self.type], ' ' }
            local paren
            if self.operand.precedence > self.precedence then
                paren = false
            else
                paren = true
            end
            if paren then
                table.insert(ret, '(')
            end
            table.insert(ret, tostring(self.operand))
            if paren then
                table.insert(ret, ')')
            end
            return table.concat(ret)
        elseif display_modes.selected_print_mode == display_modes.print_modes.prefix then
            return '$' .. node_types[self.type] .. ' ' .. tostring(self.operand)
        elseif display_modes.selected_print_mode == display_modes.print_modes.postfix then
            return tostring(self.operand) .. ' $' .. node_types[self.type]
        end
    end,
}

return function(self, parser, token)
    local operand = parser.expression(self.precedence - (self.right_associative and 1 or 0))
    if not operand then
        return nil
    end
    return setmetatable({
        type = token_node_mapping[token.type],
        operand = operand,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = token.pos.left, right = operand.pos.right },
    }, MT)
end
