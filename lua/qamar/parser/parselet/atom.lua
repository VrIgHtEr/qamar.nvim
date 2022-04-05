local token, node, string = require 'qamar.tokenizer.types', require 'qamar.parser.types', require 'qamar.util.string'

local token_node_mapping = {
    [token.name] = node.name,
    [token.number] = node.number,
    [token.kw_nil] = node.val_nil,
    [token.kw_false] = node.val_false,
    [token.kw_true] = node.val_true,
    [token.tripledot] = node.vararg,
    [token.string] = node.string,
}

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
    [node.string] = function(self)
        return sescape(self.value)
    end,
}

local MT = {
    __tostring = function(self)
        return __tostring[self.type](self)
    end,
}

return function(self, _, tok)
    return setmetatable({
        value = tok.value,
        type = token_node_mapping[tok.type],
        precedence = self.precedence,
        right_associative = self.right_associative,
        pos = tok.pos,
    }, MT)
end
