local token = require 'qamar.tokenizer.types'
local symbols = {
    ['+'] = token.plus,
    ['-'] = token.dash,
    ['*'] = token.asterisk,
    ['/'] = token.slash,
    ['%'] = token.percent,
    ['^'] = token.caret,
    ['#'] = token.hash,
    ['&'] = token.ampersand,
    ['~'] = token.tilde,
    ['|'] = token.pipe,
    ['<<'] = token.lshift,
    ['>>'] = token.rshift,
    ['//'] = token.doubleslash,
    ['=='] = token.equal,
    ['~='] = token.notequal,
    ['<='] = token.lessequal,
    ['>='] = token.greaterequal,
    ['<'] = token.less,
    ['>'] = token.greater,
    ['='] = token.assignment,
    ['('] = token.lparen,
    [')'] = token.rparen,
    ['{'] = token.lbrace,
    ['}'] = token.rbrace,
    ['['] = token.lbracket,
    [']'] = token.rbracket,
    ['::'] = token.doublecolon,
    [';'] = token.semicolon,
    [':'] = token.colon,
    [','] = token.comma,
    ['.'] = token.dot,
    ['..'] = token.doubledot,
    ['...'] = token.tripledot,
}

local t = {}
do
    for k, _ in pairs(symbols) do
        table.insert(t, k)
    end
end

local MT = {__tostring = function(self)return self.value end}
return function(stream)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    local ret = stream.combinators.alt(unpack(t))()
    if ret then
        stream.commit()
        stream.resume_skip_ws()
        return setmetatable({
            value = ret,
            type = symbols[ret],
            pos = {
                left = pos,
                right = stream.pos(),
            },
        },MT)
    end
    stream.undo()
end
