local config, token, node = require 'qamar.display_mode', require 'qamar.tokenizer.types', require 'qamar.parser.types'

local token_node_mapping = {
    [token.name] = node.name,
    [token.number] = node.number,
    [token.kw_not] = node.lnot,
    [token.len] = node.len,
    [token.sub] = node.neg,
    [token.bitnot] = node.bnot,
}

local MT = {
    __tostring = function(self)
        if config.selected_print_mode == config.print_modes.infix then
            local ret = { node[self.type], ' ' }
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
        elseif config.selected_print_mode == config.print_modes.prefix then
            return '$' .. node[self.type] .. ' ' .. tostring(self.operand)
        elseif config.selected_print_mode == config.print_modes.postfix then
            return tostring(self.operand) .. ' $' .. node[self.type]
        end
    end,
}

return function(self, parser, tok)
    local operand = parser.expression(self.precedence - (self.right_associative and 1 or 0))
    if not operand then
        return nil
    end
    return setmetatable({
        type = token_node_mapping[tok.type],
        operand = operand,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = tok.pos.left, right = operand.pos.right },
    }, MT)
end
