---@class node_prefix:node_expression
---@field operand node_expression

local config, token, node = require 'qamar.config', require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'

local token_node_mapping = {
    [token.kw_not] = node.lnot,
    [token.hash] = node.len,
    [token.dash] = node.neg,
    [token.tilde] = node.bnot,
}

local MT = {
    ---@param self node_prefix
    ---@return string
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

local expression
expression = function(self)
    expression = require('qamar.parser.production.expression').parser
    return expression(self)
end

---parselet that consumes a prefix expression
---@param self parselet
---@param parser parser
---@param tok token
---@return node_prefix|nil
return function(self, parser, tok)
    local operand = expression(parser, self.precedence - (self.right_associative and 1 or 0))
    if not operand then
        return nil
    end
    local ret = N(token_node_mapping[tok.type], range(tok.pos.left, operand.pos.right), self.precedence, self.right_associative, MT)
    ret.operand = operand
    return ret
end
