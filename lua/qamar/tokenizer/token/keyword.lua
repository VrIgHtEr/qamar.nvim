local token = require 'qamar.tokenizer.types'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}
return function(stream)
    stream.begin()
    stream.skipws()
    local pos = stream.pos()
    local ret = stream.combinators.alt(
        'and',
        'break',
        'do',
        'else',
        'elseif',
        'end',
        'false',
        'for',
        'function',
        'goto',
        'if',
        'in',
        'local',
        'nil',
        'not',
        'or',
        'repeat',
        'return',
        'then',
        'true',
        'until',
        'while'
    )()
    if ret then
        stream.begin()
        stream.suspend_skip_ws()
        local next = stream.alphanumeric()
        stream.resume_skip_ws()
        stream.undo()
        if not next then
            stream.commit()
            stream.resume_skip_ws()
            return setmetatable({
                value = ret,
                type = token['kw_' .. ret],
                pos = {
                    left = pos,
                    right = stream.pos(),
                },
            }, MT)
        end
    end
    stream.undo()
end
