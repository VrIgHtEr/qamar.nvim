---@class node_atom:node_expression
---@field value string

local token, node, string = require 'qamar.tokenizer.types', require 'qamar.parser.types', require 'qamar.util.string'
local N = require 'qamar.parser.node_expression'

local token_node_mapping = {
    [token.name] = node.name,
    [token.number] = node.number,
    [token.kw_nil] = node.val_nil,
    [token.kw_false] = node.val_false,
    [token.kw_true] = node.val_true,
    [token.tripledot] = node.vararg,
    [token.string] = node.string,
}

---@param self node_atom
---@return string
local function default__tostring(self)
    return self.value
end

local sescape = string.escape

local __tostring = {
    [node.name] = default__tostring,
    [node.number] = default__tostring,
    [node.val_nil] = default__tostring,
    [node.val_false] = default__tostring,
    [node.val_true] = default__tostring,
    [node.vararg] = default__tostring,
    ---@param self node_atom
    ---@return string
    [node.string] = function(self)
        return sescape(self.value)
    end,
}

local MT = {
    ---@param self node_atom
    ---@return string
    __tostring = function(self)
        return __tostring[self.type](self)
    end,
}

---parselet to consume an expression atom
---@param self parselet
---@param _ parser
---@param tok token
---@return node_atom
return function(self, _, tok)
    local ret = N(token_node_mapping[tok.type], tok.pos, self.precedence, self.right_associative, MT)
    ret.value = tok.value
    return ret
end
