local infix_parselet, prefix_parselet = require 'qamar.parse.parselets.infix_parselet', require 'qamar.parse.parselets.prefix_parselet'
local precedences = require 'qamar.parse.precedence'
local prefix_token_type_mappings = require 'qamar.parse.prefix_token_type_mappings'
local token_types = require 'qamar.token.types'

local parselets = {
    infix = {
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
    },
    prefix = {
        [token_types.kw_not] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.len] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.sub] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.bitnot] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.lparen] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(_, parser, token)
                local left = token.pos.left
                parser.tokenizer.begin()
                local exp = parser.parse_exp()
                if not exp then
                    parser.tokenizer.undo()
                    return nil
                end
                token = parser.tokenizer.peek()
                if not token or token.type ~= token_types.rparen then
                    parser.tokenizer.undo()
                    return nil
                end
                parser.tokenizer.take()
                parser.tokenizer.commit()
                exp.pos.left, exp.pos.right = left, token.pos.right
                return exp
            end,
        },
        [token_types.name] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(self, _, token)
                return setmetatable({
                    value = token.value,
                    type = prefix_token_type_mappings[token.type],
                    precedence = self.precedence,
                    right_associative = self.right_associative,
                    pos = token.pos,
                }, {
                    __tostring = function(node)
                        return node.value
                    end,
                })
            end,
        },
        [token_types.number] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(self, _, token)
                return setmetatable({
                    value = token.value,
                    type = prefix_token_type_mappings[token.type],
                    precedence = self.precedence,
                    right_associative = self.right_associative,
                    pos = token.pos,
                }, {
                    __tostring = function(node)
                        return node.value
                    end,
                })
            end,
        },
    },
}
return parselets
