local parselets = require 'qamar.parser.parselets'

return function(tokenizer)
    local parser = { tokenizer = tokenizer }

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

    function parser.expression(precedence)
        precedence = precedence or 0
        tokenizer.begin()
        local token = tokenizer.take()
        if not token then
            tokenizer.undo()
            return
        end

        local prefix = parselets.prefix[token.type]
        if not prefix then
            tokenizer.undo()
            return
        end

        local left = prefix:parse(parser, token)
        if not left then
            tokenizer.undo()
            return
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