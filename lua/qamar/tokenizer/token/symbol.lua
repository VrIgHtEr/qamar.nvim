local token = require 'qamar.tokenizer.types'
local symbols = {
    ['+'] = token.add,
    ['-'] = token.sub,
    ['*'] = token.mul,
    ['/'] = token.div,
    ['%'] = token.mod,
    ['^'] = token.exp,
    ['#'] = token.len,
    ['&'] = token.bitand,
    ['~'] = token.bitnot,
    ['|'] = token.bitor,
    ['<<'] = token.lshift,
    ['>>'] = token.rshift,
    ['//'] = token.fdiv,
    ['=='] = token.eq,
    ['~='] = token.neq,
    ['<='] = token.leq,
    ['>='] = token.geq,
    ['<'] = token.lt,
    ['>'] = token.gt,
    ['='] = token.assign,
    ['('] = token.lparen,
    [')'] = token.rparen,
    ['{'] = token.lbrace,
    ['}'] = token.rbrace,
    ['['] = token.lbracket,
    [']'] = token.rbracket,
    ['::'] = token.label,
    [';'] = token.semicolon,
    [':'] = token.colon,
    [','] = token.comma,
    ['.'] = token.dot,
    ['..'] = token.concat,
    ['...'] = token.vararg,
}

local t = {}
do
    for k, _ in pairs(symbols) do
        table.insert(t, k)
    end
end

return function(stream)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    local ret = stream.combinators.alt(unpack(t))()
    if ret then
        stream.commit()
        stream.resume_skip_ws()
        return {
            value = ret,
            type = symbols[ret],
            pos = {
                left = pos,
                right = stream.pos(),
            },
        }
    end
    stream.undo()
end
