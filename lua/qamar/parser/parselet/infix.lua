---@class node_infix:node_expression
---@field left node_expression
---@field right node_expression

local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'
local config, token, node = require 'qamar.config', require 'qamar.tokenizer.types', require 'qamar.parser.types'

local token_node_mapping = {
    [token.kw_or] = node.lor,
    [token.kw_and] = node.land,
    [token.less] = node.lt,
    [token.greater] = node.gt,
    [token.lessequal] = node.leq,
    [token.greaterequal] = node.geq,
    [token.notequal] = node.neq,
    [token.equal] = node.eq,
    [token.pipe] = node.bor,
    [token.tilde] = node.bxor,
    [token.ampersand] = node.band,
    [token.lshift] = node.lshift,
    [token.rshift] = node.rshift,
    [token.doubledot] = node.concat,
    [token.plus] = node.add,
    [token.dash] = node.sub,
    [token.asterisk] = node.mul,
    [token.slash] = node.div,
    [token.doubleslash] = node.fdiv,
    [token.percent] = node.mod,
    [token.caret] = node.exp,
}

local tconcat = require('qamar.util.table').tconcat

local MT = {
    ---@param self node_infix
    ---@return string
    __tostring = function(self)
        if config.expression_display_mode == config.expression_display_modes.infix then
            local ret = {}
            local idx = 0
            local paren = self.left.precedence < self.precedence or self.left.precedence == self.precedence and self.right_associative
            if paren then
                idx = idx + 1
                ret[idx] = '('
            end
            idx = idx + 1
            ret[idx] = self.left
            if paren then
                idx = idx + 1
                ret[idx] = ')'
            end
            idx = idx + 1
            ret[idx] = node[self.type]
            paren = self.right.precedence < self.precedence or self.right.precedence == self.precedence and not self.right_associative
            if paren then
                idx = idx + 1
                ret[idx] = '('
            end
            idx = idx + 1
            ret[idx] = self.right
            if paren then
                idx = idx + 1
                ret[idx] = ')'
            end
            return tconcat(ret)
        elseif config.expression_display_mode == config.expression_display_modes.prefix then
            return tconcat { node[self.type], self.left, self.right }
        elseif config.expression_display_mode == config.expression_display_modes.postfix then
            return tconcat { self.left, self.right, node[self.type] }
        end
    end,
}

local expression
expression = function(self)
    expression = require('qamar.parser.production.expression').parser
    return expression(self)
end

---parselet to consume an infix expression
---@param self parselet
---@param parser parser
---@param left node_expression
---@param tok token
---@return node_infix|nil
return function(self, parser, left, tok)
    local right = expression(parser, self.precedence - (self.right_associative and 1 or 0))
    if not right then
        return nil
    end
    local ret = N(token_node_mapping[tok.type], range(left.pos.left, right.pos.right), self.precedence, self.right_associative, MT)
    ret.left = left
    ret.right = right
    return ret
end
