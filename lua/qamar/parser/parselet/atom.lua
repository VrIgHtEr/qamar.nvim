local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local string = require 'toolshed.util.string'

local token_node_mapping = {
    [token.name] = node.name,
    [token.number] = node.number,
    [token.kw_nil] = node.val_nil,
    [token.kw_false] = node.val_false,
    [token.kw_true] = node.val_true,
    [token.tripledot] = node.vararg,
    [token.string] = node.string,
}

local __tostring = {
    [node.name] = function(self)
        return self.value
    end,
    [node.number] = function(self)
        return self.value
    end,
    [node.val_nil] = function(self)
        return self.value
    end,
    [node.val_false] = function(self)
        return self.value
    end,
    [node.val_true] = function(self)
        return self.value
    end,
    [node.vararg] = function(self)
        return self.value
    end,
    [node.string] = function(self)
        local ret, sep = {}, nil

        do
            if self.value:find '\r' or self.value:find '\n' or (self.value:find "'" and self.value:find '"') then
                local eqs = ''
                while true do
                    sep = ']' .. eqs .. ']'
                    if not string.find(self.value, sep) then
                        table.insert(ret, '[' .. eqs .. '[')
                        break
                    end
                    eqs = eqs .. '='
                end
            else
                sep = self.value:find "'" and '"' or "'"
                table.insert(ret, sep)
            end
        end
        for c in string.codepoints(self.value) do
            table.insert(ret, c)
        end
        table.insert(ret, sep)
        return table.concat(ret)
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
