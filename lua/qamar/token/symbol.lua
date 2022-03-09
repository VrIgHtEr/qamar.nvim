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
    local types = require 'qamar.token.types'
    for k, v in pairs(symbols) do
        symbols[k] = types[v]
        table.insert(t, k)
    end
    table.sort(t, function(a, b)
        return #b < #a
    end)
end

return function(buffer)
    buffer.begin()
    buffer.skipws()
    local pos = buffer.pos()
    local ret = buffer.combinators.alt(unpack(t))()
    if ret then
        buffer.commit()
        buffer.resume_skip_ws()
        return {
            value = ret,
            type = symbols[ret],
            pos = {
                left = pos,
                right = buffer.pos(),
            },
        }
    end
    buffer.undo()
end
