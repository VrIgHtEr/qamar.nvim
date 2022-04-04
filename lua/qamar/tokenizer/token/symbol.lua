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
    local i = 0
    for k, _ in pairs(symbols) do
        i = i + 1
        t[i] = k
    end
end

local parser = require('qamar.tokenizer.char_stream').combinators.alt(unpack(t))
local MT = {
    __tostring = function(self)
        return self.value
    end,
}
return function(self)
    self:begin()
    self:skipws()
    local pos = self:pos()
    local ret = parser(self)
    if ret then
        self:commit()
        self:resume_skip_ws()
        return setmetatable({
            value = ret,
            type = symbols[ret],
            pos = {
                left = pos,
                right = self:pos(),
            },
        }, MT)
    end
    self:undo()
end
