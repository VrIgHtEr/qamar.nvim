local token_types = require 'qamar.tokenizer.types'
return function(_, parser, token)
    local left = token.pos.left
    parser.tokenizer.begin()
    local exp = parser.expression()
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
end
