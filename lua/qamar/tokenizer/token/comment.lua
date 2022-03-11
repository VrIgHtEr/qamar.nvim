local token, string_token = require 'qamar.tokenizer.types', require 'qamar.tokenizer.token.string'

return function(stream)
    stream.begin()
    stream.skipws()
    stream.suspend_skip_ws()
    local pos = stream.pos()
    local comment = stream.try_consume_string '--'
    if not comment then
        stream.resume_skip_ws()
        stream.undo()
        return nil
    end
    local ret = string_token(stream, true)
    if ret then
        ret.type = token.comment
        ret.pos.left = pos
        stream.resume_skip_ws()
        stream.commit()
        return ret
    end
    ret = {}
    while true do
        local c = stream.peek()
        if c == '' or c == '\n' then
            break
        end
        table.insert(ret, stream.take())
    end
    stream.commit()
    stream.resume_skip_ws()
    return {
        value = table.concat(ret),
        type = token.comment,
        pos = {
            left = pos,
            right = stream.pos(),
        },
    }
end
