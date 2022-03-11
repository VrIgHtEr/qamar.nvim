local config, token, node = require 'qamar.display_mode', require 'qamar.tokenizer.types', require 'qamar.parser.types'

local token_node_mapping = {
    [token.kw_or] = node.lor,
    [token.kw_and] = node.land,
    [token.lt] = node.lt,
    [token.gt] = node.gt,
    [token.leq] = node.leq,
    [token.geq] = node.geq,
    [token.neq] = node.neq,
    [token.eq] = node.eq,
    [token.bitor] = node.bor,
    [token.bitnot] = node.bxor,
    [token.bitand] = node.band,
    [token.lshift] = node.lshift,
    [token.rshift] = node.rshift,
    [token.concat] = node.concat,
    [token.add] = node.add,
    [token.sub] = node.sub,
    [token.mul] = node.mul,
    [token.div] = node.div,
    [token.fdiv] = node.fdiv,
    [token.mod] = node.mod,
    [token.exp] = node.exp,
}

local MT = {
    __tostring = function(self)
        if config.selected_print_mode == config.print_modes.infix then
            local ret = {}
            local paren = self.left.precedence < self.precedence or self.left.precedence == self.precedence and self.right_associative
            if paren then
                table.insert(ret, '(')
            end
            table.insert(ret, tostring(self.left))
            if paren then
                table.insert(ret, ')')
            end
            table.insert(ret, ' ')
            table.insert(ret, node[self.type])
            table.insert(ret, ' ')
            paren = self.right.precedence < self.precedence or self.right.precedence == self.precedence and not self.right_associative
            if paren then
                table.insert(ret, '(')
            end
            table.insert(ret, tostring(self.right))
            if paren then
                table.insert(ret, ')')
            end
            return table.concat(ret)
        elseif config.selected_print_mode == config.print_modes.prefix then
            return node[self.type] .. ' ' .. tostring(self.left) .. ' ' .. tostring(self.right)
        elseif config.selected_print_mode == config.print_modes.postfix then
            return tostring(self.left) .. ' ' .. tostring(self.right) .. ' ' .. node[self.type]
        end
    end,
}

return function(self, parser, left, tok)
    local right = parser.expression(self.precedence - (self.right_associative and 1 or 0))
    if not right then
        return nil
    end
    return setmetatable({
        type = token_node_mapping[tok.type],
        left = left,
        right = right,
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = { left = left.pos.left, right = right.pos.right },
    }, MT)
end
