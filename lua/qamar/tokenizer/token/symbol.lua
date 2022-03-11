local symbols = {
    ['+'] = 'add',
    ['-'] = 'sub',
    ['*'] = 'mul',
    ['/'] = 'div',
    ['%'] = 'mod',
    ['^'] = 'exp',
    ['#'] = 'len',
    ['&'] = 'bitand',
    ['~'] = 'bitnot',
    ['|'] = 'bitor',
    ['<<'] = 'lshift',
    ['>>'] = 'rshift',
    ['//'] = 'fdiv',
    ['=='] = 'eq',
    ['~='] = 'neq',
    ['<='] = 'leq',
    ['>='] = 'geq',
    ['<'] = 'lt',
    ['>'] = 'gt',
    ['='] = 'assign',
    ['('] = 'lparen',
    [')'] = 'rparen',
    ['{'] = 'lbrace',
    ['}'] = 'rbrace',
    ['['] = 'lbracket',
    [']'] = 'rbracket',
    ['::'] = 'label',
    [';'] = 'semicolon',
    [':'] = 'colon',
    [','] = 'comma',
    ['.'] = 'dot',
    ['..'] = 'concat',
    ['...'] = 'vararg',
}

local t = {}
do
    local token = require 'qamar.tokenizer.types'
    for k, v in pairs(symbols) do
        symbols[k] = token[v]
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
