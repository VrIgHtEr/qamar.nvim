local types = require 'qamar.tokenizer.types'
local stringparser = require 'qamar.tokenizer.string'

return function(buffer)
    buffer.begin()
    buffer.skipws()
    buffer.suspend_skip_ws()
    local pos = buffer.pos()
    local comment = buffer.try_consume_string '--'
    if not comment then
        buffer.resume_skip_ws()
        buffer.undo()
        return nil
    end
    local ret = stringparser(buffer, true)
    if ret then
        ret.type = types.comment
        ret.pos.left = pos
        buffer.resume_skip_ws()
        buffer.commit()
        return ret
    end
    ret = {}
    while true do
        local c = buffer.peek()
        if c == '' or c == '\n' then
            break
        end
        table.insert(ret, buffer.take())
    end
    buffer.commit()
    buffer.resume_skip_ws()
    return {
        value = table.concat(ret),
        type = types.comment,
        pos = {
            left = pos,
            right = buffer.pos(),
        },
    }
end
