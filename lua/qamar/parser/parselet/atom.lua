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

local __tostring = {
    [node.name] = default__tostring,
    [node.number] = default__tostring,
    [node.val_nil] = default__tostring,
    [node.val_false] = default__tostring,
    [node.val_true] = default__tostring,
    [node.vararg] = default__tostring,
    [node.string] = function(self)
        local ret, sep = {}, nil
        do
            if
                false
                and (
                    self.value:find '\a'
                    or self.value:find '\b'
                    or self.value:find '\f'
                    or self.value:find '\n'
                    or self.value:find '\r'
                    or self.value:find '\t'
                    or self.value:find '\v'
                    or (self.value:find "'" and self.value:find '"')
                )
            then
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
            local v = c
            if v == '\\' then
                v = '\\\\'
            elseif v == '\a' then
                v = '\\a'
            elseif v == '\b' then
                v = '\\b'
            elseif v == '\f' then
                v = '\\f'
            elseif v == '\n' then
                v = '\\n'
            elseif v == '\r' then
                v = '\\r'
            elseif v == '\t' then
                v = '\\t'
            elseif v == '\v' then
                v = '\\v'
            elseif v == '"' and sep == '"' then
                v = '\\"'
            elseif v == "'" and sep == "'" then
                v = "\\'"
            end
            table.insert(ret, v)
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
