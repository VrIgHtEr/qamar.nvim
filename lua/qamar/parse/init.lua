local node_types = require 'qamar.parse.types'
local token_types = require 'qamar.token.types'
local infix_token_type_mappings = require 'qamar.parse.infix_token_type_mappings'
local prefix_token_type_mappings = require 'qamar.parse.prefix_token_type_mappings'
local precedences = require 'qamar.parse.precedence'

local new_parser = function(tokenizer)
    local parser = {}

    local infix_parselet = function(self, left, token)
        local right = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
        if not right then
            return nil
        end
        return setmetatable({
            type = infix_token_type_mappings[token.type],
            left = left,
            right = right,
            pos = { left = left.pos.left, right = right.pos.right },
        }, {
            __tostring = function(node)
                local ret = {}
                local paren = node.left.type ~= node_types.name and node.left.type ~= node_types.number
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.left))
                if paren then
                    table.insert(ret, ')')
                end
                table.insert(ret, node_types[node.type])
                paren = node.right.type ~= node_types.name and node.right.type ~= node_types.number
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.right))
                if paren then
                    table.insert(ret, ')')
                end
                return table.concat(ret)
            end,
        })
    end

    local prefix_parselet = function(self, token)
        local operand = parser.parse_exp(self.precedence - (self.right_associative and 1 or 0))
        if not operand then
            return nil
        end
        return setmetatable({
            type = prefix_token_type_mappings[token.type],
            operand = operand,
            pos = { left = token.pos.left, right = operand.pos.right },
        }, {
            __tostring = function(node)
                local ret = { node_types[node.type] }
                local paren = node.operand.type ~= node_types.name and node.operand.type ~= node_types.number
                if paren then
                    table.insert(ret, '(')
                end
                table.insert(ret, tostring(node.operand))
                if paren then
                    table.insert(ret, ')')
                end
                return table.concat(ret)
            end,
        })
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
        [token_types.kw_not] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.len] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.sub] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.bitnot] = { precedence = precedences.unary, right_associative = false, parse = prefix_parselet },
        [token_types.name] = {
            precedence = precedences.atom,
            right_associative = false,
            parse = function(_, token)
                return setmetatable({
                    value = token.value,
                    type = prefix_token_type_mappings[token.type],
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
            parse = function(_, token)
                return setmetatable({
                    value = token.value,
                    type = prefix_token_type_mappings[token.type],
                    pos = token.pos,
                }, {
                    __tostring = function(node)
                        return node.value
                    end,
                })
            end,
        },
    }

    local function fail()
        tokenizer.undo()
    end

    local function get_precedence()
        local next = tokenizer.peek()
        if next then
            local infix = infix_parselets[next.type]
            if infix then
                return infix.precedence
            end
        end
        return 0
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

        while precedence < get_precedence() do
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
            tokenizer.begin()
            tokenizer.take()
            local right = infix:parse(left, token)
            if not right then
                tokenizer.undo()
                tokenizer.undo()
                return left
            else
                tokenizer.commit()
                left = right
            end
        end

        tokenizer.commit()
        return left
    end

    return parser.parse_exp
end

local ppp = new_parser(require 'qamar.token'(require 'qamar.token.buffer'(require('toolshed.util.string').codepoints 'a+b*not 3^4+4')))
local parsed = ppp()
print(parsed)

print(vim.inspect(parsed))
return new_parser
