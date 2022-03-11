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

local MT = {
    __tostring = function(self)
        if display_modes.selected_print_mode == display_modes.print_modes.infix then
            local ret = {}
            local paren
            if self.left.precedence < self.precedence then
                paren = true
            elseif self.left.precedence == self.precedence then
                paren = self.left.type == self.type and self.right_associative
            else
                paren = false
            end
            if paren then
                table.insert(ret, '(')
            end
            table.insert(ret, tostring(self.left))
            if paren then
                table.insert(ret, ')')
            end
            table.insert(ret, ' ')
            table.insert(ret, node_types[self.type])
            table.insert(ret, ' ')
            if self.right.precedence < self.precedence then
                paren = true
            elseif self.right.precedence == self.precedence then
                paren = self.right.type == self.type and not self.right_associative
            else
                paren = false
            end
            if paren then
                table.insert(ret, '(')
            end
            table.insert(ret, tostring(self.right))
            if paren then
                table.insert(ret, ')')
            end
            return table.concat(ret)
        elseif display_modes.selected_print_mode == display_modes.print_modes.prefix then
            return node_types[self.type] .. ' ' .. tostring(self.left) .. ' ' .. tostring(self.right)
        elseif display_modes.selected_print_mode == display_modes.print_modes.postfix then
            return tostring(self.left) .. ' ' .. tostring(self.right) .. ' ' .. node_types[self.type]
        end
    end,
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
    }, MT)
end
