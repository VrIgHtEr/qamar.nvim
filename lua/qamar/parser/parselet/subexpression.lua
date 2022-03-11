local token = require 'qamar.tokenizer.types'

return function(_, parser, tok)
    local left = tok.pos.left
    parser.tokenizer.begin()
    local exp = parser.expression()
    if not exp then
        parser.tokenizer.undo()
        return nil
    end
    tok = parser.tokenizer.peek()
    if not tok or tok.type ~= token.rparen then
        parser.tokenizer.undo()
        return nil
    end
    parser.tokenizer.take()
    parser.tokenizer.commit()
    exp.pos.left, exp.pos.right = left, tok.pos.right
    return exp
end
