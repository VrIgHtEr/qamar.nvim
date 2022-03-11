local token_types = require 'qamar.token.types'
return function(_, parser, token)
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
end
