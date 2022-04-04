local config, token, node = require 'qamar.config', require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat

local token_node_mapping = {
    [token.kw_not] = node.lnot,
    [token.hash] = node.len,
    [token.dash] = node.neg,
    [token.tilde] = node.bnot,
}

local MT = {
    __tostring = function(self)
        if config.expression_display_mode == config.expression_display_modes.infix then
            local ret = { node[self.type] }
            local idx = 1
            local paren
            if self.operand.precedence > self.precedence then
                paren = false
            else
                paren = true
            end
            if paren then
                idx = idx + 1
                ret[idx] = '('
            end
            idx = idx + 1
            ret[idx] = self.operand
            if paren then
                idx = idx + 1
                ret[idx] = ')'
            end
            return tconcat(ret)
        elseif config.expression_display_mode == config.expression_display_modes.prefix then
            return tconcat { '$', node[self.type], self.operand }
        elseif config.expression_display_mode == config.expression_display_modes.postfix then
            return tconcat { self.operand, ' $', node[self.type] }
        end
    end,
}

return function(self, parser, tok)
    local operand = parser:expression(self.precedence - (self.right_associative and 1 or 0))
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
