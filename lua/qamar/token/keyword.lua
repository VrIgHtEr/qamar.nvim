local types = require 'qamar.token.types'

return function(buffer)
    buffer.begin()
    buffer.skipws()
    local pos = buffer.pos()
    local ret = buffer.combinators.alt(
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
        buffer.begin()
        local next = buffer.alphanumeric()
        buffer.undo()
        if not next then
            buffer.commit()
            buffer.resume_skip_ws()
            return {
                value = ret,
                type = types['kw_' .. ret],
                pos = {
                    left = pos,
                    right = buffer.pos(),
                },
            }
        end
    end
    buffer.undo()
end
