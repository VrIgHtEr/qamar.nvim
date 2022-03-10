local token_types = require 'qamar.token.types'
local nodetypes = {
    name = 1,
    lnot = 2,
    bnot = 7,
    neg = 6,
    lor = 7,
    land = 8,
    lt = 9,
    gt = 10,
    leq = 11,
    geq = 12,
    neq = 13,
    eq = 14,
    bor = 15,
    bxor = 16,
    band = 17,
    lshift = 18,
    rshift = 19,
    concat = 20,
    add = 21,
    sub = 22,
    mul = 23,
    div = 24,
    fdiv = 25,
    mod = 26,
    exp = 27,
    len = 28,
    number = 29,
}
local infix_token_type_mappings = {
    [token_types.kw_or] = nodetypes.lor,
    [token_types.kw_and] = nodetypes.land,
    [token_types.lt] = nodetypes.lt,
    [token_types.gt] = nodetypes.gt,
    [token_types.leq] = nodetypes.leq,
    [token_types.geq] = nodetypes.geq,
    [token_types.neq] = nodetypes.neq,
    [token_types.eq] = nodetypes.eq,
    [token_types.bitor] = nodetypes.bor,
    [token_types.bitnot] = nodetypes.bxor,
    [token_types.bitand] = nodetypes.band,
    [token_types.lshift] = nodetypes.lshift,
    [token_types.rshift] = nodetypes.rshift,
    [token_types.concat] = nodetypes.concat,
    [token_types.add] = nodetypes.add,
    [token_types.sub] = nodetypes.sub,
    [token_types.mul] = nodetypes.mul,
    [token_types.div] = nodetypes.div,
    [token_types.fdiv] = nodetypes.fdiv,
    [token_types.mod] = nodetypes.mod,
    [token_types.exp] = nodetypes.exp,
}
local prefix_token_type_mappings = {
    [token_types.kw_not] = nodetypes.lnot,
    [token_types.len] = nodetypes.len,
    [token_types.sub] = nodetypes.neg,
    [token_types.bitnot] = nodetypes.bnot,
}
local precedences = {
    atom = 0,
    lor = 1,
    land = 2,
    comparison = 3,
    bor = 4,
    bxor = 5,
    band = 6,
    shift = 7,
    concat = 8,
    add = 9,
    mul = 10,
    unary = 11,
    exp = 12,
}

return function(tokenizer)
    local parser = {}

    local infix_parselet = function(self, left, token)
        local right = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
        if not right then
            return nil
        end
        return { type = infix_token_type_mappings[token.type], left = left, right = right, pos = { left = left.pos.left, right = right.pos.right } }
    end

    local prefix_parselet = function(self, token)
        local operand = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
        if not operand then
            return nil
        end
        return { type = prefix_token_type_mappings[token.type], operand = operand, pos = { left = token.pos.left, right = operand.pos.right } }
    end

    local infix_parselets = {
        [token_types.kw_or] = { precedence = precedences.lor, right_associative = false, parse = infix_parselet },
        [token_types.kw_and] = { precedence = precedences.land, right_associative = false, parse = infix_parselet },
        [token_types.lt] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.gt] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.leq] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.geq] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.neq] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.eq] = { precedence = precedences.comparison, right_associative = false, parse = infix_parselet },
        [token_types.bitor] = { precedence = precedences.bor, right_associative = false, parse = infix_parselet },
        [token_types.bitnot] = { precedence = precedences.bxor, right_associative = false, parse = infix_parselet },
        [token_types.bitand] = { precedence = precedences.band, right_associative = false, parse = infix_parselet },
        [token_types.lshift] = { precedence = precedences.shift, right_associative = false, parse = infix_parselet },
        [token_types.rshift] = { precedence = precedences.shift, right_associative = false, parse = infix_parselet },
        [token_types.concat] = { precedence = precedences.concat, right_associative = true, parse = infix_parselet },
        [token_types.add] = { precedence = precedences.add, right_associative = false, parse = infix_parselet },
        [token_types.sub] = { precedence = precedences.add, right_associative = false, parse = infix_parselet },
        [token_types.mul] = { precedence = precedences.mul, right_associative = false, parse = infix_parselet },
        [token_types.div] = { precedence = precedences.mul, right_associative = false, parse = infix_parselet },
        [token_types.fdiv] = { precedence = precedences.mul, right_associative = false, parse = infix_parselet },
        [token_types.mod] = { precedence = precedences.mul, right_associative = false, parse = infix_parselet },
        [token_types.exp] = { precedence = precedences.exp, right_associative = true, parse = infix_parselet },
    }

    local prefix_parselets = {
        [token_types.name] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(_, token)
                return { value = token.value, type = nodetypes.name, pos = token.pos }
            end,
        },
        [token_types.number] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(_, token)
                return { value = token.value, type = nodetypes.number, pos = token.pos }
            end,
        },
        [token_types.kw_not] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.len] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.sub] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.bitnot] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
    }

    local function fail()
        tokenizer.undo()
    end

    function parser.parse_exp(precedence)
        precedence = precedence or 0
        tokenizer.begin()
        local token = tokenizer.take()
        if not token then
            return fail()
        end

        local prefix = prefix_parselets[token.type]
        if not prefix then
            return fail
        end

        local left = prefix:parse(token)
        if not left then
            return fail()
        end

        token = tokenizer.peek()
        if not token then
            tokenizer.commit()
            return left
        end
        local infix = infix_parselets[token.type]
        if not infix then
            tokenizer.commit()
            return left
        end
        tokenizer.take()

        tokenizer.begin()
        local ret = infix:parse(left, token)
        if not ret then
            tokenizer.undo()
            tokenizer.undo()
            return left
        else
            tokenizer.commit()
        end
        tokenizer.commit()
        return ret
    end

    return parser
end
