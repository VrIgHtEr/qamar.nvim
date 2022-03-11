local parselets = require 'qamar.parse.parselets'

local new_parser = function(tokenizer)
    local parser = { tokenizer = tokenizer }

    local function fail()
        tokenizer.undo()
    end

    local function get_precedence()
        local next = tokenizer.peek()
        if next then
            local infix = parselets.infix[next.type]
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

        local prefix = parselets.prefix[token.type]
        if not prefix then
            return fail()
        end

        local left = prefix:parse(parser, token)
        if not left then
            return fail()
        end

        while precedence < get_precedence() do
            token = tokenizer.peek()
            if not token then
                tokenizer.commit()
                return left
            end

            local infix = parselets.infix[token.type]
            if not infix then
                tokenizer.commit()
                return left
            end
            tokenizer.begin()
            tokenizer.take()
            local right = infix:parse(parser, left, token)
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

    return parser
end

local ppp = new_parser(require 'qamar.token'(require 'qamar.token.buffer'(require('toolshed.util.string').codepoints 'a+-b*-3^((4 or 7)+6)^7+4+(7+5)')))
local parsed = ppp.parse_exp()
print(parsed)
return new_parser
